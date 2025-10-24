#!/bin/bash
#
# benchmark.sh - Performance comparison tool for AWS CLI vs s5cmd
#
# Usage:
#   ./benchmark.sh [TEST_SIZE_MB]
#
# Examples:
#   ./benchmark.sh           # Default: 500 MB test
#   ./benchmark.sh 1000      # 1 GB test
#   ./benchmark.sh 5000      # 5 GB test
#
# Requirements:
#   - s5cmd installed
#   - AWS CLI installed
#   - AWS credentials configured
#   - S3 bucket configured (via S3_BUCKET env var)
#

set -euo pipefail

# Configuration
TEST_SIZE_MB="${1:-500}"
S3_BUCKET="${S3_BUCKET:-}"
S3_PREFIX="benchmark-test-$(date +%s)"
TEMP_DIR="/tmp/s3-benchmark-$$"
NUM_FILES=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
}

# Cleanup on exit
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        log_info "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi

    if [ -n "$S3_BUCKET" ]; then
        log_info "Cleaning up S3 test files..."
        if command -v s5cmd &> /dev/null; then
            s5cmd rm "s3://${S3_BUCKET}/${S3_PREFIX}/*" &> /dev/null || true
        else
            aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/" --recursive &> /dev/null || true
        fi
    fi
}
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"

    # Check s5cmd
    if ! command -v s5cmd &> /dev/null; then
        log_error "s5cmd not found in PATH"
        log_error "Install with: ./tools/install-s5cmd.sh"
        exit 1
    fi
    local s5cmd_version
    s5cmd_version=$(s5cmd version 2>&1 | head -n 1)
    log_success "s5cmd installed: $s5cmd_version"

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found in PATH"
        log_error "Install AWS CLI to run benchmarks"
        exit 1
    fi
    local aws_version
    aws_version=$(aws --version 2>&1 | head -n 1)
    log_success "AWS CLI installed: $aws_version"

    # Check S3 bucket
    if [ -z "$S3_BUCKET" ]; then
        log_error "S3_BUCKET environment variable not set"
        log_error "Set with: export S3_BUCKET=your-bucket-name"
        exit 1
    fi
    log_success "S3 bucket configured: s3://${S3_BUCKET}"

    # Test S3 access
    log_info "Testing S3 access..."
    if ! aws s3 ls "s3://${S3_BUCKET}" &> /dev/null; then
        log_error "Cannot access S3 bucket: s3://${S3_BUCKET}"
        log_error "Check bucket name, credentials, and permissions"
        exit 1
    fi
    log_success "S3 bucket accessible"

    echo ""
}

# Generate test data
generate_test_data() {
    log_header "Generating Test Data"

    mkdir -p "$TEMP_DIR"

    local file_size_mb=$((TEST_SIZE_MB / NUM_FILES))
    local file_size_bytes=$((file_size_mb * 1024 * 1024))

    log_info "Creating ${NUM_FILES} files of ${file_size_mb} MB each (${TEST_SIZE_MB} MB total)..."

    for i in $(seq 1 $NUM_FILES); do
        local filename="testfile-${i}.bin"
        log_info "  Generating ${filename}..."

        # Use /dev/urandom for test data
        dd if=/dev/urandom of="${TEMP_DIR}/${filename}" bs=1M count=$file_size_mb status=none 2>&1

        # Calculate checksum for verification
        if command -v sha256sum &> /dev/null; then
            sha256sum "${TEMP_DIR}/${filename}" | awk '{print $1}' > "${TEMP_DIR}/${filename}.sha256"
        fi
    done

    log_success "Generated ${NUM_FILES} test files (${TEST_SIZE_MB} MB total)"
    echo ""
}

