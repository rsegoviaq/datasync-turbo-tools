#!/bin/bash
#
# install-s5cmd.sh - Automatic s5cmd installation with platform detection
#
# Usage:
#   ./install-s5cmd.sh [VERSION] [INSTALL_DIR]
#
# Examples:
#   ./install-s5cmd.sh                    # Install latest to /usr/local/bin
#   ./install-s5cmd.sh v2.2.2             # Install specific version
#   ./install-s5cmd.sh latest ~/bin       # Install to custom directory
#
# Features:
#   - Automatic platform and architecture detection
#   - Downloads from GitHub releases
#   - SHA256 checksum verification
#   - Version verification
#   - AWS credentials check
#   - S3 access test
#

set -euo pipefail

# Configuration
VERSION="${1:-latest}"
INSTALL_DIR="${2:-/usr/local/bin}"
GITHUB_REPO="peak/s5cmd"
TEMP_DIR="/tmp/s5cmd-install-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions - output to stderr to avoid interfering with function returns
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Cleanup on exit
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Detect operating system
detect_os() {
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    case "$os" in
        linux*)
            echo "linux"
            ;;
        darwin*)
            echo "darwin"
            ;;
        *)
            log_error "Unsupported operating system: $os"
            log_error "Supported: Linux, macOS (Darwin)"
            exit 1
            ;;
    esac
}

# Detect CPU architecture
detect_arch() {
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        i386|i686)
            log_error "32-bit architecture ($arch) is not supported by s5cmd"
            exit 1
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            log_error "Supported: x86_64/amd64, aarch64/arm64"
            exit 1
            ;;
    esac
}

# Get latest version from GitHub
get_latest_version() {
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi

    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | \
                     grep '"tag_name":' | \
                     sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$latest_version" ]; then
        log_error "Failed to fetch latest version from GitHub"
        exit 1
    fi

    echo "$latest_version"
}

# Download s5cmd from GitHub releases
download_s5cmd() {
    local version="$1"
    local os="$2"
    local arch="$3"

    # Determine actual version to download
    if [ "$version" = "latest" ]; then
        log_info "Fetching latest s5cmd version from GitHub..."
        version=$(get_latest_version)
        log_info "Latest version: $version"
    fi

    # Remove 'v' prefix if present for filename
    local version_num="${version#v}"

    # Map OS and arch to s5cmd naming convention
    # s5cmd uses: Linux-64bit, Linux-arm64, macOS-64bit, macOS-arm64
    local s5cmd_os
    local s5cmd_arch

    case "$os" in
        linux)
            s5cmd_os="Linux"
            ;;
        darwin)
            s5cmd_os="macOS"
            ;;
    esac

    case "$arch" in
        amd64)
            s5cmd_arch="64bit"
            ;;
        arm64)
            s5cmd_arch="arm64"
            ;;
    esac

    # Construct download URL
    local filename="s5cmd_${version_num}_${s5cmd_os}-${s5cmd_arch}.tar.gz"
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${filename}"
    local checksum_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/s5cmd_checksums.txt"

    log_info "Downloading s5cmd ${version} for ${os}/${arch}..."
    log_info "URL: $download_url"

    # Create temporary directory
    mkdir -p "$TEMP_DIR"

    # Download archive
    if ! curl -L -f -o "${TEMP_DIR}/${filename}" "$download_url"; then
        log_error "Failed to download s5cmd from $download_url"
        log_error "Please check that version ${version} exists for ${os}/${arch}"
        exit 1
    fi

    log_success "Downloaded s5cmd archive"

    # Download checksums
    log_info "Downloading checksums..."
    if ! curl -L -f -o "${TEMP_DIR}/checksums.txt" "$checksum_url"; then
        log_warn "Failed to download checksums file"
        log_warn "Skipping checksum verification"
        echo "${TEMP_DIR}/${filename}"
        return
    fi

    # Verify checksum
    log_info "Verifying SHA256 checksum..."
    cd "$TEMP_DIR"

    # Extract the checksum for our specific file
    local expected_checksum
    expected_checksum=$(grep "$filename" checksums.txt | awk '{print $1}')

    if [ -z "$expected_checksum" ]; then
        log_warn "Checksum not found in checksums.txt"
        log_warn "Skipping checksum verification"
    else
        # Calculate actual checksum
        local actual_checksum
        if command -v sha256sum &> /dev/null; then
            actual_checksum=$(sha256sum "$filename" | awk '{print $1}')
        elif command -v shasum &> /dev/null; then
            actual_checksum=$(shasum -a 256 "$filename" | awk '{print $1}')
        else
            log_warn "No SHA256 tool found (sha256sum or shasum)"
            log_warn "Skipping checksum verification"
            cd - > /dev/null
            echo "${TEMP_DIR}/${filename}"
            return
        fi

        if [ "$expected_checksum" = "$actual_checksum" ]; then
            log_success "Checksum verification passed"
        else
            log_error "Checksum verification failed!"
            log_error "Expected: $expected_checksum"
            log_error "Got:      $actual_checksum"
            exit 1
        fi
    fi

    cd - > /dev/null
    echo "${TEMP_DIR}/${filename}"
}

