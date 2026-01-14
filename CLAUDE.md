# Setup Repository

This repo contains setup guides and scripts for Vision Lab members to configure their computing environments.

## Project Status

We are building a comprehensive setup guide covering multiple environments (Harvard cluster, laptops, Lightning AI, lab workstations).

### Completed

- [x] Investigated Harvard cluster storage topology
- [x] Determined optimal uv cache location (holylabs, enables hardlinks)
- [x] Verified hardlink support within holylabs filesystem
- [x] Tested uv project creation and package installation
- [x] Created Jupyter kernel spec for uv auto-detection
- [x] Draft guide started (see `docs/harvard-cluster.md`)
- [x] Organized repo structure (README, docs/, scripts/, templates/)
- [x] Created `scripts/setup-bashrc.sh` - interactive bashrc configuration
- [x] Created `templates/bashrc-additions.sh` - standard lab environment variables
- [x] Created `scripts/setup-symlinks.sh` - home directory symlink setup
- [x] Documented symlink strategy (`.cache` -> netscratch, `.conda` -> tier1)
- [x] AWS/S3 setup section (awscli, s5cmd, fsspec, boto3)
- [x] S3 bucket mounting scripts (rclone FUSE)

### TODO

#### Harvard Cluster Setup
- [ ] SLURM job submission basics
- [ ] Module loading (if needed)

#### Other Environments
- [ ] Laptop setup guide (macOS/Linux)
- [ ] Lightning AI setup guide
- [ ] Lab workstations (Lambda Labs GPUs) setup guide

## Key Findings

### Storage Topology (Harvard Cluster)

| Storage | Path | Characteristics | Use for |
|---------|------|-----------------|---------|
| Home | `~/` | 100GB limit, persistent | Config files, symlinks only |
| Tier1 | `/n/alvarez_lab_tier1/Users/$USER/` | Expensive, limited, performant, persistent | Valuable persistent data |
| Holylabs | `/n/holylabs/LABS/${LAB}/Users/$USER/` | Less performant, inexpensive, persistent | Projects, code, uv cache |
| Netscratch | `/n/netscratch/${LAB}/Lab/Users/$USER/` | Free, large, performant, ephemeral | Scratch, temp files |

**Critical:** Netscratch has monthly cleanup. Never store irreplaceable data there.

### Filesystem Boundaries

```
Device 43: /n/netscratch, /n/holylabs (same server, but hardlinks fail across them)
Device 57: /n/home02
Tier1: separate NFS server entirely
```

**Hardlinks work within holylabs** — this is why we put UV_CACHE_DIR there (same filesystem as projects).

### uv Configuration

```bash
export LAB=alvarez_lab  # or konkle_lab
export UV_CACHE_DIR=/n/holylabs/LABS/${LAB}/Users/$USER/.uv_cache
# No UV_LINK_MODE needed — hardlink is default
```

### Jupyter Kernel

The "Python (uv auto)" kernel runs `uv run python -m ipykernel`, which auto-detects the project from the notebook's location. Projects need `ipykernel` as a dependency.

## File Structure

```
setup/
├── README.md                   # Repo overview and quick start
├── CLAUDE.md                   # This file (project tracking)
├── docs/
│   └── harvard-cluster.md      # Main Harvard cluster setup guide
├── scripts/
│   ├── setup-bashrc.sh         # Bashrc configuration (interactive)
│   ├── setup-symlinks.sh       # Home directory symlink setup
│   ├── s3_bucket_mount.sh      # Mount S3 bucket via rclone FUSE
│   ├── s3_bucket_unmount.sh    # Unmount S3 bucket
│   └── s3_zombie_sweep.sh      # Clean up orphaned mounts
└── templates/
    └── bashrc-additions.sh     # Standard bashrc additions template
```

Future additions:
- `docs/laptop.md` - Laptop setup guide
- `docs/lightning-ai.md` - Lightning AI setup
- `docs/lab-workstations.md` - Lambda Labs workstations

## Lab Affiliation

The `LAB` environment variable should be set to the user's primary advisor's lab:
- `alvarez_lab`
- `konkle_lab`

This determines paths for holylabs and netscratch storage.

## Conventions

- All paths should use `${LAB}` variable where appropriate
- Scripts should be idempotent (safe to run multiple times)
- Guides should include verification steps
- Keep instructions copy-pasteable where possible
