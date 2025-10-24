# Hybrid Example - Side-by-Side Comparison

Run AWS CLI and s5cmd side-by-side to compare performance, test migration, and use both tools together.

## Overview

This example allows you to:

- **Compare** AWS CLI vs s5cmd performance on the same dataset
- **Test** s5cmd before fully migrating
- **Migrate** gradually from AWS CLI to s5cmd
- **Rollback** to AWS CLI if needed
- **Use both** tools simultaneously for different workloads

Perfect for:
- **Evaluation** - Testing s5cmd performance
- **Migration** - Gradual transition from AWS CLI
- **Comparison** - Side-by-side benchmarking
- **Hybrid deployment** - Using both tools for different purposes

## Directory Structure

```
hybrid/
├── awscli-config.env       # AWS CLI configuration
├── s5cmd-config.env        # s5cmd configuration
├── compare.sh              # Performance comparison tool
├── migrate.sh              # Migration helper
└── README.md               # This file
```

## Quick Start

### 1. Install Both Tools

```bash
# AWS CLI (usually pre-installed)
aws --version

# Install s5cmd
cd ../..
./tools/install-s5cmd.sh
```

### 2. Configure Both Tools

Edit configurations:

```bash
# AWS CLI config
nano awscli-config.env

# s5cmd config
nano s5cmd-config.env
```

### 3. Run Performance Comparison

```bash
# Compare with existing files
./compare.sh

# Or generate test data
./compare.sh --test-size 1GB
./compare.sh --test-size 5GB
```

## Performance Comparison

### Running Comparisons

The `compare.sh` script:
1. Runs AWS CLI upload
2. Runs s5cmd upload
3. Compares performance metrics
4. Saves results to logs

**Example output:**

```
╔════════════════════════════════════════════════════════════════╗
║                    PERFORMANCE COMPARISON                       ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  Dataset Size:          5.00 GB                                 ║
║  Files Uploaded:        20                                      ║
║                                                                 ║
╠════════════════════════════════════════════════════════════════╣
║                      AWS CLI (Optimized)                        ║
╟─────────────────────────────────────────────────────────────────╢
║  Duration:              45s                                     ║
║  Throughput:            284 MB/s                                ║
║                                                                 ║
╠════════════════════════════════════════════════════════════════╣
║                           s5cmd                                 ║
╟─────────────────────────────────────────────────────────────────╢
║  Duration:              8s                                      ║
║  Throughput:            1072 MB/s                               ║
║                                                                 ║
╠════════════════════════════════════════════════════════════════╣
║                         IMPROVEMENT                             ║
╟─────────────────────────────────────────────────────────────────╢
║  Time Improvement:      5.6x faster                             ║
║  Throughput Improvement:3.8x                                    ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
```

### Interpreting Results

**Good performance indicators:**
- s5cmd is **3-12x faster** than AWS CLI
- s5cmd achieves **>80% network utilization**
- Upload time is **significantly reduced**

**Potential issues:**
- s5cmd only **2x faster** → Check concurrency settings
- Low network utilization → Check bandwidth limits
- High error rates → Check S3 bucket permissions

## Migration Guide

### Step 1: Check Current Setup

```bash
./migrate.sh --check
```

Verifies:
- AWS CLI installed
- s5cmd installed
- AWS credentials configured
- Existing datasync scripts

### Step 2: Review Migration Plan

```bash
./migrate.sh --plan
```

Shows:
- Migration phases (5 phases over 2-3 weeks)
- Timeline and milestones
- Rollback procedures

### Step 3: Test s5cmd

```bash
./migrate.sh --test
```

This:
- Creates test configuration from AWS CLI config
- Runs dry-run upload
- Validates s5cmd works correctly

### Step 4: Perform Migration

```bash
./migrate.sh --migrate
```

This:
- Backs up AWS CLI configuration
- Creates s5cmd configuration
- Documents migration
- Provides rollback instructions

### Step 5: Monitor and Validate

After migration:

```bash
# Monitor logs
tail -f logs/s5cmd/*.log

# Check performance
cat logs/s5cmd/json/latest.json | jq

# Compare with AWS CLI baseline
./compare.sh
```

### Rollback if Needed

```bash
./migrate.sh --rollback
```

This restores AWS CLI configuration from backup.

## Configuration Management

### AWS CLI Configuration

`awscli-config.env`:

```bash
# Performance settings
export AWS_MAX_CONCURRENT_REQUESTS="20"
export AWS_MULTIPART_THRESHOLD="64MB"
export AWS_MULTIPART_CHUNKSIZE="64MB"

# S3 settings
export BUCKET_NAME="my-test-bucket"
export S3_SUBDIRECTORY="awscli-uploads"
```

### s5cmd Configuration

`s5cmd-config.env`:

```bash
# Performance settings (typically 3-5x AWS CLI concurrency)
export S5CMD_CONCURRENCY="64"
export S5CMD_PART_SIZE="64MB"
export S5CMD_NUM_WORKERS="32"

# S3 settings
export BUCKET_NAME="my-test-bucket"
export S3_SUBDIRECTORY="s5cmd-uploads"
```

### Configuration Conversion

| AWS CLI Setting | s5cmd Equivalent | Conversion |
|----------------|------------------|------------|
| `AWS_MAX_CONCURRENT_REQUESTS=20` | `S5CMD_CONCURRENCY=64` | 3-4x |
| `AWS_MULTIPART_CHUNKSIZE=64MB` | `S5CMD_PART_SIZE=64MB` | 1:1 |
| - | `S5CMD_NUM_WORKERS=32` | half of concurrency |

## Use Cases

### Use Case 1: Performance Evaluation

**Goal:** Determine if s5cmd is worth adopting.

