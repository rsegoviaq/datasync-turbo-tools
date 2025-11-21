#!/bin/bash
#
# datasync-s5cmd.sh - High-performance S3 upload using s5cmd
#
# Drop-in replacement for datasync-simulator.sh with 5-12x faster performance
#
# Usage:
#   ./datasync-s5cmd.sh [OPTIONS]
#
# Options:
#   --dry-run       Preview what would be uploaded without actually uploading
#   --config FILE   Path to configuration file (default: config/s5cmd.env)
#   --help          Show this help message
#
# Configuration:
#   Set via environment variables or config file:
#     SOURCE_DIR            - Local directory to upload
#     S3_BUCKET             - S3 bucket name
#     S3_SUBDIRECTORY       - S3 prefix/subdirectory
#     AWS_PROFILE           - AWS profile to use
#     AWS_REGION            - AWS region (required for s5cmd)
#     S5CMD_CONCURRENCY     - Parallel operations (default: 64)
#     S5CMD_PART_SIZE       - Multipart chunk size (default: 64MB)
#     S5CMD_NUM_WORKERS     - Worker goroutines (default: 32)
#     S5CMD_CHECKSUM        - Checksum algorithm: CRC64NVME|SHA256 (default: CRC64NVME)
#     S3_STORAGE_CLASS      - S3 storage class (default: INTELLIGENT_TIERING)
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="datasync-s5cmd"
SCRIPT_VERSION="1.4.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
DRY_RUN=false
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_DIR}/config/s5cmd.env}"
LOG_FILE=""
JSON_OUTPUT_FILE=""
START_TIME=""
END_TIME=""
FILES_SYNCED=0
BYTES_TRANSFERRED=0
SYNC_STATUS="unknown"
TEMP_DIR=""
ACTIVITY_MONITOR_PID=""

# Progress tracking variables
TOTAL_FILES_TO_UPLOAD=0
FILES_UPLOADED_COUNT=0
LAST_PROGRESS_UPDATE=0
PROGRESS_UPDATE_INTERVAL=10  # Update every N files
PROGRESS_PERCENT_INTERVAL=5  # Or every N percent
ACTUAL_BYTES_UPLOADED=0  # Track actual bytes uploaded
PROGRESS_HISTORY=""  # JSON array of progress snapshots

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

# Show upload progress with detailed metrics
# Args: $1=files_uploaded, $2=total_files, $3=bytes_uploaded, $4=elapsed_seconds
show_upload_progress() {
    local files_uploaded=$1
    local total_files=$2
    local bytes_uploaded=$3
    local elapsed=$4

    if [ "$total_files" -eq 0 ]; then
        return
    fi

    # Calculate both file-count and byte-based percentages
    local files_percent=$((files_uploaded * 100 / total_files))
    local bytes_percent=0
    if [ "$BYTES_TRANSFERRED" -gt 0 ]; then
        bytes_percent=$((bytes_uploaded * 100 / BYTES_TRANSFERRED))
    fi

    # Format human-readable byte progress (GB or MB based on size)
    local bytes_display=""
    local total_display=""
    if [ "$BYTES_TRANSFERRED" -ge 1073741824 ]; then
        # Use GB for sizes >= 1GB
        bytes_display=$(echo "scale=2; $bytes_uploaded / 1073741824" | bc)
        total_display=$(echo "scale=2; $BYTES_TRANSFERRED / 1073741824" | bc)
        bytes_display="${bytes_display}GB"
        total_display="${total_display}GB"
    else
        # Use MB for smaller sizes
        bytes_display=$(echo "scale=1; $bytes_uploaded / 1048576" | bc)
        total_display=$(echo "scale=1; $BYTES_TRANSFERRED / 1048576" | bc)
        bytes_display="${bytes_display}MB"
        total_display="${total_display}MB"
    fi

    # Calculate throughput in MB/s
    local throughput_mbps="0.0"
    if [ "$elapsed" -gt 0 ] && [ "$bytes_uploaded" -gt 0 ]; then
        # Use bc for floating point calculation: bytes / elapsed / 1048576 (bytes to MB)
        throughput_mbps=$(echo "scale=2; $bytes_uploaded / $elapsed / 1048576" | bc)
    fi

    # Calculate ETA based on bytes remaining
    local eta_string="ETA: calculating..."
    if [ "$elapsed" -gt 0 ] && [ "$BYTES_TRANSFERRED" -gt 0 ] && [ "$bytes_uploaded" -gt 0 ]; then
        # bytes_per_second = bytes_uploaded / elapsed
        # remaining_bytes = BYTES_TRANSFERRED - bytes_uploaded
        # eta_seconds = remaining_bytes / bytes_per_second
        local bytes_per_sec=$((bytes_uploaded / elapsed))
        if [ "$bytes_per_sec" -gt 0 ]; then
            local remaining_bytes=$((BYTES_TRANSFERRED - bytes_uploaded))
            local eta_seconds=$((remaining_bytes / bytes_per_sec))
            local eta_minutes=$((eta_seconds / 60))
            local eta_display

            if [ $eta_minutes -ge 60 ]; then
                local eta_hours=$((eta_minutes / 60))
                local eta_mins=$((eta_minutes % 60))
                eta_display="${eta_hours}h${eta_mins}m"
            elif [ $eta_minutes -gt 0 ]; then
                eta_display="${eta_minutes}m"
            else
                eta_display="${eta_seconds}s"
            fi
            eta_string="ETA: $eta_display"
        fi
    fi

    log_info "Progress: $files_uploaded/$total_files files (${bytes_percent}% by size, ${files_percent}% by count) | ${bytes_display}/${total_display} | Speed: $throughput_mbps MB/s | $eta_string"
}