# Run AWS CLI benchmark
benchmark_aws_cli() {
    local mode="$1"  # "default" or "optimized"

    log_header "Benchmarking AWS CLI (${mode})"

    # Configure AWS CLI based on mode
    if [ "$mode" = "default" ]; then
        unset AWS_MAX_CONCURRENT_REQUESTS
        unset AWS_MAX_QUEUE_SIZE
        log_info "Using default AWS CLI settings"
    else
        export AWS_MAX_CONCURRENT_REQUESTS=20
        export AWS_MAX_QUEUE_SIZE=10000
        log_info "Using optimized AWS CLI settings"
        log_info "  AWS_MAX_CONCURRENT_REQUESTS=20"
        log_info "  AWS_MAX_QUEUE_SIZE=10000"
    fi

    echo ""

    # Start timer
    local start_time
    start_time=$(date +%s.%N)

    # Run upload
    log_info "Uploading ${TEST_SIZE_MB} MB to s3://${S3_BUCKET}/${S3_PREFIX}-awscli-${mode}/ ..."
    if aws s3 sync "$TEMP_DIR" "s3://${S3_BUCKET}/${S3_PREFIX}-awscli-${mode}/" \
        --exclude "*.sha256" \
        --no-progress 2>&1 | grep -v "Completed"; then

        # End timer
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc)

        # Calculate throughput
        local throughput_mbs
        throughput_mbs=$(echo "scale=2; $TEST_SIZE_MB / $duration" | bc)

        log_success "Upload completed in ${duration} seconds"
        log_success "Throughput: ${throughput_mbs} MB/s"

        # Store results
        echo "$duration" > "${TEMP_DIR}/awscli-${mode}-time.txt"
        echo "$throughput_mbs" > "${TEMP_DIR}/awscli-${mode}-throughput.txt"
    else
        log_error "AWS CLI upload failed"
        echo "999999" > "${TEMP_DIR}/awscli-${mode}-time.txt"
        echo "0" > "${TEMP_DIR}/awscli-${mode}-throughput.txt"
    fi

    echo ""
}

# Run s5cmd benchmark
benchmark_s5cmd() {
    log_header "Benchmarking s5cmd"

    # Configure s5cmd
    local concurrency=64
    local num_workers=32

    log_info "Using s5cmd with high-performance settings"
    log_info "  Concurrency: $concurrency"
    log_info "  Workers: $num_workers"

    echo ""

    # Start timer
    local start_time
    start_time=$(date +%s.%N)

    # Run upload
    log_info "Uploading ${TEST_SIZE_MB} MB to s3://${S3_BUCKET}/${S3_PREFIX}-s5cmd/ ..."

    # Build s5cmd command with correct flag order
    # Global flags MUST come before 'sync' command
    # Sync flags MUST come after 'sync' command
    local s5cmd_profile_flag=""
    if [ -n "${AWS_PROFILE:-}" ]; then
        s5cmd_profile_flag="--profile $AWS_PROFILE"
    fi

    # Run s5cmd (capture output but don't fail on grep)
    local s5cmd_output
    s5cmd_output=$(s5cmd \
        --numworkers "$num_workers" \
        $s5cmd_profile_flag \
        sync \
        --concurrency "$concurrency" \
        --exclude "*.sha256" \
        "$TEMP_DIR/" \
        "s3://${S3_BUCKET}/${S3_PREFIX}-s5cmd/" \
        2>&1 || echo "FAILED")

    if [[ "$s5cmd_output" != *"FAILED"* ]]; then

        # End timer
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc)

        # Calculate throughput
        local throughput_mbs
        throughput_mbs=$(echo "scale=2; $TEST_SIZE_MB / $duration" | bc)

        log_success "Upload completed in ${duration} seconds"
        log_success "Throughput: ${throughput_mbs} MB/s"

        # Store results
        echo "$duration" > "${TEMP_DIR}/s5cmd-time.txt"
        echo "$throughput_mbs" > "${TEMP_DIR}/s5cmd-throughput.txt"
    else
        log_error "s5cmd upload failed"
        log_error "Error output: $s5cmd_output"
        echo "999999" > "${TEMP_DIR}/s5cmd-time.txt"
        echo "0" > "${TEMP_DIR}/s5cmd-throughput.txt"
    fi

    echo ""
}

