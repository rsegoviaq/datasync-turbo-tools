#!/bin/bash
#
# checksum-validation.sh - Verify uploaded files have correct checksums
#
# Creates test files, uploads them with s5cmd, and verifies data integrity
#
# Usage:
#   ./checksum-validation.sh [OPTIONS]
#
# Options:
#   --bucket BUCKET    S3 bucket to use for testing (required)
#   --cleanup          Clean up test files after completion
#   --help             Show this help message
#
# Exit codes:
#   0 - All checksums validated
#   1 - Checksum validation failed
#   2 - Prerequisites missing
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
S3_BUCKET="${S3_BUCKET:-}"
S3_PREFIX="checksum-test-$(date +%s)"
TEMP_DIR=""
CLEANUP=false
NUM_TEST_FILES=5
FILE_SIZE_MB=10

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((TESTS_PASSED++)) || true
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++)) || true
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
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        if [ "$CLEANUP" = true ]; then
            log_info "Cleaning up temporary files..."
            rm -rf "$TEMP_DIR"
        else
            log_info "Test files preserved at: $TEMP_DIR"
        fi
    fi

    if [ -n "$S3_BUCKET" ] && [ "$CLEANUP" = true ]; then
        log_info "Cleaning up S3 test files..."
        if command -v s5cmd &> /dev/null; then
            s5cmd rm "s3://${S3_BUCKET}/${S3_PREFIX}/*" &> /dev/null || true
        fi
    fi
}
trap cleanup EXIT

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Verify uploaded files have correct checksums

Options:
    --bucket BUCKET    S3 bucket to use for testing (required)
    --cleanup          Clean up test files and S3 objects after completion
    --help             Show this help message

Environment Variables:
    S3_BUCKET          S3 bucket name (alternative to --bucket)

Examples:
    # Run checksum validation
    $0 --bucket my-test-bucket

    # Run with cleanup
    $0 --bucket my-test-bucket --cleanup

    # Using environment variable
    S3_BUCKET=my-test-bucket $0 --cleanup

EOF
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            --cleanup)
                CLEANUP=true
                shift
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
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"

    local errors=0

    # Check s5cmd
    if ! command -v s5cmd &> /dev/null; then
        log_fail "s5cmd not found in PATH"
        log_info "   Install with: ./tools/install-s5cmd.sh"
        ((errors++)) || true
    else
        local version
        version=$(s5cmd version 2>&1 | head -n 1)
        log_success "s5cmd installed: $version"
    fi

    # Check bucket
    if [ -z "$S3_BUCKET" ]; then
        log_fail "S3 bucket not specified"
        log_info "   Use --bucket option or S3_BUCKET environment variable"
        ((errors++)) || true
    else
        log_success "S3 bucket: s3://$S3_BUCKET"
    fi

    # Check S3 access
    if [ -n "$S3_BUCKET" ] && command -v s5cmd &> /dev/null; then
        log_info "Testing S3 access..."
        if s5cmd ls "s3://${S3_BUCKET}/" &> /dev/null; then
            log_success "S3 bucket accessible"
        else
            log_fail "Cannot access S3 bucket: s3://${S3_BUCKET}/"
            ((errors++)) || true
        fi
    fi

    # Check sha256sum or shasum
    if command -v sha256sum &> /dev/null; then
        log_success "sha256sum available"
    elif command -v shasum &> /dev/null; then
        log_success "shasum available"
    else
        log_fail "No SHA256 tool found (sha256sum or shasum)"
        ((errors++)) || true
    fi

    if [ $errors -gt 0 ]; then
        echo ""
        log_fail "Prerequisites check failed with $errors error(s)"
        exit 2
    fi

    log_success "All prerequisites met"
    echo ""
}

# Generate test files
generate_test_files() {
    log_header "Generating Test Files"

    TEMP_DIR=$(mktemp -d)
    log_info "Test directory: $TEMP_DIR"
    echo ""

    for i in $(seq 1 $NUM_TEST_FILES); do
        local filename="testfile-${i}.bin"
        log_info "Generating ${filename} (${FILE_SIZE_MB} MB)..."

        # Generate random data
        dd if=/dev/urandom of="${TEMP_DIR}/${filename}" bs=1M count=$FILE_SIZE_MB status=none 2>&1

        # Calculate SHA256 checksum
        if command -v sha256sum &> /dev/null; then
            sha256sum "${TEMP_DIR}/${filename}" | awk '{print $1}' > "${TEMP_DIR}/${filename}.sha256"
        else
            shasum -a 256 "${TEMP_DIR}/${filename}" | awk '{print $1}' > "${TEMP_DIR}/${filename}.sha256"
        fi

        local checksum
        checksum=$(cat "${TEMP_DIR}/${filename}.sha256")
        log_info "  SHA256: $checksum"
    done

    echo ""
    log_success "Generated $NUM_TEST_FILES test files ($((NUM_TEST_FILES * FILE_SIZE_MB)) MB total)"
    echo ""
}

# Upload files with s5cmd
upload_with_s5cmd() {
    log_header "Uploading Files with s5cmd"

    local destination="s3://${S3_BUCKET}/${S3_PREFIX}/"

    log_info "Uploading to: $destination"
    log_info "Using CRC64NVME checksums (s5cmd default)"
    echo ""

    # Upload with s5cmd
    if s5cmd \
        --numworkers 8 \
        sync \
        "${TEMP_DIR}/" \
        "$destination" \
        --exclude "*.sha256" 2>&1; then

        log_success "Upload completed"
    else
        log_fail "Upload failed"
        return 1
    fi

    echo ""
}

