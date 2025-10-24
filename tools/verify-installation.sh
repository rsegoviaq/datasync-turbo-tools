#!/bin/bash
#
# verify-installation.sh - Comprehensive s5cmd installation verification
#
# Usage:
#   ./verify-installation.sh [--strict]
#
# Exit codes:
#   0 - All tests passed
#   1 - s5cmd installation issues
#   2 - AWS credential issues
#   3 - S3 access issues
#   4 - Script/configuration issues
#

set -euo pipefail

# Configuration
STRICT_MODE="${1:-}"
TEST_BUCKET="${S3_BUCKET:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0
TESTS_TOTAL=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[✗]${NC} $1"
    ((TESTS_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    ((TESTS_WARNED++))
}

# Test: s5cmd binary exists in PATH
test_s5cmd_in_path() {
    ((TESTS_TOTAL++))
    log_info "Test 1: Checking if s5cmd is in PATH..."

    if command -v s5cmd &> /dev/null; then
        local s5cmd_path
        s5cmd_path=$(command -v s5cmd)
        log_success "s5cmd found in PATH: $s5cmd_path"
        return 0
    else
        log_fail "s5cmd not found in PATH"
        log_info "   Add s5cmd to your PATH or install it with: ./tools/install-s5cmd.sh"
        return 1
    fi
}

# Test: s5cmd version
test_s5cmd_version() {
    ((TESTS_TOTAL++))
    log_info "Test 2: Checking s5cmd version..."

    if ! command -v s5cmd &> /dev/null; then
        log_fail "s5cmd not found - cannot check version"
        return 1
    fi

    local version
    version=$(s5cmd version 2>&1 | head -n 1 || echo "unknown")

    if [ "$version" = "unknown" ]; then
        log_fail "Could not determine s5cmd version"
        return 1
    fi

    # Extract version number (format: "s5cmd version v2.2.2")
    local version_num
    version_num=$(echo "$version" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "")

    if [ -z "$version_num" ]; then
        log_fail "Could not parse version from: $version"
        return 1
    fi

    # Check if version >= 2.0.0
    local major
    major=$(echo "$version_num" | sed 's/v//' | cut -d. -f1)

    if [ "$major" -ge 2 ]; then
        log_success "s5cmd version $version_num (>= v2.0.0)"
        return 0
    else
        log_fail "s5cmd version $version_num is too old (need >= v2.0.0)"
        log_info "   Update with: ./tools/install-s5cmd.sh"
        return 1
    fi
}

# Test: s5cmd execution
test_s5cmd_execution() {
    ((TESTS_TOTAL++))
    log_info "Test 3: Testing s5cmd execution..."

    if ! command -v s5cmd &> /dev/null; then
        log_fail "s5cmd not found - cannot test execution"
        return 1
    fi

    # Test with --help flag
    if s5cmd --help &> /dev/null; then
        log_success "s5cmd executes successfully"
        return 0
    else
        log_fail "s5cmd execution failed"
        return 1
    fi
}

# Test: AWS CLI installed
test_aws_cli() {
    ((TESTS_TOTAL++))
    log_info "Test 4: Checking AWS CLI installation..."

    if command -v aws &> /dev/null; then
        local aws_version
        aws_version=$(aws --version 2>&1 | head -n 1)
        log_success "AWS CLI installed: $aws_version"
        return 0
    else
        if [ "$STRICT_MODE" = "--strict" ]; then
            log_fail "AWS CLI not installed"
            return 1
        else
            log_warn "AWS CLI not installed (optional but recommended)"
            log_info "   Install with: sudo apt install awscli  or  brew install awscli"
            return 0
        fi
    fi
}

# Test: AWS credentials configured
test_aws_credentials() {
    ((TESTS_TOTAL++))
    log_info "Test 5: Checking AWS credentials..."

    # Check for credentials in environment variables
    if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        log_success "AWS credentials found in environment variables"
        return 0
    fi

    # Check for AWS profile
    if [ -n "${AWS_PROFILE:-}" ]; then
        log_success "AWS profile set: $AWS_PROFILE"
        return 0
    fi

    # Check for credentials file
    if [ -f ~/.aws/credentials ]; then
        log_success "AWS credentials file exists: ~/.aws/credentials"
        return 0
    fi

    # Check for config file (may have credentials)
    if [ -f ~/.aws/config ]; then
        log_success "AWS config file exists: ~/.aws/config"
        return 0
    fi

    if [ "$STRICT_MODE" = "--strict" ]; then
        log_fail "No AWS credentials found"
        log_info "   Configure with: aws configure"
        return 1
    else
        log_warn "No AWS credentials found"
        log_info "   Configure with: aws configure"
        return 0
    fi
}

# Test: AWS profile valid
test_aws_profile() {
    ((TESTS_TOTAL++))
    log_info "Test 6: Validating AWS profile..."

    if ! command -v aws &> /dev/null; then
        log_warn "AWS CLI not installed - skipping profile validation"
        return 0
    fi

    # Build AWS command with profile if set
    local aws_cmd="aws"
    if [ -n "${AWS_PROFILE:-}" ]; then
        aws_cmd="aws --profile $AWS_PROFILE"
    fi

    # Try to get caller identity
    if $aws_cmd sts get-caller-identity &> /dev/null; then
        local identity
        identity=$($aws_cmd sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "unknown")
        local profile_info=""
        if [ -n "${AWS_PROFILE:-}" ]; then
            profile_info=" (profile: $AWS_PROFILE)"
        fi
        log_success "AWS credentials are valid$profile_info: $identity"
        return 0
    else
        if [ "$STRICT_MODE" = "--strict" ]; then
            log_fail "AWS credentials are invalid or expired"
            log_info "   Check with: aws sts get-caller-identity"
            return 1
        else
            log_warn "Could not validate AWS credentials"
            log_info "   This may be normal if credentials are not configured yet"
            return 0
        fi
    fi
}

# Test: S3 bucket accessibility
test_s3_bucket_access() {
    ((TESTS_TOTAL++))
    log_info "Test 7: Testing S3 bucket access..."

    if ! command -v s5cmd &> /dev/null; then
        log_fail "s5cmd not found - cannot test S3 access"
        return 1
    fi

    # Build s5cmd command with profile if set
    local s5cmd_cmd="s5cmd"
    if [ -n "${AWS_PROFILE:-}" ]; then
        s5cmd_cmd="s5cmd --profile $AWS_PROFILE"
    fi

    # If no test bucket specified, just try to list any buckets
    if [ -z "$TEST_BUCKET" ]; then
        if $s5cmd_cmd ls s3:// &> /dev/null; then
            local profile_info=""
            if [ -n "${AWS_PROFILE:-}" ]; then
                profile_info=" (using profile: $AWS_PROFILE)"
            fi
            log_success "S3 access verified (can list buckets)$profile_info"
            return 0
        else
            if [ "$STRICT_MODE" = "--strict" ]; then
                log_fail "Cannot access S3"
                log_info "   Check credentials and network connectivity"
                return 1
            else
                log_warn "Cannot list S3 buckets"
                log_info "   This may be normal if credentials are limited to specific buckets"
                return 0
            fi
        fi
    else
        # Test specific bucket
        if $s5cmd_cmd ls "s3://${TEST_BUCKET}/" &> /dev/null; then
            local profile_info=""
            if [ -n "${AWS_PROFILE:-}" ]; then
                profile_info=" (using profile: $AWS_PROFILE)"
            fi
            log_success "S3 bucket accessible: s3://${TEST_BUCKET}/$profile_info"
            return 0
        else
            if [ "$STRICT_MODE" = "--strict" ]; then
                log_fail "Cannot access S3 bucket: s3://${TEST_BUCKET}/"
                log_info "   Check bucket name, permissions, and region"
                return 1
            else
                log_warn "Cannot access S3 bucket: s3://${TEST_BUCKET}/"
                log_info "   Verify bucket name and permissions"
                return 0
            fi
        fi
    fi
}

# Test: Script files exist and have correct permissions
test_script_files() {
    ((TESTS_TOTAL++))
    log_info "Test 8: Checking script files and permissions..."

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    local all_ok=true

    # Check for required scripts
    local required_scripts=(
        "tools/install-s5cmd.sh"
        "tools/verify-installation.sh"
    )

    for script in "${required_scripts[@]}"; do
        local script_path="${script_dir}/${script}"
        if [ -f "$script_path" ]; then
            if [ -x "$script_path" ]; then
                : # OK
            else
                log_warn "  ${script} exists but is not executable"
                all_ok=false
            fi
        else
            log_warn "  ${script} not found"
            all_ok=false
        fi
    done

    if [ "$all_ok" = true ]; then
        log_success "All required scripts present and executable"
        return 0
    else
        if [ "$STRICT_MODE" = "--strict" ]; then
            log_fail "Some script files are missing or not executable"
            log_info "   Fix with: chmod +x tools/*.sh"
            return 1
        else
            log_warn "Some script files are missing or not executable"
            return 0
        fi
    fi
}

# Test: Configuration directory exists
test_config_directory() {
    ((TESTS_TOTAL++))
    log_info "Test 9: Checking configuration directory..."

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local config_dir="${script_dir}/config"

    if [ -d "$config_dir" ]; then
        log_success "Configuration directory exists: $config_dir"
        return 0
    else
        log_warn "Configuration directory not found: $config_dir"
        log_info "   This is normal for a fresh installation"
        return 0
    fi
}

# Test: Performance check (optional)
test_performance() {
    ((TESTS_TOTAL++))
    log_info "Test 10: Running basic performance check..."

    if ! command -v s5cmd &> /dev/null; then
        log_fail "s5cmd not found - cannot test performance"
        return 1
    fi

    # Just verify s5cmd runs quickly (< 1 second)
    local start_time end_time duration
    start_time=$(date +%s)
    s5cmd version &> /dev/null
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if [ $duration -le 1 ]; then
        log_success "s5cmd responds quickly (${duration}s)"
        return 0
    else
        log_warn "s5cmd response time is slow (${duration}s)"
        log_info "   This may indicate performance issues"
        return 0
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "========================================="
    echo "           Verification Summary"
    echo "========================================="
    echo ""
    echo -e "  Total Tests:  ${TESTS_TOTAL}"
    echo -e "  ${GREEN}Passed:${NC}       ${TESTS_PASSED}"
    echo -e "  ${RED}Failed:${NC}       ${TESTS_FAILED}"
    echo -e "  ${YELLOW}Warnings:${NC}     ${TESTS_WARNED}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        if [ $TESTS_WARNED -eq 0 ]; then
            echo -e "${GREEN}✓ All tests passed!${NC}"
            echo ""
            log_info "Your s5cmd installation is ready to use."
            return 0
        else
            echo -e "${YELLOW}! All critical tests passed with ${TESTS_WARNED} warning(s)${NC}"
            echo ""
            log_info "Your installation is functional but has some warnings."
            if [ "$STRICT_MODE" = "--strict" ]; then
                return 4
            else
                return 0
            fi
        fi
    else
        echo -e "${RED}✗ ${TESTS_FAILED} test(s) failed${NC}"
        echo ""
        log_info "Please address the failures above before using s5cmd."

        # Determine exit code based on failures
        if [ $TESTS_FAILED -ge 1 ] && [ $TESTS_FAILED -le 3 ]; then
            return 1  # Installation issues
        elif [ $TESTS_FAILED -ge 4 ] && [ $TESTS_FAILED -le 6 ]; then
            return 2  # Credential issues
        elif [ $TESTS_FAILED -eq 7 ]; then
            return 3  # S3 access issues
        else
            return 4  # Configuration issues
        fi
    fi
}

# Main verification flow
main() {
    echo ""
    echo "========================================="
    echo "      s5cmd Installation Verification"
    echo "========================================="
    echo ""

    if [ "$STRICT_MODE" = "--strict" ]; then
        log_info "Running in STRICT mode (all tests must pass)"
    else
        log_info "Running in NORMAL mode (warnings allowed)"
        log_info "Use --strict for stricter validation"
    fi

    echo ""

    # Run all tests
    test_s5cmd_in_path || true
    test_s5cmd_version || true
    test_s5cmd_execution || true
    test_aws_cli || true
    test_aws_credentials || true
    test_aws_profile || true
    test_s3_bucket_access || true
    test_script_files || true
    test_config_directory || true
    test_performance || true

    # Print summary and exit with appropriate code
    print_summary
}

# Run main verification
main "$@"
