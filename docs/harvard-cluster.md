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

# uv (Python package manager) cache location
# On holylabs so it can hardlink to project .venvs (same filesystem)
export UV_CACHE_DIR=${HOLYLABS}/.uv_cache

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

**What each variable does:**

| Variable               | Purpose                                           |
| ---------------------- | ------------------------------------------------- |
| `LAB`                  | Your lab affiliation, used in storage paths       |
| `HOLYLABS`             | Root of your holylabs directory                   |
| `NETSCRATCH`           | Your netscratch directory (temp files, ephemeral) |
| `TIER1`                | Your tier1 directory (large datasets, persistent) |
| `PROJECT_DIR`          | Where your git repos live                         |
| `BUCKET_DIR`           | Where S3 buckets are mounted                      |
| `SANDBOX_DIR`          | For testing and scratch work                      |
| `UV_CACHE_DIR`         | Where uv stores downloaded packages               |
| `AWS_ACCESS_KEY_ID`    | Your AWS access key (get from George)             |
| `AWS_SECRET_ACCESS_KEY`| Your AWS secret key (get from George)             |
| `AWS_REGION`           | AWS region (us-east-1)                            |

### 2. Create Holylabs Folder Structure

Set up the recommended folder organization:

```bash
mkdir -p $HOLYLABS/{Projects,Buckets,Sandbox}
```

| Folder      | Purpose                                                                                 |
| ----------- | --------------------------------------------------------------------------------------- |
| `Projects/` | Git repositories. All code should be version controlled and regularly pushed to GitHub. |
| `Buckets/`  | S3 bucket mounts (see AWS setup section).                                               |
| `Sandbox/`  | Testing, experiments, organize however you like.                                        |

### 3. Set Up Home Directory Symlinks

Your home directory has a 100GB quota. Many applications create large hidden cache directories that can quickly fill this up. We symlink these to netscratch (ephemeral caches) or tier1 (persistent environments).

First, create your netscratch user directory if it doesn't exist:

```bash
mkdir -p /n/netscratch/${LAB}/Lab/Users/$USER
```

Now create the symlinks. For each directory below, we'll:

1. Move any existing data to the target location
2. Create a symlink from home to the target

**~/.cache → netscratch** (general caches - pip, huggingface, torch hub, etc.):

```bash
# Move existing cache if present
if [ -d ~/.cache ] && [ ! -L ~/.cache ]; then
    mv ~/.cache /n/netscratch/${LAB}/Lab/Users/$USER/.cache
fi
# Create target directory and symlink
mkdir -p /n/netscratch/${LAB}/Lab/Users/$USER/.cache
ln -sf /n/netscratch/${LAB}/Lab/Users/$USER/.cache ~/.cache
```

**~/.conda → tier1** (conda environments - persistent, takes time to rebuild):

```bash
# Move existing conda if present
if [ -d ~/.conda ] && [ ! -L ~/.conda ]; then
    mv ~/.conda /n/alvarez_lab_tier1/Users/$USER/.conda
fi
# Create target directory and symlink
mkdir -p /n/alvarez_lab_tier1/Users/$USER/.conda
ln -sf /n/alvarez_lab_tier1/Users/$USER/.conda ~/.conda
```

**~/.nv → netscratch** (NVIDIA/CUDA compilation cache):

```bash
if [ -d ~/.nv ] && [ ! -L ~/.nv ]; then
    rm -rf ~/.nv  # Safe to delete, will regenerate
fi
mkdir -p /n/netscratch/${LAB}/Lab/Users/$USER/.nv
ln -sf /n/netscratch/${LAB}/Lab/Users/$USER/.nv ~/.nv
```

**~/.triton → netscratch** (Triton GPU compiler cache):

```bash
if [ -d ~/.triton ] && [ ! -L ~/.triton ]; then
    rm -rf ~/.triton  # Safe to delete, will regenerate
fi
mkdir -p /n/netscratch/${LAB}/Lab/Users/$USER/.triton
ln -sf /n/netscratch/${LAB}/Lab/Users/$USER/.triton ~/.triton
```

Verify your symlinks:

```bash
ls -la ~/.cache ~/.conda ~/.nv ~/.triton
```

You should see arrows (`->`) pointing to the target locations.

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

## Home Directory Symlinks

Summary of symlinks set up in [Initial Setup](#2-set-up-home-directory-symlinks):

### Symlinked to Netscratch (ephemeral, ok to lose)

| Directory   | Purpose                                             | Typical size |
| ----------- | --------------------------------------------------- | ------------ |
| `~/.cache`  | General application caches (pip, huggingface, etc.) | 10-100+ GB   |
| `~/.nv`     | NVIDIA/CUDA compilation cache                       | 10-100+ MB   |
| `~/.triton` | Triton GPU compiler cache                           | 10-500+ MB   |

### Symlinked to Tier1 (persistent)

| Directory  | Purpose                             | Why persistent                     |
| ---------- | ----------------------------------- | ---------------------------------- |
| `~/.conda` | Conda environments (if using conda) | Environments take time to recreate |

### Left in Home (small, important)

| Directory                 | Purpose             |
| ------------------------- | ------------------- |
| `~/.ssh`                  | SSH keys            |
| `~/.config`               | Application configs |
| `~/.bashrc`, `~/.profile` | Shell config        |
| `~/.jupyter`              | Jupyter config      |

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
$UV_CACHE_DIR           # ${HOLYLABS}/.uv_cache
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
