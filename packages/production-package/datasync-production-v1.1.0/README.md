# DataSync Turbo Tools - Production Package
## Version 1.0.0

> Enterprise-ready S3 upload solution with **5-12x faster** performance than AWS CLI.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 🚀 What's Included

- ✅ **s5cmd**: High-performance S3 upload tool (5-12x faster than AWS CLI)
- ✅ **Production Configuration**: Optimized for 3+ Gbps networks
- ✅ **Monitoring & Alerts**: Health checks and status reporting
- ✅ **Automated Deployment**: Systemd integration for scheduled uploads
- ✅ **Log Management**: Automated rotation and archiving
- ✅ **Professional Documentation**: Complete guides and examples

---

## ⚡ Quick Start (5 Minutes)

### 1. Run Installer

```bash
./install.sh
```

The installer will:
- ✅ Check prerequisites
- ✅ Install s5cmd
- ✅ Create directories
- ✅ Set up configuration

### 2. Configure

Edit your settings:

```bash
nano config/production.env
```

**Required settings:**
- `AWS_PROFILE` - Your AWS profile name
- `BUCKET_NAME` - S3 bucket for uploads
- `SOURCE_DIR` - Directory to upload

### 3. Verify

Test your configuration:

```bash
./tools/verify-installation.sh
```

### 4. Test Upload (Dry-Run)

Preview what will be uploaded:

```bash
source config/production.env
./scripts/datasync-s5cmd.sh --dry-run
```

### 5. Deploy to Production

```bash
cd deployment
./deploy.sh --validate    # Validate configuration
./deploy.sh --deploy      # Deploy to production
```

---

## 📊 Expected Performance

**Your Network: 3 Gbps (~375 MB/s theoretical max)**

| Tool | Throughput | Efficiency |
|------|-----------|-----------|
| AWS CLI (default) | 40-60 MB/s | 10-15% |
| **s5cmd (this)** | **200-300 MB/s** | **50-80%** |

**Improvement: 5-8x faster with s5cmd**

---

## 📁 Package Structure

```
datasync-production-v1.0.0/
├── README.md                   # This file
├── install.sh                  # One-command installer
├── CHANGELOG.md                # Version history
├── LICENSE                     # MIT license
│
├── scripts/                    # Core scripts
│   └── datasync-s5cmd.sh      # Main upload script
│
├── tools/                      # Utilities
│   ├── install-s5cmd.sh       # s5cmd installer
│   ├── verify-installation.sh # Setup verification
│   └── benchmark.sh           # Performance testing
│
├── config/                     # Configuration
│   └── production.env.template # Production config template
│
├── deployment/                 # Deployment tools
│   ├── deploy.sh              # Production deployment
│   └── systemd/               # Systemd service files
│
├── monitoring/                 # Monitoring tools
│   ├── check-status.sh        # Health checks
│   └── alerts.sh              # Alert manager
│
└── logging/                    # Log management
    └── logrotate.conf         # Log rotation config
```

---

## 🔧 Configuration Options

### Performance Settings (High-Bandwidth Optimized)

```bash
# config/production.env

# Concurrency (64 recommended for 3+ Gbps)
S5CMD_CONCURRENCY="64"

# Part size for multipart uploads
S5CMD_PART_SIZE="128MB"

# Worker threads
S5CMD_NUM_WORKERS="32"

# Storage class
S3_STORAGE_CLASS="INTELLIGENT_TIERING"

# Checksum algorithm (CRC64NVME is fastest)
S5CMD_CHECKSUM_ALGORITHM="CRC64NVME"
```

### Monitoring & Alerts

```bash
# Health checks
ENABLE_HEALTH_CHECK="true"

# Performance thresholds
MIN_THROUGHPUT_MBPS="500"      # Alert if below 500 MB/s
MAX_SYNC_TIME="600"            # Alert if >10 minutes

# Notifications
ALERT_WEBHOOK_URL=""           # Slack/Discord webhook
ALERT_EMAIL=""                 # Email for alerts
```

---

## 📈 Monitoring

### Check Upload Status

