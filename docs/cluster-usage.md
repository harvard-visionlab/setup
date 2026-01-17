# Using the Cluster

This guide covers day-to-day cluster usage: how to access resources and when to use each method.

## Access Methods Overview

There are four ways to access the cluster:

| Method | Use Case | Guide |
|--------|----------|-------|
| **Interactive Sessions** | Developing code, visualizations, notebooks | This page |
| **Terminal Access** | Light tasks, launching jobs, system config | [Terminal & SSH Setup](terminal-ssh-setup.md) |
| **VS Code Remote** | IDE-based development on cluster | Coming soon |
| **SLURM Jobs** | Training models, batch processing | [SLURM Basics](slurm-basics.md) |

## When to Use What

- **Interactive sessions (JupyterLab):** Developing code, exploratory analysis, generating visualizations
- **Terminal access:** Quick file operations, git pulls, launching SLURM jobs
- **VS Code Remote:** When you prefer an IDE over notebooks
- **SLURM jobs:** Training models, computing features, any batch processing that runs unattended

> **Rule of thumb:** If you're actively watching and interacting with your code, use interactive. If you're "running a job" that will complete on its own, use SLURM.

## Interactive Sessions (JupyterLab)

Interactive sessions let you run Jupyter notebooks directly on cluster compute nodes.

### Starting a Session

1. Go to https://vdi.rc.fas.harvard.edu/pun/sys/dashboard
2. Under **Interactive Apps**, click **Jupyter notebook / Jupyterlab**
3. Configure your session (see below)
4. Click **Launch**

### Session Configuration

<!-- Note: Screenshots would go here if you have them in images/ folder -->

**Partition:** Choose based on your needs:

| Partition | Use Case | Notes |
|-----------|----------|-------|
| `gpu_test` | Development, testing | Good for most interactive work |
| `gpu` | Longer sessions | When you need more time |
| `gpu_h200` | H200 GPUs | For work requiring newer GPUs |
| `gpu_requeue` | Preemptible | May be interrupted, use for non-critical work |

**Typical settings for development:**
- **Memory:** 192 GB
- **Cores:** 24
- **GPUs:** 1
- **Time:** 4:00:00 (or however long you plan to work)

> **Tip:** Request only what you need. Larger requests may wait longer to start.

**Working Directory:** Set this to your holylabs user directory:
```
/n/holylabs/LABS/${LAB}/Users/<your-username>
```

For example:
- Alvarez lab: `/n/holylabs/LABS/alvarez_lab/Users/yourusername`
- Konkle lab: `/n/holylabs/LABS/konkle_lab/Users/yourusername`

**SLURM Account:** This determines which cluster resources you use:

| If you work with... | Set account to... |
|---------------------|-------------------|
| George (Alvarez lab) | `kempner_alvarez_lab` |
| Talia (Konkle lab) | `kempner_konkle_lab` |

> **Important:** Using `kempner_*` accounts schedules your jobs on the Kempner cluster, which has more GPUs and shorter wait times than the general FASRC cluster.

### Connecting to Your Session

After clicking Launch, you'll see the "My Interactive Sessions" screen.

1. Wait for status to change from "Starting..." to "Running"
2. Click **Connect to Jupyter**
3. You'll see the JupyterLab launcher with available kernels

If you've set up your environment following the [cluster setup guide](harvard-cluster.md), you should see your project kernels available.

### Canceling Sessions

**Always cancel your session when you're done working.**

1. Go to https://vdi.rc.fas.harvard.edu/pun/sys/dashboard
2. Find your session under "My Interactive Sessions"
3. Click the red **Cancel** button

This returns resources to the pool for others and ensures your fairshare only reflects actual usage time.

## Terminal Access (Login Nodes)

Login nodes are for **light tasks only**:
- Launching SLURM jobs
- Quick file operations
- Git operations
- Checking job status

**Do NOT** run heavy computations, transfers, or Python code on login nodes.

### Basic SSH Connection

```bash
ssh <your-username>@holylogin.rc.fas.harvard.edu
```

You'll need your FASRC password and 2FA code.

For easier login with SSH keys and shortcuts, see [Terminal & SSH Setup](terminal-ssh-setup.md).

## Fairshare

Fairshare is the cluster's mechanism for ensuring all groups get equitable access to resources.

- Using lots of resources for a period may mean longer wait times later
- This affects all lab members, not just you
- In practice, the lab rarely hits fairshare limits on the Kempner cluster

**Tips to be a good cluster citizen:**
- Cancel sessions when done (don't let them run to timeout)
- Request only the resources you need
- Use SLURM jobs instead of interactive sessions for long-running work

For technical details: https://docs.rc.fas.harvard.edu/kb/fairshare/

## Troubleshooting

### Long wait times for resources

- Check if there's a conference deadline (high cluster demand)
- Try a different partition (`gpu_test` often has availability)
- Reduce your resource request (fewer GPUs, less memory)
- Check lab fairshare (visible when you SSH to login node)

### Session won't start

- Verify your SLURM account is correct (`kempner_alvarez_lab` or `kempner_konkle_lab`)
- Check that your working directory path exists
- Try with a smaller resource request

### Can't see my files in JupyterLab

- Check your working directory setting
- Ensure you're looking in the right storage location (holylabs, not home)
- Verify your storage access with George if needed
