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

Run the setup script to configure your `~/.bashrc` with lab-standard settings:

```bash
# Download and review the script first
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup/main/scripts/setup-bashrc.sh
less setup-bashrc.sh  # Review what it does

# Run it (you'll be prompted for your lab affiliation)
bash setup-bashrc.sh
source ~/.bashrc
```

Or manually add to your `~/.bashrc`:

```bash
# Lab affiliation (used in storage paths)
# Use your primary advisor's lab: alvarez_lab or konkle_lab
export LAB=alvarez_lab

# Standard directory shortcuts
export HOLYLABS=/n/holylabs/LABS/${LAB}/Users/$USER
export NETSCRATCH=/n/netscratch/${LAB}/Lab/Users/$USER
export TIER1=/n/alvarez_lab_tier1/Users/$USER

# uv cache location (on holylabs for hardlink support)
export UV_CACHE_DIR=${HOLYLABS}/.uv_cache
```

Then reload:

```bash
source ~/.bashrc
```

### 2. Set Up Home Directory Symlinks

Your home directory has a 100GB quota. Many applications create large hidden cache directories that can quickly fill this up. We symlink these to netscratch (ephemeral, ok to lose) or holylabs (persistent).

Run the setup script:

```bash
bash <(curl -s https://raw.githubusercontent.com/harvard-visionlab/setup/main/scripts/setup-symlinks.sh)
```

See [Home Directory Symlinks](#home-directory-symlinks) below for details on what gets symlinked.

### 3. Verify Storage Access

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

### 3. Create Your First Project

```bash
cd $HOLYLABS
mkdir my-project && cd my-project
uv init
uv add numpy torch  # Add whatever packages you need
```

The project will contain:

-   `pyproject.toml` — project metadata and dependencies
-   `uv.lock` — exact versions for reproducibility
-   `.venv/` — the virtual environment (gitignore this)

### 4. Running Code

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

These directories commonly cause home directory bloat and should be symlinked:

### Symlinked to Netscratch (ephemeral, ok to lose)

| Directory   | Purpose                                             | Typical size |
| ----------- | --------------------------------------------------- | ------------ |
| `~/.cache`  | General application caches (pip, huggingface, etc.) | 10-100+ GB   |
| `~/.nv`     | NVIDIA/CUDA compilation cache                       | 10-100+ MB   |
| `~/.triton` | Triton GPU compiler cache                           | 10-500+ MB   |
| `~/.npm`    | npm package cache                                   | 10-100+ MB   |

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

### Standard Path Variables

```bash
$LAB          # Your lab: alvarez_lab or konkle_lab
$HOLYLABS     # /n/holylabs/LABS/${LAB}/Users/$USER
$NETSCRATCH   # /n/netscratch/${LAB}/Lab/Users/$USER
$TIER1        # /n/alvarez_lab_tier1/Users/$USER
$UV_CACHE_DIR # ${HOLYLABS}/.uv_cache
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
