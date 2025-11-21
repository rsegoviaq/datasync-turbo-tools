# Changelog

All notable changes to DataSync Turbo Tools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2025-11-21

### Added
- **Byte-Based Progress Tracking**: Progress now accurately reflects actual data uploaded, not just file count
  - Tracks actual bytes uploaded by reading file sizes with `stat` command
  - Displays both byte-based percentage (by size) and file-count percentage for comparison
  - Example: `Progress: 123/500 files (45.2% by size, 24.6% by count) | 2.5GB/5.5GB`
  - Human-readable byte progress (automatically switches between MB and GB)
  - More accurate representation for datasets with mixed file sizes
  - Cross-platform support for Linux and macOS

- **Background Upload Activity Monitor**: Provides feedback during long file uploads
  - Background process monitors upload activity every 10 seconds
  - Displays periodic updates when no file completions occur
  - Alerts when upload appears stalled (30+ seconds without progress)
  - Helps users know upload is progressing during large file transfers
  - Automatically stops when upload completes

- **Enhanced JSON Logging**: New metrics for progress tracking and analysis
  - `actual_bytes_transferred`: Actual bytes uploaded based on file sizes
  - `estimated_bytes_transferred`: Original estimated total bytes
  - `progress_accuracy_percent`: Accuracy of byte-based progress (actual vs estimated)
  - `progress_history`: Array of timestamped progress snapshots captured every 5%
  - Enables graphing upload trends and analyzing performance over time

### Changed
- **Progress Update Frequency**: Updates now occur every 5 seconds OR 2% progress (was every 10 files OR 5%)
  - More frequent updates provide better visibility
  - Time-based updates ensure progress shown during large file uploads
  - Reduced percentage threshold (5% → 2%) for finer granularity

- **Progress Calculation**: Changed from estimated bytes (based on file count proportion) to actual bytes
  - Previous: `bytes_uploaded = (files_uploaded * total_bytes / total_files)` - assumes all files same size
  - Current: `bytes_uploaded = sum(actual_file_sizes)` - accurate regardless of file size distribution

### Technical Details
- Modified `show_upload_progress()` function (lines 92-160):
  - Calculate both file-count and byte-based percentages
  - Format human-readable byte progress (GB/MB auto-selection)
  - Display both percentages for user comparison

- Updated upload loop (lines 570-666):
  - Parse s5cmd output to extract completed file paths
  - Use `stat` to get actual file sizes cross-platform (Linux: `stat -c%s`, macOS: `stat -f%z`)
  - Track cumulative actual bytes uploaded in temp file
  - Capture progress history snapshots every 5% completion
  - Time-based and byte-percentage based update triggering

- Added `monitor_upload_activity()` function (lines 162-204):
  - Runs as background process (monitored PID tracked globally)
  - Checks progress files every 10 seconds
  - Detects stalled uploads (no progress for 30+ seconds)
  - Properly cleaned up on script exit via trap

- Enhanced `generate_json_output()` function (lines 709-786):
  - Calculate progress accuracy percentage
  - Include progress_history array with snapshots
  - Add actual vs estimated bytes fields

### Notes
- No breaking changes - all changes are additive or improve existing functionality
- Progress display backward compatible - still shows file count and percentages
- JSON output includes all previous fields plus new metrics
- Performance impact minimal (~1ms per file for `stat` calls)
- Background monitor runs in separate process with no blocking

---

## [1.3.2] - 2025-11-19

### Added
- **Upload-Only Sync Protection**: Added explicit validation to prevent destructive sync operations
  - Validates that `--delete` flag is never used in both s5cmd and AWS CLI scripts
  - Aborts sync with clear error message if destructive operations detected
  - Ensures tool remains upload-only permanently
  - Added code comments documenting upload-only design intent
  - New `validate_upload_only()` function in both `datasync-s5cmd.sh` and `datasync-awscli.sh`

### Changed
- **Documentation**: Clarified upload-only sync behavior across all documentation
  - Added "Upload-Only Sync Design" section to README.md
  - Documented that empty source folders are safe and won't delete destination data
  - Updated S5CMD_GUIDE.md with upload-only behavior explanation
  - Enhanced COMPARISON.md to explain difference from bidirectional tools
  - Added safety comment headers to config templates
  - Updated version references from 1.3.0/1.3.1 to 1.3.2

