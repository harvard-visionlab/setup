#!/bin/bash
#
# Unmount an S3 bucket that was mounted with s3_bucket_mount.sh
# See: https://github.com/harvard-visionlab/setup/blob/main/docs/harvard-cluster.md#5-mounting-s3-buckets-rclone
#
# Usage:
#   ./s3_bucket_unmount.sh <mount_path> <bucket_name> [--all-jobs] [--quiet]
#
# Examples:
#   ./s3_bucket_unmount.sh $BUCKET_DIR visionlab-members
#   ./s3_bucket_unmount.sh . teamspace-lrm --all-jobs
#
# Options:
#   --all-jobs  Unmount this bucket from all job directories on this node
#   --quiet     Minimal output
#
# Note: Mounts are per-node. Run this on the SAME NODE where the mount exists.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo ""
  echo "Usage: $0 <mount_path> <bucket_name> [--all-jobs] [--quiet]"
  echo "Example: $0 \$BUCKET_DIR visionlab-members"
  exit 1
fi

MOUNT_PATH="$1"
BUCKET_NAME="$2"
shift 2

# Parse optional flags
ALL_JOBS=""
QUIET=false
for arg in "$@"; do
  case "$arg" in
    --all-jobs) ALL_JOBS="--all-jobs" ;;
    --quiet|-q) QUIET=true ;;
  esac
done

# Expand ~ in MOUNT_PATH
MOUNT_PATH=$(eval echo "$MOUNT_PATH")

# Don't keep the mount busy
cd ~

HOST_SHORT="$(hostname -s || echo node)"
JOB_TAG="${SLURM_JOB_ID:-interactive}"

# Candidate node-local mountpoints
declare -a CANDIDATES=()

if [ "$ALL_JOBS" = "--all-jobs" ]; then
  # Find all job-tagged mountpoints for this bucket
  while IFS= read -r -d '' p; do
    CANDIDATES+=("$p")
  done < <(find "/tmp/$USER/rclone" -maxdepth 4 -type d -name "${BUCKET_NAME}" -print0 2>/dev/null || true)
else
  # Check both path patterns (with and without hostname)
  CANDIDATES+=("/tmp/$USER/rclone/${JOB_TAG}/${BUCKET_NAME}")
  CANDIDATES+=("/tmp/$USER/rclone/${HOST_SHORT}/${JOB_TAG}/${BUCKET_NAME}")
fi

# Unique the list
if [ ${#CANDIDATES[@]} -gt 0 ]; then
  mapfile -t CANDIDATES < <(printf "%s\n" "${CANDIDATES[@]}" | awk '!x[$0]++')
fi

LINK_PATH="${MOUNT_PATH%/}/${BUCKET_NAME}"

if ! $QUIET; then
  echo "Unmounting bucket:   ${BUCKET_NAME}"
  echo "Symlink path:        ${LINK_PATH}"
  echo "Host:                ${HOST_SHORT}"
  if [ "$ALL_JOBS" = "--all-jobs" ]; then
    echo "Mode:                all jobs on this host"
  else
    echo "Job tag:             ${JOB_TAG}"
  fi
  echo ""
fi

# Helper to unmount one path
# Try non-lazy unmount first to flush rclone's write cache
unmount_one() {
  local MP="$1"
  [ -n "$MP" ] || return 0

  if mountpoint -q "$MP" 2>/dev/null; then
    $QUIET || echo "-> Unmounting (with cache flush): $MP"

    # Try non-lazy unmount first - waits for rclone to flush cache
    if timeout 30 /bin/umount -- "$MP" 2>/dev/null; then
      $QUIET || echo "   Unmounted (cache flushed)"
    elif timeout 30 fusermount3 -u -- "$MP" 2>/dev/null; then
      $QUIET || echo "   Unmounted (cache flushed)"
    elif timeout 30 fusermount -u -- "$MP" 2>/dev/null; then
      $QUIET || echo "   Unmounted (cache flushed)"
    else
      # Fall back to lazy unmount
      $QUIET || echo "   Non-lazy unmount timed out, using lazy unmount"
      if /bin/umount -l -- "$MP" 2>/dev/null \
        || (command -v fusermount3 >/dev/null 2>&1 && fusermount3 -uz -- "$MP" 2>/dev/null) \
        || (command -v fusermount  >/dev/null 2>&1 && fusermount  -uz -- "$MP" 2>/dev/null); then
        $QUIET || echo "   Lazy unmounted (cache may not have flushed)"
      else
        if mountpoint -q "$MP" 2>/dev/null; then
          echo "   ERROR: Still mounted (close any shells/processes using that path)"
        else
          $QUIET || echo "   Unmounted"
        fi
      fi
    fi
  else
    $QUIET || echo "-> Not a mountpoint (ok): $MP"
  fi

  # Clean up empty directories
  case "$MP" in
    "/tmp/$USER/rclone/"*)
      rmdir "$MP" 2>/dev/null || true
      rmdir "$(dirname "$MP")" 2>/dev/null || true
      rmdir "$(dirname "$(dirname "$MP")")" 2>/dev/null || true
      ;;
  esac
}

if [ ${#CANDIDATES[@]} -eq 0 ]; then
  $QUIET || echo "No candidate mountpoints found for this host/bucket."
else
  for MP in "${CANDIDATES[@]}"; do
    unmount_one "$MP"
  done
fi

# Kill any remaining rclone processes for this bucket
if command -v pkill >/dev/null 2>&1; then
  pkill -f "rclone mount .*s3_remote:${BUCKET_NAME}" 2>/dev/null || true
fi

# Remove the symlink
if [ -L "$LINK_PATH" ]; then
  $QUIET || echo "Removing symlink: $LINK_PATH"
  rm -f -- "$LINK_PATH"
elif [ -e "$LINK_PATH" ]; then
  echo "WARNING: '$LINK_PATH' exists but is not a symlink. Not removing."
else
  $QUIET || echo "Symlink not present (ok): $LINK_PATH"
fi

if ! $QUIET; then
  echo ""
  echo "Remaining rclone mounts for this bucket on this host:"
  mount | grep -E "fuse\.rclone.*${BUCKET_NAME}" || echo "  none"
  echo ""
fi

echo "Unmount complete."
