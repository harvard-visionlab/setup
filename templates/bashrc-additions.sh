# ==============================================================================
# Vision Lab Configuration
# ==============================================================================

# Lab affiliation - determines storage paths
# Set to your primary advisor's lab: alvarez_lab or konkle_lab
export LAB=alvarez_lab

# Storage roots
export MY_WORK_DIR=/n/holylabs/LABS/${LAB}/Users/$USER
export MY_NETSCRATCH=/n/netscratch/${LAB}/Everyone/$USER
export TIER1=/n/alvarez_lab_tier1/Lab/

# Holylabs folder structure
export PROJECT_DIR=${MY_WORK_DIR}/Projects    # Git repos go here
export BUCKET_DIR=${MY_WORK_DIR}/Buckets      # S3 bucket mounts
export SANDBOX_DIR=${MY_WORK_DIR}/Sandbox     # Testing/scratch

# uv (Python package manager) configuration
# Shared lab cache - first person to install a package benefits everyone
# Uses alvarez_lab since all visionlab members have access
export UV_CACHE_DIR=/n/holylabs/LABS/alvarez_lab/Everyone/.uv_cache
# Per-user tools directory
export UV_TOOL_DIR=${MY_WORK_DIR}/.uv_tools

# Shared model caches - first person to download benefits everyone
# On netscratch: performant, large, ephemeral (models re-download as needed)
export TORCH_HOME=/n/netscratch/alvarez_lab/Lab/.cache/torch
export HF_HOME=/n/netscratch/alvarez_lab/Lab/.cache/huggingface
export KERAS_HOME=/n/netscratch/alvarez_lab/Lab/.cache/keras

# AWS configuration
# Ask George to send you your credentials; keep these secret always, never commit to any public repo.
# Bots crawl and find exposed credentials - it will cost you tens of thousands of dollars
# and could bork the entire lab infrastructure.
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_REGION=us-east-1

# Convenience aliases
alias cdw='cd $MY_WORK_DIR'
alias cdn='cd $MY_NETSCRATCH'
alias cdt='cd $TIER1'
alias cdp='cd $PROJECT_DIR'
alias cdb='cd $BUCKET_DIR'
alias cds='cd $SANDBOX_DIR'

# Default working directory for interactive shells (e.g., Jupyter terminals)
if [[ $- == *i* ]]; then
    if [[ -n "${MY_WORK_DIR}" && -d "${MY_WORK_DIR}" ]]; then
        cd "${MY_WORK_DIR}"
    else
        cd "$HOME"
    fi
fi