### Notes
- This release confirms and protects existing safe behavior
- No functionality changes - tool was already upload-only
- Changes add explicit validation and documentation for clarity and future safety
- Addresses user concerns about syncing with empty source directories

---

## [1.3.1] - 2025-11-18

### Fixed
- **s5cmd AWS Region Configuration**: Fixed "MissingEndpoint" error when accessing S3 buckets
  - **Issue**: s5cmd failed with "MissingEndpoint: 'Endpoint' configuration is required for this service"
  - **Root Cause**: s5cmd requires `AWS_REGION` environment variable to be explicitly set, even when using AWS profiles. Unlike AWS CLI, it doesn't automatically read region from profile configuration.
  - **Solution**:
    - Modified `quick-install.sh` to detect and extract region from AWS profile configuration
    - Added region prompt for direct credentials authentication method
    - Export `AWS_REGION` environment variable before s5cmd bucket validation
    - Added `AWS_REGION` to generated config files with explanatory comment
    - Updated `datasync-s5cmd.sh` to export AWS_REGION if set in config
    - Updated config template (`config/s5cmd.env.template`) to mark AWS_REGION as REQUIRED
    - Added AWS_REGION display in configuration output for visibility

### Changed
- Configuration output now displays AWS Region for troubleshooting purposes
- Config template updated with clearer documentation about AWS_REGION requirement

---

## [1.3.0] - 2025-11-13

