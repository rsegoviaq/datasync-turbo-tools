#!/bin/bash
#
# DataSync Turbo Tools - Production Package Builder
# Version: 1.0.0
#
# Builds production-ready distribution package with versioned tarball
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/.release/version.txt"
BUILD_DIR="$SCRIPT_DIR"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

show_banner() {
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║  DataSync Turbo Tools - Production Package Builder      ║
║  Automated Build System                                  ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

get_version() {
    if [ ! -f "$VERSION_FILE" ]; then
        log_error "Version file not found: $VERSION_FILE"
        exit 1
    fi

    local version=$(cat "$VERSION_FILE" | tr -d '[:space:]')

    if [ -z "$version" ]; then
        log_error "Version file is empty"
        exit 1
    fi

    echo "$version"
}

validate_source_files() {
    log_step "Validating source files..."
    echo ""

    local errors=0

    # Check critical files
    local required_files=(
        "$PROJECT_ROOT/scripts/datasync-s5cmd.sh"
        "$PROJECT_ROOT/tools/install-s5cmd.sh"
        "$PROJECT_ROOT/tools/verify-installation.sh"
        "$PROJECT_ROOT/tools/benchmark.sh"
        "$PROJECT_ROOT/examples/production/deploy.sh"
        "$PROJECT_ROOT/examples/production/config.env"
        "$PROJECT_ROOT/monitoring/check-status.sh"
        "$PROJECT_ROOT/monitoring/alerts.sh"
        "$PROJECT_ROOT/logging/logrotate.conf"
    )

    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            log_success "Found: $(basename $file)"
        else
            log_error "Missing: $file"
            ((errors++))
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        log_success "All required files present"
        return 0
    else
        log_error "Validation failed with $errors missing file(s)"
        return 1
    fi
}

sync_latest_files() {
    log_step "Syncing latest files to package..."
    echo ""

    local version="$1"
    local package_dir="$BUILD_DIR/datasync-production-v${version}"

    if [ ! -d "$package_dir" ]; then
        log_error "Package directory not found: $package_dir"
        return 1
    fi

    # Sync core script
    log_info "Syncing core script..."
    cp "$PROJECT_ROOT/scripts/datasync-s5cmd.sh" "$package_dir/scripts/"
    log_success "datasync-s5cmd.sh"

    # Sync tools
    log_info "Syncing tools..."
    cp "$PROJECT_ROOT/tools/install-s5cmd.sh" "$package_dir/tools/"
    cp "$PROJECT_ROOT/tools/verify-installation.sh" "$package_dir/tools/"
    cp "$PROJECT_ROOT/tools/benchmark.sh" "$package_dir/tools/"
    log_success "Tools synced"

    # Sync deployment
    log_info "Syncing deployment..."
    cp "$PROJECT_ROOT/examples/production/deploy.sh" "$package_dir/deployment/"

    # Sync systemd files if they exist
    if [ -d "$PROJECT_ROOT/examples/production/systemd" ]; then
        mkdir -p "$package_dir/deployment/systemd"
        cp -r "$PROJECT_ROOT/examples/production/systemd/"* "$package_dir/deployment/systemd/" 2>/dev/null || true
        log_success "Deployment files synced"
    else
        log_warning "Systemd files not found, skipping"
    fi

    # Sync monitoring
    log_info "Syncing monitoring..."
    cp "$PROJECT_ROOT/monitoring/check-status.sh" "$package_dir/monitoring/"
    cp "$PROJECT_ROOT/monitoring/alerts.sh" "$package_dir/monitoring/"
    log_success "Monitoring scripts synced"

    # Sync logging
    log_info "Syncing logging..."
    cp "$PROJECT_ROOT/logging/logrotate.conf" "$package_dir/logging/"
    log_success "Log rotation config synced"

    # Sync config template
    log_info "Syncing configuration..."
    cp "$PROJECT_ROOT/examples/production/config.env" "$package_dir/config/production.env.template"
    log_success "Config template synced"

    # Set permissions
    log_info "Setting permissions..."
    chmod +x "$package_dir/install.sh"
    chmod +x "$package_dir/scripts"/*.sh 2>/dev/null || true
    chmod +x "$package_dir/tools"/*.sh 2>/dev/null || true
    chmod +x "$package_dir/monitoring"/*.sh 2>/dev/null || true
    chmod +x "$package_dir/deployment"/*.sh 2>/dev/null || true
    log_success "Permissions set"

    echo ""
    log_success "All files synced successfully"
}

create_changelog() {
    log_step "Creating CHANGELOG.md..."
    echo ""

    local version="$1"
    local package_dir="$BUILD_DIR/datasync-production-v${version}"

    # Copy CHANGELOG from project root (contains all version history)
    if [ -f "$PROJECT_ROOT/CHANGELOG.md" ]; then
        log_info "Copying CHANGELOG from project root..."
        cp "$PROJECT_ROOT/CHANGELOG.md" "$package_dir/CHANGELOG.md"
        log_success "CHANGELOG copied"
        return 0
    fi

    # Fallback: create basic CHANGELOG if none exists
    log_warning "CHANGELOG.md not found in project root, creating basic version..."
    cat > "$package_dir/CHANGELOG.md" << 'EOF'
# Changelog

All notable changes to DataSync Turbo Tools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

EOF

    log_success "CHANGELOG.md created"
}

create_license() {
    log_step "Creating LICENSE file..."
    echo ""

    local version="$1"
    local package_dir="$BUILD_DIR/datasync-production-v${version}"

    cat > "$package_dir/LICENSE" << 'EOF'
MIT License

Copyright (c) 2025 DataSync Turbo Tools

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

    log_success "LICENSE created"
}

create_tarball() {
    log_step "Creating distribution tarball..."
    echo ""

    local version="$1"
    local package_name="datasync-production-v${version}"
    local package_dir="$BUILD_DIR/$package_name"
    local tarball_name="${package_name}.tar.gz"
    local tarball_path="$BUILD_DIR/$tarball_name"

    # Remove old tarball if exists
    if [ -f "$tarball_path" ]; then
        log_info "Removing existing tarball..."
        rm "$tarball_path"
    fi

    # Create tarball
    log_info "Compressing package..."
    cd "$BUILD_DIR"
    tar czf "$tarball_name" "$package_name/"

    if [ -f "$tarball_path" ]; then
        local tarball_size=$(du -h "$tarball_path" | cut -f1)
        log_success "Tarball created: $tarball_name ($tarball_size)"
    else
        log_error "Failed to create tarball"
        return 1
    fi
}

create_checksums() {
    log_step "Generating checksums..."
    echo ""

    local version="$1"
    local tarball_name="datasync-production-v${version}.tar.gz"
    local checksum_file="$BUILD_DIR/${tarball_name}.sha256"

    cd "$BUILD_DIR"

    # Generate SHA256 checksum
    log_info "Calculating SHA256..."
    sha256sum "$tarball_name" > "$checksum_file"

    if [ -f "$checksum_file" ]; then
        local checksum=$(cat "$checksum_file" | cut -d' ' -f1)
        log_success "SHA256: $checksum"
        log_success "Checksum file: ${tarball_name}.sha256"
    else
        log_error "Failed to generate checksum"
        return 1
    fi
}

verify_package() {
    log_step "Verifying package contents..."
    echo ""

    local version="$1"
    local tarball_name="datasync-production-v${version}.tar.gz"

    cd "$BUILD_DIR"

    log_info "Listing tarball contents..."
    local file_count=$(tar tzf "$tarball_name" | wc -l)

    log_success "Package contains $file_count files"

    # Check for critical files
    log_info "Verifying critical files..."
    local critical_files=(
        "install.sh"
        "README.md"
        "CHANGELOG.md"
        "LICENSE"
        "scripts/datasync-s5cmd.sh"
        "tools/install-s5cmd.sh"
        "tools/verify-installation.sh"
        "deployment/deploy.sh"
        "monitoring/check-status.sh"
        "config/production.env.template"
    )

    local errors=0
    for file in "${critical_files[@]}"; do
        if tar tzf "$tarball_name" | grep -q "datasync-production-v${version}/$file"; then
            log_success "$file"
        else
            log_error "Missing: $file"
            ((errors++))
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        log_success "Package verification passed"
        return 0
    else
        log_error "Package verification failed with $errors error(s)"
        return 1
    fi
}

show_summary() {
    local version="$1"
    local tarball_name="datasync-production-v${version}.tar.gz"
    local tarball_path="$BUILD_DIR/$tarball_name"
    local checksum_file="${tarball_path}.sha256"

    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Build Complete!                                         ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    log_success "Package built successfully"
    echo ""
    echo "📦 Distribution Package:"
    echo "   File: $tarball_name"
    echo "   Size: $(du -h "$tarball_path" | cut -f1)"
    echo "   Path: $tarball_path"
    echo ""
    echo "🔐 Checksum:"
    echo "   File: ${tarball_name}.sha256"
    echo "   SHA256: $(cat "$checksum_file" | cut -d' ' -f1)"
    echo ""
    echo "📝 Installation Instructions:"
    echo "   1. Extract: tar xzf $tarball_name"
    echo "   2. Enter:   cd datasync-production-v${version}"
    echo "   3. Install: ./install.sh"
    echo ""
    echo "🚀 Quick Test:"
    echo "   ${CYAN}tar xzf $tarball_name${NC}"
    echo "   ${CYAN}cd datasync-production-v${version}${NC}"
    echo "   ${CYAN}./install.sh${NC}"
    echo ""
}

main() {
    show_banner

    # Get version
    log_info "Reading version..."
    VERSION=$(get_version)
    log_success "Building version: $VERSION"
    echo ""

    # Validate source files
    if ! validate_source_files; then
        log_error "Build aborted due to missing files"
        exit 1
    fi

    echo ""
    read -p "Continue with build? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Build cancelled"
        exit 0
    fi

    echo ""

    # Sync latest files
    if ! sync_latest_files "$VERSION"; then
        log_error "Failed to sync files"
        exit 1
    fi

    echo ""

    # Create changelog
    create_changelog "$VERSION"

    echo ""

    # Create license
    create_license "$VERSION"

    echo ""

    # Create tarball
    if ! create_tarball "$VERSION"; then
        log_error "Failed to create tarball"
        exit 1
    fi

    echo ""

    # Create checksums
    if ! create_checksums "$VERSION"; then
        log_error "Failed to create checksums"
        exit 1
    fi

    echo ""

    # Verify package
    if ! verify_package "$VERSION"; then
        log_error "Package verification failed"
        exit 1
    fi

    # Show summary
    show_summary "$VERSION"
}

# Run main build process
main
