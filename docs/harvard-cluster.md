# Harvard Cluster Setup Guide

This guide covers setting up your computing environment on the Harvard FASRC cluster.

## Table of Contents

-   [Getting Started](#getting-started)
-   [Storage Overview](#storage-overview)
-   [Initial Setup](#initial-setup)
    -   [Configure Your Shell](#1-configure-your-shell)
    -   [Verify Storage Access](#2-verify-storage-access)
    -   [Create Holylabs Folder Structure](#3-create-holylabs-folder-structure)
    -   [Set Up Home Directory Symlinks](#4-set-up-home-directory-symlinks)
-   [Python Environment Setup with uv](#python-environment-setup-with-uv)
    -   [Install uv](#1-install-uv)
    -   [Configure uv Cache](#2-configure-uv-cache)
    -   [Create a Test Project](#3-create-a-test-project)
    -   [Verify Hardlinks Work](#4-verify-hardlinks-work)
    -   [Jupyter Setup](#5-jupyter-setup)
    -   [Clean Up Test Projects](#6-clean-up-test-projects)
-   [AWS and S3 Buckets](#aws-and-s3-buckets)
-   [SLURM Basics](#slurm-basics)
-   [Home Directory Symlinks](#home-directory-symlinks)
-   [Quick Reference](#quick-reference)
-   [Troubleshooting](#troubleshooting)

## Getting Started

**New to the cluster?** If you haven't set up your FASRC account yet, see [Getting onto the Harvard FASRC Cluster](getting-cluster-access.md) first.

**Ready to configure?** Start an interactive JupyterLab session:

1. Go to [https://vdi.rc.fas.harvard.edu/](https://vdi.rc.fas.harvard.edu/)
2. Log in with your Harvard credentials
3. Select **Jupyter Lab** from the available applications
4. Configure the session:
    - **Partition:** `test` (no GPU needed for setup) or `gpu_test` (if you want to verify GPU access)
    - **CPUs:** 4
    - **Memory:** 16 GB
    - **Time:** 1 hour (max for test partitions)
5. Launch and wait for the session to start
6. Open a **Terminal** from the JupyterLab launcher

You'll run all the setup commands below in this terminal.

---

## Storage Overview

The cluster has several storage tiers with different characteristics:

| Storage    | Path                                   | Characteristics                                          | Use for                                       |
| ---------- | -------------------------------------- | -------------------------------------------------------- | --------------------------------------------- |
| Home       | `~/`                                   | Your home, mounted every job, 100GB limit, persistent    | Config files, symlinks                        |
| Holylabs   | `/n/holylabs/LABS/${LAB}/Users/$USER/` | Less performant, inexpensive, persistent                 | Project repos (code), uv cache, not "outputs" |
| Netscratch | `/n/netscratch/${LAB}/Everyone/$USER/` | Free, large, performant, **ephemeral** (monthly cleanup) | Temporary scratch, large intermediate files   |
| Tier1      | `/n/alvarez_lab_tier1/Users/$USER/`    | Expensive, limited (~8TB), performant, persistent        | Use for big datasets, caches, not "outputs"   |
| AWS        | cloud storage "s3 buckets"             | Affordable, very large, backed-up (aws 99.99%)           | All outputs (model weights, analysis results) |

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
export MY_WORK_DIR=/n/holylabs/LABS/${LAB}/Users/$USER
export MY_NETSCRATCH=/n/netscratch/${LAB}/Everyone/$USER
export TIER1=/n/alvarez_lab_tier1/Lab/

# Holylabs folder structure
export PROJECT_DIR=${MY_WORK_DIR}/Projects    # Git repos go here
export BUCKET_DIR=${MY_WORK_DIR}/Buckets      # S3 bucket mounts
export SANDBOX_DIR=${MY_WORK_DIR}/Sandbox     # Testing/scratch

# uv (Python package manager) configuration
# Cache on holylabs enables hardlinks for fast installs
export UV_CACHE_DIR=${MY_WORK_DIR}/.uv_cache
export UV_TOOL_DIR=${MY_WORK_DIR}/.uv_tools

# AWS configuration
# ask George to send you your credentials; keep these secret always, never commit these to any public repo
# bots will craw; and find these credentials, so if you make them publically accessible, it will cost you
# potentially tens of thousands of dollars, and could bork the entire lab infrastructure
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_REGION=us-east-1

# Default working directory for interactive shells (e.g., Jupyter terminals)
if [[ $- == *i* ]]; then
    if [[ -n "${MY_WORK_DIR}" && -d "${MY_WORK_DIR}" ]]; then
        cd "${MY_WORK_DIR}"
    else
        cd "$HOME"
    fi
fi
```

Save and exit nano: `Ctrl+X`, then `Y` to confirm save, then `Enter` to confirm filename.

Reload your shell configuration:

```bash
source ~/.bashrc
```

**What each variable does:**

| Variable                | Purpose                                             |
| ----------------------- | --------------------------------------------------- |
| `LAB`                   | Your lab affiliation, used in storage paths         |
| `MY_WORK_DIR`           | Your holylabs directory working directory           |
| `MY_NETSCRATCH`         | Your netscratch directory (temp files, ephemeral)   |
| `TIER1`                 | Lab tier1 directory (large datasets, persistent)    |
| `PROJECT_DIR`           | Where your git repos live                           |
| `BUCKET_DIR`            | Where S3 buckets are mounted                        |
| `SANDBOX_DIR`           | For testing and scratch work                        |
| `UV_CACHE_DIR`          | Your uv package cache (holylabs, enables hardlinks) |
| `UV_TOOL_DIR`           | Your uv tools directory (CLI tools like s5cmd)      |
| `AWS_ACCESS_KEY_ID`     | Your AWS access key (get from George)               |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key (get from George)               |
| `AWS_REGION`            | AWS region (us-east-1)                              |

### 2. Verify Storage Access

Run these commands to confirm you have access to the required storage locations:

```bash

# Check holylabs access
ls -la $MY_WORK_DIR/ && echo "✅ Holylabs access OK" || echo "🚫 No holylabs access"

# Check netscratch access (may need to create your directory)
ls -la $MY_NETSCRATCH/ 2>/dev/null && echo "✅ Netscratch access OK" || echo "🚫 Netscratch directory doesn't exist yet"

# Check tier1 access
ls -la $TIER1/ && echo "Tier1 access OK" || echo "🚫 No tier1 access"

# Check home directory usage (could take a couple of minutes)
echo "Home: $(du -sh ~ 2>/dev/null | cut -f1) used of 100GB"

```

If your netscratch user directory doesn't exist, create it:

```bash
mkdir -p $MY_NETSCRATCH
```

If you don't have access to tier1 or holylabs, contact the lab administrator.

### 3. Create Holylabs Folder Structure

Set up the recommended folder organization:

```bash
mkdir -p $MY_WORK_DIR/{Projects,Buckets,Sandbox}
```

| Folder      | Purpose                                                                                 |
| ----------- | --------------------------------------------------------------------------------------- |
| `Projects/` | Git repositories. All code should be version controlled and regularly pushed to GitHub. |
| `Buckets/`  | S3 bucket mounts (see AWS setup section). All outputs should be stored in s3 buckets.   |
| `Sandbox/`  | Testing, experiments, organize however you like.                                        |

Most of the time, the first thing you do when you connect to a node, or open a terminal, is cd to your $PROJECT_DIR

```
cd $PROJECT_DIR
```

And when you start jupyterlab interactive sessions, you can even set your "Working Directory" to your "MY_WORK_DIR"

```
/n/holylabs/LABS/<your-lab-here>/Users/<your-username-here>
```

e.g.

```
/n/holylabs/LABS/alvarez_lab/Users/alvarez
```

### 4. Set Up Home Directory Symlinks

Your home directory has a 100GB quota. Many applications create large hidden cache directories that can quickly fill this up. We symlink these to netscratch (ephemeral caches) or tier1 (persistent environments).

First, create your netscratch user directory if it doesn't exist:

```bash
mkdir -p $MY_NETSCRATCH
```

#### ~/.cache → netscratch

General caches (pip, huggingface models, torch hub, etc.). Safe to delete - everything will re-download as needed.

```bash
# Remove existing cache (will regenerate as needed)
rm -rf ~/.cache

# Create symlink
mkdir -p $MY_NETSCRATCH/.cache
ln -s $MY_NETSCRATCH/.cache ~/.cache
```

#### ~/.conda → tier1 (if using conda)

**Important:** Conda environments have hardcoded paths and **cannot be moved**. If you try to move them, they will break. You must delete and rebuild.

If you're new to the cluster, we recommend using **uv** instead of conda - it's faster, more reproducible, and doesn't have this problem.

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

#### ~/.lightning → netscratch

Lightning AI's `litdata` library caches StreamingDataset chunks here.

```bash
# Remove existing lightning directory
rm -rf ~/.lightning

# Create symlink to your netscratch
mkdir -p $MY_NETSCRATCH/.lightning
ln -s $MY_NETSCRATCH/.lightning ~/.lightning
```

#### Verify symlinks

```bash
ls -la ~/.cache ~/.lightning
# If using conda:
ls -la ~/.conda
```

You should see arrows (`->`) pointing to the target locations.

#### What about ~/.nv and ~/.triton?

These CUDA/Triton compiler caches are small (typically < 1 GB combined) but expensive to rebuild. We recommend **keeping them in home** rather than symlinking to netscratch. The monthly cleanup would force recompilation, which can add minutes to your first job after cleanup. The home quota savings aren't worth the annoyance.

## Python Environment Setup with uv

We use [uv](https://docs.astral.sh/uv/) for Python environment management. It's faster than conda/pip and creates reproducible environments via lockfiles.

### 1. Install uv

Run the following in your terminal (from any location, it doesn't matter what location you start from)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Check uv version

```bash
uv --version
```

### 2. Configure uv Cache

If you ran the bashrc setup above, `UV_CACHE_DIR` is already configured. Verify:

```bash
echo $UV_CACHE_DIR
# Should show: /n/holylabs/LABS/<your-lab>/Users/<your-username>/.uv_cache
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

Now add some packages:

```bash
time uv add numpy torch ipykernel
```

The first time you install, it may take a minute or two to download (torch is large). Subsequent installs will be **fast** (seconds) thanks to the cache.

The project will contain:

-   `pyproject.toml` — project metadata and dependencies
-   `uv.lock` — exact versions for reproducibility
-   `.venv/` — the virtual environment

### 4. Verify Hardlinks Work

Create a second project with the same dependencies to verify hardlinks:

```bash
cd $SANDBOX_DIR
mkdir test-project-2 && cd test-project-2
uv init
time uv add numpy torch ipykernel
```

This should be much faster because uv hardlinks from the cache instead of re-downloading.

Verify hardlinks are working by comparing disk usage:

```bash
du -h --max-depth=1 $SANDBOX_DIR/test-project*
```

You should see something like:

```
6.6G    test-project
1.8M    test-project-2
```

The second project uses almost no additional disk space because packages are hardlinked from the cache. The ~2MB is just metadata (venv config, script wrappers, etc.).

### 5. Jupyter Setup

To use your uv environments in Jupyter notebooks (e.g., on Open OnDemand), you need to install a kernel spec and add ipykernel to your projects.

#### Install the uv Kernel Spec

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

Verify installation from your test project:

```bash
cd $SANDBOX/test-project
uv run jupyter kernelspec list
```

#### Add ipykernel to Your Projects

For any project where you want Jupyter support:

```bash
cd /path/to/your/project
uv add ipykernel
```

#### Using the Kernel

1. Open a notebook in Jupyter (e.g., via Open OnDemand)
2. Navigate to or create a notebook inside your project directory
3. Select "Python (uv auto)" as the kernel
4. The kernel will automatically use the project's `.venv`

**How it works:** The kernel runs `uv run`, which searches upward from the notebook's location to find a `pyproject.toml`. It then activates that project's environment.

### 6. Clean Up Test Projects

```bash
rm -rf $SANDBOX_DIR/test-project $SANDBOX_DIR/test-project-2
```

---

## AWS and S3 Buckets

All lab outputs (model weights, analysis results, figures) should be stored in S3 buckets. This provides:

-   Reliable cloud backup (AWS 99.99% durability)
-   Access from anywhere (cluster, laptops, Lightning AI, workstations)
-   Easy sharing within and outside the lab

### 1. Install AWS CLI Tools

**AWS CLI v2** (recommended - more features, actively developed):

AWS CLI v2 is distributed as a standalone binary, not a Python package, so we install it directly:

```bash
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
./aws/install -i $MY_WORK_DIR/.aws-cli -b $HOME/.local/bin --update
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

-   `visionlab-members` - Shared lab bucket for outputs
-   `visionlab-datasets` - Common datasets

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
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup-guide/main/scripts/s3_bucket_mount.sh
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup-guide/main/scripts/s3_bucket_unmount.sh
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup-guide/main/scripts/s3_zombie_sweep.sh

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

## SLURM Basics

SLURM (Simple Linux Utility for Resource Management) is the job scheduler on the FASRC cluster. It allocates compute resources and manages the queue of jobs.

### Key Concepts

| Term          | Description                                                                |
| ------------- | -------------------------------------------------------------------------- |
| **Job**       | A request for compute resources (CPUs, GPUs, memory, time)                 |
| **Partition** | A group of nodes with similar characteristics (e.g., `gpu`, `gpu_requeue`) |
| **Node**      | A physical server with CPUs, memory, and possibly GPUs                     |
| **Task**      | A process within a job (most jobs have one task)                           |

### Common Commands

```bash
# Submit a job
sbatch job_script.sh

# Check your jobs
squeue -u $USER

# Check all jobs on a partition
squeue -p gpu

# Cancel a job
scancel <job_id>

# Cancel all your jobs
scancel -u $USER

# View partition info
sinfo -p gpu

# View detailed job info
scontrol show job <job_id>

# Check your fairshare (priority)
sshare -u $USER
```

### Interactive Sessions

For debugging or development, request an interactive session:

```bash
# Basic interactive session (1 hour, 1 CPU)
salloc -p test -t 1:00:00 --mem=4G

# Interactive GPU session
salloc -p gpu_test -t 1:00:00 --mem=16G --gres=gpu:1

# Run a command immediately on allocated resources
srun -p gpu_test -t 1:00:00 --mem=16G --gres=gpu:1 --pty bash
```

**Tip:** Use `gpu_test` or `test` partitions for quick debugging (max 1 hour). They have higher priority for short jobs.

### Basic Job Script

Create a file called `job.sh`:

```bash
#!/bin/bash
#SBATCH --job-name=my_job           # Job name (shows in squeue)
#SBATCH --partition=gpu             # Partition (queue) to submit to
#SBATCH --nodes=1                   # Number of nodes
#SBATCH --ntasks=1                  # Number of tasks (processes)
#SBATCH --cpus-per-task=4           # CPUs per task
#SBATCH --gres=gpu:1                # Number of GPUs
#SBATCH --mem=32G                   # Memory per node
#SBATCH --time=12:00:00             # Time limit (HH:MM:SS)
#SBATCH --output=logs/%j.out        # Standard output (%j = job ID)
#SBATCH --error=logs/%j.err         # Standard error

# Create logs directory if it doesn't exist
mkdir -p logs

# Load any needed modules (if required)
# module load cuda/12.2

# Print some job info
echo "Job ID: $SLURM_JOB_ID"
echo "Running on: $(hostname)"
echo "Start time: $(date)"

# Go to project directory
cd $PROJECT_DIR/my-project

# Run your code
uv run python train.py

echo "End time: $(date)"
```

Submit with:

```bash
sbatch job.sh
```

### Common Partitions

| Partition        | GPUs       | Time Limit | Notes                                                      |
| ---------------- | ---------- | ---------- | ---------------------------------------------------------- |
| `gpu`            | A100, V100 | 7 days     | Standard GPU partition                                     |
| `gpu_requeue`    | A100, V100 | 7 days     | Lower priority, preemptible, **use for checkpointed jobs** |
| `gpu_test`       | A100, V100 | 1 hour     | Testing/debugging, high priority                           |
| `test`           | None       | 1 hour     | CPU-only testing                                           |
| `serial_requeue` | None       | 7 days     | CPU jobs, preemptible                                      |

**Recommendation:** Use `gpu_requeue` for training jobs that checkpoint regularly. You get better queue times and contribute to cluster efficiency.

### Requesting GPUs

```bash
#SBATCH --gres=gpu:1          # Any 1 GPU
#SBATCH --gres=gpu:a100:1     # Specifically 1 A100
#SBATCH --gres=gpu:2          # 2 GPUs
```

Check available GPU types:

```bash
sinfo -p gpu -o "%N %G"
```

### Job Arrays

Run many similar jobs efficiently:

```bash
#!/bin/bash
#SBATCH --job-name=sweep
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --array=0-9           # Run 10 jobs with IDs 0-9
#SBATCH --output=logs/%A_%a.out   # %A=array job ID, %a=task ID

# Each job gets a different SLURM_ARRAY_TASK_ID
cd $PROJECT_DIR/my-project
uv run python train.py --seed=$SLURM_ARRAY_TASK_ID
```

### Monitoring Jobs

```bash
# Watch your jobs update every 5 seconds
watch -n 5 'squeue -u $USER'

# Check job efficiency after completion
seff <job_id>

# See detailed job accounting
sacct -j <job_id> --format=JobID,JobName,Elapsed,MaxRSS,MaxVMSize,State
```

### Tips

1. **Always checkpoint:** Save model state periodically so you can resume if preempted or timed out
2. **Request only what you need:** Smaller resource requests get scheduled faster
3. **Use `gpu_requeue`:** For long training jobs with checkpointing
4. **Check your output:** Jobs can fail silently - always check `.err` files
5. **Clean up:** Delete old logs and temp files to stay within quotas

### Example: Training Script with S3 Mount

```bash
#!/bin/bash
#SBATCH --job-name=train_model
#SBATCH --partition=gpu_requeue
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:1
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%j.out
#SBATCH --error=logs/%j.err

mkdir -p logs

echo "Starting job $SLURM_JOB_ID on $(hostname)"

cd $PROJECT_DIR/my-project

# Mount S3 bucket for saving checkpoints
$BUCKET_DIR/s3_bucket_mount.sh $BUCKET_DIR visionlab-members

# Run training
uv run python train.py \
    --checkpoint-dir=$BUCKET_DIR/visionlab-members/$USER/checkpoints \
    --resume-from-latest

# Unmount (flushes writes to S3)
$BUCKET_DIR/s3_bucket_unmount.sh $BUCKET_DIR visionlab-members

echo "Job completed at $(date)"
```

---

## Home Directory Symlinks

Summary of symlinks set up in [Initial Setup](#2-set-up-home-directory-symlinks):

### Symlinked to Netscratch (ephemeral, ok to lose)

| Directory      | Purpose                                             | Typical size |
| -------------- | --------------------------------------------------- | ------------ |
| `~/.cache`     | General application caches (pip, huggingface, etc.) | 10-100+ GB   |
| `~/.lightning` | StreamingDataset chunks (litdata)                   | 1-50+ GB     |

### Symlinked to Tier1 (persistent)

| Directory  | Purpose                             | Why persistent                     |
| ---------- | ----------------------------------- | ---------------------------------- |
| `~/.conda` | Conda environments (if using conda) | Environments take time to recreate |

### Left in Home (small, worth keeping)

| Directory                 | Purpose                       | Notes                       |
| ------------------------- | ----------------------------- | --------------------------- |
| `~/.ssh`                  | SSH keys                      | Critical, keep secure       |
| `~/.config`               | Application configs           | Small                       |
| `~/.bashrc`, `~/.profile` | Shell config                  | Small                       |
| `~/.jupyter`              | Jupyter config                | Small                       |
| `~/.nv`                   | NVIDIA/CUDA compilation cache | Small, expensive to rebuild |
| `~/.triton`               | Triton GPU compiler cache     | Small, expensive to rebuild |

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
$MY_WORK_DIR            # /n/holylabs/LABS/${LAB}/Users/$USER
$MY_NETSCRATCH          # /n/netscratch/${LAB}/Everyone/$USER
$TIER1                  # /n/alvarez_lab_tier1/Lab/
$PROJECT_DIR            # ${MY_WORK_DIR}/Projects
$BUCKET_DIR             # ${MY_WORK_DIR}/Buckets
$SANDBOX_DIR            # ${MY_WORK_DIR}/Sandbox
$UV_CACHE_DIR           # ${MY_WORK_DIR}/.uv_cache
$UV_TOOL_DIR            # ${MY_WORK_DIR}/.uv_tools
$AWS_ACCESS_KEY_ID      # Your AWS access key (keep secret!)
$AWS_SECRET_ACCESS_KEY  # Your AWS secret key (keep secret!)
$AWS_REGION             # us-east-1
```

### Convenience Aliases

```bash
cdw   # cd to work dir (holylabs)
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
