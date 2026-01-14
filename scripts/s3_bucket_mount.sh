#!/bin/bash
#
# Mount an S3 bucket using rclone FUSE.
# See: https://github.com/harvard-visionlab/setup/blob/main/docs/harvard-cluster.md#5-mounting-s3-buckets-rclone
#
# Prerequisites:
#   - rclone installed and configured (~/.config/rclone/rclone.conf)
#   - /dev/fuse available on the node
#   - AWS credentials in environment (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
#
# Usage:
#   ./s3_bucket_mount.sh <mount_path> <bucket_name>
#
# Examples:
#   ./s3_bucket_mount.sh $BUCKET_DIR visionlab-members
#   ./s3_bucket_mount.sh . teamspace-lrm
#
# The script creates a node-local mount at /tmp/$USER/rclone/<host>/<job>/bucket
# and symlinks it to <mount_path>/<bucket_name> for easy access.
#
# To unmount, use s3_bucket_unmount.sh or manually:
#   /bin/umount -l /tmp/$USER/rclone/$(hostname -s)/${SLURM_JOB_ID:-interactive}/<bucket>
#   rm -f <mount_path>/<bucket>

set -euo pipefail

# ---- Args & usage -----------------------------------------------------------
if [ $# -ne 2 ]; then
  echo ""
  echo "Usage: $0 <mount_path> <bucket_name>"
  echo "Example: $0 \$BUCKET_DIR visionlab-members"
  exit 1
fi

MOUNT_PATH="$1"
BUCKET_NAME="$2"

# Expand ~ in MOUNT_PATH
MOUNT_PATH=$(eval echo "$MOUNT_PATH")

# Basic deps
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone not found in PATH"; exit 1; }
[ -e /dev/fuse ] || { echo "ERROR: /dev/fuse not present on this node"; exit 1; }

# Node-local mountpoint (per-host, per-job or 'interactive')
HOST_SHORT="$(hostname -s || echo node)"
JOB_TAG="${SLURM_JOB_ID:-interactive}"
NODE_LOCAL_MP="/tmp/$USER/rclone/${HOST_SHORT}/${JOB_TAG}/${BUCKET_NAME}"

# Keep logs OUTSIDE the mountpoint so they remain visible even if mount fails
LOG_ROOT="/tmp/$USER/rclone-logs/${HOST_SHORT}/${JOB_TAG}/${BUCKET_NAME}"
LOG_FILE="${LOG_ROOT}/mount.log"
mkdir -p "$LOG_ROOT"

# Symlink location
LINK_PATH="${MOUNT_PATH%/}/${BUCKET_NAME}"

echo "Starting rclone setup..."
echo "Bucket:        ${BUCKET_NAME}"
echo "Symlink:       ${LINK_PATH}"
echo "Node-local MP: ${NODE_LOCAL_MP}"
echo "Log file:      ${LOG_FILE}"

# ---- Pre-flight checks -------------------------------------------------------
# Ensure rclone config exists
if [ ! -f ~/.config/rclone/rclone.conf ]; then
  echo "ERROR: Missing rclone config at ~/.config/rclone/rclone.conf"
  echo ""
  echo "Create it with:"
  echo "  mkdir -p ~/.config/rclone"
  echo "  cat > ~/.config/rclone/rclone.conf << 'EOF'"
  echo "  [s3_remote]"
  echo "  type = s3"
  echo "  provider = AWS"
  echo "  env_auth = true"
  echo "  region = us-east-1"
  echo "  EOF"
  exit 1
fi

# Test AWS creds and listable remote
echo "Testing S3 access..."
if ! rclone lsd s3_remote: > /dev/null 2>&1; then
  echo "ERROR: Cannot access S3 with current credentials (rclone lsd s3_remote: failed)."
  echo "Check that AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set in your environment."
  exit 1
fi

# Verify bucket exists
echo "Verifying bucket access..."
if ! rclone lsd "s3_remote:${BUCKET_NAME}" > /dev/null 2>&1; then
  echo "ERROR: Cannot access bucket '${BUCKET_NAME}'. Check name/permissions."
  exit 1
fi

# Ensure parent dir of LINK_PATH exists
mkdir -p "$(dirname "$LINK_PATH")"

# Refuse to proceed if LINK_PATH is currently a mountpoint (old direct mount)
if mountpoint -q "$LINK_PATH" 2>/dev/null; then
  echo "ERROR: ${LINK_PATH} is a mountpoint already. Unmount it first."
  echo "Hint: fusermount3 -uz '$LINK_PATH'  (or /bin/umount -l '$LINK_PATH')"
  exit 1
fi

# If LINK_PATH exists as a real directory (not a symlink), don't clobber it
if [ -e "$LINK_PATH" ] && [ ! -L "$LINK_PATH" ]; then
  echo "ERROR: ${LINK_PATH} exists and is not a symlink."
  echo "Please move/remove it before proceeding."
  exit 1
fi

# ---- Ensure node-local mountpoint exists and is EMPTY ------------------------
mkdir -p "$NODE_LOCAL_MP"

# If it's not already a mountpoint, make sure it's empty
if ! mountpoint -q "$NODE_LOCAL_MP" 2>/dev/null; then
  # Only auto-clean under /tmp/$USER/rclone/* for safety
  case "$NODE_LOCAL_MP" in
    "/tmp/$USER/rclone/"*) ;;
    *) echo "ERROR: Refusing to clean non-/tmp path: $NODE_LOCAL_MP"; exit 1 ;;
  esac

  # If directory contains anything, nuke contents
  if [ -n "$(ls -A "$NODE_LOCAL_MP" 2>/dev/null || true)" ]; then
    echo "INFO: ${NODE_LOCAL_MP} not empty; cleaning stale files..."
    rm -rf -- "$NODE_LOCAL_MP"/* "$NODE_LOCAL_MP"/.[!.]* "$NODE_LOCAL_MP"/..?* 2>/dev/null || true
  fi
fi

# If already mounted there, just refresh the symlink
if mountpoint -q "$NODE_LOCAL_MP" 2>/dev/null; then
  echo "INFO: Node-local mount already active at ${NODE_LOCAL_MP}"
else
  # ---- Do the mount ---------------------------------------------------------
  echo "Mounting S3 bucket '${BUCKET_NAME}' to node-local path..."
  set +e
  rclone mount "s3_remote:${BUCKET_NAME}" "$NODE_LOCAL_MP" \
    --daemon \
    --vfs-cache-mode writes \
    --s3-chunk-size 50M \
    --s3-upload-cutoff 50M \
    --buffer-size 50M \
    --dir-cache-time 30s \
    --timeout 30s \
    --contimeout 30s \
    --log-level DEBUG \
    --log-file "${LOG_FILE}"
  RC=$?
  set -e

  if [ $RC -ne 0 ]; then
    echo "ERROR: rclone mount exited with code $RC"
    echo "----- rclone log (tail) ----------------------------------------"
    tail -n 120 "${LOG_FILE}" || true
    echo "----------------------------------------------------------------"
    exit $RC
  fi

  echo "Waiting for mount to become active..."
  for i in {1..20}; do
    if mountpoint -q "$NODE_LOCAL_MP" 2>/dev/null; then
      echo "Mount is active: $NODE_LOCAL_MP"
      break
    fi
    if [ $i -eq 20 ]; then
      echo "ERROR: S3 mount did not come up at ${NODE_LOCAL_MP}"
      echo "----- rclone log (tail) ----------------------------------------"
      tail -n 200 "${LOG_FILE}" || true
      echo "----------------------------------------------------------------"
      exit 1
    fi
    sleep 1
  done
fi

# ---- Create/refresh the symlink ---------------------------------------------
ln -sfn "$NODE_LOCAL_MP" "$LINK_PATH"

# Verify the link resolves
if [ "$(readlink -f "$LINK_PATH" || true)" != "$(readlink -f "$NODE_LOCAL_MP" || true)" ]; then
  echo "ERROR: Symlink at ${LINK_PATH} did not resolve to ${NODE_LOCAL_MP}"
  exit 1
fi

echo ""
echo "Setup complete!"
echo "S3 bucket '${BUCKET_NAME}' is mounted at:"
echo "  ${NODE_LOCAL_MP}"
echo "and symlinked to:"
echo "  ${LINK_PATH}"
echo ""
echo "To unmount later (on this same node):"
echo "  ./s3_bucket_unmount.sh ${MOUNT_PATH} ${BUCKET_NAME}"