# Extract and install s5cmd
install_s5cmd() {
    local archive_path="$1"
    local install_dir="$2"

    log_info "Extracting s5cmd..."

    # Extract archive
    tar -xzf "$archive_path" -C "$TEMP_DIR"

    if [ ! -f "${TEMP_DIR}/s5cmd" ]; then
        log_error "s5cmd binary not found in archive"
        exit 1
    fi

    # Make binary executable
    chmod +x "${TEMP_DIR}/s5cmd"

    # Create install directory if it doesn't exist
    if [ ! -d "$install_dir" ]; then
        log_info "Creating install directory: $install_dir"
        mkdir -p "$install_dir"
    fi

    # Check if we need sudo
    local use_sudo=""
    if [ ! -w "$install_dir" ]; then
        log_info "Elevated privileges required to write to $install_dir"
        use_sudo="sudo"
    fi

    # Install binary
    log_info "Installing s5cmd to $install_dir..."
    $use_sudo mv "${TEMP_DIR}/s5cmd" "${install_dir}/s5cmd"

    log_success "s5cmd installed to ${install_dir}/s5cmd"
}

# Verify installation
verify_installation() {
    local install_dir="$1"

    log_info "Verifying installation..."

    # Check if s5cmd is in PATH or use full path
    local s5cmd_path
    if command -v s5cmd &> /dev/null; then
        s5cmd_path="s5cmd"
    elif [ -x "${install_dir}/s5cmd" ]; then
        s5cmd_path="${install_dir}/s5cmd"
    else
        log_error "s5cmd not found in PATH or ${install_dir}"
        log_error "You may need to add ${install_dir} to your PATH"
        exit 1
    fi

    # Test execution
    log_info "Testing s5cmd execution..."
    if ! $s5cmd_path version &> /dev/null; then
        log_error "s5cmd execution test failed"
        exit 1
    fi

    # Get and display version
    local version
    version=$($s5cmd_path version 2>&1 | head -n 1 || echo "unknown")
    log_success "s5cmd is working: $version"

    # Check if install_dir is in PATH
    if [[ ":$PATH:" != *":${install_dir}:"* ]] && [ "$install_dir" != "/usr/local/bin" ] && [ "$install_dir" != "/usr/bin" ]; then
        log_warn "⚠️  ${install_dir} is not in your PATH"
        log_warn "   Add it to your PATH by adding this to your ~/.bashrc or ~/.zshrc:"
        echo ""
        echo "   export PATH=\"${install_dir}:\$PATH\""
        echo ""
    fi
}

# Check AWS credentials
check_aws_credentials() {
    log_info "Checking AWS credentials..."

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_warn "AWS CLI not found - skipping AWS credentials check"
        log_warn "Install AWS CLI to use s5cmd with AWS S3"
        return
    fi

    # Check for AWS credentials
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && [ -z "${AWS_PROFILE:-}" ] && [ ! -f ~/.aws/credentials ]; then
        log_warn "No AWS credentials found"
        log_warn "Configure credentials with: aws configure"
        return
    fi

    log_success "AWS credentials configured"

    # Test S3 access (optional, non-fatal)
    log_info "Testing S3 access (optional)..."
    local s5cmd_path
    if command -v s5cmd &> /dev/null; then
        s5cmd_path="s5cmd"
    else
        s5cmd_path="${INSTALL_DIR}/s5cmd"
    fi

    if $s5cmd_path ls s3:// &> /dev/null; then
        log_success "S3 access verified"
    else
        log_warn "Could not verify S3 access - this may be normal if you have no buckets"
        log_warn "Try: s5cmd ls s3://your-bucket-name"
    fi
}

# Main installation flow
main() {
    echo ""
    log_info "=== s5cmd Installation Script ==="
    echo ""

    # Detect platform
    local os arch
    os=$(detect_os)
    arch=$(detect_arch)

    log_info "Platform: ${os}/${arch}"
    log_info "Target version: ${VERSION}"
    log_info "Install directory: ${INSTALL_DIR}"
    echo ""

    # Download s5cmd
    local archive_path
    archive_path=$(download_s5cmd "$VERSION" "$os" "$arch")

    # Install s5cmd
    install_s5cmd "$archive_path" "$INSTALL_DIR"

    # Verify installation
    verify_installation "$INSTALL_DIR"

    # Check AWS credentials
    check_aws_credentials

    echo ""
    log_success "=== Installation Complete ==="
    echo ""
    log_info "Next steps:"
    log_info "  1. Verify: s5cmd version"
    log_info "  2. Test:   s5cmd ls s3://your-bucket"
    log_info "  3. Upload: s5cmd cp localfile s3://your-bucket/"
    echo ""
    log_info "Documentation: https://github.com/peak/s5cmd"
    echo ""
}

# Run main installation
main "$@"