### Added
- **Real-Time Upload Progress Monitoring** (Issue #3)
  - Live progress tracking with percentage completion (e.g., "Progress: 25/50 files (50%)")
  - Upload speed in MB/s with 2 decimal precision (e.g., "Speed: 2.44 MB/s")
  - Smart ETA calculation with human-readable format (hours/minutes/seconds)
  - Progress updates every 10 files or 5% completion for optimal visibility
  - File count tracking (uploaded/total files)
  - Byte-based speed and ETA calculations for accuracy with varying file sizes

  **Example Output**:
  ```
  [INFO] Preparing to upload 50 files (4.9M)
  [INFO] Progress: 10/50 files (20%) | Speed: 0.97 MB/s | ETA: 4s
  [INFO] Progress: 25/50 files (50%) | Speed: 2.44 MB/s | ETA: 1s
  [INFO] Progress: 50/50 files (100%) | Speed: 4.88 MB/s | ETA: 0s
  [SUCCESS] Upload completed: 50/50 files (100%)
  ```

### Fixed
- **Progress Tracking Variable Scope**: Fixed issue where final upload count showed 0 files instead of actual count
  - Used temporary file to persist progress counter across subshell boundaries
  - Final completion message now correctly displays "N/N files (100%)"

- **Speed Calculation for Fast Uploads**: Fixed division-by-zero errors when uploads complete in < 1 second
  - Added minimum elapsed time of 1 second to prevent calculation errors
  - Speed metrics now display correctly even for rapid uploads

- **Output Capture**: Enhanced real-time display while capturing logs
  - Changed from separate file writes to using `tee` command
  - Maintains real-time progress visibility with complete log capture

### Changed
- Progress tracking now uses MB/s instead of files/sec for industry-standard metric
- ETA calculation based on bytes remaining instead of file count for better accuracy
- Enhanced progress function to accept bytes_uploaded and elapsed_seconds parameters

### Technical Details
- Modified `show_upload_progress()` function for MB/s calculation using `bc` for floating-point math
- Updated `perform_sync()` to track bytes uploaded with proportional estimation
- Added comprehensive test documentation in `docs/features/issue-3-upload-progress-testing.md`
- All changes tested with multiple dataset sizes (10 files/10MB and 50 files/5MB)

---

## [1.2.3] - 2025-11-07

### Fixed
- **macOS Bash Version Compatibility**: Relaxed bash version requirement to support macOS default installation
  - **Issue**: Quick install script failing on macOS with "Bash 4.0 or higher is required (found: 3.2.57)"
  - **Root Cause**: macOS ships with Bash 3.2 due to GPL v3 licensing restrictions, but script unnecessarily required Bash 4.0+
  - **Solution**: Added OS-specific bash version requirements
    - On macOS (darwin): Requires Bash 3.0+ (compatible with system default 3.2)
    - On Linux: Continues requiring Bash 4.0+ (standard across modern distributions)
  - **Files Updated**:
    - `quick-install.sh:105-116` - OS-aware bash version check in prerequisites
  - **Testing**: All existing functionality works correctly with Bash 3.2 on macOS
  - Now installation works seamlessly on macOS without requiring users to install newer bash via Homebrew

### Changed
- Updated version strings from 1.2.0 to 1.2.2 in quick-install.sh banners and comments

---

## [1.2.2] - 2025-11-07

### Fixed
- **macOS Disk Space Check Compatibility**: Fixed `df: illegal option -- B` error during installation on macOS
  - **Issue**: Installation script failing at disk space check with "illegal option -- B" error
  - **Root Cause**: macOS uses BSD `df` which doesn't support GNU-specific `-B` flag for block size
  - **Solution**: Added OS detection (`$OSTYPE`) to use platform-appropriate df commands
    - On macOS (darwin): Uses `df -g` (lowercase g flag for gigabytes)
    - On Linux: Continues using `df -BG` (block size in gigabytes)
  - **Files Updated**:
    - `quick-install.sh:131-137` - disk space check in prerequisites
    - `config/config-validator.sh:423-429` - disk space validation function
    - `monitoring/alerts.sh:160-167` - disk space monitoring
    - `monitoring/check-status.sh:135-141` - status check disk space
    - `examples/production/deploy.sh:211-218` - deployment validation
    - `examples/production/monitoring/alerts.sh:160-167` - production monitoring
    - `examples/production/monitoring/check-status.sh:125-131` - production status checks
  - Now installation and all monitoring scripts work seamlessly on macOS

### Improved
- Enhanced cross-platform compatibility (Linux, macOS, WSL2)
- All disk space checks now platform-aware across entire codebase
- Better error handling and validation during installation

---

## [1.2.1] - 2025-11-03

### Fixed
- **macOS Compatibility**: Fixed directory size calculation hanging on macOS systems
  - **Issue**: Scripts would hang at "Calculating source directory size..." on macOS
  - **Root Cause**: macOS uses BSD `du` which doesn't support GNU-specific `-b` flag
  - **Solution**: Added OS detection to use appropriate command for each platform
    - On macOS (darwin): Uses `find` + `stat -f%z` for directory size calculation
    - On Linux: Continues using `du -sb` command
  - **Files Updated**:
    - `scripts/datasync-s5cmd.sh:296-314` (calculate_source_size function)
    - `scripts/datasync-awscli.sh:258-267` (directory size calculation)
    - `datasync-client-package/scripts/datasync-s5cmd.sh:270-289` (calculate_source_size function)
  - Now fully compatible with both Linux and macOS environments

### Changed
- Updated script versions across all files to maintain consistency (1.2.1)

---

## [1.2.0] - 2025-10-31

### Added
- **Quick Install Script (`quick-install.sh`)**: One-click interactive installer for streamlined setup
  - Interactive prompts for all essential configuration
  - Real-time validation of AWS credentials, S3 bucket access, and source directories
  - Smart defaults for performance settings (concurrency, workers, part size)
  - Automatic directory creation and permission setup
  - Integrated verification and optional dry-run testing
  - **Reduces setup time from 10-15 minutes to ~2-3 minutes**
- **Configuration Validator (`config/config-validator.sh`)**: Reusable validation functions
  - `validate_aws_credentials()` - Test AWS credential validity
  - `validate_aws_profile()` - Verify AWS profile configuration
  - `validate_s3_bucket()` - Check S3 bucket accessibility
  - `validate_source_directory()` - Validate source directory exists and is readable
  - `validate_s5cmd_installation()` - Check s5cmd installation
  - `validate_config_file()` - Validate configuration file syntax and required variables
  - `validate_complete_configuration()` - Run all validation checks
  - `validate_disk_space()` - Verify sufficient disk space

### Fixed
- **Configuration Path Resolution**: Fixed `deploy.sh --validate` failure
  - `examples/production/deploy.sh` now supports multiple config file locations
  - Tries `config/production.env` (new standard), `config.env` (legacy), and relative paths
  - `monitoring/check-status.sh` updated to find config in multiple locations
  - Backward compatible with existing deployments
- **Config File Symlink**: `quick-install.sh` creates symlink for deployment compatibility

### Changed
- **Installation Process**: Simplified from 7+ manual steps to single command
  - Old: install → configure → verify → dry-run → deploy validate → deploy
  - New: `./quick-install.sh` handles everything interactively
- **README.md**: Updated Quick Start section to feature quick installer as primary method
  - Reorganized installation options (Quick Install, Manual, Development)
  - Updated version references from 1.1.0 to 1.2.0

### Improved
- Better error messages showing all possible config file locations
- Interactive AWS credential setup with format validation
- Color-coded output for better user experience
- Enhanced documentation for simplified installation process

### Notes
- **Fully Backward Compatible**: All existing configurations and workflows continue to work
- **Quick Install Recommended**: New users should use `quick-install.sh` for fastest setup
- **Manual Install Still Available**: Power users can still use step-by-step installation

---

## [1.1.0] - 2025-10-30

### Added
- **Direct AWS Credentials Support**: Configure AWS credentials directly without requiring AWS CLI profile setup
  - New config options: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
  - Ideal for CI/CD environments, containers, or systems without AWS CLI profile configuration
- **Enhanced AWS CLI Installation Guidance**: Comprehensive installation instructions when AWS CLI is not detected
  - Platform-specific instructions (Linux, macOS)
  - Package manager alternatives
  - Direct download links

### Changed
- **Configuration Template**: Updated `production.env.template` with clear authentication method selection
  - Two authentication methods: AWS Profile (Method 1) or Direct Credentials (Method 2)
  - Detailed comments explaining each approach and security considerations
- **Upload Script Authentication**: Enhanced credential detection and validation
  - Displays active authentication method during execution
  - Shows partial access key for verification (first 8 characters)
  - Falls back to default AWS credentials chain if neither method configured
- **Installer**: Updated configuration setup guidance to explain both authentication methods
  - Clear instructions for choosing between profile and credentials
  - Improved user experience during initial setup

### Improved
- Help documentation now includes complete AWS credential configuration options
- Better error messages and validation for AWS authentication
- Configuration display shows which authentication method is active

### Notes
- **Backward Compatible**: Existing configurations using `AWS_PROFILE` continue to work without changes
- **Security Best Practice**: AWS profiles still recommended for local/development environments
- **Profile Priority**: If both profile and credentials are set, profile takes precedence

---

## [1.0.0] - 2025-10-28

### Added
- Initial production release
- s5cmd integration for high-performance S3 uploads (5-12x faster than AWS CLI)
- Production-optimized configuration for 3+ Gbps networks
- Comprehensive logging system (text and JSON formats)
- Throughput monitoring and performance metrics
- Health checks and status reporting
- Automated deployment with systemd integration
- Log rotation with logrotate
- Alert system for monitoring failures
- Benchmark tool for performance testing
- Installation verification script
- Complete documentation and guides

### Performance
- Concurrency: 64 parallel operations
- Part size: 128MB for multipart uploads
- Workers: 32 threads
- Checksum: CRC64NVME (fastest algorithm)
- Storage class: INTELLIGENT_TIERING
- Expected throughput: 200-300 MB/s on 3 Gbps networks

### Security
- AWS IAM credential support
- AWS profile support
- Checksum verification (CRC64NVME/SHA256)
- Server-side encryption support (KMS)
- Secure log handling

### Documentation
- Quick start guide (5 minutes)
- Configuration reference
- Monitoring guide
- Troubleshooting guide
- Performance tuning guide

---

## Release Notes

### Version 1.0.0

This is the first production release of DataSync Turbo Tools, providing enterprise-ready S3 upload capabilities with significant performance improvements over standard AWS CLI.

**Key Features:**
- **High Performance**: 5-12x faster uploads than AWS CLI
- **Production Ready**: Comprehensive error handling and monitoring
- **Easy Deployment**: One-command installation and setup
- **Professional Monitoring**: Health checks, alerts, and metrics
- **Complete Documentation**: Step-by-step guides and examples

**Tested Environments:**
- Linux (Ubuntu 20.04+, RHEL 8+, Amazon Linux 2)
- macOS (10.15+)
- WSL2 (Windows Subsystem for Linux)

**Requirements:**
- Bash 4.0+
- AWS CLI installed and configured
- Network: 1 Gbps+ recommended (optimized for 3+ Gbps)
- Disk: Sufficient space for logs and temporary files
- AWS: S3 bucket with appropriate IAM permissions

**Getting Started:**
```bash
./install.sh
nano config/production.env
./tools/verify-installation.sh
./scripts/datasync-s5cmd.sh --dry-run
```

For full documentation, see README.md.

