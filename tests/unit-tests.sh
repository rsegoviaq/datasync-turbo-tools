#!/bin/bash
#
# unit-tests.sh - Installation validation and unit tests
#
# Validates that all components are properly installed and configured
#
# Usage:
#   ./unit-tests.sh [--verbose]
#
# Exit codes:
#   0 - All tests passed
#   1 - Installation issues
#   2 - Script/configuration issues
#   3 - Permission issues
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++)) || true
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++)) || true
}

log_test() {
    ((TESTS_TOTAL++)) || true
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[TEST $TESTS_TOTAL]${NC} $1"
    fi
}

# Test: s5cmd binary exists
test_s5cmd_binary() {
    log_test "Checking if s5cmd is installed"

    if command -v s5cmd &> /dev/null; then
        local version
        version=$(s5cmd version 2>&1 | head -n 1)
        log_pass "s5cmd is installed: $version"
        return 0
    else
        log_fail "s5cmd not found in PATH"
        log_info "   Install with: ./tools/install-s5cmd.sh"
        return 1
    fi
}

# Test: s5cmd version check
test_s5cmd_version() {
    log_test "Validating s5cmd version"

    if ! command -v s5cmd &> /dev/null; then
        log_fail "s5cmd not found"
        return 1
    fi

    local version
    version=$(s5cmd version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "")

    if [ -z "$version" ]; then
        log_fail "Could not determine s5cmd version"
        return 1
    fi

    local major
    major=$(echo "$version" | sed 's/v//' | cut -d. -f1)

    if [ "$major" -ge 2 ]; then
        log_pass "s5cmd version $version (>= v2.0.0)"
        return 0
    else
        log_fail "s5cmd version $version is too old (need >= v2.0.0)"
        return 1
    fi
}

# Test: Installation script exists and is executable
test_installation_script() {
    log_test "Checking installation script"

    local script="${PROJECT_DIR}/tools/install-s5cmd.sh"

    if [ ! -f "$script" ]; then
        log_fail "Installation script not found: $script"
        return 1
    fi

    if [ ! -x "$script" ]; then
        log_fail "Installation script is not executable: $script"
        log_info "   Fix with: chmod +x $script"
        return 1
    fi

    log_pass "Installation script exists and is executable"
    return 0
}

# Test: Verification script exists and is executable
test_verification_script() {
    log_test "Checking verification script"

    local script="${PROJECT_DIR}/tools/verify-installation.sh"

    if [ ! -f "$script" ]; then
        log_fail "Verification script not found: $script"
        return 1
    fi

    if [ ! -x "$script" ]; then
        log_fail "Verification script is not executable: $script"
        return 1
    fi

    log_pass "Verification script exists and is executable"
    return 0
}

# Test: Benchmark script exists and is executable
test_benchmark_script() {
    log_test "Checking benchmark script"

    local script="${PROJECT_DIR}/tools/benchmark.sh"

    if [ ! -f "$script" ]; then
        log_fail "Benchmark script not found: $script"
        return 1
    fi

    if [ ! -x "$script" ]; then
        log_fail "Benchmark script is not executable: $script"
        return 1
    fi

    log_pass "Benchmark script exists and is executable"
    return 0
}

# Test: Upload scripts exist and are executable
test_upload_scripts() {
    log_test "Checking upload scripts"

    local errors=0

    # Check s5cmd script
    if [ ! -f "${PROJECT_DIR}/scripts/datasync-s5cmd.sh" ]; then
        log_fail "s5cmd upload script not found"
        ((errors++)) || true
    elif [ ! -x "${PROJECT_DIR}/scripts/datasync-s5cmd.sh" ]; then
        log_fail "s5cmd upload script is not executable"
        ((errors++)) || true
    fi

    # Check AWS CLI script
    if [ ! -f "${PROJECT_DIR}/scripts/datasync-awscli.sh" ]; then
        log_fail "AWS CLI upload script not found"
        ((errors++)) || true
    elif [ ! -x "${PROJECT_DIR}/scripts/datasync-awscli.sh" ]; then
        log_fail "AWS CLI upload script is not executable"
        ((errors++)) || true
    fi

    # Check sync-now wrapper
    if [ ! -f "${PROJECT_DIR}/scripts/sync-now.sh" ]; then
        log_fail "sync-now wrapper script not found"
        ((errors++)) || true
    elif [ ! -x "${PROJECT_DIR}/scripts/sync-now.sh" ]; then
        log_fail "sync-now wrapper script is not executable"
        ((errors++)) || true
    fi

    if [ $errors -eq 0 ]; then
        log_pass "All upload scripts exist and are executable"
        return 0
    else
        return 1
    fi
}

# Test: Configuration templates exist
test_config_templates() {
    log_test "Checking configuration templates"

    local errors=0

    if [ ! -f "${PROJECT_DIR}/config/s5cmd.env.template" ]; then
        log_fail "s5cmd config template not found"
        ((errors++)) || true
    fi

    if [ ! -f "${PROJECT_DIR}/config/awscli.env.template" ]; then
        log_fail "AWS CLI config template not found"
        ((errors++)) || true
    fi

    if [ $errors -eq 0 ]; then
        log_pass "All configuration templates exist"
        return 0
    else
        return 1
    fi
}

