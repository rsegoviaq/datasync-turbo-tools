#!/bin/bash
#
# DataSync Turbo Tools - Basic Upload Script
# Simple wrapper for quick uploads using s5cmd
#
# Usage:
#   ./upload.sh                 # Upload using config.env
#   ./upload.sh --dry-run       # Preview what would be uploaded
#   ./upload.sh --help          # Show help
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_help() {
    cat << EOF
DataSync Turbo Tools - Basic Upload Script

USAGE:
    ./upload.sh [OPTIONS]

OPTIONS:
    --dry-run       Preview what would be uploaded without uploading
    --help          Show this help message

CONFIGURATION:
    Edit config.env to set your S3 bucket, source directory, and settings.

EXAMPLES:
    ./upload.sh                 # Upload files
    ./upload.sh --dry-run       # Preview upload

For more information, see README.md
EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================

DRY_RUN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ============================================================================
# Main
# ============================================================================

log_info "DataSync Turbo Tools - Basic Upload"
echo

# Load configuration
if [ ! -f "$SCRIPT_DIR/config.env" ]; then
    log_error "Configuration file not found: $SCRIPT_DIR/config.env"
    log_info "Please create config.env from the template and configure your settings."
    exit 1
fi

log_info "Loading configuration from config.env..."
source "$SCRIPT_DIR/config.env"

# Validate required settings
if [ -z "${S3_BUCKET:-}" ]; then
    log_error "S3_BUCKET is not set in config.env"
    exit 1
fi

if [ -z "${SOURCE_DIR:-}" ]; then
    log_error "SOURCE_DIR is not set in config.env"
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Check if datasync-s5cmd.sh exists
DATASYNC_SCRIPT="$SCRIPT_DIR/../../scripts/datasync-s5cmd.sh"
if [ ! -f "$DATASYNC_SCRIPT" ]; then
    log_error "Upload script not found: $DATASYNC_SCRIPT"
    log_info "Please ensure you're running this from the examples/basic/ directory"
    exit 1
fi

# Check if s5cmd is installed
if ! command -v s5cmd &> /dev/null; then
    log_error "s5cmd is not installed!"
    log_info "Please install s5cmd first:"
    log_info "  cd $SCRIPT_DIR/../.."
    log_info "  ./tools/install-s5cmd.sh"
    exit 1
fi

log_success "Configuration loaded"
log_info "Bucket: s3://$S3_BUCKET/$S3_SUBDIRECTORY"
log_info "Source: $SOURCE_DIR"
echo

# Run the upload
if [ -n "$DRY_RUN" ]; then
    log_warning "DRY-RUN MODE - No files will be uploaded"
    echo
fi

log_info "Starting upload..."
"$DATASYNC_SCRIPT" $DRY_RUN

# Check exit status
if [ $? -eq 0 ]; then
    echo
    log_success "Upload completed successfully!"
else
    echo
    log_error "Upload failed. Check the logs for details."
    exit 1
fi
