#!/bin/bash
#
# Scan for orphaned rclone FUSE mounts and clean them up (cross-platform).
# See: https://github.com/harvard-visionlab/setup-guide
#
# Orphaned mounts occur when:
#   - A job/session ends without unmounting
#   - The rclone process crashes
#   - You forgot to unmount before closing terminal
#
# Usage:
#   ./s3_zombie_sweep.sh          # report only (default)
#   ./s3_zombie_sweep.sh report   # report only
#   ./s3_zombie_sweep.sh fix      # unmount orphans

set -euo pipefail

MODE="${1:-report}"
USER="${USER:-$(whoami)}"

# Platform detection
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      echo "ERROR: Unsupported OS: $OS"; exit 1 ;;
esac

echo "Platform: ${PLATFORM}"
echo "User:     ${USER}"
echo "Mode:     ${MODE}"
echo ""

# Find rclone mounts - platform specific parsing
if [ "$PLATFORM" = "linux" ]; then
  # Linux: look for "type fuse.rclone"
  MOUNTS=$(mount | grep "type fuse.rclone" | awk '{print $1 "||" $3}' || true)
else
  # macOS: look for rclone in mount output (format differs)
  MOUNTS=$(mount | grep "rclone" | awk '{print $1 "||" $3}' || true)
fi

if [ -z "$MOUNTS" ]; then
  echo "No rclone FUSE mounts found."
  exit 0
fi

printf "%-40s  %-50s  %s\n" "REMOTE" "MOUNTPOINT" "STATUS"
printf "%-40s  %-50s  %s\n" "------" "----------" "------"

# Platform-specific unmount
do_unmount() {
  local mp="$1"
  if [ "$PLATFORM" = "linux" ]; then
    fusermount3 -uz "$mp" 2>/dev/null || \
    fusermount -uz "$mp" 2>/dev/null || \
    /bin/umount -l "$mp" 2>/dev/null || return 1
  else
    umount "$mp" 2>/dev/null || return 1
  fi
  return 0
}

echo "$MOUNTS" | while IFS= read -r line; do
  [ -z "$line" ] && continue

  remote="${line%%||*}"
  mp="${line##*||}"
  bucket="${remote#*:}"

  # Check if there's a live rclone process for this bucket
  if pgrep -f "rclone mount.*${bucket}" >/dev/null 2>&1; then
    status="OK (rclone running)"
  else
    status="ORPHAN (no rclone process)"
  fi

  printf "%-40s  %-50s  %s\n" "$remote" "$mp" "$status"

  # Fix orphans if requested
  if [ "$MODE" = "fix" ] && [[ "$status" == ORPHAN* ]]; then
    echo "  -> Cleaning up..."
    if do_unmount "$mp"; then
      echo "  -> Unmounted"
      rmdir "$mp" 2>/dev/null || true
    else
      echo "  -> Failed to unmount"
    fi
  fi
done

echo ""
if [ "$MODE" = "fix" ]; then
  echo "Sweep complete."
else
  echo "No changes made (report mode). Run with 'fix' to clean up orphans."
fi
