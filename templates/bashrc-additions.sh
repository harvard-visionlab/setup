# ==============================================================================
# Vision Lab Configuration
# ==============================================================================

# Lab affiliation - determines storage paths
# Set to your primary advisor's lab: alvarez_lab or konkle_lab
export LAB=alvarez_lab

# Storage roots
export HOLYLABS=/n/holylabs/LABS/${LAB}/Users/$USER
export NETSCRATCH=/n/netscratch/${LAB}/Lab/Users/$USER
export TIER1=/n/alvarez_lab_tier1/Users/$USER

# Holylabs folder structure
export PROJECT_DIR=${HOLYLABS}/Projects    # Git repos go here
export BUCKET_DIR=${HOLYLABS}/Buckets      # S3 bucket mounts
export SANDBOX_DIR=${HOLYLABS}/Sandbox     # Testing/scratch

# uv (Python package manager) configuration
# Shared lab cache - first person to install a package benefits everyone
# Uses alvarez_lab since all visionlab members have access
export UV_CACHE_DIR=/n/holylabs/LABS/alvarez_lab/Lab/.uv_cache
# Per-user tools directory
export UV_TOOL_DIR=${HOLYLABS}/.uv_tools

# AWS configuration
# Ask George to send you your credentials; keep these secret always, never commit to any public repo.
# Bots crawl and find exposed credentials - it will cost you tens of thousands of dollars
# and could bork the entire lab infrastructure.
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_REGION=us-east-1

# Convenience aliases
alias cdh='cd $HOLYLABS'
alias cdn='cd $NETSCRATCH'
alias cdt='cd $TIER1'
alias cdp='cd $PROJECT_DIR'
alias cdb='cd $BUCKET_DIR'
alias cds='cd $SANDBOX_DIR'
