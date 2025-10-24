# Production Example - Enterprise Deployment

Comprehensive production-ready deployment of DataSync Turbo Tools with monitoring, alerting, and automated management.

## Overview

This example provides a **complete production deployment** with:

- ✅ **High-performance configuration** optimized for 3+ Gbps networks
- ✅ **Comprehensive monitoring** and health checks
- ✅ **Automated alerting** via webhook, email, or log
- ✅ **Log rotation** and management
- ✅ **Systemd service** for automated uploads
- ✅ **Security** best practices
- ✅ **Disaster recovery** procedures

Perfect for:
- **Production environments** with critical data
- **High-throughput** data pipelines (3+ Gbps)
- **Automated** scheduled uploads
- **Enterprise** deployments requiring monitoring

## Directory Structure

```
production/
├── config.env                  # Production configuration
├── deploy.sh                   # Deployment automation
├── monitoring/
│   ├── check-status.sh        # Health check script
│   └── alerts.sh              # Alert manager
├── logging/
│   └── log-rotation.conf      # Logrotate configuration
└── README.md                   # This file
```

## Quick Start

### 1. Install Dependencies

```bash
./deploy.sh --install
```

This will:
- Install s5cmd
- Verify prerequisites
- Create directories
- Configure log rotation

### 2. Configure Production Settings

Edit `config.env`:

```bash
# Required settings
export BUCKET_NAME="production-data-bucket"
export SOURCE_DIR="/data/production/uploads"

# AWS settings
export AWS_PROFILE="production"
export AWS_REGION="us-east-1"

# Performance (optimized for 3+ Gbps)
export S5CMD_CONCURRENCY="64"
export S5CMD_PART_SIZE="128MB"
export S5CMD_NUM_WORKERS="32"

# Monitoring thresholds
export MIN_THROUGHPUT_MBPS="500"
export MAX_SYNC_TIME="600"
```

### 3. Validate Configuration

```bash
./deploy.sh --validate
```

This checks:
- s5cmd installation
- AWS credentials
- S3 bucket access
- Directory permissions
- Disk space
- Monitoring scripts

### 4. Test Upload (Dry-Run)

```bash
./deploy.sh --test
```

This runs a dry-run upload to preview what would happen.

### 5. Deploy to Production

```bash
./deploy.sh --deploy
```

This will:
- Validate configuration
- Create systemd service (optional)
- Configure monitoring
- Enable automated uploads

## Configuration Guide

### Performance Settings

For **3 Gbps networks**:

```bash
export S5CMD_CONCURRENCY="64"
export S5CMD_PART_SIZE="128MB"
export S5CMD_NUM_WORKERS="32"
```

For **10 Gbps networks**:

```bash
export S5CMD_CONCURRENCY="128"
export S5CMD_PART_SIZE="256MB"
export S5CMD_NUM_WORKERS="64"
```

For **1 Gbps networks**:

```bash
export S5CMD_CONCURRENCY="32"
export S5CMD_PART_SIZE="64MB"
export S5CMD_NUM_WORKERS="16"
```

### Monitoring Configuration

```bash
# Throughput threshold (alert if below this)
export MIN_THROUGHPUT_MBPS="500"

# Max acceptable sync time (alert if exceeded)
export MAX_SYNC_TIME="600"

# Health check file (updated after each sync)
export HEALTH_CHECK_FILE="/var/run/datasync-turbo/last-sync"
```

### Alert Configuration

**Log-only alerts** (default):

```bash
export NOTIFICATION_METHOD="log"
```

**Email alerts**:

```bash
export NOTIFICATION_METHOD="email"
export ALERT_EMAIL="ops@example.com"
```

**Webhook alerts** (Slack/Discord):

```bash
export NOTIFICATION_METHOD="webhook"
export ALERT_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

**All methods**:

```bash
export NOTIFICATION_METHOD="all"
export ALERT_EMAIL="ops@example.com"
export ALERT_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### Security Configuration

**Server-side encryption**:

```bash
export S3_SERVER_SIDE_ENCRYPTION="aws:kms"
export S3_KMS_KEY_ID="arn:aws:kms:region:account:key/12345678"
```

**Checksum verification**:

