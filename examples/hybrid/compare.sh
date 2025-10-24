#!/bin/bash
#
# DataSync Turbo Tools - Comparison Script
# Run both AWS CLI and s5cmd uploads and compare performance
#
# Usage:
#   ./compare.sh [--test-size SIZE]
#
# Examples:
#   ./compare.sh                    # Use existing files
#   ./compare.sh --test-size 1GB    # Generate 1GB test data
#   ./compare.sh --test-size 5GB    # Generate 5GB test data
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

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

log_section() {
    echo
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo
}

show_help() {
    cat << EOF
DataSync Turbo Tools - Performance Comparison

USAGE:
    ./compare.sh [OPTIONS]

OPTIONS:
    --test-size SIZE    Generate test data of specified size (e.g., 1GB, 5GB)
    --help              Show this help message

DESCRIPTION:
    Runs both AWS CLI and s5cmd uploads on the same dataset and compares:
    - Upload time
    - Throughput (MB/s)
    - CPU usage
    - Memory usage
    - Cost (if available)

EXAMPLES:
    ./compare.sh                    # Use existing files
    ./compare.sh --test-size 1GB    # Generate 1GB test data
    ./compare.sh --test-size 5GB    # Generate 5GB test data

REQUIREMENTS:
    - Both AWS CLI and s5cmd must be installed
    - AWS credentials configured
    - S3 bucket accessible

OUTPUT:
    Results are saved to:
    - ./logs/comparison-TIMESTAMP.txt
    - ./logs/comparison-TIMESTAMP.json
EOF
}

# Generate test data
generate_test_data() {
    local size=$1
    local test_dir="$SCRIPT_DIR/test-data"

    log_info "Generating ${size} of test data in $test_dir..."

    mkdir -p "$test_dir"

    # Convert size to MB
    local size_mb
    case ${size^^} in
        *GB)
            size_mb=$((${size%GB} * 1024))
            ;;
        *MB)
            size_mb=${size%MB}
            ;;
        *)
            log_error "Invalid size format: $size (use 1GB, 500MB, etc.)"
            return 1
            ;;
    esac

    # Generate multiple files
    local num_files=10
    local file_size_mb=$((size_mb / num_files))

    log_info "Creating $num_files files of ${file_size_mb}MB each..."

    for i in $(seq 1 $num_files); do
        dd if=/dev/urandom of="$test_dir/test-file-$i.bin" bs=1M count=$file_size_mb 2>/dev/null
        echo -n "."
    done
    echo

    log_success "Test data generated: $test_dir"
}

# Run AWS CLI upload
run_awscli_upload() {
    log_section "Running AWS CLI Upload"

    # Load AWS CLI config
    source "$SCRIPT_DIR/awscli-config.env"

    # Create log directory
    mkdir -p "$LOG_DIR"

    # Run upload
    local start_time=$(date +%s)
    "$PROJECT_ROOT/scripts/datasync-awscli.sh"
    local end_time=$(date +%s)

    local duration=$((end_time - start_time))

    log_success "AWS CLI upload completed in ${duration}s"

    # Save results
    echo "$duration" > /tmp/awscli-duration
}

# Run s5cmd upload
run_s5cmd_upload() {
    log_section "Running s5cmd Upload"

    # Load s5cmd config
    source "$SCRIPT_DIR/s5cmd-config.env"

    # Create log directory
    mkdir -p "$LOG_DIR"

    # Run upload
    local start_time=$(date +%s)
    "$PROJECT_ROOT/scripts/datasync-s5cmd.sh"
    local end_time=$(date +%s)

    local duration=$((end_time - start_time))

    log_success "s5cmd upload completed in ${duration}s"

    # Save results
    echo "$duration" > /tmp/s5cmd-duration
}