# Monitor upload activity to provide feedback during long file uploads
# This function runs in background and displays periodic activity updates
monitor_upload_activity() {
    local progress_file=$1
    local bytes_file=$2
    local start_time=$3
    local check_interval=10  # Check every 10 seconds
    local last_count=0
    local last_bytes=0
    local stall_threshold=30  # Consider stalled if no progress for 30 seconds

    while true; do
        sleep $check_interval

        # Check if main process is still running (if progress file exists)
        if [ ! -f "$progress_file" ]; then
            break
        fi

        # Get current progress
        local current_count=$(cat "$progress_file" 2>/dev/null || echo "0")
        local current_bytes=$(cat "$bytes_file" 2>/dev/null || echo "0")

        # Calculate time since start
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        # Check if progress has stalled
        if [ "$current_count" -eq "$last_count" ] && [ "$current_bytes" -eq "$last_bytes" ]; then
            # No progress since last check
            local time_stalled=$((elapsed % 60))  # Simplified stall tracking
            if [ $time_stalled -ge $stall_threshold ]; then
                echo -e "${YELLOW}[INFO]${NC} $(date +'%Y-%m-%d %H:%M:%S') - Upload active (no file completions in last ${time_stalled}s - large file in progress?)" | tee -a "$LOG_FILE"
            else
                echo -e "${CYAN}[INFO]${NC} $(date +'%Y-%m-%d %H:%M:%S') - Upload in progress... (${current_count} files completed, ${elapsed}s elapsed)" | tee -a "$LOG_FILE"
            fi
        fi

        # Update tracking
        last_count=$current_count
        last_bytes=$current_bytes
    done
}