```bash
export ENABLE_CHECKSUM_VERIFICATION="true"
export S5CMD_CHECKSUM_ALGORITHM="CRC64NVME"  # or SHA256
```

## Systemd Service

The deployment script can create a systemd service for automated uploads.

### Service Files

```bash
# Service unit
/etc/systemd/system/datasync-turbo.service

# Timer unit (runs hourly by default)
/etc/systemd/system/datasync-turbo.timer
```

### Managing the Service

```bash
# Start timer
sudo systemctl start datasync-turbo.timer

# Stop timer
sudo systemctl stop datasync-turbo.timer

# Check status
sudo systemctl status datasync-turbo.timer

# View logs
sudo journalctl -u datasync-turbo
```

### Customizing Schedule

Edit timer schedule:

```bash
sudo systemctl edit datasync-turbo.timer
```

Add:

```ini
[Timer]
OnCalendar=
OnCalendar=*:0/15  # Every 15 minutes
```

## Monitoring

### Health Checks

Manual check:

```bash
./monitoring/check-status.sh
```

Output includes:
- s5cmd installation status
- Last sync time
- Recent errors
- Performance metrics
- Disk space
- AWS credentials status

### Automated Monitoring

Run alerts script after each upload:

```bash
./monitoring/alerts.sh
```

This checks:
- Upload failures
- Low throughput
- Long sync times
- Low disk space
- Stale syncs

### Integration with Monitoring Systems

**Nagios/Icinga**:

```bash
# Add to Nagios commands
define command {
    command_name    check_datasync
    command_line    /path/to/production/monitoring/check-status.sh
}
```

**Prometheus**:

Export metrics from JSON logs:

```bash
# Parse latest.json for metrics
jq '.throughput_mbps, .duration_seconds' /var/log/datasync-turbo/json/latest.json
```

**CloudWatch**:

```bash
# Enable CloudWatch metrics in config.env
export ENABLE_CLOUDWATCH_METRICS="true"
export CLOUDWATCH_NAMESPACE="DataSync/Turbo"
```

## Log Management

### Log Locations

```
/var/log/datasync-turbo/
├── datasync-20250123.log       # Main logs (daily rotation)
├── json/
│   ├── latest.json             # Latest sync metadata
│   └── 20250123-140530.json    # Historical metadata
└── alerts.log                   # Alert history
```

### Log Rotation

Logs are automatically rotated by logrotate:

```bash
# Test rotation config
sudo logrotate -d /etc/logrotate.d/datasync-turbo

# Force rotation (for testing)
sudo logrotate -f /etc/logrotate.d/datasync-turbo

# View rotation status
sudo cat /var/lib/logrotate/status | grep datasync
```

### Log Retention

Default retention:
- **Main logs**: 30 days (daily rotation)
- **JSON logs**: 12 weeks (weekly rotation)
- **Alert logs**: 52 weeks (weekly rotation)

Customize retention in `logging/log-rotation.conf`:

```
rotate 90  # Keep 90 days instead of 30
```

## Performance Tuning

### Network Optimization

**TCP tuning** for high-bandwidth networks:

```bash
# Add to /etc/sysctl.conf
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Apply
sudo sysctl -p
```

### S3 Optimization

**Use S3 Transfer Acceleration**:

```bash
# Enable on bucket first
aws s3api put-bucket-accelerate-configuration \
    --bucket production-data-bucket \
    --accelerate-configuration Status=Enabled

# Update s5cmd endpoint
export S5CMD_ENDPOINT_URL="https://production-data-bucket.s3-accelerate.amazonaws.com"
```

**Use VPC endpoint** (no data transfer costs):

```bash
# Create VPC endpoint in AWS Console
# Then use internal endpoint
export S5CMD_ENDPOINT_URL="https://bucket.vpce-abc123.s3.region.vpce.amazonaws.com"
```

## Disaster Recovery

### Backup Strategy

1. **Log backups** (automated):
   ```bash
   # Logs are retained for 30 days and compressed
   # Archive to S3 for long-term storage
   aws s3 sync /var/log/datasync-turbo/ s3://backup-bucket/logs/
   ```

