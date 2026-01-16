#!/bin/bash
#
# Mount an S3 bucket using rclone FUSE (cross-platform: Linux/macOS).
# See: https://github.com/harvard-visionlab/setup-guide
#
# Usage:
#   ./s3_bucket_mount.sh <mount_path> <bucket_name>
#
# Examples:
#   ./s3_bucket_mount.sh $BUCKET_DIR visionlab-members
#   ./s3_bucket_mount.sh . visionlab-datasets

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <mount_path> <bucket_name>"
  echo "Example: $0 \$BUCKET_DIR visionlab-members"
  exit 1
fi

MOUNT_PATH="$(eval echo "$1")"
BUCKET_NAME="$2"
USER="${USER:-$(whoami)}"

# Platform detection
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      echo "ERROR: Unsupported OS: $OS"; exit 1 ;;
esac

# Paths - use job ID for isolation on SLURM
JOB_TAG="${SLURM_JOB_ID:-interactive}"
NODE_LOCAL_MP="/tmp/$USER/rclone/${JOB_TAG}/${BUCKET_NAME}"
LOG_DIR="/tmp/$USER/rclone-logs/${JOB_TAG}"
LOG_FILE="${LOG_DIR}/${BUCKET_NAME}.log"
LINK_PATH="${MOUNT_PATH%/}/${BUCKET_NAME}"

echo "Bucket:        ${BUCKET_NAME}"
echo "Symlink:       ${LINK_PATH}"
echo "Mount point:   ${NODE_LOCAL_MP}"
echo "Platform:      ${PLATFORM}"

# Pre-flight checks
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone not found"; exit 1; }
[ -f ~/.config/rclone/rclone.conf ] || { echo "ERROR: Missing rclone config at ~/.config/rclone/rclone.conf"; exit 1; }

# Platform-specific FUSE check
if [ "$PLATFORM" = "linux" ]; then
  [ -e /dev/fuse ] || { echo "ERROR: /dev/fuse not present"; exit 1; }
else
  [ -d /Library/Frameworks/fuse_t.framework ] || [ -d /Library/Frameworks/macFUSE.framework ] || \
    { echo "ERROR: FUSE-T not installed - brew install --cask fuse-t"; exit 1; }
fi

# Platform-specific mountpoint check
is_mounted() {
  local check_path="$1"
  if [ "$PLATFORM" = "linux" ]; then
    mountpoint -q "$check_path" 2>/dev/null
  else
    mount | grep -q " on /private${check_path} " || mount | grep -q " on ${check_path} "
  fi
}

echo "Testing S3 access..."
rclone lsd s3_remote: >/dev/null 2>&1 || { echo "ERROR: Cannot access S3. Check AWS credentials."; exit 1; }
rclone lsd "s3_remote:${BUCKET_NAME}" >/dev/null 2>&1 || { echo "ERROR: Cannot access bucket '${BUCKET_NAME}'"; exit 1; }

mkdir -p "$(dirname "$LINK_PATH")" "$LOG_DIR" "$NODE_LOCAL_MP"

# Check for existing mount/symlink issues
if is_mounted "$LINK_PATH"; then
  echo "ERROR: ${LINK_PATH} is already a mountpoint. Unmount first."
  exit 1
fi

if [ -e "$LINK_PATH" ] && [ ! -L "$LINK_PATH" ]; then
  echo "ERROR: ${LINK_PATH} exists and is not a symlink"
  exit 1
fi

# If already mounted, just refresh symlink
if is_mounted "$NODE_LOCAL_MP"; then
  echo "Mount already active at ${NODE_LOCAL_MP}"
else
  # Clean stale files if not mounted
  rm -rf "${NODE_LOCAL_MP:?}"/* 2>/dev/null || true

  echo "Mounting..."
  rclone mount "s3_remote:${BUCKET_NAME}" "$NODE_LOCAL_MP" \
    --daemon \
    --vfs-cache-mode writes \
    --s3-chunk-size 50M \
    --s3-upload-cutoff 50M \
    --buffer-size 50M \
    --dir-cache-time 30s \
    --timeout 30s \
    --contimeout 30s \
    --log-level INFO \
    --log-file "${LOG_FILE}"

  # Wait for mount
  for i in {1..10}; do
    if is_mounted "$NODE_LOCAL_MP"; then
      echo "Mount active"
      break
    fi
    [ $i -eq 10 ] && { echo "ERROR: Mount failed. Check: ${LOG_FILE}"; tail -50 "$LOG_FILE" 2>/dev/null || true; exit 1; }
    sleep 1
  done
fi

# Create symlink
ln -sfn "$NODE_LOCAL_MP" "$LINK_PATH"

echo ""
echo "Done: ${LINK_PATH} -> ${NODE_LOCAL_MP}"
echo ""
echo "To unmount:"
echo "  ./s3_bucket_unmount.sh ${MOUNT_PATH} ${BUCKET_NAME}"
