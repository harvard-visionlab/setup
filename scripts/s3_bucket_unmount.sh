#!/bin/bash
#
# Unmount an S3 bucket (cross-platform: Linux/macOS).
# See: https://github.com/harvard-visionlab/setup-guide
#
# Usage:
#   ./s3_bucket_unmount.sh <mount_path> <bucket_name>
#
# Examples:
#   ./s3_bucket_unmount.sh $BUCKET_DIR visionlab-members
#   ./s3_bucket_unmount.sh . visionlab-datasets

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

# Don't keep the mount busy
cd ~

JOB_TAG="${SLURM_JOB_ID:-interactive}"
NODE_LOCAL_MP="/tmp/$USER/rclone/${JOB_TAG}/${BUCKET_NAME}"
LINK_PATH="${MOUNT_PATH%/}/${BUCKET_NAME}"

echo "Unmounting bucket: ${BUCKET_NAME}"
echo "Symlink:           ${LINK_PATH}"
echo "Mount point:       ${NODE_LOCAL_MP}"
echo "Platform:          ${PLATFORM}"
echo ""

# Platform-specific mountpoint check
is_mounted() {
  local check_path="$1"
  if [ "$PLATFORM" = "linux" ]; then
    mountpoint -q "$check_path" 2>/dev/null
  else
    mount | grep -q " on /private${check_path} " || mount | grep -q " on ${check_path} "
  fi
}

# Platform-specific unmount
do_unmount() {
  local mp="$1"
  if [ "$PLATFORM" = "linux" ]; then
    # Try fusermount3, then fusermount, then umount
    fusermount3 -uz "$mp" 2>/dev/null || \
    fusermount -uz "$mp" 2>/dev/null || \
    /bin/umount -l "$mp" 2>/dev/null || true
  else
    umount "$mp" 2>/dev/null || true
  fi
}

# Kill rclone processes for this bucket
if command -v pkill >/dev/null 2>&1; then
  pkill -f "rclone mount .*s3_remote:${BUCKET_NAME}" 2>/dev/null || true
fi

# Unmount if mounted
if is_mounted "$NODE_LOCAL_MP"; then
  echo "Unmounting ${NODE_LOCAL_MP}..."
  do_unmount "$NODE_LOCAL_MP"

  # Verify
  if is_mounted "$NODE_LOCAL_MP"; then
    echo "WARNING: Still mounted. Close any shells or processes using the mount."
  else
    echo "Unmounted successfully"
  fi
else
  echo "Not mounted: ${NODE_LOCAL_MP}"
fi

# Clean up empty directories
rmdir "$NODE_LOCAL_MP" 2>/dev/null || true
rmdir "$(dirname "$NODE_LOCAL_MP")" 2>/dev/null || true

# Remove symlink
if [ -L "$LINK_PATH" ]; then
  echo "Removing symlink: ${LINK_PATH}"
  rm -f "$LINK_PATH"
elif [ -e "$LINK_PATH" ]; then
  echo "WARNING: ${LINK_PATH} exists but is not a symlink. Not removing."
else
  echo "Symlink not present: ${LINK_PATH}"
fi

echo ""
echo "Unmount complete."
