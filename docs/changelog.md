# Changelog

Updates to the setup guides. If you've already completed setup, check here for changes you may need to apply.

---

## 2025-01-17: Environment Variable Updates

### What Changed

1. **`TIER1` renamed to `LAB_TIER1`** - Clearer naming convention
2. **New `LAB_NETSCRATCH` variable** - Shared lab netscratch for litdata caches
3. **`AWS_REGION` renamed to `AWS_DEFAULT_REGION`** - Better AWS CLI compatibility
4. **`.lightning` symlink now points to shared location** - All lab members share cached datasets

### Why

- `LAB_NETSCRATCH` allows all lab members to share the same StreamingDataset caches (litdata), avoiding duplicate downloads of the same datasets
- Consistent naming: `LAB_*` for shared lab resources, `MY_*` for personal directories
- `AWS_DEFAULT_REGION` is recognized by more AWS tools than `AWS_REGION`

### How to Update

If you've already set up your cluster environment, update your `~/.bashrc`:

#### 1. Update environment variables

Open your bashrc:

```bash
nano ~/.bashrc
```

Find and update the storage roots section:

**Before:**
```bash
export MY_WORK_DIR=/n/holylabs/LABS/${LAB}/Users/$USER
export MY_NETSCRATCH=/n/netscratch/${LAB}/Everyone/$USER
export TIER1=/n/alvarez_lab_tier1/Lab/
```

**After:**
```bash
export MY_WORK_DIR=/n/holylabs/LABS/${LAB}/Users/$USER
export MY_NETSCRATCH=/n/netscratch/${LAB}/Everyone/$USER
export LAB_NETSCRATCH=/n/netscratch/${LAB}/Everyone
export LAB_TIER1=/n/alvarez_lab_tier1/Lab/
```

Also update AWS region:

**Before:**
```bash
export AWS_REGION=us-east-1
```

**After:**
```bash
export AWS_DEFAULT_REGION=us-east-1
```

Save and reload:

```bash
source ~/.bashrc
```

#### 2. Update .lightning symlink

```bash
# Remove old symlink
rm ~/.lightning

# Create new symlink to shared lab location
mkdir -p $LAB_NETSCRATCH/.lightning
ln -s $LAB_NETSCRATCH/.lightning ~/.lightning
```

#### 3. Verify

```bash
# Check variables are set
echo "LAB_NETSCRATCH: $LAB_NETSCRATCH"
echo "LAB_TIER1: $LAB_TIER1"
echo "AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"

# Check symlink
ls -la ~/.lightning
# Should show: ~/.lightning -> /n/netscratch/<lab>/Everyone/.lightning
```

---
