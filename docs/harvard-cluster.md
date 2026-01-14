# Harvard Cluster Setup Guide

This guide covers setting up your computing environment on the Harvard FASRC cluster.

## Storage Overview

The cluster has several storage tiers with different characteristics:

| Storage    | Path                                    | Characteristics                                          | Use for                                       |
| ---------- | --------------------------------------- | -------------------------------------------------------- | --------------------------------------------- |
| Home       | `~/`                                    | 100GB limit, persistent, your home, mounted every job    | Config files, symlinks                        |
| Tier1      | `/n/alvarez_lab_tier1/Users/$USER/`     | Expensive, limited (~TB), performant, persistent         | Use for big datasets, caches, not "outputs"   |
| Holylabs   | `/n/holylabs/LABS/${LAB}/Users/$USER/`  | Less performant, inexpensive, persistent                 | Project repos (code), uv cache, not "outputs" |
| Netscratch | `/n/netscratch/${LAB}/Lab/Users/$USER/` | Free, large, performant, **ephemeral** (monthly cleanup) | Temporary scratch, large intermediate files   |
| AWS        | cloud storage "s3 buckets"              | Affordable, very large, backed-up (aws 99.99%)           | All outputs (model weights, analysis results) |

**Warning:** Files on netscratch are automatically deleted during monthly cleanup. Never store anything there that you can't regenerate.

## Initial Setup

### 1. Configure Your Shell

Add the following to your `~/.bashrc`. Open it with your preferred editor:

```bash
nano ~/.bashrc  # or vim, emacs, etc.
```

Add these lines at the end:

```bash
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
# ask George to send you your credentials; keep these secret always, never commit these to any public repo
# bots will craw; and find these credentials, so if you make them publically accessible, it will cost you
# potentially tens of thousands of dollars, and could bork the entire lab infrastructure
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_REGION=us-east-1
```

Save and reload:

```bash
source ~/.bashrc
```

**Note on shared uv cache:** The `UV_CACHE_DIR` points to a shared lab directory. When you install a package, it benefits everyone - subsequent installs are near-instant via hardlinks. The directory should already exist with proper permissions. If not, ask George to create it:
```bash
mkdir -p /n/holylabs/LABS/alvarez_lab/Lab/.uv_cache
chmod 2775 /n/holylabs/LABS/alvarez_lab/Lab/.uv_cache
```

**What each variable does:**

| Variable                | Purpose                                           |
| ----------------------- | ------------------------------------------------- |
| `LAB`                   | Your lab affiliation, used in storage paths       |
| `HOLYLABS`              | Root of your holylabs directory                   |
| `NETSCRATCH`            | Your netscratch directory (temp files, ephemeral) |
| `TIER1`                 | Your tier1 directory (large datasets, persistent) |
| `PROJECT_DIR`           | Where your git repos live                         |
| `BUCKET_DIR`            | Where S3 buckets are mounted                      |
| `SANDBOX_DIR`           | For testing and scratch work                      |
| `UV_CACHE_DIR`          | Shared lab cache for uv packages                  |
| `UV_TOOL_DIR`           | Your uv tools directory (CLI tools like s5cmd)    |
| `AWS_ACCESS_KEY_ID`     | Your AWS access key (get from George)             |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key (get from George)             |
| `AWS_REGION`            | AWS region (us-east-1)                            |

### 2. Create Holylabs Folder Structure

Set up the recommended folder organization:

```bash
mkdir -p $HOLYLABS/{Projects,Buckets,Sandbox}
```

| Folder      | Purpose                                                                                 |
| ----------- | --------------------------------------------------------------------------------------- |
| `Projects/` | Git repositories. All code should be version controlled and regularly pushed to GitHub. |
| `Buckets/`  | S3 bucket mounts (see AWS setup section). All outputs should be stored in s3 buckets.   |
| `Sandbox/`  | Testing, experiments, organize however you like.                                        |

### 3. Set Up Home Directory Symlinks

Your home directory has a 100GB quota. Many applications create large hidden cache directories that can quickly fill this up. We symlink these to netscratch (ephemeral caches) or tier1 (persistent environments).

First, create your netscratch user directory if it doesn't exist:

```bash
mkdir -p /n/netscratch/${LAB}/Lab/Users/$USER
```