```bash
./monitoring/check-status.sh
```

Output example:
```
DataSync Turbo Tools - Status Check
====================================

[✓] s5cmd installed: v2.3.0
[✓] Last sync: 5 minutes ago
[✓] Throughput: 285 MB/s
[✓] Duration: 245s
[✓] AWS credentials valid
[✓] Disk space: 916GB available
```

### View Logs

```bash
# Real-time logs
tail -f logs/datasync-s5cmd-*.log

# JSON logs (for log aggregation tools)
cat logs/datasync-s5cmd-*.json | jq .
```

---

## 🔄 Automated Uploads (Optional)

### Setup Systemd Service

```bash
cd deployment
./deploy.sh --deploy
```

This creates:
- **Service**: `datasync-turbo.service` - Upload script
- **Timer**: `datasync-turbo.timer` - Scheduled execution

### Manage Service

```bash
# Check status
sudo systemctl status datasync-turbo.timer

# Start timer
sudo systemctl start datasync-turbo.timer

# Stop timer
sudo systemctl stop datasync-turbo.timer

# View logs
sudo journalctl -u datasync-turbo.service -f
```

---

## 🎯 Use Cases

### One-Time Upload

```bash
source config/production.env
./scripts/datasync-s5cmd.sh
```

### Scheduled Uploads

Configure systemd timer (hourly, daily, etc.)

### Manual Trigger

```bash
cd deployment
./deploy.sh --status    # Check status
```

---

## 🔍 Troubleshooting

### s5cmd Not Found

```bash
./tools/install-s5cmd.sh
```

### AWS Credentials Error

```bash
# Verify credentials
aws sts get-caller-identity --profile your-profile

# Or set environment variables
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

### Slow Performance

Check configuration:
- Increase `S5CMD_CONCURRENCY` for more parallelism
- Increase `S5CMD_PART_SIZE` for larger files
- Verify network not throttled
- Check S3 bucket region matches your location

### Permission Denied

```bash
chmod +x scripts/*.sh tools/*.sh monitoring/*.sh deployment/*.sh
```

---

## 📝 Logging

### Log Files

- **Text logs**: `logs/datasync-s5cmd-YYYYMMDD-HHMMSS.log`
- **JSON logs**: `logs/datasync-s5cmd-YYYYMMDD-HHMMSS.json`
- **Health check**: `logs/last-sync`
- **Metrics**: `logs/metrics.json`

### Log Rotation

Automatically configured for:
- **Text logs**: Daily rotation, 30 days retention
- **JSON logs**: Weekly rotation, 12 weeks retention
- **Compression**: Enabled

---

## 🔐 Security

- ✅ Uses AWS IAM credentials (no hardcoded secrets)
- ✅ Supports AWS profiles and roles
- ✅ Checksum verification (CRC64NVME or SHA256)
- ✅ Server-side encryption (KMS supported)
- ✅ Secure log handling

---

## 📊 Benchmark Tool

Compare s5cmd vs AWS CLI:

```bash
# Test with 1 GB
./tools/benchmark.sh 1000

# Test with 5 GB (recommended for 3 Gbps)
./tools/benchmark.sh 5000

# Test with 10 GB (maximum throughput test)
./tools/benchmark.sh 10000
```

---

## 🆘 Support

For issues or questions:
1. Check logs: `logs/datasync-s5cmd-*.log`
2. Run status check: `./monitoring/check-status.sh`
3. Review configuration: `config/production.env`
4. Contact support with logs and benchmark results

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file.

---

## 🔗 Related Resources

- [s5cmd Documentation](https://github.com/peak/s5cmd)
- [AWS CLI Documentation](https://aws.amazon.com/cli/)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html)

---

**Version**: 1.0.0
**Release Date**: October 2025
**Compatibility**: Linux, macOS, WSL2

---

## ✨ What's New in v1.0.0

- 🎉 Initial production release
- ⚡ Throughput logging and monitoring
- 📊 JSON output for log aggregation
- 🔄 Automated deployment with systemd
- 📝 Comprehensive documentation
- 🛡️ Production-hardened error handling
