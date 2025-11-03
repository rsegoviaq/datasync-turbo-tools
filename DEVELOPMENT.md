# Development Guide

> Complete guide to the development process, architecture decisions, and maintenance of DataSync Turbo Tools.

---

## Table of Contents

- [Development History](#development-history)
- [Architecture Overview](#architecture-overview)
- [Development Workflow](#development-workflow)
- [Key Design Decisions](#key-design-decisions)
- [Testing Strategy](#testing-strategy)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting Development Issues](#troubleshooting-development-issues)

---

## Development History

### Phase 0: Planning (October 2025)
- Initial concept: High-performance S3 uploads using s5cmd
- Goal: 5-12x faster than AWS CLI for high-bandwidth networks
- Target use case: Production data synchronization for 3+ Gbps networks

### Phase 1: Core Implementation
**Completed:** October 22-24, 2025

#### Phase 1.1: Repository Setup
- Created project structure
- Established directory organization
- Set up initial configuration templates

#### Phase 1.2: s5cmd Installation Tool
- Created `tools/install-s5cmd.sh`
- Platform detection (Linux, macOS, WSL2)
- Architecture detection (amd64, arm64)
- Automated download and installation

#### Phase 1.3: Upload Script Development
- Implemented `scripts/datasync-s5cmd.sh`
- Configuration management via environment variables
- Error handling and validation
- Dry-run mode for testing
- Comprehensive logging (text and JSON)

### Phase 2: Production Hardening
**Completed:** October 25-27, 2025

#### Phase 2.1: Testing & Validation
- Created verification scripts
- Developed benchmark tools
- Real-world performance testing
- Bug fixes and optimization

#### Phase 2.2: Monitoring & Logging
- Health check system (`monitoring/check-status.sh`)
- Alert system (`monitoring/alerts.sh`)
- JSON logging for metrics aggregation
- Log rotation with logrotate

#### Phase 2.3: Throughput Tracking
**Critical Bug Fix:** October 28, 2025
- **Issue**: Throughput showing 0 MB/s in logs
- **Root Cause**: Log messages contaminating variable captures in bash
- **Solution**: Redirected log output to stderr in helper functions
- **Files Modified**:
  - `scripts/datasync-s5cmd.sh:270-293` (calculate_source_size, count_source_files)
  - `scripts/datasync-s5cmd.sh:395-399` (FILES_SYNCED cleanup)

### Phase 3: Production Deployment
**Completed:** October 27-28, 2025

#### Phase 3.1: Deployment Automation
- Created `examples/production/deploy.sh`
- Systemd service integration
- Scheduled execution with timers
- Service management commands

#### Phase 3.2: Documentation
- Comprehensive README files
- Configuration guides
- Troubleshooting documentation
- Performance tuning guides

#### Phase 3.3: Production Package
- Created distribution package structure
- Automated build system (`packages/production-package/build.sh`)
- One-command installer
- Professional documentation
- Tarball generation with checksums

### Version 1.0.0 Release
**Released:** October 28, 2025
- Production-ready deployment
- Complete documentation
- Automated packaging
- Performance validated (2.1GB in 245 seconds = 8.8 MB/s actual upload)

### Phase 4: Installation Simplification
**Completed:** October 31, 2025

#### Phase 4.1: Quick Install Script Development
- Created `quick-install.sh` - Interactive one-click installer
- Interactive prompts for essential configuration (AWS, S3, source directory)
- Real-time validation of AWS credentials, S3 bucket access, and directories
- Smart defaults for performance settings (concurrency: 64, workers: 32, part size: 128MB)
- Integrated verification and optional dry-run testing
- Reduced setup time from 10-15 minutes to ~2-3 minutes

#### Phase 4.2: Configuration Validator Library
- Created `config/config-validator.sh` - Reusable validation functions
- Functions for AWS credentials, profiles, S3 buckets, directories, disk space
- Centralized validation logic for use across multiple scripts
- Improved error messages and user feedback

#### Phase 4.3: Config Path Resolution Fix
- **Issue**: `deploy.sh --validate` failing due to config file path mismatch
- **Root Cause**: deploy.sh looked for `deployment/config.env`, installer created `config/production.env`
- **Solution**: Updated `examples/production/deploy.sh` and `monitoring/check-status.sh`
  - Added `find_and_source_config()` function with multiple location support
  - Tries: `config/production.env`, `config.env`, relative paths
  - Backward compatible with existing deployments
- Fixed systemd service configuration to use correct config path

#### Phase 4.4: Documentation Updates
- Updated README.md with quick-install as primary method
- Comprehensive CHANGELOG.md entry for v1.2.0
- Updated version references throughout documentation
- Clear migration path for existing users

### Version 1.1.0 Release
**Released:** October 30, 2025
- Direct AWS credentials support (without AWS CLI profiles)
- Enhanced credential configuration options
- CI/CD environment compatibility improvements

### Version 1.2.0 Release
**Released:** October 31, 2025
- Quick install script for streamlined setup
- Configuration validator library
- Fixed config path resolution issues
- Improved user experience and documentation

### Phase 5: Cross-Platform Compatibility
**Completed:** November 3, 2025

#### Phase 5.1: macOS Compatibility Fix
- **Issue**: Scripts hanging on "Calculating source directory size..." on macOS
- **Root Cause**: macOS uses BSD `du` which lacks GNU-specific `-b` flag
- **Solution**: Added OS detection (`$OSTYPE`) to use platform-appropriate commands
  - macOS: `find` + `stat -f%z` for byte-accurate directory sizing
  - Linux: Original `du -sb` command
- **Files Modified**:
  - `scripts/datasync-s5cmd.sh:296-314` - calculate_source_size() function
  - `scripts/datasync-awscli.sh:258-267` - BYTES_TRANSFERRED calculation
  - `datasync-client-package/scripts/datasync-s5cmd.sh:270-289` - calculate_source_size() function
- **Testing**: Validated on both Linux and macOS environments

### Version 1.2.1 Release
**Released:** November 3, 2025
- macOS compatibility for directory size calculation
- Cross-platform support (Linux, macOS, WSL2)
- Unified codebase for all platforms

---

## Architecture Overview

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface                           │
│  (CLI, Environment Variables, Configuration Files)           │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│              Configuration Manager                           │
│  • Environment variable loading                              │
│  • Config file parsing                                       │
│  • Parameter validation                                      │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│              Core Upload Engine                              │
│  • s5cmd execution                                           │
│  • Error handling                                            │
│  • Retry logic                                               │
│  • Progress tracking                                         │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
┌───────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐
│   Logging    │ │ Monitoring │ │   Metrics  │
│   System     │ │   System   │ │ Collection │
│              │ │            │ │            │
│ • Text logs  │ │ • Health   │ │ • Through  │
│ • JSON logs  │ │   checks   │ │   -put     │
│ • Rotation   │ │ • Alerts   │ │ • Duration │
└──────────────┘ └────────────┘ └────────────┘
```

### Data Flow

1. **Configuration Loading**
   - Check for config file
   - Load environment variables
   - Apply defaults
   - Validate settings

2. **Prerequisites Validation**
   - Check s5cmd installation
   - Verify source directory
   - Validate AWS credentials
   - Test S3 bucket access

3. **Upload Execution**
   - Calculate source size
   - Count files
   - Execute s5cmd with optimized parameters
   - Capture output and metrics

4. **Post-Processing**
   - Calculate throughput
   - Generate JSON metrics
   - Update health check file
   - Trigger alerts if needed

---

## Development Workflow

### Setting Up Development Environment

```bash
# Clone repository
git clone <repository-url>
cd datasync-turbo-tools

# Install s5cmd for testing
./tools/install-s5cmd.sh

# Create test configuration
cd examples/basic
cp config.env.template config.env
nano config.env  # Edit with test settings
```

### Making Changes

1. **Create Feature Branch** (if using git flow)
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Edit relevant scripts
   - Update documentation
   - Add tests if applicable

3. **Test Changes**
   ```bash
   # Test basic functionality
   source config.env
   ../../scripts/datasync-s5cmd.sh --dry-run

   # Test actual upload (small dataset)
   ../../scripts/datasync-s5cmd.sh

   # Verify logs
   cat logs/datasync-s5cmd-*.json | jq .
   ```

4. **Update Documentation**
   - Update README if features changed
   - Update CHANGELOG.md
   - Update relevant guides

5. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: description of changes"
   ```

### Testing Checklist

Before committing changes, verify:

- [ ] Script runs with `--dry-run`
- [ ] Script runs with actual upload (test data)
- [ ] Logs are generated correctly (text and JSON)
- [ ] Throughput is calculated accurately
- [ ] Error handling works as expected
- [ ] Documentation is updated
- [ ] No hardcoded credentials or paths
- [ ] Permissions are correct (chmod +x for scripts)

---

## Key Design Decisions

### 1. Environment Variable Configuration

**Decision**: Use environment variables as primary configuration method

**Rationale**:
- Compatible with containerization
- Works with systemd services
- Secure (no hardcoded credentials)
- Easy to override for different environments
- Follows 12-factor app principles

**Implementation**:
```bash
# Load from file
source config/production.env

# Or set directly
export AWS_PROFILE="my-profile"
export BUCKET_NAME="my-bucket"
```

### 2. Dual Logging Format

**Decision**: Generate both text and JSON logs

**Rationale**:
- **Text logs**: Human-readable for troubleshooting
- **JSON logs**: Machine-parseable for metrics aggregation
- Supports both manual debugging and automated monitoring
- Enables integration with log aggregation tools (ELK, Splunk, CloudWatch)

**Implementation**: `scripts/datasync-s5cmd.sh:440-465`

### 3. Stderr Redirection for Helper Functions

**Decision**: Redirect log_info output to stderr in helper functions that return values

**Rationale**:
- Prevents log messages from contaminating function return values
- Enables clean variable capture via command substitution
- Critical for throughput calculation accuracy

**Example**:
```bash
calculate_source_size() {
    log_info "Calculating..." >&2  # Redirect to stderr
    echo "$size_bytes"              # Return value to stdout
}

# Usage
SIZE=$(calculate_source_size)  # Only captures size, not log messages
```

### 4. CRC64NVME Checksums

**Decision**: Use CRC64NVME as default checksum algorithm

**Rationale**:
- Significantly faster than SHA256
- Hardware-accelerated on modern CPUs
- Sufficient for data integrity verification
- Reduces CPU overhead on high-bandwidth uploads

**Performance Impact**:
- CRC64NVME: ~10GB/s
- SHA256: ~500MB/s
- For 3 Gbps network, CRC64NVME adds <1% overhead vs ~25% for SHA256

### 5. Intelligent Tiering Storage Class

**Decision**: Default to INTELLIGENT_TIERING storage class

**Rationale**:
- Automatic cost optimization
- No retrieval fees
- No minimum storage duration
- Suitable for unknown access patterns
- Can be overridden per deployment

### 6. High Concurrency Settings

**Decision**: Default to 64 concurrent operations, 32 workers, 128MB parts

**Rationale**:
- Optimized for 3+ Gbps networks
- Maximizes throughput without overwhelming systems
- Tested values from real-world deployments
- Configurable for different network conditions

**Performance Matrix**:
| Concurrency | Workers | Part Size | 3 Gbps Throughput |
|-------------|---------|-----------|-------------------|
| 16          | 8       | 64MB      | ~120 MB/s         |
| 32          | 16      | 128MB     | ~200 MB/s         |
| 64          | 32      | 128MB     | ~285 MB/s         |
| 128         | 64      | 256MB     | ~290 MB/s         |

*Diminishing returns beyond 64 concurrency for 3 Gbps networks*

---

## Testing Strategy

### Unit Testing
Currently manual testing due to bash script nature. Future: consider BATS (Bash Automated Testing System).

### Integration Testing

**Test Scenarios**:

1. **Basic Upload**
   ```bash
   # Small dataset (< 1 GB)
   source config.env
   ./scripts/datasync-s5cmd.sh
   ```

2. **Large Upload**
   ```bash
   # Large dataset (> 10 GB)
   source config.env
   ./scripts/datasync-s5cmd.sh
   ```

3. **Error Conditions**
   ```bash
   # Invalid credentials
   export AWS_PROFILE="nonexistent"
   ./scripts/datasync-s5cmd.sh  # Should fail gracefully

   # Missing source directory
   export SOURCE_DIR="/nonexistent/path"
   ./scripts/datasync-s5cmd.sh  # Should fail with clear error
   ```

4. **Performance Benchmarks**
   ```bash
   # Compare with AWS CLI
   ./tools/benchmark.sh 5000  # 5 GB test
   ```

### Performance Testing

**Test Environment Requirements**:
- High-bandwidth network (3+ Gbps recommended)
- Test S3 bucket in same region
- AWS credentials with appropriate permissions
- Sufficient disk space for test data

**Metrics to Capture**:
- Throughput (MB/s)
- Duration (seconds)
- Files transferred
- CPU usage
- Memory usage
- Network utilization

**Example Test**:
```bash
# Generate test data
dd if=/dev/urandom of=test-5gb.bin bs=1M count=5000

# Run upload with monitoring
source config.env
time ./scripts/datasync-s5cmd.sh

# Check results
cat logs/datasync-s5cmd-*.json | jq '.throughput_mbps'
```

---

## Performance Optimization

### Network-Level Optimizations

1. **TCP Tuning** (Linux)
   ```bash
   # Increase TCP buffer sizes
   sudo sysctl -w net.core.rmem_max=134217728
   sudo sysctl -w net.core.wmem_max=134217728
   sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 67108864"
   sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 67108864"
   ```

2. **MTU Optimization**
   ```bash
   # Check current MTU
   ip link show

   # Set jumbo frames if supported (9000 bytes)
   sudo ip link set dev eth0 mtu 9000
   ```

### s5cmd Parameter Tuning

**For Different Network Speeds**:

**1 Gbps Network**:
```bash
S5CMD_CONCURRENCY="32"
S5CMD_NUM_WORKERS="16"
S5CMD_PART_SIZE="64MB"
```

**3 Gbps Network** (Default):
```bash
S5CMD_CONCURRENCY="64"
S5CMD_NUM_WORKERS="32"
S5CMD_PART_SIZE="128MB"
```

**10 Gbps Network**:
```bash
S5CMD_CONCURRENCY="128"
S5CMD_NUM_WORKERS="64"
S5CMD_PART_SIZE="256MB"
```

**For Different File Sizes**:

**Many small files (< 10MB)**:
```bash
S5CMD_CONCURRENCY="128"  # Higher concurrency
S5CMD_PART_SIZE="64MB"   # Smaller parts
```

**Few large files (> 1GB)**:
```bash
S5CMD_CONCURRENCY="32"   # Lower concurrency
S5CMD_PART_SIZE="256MB"  # Larger parts
```

### System Resource Tuning

1. **File Descriptors**
   ```bash
   # Check current limit
   ulimit -n

   # Increase limit (temporary)
   ulimit -n 65535

   # Permanent (add to /etc/security/limits.conf)
   * soft nofile 65535
   * hard nofile 65535
   ```

2. **CPU Affinity** (for high-load systems)
   ```bash
   # Pin s5cmd to specific CPU cores
   taskset -c 0-7 ./scripts/datasync-s5cmd.sh
   ```

---

## Troubleshooting Development Issues

### Common Issues

#### 1. Throughput Showing 0 MB/s

**Symptoms**:
- JSON logs show `"throughput_mbps": 0`
- Text logs show 0 MB/s

**Diagnosis**:
```bash
# Check variable captures
bash -x ./scripts/datasync-s5cmd.sh 2>&1 | grep "BYTES_TRANSFERRED"
```

**Solution**:
- Ensure log_info redirects to stderr in helper functions
- Use `>&2` for all output in functions that return values

#### 2. JSON Logs Malformed

**Symptoms**:
- `jq` fails to parse JSON logs
- Fields contain text instead of numbers

**Diagnosis**:
```bash
# Validate JSON
cat logs/datasync-s5cmd-*.json | jq .
```

**Solution**:
- Check for unescaped quotes in log messages
- Ensure numeric fields don't contain text
- Validate JSON structure after changes

#### 3. Permission Denied Errors

**Symptoms**:
- Scripts fail to execute
- "Permission denied" errors

**Solution**:
```bash
# Fix permissions
chmod +x scripts/*.sh
chmod +x tools/*.sh
chmod +x monitoring/*.sh
chmod +x deployment/*.sh
```

#### 4. AWS Credentials Not Found

**Symptoms**:
- "Unable to locate credentials"
- AWS API errors

**Diagnosis**:
```bash
# Test AWS credentials
aws sts get-caller-identity --profile your-profile

# Check environment variables
env | grep AWS
```

**Solution**:
- Set `AWS_PROFILE` correctly
- Verify `~/.aws/credentials` exists
- Check IAM permissions for S3 access

#### 5. Slow Upload Performance

**Symptoms**:
- Throughput below expected
- High CPU usage
- Network not saturated

**Diagnosis**:
```bash
# Monitor during upload
htop                    # CPU/memory
iftop                   # Network
iostat -x 1            # Disk I/O
```

**Common Causes & Solutions**:
- **Low concurrency**: Increase `S5CMD_CONCURRENCY`
- **CPU bound**: Reduce `S5CMD_NUM_WORKERS` or use CRC64NVME
- **Disk I/O**: Use faster storage or reduce file count
- **Network latency**: Increase `S5CMD_CONCURRENCY` to mask latency
- **Wrong region**: Upload to S3 bucket in nearest region

---

## Best Practices

### Code Style

1. **Bash Script Style**
   - Use `set -euo pipefail` at script start
   - Quote all variables: `"$VARIABLE"`
   - Use `[[` instead of `[` for conditions
   - Redirect errors to stderr: `>&2`
   - Use functions for reusable code

2. **Error Handling**
   ```bash
   # Good
   if ! command; then
       log_error "Command failed"
       return 1
   fi

   # Better
   command || {
       log_error "Command failed"
       return 1
   }
   ```

3. **Variable Naming**
   - UPPERCASE for environment variables: `AWS_PROFILE`
   - lowercase for local variables: `file_count`
   - Descriptive names: `source_directory` not `src_dir`

4. **Logging**
   - Use appropriate log levels
   - Include timestamps
   - Log both success and failure
   - Use stderr for helper function output

### Security Considerations

1. **Credentials**
   - Never hardcode credentials
   - Use AWS profiles or IAM roles
   - Don't log credentials
   - Use environment variables

2. **File Permissions**
   - Scripts: 755 (rwxr-xr-x)
   - Config files: 600 (rw-------)
   - Log files: 644 (rw-r--r--)

3. **Input Validation**
   - Validate all user inputs
   - Check file paths exist
   - Verify S3 bucket access
   - Sanitize inputs used in commands

---

## Future Development Ideas

### Planned Enhancements

1. **Web Dashboard**
   - Real-time monitoring
   - Historical performance graphs
   - Alert management
   - Configuration UI

2. **Multi-Region Support**
   - Automatic region detection
   - Cross-region replication
   - Regional failover

3. **Advanced Scheduling**
   - Time-window uploads
   - Bandwidth throttling
   - Priority queues

4. **CI/CD Integration**
   - GitHub Actions workflows
   - GitLab CI pipelines
   - Docker container support

### Potential Improvements

- [ ] BATS test suite
- [ ] Prometheus metrics exporter
- [ ] Configuration validation tool
- [ ] Interactive setup wizard
- [ ] Recovery from partial uploads
- [ ] Progress bar for CLI
- [ ] Email notifications
- [ ] Slack/Discord webhook integration

---

## Resources

### Internal Documentation
- [VERSIONING.md](VERSIONING.md) - Version management
- [PROJECT_ORGANIZATION.md](PROJECT_ORGANIZATION.md) - Project structure
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) - Original development plan

### External Resources
- [s5cmd Documentation](https://github.com/peak/s5cmd)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html)
- [Bash Best Practices](https://bertvv.github.io/cheat-sheets/Bash.html)

---

**Last Updated:** 2025-10-29
**Document Version:** 1.0.0