#### ~/.cache → netscratch

General caches (pip, huggingface models, torch hub, etc.). Safe to delete - everything will re-download as needed.

```bash
# Remove existing cache (will regenerate as needed)
rm -rf ~/.cache

# Create symlink
mkdir -p /n/netscratch/${LAB}/Lab/Users/$USER/.cache
ln -s /n/netscratch/${LAB}/Lab/Users/$USER/.cache ~/.cache
```

#### ~/.conda → tier1 (if using conda)

**Important:** Conda environments have hardcoded paths and **cannot be moved**. If you try to move them, they will break. You must delete and rebuild.

If you're new to the cluster, we recommend using **uv** instead of conda - it's faster, more reproducible, and doesn't have this problem. See the [Python Environment Setup](#python-environment-setup-with-uv) section.

If you're an existing conda user and want to set up the symlink:

```bash
# Check what conda environments you have
conda env list

# If you have environments you need, export them first:
# conda env export -n myenv > myenv.yml

# Remove conda directory (this deletes all environments!)
rm -rf ~/.conda

# Create symlink to tier1
mkdir -p /n/alvarez_lab_tier1/Users/$USER/.conda
ln -s /n/alvarez_lab_tier1/Users/$USER/.conda ~/.conda

# Recreate environments from exported files:
# conda env create -f myenv.yml
```

Skip this step if you don't use conda or plan to switch to uv.

#### Verify symlinks

```bash
ls -la ~/.cache
# If using conda:
ls -la ~/.conda
```

You should see arrows (`->`) pointing to the target locations.

#### What about ~/.nv and ~/.triton?

These CUDA/Triton compiler caches are small (typically < 1 GB combined) but expensive to rebuild. We recommend **keeping them in home** rather than symlinking to netscratch. The monthly cleanup would force recompilation, which can add minutes to your first job after cleanup. The home quota savings aren't worth the annoyance.

### 4. Verify Storage Access

Run these commands to confirm you have access to the required storage locations:

```bash
# Check home directory usage
echo "Home: $(du -sh ~ 2>/dev/null | cut -f1) used of 100GB"

# Check tier1 access
ls -la /n/alvarez_lab_tier1/Users/$USER/ && echo "Tier1 access OK" || echo "No tier1 access"

# Check holylabs access
ls -la /n/holylabs/LABS/${LAB}/Users/$USER/ && echo "Holylabs access OK" || echo "No holylabs access"

# Check netscratch access (may need to create your directory)
ls -la /n/netscratch/${LAB}/Lab/Users/$USER/ 2>/dev/null && echo "Netscratch access OK" || echo "Netscratch directory doesn't exist yet"
```

If your netscratch user directory doesn't exist, create it:

```bash
mkdir -p /n/netscratch/${LAB}/Lab/Users/$USER
```

If you don't have access to tier1 or holylabs, contact the lab administrator.

---

## Python Environment Setup with uv

