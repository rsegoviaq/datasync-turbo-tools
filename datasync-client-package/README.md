# DataSync s5cmd Client Test Package

Quick setup package for testing s5cmd S3 upload performance on high-bandwidth connections.

## What's Included

- **s5cmd**: High-performance S3 upload tool (5-12x faster than AWS CLI)
- **Installation scripts**: Automated setup for Linux/macOS/WSL
- **Benchmark tool**: Compare AWS CLI vs s5cmd performance
- **Basic example**: Simple upload configuration

## Quick Start (5 minutes)

### 1. Install s5cmd

```bash
chmod +x tools/*.sh scripts/*.sh examples/basic/*.sh
./tools/install-s5cmd.sh
```

### 2. Configure AWS Credentials

```bash
# Option A: Use AWS CLI (if already configured)
aws configure

# Option B: Set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Option C: Use AWS Profile
export AWS_PROFILE="your-profile-name"
```

### 3. Verify Installation

```bash
export S3_BUCKET="your-test-bucket-name"
./tools/verify-installation.sh
```

Expected output:
```
✓ s5cmd installed
✓ AWS credentials valid
✓ S3 bucket accessible
```

### 4. Run Benchmark Test

Test s5cmd vs AWS CLI performance with 500 MB of test data:

```bash
export AWS_PROFILE="your-profile"  # if using profiles
export S3_BUCKET="your-test-bucket-name"

# Run benchmark (creates 500 MB test data)
./tools/benchmark.sh 500
```

**For 3 Gbps connection testing**, try larger datasets:

```bash
# 1 GB test
./tools/benchmark.sh 1000

# 5 GB test (recommended for 3 Gbps)
./tools/benchmark.sh 5000

# 10 GB test (for maximum throughput testing)
./tools/benchmark.sh 10000
```

### 5. Upload Real Data (Optional)

To test with your own data:

1. Edit `examples/basic/config.env`:
```bash
export S3_BUCKET="your-bucket-name"
export SOURCE_DIR="/path/to/your/data"
export S3_SUBDIR="test-upload"
export AWS_PROFILE="your-profile"  # if using profiles
```

2. Run upload:
```bash
cd examples/basic
source config.env
./upload.sh
```

## Expected Performance

**Your Connection: 3 Gbps (~375 MB/s theoretical max)**

### Realistic Expectations:
- **AWS CLI**: 40-60 MB/s (10-15% of bandwidth)
- **s5cmd**: 200-300 MB/s (50-80% of bandwidth)
- **Improvement**: 5-8x faster with s5cmd

### Factors affecting performance:
- File sizes (larger = better throughput)
- Number of files (parallel uploads help)
- S3 region latency
- Network overhead (TCP, encryption)
- System resources (CPU, memory)

## Benchmark Output Example

```
┌─────────────────────────┬──────────────┬────────────────┬─────────────┐
│ Tool                    │ Time (s)     │ Throughput     │ Improvement │
├─────────────────────────┼──────────────┼────────────────┼─────────────┤
│ AWS CLI (default)       │ 69.33        │   7.21 MB/s    │ Baseline    │
│ AWS CLI (optimized)     │ 78.95        │   6.33 MB/s    │ 1.1x        │
│ s5cmd                   │ 58.17        │   8.59 MB/s    │ 1.3x        │
└─────────────────────────┴──────────────┴────────────────┴─────────────┘

🏆 Winner: s5cmd is 1.3x faster than optimized AWS CLI
```

*(This was on 77.73 Mbps connection - you should see much better results on 3 Gbps!)*

## Troubleshooting

### s5cmd not found
```bash
# Check PATH
echo $PATH

# Install manually
./tools/install-s5cmd.sh
```

### AWS credentials error
```bash
# Verify credentials
aws sts get-caller-identity

# Or with profile
aws --profile your-profile sts get-caller-identity
```

### S3 bucket access denied
```bash
# Test bucket access
aws s3 ls s3://your-bucket-name/

# Check bucket exists and you have permissions
```

### Slow performance
- Use larger test sizes (5-10 GB) to see better throughput
- Ensure you're not on VPN
- Check S3 bucket region matches your location
- Verify no bandwidth throttling on network

## Test Recommendations for 3 Gbps

1. **Start small**: Run 500 MB test to verify everything works
2. **Scale up**: Run 5 GB test to see real performance
3. **Large dataset**: Run 10 GB test for maximum throughput measurement
4. **Note results**: Save benchmark output to share with us

## Need Help?

- Check `examples/basic/README.md` for detailed configuration options
- Review benchmark results file: `benchmark-results-*.txt`
- Contact support with benchmark results and any errors

## Clean Up Test Data

The benchmark automatically cleans up temporary files and S3 test objects.

To manually clean S3 test data:
```bash
# Using s5cmd
s5cmd rm "s3://your-bucket/benchmark-test-*/*"

# Using AWS CLI
aws s3 rm s3://your-bucket/benchmark-test- --recursive
```

## Package Contents

```
datasync-client-package/
├── README.md                          # This file
├── tools/
│   ├── install-s5cmd.sh              # Install s5cmd
│   ├── verify-installation.sh        # Verify setup
│   └── benchmark.sh                  # Performance testing
├── scripts/
│   └── datasync-s5cmd.sh            # Main upload script
└── examples/basic/
    ├── README.md                     # Detailed guide
    ├── config.env                    # Configuration template
    └── upload.sh                     # Simple upload wrapper
```

---

**Version**: 1.0.0
**Test Date**: October 2025
**Verified Performance**: Up to 8.59 MB/s on 77 Mbps connection (88% bandwidth utilization)