# Test: Directory structure
test_directory_structure() {
    log_test "Validating directory structure"

    local errors=0
    local dirs=("tools" "scripts" "config" "tests" "docs" "examples")

    for dir in "${dirs[@]}"; do
        if [ ! -d "${PROJECT_DIR}/${dir}" ]; then
            log_fail "Directory not found: ${dir}/"
            ((errors++)) || true
        fi
    done

    if [ $errors -eq 0 ]; then
        log_pass "Directory structure is correct"
        return 0
    else
        return 1
    fi
}

# Test: README exists
test_readme() {
    log_test "Checking README file"

    if [ ! -f "${PROJECT_DIR}/README.md" ]; then
        log_fail "README.md not found"
        return 1
    fi

    # Check if README has content
    local lines
    lines=$(wc -l < "${PROJECT_DIR}/README.md")

    if [ "$lines" -lt 10 ]; then
        log_fail "README.md seems incomplete (< 10 lines)"
        return 1
    fi

    log_pass "README.md exists and has content"
    return 0
}

# Test: LICENSE exists
test_license() {
    log_test "Checking LICENSE file"

    if [ ! -f "${PROJECT_DIR}/LICENSE" ]; then
        log_fail "LICENSE not found"
        return 1
    fi

    log_pass "LICENSE file exists"
    return 0
}

# Test: .gitignore exists
test_gitignore() {
    log_test "Checking .gitignore file"

    if [ ! -f "${PROJECT_DIR}/.gitignore" ]; then
        log_fail ".gitignore not found"
        return 1
    fi

    log_pass ".gitignore file exists"
    return 0
}

# Test: Scripts have proper shebang
test_script_shebangs() {
    log_test "Validating script shebangs"

    local errors=0
    local scripts=(
        "tools/install-s5cmd.sh"
        "tools/verify-installation.sh"
        "tools/benchmark.sh"
        "scripts/datasync-s5cmd.sh"
        "scripts/datasync-awscli.sh"
        "scripts/sync-now.sh"
        "tests/unit-tests.sh"
    )

    for script in "${scripts[@]}"; do
        local script_path="${PROJECT_DIR}/${script}"
        if [ -f "$script_path" ]; then
            local first_line
            first_line=$(head -n 1 "$script_path")
            if [[ ! "$first_line" =~ ^#!/bin/bash ]]; then
                log_fail "$script has invalid shebang: $first_line"
                ((errors++)) || true
            fi
        fi
    done

    if [ $errors -eq 0 ]; then
        log_pass "All scripts have proper shebangs"
        return 0
    else
        return 1
    fi
}

# Test: AWS CLI optional check
test_aws_cli_optional() {
    log_test "Checking AWS CLI (optional)"

    if command -v aws &> /dev/null; then
        local version
        version=$(aws --version 2>&1 | head -n 1)
        log_pass "AWS CLI installed: $version"
        return 0
    else
        log_info "AWS CLI not installed (optional)"
        ((TESTS_PASSED++)) || true
        return 0
    fi
}

# Test: Git repository
test_git_repository() {
    log_test "Validating git repository"

    if [ ! -d "${PROJECT_DIR}/.git" ]; then
        log_fail "Not a git repository"
        return 1
    fi

    # Check if there are commits
    if ! git -C "$PROJECT_DIR" rev-parse HEAD &> /dev/null; then
        log_fail "Git repository has no commits"
        return 1
    fi

    log_pass "Git repository is valid"
    return 0
}

# Test: Logs directory can be created
test_logs_directory() {
    log_test "Testing logs directory creation"

    local logs_dir="${PROJECT_DIR}/logs"

    if [ ! -d "$logs_dir" ]; then
        if mkdir -p "$logs_dir" 2>/dev/null; then
            log_pass "Logs directory can be created"
            return 0
        else
            log_fail "Cannot create logs directory"
            return 1
        fi
    else
        if [ -w "$logs_dir" ]; then
            log_pass "Logs directory exists and is writable"
            return 0
        else
            log_fail "Logs directory exists but is not writable"
            return 1
        fi
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "========================================="
    echo "         Unit Tests Summary"
    echo "========================================="
    echo ""
    echo "  Total Tests:  $TESTS_TOTAL"
    echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All unit tests passed!${NC}"
        echo ""
        log_info "Installation is complete and valid"
        return 0
    else
        echo -e "${RED}✗ $TESTS_FAILED test(s) failed${NC}"
        echo ""
        log_info "Please fix the issues above"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo "========================================="
    echo "    DataSync Turbo Tools - Unit Tests"
    echo "========================================="
    echo ""

    if [ "$VERBOSE" = true ]; then
        log_info "Running in verbose mode"
    fi

    log_info "Project directory: $PROJECT_DIR"
    echo ""

    # Run all tests
    test_s5cmd_binary || true
    test_s5cmd_version || true
    test_installation_script || true
    test_verification_script || true
    test_benchmark_script || true
    test_upload_scripts || true
    test_config_templates || true
    test_directory_structure || true
    test_readme || true
    test_license || true
    test_gitignore || true
    test_script_shebangs || true
    test_aws_cli_optional || true
    test_git_repository || true
    test_logs_directory || true

    # Print summary
    print_summary
}

# Run main
main "$@"