# Display comparison results
display_results() {
    log_header "Benchmark Results"

    # Read results
    local awscli_default_time awscli_default_throughput
    local awscli_opt_time awscli_opt_throughput
    local s5cmd_time s5cmd_throughput

    awscli_default_time=$(cat "${TEMP_DIR}/awscli-default-time.txt" 2>/dev/null || echo "N/A")
    awscli_default_throughput=$(cat "${TEMP_DIR}/awscli-default-throughput.txt" 2>/dev/null || echo "N/A")

    awscli_opt_time=$(cat "${TEMP_DIR}/awscli-optimized-time.txt" 2>/dev/null || echo "N/A")
    awscli_opt_throughput=$(cat "${TEMP_DIR}/awscli-optimized-throughput.txt" 2>/dev/null || echo "N/A")

    s5cmd_time=$(cat "${TEMP_DIR}/s5cmd-time.txt" 2>/dev/null || echo "N/A")
    s5cmd_throughput=$(cat "${TEMP_DIR}/s5cmd-throughput.txt" 2>/dev/null || echo "N/A")

    # Calculate improvements
    local improvement_default improvement_opt
    if [ "$awscli_default_time" != "N/A" ] && [ "$s5cmd_time" != "N/A" ]; then
        improvement_default=$(echo "scale=1; $awscli_default_time / $s5cmd_time" | bc)
    else
        improvement_default="N/A"
    fi

    if [ "$awscli_opt_time" != "N/A" ] && [ "$s5cmd_time" != "N/A" ]; then
        improvement_opt=$(echo "scale=1; $awscli_opt_time / $s5cmd_time" | bc)
    else
        improvement_opt="N/A"
    fi

    # Display table
    echo "Test Configuration:"
    echo "  Dataset size:    ${TEST_SIZE_MB} MB"
    echo "  Number of files: ${NUM_FILES}"
    echo "  S3 bucket:       s3://${S3_BUCKET}"
    echo ""
    echo "┌─────────────────────────┬──────────────┬────────────────┬─────────────┐"
    echo "│ Tool                    │ Time (s)     │ Throughput     │ Improvement │"
    echo "├─────────────────────────┼──────────────┼────────────────┼─────────────┤"
    printf "│ %-23s │ %12s │ %11s MB/s │ %-11s │\n" \
        "AWS CLI (default)" "$awscli_default_time" "$awscli_default_throughput" "Baseline"
    printf "│ %-23s │ %12s │ %11s MB/s │ %-11s │\n" \
        "AWS CLI (optimized)" "$awscli_opt_time" "$awscli_opt_throughput" "${improvement_default}x"
    printf "│ %-23s │ %12s │ %11s MB/s │ %-11s │\n" \
        "s5cmd" "$s5cmd_time" "$s5cmd_throughput" "${improvement_opt}x"
    echo "└─────────────────────────┴──────────────┴────────────────┴─────────────┘"

    echo ""

    # Winner announcement
    if [ "$s5cmd_throughput" != "N/A" ] && [ "$awscli_opt_throughput" != "N/A" ]; then
        local is_faster
        is_faster=$(echo "$s5cmd_throughput > $awscli_opt_throughput" | bc)

        if [ "$is_faster" -eq 1 ]; then
            echo -e "${GREEN}🏆 Winner: s5cmd is ${improvement_opt}x faster than optimized AWS CLI${NC}"
        else
            echo -e "${YELLOW}⚠️  AWS CLI performed better in this test${NC}"
            echo -e "${YELLOW}   This may indicate network/system constraints${NC}"
        fi
    fi

    echo ""
}

# Save results to file
save_results() {
    local results_file="benchmark-results-$(date +%Y%m%d-%H%M%S).txt"

    log_info "Saving results to: $results_file"

    {
        echo "s5cmd vs AWS CLI Benchmark Results"
        echo "===================================="
        echo ""
        echo "Timestamp: $(date)"
        echo "Test size: ${TEST_SIZE_MB} MB"
        echo "Files: ${NUM_FILES}"
        echo "S3 bucket: s3://${S3_BUCKET}"
        echo ""
        echo "Results:"
        echo "--------"
        cat "${TEMP_DIR}/awscli-default-time.txt" 2>/dev/null && \
            echo "AWS CLI (default) time:       $(cat "${TEMP_DIR}/awscli-default-time.txt") seconds"
        cat "${TEMP_DIR}/awscli-default-throughput.txt" 2>/dev/null && \
            echo "AWS CLI (default) throughput: $(cat "${TEMP_DIR}/awscli-default-throughput.txt") MB/s"
        echo ""
        cat "${TEMP_DIR}/awscli-optimized-time.txt" 2>/dev/null && \
            echo "AWS CLI (optimized) time:     $(cat "${TEMP_DIR}/awscli-optimized-time.txt") seconds"
        cat "${TEMP_DIR}/awscli-optimized-throughput.txt" 2>/dev/null && \
            echo "AWS CLI (optimized) throughput: $(cat "${TEMP_DIR}/awscli-optimized-throughput.txt") MB/s"
        echo ""
        cat "${TEMP_DIR}/s5cmd-time.txt" 2>/dev/null && \
            echo "s5cmd time:                   $(cat "${TEMP_DIR}/s5cmd-time.txt") seconds"
        cat "${TEMP_DIR}/s5cmd-throughput.txt" 2>/dev/null && \
            echo "s5cmd throughput:             $(cat "${TEMP_DIR}/s5cmd-throughput.txt") MB/s"
    } > "$results_file"

    log_success "Results saved to: $results_file"
    echo ""
}

# Main benchmark flow
main() {
    log_header "S3 Upload Performance Benchmark"
    echo "Comparing AWS CLI vs s5cmd upload performance"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Generate test data
    generate_test_data

    # Run benchmarks
    benchmark_aws_cli "default"
    benchmark_aws_cli "optimized"
    benchmark_s5cmd

    # Display results
    display_results

    # Save results
    save_results

    log_success "Benchmark complete!"
    echo ""
}

# Run main benchmark
main "$@"
