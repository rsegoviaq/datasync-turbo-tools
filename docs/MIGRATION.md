# Migration Guide

Step-by-step guide for migrating from AWS CLI to s5cmd.

## Table of Contents

- [Migration Overview](#migration-overview)
- [Pre-Migration Checklist](#pre-migration-checklist)
- [Migration Strategies](#migration-strategies)
- [Step-by-Step Migration](#step-by-step-migration)
- [Configuration Mapping](#configuration-mapping)
- [Testing and Validation](#testing-and-validation)
- [Rollback Plan](#rollback-plan)
- [Post-Migration](#post-migration)
- [Common Migration Issues](#common-migration-issues)

---

## Migration Overview

### Why Migrate?

**Performance Gains:**
- 5-12x faster uploads
- 95%+ network utilization
- Lower CPU and memory usage

**Typical Results:**
- 150 GB upload: 8 min → 2 min (6 min saved)
- 500 GB daily: 2 hours → 20 min (1h 40min saved)
- Annual time savings: 35-600 hours

### Migration Effort

| Current Setup | Effort | Time | Risk |
|--------------|--------|------|------|
| Simple sync scripts | Low | 1-2 hours | Low |
| Complex workflows | Medium | 4-8 hours | Medium |
| Integrated systems | High | 1-2 days | Medium |

### Compatibility

✅ **Compatible:**
- Basic `aws s3 sync` commands
- Environment variable configuration
- IAM roles and credentials
- S3 storage classes
- Multipart uploads
- Server-side encryption

⚠️ **May require changes:**
- Advanced AWS CLI features
- Custom error handling
- Monitoring and alerting
- CI/CD integrations

❌ **Not compatible:**
- CloudFront invalidation (use AWS CLI separately)
- S3 Select queries
- Lambda triggers (configure in S3)
- Cross-service AWS operations

---

## Pre-Migration Checklist

### 1. Assessment

- [ ] Document current upload workflows
- [ ] Identify all scripts using AWS CLI for S3
- [ ] List required features (checksums, storage classes, etc.)
- [ ] Measure current performance (throughput, time)
- [ ] Check for AWS-specific integrations

### 2. Requirements

- [ ] Network bandwidth available (>= 100 Mbps for benefits)
- [ ] System resources adequate (CPU, memory, disk)
- [ ] AWS credentials configured
- [ ] S3 buckets accessible
- [ ] Approval for new tool installation

### 3. Testing Environment

- [ ] Non-production S3 bucket for testing
- [ ] Test data prepared (sample of production data)
- [ ] Baseline measurements recorded
- [ ] Rollback plan documented

### 4. Stakeholder Alignment

- [ ] Team informed of migration
- [ ] Change management process followed
- [ ] Monitoring team notified
- [ ] Rollback procedures communicated

---

## Migration Strategies

### Strategy 1: Parallel Deployment (Recommended)

**Timeline:** 1-2 weeks

**Approach:**
1. Deploy s5cmd alongside AWS CLI
2. Run both in parallel for validation
3. Compare results and performance
4. Gradually shift workloads to s5cmd
5. Decommission AWS CLI when confident

**Pros:**
- Low risk (both tools available)
- Easy rollback
- Gradual transition
- Time to build confidence

**Cons:**
- Longer migration period
- More monitoring required
- Temporary dual maintenance

### Strategy 2: Phased Migration

**Timeline:** 2-4 weeks

**Approach:**
1. Migrate non-critical workloads first
2. Monitor and validate
3. Migrate medium-priority workloads
4. Finally migrate critical workloads

**Pros:**
- Risk minimized
- Learn from each phase
- Gradual team adoption
- Controlled rollout

**Cons:**
- Longest timeline
- Complex tracking
- Partial benefits during migration

### Strategy 3: Direct Cutover

**Timeline:** 1-3 days

**Approach:**
1. Test thoroughly in non-production
2. Schedule maintenance window
3. Switch all workloads simultaneously
4. Monitor closely

**Pros:**
- Fastest migration
- Immediate full benefits
- Simpler process

**Cons:**
- Higher risk
- Requires confidence
- Less time to adapt
- Rollback more disruptive

---

## Step-by-Step Migration

### Phase 1: Installation and Setup

**Step 1.1: Install s5cmd**

```bash
# On all systems that upload to S3
cd /path/to/install/location
git clone https://github.com/your-org/datasync-turbo-tools.git
cd datasync-turbo-tools
./tools/install-s5cmd.sh
```

**Step 1.2: Verify Installation**

```bash
# Run verification tests
./tools/verify-installation.sh

# Expected output:
# [PASS] s5cmd is installed
# [PASS] AWS credentials configured
# [PASS] S3 bucket accessible
```

**Step 1.3: Create Configuration**

```bash
# Copy your existing AWS CLI config
cp your-existing-config.env config/s5cmd.env

# Convert AWS CLI vars to s5cmd vars (see mapping below)
nano config/s5cmd.env
```

### Phase 2: Testing

**Step 2.1: Dry-Run Test**

```bash
# Test with dry-run (no actual upload)
./scripts/datasync-s5cmd.sh --dry-run

# Verify:
# - Configuration loads correctly
# - Source directory detected
# - S3 bucket accessible
# - No errors
```

**Step 2.2: Small Test Upload**

```bash
# Create test data
mkdir -p /tmp/test-migration
dd if=/dev/urandom of=/tmp/test-migration/test-1gb.bin bs=1M count=1000

# Upload with s5cmd
SOURCE_DIR="/tmp/test-migration" \
S3_BUCKET="your-test-bucket" \
S3_SUBDIRECTORY="s5cmd-test/$(date +%Y%m%d)" \
./scripts/datasync-s5cmd.sh

# Verify upload successful
aws s3 ls s3://your-test-bucket/s5cmd-test/
```

**Step 2.3: Compare with AWS CLI**

```bash
# Upload same data with AWS CLI
aws s3 sync /tmp/test-migration s3://your-test-bucket/awscli-test/

# Compare results
./tools/benchmark.sh

# Check:
# - File count matches
# - File sizes match
# - Checksums match (if enabled)
# - Performance improvement measured
```

### Phase 3: Parallel Deployment

**Step 3.1: Deploy to Non-Production**

```bash
# Update non-prod scripts to use s5cmd
# Keep AWS CLI commands commented as backup

# Example script update:
#!/bin/bash

# OLD (AWS CLI)
# aws s3 sync /data s3://bucket/prefix/

# NEW (s5cmd)
SOURCE_DIR="/data" \
S3_BUCKET="bucket" \
S3_SUBDIRECTORY="prefix" \
/opt/datasync-turbo-tools/scripts/datasync-s5cmd.sh
```

**Step 3.2: Monitor for 1 Week**

```bash
# Check logs daily
tail -f /path/to/datasync-turbo-tools/logs/*.log

# Parse JSON output for metrics
jq '{status, throughput_mbps, files_synced}' logs/datasync-s5cmd-*.json

# Compare with previous AWS CLI performance
# - Upload times
# - Throughput
# - Error rates
# - System resource usage
```

**Step 3.3: Validate Results**

```bash
# Run validation tests
./tests/unit-tests.sh
./tests/checksum-validation.sh

# Spot-check random files
./scripts/verify-uploads.sh
```

### Phase 4: Production Migration

**Step 4.1: Gradual Production Rollout**

**Week 1: Low-Priority Workloads**
```bash
# Migrate non-critical background uploads
# Example: log backups, staging data
```

**Week 2: Medium-Priority Workloads**
```bash
# Migrate regular data uploads
# Example: daily backups, batch processing
```

**Week 3: High-Priority Workloads**
```bash
# Migrate critical uploads
# Example: production data, customer data
```

**Step 4.2: Update Cron Jobs**

```bash
# Edit crontab
crontab -e

# OLD:
# 0 2 * * * /scripts/aws-cli-upload.sh

# NEW:
# 0 2 * * * cd /opt/datasync-turbo-tools && ./scripts/datasync-s5cmd.sh
```

**Step 4.3: Update Systemd Services**

```bash
# Update service file
sudo nano /etc/systemd/system/datasync.service

# Change ExecStart to use s5cmd script
ExecStart=/opt/datasync-turbo-tools/scripts/datasync-s5cmd.sh

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart datasync.service
```

**Step 4.4: Update CI/CD Pipelines**

```yaml
# Example: GitHub Actions
- name: Upload to S3
  run: |
    cd datasync-turbo-tools
    SOURCE_DIR=${{ github.workspace }}/build \
    S3_BUCKET=${{ secrets.S3_BUCKET }} \
    ./scripts/datasync-s5cmd.sh
```

### Phase 5: Monitoring and Optimization

**Step 5.1: Set Up Monitoring**

```bash
# Monitor upload metrics
watch -n 60 'jq ".throughput_mbps" logs/datasync-s5cmd-*.json | tail -10'

# Alert on failures
./scripts/check-upload-status.sh

# Track performance trends
./scripts/generate-performance-report.sh
```

**Step 5.2: Performance Tuning**

```bash
# Based on observed performance, tune:
export S5CMD_CONCURRENCY="128"  # Adjust based on network
export S5CMD_PART_SIZE="128MB"   # Adjust based on file sizes

# Re-test and measure
./tools/benchmark.sh
```

### Phase 6: Decommission AWS CLI

**Step 6.1: Remove AWS CLI Scripts** (after 2+ weeks success)

```bash
# Archive old scripts
mkdir -p ~/archive/old-aws-cli-scripts
mv /scripts/aws-cli-*.sh ~/archive/old-aws-cli-scripts/

# Remove from cron
crontab -e
# Comment out or remove AWS CLI jobs
```

**Step 6.2: Update Documentation**

- Update runbooks
- Update deployment guides
- Update team wiki
- Update monitoring dashboards

**Step 6.3: Team Training**

- Conduct training session on s5cmd
- Share documentation (S5CMD_GUIDE.md)
- Create quick reference cards
- Set up support channels

---

## Configuration Mapping

### AWS CLI → s5cmd Variable Mapping

| AWS CLI Variable | s5cmd Equivalent | Notes |
|-----------------|------------------|-------|
| `SOURCE_DIR` | `SOURCE_DIR` | Same |
| `S3_BUCKET` | `S3_BUCKET` | Same (no s3:// prefix) |
| `S3_PREFIX` | `S3_SUBDIRECTORY` | Renamed |
| `AWS_PROFILE` | `AWS_PROFILE` | Same |
| `AWS_MAX_CONCURRENT_REQUESTS` | `S5CMD_CONCURRENCY` | Different range |
| `AWS_MAX_QUEUE_SIZE` | N/A | Not applicable |
| N/A | `S5CMD_PART_SIZE` | New setting |
| N/A | `S5CMD_NUM_WORKERS` | New setting |
| N/A | `S5CMD_CHECKSUM` | New setting |
| `S3_STORAGE_CLASS` | `S3_STORAGE_CLASS` | Same |

### Command Mapping

| AWS CLI Command | s5cmd Equivalent |
|----------------|------------------|
| `aws s3 sync /src s3://bucket/` | `s5cmd sync /src/ s3://bucket/` |
| `aws s3 cp file s3://bucket/` | `s5cmd cp file s3://bucket/` |
| `aws s3 ls s3://bucket/` | `s5cmd ls s3://bucket/` |
| `aws s3 rm s3://bucket/file` | `s5cmd rm s3://bucket/file` |
| `aws s3 mb s3://bucket` | Use AWS CLI |
| `aws s3 rb s3://bucket` | Use AWS CLI |

### Configuration File Example

**Before (AWS CLI):**

```bash
# awscli-config.env
SOURCE_DIR="/data/uploads"
S3_BUCKET="my-backup-bucket"
S3_PREFIX="backups/daily"
AWS_PROFILE="production"
AWS_MAX_CONCURRENT_REQUESTS="20"
AWS_MAX_QUEUE_SIZE="10000"
S3_STORAGE_CLASS="INTELLIGENT_TIERING"
```

**After (s5cmd):**

```bash
# s5cmd.env
SOURCE_DIR="/data/uploads"
S3_BUCKET="my-backup-bucket"
S3_SUBDIRECTORY="backups/daily"
AWS_PROFILE="production"
S5CMD_CONCURRENCY="64"
S5CMD_NUM_WORKERS="32"
S5CMD_PART_SIZE="64MB"
S5CMD_CHECKSUM="CRC64NVME"
S3_STORAGE_CLASS="INTELLIGENT_TIERING"
```

---

## Testing and Validation

### Test Plan

**1. Functional Testing**

```bash
# Test basic upload
./scripts/datasync-s5cmd.sh

# Test dry-run
./scripts/datasync-s5cmd.sh --dry-run

# Test with custom config
./scripts/datasync-s5cmd.sh --config config/test.env

# Test error handling
SOURCE_DIR=/nonexistent ./scripts/datasync-s5cmd.sh
```

**2. Performance Testing**

```bash
# Run benchmark
./tools/benchmark.sh

# Expected: 5-12x improvement over AWS CLI
```

**3. Data Integrity Testing**

```bash
# Upload test files
SOURCE_DIR=/test-data S3_BUCKET=test ./scripts/datasync-s5cmd.sh

# Download and verify
s5cmd cp s3://test/\* /tmp/downloaded/
diff -r /test-data /tmp/downloaded

# Check checksums
./tests/checksum-validation.sh
```

**4. Load Testing**

```bash
# Test with large dataset
SOURCE_DIR=/large-dataset ./scripts/datasync-s5cmd.sh

# Monitor:
# - CPU usage (should be < 70%)
# - Memory usage (should be < 80%)
# - Network utilization (should be > 90%)
# - No errors in logs
```

### Validation Checklist

- [ ] All test files uploaded successfully
- [ ] File count matches (source vs S3)
- [ ] File sizes match
- [ ] Checksums verified (if enabled)
- [ ] Performance improvement confirmed (5x+ faster)
- [ ] No errors in logs
- [ ] System resources within limits
- [ ] Monitoring alerts working
- [ ] Team comfortable with new tool

---

## Rollback Plan

### When to Rollback

Rollback if:
- Critical functionality not working
- Performance worse than AWS CLI
- Data integrity issues
- System instability
- Team not ready

### Rollback Procedure

**1. Immediate Rollback (Production Issues)**

```bash
# Switch back to AWS CLI
crontab -e
# Uncomment AWS CLI commands
# Comment out s5cmd commands

# Restart services
sudo systemctl restart datasync-awscli.service
```

**2. Gradual Rollback**

```bash
# Revert one workload at a time
# Test stability
# Continue if needed
```

**3. Communication**

- Notify team of rollback
- Document reasons
- Plan corrective actions
- Schedule retry if appropriate

---

## Post-Migration

### 1. Monitor Performance

**First Week: Daily Checks**

```bash
# Check upload success rate
jq '.status' logs/datasync-s5cmd-*.json | \
  awk '{print $1}' | sort | uniq -c

# Check average throughput
jq '.throughput_mbps' logs/datasync-s5cmd-*.json | \
  awk '{sum+=$1; count++} END {print "Average:", sum/count, "MB/s"}'
```

**First Month: Weekly Reviews**

- Review performance trends
- Check for any errors or anomalies
- Compare with pre-migration metrics
- Gather team feedback

### 2. Optimize Configuration

```bash
# Fine-tune based on real workload
# Adjust concurrency for network speed
export S5CMD_CONCURRENCY="128"

# Adjust part size for file sizes
export S5CMD_PART_SIZE="128MB"

# Re-test
./tools/benchmark.sh
```

### 3. Document Lessons Learned

- What went well?
- What could be improved?
- Unexpected issues?
- Best practices discovered?

### 4. Share Success

- Publish metrics (time saved, cost saved)
- Share with team/organization
- Update documentation
- Celebrate wins!

---

## Common Migration Issues

### Issue: Performance not as expected

**Symptoms:**
- Throughput < 3x improvement
- Network not saturated

**Solutions:**
1. Increase concurrency: `S5CMD_CONCURRENCY="128"`
2. Increase part size: `S5CMD_PART_SIZE="128MB"`
3. Check network bottlenecks
4. See [PERFORMANCE.md](PERFORMANCE.md)

### Issue: Checksum mismatches

**Symptoms:**
- Checksum verification failures
- Data integrity warnings

**Solutions:**
1. Verify source files: `sha256sum files/*`
2. Check disk health: `smartctl -a /dev/sda`
3. Try different algorithm: `S5CMD_CHECKSUM="SHA256"`
4. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Issue: High memory usage

**Symptoms:**
- OOM errors
- System swapping

**Solutions:**
1. Reduce concurrency: `S5CMD_CONCURRENCY="32"`
2. Reduce part size: `S5CMD_PART_SIZE="32MB"`
3. Add swap space
4. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#high-memory-usage--oom)

### Issue: Team resistance

**Solutions:**
1. Provide training and documentation
2. Show performance metrics
3. Gradual adoption
4. Designate champions/experts
5. Be patient

### Issue: Monitoring gaps

**Solutions:**
1. Parse JSON output for metrics
2. Set up alerts: `./scripts/alert-on-failure.sh`
3. Create dashboards
4. Update runbooks

---

## Migration Checklist

### Pre-Migration

- [ ] Assess current workflows
- [ ] Install s5cmd on all systems
- [ ] Test in non-production
- [ ] Measure baseline performance
- [ ] Get stakeholder approval

### Migration

- [ ] Create s5cmd configurations
- [ ] Run parallel deployment
- [ ] Monitor for 1+ week
- [ ] Migrate non-critical workloads
- [ ] Migrate critical workloads
- [ ] Update cron jobs/systemd
- [ ] Update CI/CD pipelines
- [ ] Update documentation

### Post-Migration

- [ ] Monitor performance daily
- [ ] Validate data integrity
- [ ] Optimize configuration
- [ ] Gather team feedback
- [ ] Document lessons learned
- [ ] Decommission AWS CLI (after success)

---

## Success Criteria

Migration is successful when:

✅ **Functionality**
- All uploads working correctly
- No data loss or corruption
- Error rate < 1%

✅ **Performance**
- 5x+ faster than AWS CLI
- Network utilization > 90%
- System resources within limits

✅ **Stability**
- Running smoothly for 2+ weeks
- No critical issues
- Team confident

✅ **Team**
- Team trained and comfortable
- Documentation complete
- Support processes established

---

## Support

### Documentation

- [Installation Guide](INSTALLATION.md)
- [Usage Guide](S5CMD_GUIDE.md)
- [Performance Tuning](PERFORMANCE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Comparison](COMPARISON.md)

### Getting Help

- **GitHub Issues:** https://github.com/your-org/datasync-turbo-tools/issues
- **Internal Support:** [your-team-slack-channel]
- **s5cmd Issues:** https://github.com/peak/s5cmd/issues

---

**Last Updated:** 2025-10-23
