# s5cmd Usage Guide

Complete reference for using DataSync Turbo Tools with s5cmd.

## Table of Contents

- [Quick Start](#quick-start)
- [Command Syntax](#command-syntax)
- [Configuration](#configuration)
- [Upload Modes](#upload-modes)
- [Performance Tuning](#performance-tuning)
- [Checksum Verification](#checksum-verification)
- [Advanced Usage](#advanced-usage)
- [Integration Examples](#integration-examples)
- [Best Practices](#best-practices)

---

## Quick Start

###Basic Upload

```bash
# Using configuration file
./scripts/datasync-s5cmd.sh

# Using environment variables
SOURCE_DIR="/data/uploads" \
S3_BUCKET="my-bucket" \
./scripts/datasync-s5cmd.sh

# Dry-run (preview without uploading)
./scripts/datasync-s5cmd.sh --dry-run
```

### Quick Test

```bash
# Create test data
mkdir -p /tmp/test-upload
echo "Hello World" > /tmp/test-upload/test.txt

# Upload
SOURCE_DIR="/tmp/test-upload" \
S3_BUCKET="my-test-bucket" \
S3_SUBDIRECTORY="tests/$(date +%Y%m%d)" \
./scripts/datasync-s5cmd.sh
```

---

## Command Syntax

### Script Invocation

```bash
./scripts/datasync-s5cmd.sh [OPTIONS]
```

### Available Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview what would be uploaded (no actual upload) |
| `--config FILE` | Path to configuration file (default: `config/s5cmd.env`) |
| `--help` | Show help message |

### Examples

```bash
# Standard upload
./scripts/datasync-s5cmd.sh

# Dry-run with custom config
./scripts/datasync-s5cmd.sh --dry-run --config /path/to/config.env

# Override config with environment variables
SOURCE_DIR=/data S5CMD_CONCURRENCY=128 ./scripts/datasync-s5cmd.sh
```

---

## Configuration

### Configuration File

**Location:** `config/s5cmd.env`

```bash
# Required Settings
SOURCE_DIR="/path/to/source"
S3_BUCKET="your-bucket-name"
S3_SUBDIRECTORY="optional/prefix"

# Optional Settings
AWS_PROFILE="default"
S5CMD_CONCURRENCY="64"
S5CMD_PART_SIZE="64MB"
S5CMD_NUM_WORKERS="32"
S5CMD_RETRY_COUNT="3"
S5CMD_LOG_LEVEL="info"
S5CMD_CHECKSUM="CRC64NVME"
S3_STORAGE_CLASS="INTELLIGENT_TIERING"
```

### Configuration Variables

#### Source and Destination

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SOURCE_DIR` | Yes | - | Local directory to upload |
| `S3_BUCKET` | Yes | - | S3 bucket name (no s3:// prefix) |
| `S3_SUBDIRECTORY` | No | (empty) | S3 prefix/subdirectory |

#### AWS Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AWS_PROFILE` | No | `default` | AWS credentials profile |
| `AWS_DEFAULT_REGION` | No | (from AWS config) | AWS region |
| `AWS_ACCESS_KEY_ID` | No | (from AWS config) | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | No | (from AWS config) | AWS secret key |

#### Performance Settings

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `S5CMD_CONCURRENCY` | `64` | 1-256 | Parallel file operations |
| `S5CMD_PART_SIZE` | `64MB` | 5MB-5GB | Multipart chunk size |
| `S5CMD_NUM_WORKERS` | `32` | 1-256 | Worker goroutines |

**Tuning Guidelines:**

- **Low bandwidth (< 100 Mbps):** Concurrency 16-32, Part Size 32MB
- **Medium bandwidth (100 Mbps - 1 Gbps):** Concurrency 32-64, Part Size 64MB
- **High bandwidth (1-3 Gbps):** Concurrency 64-128, Part Size 64-128MB
- **Ultra-high bandwidth (> 3 Gbps):** Concurrency 128-256, Part Size 128-256MB

#### Reliability Settings

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `S5CMD_RETRY_COUNT` | `3` | 0-10 | Number of retry attempts |
| `S5CMD_LOG_LEVEL` | `info` | debug, info, warn, error | Logging verbosity |

#### Data Integrity

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `S5CMD_CHECKSUM` | `CRC64NVME` | `CRC64NVME`, `SHA256`, `none` | Checksum algorithm |

**Checksum Recommendations:**

- **CRC64NVME** (default): Fastest, hardware-accelerated on modern CPUs
- **SHA256**: Required for compliance (HIPAA, SOC2), slower
- **none**: Fastest, no verification (not recommended)

#### S3 Settings

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `S3_STORAGE_CLASS` | `INTELLIGENT_TIERING` | See below | S3 storage class |

**Storage Class Options:**

- `STANDARD` - Frequent access
- `INTELLIGENT_TIERING` - Automatic cost optimization (recommended)
- `STANDARD_IA` - Infrequent access
- `ONEZONE_IA` - Single AZ, infrequent access
- `GLACIER_IR` - Instant retrieval, archive
- `GLACIER` - Archive, 3-5 hour retrieval
- `DEEP_ARCHIVE` - Long-term archive, 12 hour retrieval

---

## Upload Modes

### Standard Upload

Uploads all files from source to destination:

```bash
./scripts/datasync-s5cmd.sh
```

### Dry-Run Mode

Preview what would be uploaded without actually uploading:

```bash
./scripts/datasync-s5cmd.sh --dry-run
```

**Use Cases:**
- Validate configuration
- Preview transfer size
- Test S3 access
- Verify file selection

### Incremental Sync

s5cmd automatically performs incremental sync:

- Only uploads new or modified files
- Compares file size and modification time
- Skips unchanged files
- Uses checksums for verification (if enabled)

---

## Performance Tuning

### Network Optimization

#### Concurrent Operations

```bash
# Low bandwidth (< 100 Mbps)
export S5CMD_CONCURRENCY="16"
export S5CMD_NUM_WORKERS="16"

# Medium bandwidth (100 Mbps - 1 Gbps)
export S5CMD_CONCURRENCY="64"
export S5CMD_NUM_WORKERS="32"

# High bandwidth (1-3 Gbps)
export S5CMD_CONCURRENCY="128"
export S5CMD_NUM_WORKERS="64"

# Ultra bandwidth (> 3 Gbps)
export S5CMD_CONCURRENCY="256"
export S5CMD_NUM_WORKERS="128"
```

#### Part Size Tuning

```bash
# Small files (< 10 MB average)
export S5CMD_PART_SIZE="32MB"

# Medium files (10-100 MB average)
export S5CMD_PART_SIZE="64MB"

# Large files (> 100 MB average)
export S5CMD_PART_SIZE="128MB"

# Huge files (> 1 GB average)
export S5CMD_PART_SIZE="256MB"
```

### CPU Optimization

s5cmd is CPU-efficient but checksums can be intensive:

```bash
# Maximum performance (CRC64NVME)
export S5CMD_CHECKSUM="CRC64NVME"

# Compliance (SHA256, slower)
export S5CMD_CHECKSUM="SHA256"

# No checksums (fastest, not recommended)
export S5CMD_CHECKSUM="none"
```

### Memory Optimization

Memory usage scales with concurrency:

- **Concurrency 16:** ~500 MB RAM
- **Concurrency 64:** ~1 GB RAM
- **Concurrency 128:** ~2 GB RAM
- **Concurrency 256:** ~4 GB RAM

```bash
# Low memory systems
export S5CMD_CONCURRENCY="32"
export S5CMD_NUM_WORKERS="16"

# High memory systems
export S5CMD_CONCURRENCY="256"
export S5CMD_NUM_WORKERS="128"
```

---

## Checksum Verification

### Checksum Algorithms

#### CRC64NVME (Default)

```bash
export S5CMD_CHECKSUM="CRC64NVME"
```

**Features:**
- Hardware-accelerated on modern CPUs (2017+)
- 5-10x faster than SHA256
- Excellent error detection
- Supported by S3

**Use Cases:**
- High-performance uploads
- Large file transfers
- General purpose uploads

#### SHA256

```bash
export S5CMD_CHECKSUM="SHA256"
```

**Features:**
- Cryptographically secure
- Required for some compliance standards
- Slower than CRC64NVME
- Universal support

**Use Cases:**
- HIPAA/SOC2 compliance
- Financial data
- Legal records
- Medical records

#### No Checksums

```bash
export S5CMD_CHECKSUM="none"
```

**Not Recommended** - No integrity verification

### Verifying Checksums

#### During Upload

Checksums are automatically calculated and verified during upload when enabled.

#### After Upload

Verify uploaded file integrity:

```bash
# List objects with checksums
s5cmd --checksum ls s3://bucket/prefix/

# Download and verify
s5cmd --checksum cp s3://bucket/file.dat ./downloaded/
```

---

## Advanced Usage

### Custom Configuration Files

```bash
# Production config
./scripts/datasync-s5cmd.sh --config config/production.env

# Staging config
./scripts/datasync-s5cmd.sh --config config/staging.env

# Development config
./scripts/datasync-s5cmd.sh --config config/dev.env
```

### Environment Variable Override

Configuration precedence (highest to lowest):

1. Command-line environment variables
2. Configuration file
3. Default values

```bash
# Override concurrency
S5CMD_CONCURRENCY=128 ./scripts/datasync-s5cmd.sh

# Override bucket and concurrency
S3_BUCKET=backup-bucket \
S5CMD_CONCURRENCY=256 \
./scripts/datasync-s5cmd.sh
```

### Multiple AWS Profiles

```bash
# Production profile
AWS_PROFILE=production ./scripts/datasync-s5cmd.sh

# Staging profile
AWS_PROFILE=staging ./scripts/datasync-s5cmd.sh

# Development profile
AWS_PROFILE=dev ./scripts/datasync-s5cmd.sh
```

### Cross-Region Uploads

```bash
# Upload to us-west-2
AWS_DEFAULT_REGION=us-west-2 \
S3_BUCKET=west-backup \
./scripts/datasync-s5cmd.sh

# Upload to eu-central-1
AWS_DEFAULT_REGION=eu-central-1 \
S3_BUCKET=eu-backup \
./scripts/datasync-s5cmd.sh
```

---

## Integration Examples

### Cron Job

```bash
# Add to crontab
crontab -e

# Upload every hour
0 * * * * cd /path/to/datasync-turbo-tools && ./scripts/datasync-s5cmd.sh >> /var/log/datasync.log 2>&1

# Upload daily at 2 AM
0 2 * * * cd /path/to/datasync-turbo-tools && ./scripts/datasync-s5cmd.sh

# Upload every 5 minutes
*/5 * * * * cd /path/to/datasync-turbo-tools && ./scripts/datasync-s5cmd.sh
```

### Systemd Service

Create `/etc/systemd/system/datasync.service`:

```ini
[Unit]
Description=DataSync S3 Upload
After=network.target

[Service]
Type=oneshot
User=datasync
Group=datasync
WorkingDirectory=/opt/datasync-turbo-tools
EnvironmentFile=/opt/datasync-turbo-tools/config/s5cmd.env
ExecStart=/opt/datasync-turbo-tools/scripts/datasync-s5cmd.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Create timer `/etc/systemd/system/datasync.timer`:

```ini
[Unit]
Description=DataSync Upload Timer
Requires=datasync.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable datasync.timer
sudo systemctl start datasync.timer
```

### Shell Script Wrapper

```bash
#!/bin/bash
# upload-wrapper.sh

set -euo pipefail

# Configuration
export SOURCE_DIR="/data/uploads"
export S3_BUCKET="my-backup-bucket"
export S3_SUBDIRECTORY="backups/$(date +%Y/%m/%d)"

# Run upload
cd /path/to/datasync-turbo-tools
./scripts/datasync-s5cmd.sh

# Check status
if [ $? -eq 0 ]; then
    echo "Upload successful"
    # Send success notification
else
    echo "Upload failed"
    # Send failure alert
    exit 1
fi
```

### Docker Container

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install s5cmd
RUN curl -L https://github.com/peak/s5cmd/releases/latest/download/s5cmd_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin/

# Copy datasync tools
COPY . /opt/datasync-turbo-tools
WORKDIR /opt/datasync-turbo-tools

# Run upload
CMD ["./scripts/datasync-s5cmd.sh"]
```

Build and run:

```bash
docker build -t datasync-s5cmd .
docker run -v /data:/data -e SOURCE_DIR=/data datasync-s5cmd
```

---

## Best Practices

### Configuration Management

1. **Use configuration files** for static settings
2. **Use environment variables** for dynamic overrides
3. **Keep separate configs** for dev/staging/prod
4. **Never commit AWS credentials** to version control

### Error Handling

1. **Enable retries** (`S5CMD_RETRY_COUNT=3`)
2. **Monitor log files** in `logs/` directory
3. **Check JSON output** for transfer metrics
4. **Set up alerts** for failed uploads

### Performance

1. **Start with defaults** (concurrency 64, part size 64MB)
2. **Tune for your network** based on available bandwidth
3. **Monitor CPU usage** - high usage may need lower concurrency
4. **Monitor memory** - OOM errors mean too much concurrency

### Security

1. **Use IAM roles** when possible (EC2, ECS, Lambda)
2. **Restrict config file permissions** (`chmod 600 config/*.env`)
3. **Enable S3 encryption** at rest
4. **Use VPC endpoints** for private S3 access
5. **Enable CloudTrail logging** for audit trail

### Data Integrity

1. **Enable checksums** (CRC64NVME or SHA256)
2. **Test with dry-run first**
3. **Verify critical uploads** manually
4. **Enable S3 versioning** for recovery
5. **Monitor checksum failures**

### Monitoring

1. **Check log files** regularly (`logs/`)
2. **Parse JSON output** for metrics
3. **Set up alerts** for failures
4. **Track throughput** over time
5. **Monitor S3 costs** (storage, requests, transfer)

---

## Output Format

### Log Files

**Location:** `logs/datasync-s5cmd-YYYYMMDD-HHMMSS.log`

```
[INFO] 2025-10-23 14:30:00 - Loading configuration...
[INFO] 2025-10-23 14:30:00 - Source: /data/uploads
[INFO] 2025-10-23 14:30:00 - Destination: s3://my-bucket/prefix/
[INFO] 2025-10-23 14:30:01 - Upload started
[INFO] 2025-10-23 14:32:15 - Upload completed
[SUCCESS] 2025-10-23 14:32:15 - 150 files synced, 150GB transferred
```

### JSON Output

**Location:** `logs/datasync-s5cmd-YYYYMMDD-HHMMSS.json`

```json
{
    "timestamp": "2025-10-23T14:32:15-06:00",
    "duration_seconds": 125,
    "files_synced": 150,
    "bytes_transferred": 161061273600,
    "source_size": "150GB",
    "s3_objects": 150,
    "status": "success",
    "tool": "s5cmd",
    "tool_version": "v2.2.2",
    "throughput_mbps": 1200,
    "source": "/data/uploads",
    "destination": "s3://my-bucket/prefix/",
    "dry_run": false,
    "configuration": {
        "concurrency": 64,
        "part_size": "64MB",
        "num_workers": 32,
        "retry_count": 3,
        "storage_class": "INTELLIGENT_TIERING"
    },
    "checksum_verification": {
        "enabled": true,
        "algorithm": "CRC64NVME",
        "verified": true,
        "errors": 0
    }
}
```

### Parsing JSON with jq

```bash
# Get upload status
jq '.status' logs/datasync-s5cmd-*.json

# Get throughput
jq '.throughput_mbps' logs/datasync-s5cmd-*.json

# Get total bytes transferred
jq '.bytes_transferred' logs/datasync-s5cmd-*.json

# Get files synced
jq '.files_synced' logs/datasync-s5cmd-*.json

# Get checksum errors
jq '.checksum_verification.errors' logs/datasync-s5cmd-*.json
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed troubleshooting guide.

### Quick Fixes

| Problem | Solution |
|---------|----------|
| Slow uploads | Increase concurrency and workers |
| High CPU usage | Decrease concurrency, switch to CRC64NVME |
| Out of memory | Decrease concurrency and workers |
| Network timeouts | Increase retry count |
| Checksum failures | Check source file integrity, verify S3 settings |

---

## Next Steps

- **Optimize performance:** See [PERFORMANCE.md](PERFORMANCE.md)
- **Production deployment:** See [examples/production/](../examples/production/)
- **Compare with AWS CLI:** See [COMPARISON.md](COMPARISON.md)
- **Migrate from AWS CLI:** See [MIGRATION.md](MIGRATION.md)

---

**Last Updated:** 2025-10-23
