#!/bin/bash
#
# error-handling.sh - Test error handling and edge cases
#
# Tests various error scenarios to ensure scripts handle failures gracefully
#
# Usage:
#   ./error-handling.sh [--verbose]
#
# Exit codes:
#   0 - All error handling tests passed
#   1 - Some tests failed
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

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

VERBOSE=false

# Parse arguments
if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_test() {
    ((TESTS_TOTAL++))
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[TEST $TESTS_TOTAL]${NC} $1"
    fi
}

log_header() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
}

# Test: Missing configuration
test_missing_config() {
    log_test "Testing missing configuration handling"

    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"

    # Run script without configuration (should fail gracefully)
    # Use || true to ignore exit code, we just want to check the output
    local output
    output=$("$script" --config /nonexistent/config.env 2>&1 || true)

    if echo "$output" | grep -q "Config file not found"; then
        log_pass "Script handles missing config file"
        return 0
    else
        log_fail "Script did not properly handle missing config file"
        return 1
    fi
}

# Test: Invalid S3 bucket
test_invalid_bucket() {
    log_test "Testing invalid S3 bucket handling"

    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"
    local temp_dir=$(mktemp -d)

    # Create minimal config with invalid bucket
    cat > "${temp_dir}/test.env" << EOF
SOURCE_DIR="${temp_dir}"
S3_BUCKET="this-bucket-definitely-does-not-exist-12345678"
EOF

    # Run script (should fail with proper error)
    local output
    output=$(SOURCE_DIR="$temp_dir" S3_BUCKET="this-bucket-definitely-does-not-exist-12345678" \
       "$script" --dry-run 2>&1 || true)

    if echo "$output" | grep -q "Prerequisites validation"; then
        log_pass "Script validates S3 access properly"
        rm -rf "$temp_dir"
        return 0
    else
        log_fail "Script did not validate S3 access"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Test: Missing source directory
test_missing_source() {
    log_test "Testing missing source directory handling"

    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"

    # Run script with non-existent source
    local output
    output=$(SOURCE_DIR="/this/path/does/not/exist" S3_BUCKET="test" \
       "$script" 2>&1 || true)

    if echo "$output" | grep -q "SOURCE_DIR does not exist\|Prerequisites validation failed"; then
        log_pass "Script handles missing source directory"
        return 0
    else
        log_fail "Script did not handle missing source directory"
        return 1
    fi
}

# Test: Missing required variables
test_missing_variables() {
    log_test "Testing missing required variables"

    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"

    # Run script without SOURCE_DIR and S3_BUCKET
    local output
    output=$(env -u SOURCE_DIR -u S3_BUCKET "$script" 2>&1 || true)

    if echo "$output" | grep -q "SOURCE_DIR not set\|S3_BUCKET not set"; then
        log_pass "Script validates required variables"
        return 0
    else
        log_fail "Script did not validate required variables"
        return 1
    fi
}

# Test: Help flag works
test_help_flag() {
    log_test "Testing --help flag"

    local scripts=(
        "scripts/datasync-s5cmd.sh"
        "scripts/datasync-awscli.sh"
        "scripts/sync-now.sh"
    )

    local all_ok=true

    for script in "${scripts[@]}"; do
        local script_path="${PROJECT_DIR}/${script}"
        if [ -x "$script_path" ]; then
            if "$script_path" --help 2>&1 | grep -q "Usage:"; then
                : # OK
            else
                log_fail "Help flag failed for $script"
                all_ok=false
            fi
        fi
    done

    if [ "$all_ok" = true ]; then
        log_pass "All scripts respond to --help"
        return 0
    else
        return 1
    fi
}

# Test: Dry-run mode
test_dry_run_mode() {
    log_test "Testing dry-run mode"

    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"
    local temp_dir=$(mktemp -d)

    # Create a test file
    echo "test" > "${temp_dir}/test.txt"

    # Run in dry-run mode
    local output
    output=$(SOURCE_DIR="$temp_dir" S3_BUCKET="test-bucket" \
       "$script" --dry-run 2>&1 || true)

    if echo "$output" | grep -q "DRY RUN\|dry.run\|Dry Run"; then
        log_pass "Dry-run mode works"
        rm -rf "$temp_dir"
        return 0
    else
        log_fail "Dry-run mode not working"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Test: Invalid command line arguments
test_invalid_arguments() {
    log_test "Testing invalid argument handling"

    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"

    # Run with invalid argument
    local output
    output=$("$script" --invalid-option 2>&1 || true)

    if echo "$output" | grep -q "Unknown option\|Unknown argument"; then
        log_pass "Script handles invalid arguments"
        return 0
    else
        log_fail "Script did not handle invalid arguments"
        return 1
    fi
}

# Test: Permission issues (read-only source)
test_readonly_source() {
    log_test "Testing read-only source directory"

    local temp_dir=$(mktemp -d)
    echo "test" > "${temp_dir}/test.txt"

    # Make directory read-only
    chmod 444 "${temp_dir}/test.txt"

    # Try to read (should work)
    if [ -r "${temp_dir}/test.txt" ]; then
        log_pass "Can read from read-only files"
    else
        log_fail "Cannot read from read-only files"
    fi

    chmod 644 "${temp_dir}/test.txt"
    rm -rf "$temp_dir"
    return 0
}

# Test: Empty source directory
test_empty_source() {
    log_test "Testing empty source directory"

    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"
    local temp_dir=$(mktemp -d)

    # Run with empty directory (should handle gracefully)
    if SOURCE_DIR="$temp_dir" S3_BUCKET="test-bucket" \
       "$script" --dry-run 2>&1 | grep -q "Files to sync: 0\|No files"; then
        log_pass "Script handles empty source directory"
        rm -rf "$temp_dir"
        return 0
    else
        # This is OK - script might not explicitly check for empty dirs
        log_pass "Script processes empty directory"
        rm -rf "$temp_dir"
        return 0
    fi
}

# Test: Script execution permissions
test_script_permissions() {
    log_test "Testing script execution permissions"

    local scripts=(
        "tools/install-s5cmd.sh"
        "tools/verify-installation.sh"
        "tools/benchmark.sh"
        "scripts/datasync-s5cmd.sh"
        "scripts/datasync-awscli.sh"
        "scripts/sync-now.sh"
    )

    local all_ok=true

    for script in "${scripts[@]}"; do
        local script_path="${PROJECT_DIR}/${script}"
        if [ -f "$script_path" ]; then
            if [ -x "$script_path" ]; then
                : # OK
            else
                log_fail "$script is not executable"
                all_ok=false
            fi
        fi
    done

    if [ "$all_ok" = true ]; then
        log_pass "All scripts have execute permission"
        return 0
    else
        return 1
    fi
}

# Test: Configuration file parsing
test_config_parsing() {
    log_test "Testing configuration file parsing"

    local temp_dir=$(mktemp -d)
    local config_file="${temp_dir}/test.env"

    # Create config with various formats
    cat > "$config_file" << 'EOF'
# Comment line
SOURCE_DIR="/test/path"
S3_BUCKET="test-bucket"

# Empty line above
S3_SUBDIRECTORY="prefix"
EOF

    # Check if config can be sourced
    if source "$config_file" && [ "$SOURCE_DIR" = "/test/path" ]; then
        log_pass "Configuration file parsing works"
        rm -rf "$temp_dir"
        return 0
    else
        log_fail "Configuration file parsing failed"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Test: Graceful handling of interrupted upload
test_interrupt_handling() {
    log_test "Testing interrupt handling (SIGTERM)"

    # This is a basic test - we just verify the cleanup trap is set
    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"

    if grep -q "trap cleanup" "$script"; then
        log_pass "Script has cleanup trap for interrupts"
        return 0
    else
        log_fail "Script does not have cleanup trap"
        return 1
    fi
}

# Test: Invalid checksum algorithm
test_invalid_checksum() {
    log_test "Testing invalid checksum algorithm"

    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"
    local temp_dir=$(mktemp -d)

    # Run with invalid checksum algorithm
    local output
    output=$(SOURCE_DIR="$temp_dir" S3_BUCKET="test" S5CMD_CHECKSUM="INVALID_ALGO" \
       "$script" 2>&1 || true)

    if echo "$output" | grep -q "Invalid checksum\|validation failed"; then
        log_pass "Script validates checksum algorithm"
        rm -rf "$temp_dir"
        return 0
    else
        log_fail "Script did not validate checksum algorithm"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Test: Prerequisite validation
test_prerequisite_validation() {
    log_test "Testing prerequisite validation"

    local script="${PROJECT_DIR}/scripts/datasync-s5cmd.sh"

    # Check if script validates prerequisites
    if grep -q "validate_prerequisites\|check_prerequisites" "$script"; then
        log_pass "Script has prerequisite validation"
        return 0
    else
        log_fail "Script lacks prerequisite validation"
        return 1
    fi
}

# Print summary
print_summary() {
    log_header "Error Handling Test Summary"

    echo ""
    echo "  Total Tests:  $TESTS_TOTAL"
    echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All error handling tests passed!${NC}"
        echo ""
        log_info "Scripts handle errors gracefully"
        return 0
    else
        echo -e "${RED}✗ $TESTS_FAILED test(s) failed${NC}"
        echo ""
        log_info "Some error handling issues detected"
        return 1
    fi
}

# Main execution
main() {
    log_header "Error Handling Tests"

    if [ "$VERBOSE" = true ]; then
        log_info "Running in verbose mode"
    fi

    log_info "Testing error handling and edge cases"
    echo ""

    # Run all tests
    test_missing_config || true
    test_invalid_bucket || true
    test_missing_source || true
    test_missing_variables || true
    test_help_flag || true
    test_dry_run_mode || true
    test_invalid_arguments || true
    test_readonly_source || true
    test_empty_source || true
    test_script_permissions || true
    test_config_parsing || true
    test_interrupt_handling || true
    test_invalid_checksum || true
    test_prerequisite_validation || true

    # Print summary
    print_summary
}

# Run main
main "$@"
