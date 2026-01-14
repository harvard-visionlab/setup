#!/bin/bash
# Setup home directory symlinks to prevent quota bloat
# Usage: bash setup-symlinks.sh
#
# This script symlinks large cache directories out of your home directory
# to prevent hitting the 100GB quota.
#
# Directories are symlinked to:
#   - Netscratch: for ephemeral caches (ok to lose on monthly cleanup)
#   - Holylabs: for persistent data (conda envs, etc.)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if LAB is set
if [ -z "$LAB" ]; then
    error "LAB environment variable is not set."
    echo "Please run setup-bashrc.sh first, or set LAB manually:"
    echo "  export LAB=alvarez_lab  # or konkle_lab"
    exit 1
fi

NETSCRATCH="/n/netscratch/${LAB}/Lab/Users/$USER"
HOLYLABS="/n/holylabs/LABS/${LAB}/Users/$USER"
TIER1="/n/alvarez_lab_tier1/Users/$USER"

# Verify storage access
if [ ! -d "$NETSCRATCH" ]; then
    warn "Netscratch directory doesn't exist. Creating it..."
    mkdir -p "$NETSCRATCH"
fi

if [ ! -d "$HOLYLABS" ]; then
    error "Holylabs directory doesn't exist: $HOLYLABS"
    echo "Please contact the lab administrator for access."
    exit 1
fi

if [ ! -d "$TIER1" ]; then
    warn "Tier1 directory doesn't exist: $TIER1"
    warn "Conda environments will be stored on holylabs instead."
    TIER1="$HOLYLABS"  # Fallback to holylabs
fi

# Function to create a symlink
# Usage: setup_symlink <source_in_home> <target_base> <description>
setup_symlink() {
    local src="$HOME/$1"
    local target_base="$2"
    local desc="$3"
    local target="$target_base/home_symlinks/$1"

    echo ""
    info "Setting up $1 ($desc)"

    # If already a symlink, check if it points to the right place
    if [ -L "$src" ]; then
        current_target=$(readlink "$src")
        if [ "$current_target" = "$target" ]; then
            info "  Already symlinked correctly"
            return 0
        else
            warn "  Already a symlink to: $current_target"
            warn "  Expected: $target"
            warn "  Skipping (remove manually if you want to change it)"
            return 0
        fi
    fi

    # Create target directory
    mkdir -p "$(dirname "$target")"

    # If source exists and has content, move it
    if [ -e "$src" ]; then
        if [ -d "$src" ] && [ "$(ls -A "$src" 2>/dev/null)" ]; then
            info "  Moving existing data to $target"
            mkdir -p "$target"
            # Use cp + rm instead of mv for cross-filesystem moves
            cp -a "$src/." "$target/" 2>/dev/null || true
            rm -rf "$src"
        elif [ -d "$src" ]; then
            # Empty directory, just remove it
            rmdir "$src"
        else
            # Regular file
            mkdir -p "$(dirname "$target")"
            cp -a "$src" "$target"
            rm "$src"
        fi
    fi

    # Create target directory if it doesn't exist
    mkdir -p "$target"

    # Create symlink
    ln -s "$target" "$src"
    info "  Created symlink: $src -> $target"
}

echo "========================================"
echo "Vision Lab Home Directory Symlink Setup"
echo "========================================"
echo ""
echo "LAB: $LAB"
echo "NETSCRATCH: $NETSCRATCH"
echo "TIER1: $TIER1"
echo ""
echo "This script will symlink the following directories:"
echo ""
echo "To NETSCRATCH (ephemeral - ok to lose on monthly cleanup):"
echo "  ~/.cache           - General caches (pip, huggingface, torch hub, etc.)"
echo ""
echo "To TIER1 (persistent):"
echo "  ~/.conda           - Conda environments (if using conda)"
echo ""
echo "NOT symlinked (kept in home, small but expensive to rebuild):"
echo "  ~/.nv              - NVIDIA/CUDA cache"
echo "  ~/.triton          - Triton (GPU compiler) cache"
echo ""
read -p "Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Symlinks to netscratch (ephemeral caches)
setup_symlink ".cache" "$NETSCRATCH" "general caches (pip, huggingface, torch hub, etc.)"

# Symlinks to tier1 (persistent - environments take time to recreate)
setup_symlink ".conda" "$TIER1" "conda environments"

echo ""
echo "========================================"
info "Setup complete!"
echo "========================================"
echo ""
echo "Your home directory symlinks:"
ls -la ~/.cache ~/.conda 2>/dev/null || true
echo ""
echo "Check your home directory usage with: du -sh ~"