We use [uv](https://docs.astral.sh/uv/) for Python environment management. It's faster than conda/pip and creates reproducible environments via lockfiles.

### 1. Install uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Restart your shell or run:

```bash
source ~/.local/bin/env
```

Verify installation:

```bash
uv --version
```

### 2. Configure uv Cache

If you ran the bashrc setup above, `UV_CACHE_DIR` is already configured. Verify:

```bash
echo $UV_CACHE_DIR
# Should show: /n/holylabs/LABS/<your_lab>/Users/<you>/.uv_cache
```

**Why holylabs?** The uv cache and your project virtual environments will both live on holylabs. This allows uv to use hardlinks instead of copying files, which means:

-   Near-instant package installation after the first download
-   Multiple projects sharing the same packages use almost no extra disk space

### 3. Create a Test Project

Let's create a test project to verify everything works:

```bash
cd $SANDBOX_DIR
mkdir test-project && cd test-project
uv init
```

Now add some packages. The first time you install a package, uv downloads it to the cache:

```bash
time uv add numpy torch
```

This may take a minute or two depending on your connection (torch is large).

The project will contain:

-   `pyproject.toml` — project metadata and dependencies
-   `uv.lock` — exact versions for reproducibility
-   `.venv/` — the virtual environment

### 4. Verify Cache Works (Hardlinks)

Create a second project with the same dependencies to see the cache in action:

```bash
cd $SANDBOX_DIR
mkdir test-project-2 && cd test-project-2
uv init
time uv add numpy torch
```

This should complete in **seconds** (not minutes) because uv hardlinks from the cache instead of downloading.

Verify the disk space savings:

```bash
# Check apparent size vs actual disk usage
du -sh $SANDBOX_DIR/test-project/.venv
du -sh $SANDBOX_DIR/test-project-2/.venv

# Both show ~2GB, but actual disk usage is shared!
# Check with --apparent-size to see the difference:
du -sh --apparent-size $SANDBOX_DIR/test-project/.venv
```

Clean up the test projects when done:

```bash
rm -rf $SANDBOX_DIR/test-project $SANDBOX_DIR/test-project-2
```

### 5. Running Code

```bash
# Run a script
uv run python my_script.py

# Run an interactive Python session
uv run python

# Add a new package
uv add scipy
```

---

## Jupyter Setup

To use your uv environments in Jupyter notebooks (e.g., on Open OnDemand), you need to install a kernel spec and add ipykernel to your projects.

### 1. Install the uv Kernel Spec

Run this once to install a "Python (uv auto)" kernel that automatically detects your project's environment:

```bash
mkdir -p ~/.local/share/jupyter/kernels/python-uv

cat > ~/.local/share/jupyter/kernels/python-uv/kernel.json << 'EOF'
{
  "argv": [
    "bash",
    "-c",
    "source ~/.bashrc && exec uv run python -m ipykernel -f {connection_file}"
  ],
  "display_name": "Python (uv auto)",
  "language": "python"
}
EOF
```

Verify installation:

```bash
jupyter kernelspec list
```

### 2. Add ipykernel to Your Projects

For any project where you want Jupyter support:

```bash
cd /path/to/your/project
uv add ipykernel
```

### 3. Using the Kernel

1. Open a notebook in Jupyter (e.g., via Open OnDemand)
2. Navigate to or create a notebook inside your project directory
3. Select "Python (uv auto)" as the kernel
4. The kernel will automatically use the project's `.venv`

**How it works:** The kernel runs `uv run`, which searches upward from the notebook's location to find a `pyproject.toml`. It then activates that project's environment.

---

## AWS and S3 Buckets

All lab outputs (model weights, analysis results, figures) should be stored in S3 buckets. This provides:
- Reliable cloud backup (AWS 99.99% durability)
- Access from anywhere (cluster, laptops, Lightning AI, workstations)
- Easy sharing within and outside the lab

### 1. Install AWS CLI Tools

**AWS CLI v2** (recommended - more features, actively developed):

AWS CLI v2 is distributed as a standalone binary, not a Python package, so we install it directly:

```bash
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
./aws/install -i $HOLYLABS/.aws-cli -b $HOME/.local/bin --update
```

This installs the CLI to holylabs (saves home quota) and creates symlinks in `~/.local/bin`.

**s5cmd** (fast parallel S3 operations):

```bash
uv tool install s5cmd
```

Verify both are installed:

```bash
# Clear bash's command cache if you had old versions
hash -r

aws --version   # Should show v2.x
s5cmd version   # Should show v2.x
```

### 2. Verify AWS Access

Test your credentials (you should have set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in your bashrc):

```bash
# List buckets you have access to
aws s3 ls
```

You should see at least:
- `visionlab-members` - Shared lab bucket for outputs
- `visionlab-datasets` - Common datasets

List contents of a bucket:

```bash
# Using aws cli
aws s3 ls s3://visionlab-members/

# Using s5cmd (faster for large listings)
s5cmd ls s3://visionlab-members/
```

### 3. Basic S3 Operations

**Copy files to/from S3:**

```bash
# Upload a file
aws s3 cp local_file.pt s3://visionlab-members/$USER/models/

# Download a file
aws s3 cp s3://visionlab-members/$USER/models/model.pt ./

# Sync a directory (only copies changed files)
aws s3 sync ./results s3://visionlab-members/$USER/experiment1/results/
```

**Using s5cmd (faster for bulk operations):**

```bash
# Copy with parallelism
s5cmd cp local_file.pt s3://visionlab-members/$USER/models/

# Sync directory
s5cmd sync ./results s3://visionlab-members/$USER/experiment1/results/
```

### 4. Python Access (fsspec)

For Python S3 access, we use `fsspec` with the `s3fs` backend. This provides a Pythonic filesystem interface that works seamlessly with pandas, xarray, and other data tools.

**Note:** Don't install `boto3` alongside `s3fs` - they have conflicting dependencies. Use `s3fs` for Python access and the AWS CLI for shell operations.

Create a test project:

```bash
cd $SANDBOX_DIR
mkdir s3-test && cd s3-test
uv init
uv add fsspec s3fs ipykernel
```

**Basic fsspec usage:**

```python
import os
import fsspec

USER = os.getenv('USER')

# Create S3 filesystem
fs = fsspec.filesystem('s3')

# List bucket contents
fs.ls('visionlab-members')

# Write a file
with fs.open(f's3://visionlab-members/{USER}/testing123/test.txt', 'w') as f:
    f.write('Hello from Python!')

# Read a file directly
with fs.open(f's3://visionlab-members/{USER}/testing123/test.txt') as f:
    data = f.read()
print(data)
```

**Verify permissions:**

```python
# List your files (should work)
fs.ls(f'visionlab-members/{USER}/')

# List another user's files (should error - no permission)
fs.ls('visionlab-members/someotheruser/')
```

Each user can only read/write within their own directory in `visionlab-members`.

**Works with pandas:**

```python
import pandas as pd

# Read directly from S3
df = pd.read_csv('s3://visionlab-members/path/to/data.csv')
df = pd.read_parquet('s3://visionlab-members/path/to/data.parquet')

# Write directly to S3
df.to_parquet('s3://visionlab-members/myuser/output.parquet')
```

**Works with PyTorch:**

```python
import torch
import fsspec

# Save model to S3
with fsspec.open('s3://visionlab-members/myuser/model.pt', 'wb') as f:
    torch.save(model.state_dict(), f)

# Load model from S3
with fsspec.open('s3://visionlab-members/myuser/model.pt', 'rb') as f:
    model.load_state_dict(torch.load(f))
```

Clean up test project:

```bash
rm -rf $SANDBOX_DIR/s3-test
```

### 5. Mounting S3 Buckets (rclone)

For workflows that need filesystem-like access to S3 (e.g., training code that expects local paths), we use rclone FUSE mounts. This creates a local directory that transparently reads/writes to S3.

#### One-time rclone setup

Install rclone and create the config:

```bash
# Install rclone (if not already available)
# On the cluster, rclone may be available via module or already installed

# Create rclone config
mkdir -p ~/.config/rclone

cat > ~/.config/rclone/rclone.conf << 'EOF'
[s3_remote]
type = s3
provider = AWS
env_auth = true
region = us-east-1
EOF
```

Test rclone can access your buckets:

```bash
rclone lsd s3_remote:
```

#### Download mount scripts

Copy the bucket mounting scripts to your Buckets directory:

```bash
cd $BUCKET_DIR

# Download scripts
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup/main/scripts/s3_bucket_mount.sh
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup/main/scripts/s3_bucket_unmount.sh
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup/main/scripts/s3_zombie_sweep.sh

chmod +x s3_bucket_*.sh s3_zombie_sweep.sh
```

#### Mount a bucket

```bash
cd $BUCKET_DIR

# Mount visionlab-members bucket
./s3_bucket_mount.sh . visionlab-members

# Now you can access it like a local directory
ls visionlab-members/
```

The script:
1. Creates a node-local mount at `/tmp/$USER/rclone/<hostname>/<job_id>/<bucket>`
2. Creates a symlink from `$BUCKET_DIR/<bucket>` to the mount
3. Works with SLURM jobs (each job gets isolated mounts)

#### Unmount a bucket

```bash
cd $BUCKET_DIR
./s3_bucket_unmount.sh . visionlab-members
```

**Important:** Always unmount before your SLURM job ends to ensure writes are flushed to S3.

#### Clean up zombie mounts

If mounts get orphaned (job crashed, forgot to unmount), use the sweep script:

```bash
cd $BUCKET_DIR

# Report orphaned mounts on this node
./s3_zombie_sweep.sh report

# Fix orphaned mounts
./s3_zombie_sweep.sh fix
```

---

## Home Directory Symlinks

Summary of symlinks set up in [Initial Setup](#2-set-up-home-directory-symlinks):

### Symlinked to Netscratch (ephemeral, ok to lose)

| Directory  | Purpose                                             | Typical size |
| ---------- | --------------------------------------------------- | ------------ |
| `~/.cache` | General application caches (pip, huggingface, etc.) | 10-100+ GB   |

### Symlinked to Tier1 (persistent)

| Directory  | Purpose                             | Why persistent                     |
| ---------- | ----------------------------------- | ---------------------------------- |
| `~/.conda` | Conda environments (if using conda) | Environments take time to recreate |

### Left in Home (small, worth keeping)

| Directory                 | Purpose                            | Notes                               |
| ------------------------- | ---------------------------------- | ----------------------------------- |
| `~/.ssh`                  | SSH keys                           | Critical, keep secure               |
| `~/.config`               | Application configs                | Small                               |
| `~/.bashrc`, `~/.profile` | Shell config                       | Small                               |
| `~/.jupyter`              | Jupyter config                     | Small                               |
| `~/.nv`                   | NVIDIA/CUDA compilation cache      | Small, expensive to rebuild         |
| `~/.triton`               | Triton GPU compiler cache          | Small, expensive to rebuild         |

---

## Quick Reference

### Common uv Commands

```bash
uv init                    # Initialize a new project
uv add <package>           # Add a dependency
uv add <package>==1.2.3    # Add a specific version
uv remove <package>        # Remove a dependency
uv sync                    # Install all dependencies from lockfile
uv run <command>           # Run a command in the environment
uv lock                    # Update the lockfile
uv cache prune             # Clean up old cached packages
```

### Standard Environment Variables

```bash
$LAB                    # Your lab: alvarez_lab or konkle_lab
$HOLYLABS               # /n/holylabs/LABS/${LAB}/Users/$USER
$NETSCRATCH             # /n/netscratch/${LAB}/Lab/Users/$USER
$TIER1                  # /n/alvarez_lab_tier1/Users/$USER
$PROJECT_DIR            # ${HOLYLABS}/Projects
$BUCKET_DIR             # ${HOLYLABS}/Buckets
$SANDBOX_DIR            # ${HOLYLABS}/Sandbox
$UV_CACHE_DIR           # Shared: /n/holylabs/LABS/alvarez_lab/Lab/.uv_cache
$UV_TOOL_DIR            # ${HOLYLABS}/.uv_tools
$AWS_ACCESS_KEY_ID      # Your AWS access key (keep secret!)
$AWS_SECRET_ACCESS_KEY  # Your AWS secret key (keep secret!)
$AWS_REGION             # us-east-1
```

### Convenience Aliases

```bash
cdh   # cd to holylabs
cdn   # cd to netscratch
cdt   # cd to tier1
cdp   # cd to projects
cdb   # cd to buckets
cds   # cd to sandbox
```

### Sharing Projects

When sharing a project (e.g., via git), include:

-   `pyproject.toml`
-   `uv.lock`

Do **not** include:

-   `.venv/` (add to `.gitignore`)

Others can recreate your exact environment with:

```bash
git clone <repo>
cd <repo>
uv sync
```

---

## Troubleshooting

### "No kernel" when selecting Python (uv auto)

Make sure ipykernel is installed in the project:

```bash
cd /path/to/your/project
uv add ipykernel
```

### Package installation is slow

If uv is copying files instead of hardlinking, check that:

1. `UV_CACHE_DIR` is set to a path on holylabs
2. Your project is also on holylabs
3. You haven't set `UV_LINK_MODE=copy`

### Building from source

If you see "Building <package>..." and it takes a long time, that package doesn't have a pre-built wheel for your Python version/platform. Either:

-   Use a different version of the package that has wheels
-   Use a different Python version
-   Wait for the build to complete (one-time cost, cached afterward)

### Home directory quota exceeded

Check what's using space:

```bash
du -sh ~/.* 2>/dev/null | sort -h
```

Common culprits: `.cache`, `.conda`, `.local`. See [Home Directory Symlinks](#home-directory-symlinks) for the fix.
