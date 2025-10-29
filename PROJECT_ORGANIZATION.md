# Project Organization

> Complete guide to the directory structure, file organization, and maintenance of DataSync Turbo Tools.

---

## Table of Contents

- [Project Structure](#project-structure)
- [Directory Details](#directory-details)
- [File Naming Conventions](#file-naming-conventions)
- [Configuration Management](#configuration-management)
- [Log Organization](#log-organization)
- [Package Structure](#package-structure)
- [Maintenance Guidelines](#maintenance-guidelines)

---

## Project Structure

### Complete Directory Tree

```
datasync-turbo-tools/
├── .release/                          # Version management
│   ├── version.txt                    # Current version (source of truth)
│   └── update-version.sh              # Version update automation (future)
│
├── packages/                          # Distribution packages
│   └── production-package/
│       ├── datasync-production-v1.0.0/      # Extracted package
│       │   ├── README.md                    # Package documentation
│       │   ├── CHANGELOG.md                 # Version history
│       │   ├── LICENSE                      # MIT license
│       │   ├── install.sh                   # One-command installer
│       │   ├── scripts/                     # Core scripts
│       │   ├── tools/                       # Utilities
│       │   ├── deployment/                  # Deployment automation
│       │   ├── monitoring/                  # Health checks & alerts
│       │   ├── logging/                     # Log management
│       │   └── config/                      # Configuration templates
│       ├── datasync-production-v1.0.0.tar.gz           # Distribution tarball
│       ├── datasync-production-v1.0.0.tar.gz.sha256    # Checksum file
│       └── build.sh                                    # Package builder
│
├── scripts/                           # Core upload scripts
│   └── datasync-s5cmd.sh             # Main s5cmd upload script
│
├── tools/                             # Utilities and helpers
│   ├── install-s5cmd.sh              # s5cmd installation tool
│   ├── verify-installation.sh         # Setup verification
│   └── benchmark.sh                   # Performance benchmarking
│
├── monitoring/                        # Health monitoring
│   ├── check-status.sh               # Status checking script
│   └── alerts.sh                      # Alert management
│
├── logging/                           # Log management
│   └── logrotate.conf                # Log rotation configuration
│
├── examples/                          # Example deployments
│   ├── basic/                        # Basic usage examples
│   │   ├── README.md                 # Basic setup guide
│   │   └── config.env.template       # Basic configuration template
│   └── production/                   # Production deployment
│       ├── README.md                 # Production deployment guide
│       ├── deploy.sh                 # Deployment automation
│       ├── config.env                # Production configuration
│       ├── monitoring/               # Production monitoring
│       ├── logging/                  # Production logging
│       └── systemd/                  # Systemd service files
│
├── docs/                              # Additional documentation
│   └── (future documentation files)
│
├── logs/                              # Log output directory
│   ├── datasync-s5cmd-YYYYMMDD-HHMMSS.log   # Text logs
│   ├── datasync-s5cmd-YYYYMMDD-HHMMSS.json  # JSON logs
│   ├── last-sync                             # Health check file
│   └── metrics.json                          # Performance metrics
│
├── DEVELOPMENT.md                     # Development guide
├── VERSIONING.md                      # Versioning strategy
├── PROJECT_ORGANIZATION.md            # This file
├── CONTRIBUTING.md                    # Contribution guidelines
├── README.md                          # Main project README
├── IMPLEMENTATION_PLAN.md             # Original development plan
├── CHANGELOG.md                       # Version history (future)
└── LICENSE                            # MIT license
```

---

## Directory Details

### Root Level

#### `.release/`
**Purpose**: Version management and release automation

- `version.txt` - Single source of truth for current version
- `update-version.sh` - Automated version update script (future)

**Usage**:
```bash
# Check current version
cat .release/version.txt

# Update version (future)
./.release/update-version.sh 1.1.0
```

#### `packages/`
**Purpose**: Distribution package creation and storage

**Structure**:
- `production-package/` - Production-ready package
  - `datasync-production-v{VERSION}/` - Extracted package directory
  - `datasync-production-v{VERSION}.tar.gz` - Distribution tarball
  - `datasync-production-v{VERSION}.tar.gz.sha256` - Checksum
  - `build.sh` - Automated package builder

**Usage**:
```bash
# Build new package
cd packages/production-package
./build.sh

# Extract package
tar xzf datasync-production-v1.0.0.tar.gz

# Verify checksum
sha256sum -c datasync-production-v1.0.0.tar.gz.sha256
```

#### `scripts/`
**Purpose**: Core functionality - main upload scripts

**Files**:
- `datasync-s5cmd.sh` - Main s5cmd upload script with comprehensive logging

**Responsibilities**:
- Configuration loading and validation
- Prerequisites checking
- S5 upload execution
- Logging (text and JSON)
- Metrics collection
- Error handling

**Usage**:
```bash
source config.env
./scripts/datasync-s5cmd.sh [--dry-run]
```

#### `tools/`
**Purpose**: Installation, verification, and utility scripts

**Files**:
- `install-s5cmd.sh` - Downloads and installs s5cmd binary
- `verify-installation.sh` - Verifies complete setup
- `benchmark.sh` - Performance comparison tool

**Usage**:
```bash
# Install s5cmd
./tools/install-s5cmd.sh

# Verify setup
./tools/verify-installation.sh

# Run benchmark (5 GB test)
./tools/benchmark.sh 5000
```

#### `monitoring/`
**Purpose**: Health checks and alert management

**Files**:
- `check-status.sh` - System health monitoring
- `alerts.sh` - Alert and notification management

**Usage**:
```bash
# Check system status
./monitoring/check-status.sh

# Configure alerts
./monitoring/alerts.sh --configure

# Test alerts
./monitoring/alerts.sh --test
```

#### `logging/`
**Purpose**: Log management configuration

**Files**:
- `logrotate.conf` - Log rotation configuration for logrotate

**Features**:
- Daily rotation for text logs
- Weekly rotation for JSON logs
- Compression after rotation
- 30-day retention for text logs
- 12-week retention for JSON logs

**Installation**:
```bash
sudo cp logging/logrotate.conf /etc/logrotate.d/datasync-turbo
```

#### `examples/`
**Purpose**: Example configurations and deployments

##### `examples/basic/`
**Purpose**: Simple, straightforward examples for learning

**Files**:
- `README.md` - Basic usage guide
- `config.env.template` - Minimal configuration template

**Use Case**: Learning, testing, development

##### `examples/production/`
**Purpose**: Production-ready deployment example

**Files**:
- `README.md` - Production deployment guide
- `deploy.sh` - Automated deployment script
- `config.env` - Production configuration
- `monitoring/` - Production monitoring scripts
- `logging/` - Production log configuration
- `systemd/` - Systemd service files

**Use Case**: Production deployments, scheduled uploads

**Features**:
- Systemd service integration
- Automated scheduling
- Health monitoring
- Alert configuration
- Log management

#### `docs/`
**Purpose**: Extended documentation (future)

**Planned Content**:
- Architecture diagrams
- API documentation
- Troubleshooting guides
- Performance tuning guides
- Security best practices

#### `logs/`
**Purpose**: Log output storage (generated at runtime)

**Files**:
- `datasync-s5cmd-YYYYMMDD-HHMMSS.log` - Human-readable text logs
- `datasync-s5cmd-YYYYMMDD-HHMMSS.json` - Machine-parseable JSON logs
- `last-sync` - Health check file (timestamp of last successful sync)
- `metrics.json` - Aggregated performance metrics

**Management**:
- Automatically rotated by logrotate
- Compressed after rotation
- Configurable retention period
- Separate retention for text vs JSON

---

## File Naming Conventions

### Scripts

**Format**: `{purpose}-{tool}.sh`

**Examples**:
- `datasync-s5cmd.sh` - DataSync upload using s5cmd
- `install-s5cmd.sh` - Install s5cmd tool
- `check-status.sh` - Check system status

**Rules**:
- Lowercase with hyphens
- Descriptive names
- `.sh` extension
- Executable permissions (755)

### Configuration Files

**Format**: `{environment}.env` or `{purpose}.conf`

**Examples**:
- `production.env` - Production environment config
- `config.env.template` - Configuration template
- `logrotate.conf` - Logrotate configuration

**Rules**:
- Lowercase with hyphens or underscores
- Environment-specific suffixes
- `.template` for templates
- Restricted permissions for secrets (600)

### Log Files

**Format**: `{purpose}-{timestamp}.{extension}`

**Examples**:
- `datasync-s5cmd-20251028-151424.log` - Text log
- `datasync-s5cmd-20251028-151424.json` - JSON log

**Timestamp Format**: `YYYYMMDD-HHMMSS` (ISO 8601 compatible, sortable)

**Rules**:
- Consistent timestamp format
- Clear purpose identifier
- Appropriate extension (.log, .json)
- Chronologically sortable

### Package Files

**Format**: `{name}-v{version}.tar.gz`

**Examples**:
- `datasync-production-v1.0.0.tar.gz`
- `datasync-production-v1.0.0.tar.gz.sha256`

**Rules**:
- Version prefix `v`
- Semantic versioning
- `.tar.gz` for tarballs
- `.sha256` for checksums

### Documentation Files

**Format**: `{TOPIC}.md` or `{topic}-guide.md`

**Examples**:
- `README.md` - Main project documentation
- `DEVELOPMENT.md` - Development guide
- `CHANGELOG.md` - Version history

**Rules**:
- UPPERCASE for major docs (README, LICENSE, CHANGELOG)
- Title case for guides (Development.md, Contributing.md)
- Markdown format (.md)
- Descriptive names

---

## Configuration Management

### Configuration Hierarchy

**Priority** (highest to lowest):

1. **Command-line arguments** (e.g., `--dry-run`)
2. **Environment variables** (e.g., `export AWS_PROFILE=prod`)
3. **Configuration file** (e.g., `source config.env`)
4. **Default values** (in script)

### Configuration Files

#### Production Configuration

**Location**: `examples/production/config.env`

**Purpose**: Production deployment settings

**Required Variables**:
```bash
AWS_PROFILE="production"           # AWS credentials profile
BUCKET_NAME="my-prod-bucket"       # S3 bucket name
SOURCE_DIR="/path/to/data"         # Source directory
S3_SUBDIRECTORY="uploads/"         # S3 prefix
```

**Performance Variables**:
```bash
S5CMD_CONCURRENCY="64"             # Parallel operations
S5CMD_PART_SIZE="128MB"            # Multipart upload size
S5CMD_NUM_WORKERS="32"             # Worker threads
```

**Optional Variables**:
```bash
LOG_DIR="./logs"                   # Log output directory
LOG_LEVEL="info"                   # Log verbosity
ENABLE_HEALTH_CHECK="true"         # Health monitoring
MIN_THROUGHPUT_MBPS="500"          # Performance threshold
```

#### Template Configuration

**Location**: `config/{environment}.env.template`

**Purpose**: Template for creating new configurations

**Usage**:
```bash
cp config/production.env.template config/production.env
nano config/production.env  # Edit with actual values
```

### Environment-Specific Configurations

**Recommended Structure**:

```
config/
├── development.env          # Development environment
├── staging.env             # Staging environment
├── production.env          # Production environment
└── test.env                # Testing environment
```

**Usage**:
```bash
# Development
source config/development.env
./scripts/datasync-s5cmd.sh

# Production
source config/production.env
./scripts/datasync-s5cmd.sh
```

### Secrets Management

**Best Practices**:

1. **Never commit secrets**
   - Add `*.env` to `.gitignore` (except templates)
   - Use AWS profiles instead of access keys
   - Use IAM roles when possible

2. **Use environment-specific configs**
   - Separate files for dev/staging/prod
   - Different AWS accounts/buckets
   - Appropriate permissions per environment

3. **File Permissions**
   ```bash
   # Configuration files with secrets
   chmod 600 config/production.env

   # Templates (no secrets)
   chmod 644 config/production.env.template
   ```

4. **Validation**
   ```bash
   # Check for exposed secrets
   git log --all --full-history -- "*.env"

   # Scan for accidentally committed secrets
   git secrets --scan
   ```

---

## Log Organization

### Log Types

#### 1. Text Logs (Human-Readable)

**Location**: `logs/datasync-s5cmd-YYYYMMDD-HHMMSS.log`

**Format**:
```
[INFO] 2025-10-28 15:14:24 - Started: 2025-10-28T15:14:24-06:00
[SUCCESS] 2025-10-28 15:14:25 - Upload completed successfully
```

**Use Cases**:
- Manual troubleshooting
- Real-time monitoring
- Support investigations

**Rotation**: Daily, 30-day retention

#### 2. JSON Logs (Machine-Parseable)

**Location**: `logs/datasync-s5cmd-YYYYMMDD-HHMMSS.json`

**Format**:
```json
{
  "timestamp": "2025-10-28T15:14:25-06:00",
  "duration_seconds": 245,
  "throughput_mbps": 8.8,
  "status": "success"
}
```

**Use Cases**:
- Metrics aggregation
- Performance analysis
- Automated monitoring
- Log aggregation tools (ELK, Splunk)

**Rotation**: Weekly, 12-week retention

#### 3. Health Check File

**Location**: `logs/last-sync`

**Format**: Unix timestamp
```
1698517724
```

**Use Cases**:
- Quick status checks
- Monitoring systems
- Alert triggers

**Updated**: After each successful sync

#### 4. Metrics File

**Location**: `logs/metrics.json`

**Format**: Aggregated metrics
```json
{
  "last_7_days": {
    "total_syncs": 14,
    "avg_throughput_mbps": 285.5,
    "total_bytes": 30064771072
  }
}
```

**Use Cases**:
- Performance trending
- Capacity planning
- SLA monitoring

### Log Rotation

**Configuration**: `logging/logrotate.conf`

**Schedule**:
- Text logs: Daily rotation
- JSON logs: Weekly rotation
- Compressed: Yes (gzip)
- Retention: Configurable

**Installation**:
```bash
sudo cp logging/logrotate.conf /etc/logrotate.d/datasync-turbo
sudo logrotate -d /etc/logrotate.d/datasync-turbo  # Test
sudo logrotate -f /etc/logrotate.d/datasync-turbo  # Force rotation
```

### Log Analysis

**View Recent Logs**:
```bash
# Text logs
tail -f logs/datasync-s5cmd-*.log

# JSON logs
cat logs/datasync-s5cmd-*.json | jq .

# Filter by status
cat logs/*.json | jq 'select(.status == "success")'

# Calculate average throughput
cat logs/*.json | jq '.throughput_mbps' | awk '{sum+=$1; n++} END {print sum/n}'
```

---

## Package Structure

### Production Package Contents

```
datasync-production-v1.0.0/
├── README.md                    # Quick start guide
├── CHANGELOG.md                 # Version history
├── LICENSE                      # MIT license
├── install.sh                   # Interactive installer
│
├── scripts/                     # Core functionality
│   └── datasync-s5cmd.sh       # Main upload script
│
├── tools/                       # Utilities
│   ├── install-s5cmd.sh        # s5cmd installer
│   ├── verify-installation.sh   # Setup verification
│   └── benchmark.sh             # Performance tool
│
├── deployment/                  # Production deployment
│   ├── deploy.sh               # Deployment automation
│   └── systemd/                # Service files (future)
│       ├── datasync-turbo.service
│       └── datasync-turbo.timer
│
├── monitoring/                  # Health & alerts
│   ├── check-status.sh         # Status monitoring
│   └── alerts.sh               # Alert management
│
├── logging/                     # Log management
│   └── logrotate.conf          # Rotation config
│
└── config/                      # Configuration
    └── production.env.template  # Config template
```

### Package Build Process

**Build Script**: `packages/production-package/build.sh`

**Process**:
1. Validate source files exist
2. Read version from `.release/version.txt`
3. Sync latest files to package directory
4. Generate CHANGELOG.md
5. Create LICENSE file
6. Create tarball
7. Generate SHA256 checksum
8. Verify package contents

**Output**:
- `datasync-production-v{VERSION}.tar.gz` - Distribution package
- `datasync-production-v{VERSION}.tar.gz.sha256` - Checksum file

---

## Maintenance Guidelines

### Regular Maintenance Tasks

#### Weekly
- [ ] Review logs for errors
- [ ] Check system resources
- [ ] Verify backup completion
- [ ] Monitor performance metrics

#### Monthly
- [ ] Review and clean old logs
- [ ] Update dependencies
- [ ] Check for s5cmd updates
- [ ] Review security advisories
- [ ] Test backup restoration

#### Quarterly
- [ ] Performance benchmarking
- [ ] Capacity planning review
- [ ] Documentation updates
- [ ] Security audit
- [ ] Disaster recovery testing

### File Organization Best Practices

#### DO:
- ✅ Use consistent naming conventions
- ✅ Group related files in directories
- ✅ Maintain clear directory hierarchy
- ✅ Document file purposes
- ✅ Keep configurations separate from code
- ✅ Use templates for configurations
- ✅ Version control everything except secrets

#### DON'T:
- ❌ Mix code and data
- ❌ Hardcode paths or credentials
- ❌ Commit sensitive information
- ❌ Create deep directory nesting
- ❌ Use inconsistent naming
- ❌ Leave orphaned files
- ❌ Ignore file permissions

### Code Organization Principles

1. **Separation of Concerns**
   - Core logic in `scripts/`
   - Utilities in `tools/`
   - Deployment in `examples/production/`
   - Documentation at root level

2. **Single Responsibility**
   - Each script has one primary purpose
   - No monolithic scripts
   - Clear interfaces between components

3. **DRY (Don't Repeat Yourself)**
   - Common functions in shared libraries (future)
   - Configuration templates
   - Reusable scripts

4. **KISS (Keep It Simple)**
   - Clear, readable code
   - Straightforward directory structure
   - Minimal dependencies
   - Well-documented

### Cleanup Tasks

```bash
# Remove old logs (manual)
find logs/ -name "*.log" -mtime +30 -delete
find logs/ -name "*.json" -mtime +90 -delete

# Clean build artifacts
rm -rf packages/production-package/*.tar.gz
rm -rf packages/production-package/*.sha256

# Remove temporary files
find . -name "*.tmp" -delete
find . -name "*.swp" -delete
```

### Directory Growth Management

**Monitor**:
```bash
# Check directory sizes
du -sh logs/
du -sh packages/

# Find large files
find logs/ -type f -size +100M

# Count files
find logs/ -type f | wc -l
```

**Maintenance**:
- Configure log rotation appropriately
- Archive old packages
- Remove test data
- Clean temporary files

---

## Adding New Components

### Adding a New Script

1. **Create Script**
   ```bash
   nano scripts/new-feature.sh
   chmod +x scripts/new-feature.sh
   ```

2. **Update Documentation**
   - Add to README.md
   - Update PROJECT_ORGANIZATION.md
   - Create usage examples

3. **Add to Package**
   - Update `packages/production-package/build.sh`
   - Add to validation list
   - Update package README

### Adding a New Configuration Option

1. **Update Script**
   - Add variable with default
   - Document in comments
   - Validate input

2. **Update Templates**
   - Add to config templates
   - Document in README
   - Provide examples

3. **Update Documentation**
   - Document in configuration guide
   - Add to troubleshooting
   - Include in upgrade notes

### Adding a New Tool

1. **Create Tool**
   ```bash
   nano tools/new-tool.sh
   chmod +x tools/new-tool.sh
   ```

2. **Integration**
   - Add to install.sh if needed
   - Update verification script
   - Add to package builder

3. **Documentation**
   - Usage guide
   - Integration examples
   - Troubleshooting section

---

## Resources

### Related Documentation
- [DEVELOPMENT.md](DEVELOPMENT.md) - Development process
- [VERSIONING.md](VERSIONING.md) - Version management
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [README.md](README.md) - Project overview

### External Resources
- [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
- [Bash Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Semantic Versioning](https://semver.org/)

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-29