# Compare results
compare_results() {
    log_section "Comparison Results"

    # Load durations
    local awscli_duration=$(cat /tmp/awscli-duration)
    local s5cmd_duration=$(cat /tmp/s5cmd-duration)

    # Load JSON results
    source "$SCRIPT_DIR/awscli-config.env"
    local awscli_json="$JSON_OUTPUT_DIR/latest.json"

    source "$SCRIPT_DIR/s5cmd-config.env"
    local s5cmd_json="$JSON_OUTPUT_DIR/latest.json"

    # Extract metrics
    local awscli_throughput=$(jq -r '.throughput_mbps // 0' "$awscli_json" 2>/dev/null || echo 0)
    local awscli_files=$(jq -r '.files_synced // 0' "$awscli_json" 2>/dev/null || echo 0)
    local awscli_bytes=$(jq -r '.bytes_transferred // 0' "$awscli_json" 2>/dev/null || echo 0)

    local s5cmd_throughput=$(jq -r '.throughput_mbps // 0' "$s5cmd_json" 2>/dev/null || echo 0)
    local s5cmd_files=$(jq -r '.files_synced // 0' "$s5cmd_json" 2>/dev/null || echo 0)
    local s5cmd_bytes=$(jq -r '.bytes_transferred // 0' "$s5cmd_json" 2>/dev/null || echo 0)

    # Calculate improvement
    local time_improvement=$(echo "scale=2; $awscli_duration / $s5cmd_duration" | bc)
    local throughput_improvement=$(echo "scale=2; $s5cmd_throughput / $awscli_throughput" | bc)

    # Calculate data size in GB
    local data_size_gb=$(echo "scale=2; $awscli_bytes / 1073741824" | bc)

    # Display results
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    PERFORMANCE COMPARISON                       ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║                                                                 ║"
    printf "║  Dataset Size:          %-35s  ║\n" "${data_size_gb} GB"
    printf "║  Files Uploaded:        %-35s  ║\n" "$awscli_files"
    echo "║                                                                 ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║                      AWS CLI (Optimized)                        ║"
    echo "╟─────────────────────────────────────────────────────────────────╢"
    printf "║  Duration:              %-35s  ║\n" "${awscli_duration}s"
    printf "║  Throughput:            %-35s  ║\n" "${awscli_throughput} MB/s"
    echo "║                                                                 ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║                           s5cmd                                 ║"
    echo "╟─────────────────────────────────────────────────────────────────╢"
    printf "║  Duration:              %-35s  ║\n" "${s5cmd_duration}s"
    printf "║  Throughput:            %-35s  ║\n" "${s5cmd_throughput} MB/s"
    echo "║                                                                 ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║                         IMPROVEMENT                             ║"
    echo "╟─────────────────────────────────────────────────────────────────╢"
    printf "║  Time Improvement:      %-35s  ║\n" "${time_improvement}x faster"
    printf "║  Throughput Improvement:%-35s  ║\n" "${throughput_improvement}x"
    echo "║                                                                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"

    echo

    # Save results to file
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local results_file="$SCRIPT_DIR/logs/comparison-${timestamp}.txt"
    local results_json="$SCRIPT_DIR/logs/comparison-${timestamp}.json"

    mkdir -p "$SCRIPT_DIR/logs"

    # Save text results
    {
        echo "DataSync Turbo Tools - Performance Comparison"
        echo "=============================================="
        echo
        echo "Timestamp: $(date -Iseconds)"
        echo "Dataset Size: ${data_size_gb} GB"
        echo "Files: $awscli_files"
        echo
        echo "AWS CLI (Optimized):"
        echo "  Duration: ${awscli_duration}s"
        echo "  Throughput: ${awscli_throughput} MB/s"
        echo
        echo "s5cmd:"
        echo "  Duration: ${s5cmd_duration}s"
        echo "  Throughput: ${s5cmd_throughput} MB/s"
        echo
        echo "Improvement:"
        echo "  Time: ${time_improvement}x faster"
        echo "  Throughput: ${throughput_improvement}x"
    } > "$results_file"

    # Save JSON results
    jq -n \
        --arg timestamp "$(date -Iseconds)" \
        --arg dataset_size_gb "$data_size_gb" \
        --arg files "$awscli_files" \
        --arg awscli_duration "$awscli_duration" \
        --arg awscli_throughput "$awscli_throughput" \
        --arg s5cmd_duration "$s5cmd_duration" \
        --arg s5cmd_throughput "$s5cmd_throughput" \
        --arg time_improvement "$time_improvement" \
        --arg throughput_improvement "$throughput_improvement" \
        '{
            timestamp: $timestamp,
            dataset: {
                size_gb: $dataset_size_gb,
                files: $files
            },
            awscli: {
                duration_seconds: $awscli_duration,
                throughput_mbps: $awscli_throughput
            },
            s5cmd: {
                duration_seconds: $s5cmd_duration,
                throughput_mbps: $s5cmd_throughput
            },
            improvement: {
                time_factor: $time_improvement,
                throughput_factor: $throughput_improvement
            }
        }' > "$results_json"

    log_success "Results saved:"
    log_info "  Text: $results_file"
    log_info "  JSON: $results_json"
}

# ============================================================================
# Main
# ============================================================================

TEST_SIZE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --test-size)
            TEST_SIZE="$2"
            shift 2
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

log_section "DataSync Turbo Tools - Performance Comparison"

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not installed"
    exit 1
fi

if ! command -v s5cmd &> /dev/null; then
    log_error "s5cmd not installed. Run: $PROJECT_ROOT/tools/install-s5cmd.sh"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_error "jq not installed. Install with: apt-get install jq (or brew install jq on macOS)"
    exit 1
fi

log_success "Prerequisites OK"

# Generate test data if requested
if [ -n "$TEST_SIZE" ]; then
    generate_test_data "$TEST_SIZE"

    # Update configs to use test data
    export SOURCE_DIR="$SCRIPT_DIR/test-data"
fi

# Run uploads
run_awscli_upload
run_s5cmd_upload

# Compare results
compare_results

# Cleanup
rm -f /tmp/awscli-duration /tmp/s5cmd-duration

log_success "Comparison complete!"
