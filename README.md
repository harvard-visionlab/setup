# Vision Lab Setup

Setup guides and scripts for Vision Lab members to configure their computing environments.

## Guides

| Environment | Guide | Status |
|-------------|-------|--------|
| Harvard FASRC Cluster | [docs/harvard-cluster.md](docs/harvard-cluster.md) | In progress |
| Laptop (macOS/Linux) | docs/laptop.md | Planned |
| Lightning AI | docs/lightning-ai.md | Planned |
| Lab Workstations | docs/lab-workstations.md | Planned |

## Quick Start (Harvard Cluster)

```bash
# 1. Set up your shell configuration
curl -O https://raw.githubusercontent.com/harvard-visionlab/setup/main/scripts/setup-bashrc.sh
bash setup-bashrc.sh
source ~/.bashrc

# 2. Set up home directory symlinks (prevents quota issues)
bash <(curl -s https://raw.githubusercontent.com/harvard-visionlab/setup/main/scripts/setup-symlinks.sh)

# 3. Install uv for Python environment management
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env

# 4. Create your first project
cd $HOLYLABS
mkdir my-project && cd my-project
uv init
uv add numpy torch ipykernel
```

See the [full guide](docs/harvard-cluster.md) for details.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup-bashrc.sh` | Configure shell with lab-standard environment variables |
| `scripts/setup-symlinks.sh` | Set up home directory symlinks to prevent quota bloat |

## Lab Affiliation

Set `LAB` to your primary advisor's lab:
- `alvarez_lab`
- `konkle_lab`

This determines paths for holylabs and netscratch storage.

## Contributing

Found an issue or have a suggestion? Open an issue or PR.
