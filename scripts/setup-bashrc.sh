#!/bin/bash
# Setup script for Vision Lab bashrc configuration
# Usage: bash setup-bashrc.sh

set -e

MARKER="# Vision Lab Standard Configuration"
BASHRC="$HOME/.bashrc"

# Check if already configured
if grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    echo "Vision Lab configuration already present in $BASHRC"
    echo "To reconfigure, remove the 'Vision Lab Standard Configuration' block from your bashrc first."
    exit 0
fi

# Get lab affiliation
echo "Vision Lab Bashrc Setup"
echo "========================"
echo ""
echo "Which lab are you affiliated with?"
echo "  1) alvarez_lab"
echo "  2) konkle_lab"
echo ""
read -p "Enter 1 or 2: " choice

case $choice in
    1) LAB="alvarez_lab" ;;
    2) LAB="konkle_lab" ;;
    *)
        echo "Invalid choice. Please enter 1 or 2."
        exit 1
        ;;
esac

echo ""
echo "Setting LAB=$LAB"
echo ""

# Create the configuration block
CONFIG=$(cat << 'ENDCONFIG'

# ==============================================================================
# Vision Lab Standard Configuration
# Added by harvard-visionlab/setup
# ==============================================================================

# Lab affiliation (determines storage paths)
# Options: alvarez_lab, konkle_lab
export LAB=__LAB__

# Standard directory shortcuts
export HOLYLABS=/n/holylabs/LABS/${LAB}/Users/$USER
export NETSCRATCH=/n/netscratch/${LAB}/Lab/Users/$USER
export TIER1=/n/alvarez_lab_tier1/Users/$USER

# uv (Python package manager) configuration
# Cache on holylabs enables hardlinks for fast installs
export UV_CACHE_DIR=${HOLYLABS}/.uv_cache

# Convenience aliases
alias cdh='cd $HOLYLABS'
alias cdn='cd $NETSCRATCH'
alias cdt='cd $TIER1'

# ==============================================================================
# End Vision Lab Configuration
# ==============================================================================
ENDCONFIG
)

# Replace placeholder with actual lab
CONFIG="${CONFIG//__LAB__/$LAB}"

# Append to bashrc
echo "$CONFIG" >> "$BASHRC"

echo "Configuration added to $BASHRC"
echo ""
echo "Run 'source ~/.bashrc' to apply changes, or start a new shell."
echo ""
echo "You now have these shortcuts:"
echo "  \$HOLYLABS   - Your holylabs directory (projects, code)"
echo "  \$NETSCRATCH - Your netscratch directory (temp files)"
echo "  \$TIER1      - Your tier1 directory (valuable data)"
echo "  cdh         - cd to holylabs"
echo "  cdn         - cd to netscratch"
echo "  cdt         - cd to tier1"