# Verify checksums by downloading
verify_checksums_download() {
    log_header "Verifying Checksums (Download Method)"

    local download_dir="${TEMP_DIR}/downloaded"
    mkdir -p "$download_dir"

    log_info "Downloading files from S3..."

    # Download files
    if s5cmd cp "s3://${S3_BUCKET}/${S3_PREFIX}/*" "$download_dir/" 2>&1; then
        log_success "Download completed"
    else
        log_fail "Download failed"
        return 1
    fi

    echo ""
    log_info "Comparing checksums..."
    echo ""

    local all_match=true

    for i in $(seq 1 $NUM_TEST_FILES); do
        local filename="testfile-${i}.bin"
        local original="${TEMP_DIR}/${filename}"
        local downloaded="${download_dir}/${filename}"

        if [ ! -f "$downloaded" ]; then
            log_fail "$filename: Downloaded file not found"
            all_match=false
            continue
        fi

        # Calculate checksums
        local original_checksum downloaded_checksum

        if command -v sha256sum &> /dev/null; then
            original_checksum=$(sha256sum "$original" | awk '{print $1}')
            downloaded_checksum=$(sha256sum "$downloaded" | awk '{print $1}')
        else
            original_checksum=$(shasum -a 256 "$original" | awk '{print $1}')
            downloaded_checksum=$(shasum -a 256 "$downloaded" | awk '{print $1}')
        fi

        if [ "$original_checksum" = "$downloaded_checksum" ]; then
            log_success "$filename: Checksums match ($original_checksum)"
        else
            log_fail "$filename: Checksum mismatch!"
            log_fail "  Original:   $original_checksum"
            log_fail "  Downloaded: $downloaded_checksum"
            all_match=false
        fi
    done

    echo ""

    if [ "$all_match" = true ]; then
        log_success "All checksums verified successfully"
        return 0
    else
        log_fail "Some checksums did not match"
        return 1
    fi
}

# Verify file sizes
verify_file_sizes() {
    log_header "Verifying File Sizes"

    log_info "Checking S3 object sizes..."
    echo ""

    local all_match=true

    for i in $(seq 1 $NUM_TEST_FILES); do
        local filename="testfile-${i}.bin"
        local local_file="${TEMP_DIR}/${filename}"
        local s3_key="${S3_PREFIX}/${filename}"

        # Get local file size
        local local_size
        local_size=$(stat -f%z "$local_file" 2>/dev/null || stat -c%s "$local_file" 2>/dev/null)

        # Get S3 object size using s5cmd
        local s3_size
        s3_size=$(s5cmd ls "s3://${S3_BUCKET}/${s3_key}" 2>/dev/null | awk '{print $3}' || echo "0")

        if [ "$local_size" = "$s3_size" ]; then
            log_success "$filename: Size matches ($local_size bytes)"
        else
            log_fail "$filename: Size mismatch!"
            log_fail "  Local: $local_size bytes"
            log_fail "  S3:    $s3_size bytes"
            all_match=false
        fi
    done

    echo ""

    if [ "$all_match" = true ]; then
        log_success "All file sizes match"
        return 0
    else
        log_fail "Some file sizes did not match"
        return 1
    fi
}

# Test ETag consistency
test_etag_consistency() {
    log_header "Testing ETag Consistency"

    log_info "Checking S3 ETags..."
    echo ""

    for i in $(seq 1 $NUM_TEST_FILES); do
        local filename="testfile-${i}.bin"
        local s3_key="${S3_PREFIX}/${filename}"

        # Get ETag (requires AWS CLI)
        if command -v aws &> /dev/null; then
            local etag
            etag=$(aws s3api head-object \
                --bucket "$S3_BUCKET" \
                --key "$s3_key" \
                --query 'ETag' \
                --output text 2>/dev/null | tr -d '"' || echo "")

            if [ -n "$etag" ]; then
                log_success "$filename: ETag present ($etag)"
            else
                log_info "$filename: Could not retrieve ETag"
            fi
        else
            log_info "AWS CLI not available - skipping ETag test"
            break
        fi
    done

    echo ""
}

# Print summary
print_summary() {
    log_header "Checksum Validation Summary"

    echo ""
    echo "  Test files:   $NUM_TEST_FILES"
    echo "  File size:    ${FILE_SIZE_MB} MB each"
    echo "  Total data:   $((NUM_TEST_FILES * FILE_SIZE_MB)) MB"
    echo "  S3 prefix:    s3://${S3_BUCKET}/${S3_PREFIX}/"
    echo ""
    echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All checksum validations passed!${NC}"
        echo ""
        log_info "Data integrity verified successfully"
        return 0
    else
        echo -e "${RED}✗ $TESTS_FAILED validation(s) failed${NC}"
        echo ""
        log_info "Data integrity issues detected"
        return 1
    fi
}

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"

    echo ""
    log_header "S3 Checksum Validation Test"
    log_info "Testing data integrity of s5cmd uploads"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Generate test files
    generate_test_files

    # Upload files
    upload_with_s5cmd

    # Verify checksums
    verify_checksums_download

    # Verify file sizes
    verify_file_sizes

    # Test ETags (optional)
    test_etag_consistency

    # Print summary
    print_summary
}

# Run main
main "$@"
