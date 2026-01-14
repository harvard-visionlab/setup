# ==============================================================================
# Vision Lab Standard Configuration
# Added by harvard-visionlab/setup
# ==============================================================================

# Lab affiliation (determines storage paths)
# Options: alvarez_lab, konkle_lab
export LAB=__LAB_PLACEHOLDER__

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
