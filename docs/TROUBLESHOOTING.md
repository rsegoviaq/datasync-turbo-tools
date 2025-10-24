# Troubleshooting Guide

Solutions to common issues and errors with DataSync Turbo Tools.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Configuration Issues](#configuration-issues)
- [AWS Authentication Issues](#aws-authentication-issues)
- [S3 Access Issues](#s3-access-issues)
- [Performance Issues](#performance-issues)
- [Upload Failures](#upload-failures)
- [Checksum Errors](#checksum-errors)
- [Network Issues](#network-issues)
- [System Resource Issues](#system-resource-issues)
- [Common Error Messages](#common-error-messages)
- [FAQ](#faq)

---

## Installation Issues

### s5cmd not found in PATH

**Error:**
```
[ERROR] s5cmd not found in PATH
```

**Solutions:**

1. **Install s5cmd:**
   ```bash
   ./tools/install-s5cmd.sh
   ```

2. **Check installation:**
   ```bash
   which s5cmd
   s5cmd version
   ```

3. **Add to PATH:**
   ```bash
   # If installed in custom location
   export PATH="$HOME/bin:$PATH"

   # Make permanent
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

### Platform not supported

**Error:**
```
Unsupported architecture: armv7l
```

**Solutions:**

1. **Install with Go** (if available):
   ```bash
   go install github.com/peak/s5cmd/v2@latest
   ```

2. **Build from source:**
   ```bash
   git clone https://github.com/peak/s5cmd.git
   cd s5cmd
   go build
   sudo mv s5cmd /usr/local/bin/
   ```

3. **Use AWS CLI instead:**
   ```bash
   ./scripts/datasync-awscli.sh
   ```

### Permission denied during installation

**Error:**
```
mv: cannot move 's5cmd' to '/usr/local/bin/s5cmd': Permission denied
```

**Solutions:**

1. **Use sudo:**
   ```bash
   sudo ./tools/install-s5cmd.sh
   ```

2. **Install to user directory:**
   ```bash
   ./tools/install-s5cmd.sh latest ~/bin
   export PATH="$HOME/bin:$PATH"
   ```

### Checksum verification failed

**Error:**
```
Checksum mismatch for downloaded s5cmd binary
```

**Solutions:**

1. **Retry download:**
   ```bash
   rm /tmp/s5cmd*
   ./tools/install-s5cmd.sh
   ```

2. **Skip checksum verification** (not recommended):
   ```bash
   # Edit install-s5cmd.sh to skip verification
   # Only for testing purposes
   ```

3. **Manual installation:**
   ```bash
   # Download and verify manually
   curl -LO https://github.com/peak/s5cmd/releases/latest/download/s5cmd_Linux_x86_64.tar.gz
   curl -LO https://github.com/peak/s5cmd/releases/latest/download/s5cmd_Linux_x86_64.tar.gz.sha256
   sha256sum -c s5cmd_Linux_x86_64.tar.gz.sha256
   tar -xzf s5cmd_Linux_x86_64.tar.gz
   sudo mv s5cmd /usr/local/bin/
   ```

---

## Configuration Issues

### Config file not found

**Error:**
```
[WARN] Config file not found: config/s5cmd.env
```

**This is a WARNING, not an error.** The script will use environment variables or defaults.

**Solutions:**

1. **Create config file:**
   ```bash
   cp config/s5cmd.env.template config/s5cmd.env
   nano config/s5cmd.env
   ```

2. **Use environment variables:**
   ```bash
   export SOURCE_DIR="/data"
   export S3_BUCKET="my-bucket"
   ./scripts/datasync-s5cmd.sh
   ```

3. **Specify config file:**
   ```bash
   ./scripts/datasync-s5cmd.sh --config /path/to/custom.env
   ```

### SOURCE_DIR not set

**Error:**
```
[ERROR] SOURCE_DIR not set
```

**Solutions:**

1. **Set in config file:**
   ```bash
   echo 'SOURCE_DIR="/path/to/data"' >> config/s5cmd.env
   ```

2. **Set as environment variable:**
   ```bash
   export SOURCE_DIR="/path/to/data"
   ./scripts/datasync-s5cmd.sh
   ```

### SOURCE_DIR does not exist

**Error:**
```
[ERROR] SOURCE_DIR does not exist: /nonexistent/path
```

**Solutions:**

1. **Create directory:**
   ```bash
   mkdir -p /path/to/source
   ```

2. **Fix typo in path:**
   ```bash
   # Check actual path
   ls -ld /path/to/data

   # Update config
   nano config/s5cmd.env
   ```

3. **Check permissions:**
   ```bash
   ls -ld /path/to/source
   # Should be readable by current user
   ```

### Invalid checksum algorithm

**Error:**
```
[ERROR] Invalid checksum algorithm: INVALID_ALGO
```

**Valid Options:**
- `CRC64NVME` (default)
- `SHA256`
- `none`

**Solution:**

```bash
export S5CMD_CHECKSUM="CRC64NVME"
./scripts/datasync-s5cmd.sh
```

---

## AWS Authentication Issues

### AWS credentials not configured

**Error:**
```
[ERROR] AWS credentials not configured
```

**Solutions:**

1. **Configure AWS CLI:**
   ```bash
   aws configure
   ```

2. **Set environment variables:**
   ```bash
   export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
   export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

3. **Use AWS profile:**
   ```bash
   export AWS_PROFILE="production"
   ./scripts/datasync-s5cmd.sh
   ```

4. **Verify credentials:**
   ```bash
   aws sts get-caller-identity
   ```

### ExpiredToken

**Error:**
```
An error occurred (ExpiredToken): The security token included in the request is expired
```

**Solutions:**

1. **Refresh temporary credentials:**
   ```bash
   # If using MFA or assumed role
   aws sts get-session-token --duration-seconds 43200

   # Update environment variables with new token
   ```

2. **Use long-term credentials:**
   ```bash
   aws configure
   # Enter long-term access key and secret
   ```

3. **Refresh IAM role** (EC2/ECS):
   ```bash
   # IAM roles automatically refresh
   # If issue persists, check IAM role attachment
   ```

### AccessDenied

**Error:**
```
An error occurred (AccessDenied): Access Denied
```

**Solutions:**

1. **Check IAM permissions:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:PutObject",
           "s3:GetObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::my-bucket/*",
           "arn:aws:s3:::my-bucket"
         ]
       }
     ]
   }
   ```

2. **Check bucket policy:**
   ```bash
   aws s3api get-bucket-policy --bucket my-bucket
   ```

3. **Check bucket ACL:**
   ```bash
   aws s3api get-bucket-acl --bucket my-bucket
   ```

4. **Verify you're using correct AWS account:**
   ```bash
   aws sts get-caller-identity
   ```

---

## S3 Access Issues

### NoSuchBucket

**Error:**
```
An error occurred (NoSuchBucket): The specified bucket does not exist
```

**Solutions:**

1. **Check bucket name:**
   ```bash
   # List all buckets
   aws s3 ls

   # Bucket names are case-sensitive and globally unique
   ```

2. **Create bucket:**
   ```bash
   aws s3 mb s3://my-bucket --region us-east-1
   ```

3. **Check region:**
   ```bash
   # Specify correct region
   export AWS_DEFAULT_REGION="us-west-2"
   ```

### BucketAlreadyOwnedByYou

**Error:**
```
An error occurred (BucketAlreadyOwnedByYou)
```

**This is usually harmless.** The bucket exists and you own it.

**Solution:**
- Continue with upload
- No action needed

### BucketNotEmpty (deletion)

**Error:**
```
An error occurred (BucketNotEmpty): The bucket you tried to delete is not empty
```

**Solutions:**

1. **Delete objects first:**
   ```bash
   aws s3 rm s3://my-bucket --recursive
   ```

2. **Force delete:**
   ```bash
   aws s3 rb s3://my-bucket --force
   ```

### RequestLimitExceeded / SlowDown

**Error:**
```
An error occurred (RequestLimitExceeded): Please reduce your request rate
```

**Solutions:**

1. **Reduce concurrency:**
   ```bash
   export S5CMD_CONCURRENCY="32"
   export S5CMD_NUM_WORKERS="16"
   ```

2. **Increase retry count:**
   ```bash
   export S5CMD_RETRY_COUNT="5"
   ```

3. **Add exponential backoff:**
   ```bash
   # s5cmd automatically retries with backoff
   # Just increase retry count
   ```

4. **Contact AWS Support** for rate limit increase (if needed)

---

## Performance Issues

### Slow upload speed

**Symptoms:**
- Throughput < 50% of expected
- Low network utilization

**Diagnostic Steps:**

1. **Test network speed:**
   ```bash
   # Test to S3
   time dd if=/dev/zero bs=1M count=1000 2>/dev/null | \
     aws s3 cp - s3://test-bucket/speedtest.bin

   # Calculate MB/s: 1000 / time_seconds
   ```

2. **Check current configuration:**
   ```bash
   # View current upload logs
   tail -50 logs/datasync-s5cmd-*.log

   # Check throughput
   jq '.throughput_mbps' logs/datasync-s5cmd-*.json
   ```

3. **Check system resources:**
   ```bash
   # CPU usage
   top

   # Memory usage
   free -h

   # Network usage
   ifstat
   ```

**Solutions:**

1. **Increase concurrency:**
   ```bash
   export S5CMD_CONCURRENCY="128"
   export S5CMD_NUM_WORKERS="64"
   ```

2. **Increase part size:**
   ```bash
   export S5CMD_PART_SIZE="128MB"
   ```

3. **Use faster checksum:**
   ```bash
   export S5CMD_CHECKSUM="CRC64NVME"
   ```

4. **Check source disk speed:**
   ```bash
   # Test disk read speed
   dd if=/dev/sda of=/dev/null bs=1M count=1000
   ```

See [PERFORMANCE.md](PERFORMANCE.md) for detailed tuning.

### High CPU usage

**Symptoms:**
- CPU > 80%
- System sluggish

**Solutions:**

1. **Reduce concurrency:**
   ```bash
   export S5CMD_CONCURRENCY="32"
   export S5CMD_NUM_WORKERS="16"
   ```

2. **Use hardware-accelerated checksum:**
   ```bash
   export S5CMD_CHECKSUM="CRC64NVME"
   ```

3. **Disable checksums** (if acceptable):
   ```bash
   export S5CMD_CHECKSUM="none"  # Not recommended
   ```

### High memory usage / OOM

**Symptoms:**
- Out of memory errors
- System swapping
- Process killed

**Solutions:**

1. **Reduce concurrency and part size:**
   ```bash
   export S5CMD_CONCURRENCY="32"
   export S5CMD_PART_SIZE="32MB"
   export S5CMD_NUM_WORKERS="16"
   ```

2. **Add swap space:**
   ```bash
   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

3. **Upgrade system RAM**

---

## Upload Failures

### Upload interrupted / killed

**Symptoms:**
- Upload stops mid-transfer
- No error message
- Process killed

**Solutions:**

1. **Check for OOM killer:**
   ```bash
   dmesg | grep -i "out of memory"
   dmesg | grep -i "killed process"
   ```

2. **Check disk space:**
   ```bash
   df -h
   ```

3. **Check network stability:**
   ```bash
   ping -c 100 s3.amazonaws.com
   # Check for packet loss
   ```

4. **Increase retry count:**
   ```bash
   export S5CMD_RETRY_COUNT="5"
   ```

5. **Resume upload:**
   ```bash
   # s5cmd sync automatically resumes
   ./scripts/datasync-s5cmd.sh
   ```

### Partial file uploads

**Symptoms:**
- Some files uploaded, others missing
- Incomplete transfer

**Solutions:**

1. **Check error logs:**
   ```bash
   grep -i error logs/datasync-s5cmd-*.log
   ```

2. **Re-run sync:**
   ```bash
   # s5cmd sync will upload missing files
   ./scripts/datasync-s5cmd.sh
   ```

3. **Verify with dry-run:**
   ```bash
   ./scripts/datasync-s5cmd.sh --dry-run
   # Check which files would be uploaded
   ```

### Connection timeout

**Error:**
```
RequestError: send request failed: dial tcp: lookup s3.amazonaws.com: i/o timeout
```

**Solutions:**

1. **Check DNS:**
   ```bash
   nslookup s3.amazonaws.com
   dig s3.amazonaws.com
   ```

2. **Check internet connectivity:**
   ```bash
   ping 8.8.8.8
   ping s3.amazonaws.com
   ```

3. **Check firewall:**
   ```bash
   # Ensure ports 80, 443 are open
   sudo iptables -L
   ```

4. **Use VPC endpoint** (if on AWS):
   ```bash
   # Configure VPC endpoint for S3
   # Reduces latency and avoids internet
   ```

---

## Checksum Errors

### Checksum mismatch

**Error:**
```
[ERROR] Checksum verification failed for file: data.bin
```

**Possible Causes:**
- File corruption during upload
- Network errors
- Disk errors

**Solutions:**

1. **Check source file integrity:**
   ```bash
   sha256sum /path/to/file
   # Compare with known good checksum
   ```

2. **Re-upload file:**
   ```bash
   # Delete from S3
   s5cmd rm s3://bucket/path/to/file

   # Re-upload
   ./scripts/datasync-s5cmd.sh
   ```

3. **Check disk health:**
   ```bash
   # Check for disk errors
   sudo dmesg | grep -i error
   sudo smartctl -a /dev/sda
   ```

4. **Try different checksum algorithm:**
   ```bash
   # Switch to SHA256
   export S5CMD_CHECKSUM="SHA256"
   ```

---

## Network Issues

### Network timeouts

**Error:**
```
RequestError: send request failed: context deadline exceeded
```

**Solutions:**

1. **Increase retry count:**
   ```bash
   export S5CMD_RETRY_COUNT="5"
   ```

2. **Check network stability:**
   ```bash
   ping -c 100 s3.amazonaws.com
   mtr s3.amazonaws.com
   ```

3. **Reduce concurrency:**
   ```bash
   export S5CMD_CONCURRENCY="32"
   ```

### Connection refused

**Error:**
```
Connection refused
```

**Solutions:**

1. **Check firewall:**
   ```bash
   sudo iptables -L
   # Ensure outbound HTTPS (443) is allowed
   ```

2. **Check proxy settings:**
   ```bash
   echo $HTTP_PROXY
   echo $HTTPS_PROXY

   # Unset if not needed
   unset HTTP_PROXY HTTPS_PROXY
   ```

3. **Check VPN/network security:**
   - Ensure S3 endpoints are accessible

### SSL/TLS errors

**Error:**
```
x509: certificate signed by unknown authority
```

**Solutions:**

1. **Update CA certificates:**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install ca-certificates

   # CentOS/RHEL
   sudo yum install ca-certificates
   sudo update-ca-trust
   ```

2. **Check system time:**
   ```bash
   date
   # Ensure time is correct (affects SSL validation)

   # Sync time
   sudo ntpdate pool.ntp.org
   ```

---

## System Resource Issues

### Disk space full

**Error:**
```
No space left on device
```

**Solutions:**

1. **Check disk space:**
   ```bash
   df -h
   ```

2. **Clean up logs:**
   ```bash
   # Archive old logs
   tar -czf logs-archive-$(date +%Y%m%d).tar.gz logs/*.log
   rm logs/*.log
   ```

3. **Clean up temp files:**
   ```bash
   rm -rf /tmp/s5cmd*
   ```

### File descriptor limits

**Error:**
```
Too many open files
```

**Solutions:**

1. **Check limits:**
   ```bash
   ulimit -n
   ```

2. **Increase limits:**
   ```bash
   # Temporary
   ulimit -n 65536

   # Permanent
   echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
   echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
   ```

3. **Reduce concurrency:**
   ```bash
   export S5CMD_CONCURRENCY="32"
   ```

---

## Common Error Messages

### "Unknown option"

**Error:**
```
[ERROR] Unknown option: --invalid-option
```

**Valid Options:**
- `--dry-run`
- `--config FILE`
- `--help`

**Solution:**
```bash
./scripts/datasync-s5cmd.sh --help
```

### "Prerequisites validation failed"

**Error:**
```
[ERROR] Prerequisites validation failed with 2 error(s)
```

**Solution:**
Review earlier error messages in the log to see which prerequisites failed.

Common prerequisites:
- s5cmd installed
- SOURCE_DIR exists
- S3_BUCKET configured
- AWS credentials valid
- S3 bucket accessible

### "DRY RUN MODE"

**Not an error!** This is informational.

```
[WARN] DRY RUN MODE - No files will be uploaded
```

**Solution:**
Remove `--dry-run` flag for actual upload:
```bash
./scripts/datasync-s5cmd.sh
```

---

## FAQ

### Q: Why is my upload slow compared to benchmarks?

**A:** Several factors affect upload speed:
1. **Network bandwidth** - Benchmarks assume high-speed networks (1-3 Gbps)
2. **Latency to S3 region** - Distance affects performance
3. **File size distribution** - Many small files are slower
4. **System resources** - CPU, memory, disk I/O
5. **Configuration** - Concurrency and part size matter

See [PERFORMANCE.md](PERFORMANCE.md) for tuning.

### Q: Can I resume an interrupted upload?

**A:** Yes! s5cmd sync automatically resumes:
```bash
# Just re-run the same command
./scripts/datasync-s5cmd.sh
```

s5cmd compares local and S3 files, uploading only what's needed.

### Q: How do I know if checksums are working?

**A:** Check JSON output:
```bash
jq '.checksum_verification' logs/datasync-s5cmd-*.json
```

Look for:
```json
{
  "enabled": true,
  "algorithm": "CRC64NVME",
  "verified": true,
  "errors": 0
}
```

### Q: Can I upload to multiple S3 buckets simultaneously?

**A:** Yes, run multiple instances:
```bash
# Terminal 1
S3_BUCKET=bucket1 ./scripts/datasync-s5cmd.sh &

# Terminal 2
S3_BUCKET=bucket2 ./scripts/datasync-s5cmd.sh &
```

### Q: Does s5cmd work with S3-compatible storage?

**A:** Yes! Use custom endpoint:
```bash
# Example: MinIO
export S3_ENDPOINT="https://minio.example.com"
s5cmd --endpoint-url $S3_ENDPOINT sync /data s3://bucket/
```

### Q: How do I monitor uploads in real-time?

**A:** Monitor log files:
```bash
tail -f logs/datasync-s5cmd-*.log
```

Or use watch:
```bash
watch -n 1 'tail -20 logs/datasync-s5cmd-*.log'
```

### Q: Can I use s5cmd with AWS GovCloud or China regions?

**A:** Yes, specify the region:
```bash
export AWS_DEFAULT_REGION="us-gov-west-1"
./scripts/datasync-s5cmd.sh
```

### Q: How do I test without uploading?

**A:** Use dry-run mode:
```bash
./scripts/datasync-s5cmd.sh --dry-run
```

### Q: What's the difference between s5cmd and AWS CLI?

**A:** See [COMPARISON.md](COMPARISON.md) for detailed comparison.

**Summary:**
- s5cmd is 5-12x faster
- Lower CPU usage
- Better concurrency
- Written in Go

---

## Getting Help

### Check Documentation

- [INSTALLATION.md](INSTALLATION.md) - Installation help
- [S5CMD_GUIDE.md](S5CMD_GUIDE.md) - Usage guide
- [PERFORMANCE.md](PERFORMANCE.md) - Performance tuning
- [COMPARISON.md](COMPARISON.md) - Tool comparison

### Enable Debug Logging

```bash
export S5CMD_LOG_LEVEL="debug"
./scripts/datasync-s5cmd.sh
```

Check logs in `logs/` directory.

### Run Verification Tests

```bash
# Check installation
./tools/verify-installation.sh

# Run unit tests
./tests/unit-tests.sh

# Test error handling
./tests/error-handling.sh
```

### Report Issues

**GitHub Issues:** https://github.com/your-org/datasync-turbo-tools/issues

Include:
- Error message (full output)
- Configuration (sanitize credentials!)
- System info (OS, architecture)
- s5cmd version: `s5cmd version`
- Steps to reproduce

### s5cmd Specific Issues

**s5cmd GitHub:** https://github.com/peak/s5cmd/issues

For s5cmd-specific bugs or feature requests.

---

**Last Updated:** 2025-10-23
