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
    -   [Install AWS CLI Tools](#1-install-aws-cli-tools)
    -   [Verify AWS Access](#2-verify-aws-access)
    -   [Basic S3 Operations](#3-basic-s3-operations)
    -   [Python Access (fsspec)](#4-python-access-fsspec)
    -   [Mounting S3 Buckets (rclone)](#5-mounting-s3-buckets-rclone)
-   [Quick Reference](#quick-reference)
-   [Summary](#summary)

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
    - **Time:** 3 hours
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
cd $SANDBOX_DIR/test-project
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

Let's test basic read/write operations with s5cmd:

```bash
# Create a test directory
cd $SANDBOX_DIR
mkdir s3-test && cd s3-test

# Create a test file
echo "Hello from the cluster!" > hello-world.txt

# Upload to your S3 folder
s5cmd cp hello-world.txt s3://visionlab-members/$USER/testing/

# Verify it's there
s5cmd ls s3://visionlab-members/$USER/testing/

# Download it back with a different name
s5cmd cp s3://visionlab-members/$USER/testing/hello-world.txt downloaded.txt

# Verify contents match
cat downloaded.txt
```

You should see "Hello from the cluster!" - confirming read/write access works.

### 4. Python Access (fsspec)

For Python S3 access, we use `fsspec` with the `s3fs` backend. This provides a Pythonic filesystem interface that works seamlessly with pandas, PyTorch, and other data tools.

#### Set up the test project

Initialize a uv project in your s3-test directory:

```bash
cd $SANDBOX_DIR/s3-test
uv init
uv add fsspec s3fs pandas pyarrow torch ipykernel
```

#### Open a Jupyter notebook

1. In JupyterLab, navigate to your `s3-test` directory (`$SANDBOX_DIR/s3-test`)
2. Click **File → New → Notebook**
3. Select **Python (uv auto)** as the kernel
4. The kernel will automatically use the project's `.venv` with all the packages you just installed

#### Basic fsspec usage

**Cell 1** - Set up the filesystem:

```python
import os
import fsspec

USER = os.getenv('USER')
fs = fsspec.filesystem('s3')
print(f"User: {USER}")
```

**Cell 2** - List your files in S3:

```python
fs.ls(f'visionlab-members/{USER}/testing/')
```

You should see `hello-world.txt` from step 3!

**Cell 3** - Read the file you uploaded with s5cmd:

```python
with fs.open(f's3://visionlab-members/{USER}/testing/hello-world.txt') as f:
    content = f.read()
print(content)
```

Output: `Hello from the cluster!`

**Cell 4** - Write a new file from Python:

```python
with fs.open(f's3://visionlab-members/{USER}/testing/hello-from-python.txt', 'w') as f:
    f.write('Hello from Python!')

# Verify it's there
fs.ls(f'visionlab-members/{USER}/testing/')
```

#### Works with pandas

**Cell 5** - Create sample data and save to S3:

```python
import pandas as pd
import numpy as np

# Generate sample analysis results
np.random.seed(42)
df = pd.DataFrame({
    'model': [f'model_{i}' for i in range(100)],
    'accuracy': np.random.uniform(0.7, 0.95, 100),
    'loss': np.random.uniform(0.1, 0.5, 100),
    'epoch': np.random.randint(1, 50, 100)
})
df.head()
```

**Cell 6** - Save as CSV and Parquet, compare sizes:

```python
csv_path = f's3://visionlab-members/{USER}/testing/results.csv'
parquet_path = f's3://visionlab-members/{USER}/testing/results.parquet'

# Save both formats
df.to_csv(csv_path, index=False)
df.to_parquet(parquet_path, index=False)

# Compare file sizes
csv_size = fs.size(csv_path)
parquet_size = fs.size(parquet_path)
print(f"CSV size:     {csv_size:,} bytes")
print(f"Parquet size: {parquet_size:,} bytes")
print(f"Parquet is {csv_size/parquet_size:.1f}x smaller!")
```

**Cell 7** - Read the files back:

```python
# Read directly from S3
df_from_csv = pd.read_csv(csv_path)
df_from_parquet = pd.read_parquet(parquet_path)

print("From CSV:")
print(df_from_csv.head(3))
print("\nFrom Parquet:")
print(df_from_parquet.head(3))
```

#### Works with PyTorch

**Cell 8** - Create and save a model:

```python
import torch
import torch.nn as nn

# Create a simple model
model = nn.Sequential(
    nn.Linear(128, 64),
    nn.ReLU(),
    nn.Linear(64, 10)
)

# Initialize with random weights
print(f"Original first weight: {model[0].weight[0, 0].item():.6f}")

# Save to S3
model_path = f's3://visionlab-members/{USER}/testing/demo_model.pt'
with fs.open(model_path, 'wb') as f:
    torch.save(model.state_dict(), f)

print(f"Model saved to {model_path}")
```

**Cell 9** - Load the model back:

```python
# Create a fresh model (random weights)
loaded_model = nn.Sequential(
    nn.Linear(128, 64),
    nn.ReLU(),
    nn.Linear(64, 10)
)
print(f"Before loading: {loaded_model[0].weight[0, 0].item():.6f}")

# Load weights from S3
with fs.open(model_path, 'rb') as f:
    loaded_model.load_state_dict(torch.load(f, weights_only=True))

print(f"After loading:  {loaded_model[0].weight[0, 0].item():.6f}")
print("Weights restored successfully!")
```

#### Summary

You now know how to read and write files to S3 from Python. **S3 is your primary storage location** - all outputs (model weights, analysis results, figures) should be saved here. Files in S3 are:

-   Backed up with 99.99% durability
-   Accessible from anywhere (cluster, laptop, Lightning AI)
-   Easy to share with collaborators

#### Quick reference

```python
import fsspec
fs = fsspec.filesystem('s3')

# List files
fs.ls(f'visionlab-members/{USER}/path/')

# Check if file exists
fs.exists(f'visionlab-members/{USER}/path/file.pt')

# Get file size
fs.size(f'visionlab-members/{USER}/path/file.pt')

# Delete a file
fs.rm(f's3://visionlab-members/{USER}/path/file.pt')

# Read/write text
with fs.open('s3://...', 'r') as f: text = f.read()
with fs.open('s3://...', 'w') as f: f.write(text)

# Read/write binary (models, pickles)
with fs.open('s3://...', 'rb') as f: data = f.read()
with fs.open('s3://...', 'wb') as f: f.write(data)
```

#### Save and close

1. **Save the notebook:** File → Rename Notebook → `s3_test.ipynb`
2. **Stop the kernel:** Kernel → Shut Down Kernel (frees up memory)

You can keep this project in your Sandbox for reference, or remove it:

```bash
rm -rf $SANDBOX_DIR/s3-test
```

### 5. Mounting S3 Buckets (rclone)

If you prefer filesystem-like access to S3 (treating an s3 bucket like a "mounted local file system"), we use rclone FUSE mounts. This creates a local directory that transparently reads/writes to S3.

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

Verify rclone can access your buckets by listing directories (`lsd`) at the remote root:

```bash
rclone lsd s3_remote:
```

You should see `visionlab-members`, `visionlab-datasets`, and any other buckets you have access to.

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

#### Clean up zombie mounts

If mounts get orphaned (job crashed, forgot to unmount), use the sweep script:

```bash
cd $BUCKET_DIR

# Report orphaned mounts on this node
./s3_zombie_sweep.sh report

# Fix orphaned mounts
./s3_zombie_sweep.sh fix
```

#### When to use mounted buckets

Mount S3 buckets when your code expects local file paths and can't easily be modified to use fsspec. Common cases:

-   Training frameworks that read data from disk
-   Legacy code that uses `open()` or `os.path` functions
-   Tools that don't support S3 URLs directly

For new code, prefer **fsspec** (section 4) - it's simpler and doesn't require mount/unmount management.

#### Best practices

-   **Mounts auto-cleanup when jobs end** - the `/tmp` mount location ensures cleanup when the node releases
-   **Use the sweep script** if you see stale mounts or "transport endpoint not connected" errors
-   **One mount per bucket per job** - the scripts handle this automatically

---

## Quick Reference

### Environment Variables

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

### Home Directory Symlinks

Summary of symlinks set up in [Initial Setup](#4-set-up-home-directory-symlinks):

| Directory      | Points to                      | Purpose                              |
| -------------- | ------------------------------ | ------------------------------------ |
| `~/.cache`     | `$MY_NETSCRATCH/.cache`        | App caches (pip, huggingface, torch) |
| `~/.lightning` | `$MY_NETSCRATCH/.lightning`    | StreamingDataset chunks (litdata)    |
| `~/.conda`     | Tier1 `/Users/$USER/.conda`    | Conda environments (if using conda)  |

Kept in home: `~/.ssh`, `~/.config`, `~/.bashrc`, `~/.jupyter`, `~/.nv`, `~/.triton` (small or critical)

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

## Summary

You've now configured your Harvard cluster environment. Here's what you set up:

**Storage architecture:**

-   **Home directory (`~/`)** - Your small login node home (100GB limit). We set up symlinks so large caches don't fill it up.
-   **Holylabs (`$MY_WORK_DIR`)** - Your working directory for code and projects. This is where your git repos and uv environments live.
-   **Netscratch (`$MY_NETSCRATCH`)** - Fast, ephemeral storage for temporary files and caches. Cleaned monthly - don't store anything irreplaceable here.
-   **S3 buckets** - Cloud storage for all outputs (model weights, results, figures). Accessible from anywhere, backed up, and easy to share.

**Environment management:**

-   **uv** is your Python environment manager (not conda). It's fast, creates reproducible lockfiles, and uses hardlinks for efficient disk usage.
-   Each project gets its own `.venv` with dependencies tracked in `pyproject.toml` and `uv.lock`.

**Workflow:**

1.  Log in via JupyterLab at [vdi.rc.fas.harvard.edu](https://vdi.rc.fas.harvard.edu)
2.  Work in `$PROJECT_DIR` for code, `$SANDBOX_DIR` for experiments
3.  Save all outputs to S3 (`s3://visionlab-members/$USER/...`)
4.  Use `uv run` to execute code in your project's environment

**Next steps:** See [SLURM Basics](slurm-basics.md) for submitting batch jobs to the cluster.
