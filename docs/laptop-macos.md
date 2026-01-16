# Laptop Setup Guide (macOS)

This guide covers setting up your local macOS laptop for Vision Lab development work.

## Table of Contents

- [Overview](#overview)
- [GitHub Setup](#github-setup)
  - [Create GitHub Account](#1-create-github-account)
  - [Install GitHub Desktop](#2-install-github-desktop)
  - [Set Up SSH Keys](#3-set-up-ssh-keys)
  - [Configure Git](#4-configure-git)
- [Essential Tools](#essential-tools)
  - [VS Code](#vs-code)
  - [Homebrew](#homebrew)
- [Directory Structure](#directory-structure)
- [Shell Configuration](#shell-configuration)
- [Python Environment Setup with uv](#python-environment-setup-with-uv)
- [AWS and S3 Access](#aws-and-s3-access)
  - [Configure AWS Credentials](#1-configure-aws-credentials)
  - [Install AWS CLI Tools](#2-install-aws-cli-tools)
  - [Verify AWS Access](#3-verify-aws-access)
- [S3 Bucket Mounting (rclone + FUSE-T)](#s3-bucket-mounting-rclone--fuse-t)
  - [Install FUSE-T](#1-install-fuse-t)
  - [Install rclone](#2-install-rclone)
  - [Configure rclone](#3-configure-rclone)
  - [Download Mount Scripts](#4-download-mount-scripts)
  - [Mount a Bucket](#5-mount-a-bucket)
  - [Unmount](#6-unmount)
  - [Clean Up Orphaned Mounts](#7-clean-up-orphaned-mounts)
- [Python S3 Access (fsspec)](#python-s3-access-fsspec)
- [Optional Tools](#optional-tools)
  - [Docker Desktop](#docker-desktop)
  - [JupyterLab Desktop](#jupyterlab-desktop)
- [Quick Reference](#quick-reference)

---

## Overview

Your laptop setup mirrors the cluster environment where possible:

| Component | Cluster | Laptop |
|-----------|---------|--------|
| Python environments | uv | uv |
| S3 access (Python) | fsspec/s3fs | fsspec/s3fs |
| S3 mounting | rclone FUSE | rclone + FUSE-T |
| AWS credentials | Environment variables | Environment variables |

This consistency means code that works on your laptop will work on the cluster (and vice versa).

---

## GitHub Setup

All lab code is stored on GitHub. You'll need an account, SSH keys for accessing private repositories, and Git configured on your machine.

### 1. Create GitHub Account

If you don't already have a GitHub account:

1. Go to https://github.com/join
2. Create an account (use your personal email or Harvard email)
3. Ask George to add you to the [harvard-visionlab](https://github.com/harvard-visionlab) organization

### 2. Install GitHub Desktop

GitHub Desktop provides a visual interface for Git operations. Even if you prefer the command line, it's useful for visualizing changes and resolving merge conflicts.

Download and install from: https://desktop.github.com/

After installation:
1. Open GitHub Desktop
2. Sign in with your GitHub account
3. It will prompt you to configure Git (name and email) - do this in the next step

### 3. Set Up SSH Keys

SSH keys let you access private repositories without entering your password each time.

**Check for existing keys:**

```bash
ls -la ~/.ssh
```

If you see `id_ed25519` and `id_ed25519.pub` (or `id_rsa` and `id_rsa.pub`), you already have keys. Skip to "Add key to GitHub" below.

**Generate a new SSH key:**

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

Press Enter to accept the default file location. When prompted for a passphrase, just press Enter (not required, ok to leave empty).

**Start the SSH agent and add your key:**

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

**Add key to GitHub (on the website, not the desktop app):**

1. Copy your public key:
   ```bash
   pbcopy < ~/.ssh/id_ed25519.pub
   ```
2. Open https://github.com/settings/keys in your browser
3. Click "New SSH key"
4. Give it a title (e.g., "MacBook Pro") and paste the key
5. Click "Add SSH key"

**Test the connection:**

```bash
ssh -T git@github.com
```

The first time you connect, you'll see a message like this (don't panic, this is normal!):

```
The authenticity of host 'github.com (140.82.114.3)' can't be established.
ED25519 key fingerprint is SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press Enter. You should then see:

```
Hi tkonkle! You've successfully authenticated, but GitHub does not provide shell access.
```

This confirms your SSH key is working (the "does not provide shell access" part is expected).

### 4. Configure Git

Set your name and email (used for commit messages):

```bash
git config --global user.name "Your Name"
git config --global user.email "your_email@example.com"
```

Set the default branch name to `main`:

```bash
git config --global init.defaultBranch main
```

Verify your configuration:

```bash
git config --list
```

---

## Essential Tools

### VS Code

VS Code is the recommended editor for lab work. It has excellent Python support, Git integration, and remote development capabilities (for connecting to the cluster).

Download and install from: https://code.visualstudio.com/

**Recommended extensions:**

- **Python** (Microsoft) - Python language support
- **Pylance** - Fast Python language server
- **Remote - SSH** - Connect to the cluster from VS Code

Install from the Extensions panel (`Cmd+Shift+X`) or via command line:

```bash
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-vscode-remote.remote-ssh
```

### Homebrew

Homebrew is the package manager for macOS. Many tools in this guide are installed via Homebrew.

**Check if already installed:**

```bash
brew --version
```

If you see a version number, you're all set. If you see "command not found", install it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the post-install instructions to add Homebrew to your PATH (it will print these after installation).

---

## Directory Structure

**Important:** Keep your code repositories outside of cloud-synced folders (Dropbox, iCloud, Google Drive). These services can corrupt Git repositories and cause sync conflicts.

Choose a local folder as your work directory. Common choices:

- `~/Work` - dedicated work folder
- `~/Documents` - if you prefer keeping everything in Documents

Within your work directory, we recommend this structure:

```
~/Work/                # Your chosen work directory (MY_WORK_DIR)
├── Projects/          # Git repositories go here
├── Buckets/           # S3 bucket mounts (optional)
└── Sandbox/           # Testing and scratch work
```

Create the directories (using `~/Work` as an example):

```bash
mkdir -p ~/Work/Projects ~/Work/Buckets ~/Work/Sandbox
```

When you clone lab repositories:

```bash
cd ~/Work/Projects
git clone git@github.com:harvard-visionlab/some-project.git
```

---

## Shell Configuration

Add the following to your shell configuration file (`~/.zshrc` for macOS Catalina and later, or `~/.bashrc` if using bash):

```bash
nano ~/.zshrc  # or ~/.bashrc
```

Add these lines:

```bash
# ==============================================================================
# Vision Lab Configuration (macOS)
# ==============================================================================

# Your FASRC username (used for S3 paths, consistent across all systems)
# This may differ from your local macOS username ($USER)
export VISLAB_USERNAME=your_fasrc_username_here

# Work directory - change this to your chosen location
# Common choices: ~/Work, ~/Documents
export MY_WORK_DIR=~/Work

# Directory structure (relative to MY_WORK_DIR)
export PROJECT_DIR=${MY_WORK_DIR}/Projects   # Git repos
export BUCKET_DIR=${MY_WORK_DIR}/Buckets     # S3 bucket mounts
export SANDBOX_DIR=${MY_WORK_DIR}/Sandbox    # Testing/scratch

# AWS credentials - get these from George
# IMPORTANT: Keep these secret! Never commit to git or share publicly.
export AWS_ACCESS_KEY_ID=your_access_key_here
export AWS_SECRET_ACCESS_KEY=your_secret_key_here
export AWS_DEFAULT_REGION=us-east-1

# uv configuration
export UV_CACHE_DIR=~/.uv_cache
export UV_TOOL_DIR=~/.uv_tools

# Add uv tools to PATH (for s5cmd, etc.)
export PATH="$HOME/.local/bin:$PATH"
```

Reload your shell:

```bash
source ~/.zshrc  # or source ~/.bashrc
```

---

## Python Environment Setup with uv

We use [uv](https://docs.astral.sh/uv/) for Python environment management. It's faster than conda/pip and creates reproducible environments.

### Install uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Restart your terminal or run:

```bash
source ~/.zshrc
```

Verify installation:

```bash
uv --version
```

### Create a Test Project

```bash
cd $SANDBOX_DIR
mkdir test-project && cd test-project
uv init
uv add numpy pandas ipykernel
```

Run Python in the environment:

```bash
uv run python -c "import numpy; print(f'NumPy {numpy.__version__} works!')"
```

### Clean Up

```bash
rm -rf $SANDBOX_DIR/test-project
```

---

## AWS and S3 Access

### 1. Configure AWS Credentials

Your AWS credentials should already be in your shell config (see [Shell Configuration](#shell-configuration)). Verify they're set:

```bash
echo $AWS_ACCESS_KEY_ID | head -c 8
# Should show first 8 characters of your key
```

If empty, get your credentials from George and add them to `~/.zshrc`.

### 2. Install AWS CLI Tools

**AWS CLI v2** (macOS instructions - see [official docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) for other platforms):

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg ./AWSCLIV2.pkg -target /
```

Verify installation:

```bash
which aws       # Should show /usr/local/bin/aws
aws --version   # Should show aws-cli/2.x.x ...
```

**s5cmd** (fast parallel S3 operations):

```bash
uv tool install s5cmd
```

Verify:

```bash
s5cmd version   # Should show v2.x
```

### 3. Verify AWS Access

```bash
# List buckets
aws s3 ls

# List contents of lab bucket
s5cmd ls s3://visionlab-members/
```

You should see `visionlab-members`, `visionlab-datasets`, and other lab buckets.

---

## S3 Bucket Mounting (rclone + FUSE-T)

For filesystem-like access to S3 buckets (treating them as local directories), we use rclone with FUSE-T.

### 1. Install FUSE-T

FUSE-T is a kext-less FUSE implementation for macOS (doesn't require kernel extensions).

First, remove any conflicting FUSE implementations:

```bash
brew uninstall --cask macfuse 2>/dev/null
brew uninstall --cask osxfuse 2>/dev/null
```

Install FUSE-T:

```bash
brew install --cask fuse-t
```

Verify installation:

```bash
ls -la /Library/Frameworks/fuse_t.framework
```

You should see the framework directory.

### 2. Install rclone

Use the official rclone binary (not Homebrew's version):

```bash
# Remove Homebrew rclone if present
brew uninstall rclone 2>/dev/null

# Download and install official binary
cd /tmp
curl -O https://downloads.rclone.org/rclone-current-osx-arm64.zip
unzip rclone-current-osx-arm64.zip
cd rclone-*-osx-arm64
sudo mkdir -p /usr/local/bin
sudo cp rclone /usr/local/bin/
sudo chmod +x /usr/local/bin/rclone
cd ..
rm -rf rclone-*-osx-arm64*
```

Verify:

```bash
which rclone        # Should show /usr/local/bin/rclone
rclone version      # Should show version info
```

### 3. Configure rclone

Create the rclone config:

```bash
mkdir -p ~/.config/rclone

cat > ~/.config/rclone/rclone.conf << 'EOF'
[s3_remote]
type = s3
provider = AWS
env_auth = true
region = us-east-1
EOF
```

Verify rclone can access your buckets:

```bash
rclone lsd s3_remote:
```

You should see `visionlab-members`, `visionlab-datasets`, etc.

### 4. Download Mount Scripts

Download the cross-platform mount scripts:

```bash
cd $BUCKET_DIR

# Download scripts
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup-guide/main/scripts/s3_bucket_mount.sh
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup-guide/main/scripts/s3_bucket_unmount.sh
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup-guide/main/scripts/s3_zombie_sweep.sh

chmod +x s3_bucket_mount.sh s3_bucket_unmount.sh s3_zombie_sweep.sh
```

### 5. Mount a Bucket

```bash
cd $BUCKET_DIR
./s3_bucket_mount.sh . visionlab-members
```

Verify the mount:

```bash
ls $BUCKET_DIR/visionlab-members/
```

You should see the contents of the S3 bucket.

### 6. Unmount

When done, unmount the bucket:

```bash
cd $BUCKET_DIR
./s3_bucket_unmount.sh . visionlab-members
```

### 7. Clean Up Orphaned Mounts

If mounts get stuck (e.g., after sleep/wake or crash), use the sweep script:

```bash
# Report orphaned mounts
./s3_zombie_sweep.sh report

# Fix orphaned mounts
./s3_zombie_sweep.sh fix
```

### When to use mounted buckets

Mount S3 when your code expects local file paths:

- Training frameworks that read data from disk
- Legacy code using `open()` or `os.path`
- Tools that don't support S3 URLs

For new code, prefer **fsspec** (next section) - it's simpler and doesn't require mount management.

**Note:** Mounts survive sleep/wake but are lost on reboot. Just re-run the mount script when needed.

---

## Python S3 Access (fsspec)

For programmatic S3 access, we use `fsspec` with the `s3fs` backend. Let's test this using VS Code.

### Create the test project

```bash
cd $SANDBOX_DIR
mkdir s3-test && cd s3-test
uv init
uv add fsspec s3fs
```

### Open in VS Code

```bash
code .
```

This opens VS Code in the `s3-test` directory.

### Create a test script

1. In VS Code, create a new file: **File → New File** (or `Cmd+N`)
2. Save it as `test_s3.py` (or `Cmd+S`, then type `test_s3.py`)
3. Paste the following code:

```python
import os
import fsspec

fs = fsspec.filesystem('s3')

# Use VISLAB_USERNAME (your FASRC username) for S3 paths
username = os.getenv('VISLAB_USERNAME')
if not username:
    raise ValueError("VISLAB_USERNAME not set! Check your ~/.zshrc has: export VISLAB_USERNAME=...")

print(f"Username: {username}")

# List your testing directory
print(f"\nListing s3://visionlab-members/{username}/testing/")
try:
    files = fs.ls(f'visionlab-members/{username}/testing/')
    for f in files:
        print(f"  {f}")
except FileNotFoundError:
    print("  (empty or doesn't exist yet)")

# Write a test file
test_path = f's3://visionlab-members/{username}/testing/laptop-test.txt'
with fs.open(test_path, 'w') as f:
    f.write('Hello from my laptop!')
print(f"\nWrote: {test_path}")

# Read it back
with fs.open(test_path, 'r') as f:
    print(f"Read: {f.read()}")

print("\nS3 access is working!")
```

### Run the script

Open the VS Code terminal (**Terminal → New Terminal** or `` Ctrl+` ``) and run:

```bash
uv run python test_s3.py
```

You should see output like:

```
Username: alvarez

Listing s3://visionlab-members/alvarez/testing/
  visionlab-members/alvarez/testing/laptop-test.txt

Wrote: s3://visionlab-members/alvarez/testing/laptop-test.txt
Read: Hello from my laptop!

S3 access is working!
```

### Clean up

When done testing, you can remove the project:

```bash
rm -rf $SANDBOX_DIR/s3-test
```

---

## Optional Tools

### Docker Desktop

Docker is useful for:
- Running containerized applications
- Testing deployment configurations
- Reproducing cluster environments locally

Install from: https://www.docker.com/products/docker-desktop/

Or via Homebrew:

```bash
brew install --cask docker
```

After installation, open Docker Desktop from Applications to complete setup.

Verify:

```bash
docker --version
docker run hello-world
```

### JupyterLab Desktop

JupyterLab Desktop provides a native app experience for Jupyter notebooks.

Install from: https://github.com/jupyterlab/jupyterlab-desktop/releases

Or via Homebrew:

```bash
brew install --cask jupyterlab
```

**Using with uv projects:**

JupyterLab Desktop can use your uv project environments:

1. Open JupyterLab Desktop
2. Navigate to your project directory
3. Open a notebook
4. Select the Python interpreter from your project's `.venv`

Alternatively, run JupyterLab through uv in any project:

```bash
cd ~/Projects/my-project
uv add jupyterlab
uv run jupyter lab
```

This opens JupyterLab in your browser with the project's environment.

---

## Quick Reference

### Environment Variables

```bash
$VISLAB_USERNAME               # Your FASRC username (for S3 paths)
$MY_WORK_DIR            # Your work directory (e.g., ~/Work)
$PROJECT_DIR            # ${MY_WORK_DIR}/Projects
$BUCKET_DIR             # ${MY_WORK_DIR}/Buckets
$SANDBOX_DIR            # ${MY_WORK_DIR}/Sandbox
$AWS_ACCESS_KEY_ID      # Your AWS access key (keep secret!)
$AWS_SECRET_ACCESS_KEY  # Your AWS secret key (keep secret!)
$AWS_DEFAULT_REGION     # us-east-1
$UV_CACHE_DIR           # ~/.uv_cache
$UV_TOOL_DIR            # ~/.uv_tools
```

### Common Commands

**uv (Python environments):**

```bash
uv init                    # Initialize a new project
uv add <package>           # Add a dependency
uv sync                    # Install from lockfile
uv run <command>           # Run in environment
```

**S3 access:**

```bash
# CLI
aws s3 ls s3://bucket/path/
s5cmd ls s3://bucket/path/
s5cmd cp local.txt s3://bucket/path/

# Mount (with visionlab-buckets)
mount-bucket visionlab-members
unmount-bucket visionlab-members
mount-bucket --list
```

**rclone:**

```bash
rclone lsd s3_remote:              # List buckets
rclone ls s3_remote:bucket/path/   # List files
rclone copy local/ s3_remote:bucket/path/  # Upload
```

### Python S3 Access

```python
import os
import fsspec

fs = fsspec.filesystem('s3')
username = os.getenv('VISLAB_USERNAME')  # Your FASRC username

# List files
fs.ls(f'visionlab-members/{username}/path/')

# Read/write
with fs.open(f's3://visionlab-members/{username}/file.txt', 'r') as f:
    content = f.read()

with fs.open(f's3://visionlab-members/{username}/file.txt', 'w') as f:
    f.write('content')

# Works with pandas
import pandas as pd
df = pd.read_parquet(f's3://visionlab-members/{username}/data.parquet')
df.to_parquet(f's3://visionlab-members/{username}/output.parquet')
```

---

## Summary

You've now configured your macOS laptop for Vision Lab work:

- **uv** manages Python environments (same as cluster)
- **AWS credentials** are set via environment variables
- **fsspec** provides programmatic S3 access
- **rclone + FUSE-T** enables filesystem-like S3 mounting

Your code will work seamlessly across your laptop, the Harvard cluster, and other lab environments.