2. **Configuration backups**:
   ```bash
   # Backup config
   cp config.env config.env.backup-$(date +%Y%m%d)
   ```

3. **Metadata backups**:
   ```bash
   # JSON logs contain complete sync metadata
   tar -czf metadata-backup-$(date +%Y%m%d).tar.gz /var/log/datasync-turbo/json/
   ```

### Rollback Procedures

1. **Stop automated uploads**:
   ```bash
   sudo systemctl stop datasync-turbo.timer
   ```

2. **Switch back to AWS CLI**:
   ```bash
   # Use AWS CLI reference implementation
   ../../scripts/datasync-awscli.sh
   ```

3. **Restore configuration**:
   ```bash
   cp config.env.backup-20250123 config.env
   ```

### Emergency Contacts

Document your emergency procedures:

```bash
# Emergency stop
sudo systemctl stop datasync-turbo.timer

# Check what's running
ps aux | grep datasync

# Kill running uploads (if needed)
pkill -f datasync-s5cmd.sh
```

## Troubleshooting

### Upload Failures

Check logs:

```bash
# View main log
tail -f /var/log/datasync-turbo/datasync.log

# View JSON metadata
cat /var/log/datasync-turbo/json/latest.json | jq
```

Check status:

```bash
./deploy.sh --status
./monitoring/check-status.sh
```

### Low Throughput

1. **Check network utilization**:
   ```bash
   # Monitor network during upload
   iftop -i eth0
   ```

2. **Increase concurrency**:
   ```bash
   export S5CMD_CONCURRENCY="128"
   ```

3. **Check AWS throttling**:
   ```bash
   # Look for 503 errors in logs
   grep "503" /var/log/datasync-turbo/datasync.log
   ```

### High Memory Usage

Reduce concurrency:

```bash
export S5CMD_CONCURRENCY="32"
export S5CMD_NUM_WORKERS="16"
```

### Disk Space Issues

Enable cleanup:

```bash
export ENABLE_CLEANUP="true"
export CLEANUP_AGE_DAYS="7"
```

## Security Best Practices

1. **Use IAM roles** (not access keys):
   ```bash
   # Attach IAM role to EC2 instance
   # Remove AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY from config
   ```

2. **Enable encryption**:
   ```bash
   export S3_SERVER_SIDE_ENCRYPTION="aws:kms"
   export S5CMD_CHECKSUM_ALGORITHM="SHA256"
   ```

3. **Restrict bucket access**:
   ```json
   {
       "Effect": "Allow",
       "Action": ["s3:PutObject", "s3:GetObject"],
       "Resource": "arn:aws:s3:::production-data-bucket/*",
       "Condition": {
           "StringEquals": {
               "aws:SourceVpce": "vpce-abc123"
           }
       }
   }
   ```

4. **Enable versioning**:
   ```bash
   aws s3api put-bucket-versioning \
       --bucket production-data-bucket \
       --versioning-configuration Status=Enabled
   ```

## Production Checklist

Before going live:

- [ ] s5cmd installed and verified
- [ ] AWS credentials configured
- [ ] S3 bucket access tested
- [ ] Configuration reviewed
- [ ] Dry-run upload successful
- [ ] Monitoring configured
- [ ] Alerts tested
- [ ] Log rotation configured
- [ ] Systemd service created
- [ ] Backup procedures documented
- [ ] Rollback plan tested
- [ ] Emergency contacts documented
- [ ] Security audit completed
- [ ] Performance benchmarked

## Additional Resources

- [Installation Guide](../../docs/INSTALLATION.md)
- [s5cmd Guide](../../docs/S5CMD_GUIDE.md)
- [Performance Guide](../../docs/PERFORMANCE.md)
- [Troubleshooting](../../docs/TROUBLESHOOTING.md)
- [Basic Example](../basic/) - Simple setup
- [Hybrid Example](../hybrid/) - Use both AWS CLI and s5cmd

## Support

For production support:

1. Check [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md)
2. Review logs in `/var/log/datasync-turbo/`
3. Run health checks: `./monitoring/check-status.sh`
4. Check [GitHub Issues](https://github.com/peak/s5cmd/issues)

## License

MIT License - See [LICENSE](../../LICENSE) for details.
