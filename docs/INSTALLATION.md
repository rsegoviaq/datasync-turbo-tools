# Installation Guide

Complete guide to installing and configuring DataSync Turbo Tools.

## Table of Contents

- [System Requirements](#system-requirements)
- [Quick Installation](#quick-installation)
- [Detailed Installation Steps](#detailed-installation-steps)
- [Configuration](#configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## System Requirements

### Minimum Requirements

- **Operating System:** Linux (x86_64 or ARM64) or macOS (Intel or Apple Silicon)
- **Disk Space:** 100 MB free space
- **Network:** Internet connection for installation and S3 uploads
- **Memory:** 512 MB RAM minimum
- **AWS:** Valid AWS credentials with S3 access

### Recommended Requirements

- **Operating System:** Ubuntu 20.04+ or macOS 12+
- **Network:** 1 Gbps or faster for optimal performance
- **Memory:** 2 GB RAM for large transfers
- **AWS:** IAM role or user with `s3:PutObject`, `s3:GetObject`, `s3:ListBucket` permissions

### Software Prerequisites

**Required:**
- AWS CLI v2.x (for awscli mode) or s5cmd v2.x+ (for s5cmd mode)
- bash 4.0 or higher
- Standard Unix utilities: `curl`, `tar`, `gzip`

**Optional:**
- `jq` - for parsing JSON output
- `bc` - for performance calculations (automatically used if available)

---

## Quick Installation

### One-Line Install

```bash
# Clone and install s5cmd
git clone https://github.com/your-org/datasync-turbo-tools.git
cd datasync-turbo-tools
./tools/install-s5cmd.sh
```

### Verify Installation

```bash
./tools/verify-installation.sh
```

---

## Detailed Installation Steps

### Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/your-org/datasync-turbo-tools.git
cd datasync-turbo-tools

# Verify structure
ls -la
# Expected: tools/, scripts/, config/, tests/, docs/, examples/
```

### Step 2: Install s5cmd (Recommended)

#### Automatic Installation (Recommended)

```bash
# Install latest version to /usr/local/bin
./tools/install-s5cmd.sh

# Or install specific version
./tools/install-s5cmd.sh v2.2.2

# Or install to custom location
./tools/install-s5cmd.sh latest ~/bin
```

#### Manual Installation

**Option 1: Download Binary**

```bash
# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Download latest release
curl -LO "https://github.com/peak/s5cmd/releases/latest/download/s5cmd_$(uname -s)_$(uname -m).tar.gz"

# Extract and install
tar -xzf s5cmd_*.tar.gz
sudo mv s5cmd /usr/local/bin/
sudo chmod +x /usr/local/bin/s5cmd

# Verify
s5cmd version
```

**Option 2: Install with Go**

```bash
go install github.com/peak/s5cmd/v2@latest
```

**Option 3: Package Manager**

```bash
# macOS with Homebrew
brew install peak/tap/s5cmd

# Linux with Snap
snap install s5cmd
```

### Step 3: Configure AWS Credentials

#### Using AWS CLI Configuration

```bash
# Configure AWS credentials (if not already configured)
aws configure
# Enter:
#   AWS Access Key ID: [your-key-id]
#   AWS Secret Access Key: [your-secret-key]
#   Default region name: [us-east-1]
#   Default output format: [json]

# Or use AWS profiles
aws configure --profile production
```

#### Using Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

#### Using IAM Roles (EC2/ECS)

If running on AWS infrastructure, no additional configuration needed - IAM roles are automatically detected.

### Step 4: Configure DataSync

#### Create Configuration File

```bash
# For s5cmd
cp config/s5cmd.env.template config/s5cmd.env

# Or for AWS CLI
cp config/awscli.env.template config/awscli.env
```

#### Edit Configuration

```bash
# Edit with your preferred editor
nano config/s5cmd.env
# OR
vim config/s5cmd.env
```

**Minimum Required Settings:**

```bash
# Source and destination
SOURCE_DIR="/path/to/your/data"
S3_BUCKET="your-bucket-name"
S3_SUBDIRECTORY="optional/prefix"

# Optional: AWS profile
AWS_PROFILE="default"
```

**Performance Tuning (Optional):**

```bash
# s5cmd performance settings
export S5CMD_CONCURRENCY="64"        # Parallel operations
export S5CMD_PART_SIZE="64MB"        # Multipart chunk size
export S5CMD_NUM_WORKERS="32"        # Worker threads
export S5CMD_CHECKSUM="CRC64NVME"    # Checksum algorithm
export S3_STORAGE_CLASS="INTELLIGENT_TIERING"
```

See [PERFORMANCE.md](PERFORMANCE.md) for detailed tuning recommendations.

---

## Configuration

### Configuration Methods

DataSync supports three configuration methods (in order of precedence):

1. **Command-line environment variables** (highest priority)
2. **Configuration file** (`config/s5cmd.env` or `config/awscli.env`)
3. **Default values** (lowest priority)

### Configuration Variables Reference

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SOURCE_DIR` | Local directory to upload | `/data/uploads` |
| `S3_BUCKET` | S3 bucket name | `my-backup-bucket` |

#### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_SUBDIRECTORY` | (empty) | S3 prefix/subdirectory |
| `AWS_PROFILE` | `default` | AWS credentials profile |
| `S5CMD_CONCURRENCY` | `64` | Parallel operations |
| `S5CMD_PART_SIZE` | `64MB` | Multipart chunk size |
| `S5CMD_NUM_WORKERS` | `32` | Worker goroutines |
| `S5CMD_RETRY_COUNT` | `3` | Retry attempts |
| `S5CMD_CHECKSUM` | `CRC64NVME` | Checksum algorithm |
| `S3_STORAGE_CLASS` | `INTELLIGENT_TIERING` | S3 storage class |

### Example Configurations

#### Basic Upload

```bash
SOURCE_DIR="/data/videos"
S3_BUCKET="video-archive"
S3_SUBDIRECTORY="2025/october"
```

#### High-Performance Upload (3+ Gbps)

```bash
SOURCE_DIR="/data/large-files"
S3_BUCKET="fast-uploads"
S5CMD_CONCURRENCY="128"
S5CMD_PART_SIZE="128MB"
S5CMD_NUM_WORKERS="64"
```

#### Compliance Upload (SHA256 checksums)

```bash
SOURCE_DIR="/data/medical-records"
S3_BUCKET="hipaa-compliant-bucket"
S5CMD_CHECKSUM="SHA256"
S3_STORAGE_CLASS="GLACIER_IR"
```

---

## Verification

### Run Installation Tests

```bash
# Comprehensive verification
./tools/verify-installation.sh

# Expected output:
# [PASS] s5cmd is installed: v2.2.2
# [PASS] AWS credentials configured
# [PASS] S3 bucket accessible
# [PASS] Scripts have correct permissions
# [PASS] All prerequisites met
```

### Manual Verification

```bash
# Check s5cmd
s5cmd version
# Expected: s5cmd version v2.2.2

# Check AWS CLI
aws --version
# Expected: aws-cli/2.x.x

# Test S3 access
s5cmd ls s3://your-bucket/
# Should list bucket contents

# Test upload script
./scripts/datasync-s5cmd.sh --help
# Should display usage information
```

### Run Test Upload (Dry-Run)

```bash
# Configure test environment
export SOURCE_DIR="/tmp/test-data"
export S3_BUCKET="your-test-bucket"

# Create test data
mkdir -p /tmp/test-data
echo "test" > /tmp/test-data/test.txt

# Dry-run test (no actual upload)
./scripts/datasync-s5cmd.sh --dry-run

# Expected: Success with "DRY RUN MODE" warning
```

---

## Troubleshooting

### Common Installation Issues

#### Issue: "s5cmd not found in PATH"

**Solution:**

```bash
# Check if s5cmd is installed
which s5cmd

# If not found, install it
./tools/install-s5cmd.sh

# Add to PATH if installed elsewhere
export PATH="$HOME/bin:$PATH"
```

#### Issue: "Permission denied"

**Solution:**

```bash
# Make scripts executable
chmod +x tools/*.sh
chmod +x scripts/*.sh
chmod +x tests/*.sh

# Or use sudo for system-wide install
sudo ./tools/install-s5cmd.sh
```

#### Issue: "AWS credentials not configured"

**Solution:**

```bash
# Configure AWS credentials
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# Or use AWS profile
export AWS_PROFILE="production"
```

#### Issue: "Cannot access S3 bucket"

**Solutions:**

1. **Check bucket exists:**
   ```bash
   aws s3 ls s3://your-bucket/
   ```

2. **Check IAM permissions:**
   - Ensure `s3:PutObject`, `s3:GetObject`, `s3:ListBucket` permissions
   - Check bucket policy allows your IAM user/role

3. **Check region:**
   ```bash
   # Specify bucket region
   export AWS_DEFAULT_REGION="us-west-2"
   ```

#### Issue: "Platform not supported"

**Supported Platforms:**
- Linux x86_64 (amd64)
- Linux ARM64 (aarch64)
- macOS Intel (x86_64)
- macOS Apple Silicon (arm64)

**Workaround for unsupported platforms:**

```bash
# Install with Go
go install github.com/peak/s5cmd/v2@latest
```

### Getting Help

- **Documentation:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **GitHub Issues:** https://github.com/your-org/datasync-turbo-tools/issues
- **s5cmd Issues:** https://github.com/peak/s5cmd/issues

---

## Next Steps

After successful installation:

1. **Configure for your environment:** Edit `config/s5cmd.env`
2. **Run test upload:** Use `--dry-run` mode first
3. **Optimize performance:** See [PERFORMANCE.md](PERFORMANCE.md)
4. **Set up monitoring:** See [examples/production/](../examples/production/)
5. **Read usage guide:** See [S5CMD_GUIDE.md](S5CMD_GUIDE.md)

---

## Uninstallation

### Remove s5cmd

```bash
# Remove binary
sudo rm /usr/local/bin/s5cmd

# Or remove from custom location
rm ~/bin/s5cmd
```

### Remove DataSync Tools

```bash
# Remove project directory
cd ~
rm -rf datasync-turbo-tools
```

### Clean Up AWS Configuration

```bash
# Remove AWS credentials (optional)
rm ~/.aws/credentials
rm ~/.aws/config
```

---

## Security Considerations

### File Permissions

```bash
# Restrict config file permissions
chmod 600 config/s5cmd.env
chmod 600 config/awscli.env

# Verify
ls -l config/*.env
# Expected: -rw------- (600)
```

### AWS Credentials

- **Never commit AWS credentials to git**
- Use IAM roles when possible (EC2, ECS, Lambda)
- Rotate credentials regularly
- Use least-privilege IAM policies
- Enable MFA for sensitive operations

### S3 Bucket Security

- Enable bucket encryption
- Enable versioning for recovery
- Use bucket policies to restrict access
- Enable CloudTrail logging
- Consider VPC endpoints for private access

---

## Supported Regions

All AWS regions are supported:

- US regions: `us-east-1`, `us-east-2`, `us-west-1`, `us-west-2`
- EU regions: `eu-west-1`, `eu-central-1`, etc.
- Asia Pacific: `ap-southeast-1`, `ap-northeast-1`, etc.
- Other regions: `ca-central-1`, `sa-east-1`, etc.
- AWS GovCloud: `us-gov-west-1`, `us-gov-east-1`
- AWS China: `cn-north-1`, `cn-northwest-1`

---

## License

MIT License - see [LICENSE](../LICENSE) file for details.

---

**Last Updated:** 2025-10-23
