#!/bin/bash
#
# datasync-awscli.sh - AWS CLI reference implementation
#
# Reference implementation using AWS CLI for performance comparison
#
# Usage:
#   ./datasync-awscli.sh [OPTIONS]
#
# Options:
#   --dry-run       Preview what would be uploaded without actually uploading
#   --config FILE   Path to configuration file (default: config/awscli.env)
#   --help          Show this help message
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="datasync-awscli"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
DRY_RUN=false
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_DIR}/config/awscli.env}"
LOG_FILE=""
JSON_OUTPUT_FILE=""
START_TIME=""
END_TIME=""
FILES_SYNCED=0
BYTES_TRANSFERRED=0
SYNC_STATUS="unknown"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_header() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${CYAN}=========================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}=========================================${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

AWS CLI reference implementation for S3 upload (optimized settings)

Options:
    --dry-run           Preview what would be uploaded without actually uploading
    --config FILE       Path to configuration file (default: config/awscli.env)
    --help              Show this help message

Configuration:
    Set via environment variables or config file:
        SOURCE_DIR                      Local directory to upload
        S3_BUCKET                       S3 bucket name
        S3_SUBDIRECTORY                 S3 prefix/subdirectory (optional)
        AWS_PROFILE                     AWS profile to use (optional)
        AWS_MAX_CONCURRENT_REQUESTS     Parallel operations (default: 20)
        AWS_MAX_QUEUE_SIZE              Max queue size (default: 10000)
        S3_STORAGE_CLASS                S3 storage class (default: INTELLIGENT_TIERING)

Examples:
    # Upload using config file
    $0

    # Dry run to preview
    $0 --dry-run

    # Use custom config
    $0 --config /path/to/config.env

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Load configuration
load_configuration() {
    log_info "Loading configuration..."

    if [ -f "$CONFIG_FILE" ]; then
        log_info "Loading config from: $CONFIG_FILE"
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
        log_success "Configuration loaded from file"
    else
        log_warn "Config file not found: $CONFIG_FILE"
        log_info "Using environment variables only"
    fi

    # Set defaults for AWS CLI settings (optimized)
    export AWS_MAX_CONCURRENT_REQUESTS="${AWS_MAX_CONCURRENT_REQUESTS:-20}"
    export AWS_MAX_QUEUE_SIZE="${AWS_MAX_QUEUE_SIZE:-10000}"
    export AWS_MAX_BANDWIDTH="${AWS_MAX_BANDWIDTH:-}"
    export S3_STORAGE_CLASS="${S3_STORAGE_CLASS:-INTELLIGENT_TIERING}"

    log_info "Configuration:"
    log_info "  Source:                    ${SOURCE_DIR:-<not set>}"
    log_info "  S3 Bucket:                 ${S3_BUCKET:-<not set>}"
    log_info "  S3 Subdirectory:           ${S3_SUBDIRECTORY:-<root>}"
    log_info "  AWS Profile:               ${AWS_PROFILE:-<default>}"
    log_info "  Concurrent Requests:       $AWS_MAX_CONCURRENT_REQUESTS"
    log_info "  Queue Size:                $AWS_MAX_QUEUE_SIZE"
    log_info "  Storage Class:             $S3_STORAGE_CLASS"
    log_info "  Dry Run:                   $DRY_RUN"
    echo ""
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."

    local errors=0

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found in PATH"
        ((errors++))
    else
        local aws_version
        aws_version=$(aws --version 2>&1)
        log_success "AWS CLI installed: $aws_version"
    fi

    # Check required variables
    if [ -z "${SOURCE_DIR:-}" ]; then
        log_error "SOURCE_DIR not set"
        ((errors++))
    elif [ ! -d "$SOURCE_DIR" ]; then
        log_error "SOURCE_DIR does not exist: $SOURCE_DIR"
        ((errors++))
    else
        log_success "Source directory exists: $SOURCE_DIR"
    fi

    if [ -z "${S3_BUCKET:-}" ]; then
        log_error "S3_BUCKET not set"
        ((errors++))
    else
        log_success "S3 bucket configured: s3://$S3_BUCKET"
    fi

    if [ $errors -gt 0 ]; then
        log_error "Prerequisites validation failed with $errors error(s)"
        exit 1
    fi

    log_success "All prerequisites validated"
    echo ""
}

# Perform sync operation
perform_sync() {
    log_header "Starting S3 Sync (AWS CLI)"

    # Build destination path
    local destination
    if [ -n "${S3_SUBDIRECTORY:-}" ]; then
        destination="s3://${S3_BUCKET}/${S3_SUBDIRECTORY}/"
    else
        destination="s3://${S3_BUCKET}/"
    fi

    log_info "Syncing: $SOURCE_DIR -> $destination"
    echo ""

    # Build AWS CLI command
    local aws_cmd="aws s3 sync"
    aws_cmd+=" \"$SOURCE_DIR\""
    aws_cmd+=" \"$destination\""
    aws_cmd+=" --storage-class $S3_STORAGE_CLASS"

    if [ "$DRY_RUN" = true ]; then
        aws_cmd+=" --dryrun"
        log_warn "DRY RUN MODE - No files will be uploaded"
    fi

    log_info "AWS CLI Configuration:"
    log_info "  AWS_MAX_CONCURRENT_REQUESTS=$AWS_MAX_CONCURRENT_REQUESTS"
    log_info "  AWS_MAX_QUEUE_SIZE=$AWS_MAX_QUEUE_SIZE"
    echo ""

    # Execute sync
    START_TIME=$(date +%s)
    local start_time_iso
    start_time_iso=$(date -Iseconds)

    log_info "Upload started at: $start_time_iso"
    echo ""

    if eval "$aws_cmd" 2>&1 | tee -a "$LOG_FILE"; then
        SYNC_STATUS="success"
        log_success "Sync completed successfully"
    else
        SYNC_STATUS="failed"
        log_error "Sync failed"
        return 1
    fi

    END_TIME=$(date +%s)
    local end_time_iso
    end_time_iso=$(date -Iseconds)

    echo ""
    log_info "Upload finished at: $end_time_iso"

    # Calculate transferred data
    BYTES_TRANSFERRED=$(du -sb "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')
    FILES_SYNCED=$(find "$SOURCE_DIR" -type f | wc -l)

    return 0
}

# Generate JSON output
generate_json_output() {
    log_info "Generating JSON output..."

    local duration=$((END_TIME - START_TIME))
    local throughput_mbps=0

    if [ $duration -gt 0 ] && [ "$BYTES_TRANSFERRED" -gt 0 ]; then
        throughput_mbps=$(echo "scale=2; ($BYTES_TRANSFERRED / 1048576) / $duration" | bc)
    fi

    local source_size_human
    source_size_human=$(du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')

    local destination
    if [ -n "${S3_SUBDIRECTORY:-}" ]; then
        destination="s3://${S3_BUCKET}/${S3_SUBDIRECTORY}/"
    else
        destination="s3://${S3_BUCKET}/"
    fi

    JSON_OUTPUT_FILE="${LOG_FILE%.log}.json"

    cat > "$JSON_OUTPUT_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "duration_seconds": $duration,
    "files_synced": $FILES_SYNCED,
    "bytes_transferred": $BYTES_TRANSFERRED,
    "source_size": "$source_size_human",
    "s3_objects": $FILES_SYNCED,
    "status": "$SYNC_STATUS",
    "tool": "aws-cli",
    "tool_version": "$(aws --version 2>&1 | awk '{print $1}')",
    "throughput_mbps": $throughput_mbps,
    "source": "$SOURCE_DIR",
    "destination": "$destination",
    "dry_run": $DRY_RUN,
    "configuration": {
        "max_concurrent_requests": $AWS_MAX_CONCURRENT_REQUESTS,
        "max_queue_size": $AWS_MAX_QUEUE_SIZE,
        "storage_class": "$S3_STORAGE_CLASS"
    }
}
EOF

    log_success "JSON output saved to: $JSON_OUTPUT_FILE"
}

# Display summary
display_summary() {
    log_header "Upload Summary"

    local duration=$((END_TIME - START_TIME))
    local throughput_mbps=0

    if [ $duration -gt 0 ] && [ "$BYTES_TRANSFERRED" -gt 0 ]; then
        throughput_mbps=$(echo "scale=2; ($BYTES_TRANSFERRED / 1048576) / $duration" | bc)
    fi

    local source_size_human
    source_size_human=$(du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')

    echo ""
    echo "  Status:           $SYNC_STATUS"
    echo "  Files synced:     $FILES_SYNCED"
    echo "  Data transferred: $source_size_human ($BYTES_TRANSFERRED bytes)"
    echo "  Duration:         ${duration}s"
    echo "  Throughput:       ${throughput_mbps} MB/s"
    echo "  Tool:             AWS CLI (optimized)"
    echo ""
    echo "  Log file:         $LOG_FILE"
    echo "  JSON output:      $JSON_OUTPUT_FILE"
    echo ""

    if [ "$SYNC_STATUS" = "success" ]; then
        log_success "Upload completed successfully!"
    else
        log_error "Upload failed!"
        return 1
    fi
}

# Main execution
main() {
    parse_arguments "$@"

    # Setup logging
    local log_dir="${PROJECT_DIR}/logs"
    mkdir -p "$log_dir"
    LOG_FILE="${log_dir}/datasync-awscli-$(date +%Y%m%d-%H%M%S).log"

    log_header "DataSync S3 Upload - AWS CLI Edition"
    log_info "Version: $SCRIPT_VERSION"
    log_info "Started: $(date -Iseconds)"
    echo ""

    load_configuration
    validate_prerequisites

    if perform_sync; then
        SYNC_STATUS="success"
    else
        SYNC_STATUS="failed"
    fi

    generate_json_output
    display_summary

    if [ "$SYNC_STATUS" = "success" ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
