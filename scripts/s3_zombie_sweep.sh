#!/bin/bash
#
# Scan the current node for rclone FUSE mounts and report/clean up orphans.
# See: https://github.com/harvard-visionlab/setup/blob/main/docs/harvard-cluster.md#5-mounting-s3-buckets-rclone
#
# Orphaned mounts can occur when:
#   - A SLURM job crashes without unmounting
#   - You forgot to unmount before ending an interactive session
#   - The rclone process died unexpectedly
#
# Usage:
#   ./s3_zombie_sweep.sh            # report only (default)
#   ./s3_zombie_sweep.sh report     # report only
#   ./s3_zombie_sweep.sh fix        # kill orphan rclone processes and unmount

set -euo pipefail

MODE="${1:-report}"
HOST_SHORT="$(hostname -s || echo node)"
USER_NAME="$(id -un)"
USER_ID="$(id -u)"

echo "Host: ${HOST_SHORT}  User: ${USER_NAME} (UID ${USER_ID})"
echo "Mode: ${MODE}"
echo

# List: remote and mountpoint for fuse.rclone lines
mapfile -t MOUNTS < <(mount | awk '/type fuse\.rclone/ {print $1"||"$3}')

if [ ${#MOUNTS[@]} -eq 0 ]; then
  echo "No rclone FUSE mounts found on this node."
  exit 0
fi

printf "%-42s  %-64s  %-s\n" "REMOTE" "MOUNTPOINT" "STATUS"
printf "%-42s  %-64s  %-s\n" "------" "----------" "------"

# Helper: unmount one mountpoint safely
unmount_one() {
  local mp="$1"
  /bin/umount -l -- "$mp" 2>/dev/null \
    || (command -v fusermount3 >/dev/null 2>&1 && fusermount3 -uz -- "$mp" 2>/dev/null) \
    || (command -v fusermount  >/dev/null 2>&1 && fusermount  -uz -- "$mp" 2>/dev/null) \
    || return 1

  # Clean empty directories
  case "$mp" in
    "/tmp/$USER/rclone/"*)
      rmdir "$mp" 2>/dev/null || true
      rmdir "$(dirname "$mp")" 2>/dev/null || true
      rmdir "$(dirname "$(dirname "$mp")")" 2>/dev/null || true
      ;;
  esac
  return 0
}

for line in "${MOUNTS[@]}"; do
  remote="${line%%||*}"
  mp="${line##*||}"
  bucket="${remote#*:}"

  # Check if there's a live rclone process for this bucket
  if pgrep -fa "rclone mount .*${bucket}(\$|[^[:alnum:]_-])" >/dev/null 2>&1; then
    status="OK (owned by rclone)"
  else
    status="ORPHAN (no rclone pid)"
  fi

  printf "%-42s  %-64s  %-s\n" "$remote" "$mp" "$status"

  if [ "$MODE" = "fix" ] && [ "$status" != "OK (owned by rclone)" ]; then
    # Kill any stale rclone for this bucket
    pkill -f "rclone mount .*${bucket}(\$|[^[:alnum:]_-])" 2>/dev/null || true
    if mountpoint -q "$mp" 2>/dev/null; then
      if unmount_one "$mp"; then
        printf "  -> cleaned: %s\n" "$mp"
      else
        printf "  -> FAILED to unmount: %s\n" "$mp"
      fi
    else
      printf "  -> already gone: %s\n" "$mp"
    fi
  fi
done

echo
if [ "$MODE" = "fix" ]; then
  echo "Sweep complete."
else
  echo "No changes made (report mode). Run with 'fix' to clean up orphans."
fi