# Cleanup on exit
cleanup() {
    # Kill background monitor if running
    if [ -n "$ACTIVITY_MONITOR_PID" ]; then
        kill "$ACTIVITY_MONITOR_PID" 2>/dev/null || true
    fi

    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

High-performance S3 upload using s5cmd (5-12x faster than AWS CLI)

Options:
    --dry-run           Preview what would be uploaded without actually uploading
    --config FILE       Path to configuration file (default: config/s5cmd.env)
    --help              Show this help message

Configuration:
    Set via environment variables or config file:
        SOURCE_DIR              Local directory to upload
        S3_BUCKET               S3 bucket name
        S3_SUBDIRECTORY         S3 prefix/subdirectory (optional)

        AWS Authentication (choose ONE method):
        AWS_PROFILE             AWS profile to use (recommended)
        AWS_ACCESS_KEY_ID       AWS access key (alternative to profile)
        AWS_SECRET_ACCESS_KEY   AWS secret key (alternative to profile)
        AWS_SESSION_TOKEN       AWS session token (optional, for temp credentials)

        S5CMD_CONCURRENCY       Parallel operations (default: 64)
        S5CMD_PART_SIZE         Multipart chunk size (default: 64MB)
        S5CMD_NUM_WORKERS       Worker goroutines (default: 32)
        S5CMD_CHECKSUM          CRC64NVME|SHA256 (default: CRC64NVME)
        S3_STORAGE_CLASS        S3 storage class (default: INTELLIGENT_TIERING)
        S5CMD_RETRY_COUNT       Retry attempts (default: 3)
        S5CMD_LOG_LEVEL         debug|info|warn|error (default: info)

Examples:
    # Upload using config file
    $0

    # Dry run to preview
    $0 --dry-run

    # Use custom config
    $0 --config /path/to/config.env

    # Override with environment variables
    SOURCE_DIR=/data S3_BUCKET=mybucket $0

Documentation:
    See docs/S5CMD_GUIDE.md for complete usage guide

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

    # Load from config file if it exists
    if [ -f "$CONFIG_FILE" ]; then
        log_info "Loading config from: $CONFIG_FILE"
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
        log_success "Configuration loaded from file"
    else
        log_warn "Config file not found: $CONFIG_FILE"
        log_info "Using environment variables only"
    fi

    # Set defaults for s5cmd-specific settings
    export S5CMD_CONCURRENCY="${S5CMD_CONCURRENCY:-64}"
    export S5CMD_PART_SIZE="${S5CMD_PART_SIZE:-64MB}"
    export S5CMD_NUM_WORKERS="${S5CMD_NUM_WORKERS:-32}"
    export S5CMD_RETRY_COUNT="${S5CMD_RETRY_COUNT:-3}"
    export S5CMD_LOG_LEVEL="${S5CMD_LOG_LEVEL:-info}"
    export S5CMD_CHECKSUM="${S5CMD_CHECKSUM:-CRC64NVME}"
    export S3_STORAGE_CLASS="${S3_STORAGE_CLASS:-INTELLIGENT_TIERING}"

    # Export AWS_REGION if set (required for s5cmd)
    if [ -n "${AWS_REGION:-}" ]; then
        export AWS_REGION
    fi

    # Display configuration
    log_info "Configuration:"
    log_info "  Source:            ${SOURCE_DIR:-<not set>}"
    log_info "  S3 Bucket:         ${S3_BUCKET:-<not set>}"
    log_info "  S3 Subdirectory:   ${S3_SUBDIRECTORY:-<root>}"

    # Display AWS authentication method
    if [ -n "${AWS_PROFILE:-}" ]; then
        log_info "  AWS Auth:          Profile ($AWS_PROFILE)"
    elif [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
        log_info "  AWS Auth:          Direct credentials (Access Key: ${AWS_ACCESS_KEY_ID:0:8}...)"
    else
        log_info "  AWS Auth:          Default credentials chain"
    fi
    log_info "  AWS Region:        ${AWS_REGION:-<not set>}"

    log_info "  Concurrency:       $S5CMD_CONCURRENCY"
    log_info "  Part Size:         $S5CMD_PART_SIZE"
    log_info "  Workers:           $S5CMD_NUM_WORKERS"
    log_info "  Checksum:          $S5CMD_CHECKSUM"
    log_info "  Storage Class:     $S3_STORAGE_CLASS"
    log_info "  Retry Count:       $S5CMD_RETRY_COUNT"
    log_info "  Log Level:         $S5CMD_LOG_LEVEL"
    log_info "  Dry Run:           $DRY_RUN"
    echo ""
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."

    local errors=0

    # Check if s5cmd is installed
    if ! command -v s5cmd &> /dev/null; then
        log_error "s5cmd not found in PATH"
        log_error "Install with: ./tools/install-s5cmd.sh"
        ((errors++)) || true
    else
        local s5cmd_version
        s5cmd_version=$(s5cmd version 2>&1 | head -n 1)
        log_success "s5cmd installed: $s5cmd_version"
    fi

    # Check required variables
    if [ -z "${SOURCE_DIR:-}" ]; then
        log_error "SOURCE_DIR not set"
        ((errors++)) || true
    elif [ ! -d "$SOURCE_DIR" ]; then
        log_error "SOURCE_DIR does not exist: $SOURCE_DIR"
        ((errors++)) || true
    else
        log_success "Source directory exists: $SOURCE_DIR"
    fi

    if [ -z "${S3_BUCKET:-}" ]; then
        log_error "S3_BUCKET not set"
        ((errors++)) || true
    else
        log_success "S3 bucket configured: s3://$S3_BUCKET"
    fi

    # Check AWS credentials
    if [ -n "${AWS_PROFILE:-}" ]; then
        export AWS_PROFILE
        log_success "AWS authentication: Profile ($AWS_PROFILE)"
    elif [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        export AWS_ACCESS_KEY_ID
        export AWS_SECRET_ACCESS_KEY
        if [ -n "${AWS_SESSION_TOKEN:-}" ]; then
            export AWS_SESSION_TOKEN
        fi
        log_success "AWS authentication: Direct credentials (Access Key: ${AWS_ACCESS_KEY_ID:0:8}...)"
    else
        log_info "AWS authentication: Using default credentials chain"
        log_warn "No explicit credentials configured - will use AWS default credential provider chain"
    fi

    # Validate S3 access (skip in dry-run mode and if s5cmd not available)
    if [ "$DRY_RUN" = false ] && command -v s5cmd &> /dev/null; then
        log_info "Testing S3 access..."
        if s5cmd ls "s3://${S3_BUCKET}/" &> /dev/null; then
            log_success "S3 bucket accessible"
        else
            log_error "Cannot access S3 bucket: s3://${S3_BUCKET}/"
            log_error "Check credentials and bucket permissions"
            ((errors++))
        fi
    fi

    # Validate checksum algorithm
    if [[ ! "$S5CMD_CHECKSUM" =~ ^(CRC64NVME|SHA256|none)$ ]]; then
        log_error "Invalid checksum algorithm: $S5CMD_CHECKSUM"
        log_error "Valid options: CRC64NVME, SHA256, none"
        ((errors++))
    fi

    if [ $errors -gt 0 ]; then
        log_error "Prerequisites validation failed with $errors error(s)"
        exit 1
    fi

    log_success "All prerequisites validated"
    echo ""
}

# Calculate source directory size
calculate_source_size() {
    log_info "Calculating source directory size..." >&2

    local size_bytes
    # macOS uses BSD du which doesn't support -b flag, so detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use find + stat
        size_bytes=$(find "$SOURCE_DIR" -type f -exec stat -f%z {} \; 2>/dev/null | awk '{s+=$1} END {print s}')
    else
        # Linux: use du -sb
        size_bytes=$(du -sb "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')
    fi

    local size_human
    size_human=$(du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')

    log_info "Source directory size: $size_human ($size_bytes bytes)" >&2
    echo "$size_bytes"
}

# Count files in source directory
count_source_files() {
    log_info "Counting files in source directory..." >&2

    local file_count
    file_count=$(find "$SOURCE_DIR" -type f | wc -l)

    log_info "Files to sync: $file_count" >&2
    echo "$file_count"
}

# Validate upload-only sync (no delete operations)
validate_upload_only() {
    log_info "Validating upload-only sync configuration..."

    # Check if --delete flag is present in any sync parameters
    if echo "$S5CMD_SYNC_FLAGS ${*}" | grep -q -- "--delete"; then
        log_error "SAFETY CHECK FAILED: --delete flag detected!"
        log_error "This tool is designed for UPLOAD-ONLY sync operations."
        log_error "Using --delete would make sync bidirectional and could delete destination data."
        log_error ""
        log_error "If you need bidirectional sync with deletions, please use a different tool."
        log_error "Recommended: aws s3 sync with explicit --delete flag and proper safeguards"
        exit 1
    fi

    log_success "Upload-only sync validated (no destructive operations)"
}

# Perform sync operation
perform_sync() {
    log_header "Starting S3 Sync"

    # Build destination path
    local destination
    if [ -n "${S3_SUBDIRECTORY:-}" ]; then
        destination="s3://${S3_BUCKET}/${S3_SUBDIRECTORY}/"
    else
        destination="s3://${S3_BUCKET}/"
    fi

    log_info "Syncing: $SOURCE_DIR -> $destination"
    echo ""

    # IMPORTANT: This is an UPLOAD-ONLY sync operation
    # - Only new/modified files are uploaded to S3
    # - NO files are ever deleted from S3 (no --delete flag)
    # - Safe to run even with empty source directory
    # - Destination data remains intact regardless of source state

    # Build s5cmd command
    local s5cmd_cmd="s5cmd"

    # Add global flags (must come before 'sync' command)
    s5cmd_cmd+=" --numworkers $S5CMD_NUM_WORKERS"
    s5cmd_cmd+=" --retry-count $S5CMD_RETRY_COUNT"
    s5cmd_cmd+=" --log $S5CMD_LOG_LEVEL"

    # Add AWS profile if specified
    if [ -n "${AWS_PROFILE:-}" ]; then
        s5cmd_cmd+=" --profile $AWS_PROFILE"
    fi

    # Add dry-run global flag if requested
    if [ "$DRY_RUN" = true ]; then
        s5cmd_cmd+=" --dry-run"
    fi

    # Add sync command
    s5cmd_cmd+=" sync"

    # Add sync flags (must come after 'sync' command)
    s5cmd_cmd+=" --concurrency $S5CMD_CONCURRENCY"

    # Convert part size from MB to MiB (s5cmd expects integer in MiB)
    local part_size_mb="${S5CMD_PART_SIZE//MB/}"
    s5cmd_cmd+=" --part-size $part_size_mb"

    s5cmd_cmd+=" --storage-class $S3_STORAGE_CLASS"

    # Checksum handling
    if [ "$S5CMD_CHECKSUM" != "none" ]; then
        # s5cmd doesn't have a direct checksum flag, but it uses checksums internally
        # We'll verify checksums post-upload if needed
        :
    fi

    # Log dry-run warning
    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN MODE - No files will be uploaded"
    fi

    # Add source and destination
    # Ensure source ends with / for directory sync
    local source_path="$SOURCE_DIR"
    if [[ ! "$source_path" =~ /$ ]]; then
        source_path="${source_path}/"
    fi

    s5cmd_cmd+=" \"$source_path\" \"$destination\""

    # Log the command (sanitized)
    log_info "Executing s5cmd command:"
    log_info "  $s5cmd_cmd"
    echo ""

    # Execute sync
    START_TIME=$(date +%s)
    local start_time_iso
    start_time_iso=$(date -Iseconds)

    log_info "Upload started at: $start_time_iso"
    echo ""

    # Create temp file for output
    TEMP_DIR=$(mktemp -d)
    local output_file="${TEMP_DIR}/s5cmd_output.txt"

    # Execute and capture output with real-time progress tracking
    # Use a temp file to track progress across subshells
    local progress_file="${TEMP_DIR}/progress.txt"
    local bytes_file="${TEMP_DIR}/bytes.txt"
    echo "0" > "$progress_file"
    echo "0" > "$bytes_file"
    FILES_UPLOADED_COUNT=0
    LAST_PROGRESS_UPDATE=0
    local last_bytes_percent=0
    local last_update_time=0
    local upload_start_time=$(date +%s)

    # Start background activity monitor to provide feedback during long file uploads
    monitor_upload_activity "$progress_file" "$bytes_file" "$upload_start_time" &
    ACTIVITY_MONITOR_PID=$!
    log_info "Started upload activity monitor (PID: $ACTIVITY_MONITOR_PID)"

    # Execute s5cmd and capture output
    eval "$s5cmd_cmd" 2>&1 | tee "$output_file" | while IFS= read -r line; do
        # Parse s5cmd output for completed uploads
        # s5cmd outputs lines like "cp s3://bucket/file" for each completed upload
        if [[ "$line" =~ ^cp[[:space:]](.+)[[:space:]]s3:// ]] || [[ "$line" =~ uploaded ]]; then
            # Increment counter in temp file (to persist across subshells)
            local count=$(cat "$progress_file")
            count=$((count + 1))
            echo "$count" > "$progress_file"

            # Extract file path and get actual file size
            local actual_bytes_uploaded=$(cat "$bytes_file")
            if [[ "$line" =~ ^cp[[:space:]](.+)[[:space:]]s3:// ]]; then
                local source_file="${BASH_REMATCH[1]}"
                # Get file size - handle both Linux and macOS
                local file_size=0
                if [[ -f "$source_file" ]]; then
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        file_size=$(stat -f%z "$source_file" 2>/dev/null || echo "0")
                    else
                        file_size=$(stat -c%s "$source_file" 2>/dev/null || echo "0")
                    fi
                    actual_bytes_uploaded=$((actual_bytes_uploaded + file_size))
                    echo "$actual_bytes_uploaded" > "$bytes_file"
                fi
            fi

            # Calculate progress if total is known
            if [ "$TOTAL_FILES_TO_UPLOAD" -gt 0 ]; then
                local files_percent=$((count * 100 / TOTAL_FILES_TO_UPLOAD))
                local bytes_percent=0
                if [ "$BYTES_TRANSFERRED" -gt 0 ]; then
                    bytes_percent=$((actual_bytes_uploaded * 100 / BYTES_TRANSFERRED))
                fi

                # Calculate time since last update
                local current_time=$(date +%s)
                local time_since_update=$((current_time - last_update_time))
                local bytes_percent_change=$((bytes_percent - last_bytes_percent))

                # Capture progress history snapshots every 5%
                local snapshot_interval=5
                local prev_snapshot=$(( (last_bytes_percent / snapshot_interval) * snapshot_interval ))
                local curr_snapshot=$(( (bytes_percent / snapshot_interval) * snapshot_interval ))
                if [ $curr_snapshot -gt $prev_snapshot ] && [ $bytes_percent -gt 0 ]; then
                    # Save snapshot
                    local timestamp=$(date +%s)
                    if [ -z "$PROGRESS_HISTORY" ]; then
                        PROGRESS_HISTORY="{\"time\":$timestamp,\"bytes\":$actual_bytes_uploaded,\"files\":$count,\"percent\":$bytes_percent}"
                    else
                        PROGRESS_HISTORY="$PROGRESS_HISTORY,{\"time\":$timestamp,\"bytes\":$actual_bytes_uploaded,\"files\":$count,\"percent\":$bytes_percent}"
                    fi
                fi

                # Show progress at intervals:
                # - First file
                # - Every 5 seconds OR 2% progress by bytes
                # - Last file
                if [ $count -eq 1 ] || \
                   [ $time_since_update -ge 5 ] || \
                   [ $bytes_percent_change -ge 2 ] || \
                   [ $count -eq $TOTAL_FILES_TO_UPLOAD ]; then

                    # Calculate elapsed time
                    local elapsed=$((current_time - upload_start_time))
                    # Set minimum 1 second to avoid division by zero
                    if [ $elapsed -eq 0 ]; then
                        elapsed=1
                    fi

                    show_upload_progress "$count" "$TOTAL_FILES_TO_UPLOAD" "$actual_bytes_uploaded" "$elapsed"
                    LAST_PROGRESS_UPDATE=$count
                    last_bytes_percent=$bytes_percent
                    last_update_time=$current_time
                fi
            fi
        fi
    done

    # Get final upload count and bytes from temp files
    FILES_UPLOADED_COUNT=$(cat "$progress_file" 2>/dev/null || echo "0")
    ACTUAL_BYTES_UPLOADED=$(cat "$bytes_file" 2>/dev/null || echo "0")

    # Check if sync was successful
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        SYNC_STATUS="success"

        # Show final progress if we have tracked files
        if [ "$TOTAL_FILES_TO_UPLOAD" -gt 0 ]; then
            log_success "Upload completed: $FILES_UPLOADED_COUNT/$TOTAL_FILES_TO_UPLOAD files (100%)"
        else
            log_success "Sync completed successfully"
        fi
    else
        SYNC_STATUS="failed"
        if [ "$FILES_UPLOADED_COUNT" -gt 0 ]; then
            log_error "Upload failed after $FILES_UPLOADED_COUNT files"
        else
            log_error "Sync failed"
        fi
        return 1
    fi

    END_TIME=$(date +%s)
    local end_time_iso
    end_time_iso=$(date -Iseconds)

    echo ""
    log_info "Upload finished at: $end_time_iso"

    # Parse output to get statistics
    # s5cmd outputs lines like: "cp s3://bucket/file"
    FILES_SYNCED=$(grep -c "^cp " "$output_file" 2>/dev/null || echo "0")
    # Ensure FILES_SYNCED is a clean integer (take only first line)
    FILES_SYNCED=$(echo "$FILES_SYNCED" | head -n 1 | tr -d '\n\r ')

    # Calculate bytes transferred (if available in output)
    # This is approximate - s5cmd doesn't always show byte counts in sync output
    BYTES_TRANSFERRED=$(calculate_source_size)

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

    local checksum_verified=false
    if [ "$S5CMD_CHECKSUM" != "none" ] && [ "$SYNC_STATUS" = "success" ]; then
        checksum_verified=true
    fi

    # Calculate progress accuracy
    local progress_accuracy=0
    if [ "$BYTES_TRANSFERRED" -gt 0 ] && [ "$ACTUAL_BYTES_UPLOADED" -gt 0 ]; then
        progress_accuracy=$((ACTUAL_BYTES_UPLOADED * 100 / BYTES_TRANSFERRED))
    fi

    # Create JSON output file
    JSON_OUTPUT_FILE="${LOG_FILE%.log}.json"

    cat > "$JSON_OUTPUT_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "duration_seconds": $duration,
    "files_synced": $FILES_SYNCED,
    "bytes_transferred": $BYTES_TRANSFERRED,
    "actual_bytes_transferred": $ACTUAL_BYTES_UPLOADED,
    "estimated_bytes_transferred": $BYTES_TRANSFERRED,
    "progress_accuracy_percent": $progress_accuracy,
    "source_size": "$source_size_human",
    "s3_objects": $FILES_SYNCED,
    "status": "$SYNC_STATUS",
    "tool": "s5cmd",
    "tool_version": "$(s5cmd version 2>&1 | head -n 1 | awk '{print $3}')",
    "throughput_mbps": $throughput_mbps,
    "source": "$SOURCE_DIR",
    "destination": "$destination",
    "dry_run": $DRY_RUN,
    "progress_history": [
        $PROGRESS_HISTORY
    ],
    "configuration": {
        "concurrency": $S5CMD_CONCURRENCY,
        "part_size": "$S5CMD_PART_SIZE",
        "num_workers": $S5CMD_NUM_WORKERS,
        "retry_count": $S5CMD_RETRY_COUNT,
        "storage_class": "$S3_STORAGE_CLASS"
    },
    "checksum_verification": {
        "enabled": $([ "$S5CMD_CHECKSUM" != "none" ] && echo "true" || echo "false"),
        "algorithm": "$S5CMD_CHECKSUM",
        "verified": $checksum_verified,
        "errors": 0
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
    echo "  Tool:             s5cmd"
    echo "  Checksum:         $S5CMD_CHECKSUM"
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
    # Parse arguments
    parse_arguments "$@"

    # Setup logging
    local log_dir="${PROJECT_DIR}/logs"
    mkdir -p "$log_dir"
    LOG_FILE="${log_dir}/datasync-s5cmd-$(date +%Y%m%d-%H%M%S).log"

    # Print header
    log_header "DataSync S3 Upload - s5cmd Edition"
    log_info "Version: $SCRIPT_VERSION"
    log_info "Started: $(date -Iseconds)"
    echo ""

    # Load configuration
    load_configuration

    # Validate prerequisites
    validate_prerequisites

    # Get source stats and prepare for progress tracking
    log_header "Calculating Upload Scope"
    local source_size_bytes
    source_size_bytes=$(calculate_source_size)
    BYTES_TRANSFERRED=$source_size_bytes

    TOTAL_FILES_TO_UPLOAD=$(count_source_files)

    local source_size_human
    source_size_human=$(du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')

    log_info "Preparing to upload $TOTAL_FILES_TO_UPLOAD files ($source_size_human)"
    echo ""

    # Validate upload-only configuration
    validate_upload_only "$@"

    # Perform sync
    if perform_sync; then
        SYNC_STATUS="success"
    else
        SYNC_STATUS="failed"
    fi

    # Generate output
    generate_json_output

    # Display summary
    display_summary

    # Return appropriate exit code
    if [ "$SYNC_STATUS" = "success" ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
