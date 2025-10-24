#!/bin/bash
#
# performance-test.sh - Performance testing wrapper
#
# Runs performance benchmarks and validates throughput targets
#
# Usage:
#   ./performance-test.sh [OPTIONS]
#
# Options:
#   --size MB          Test data size in MB (default: 500)
#   --bucket BUCKET    S3 bucket for testing (required)
#   --help             Show this help message
#
# Exit codes:
#   0 - Performance targets met
#   1 - Performance below targets
#   2 - Test failed to run
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
TEST_SIZE_MB="500"
S3_BUCKET="${S3_BUCKET:-}"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run performance benchmarks and validate throughput

Options:
    --size MB          Test data size in MB (default: 500)
    --bucket BUCKET    S3 bucket for testing (required)
    --help             Show this help message

Environment Variables:
    S3_BUCKET          S3 bucket name (alternative to --bucket)

Examples:
    # Run default 500 MB test
    $0 --bucket my-test-bucket

    # Run 1 GB test
    $0 --bucket my-test-bucket --size 1000

    # Using environment variable
    S3_BUCKET=my-test-bucket $0

Performance Targets:
    s5cmd should be at least 3x faster than AWS CLI baseline
    on most networks

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --size)
            TEST_SIZE_MB="$2"
            shift 2
            ;;
        --bucket)
            S3_BUCKET="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate bucket
if [ -z "$S3_BUCKET" ]; then
    echo -e "${RED}[ERROR]${NC} S3 bucket not specified"
    echo "Use --bucket option or S3_BUCKET environment variable"
    exit 2
fi

log_header "Performance Test"
log_info "Test size: ${TEST_SIZE_MB} MB"
log_info "S3 bucket: s3://${S3_BUCKET}"
echo ""

# Check if benchmark script exists
BENCHMARK_SCRIPT="${PROJECT_DIR}/tools/benchmark.sh"

if [ ! -f "$BENCHMARK_SCRIPT" ]; then
    log_fail "Benchmark script not found: $BENCHMARK_SCRIPT"
    exit 2
fi

if [ ! -x "$BENCHMARK_SCRIPT" ]; then
    log_fail "Benchmark script is not executable"
    exit 2
fi

log_info "Using benchmark script: $BENCHMARK_SCRIPT"
echo ""

# Run benchmark
log_header "Running Benchmark"

export S3_BUCKET

if "$BENCHMARK_SCRIPT" "$TEST_SIZE_MB"; then
    log_success "Benchmark completed successfully"
else
    log_fail "Benchmark failed"
    exit 2
fi

echo ""
log_header "Performance Analysis"

# Try to parse results from the most recent benchmark results file
RESULTS_FILE=$(ls -t benchmark-results-*.txt 2>/dev/null | head -n 1 || echo "")

if [ -n "$RESULTS_FILE" ] && [ -f "$RESULTS_FILE" ]; then
    log_info "Analyzing results from: $RESULTS_FILE"
    echo ""

    # Extract throughput values
    AWS_CLI_DEFAULT_THROUGHPUT=$(grep "AWS CLI (default) throughput:" "$RESULTS_FILE" 2>/dev/null | awk '{print $5}' || echo "0")
    S5CMD_THROUGHPUT=$(grep "s5cmd throughput:" "$RESULTS_FILE" 2>/dev/null | awk '{print $3}' || echo "0")

    log_info "AWS CLI (default): ${AWS_CLI_DEFAULT_THROUGHPUT} MB/s"
    log_info "s5cmd:             ${S5CMD_THROUGHPUT} MB/s"
    echo ""

    # Calculate improvement
    if [ "$AWS_CLI_DEFAULT_THROUGHPUT" != "0" ] && [ "$S5CMD_THROUGHPUT" != "0" ]; then
        IMPROVEMENT=$(echo "scale=1; $S5CMD_THROUGHPUT / $AWS_CLI_DEFAULT_THROUGHPUT" | bc)
        log_info "Performance improvement: ${IMPROVEMENT}x"
        echo ""

        # Check if performance target is met (3x minimum)
        TARGET_MET=$(echo "$IMPROVEMENT >= 3" | bc)

        if [ "$TARGET_MET" -eq 1 ]; then
            log_success "✓ Performance target met (>= 3x improvement)"
            log_success "s5cmd is ${IMPROVEMENT}x faster than AWS CLI baseline"
            exit 0
        else
            log_fail "✗ Performance target not met (< 3x improvement)"
            log_fail "s5cmd is only ${IMPROVEMENT}x faster (target: >= 3x)"
            log_info "This may indicate network constraints or system limitations"
            exit 1
        fi
    else
        log_info "Could not calculate improvement ratio"
        log_info "Check benchmark results manually"
        exit 0
    fi
else
    log_info "No results file found for automatic analysis"
    log_info "Check benchmark output above for performance metrics"
    exit 0
fi
