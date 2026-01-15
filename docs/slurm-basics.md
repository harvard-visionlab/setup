# SLURM Basics

> **TODO:** This guide is a placeholder extracted from the main Harvard cluster guide. Content will be expanded.

SLURM (Simple Linux Utility for Resource Management) is the job scheduler on the FASRC cluster. It allocates compute resources and manages the queue of jobs.

## Key Concepts

| Term          | Description                                                                |
| ------------- | -------------------------------------------------------------------------- |
| **Job**       | A request for compute resources (CPUs, GPUs, memory, time)                 |
| **Partition** | A group of nodes with similar characteristics (e.g., `gpu`, `gpu_requeue`) |
| **Node**      | A physical server with CPUs, memory, and possibly GPUs                     |
| **Task**      | A process within a job (most jobs have one task)                           |

## Common Commands

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

## Interactive Sessions

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

## Basic Job Script

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

## Common Partitions

| Partition        | GPUs       | Time Limit | Notes                                                      |
| ---------------- | ---------- | ---------- | ---------------------------------------------------------- |
| `gpu`            | A100, V100 | 7 days     | Standard GPU partition                                     |
| `gpu_requeue`    | A100, V100 | 7 days     | Lower priority, preemptible, **use for checkpointed jobs** |
| `gpu_test`       | A100, V100 | 1 hour     | Testing/debugging, high priority                           |
| `test`           | None       | 1 hour     | CPU-only testing                                           |
| `serial_requeue` | None       | 7 days     | CPU jobs, preemptible                                      |

**Recommendation:** Use `gpu_requeue` for training jobs that checkpoint regularly. You get better queue times and contribute to cluster efficiency.

## Requesting GPUs

```bash
#SBATCH --gres=gpu:1          # Any 1 GPU
#SBATCH --gres=gpu:a100:1     # Specifically 1 A100
#SBATCH --gres=gpu:2          # 2 GPUs
```

Check available GPU types:

```bash
sinfo -p gpu -o "%N %G"
```

## Job Arrays

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

## Monitoring Jobs

```bash
# Watch your jobs update every 5 seconds
watch -n 5 'squeue -u $USER'

# Check job efficiency after completion
seff <job_id>

# See detailed job accounting
sacct -j <job_id> --format=JobID,JobName,Elapsed,MaxRSS,MaxVMSize,State
```

## Tips

1. **Always checkpoint:** Save model state periodically so you can resume if preempted or timed out
2. **Request only what you need:** Smaller resource requests get scheduled faster
3. **Use `gpu_requeue`:** For long training jobs with checkpointing
4. **Check your output:** Jobs can fail silently - always check `.err` files
5. **Clean up:** Delete old logs and temp files to stay within quotas

## Example: Training Script with S3 Mount

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

# Unmount
$BUCKET_DIR/s3_bucket_unmount.sh $BUCKET_DIR visionlab-members

echo "Job completed at $(date)"
```