```bash
# Run comparison
./compare.sh --test-size 5GB

# Review results
cat logs/comparison-*.txt
```

**Decision criteria:**
- s5cmd >3x faster → Worth migrating
- s5cmd 1-2x faster → Marginal benefit, consider complexity
- s5cmd similar speed → Investigate configuration

### Use Case 2: Gradual Migration

**Goal:** Migrate from AWS CLI to s5cmd safely.

**Phase 1: Side-by-side (Week 1)**
```bash
# Run both tools in parallel
source awscli-config.env && ../../scripts/datasync-awscli.sh
source s5cmd-config.env && ../../scripts/datasync-s5cmd.sh

# Compare results
./compare.sh
```

**Phase 2: s5cmd primary (Week 2)**
```bash
# Use s5cmd by default, AWS CLI as backup
source s5cmd-config.env && ../../scripts/datasync-s5cmd.sh || \
source awscli-config.env && ../../scripts/datasync-awscli.sh
```

**Phase 3: s5cmd only (Week 3+)**
```bash
# s5cmd only, AWS CLI for emergencies
source s5cmd-config.env && ../../scripts/datasync-s5cmd.sh
```

### Use Case 3: Different Tools for Different Workloads

**Goal:** Use the right tool for each workload.

**Large files (>1GB) → s5cmd:**
```bash
# Maximum performance for large files
export SOURCE_DIR="/data/large-files"
source s5cmd-config.env
../../scripts/datasync-s5cmd.sh
```

**Small files (<10MB) → AWS CLI:**
```bash
# Simple and reliable for small files
export SOURCE_DIR="/data/small-files"
source awscli-config.env
../../scripts/datasync-awscli.sh
```

### Use Case 4: Testing and Production

**Goal:** Use different tools for different environments.

**Development/Testing → AWS CLI:**
```bash
# Familiar and simple for dev/test
export BUCKET_NAME="dev-bucket"
source awscli-config.env
../../scripts/datasync-awscli.sh
```

**Production → s5cmd:**
```bash
# Maximum performance for production
export BUCKET_NAME="prod-bucket"
source s5cmd-config.env
../../scripts/datasync-s5cmd.sh
```

## Hybrid Deployment Patterns

### Pattern 1: Fallback on Failure

Use s5cmd, fallback to AWS CLI on error:

```bash
#!/bin/bash
source s5cmd-config.env
if ! ../../scripts/datasync-s5cmd.sh; then
    echo "s5cmd failed, falling back to AWS CLI"
    source awscli-config.env
    ../../scripts/datasync-awscli.sh
fi
```

### Pattern 2: Time-based Selection

Use s5cmd during off-peak, AWS CLI during peak:

```bash
#!/bin/bash
hour=$(date +%H)
if [ $hour -ge 22 ] || [ $hour -le 6 ]; then
    # Off-peak: use s5cmd for speed
    source s5cmd-config.env
    ../../scripts/datasync-s5cmd.sh
else
    # Peak hours: use AWS CLI (less aggressive)
    source awscli-config.env
    ../../scripts/datasync-awscli.sh
fi
```

### Pattern 3: Size-based Selection

Use s5cmd for large uploads, AWS CLI for small:

```bash
#!/bin/bash
size=$(du -sb "$SOURCE_DIR" | awk '{print $1}')
threshold=$((1024 * 1024 * 1024))  # 1 GB

if [ $size -gt $threshold ]; then
    # Large upload: use s5cmd
    source s5cmd-config.env
    ../../scripts/datasync-s5cmd.sh
else
    # Small upload: use AWS CLI
    source awscli-config.env
    ../../scripts/datasync-awscli.sh
fi
```

## Troubleshooting

### Issue: s5cmd not significantly faster

**Check concurrency:**
```bash
# Increase concurrency
export S5CMD_CONCURRENCY="128"
export S5CMD_NUM_WORKERS="64"
```

**Check network:**
```bash
# Monitor network during upload
iftop -i eth0
```

### Issue: s5cmd uses too much memory

**Reduce concurrency:**
```bash
export S5CMD_CONCURRENCY="32"
export S5CMD_NUM_WORKERS="16"
```

### Issue: Inconsistent results

**Clear S3 destination between tests:**
```bash
# Clean up test uploads
aws s3 rm s3://bucket/awscli-uploads/ --recursive
aws s3 rm s3://bucket/s5cmd-uploads/ --recursive
```

### Issue: Migration concerns

**Test thoroughly:**
```bash
# 1. Test with dry-run
./migrate.sh --test

# 2. Compare checksums
# Upload same files with both tools
# Verify S3 ETags match

# 3. Run in parallel for a week
# Monitor both tools
# Compare reliability and performance
```

## Best Practices

1. **Always test before migrating**
   - Run comparison with real data
   - Verify checksums match
   - Test error handling

2. **Keep AWS CLI as backup**
   - Don't remove AWS CLI config
   - Document rollback procedures
   - Test rollback process

3. **Monitor performance**
   - Save comparison results
   - Track performance over time
   - Alert on degradation

4. **Document your decision**
   - Record why you chose s5cmd or AWS CLI
   - Document configuration choices
   - Update runbooks

## Additional Resources

- [AWS CLI Script](../../scripts/datasync-awscli.sh)
- [s5cmd Script](../../scripts/datasync-s5cmd.sh)
- [Performance Guide](../../docs/PERFORMANCE.md)
- [Troubleshooting](../../docs/TROUBLESHOOTING.md)
- [Migration Guide](../../docs/MIGRATION.md)

## Examples

- [Basic Example](../basic/) - Simple s5cmd setup
- [Production Example](../production/) - Enterprise deployment

## License

MIT License - See [LICENSE](../../LICENSE) for details.
