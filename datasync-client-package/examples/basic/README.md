# Basic Example - Quick Start

Simple, minimal setup for quick evaluation and single-file uploads with DataSync Turbo Tools.

## Overview

This example provides the fastest way to get started with s5cmd for S3 uploads. It's perfect for:

- **Quick evaluation** of s5cmd performance
- **Single-file uploads** or small datasets
- **Learning** how the tool works
- **Testing** before production deployment

## What's Included

```
basic/
├── config.env      # Minimal configuration file
├── upload.sh       # Simple upload wrapper
└── README.md       # This file
```

## Quick Start

### 1. Install s5cmd

```bash
# From the project root
cd ../..
./tools/install-s5cmd.sh

# Verify installation
./tools/verify-installation.sh
```

### 2. Configure

Edit `config.env` and set your values:

```bash
# Required settings
export BUCKET_NAME="my-bucket"              # Your S3 bucket
export SOURCE_DIR="/path/to/your/files"     # Directory to upload

# Optional (defaults are good for most cases)
export AWS_PROFILE="default"
export AWS_REGION="us-east-1"
export S3_SUBDIRECTORY="uploads"
```

### 3. Upload

```bash
# Preview what would be uploaded
./upload.sh --dry-run

# Upload files
./upload.sh
```

## Configuration Options

### Required Settings

| Variable | Description | Example |
|----------|-------------|---------|
| `BUCKET_NAME` | S3 bucket name | `my-data-bucket` |
| `SOURCE_DIR` | Directory to upload | `/data/uploads` |

### Optional Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_PROFILE` | `default` | AWS credentials profile |
| `AWS_REGION` | `us-east-1` | AWS region |
| `S3_SUBDIRECTORY` | `uploads` | S3 key prefix |
| `S5CMD_CONCURRENCY` | `32` | Parallel operations |
| `S5CMD_PART_SIZE` | `64MB` | Multipart chunk size |
| `S5CMD_NUM_WORKERS` | `16` | Worker goroutines |

## Usage Examples

### Basic Upload

```bash
./upload.sh
```

### Preview Without Uploading

```bash
./upload.sh --dry-run
```

### Show Help

```bash
./upload.sh --help
```

## Performance Tips

For optimal performance on fast networks (1+ Gbps):

1. **Increase concurrency:**
   ```bash
   export S5CMD_CONCURRENCY="64"
   ```

2. **Increase part size for large files:**
   ```bash
   export S5CMD_PART_SIZE="128MB"
   ```

3. **Increase workers:**
   ```bash
   export S5CMD_NUM_WORKERS="32"
   ```

## Expected Performance

| Network Speed | Expected Throughput | Upload Time (1 GB) |
|--------------|--------------------|--------------------|
| 100 Mbps | 10-12 MB/s | ~85 seconds |
| 1 Gbps | 100-120 MB/s | ~8 seconds |
| 3 Gbps | 300-375 MB/s | ~3 seconds |
| 10 Gbps | 800-1200 MB/s | ~1 second |

*Actual performance depends on file sizes, network conditions, and AWS region.*

## Troubleshooting

### s5cmd not found

```bash
# Install s5cmd first
cd ../..
./tools/install-s5cmd.sh
```

### AWS credentials error

```bash
# Configure AWS credentials
aws configure

# Or use a specific profile
export AWS_PROFILE="my-profile"
```

### Source directory not found

Check that `SOURCE_DIR` in `config.env` points to an existing directory:

```bash
# Verify directory exists
ls -la /path/to/your/files
```

### Permission denied

```bash
# Make sure upload.sh is executable
chmod +x upload.sh
```

## Next Steps

Once you've tested the basic setup:

1. **Benchmark performance** - Compare with AWS CLI:
   ```bash
   cd ../..
   ./tools/benchmark.sh
   ```

2. **Production deployment** - See `examples/production/` for:
   - Monitoring and alerting
   - Log rotation
   - Advanced error handling
   - Scheduled uploads

3. **Hybrid setup** - See `examples/hybrid/` for:
   - Using both AWS CLI and s5cmd
   - Performance comparison
   - Migration strategies

## Additional Resources

- **Complete Documentation:**
  - [Installation Guide](../../docs/INSTALLATION.md)
  - [s5cmd Usage Guide](../../docs/S5CMD_GUIDE.md)
  - [Performance Tuning](../../docs/PERFORMANCE.md)
  - [Troubleshooting](../../docs/TROUBLESHOOTING.md)

- **Tools:**
  - [Verification Tool](../../tools/verify-installation.sh)
  - [Benchmark Tool](../../tools/benchmark.sh)

- **Scripts:**
  - [Main s5cmd Script](../../scripts/datasync-s5cmd.sh)
  - [AWS CLI Reference](../../scripts/datasync-awscli.sh)

## Support

For issues or questions:

1. Check [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md)
2. Review [FAQ](../../docs/TROUBLESHOOTING.md#faq)
3. Check [s5cmd documentation](https://github.com/peak/s5cmd)

## License

MIT License - See [LICENSE](../../LICENSE) for details.
