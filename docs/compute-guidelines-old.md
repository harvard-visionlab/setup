# Compute Guidelines

Lab policies, rules, and best practices for using compute resources.

## Usage Rules

### Lab Resources Are for Lab Projects

Lab storage and compute resources are for lab projects only:

- **Side projects?** No, don't use lab resources
- **Outside collaborations without PI involvement?** No, don't use lab resources
- **Vision Lab project with Talia or George?** Yes, use lab resources

If you're unsure whether something qualifies, ask your PI.

### Model Training Requires Approval

If you're training models:

1. **Get approval first** - Discuss with George or Talia before starting
2. **Define scope** - Clear compute budget and timeline
3. **Use the lab template** - All models must use the lab's training template

This ensures:
- Models are logged in the lab's systems
- Models are accessible through lab code packages
- Compute usage is tracked and managed

> **Need features the template doesn't support?** We'll fork and develop the new capability, then merge it into the main codebase.

### Significant Resource Usage

If you're consuming significant resources, vet the specifics with George or Talia first.

Not sure what counts as "significant"? Ask your PI.

## Project Infrastructure

### Where Things Live

<!-- Note: A diagram showing the infrastructure would go here if you have images/ -->

| Location | What Goes There |
|----------|-----------------|
| **GitHub** (harvard-visionlab org) | Project code repositories |
| **S3** (`s3://visionlab-members/username/project/`) | Code outputs, datasets, model weights |
| **Cluster (holylabs)** | Active project code, things needing frequent read/write |
| **Cluster (netscratch)** | Temporary cache for high-frequency I/O |
| **Laptop (Dropbox)** | Lab books, posters, manuscripts, presentations |

### S3 for Outputs

Store all code outputs on S3, not on the cluster:

**Pros:**
- Easy to access from anywhere
- Automatic backup
- Shareable with collaborators
- Auto-archivable

**Note:** You need to mount S3 buckets each time you work on a project. See the [S3 setup section](harvard-cluster.md#s3-setup) in the cluster guide.

## Storage Guidelines

### Cluster Storage Locations

| Storage | Path | Use For |
|---------|------|---------|
| **Home** | `~/` | Config files, symlinks only (100GB limit) |
| **Holylabs** | `/n/holylabs/LABS/${LAB}/Users/$USER/` | Projects, code, main work |
| **Netscratch** | `/n/netscratch/${LAB}/Everyone/$USER/` | Temporary files, cache |
| **Tier1** | `/n/alvarez_lab_tier1/Users/$USER/` | Valuable persistent data (expensive, limited) |

### Directory Structure

In your holylabs directory:

```
/n/holylabs/LABS/${LAB}/Users/$USER/
├── Projects/     # Git repositories go here
└── Sandbox/      # Tinkering/experimental space
```

### Storage Rules of Thumb

- **Don't store much in home** - It's small (100GB) and for configs only
- **Don't leave data in netscratch long-term** - It gets cleaned up monthly
- **Don't store outputs on the cluster** - Use S3 instead
- **Don't store large datasets on holylabs** - Stream from S3 or use netscratch for local cache

## Best Practices

### Use Streaming Datasets

Make all datasets streaming where possible:

- Competitive with standard formats in speed (except FFCV)
- Elegant caching and access patterns
- Easy integration with S3 buckets

We recommend using [LitData](https://github.com/Lightning-AI/litdata) for streaming datasets.

### Use FFCV for Model Training

When training models, use FFCV if possible. It provides significant speedups (up to 10x) for data loading.

### Cancel Sessions When Done

When you finish working in an interactive session, always click **Cancel** to return resources:

1. Go to https://vdi.rc.fas.harvard.edu/pun/sys/dashboard
2. Find your session
3. Click the red Cancel button

This:
- Returns resources for others to use
- Reduces your fairshare impact (only actual usage counts)
- Is good cluster citizenship

### Request Appropriate Resources

- Don't over-request GPUs, memory, or time
- Larger requests may wait longer in the queue
- Start small and scale up if needed

## Summary

1. **Lab resources are for lab projects only**
2. **Get approval before training models**
3. **Store outputs on S3, not the cluster**
4. **Use streaming datasets**
5. **Cancel sessions when done**
6. **Ask your PI if you're unsure about anything**

## Questions?

If you're unsure about any policy or best practice, ask George or Talia.
