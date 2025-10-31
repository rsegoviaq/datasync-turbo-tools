#!/bin/bash
#
# config-validator.sh - Reusable configuration validation functions
#
# This script provides validation functions that can be sourced by other scripts
# to validate AWS credentials, S3 bucket access, and other configuration settings.
#
# Usage: source config/config-validator.sh
#        validate_aws_credentials
#        validate_s3_bucket "bucket-name"
#
# Author: DataSync Turbo Tools Team
# Version: 1.2.0
#

# Color codes for output
readonly V_RED='\033[0;31m'
readonly V_GREEN='\033[0;32m'
readonly V_YELLOW='\033[1;33m'
readonly V_BLUE='\033[0;34m'
readonly V_NC='\033[0m' # No Color

# Validation log functions
v_log_info() {
    echo -e "${V_BLUE}[VALIDATE]${V_NC} $*" >&2
}

v_log_success() {
    echo -e "${V_GREEN}[VALID]${V_NC} $*" >&2
}

v_log_warning() {
    echo -e "${V_YELLOW}[WARNING]${V_NC} $*" >&2
}

v_log_error() {
    echo -e "${V_RED}[INVALID]${V_NC} $*" >&2
}

#
# Validate AWS credentials
#
# Returns: 0 if valid, 1 if invalid
#
# Usage:
#   if validate_aws_credentials; then
#       echo "Credentials are valid"
#   fi
#
validate_aws_credentials() {
    v_log_info "Validating AWS credentials..."

    # Check if AWS CLI is available
    if ! command -v aws &>/dev/null; then
        v_log_warning "AWS CLI not installed, skipping credential validation"
        return 0  # Not an error, just a warning
    fi

    # Try to get caller identity
    if aws sts get-caller-identity &>/dev/null; then
        local identity
        identity=$(aws sts get-caller-identity --output json 2>/dev/null)
        local account
        local arn
        account=$(echo "$identity" | grep -oP '"Account":\s*"\K[^"]+')
        arn=$(echo "$identity" | grep -oP '"Arn":\s*"\K[^"]+')

        v_log_success "AWS credentials valid"
        v_log_info "Account: $account"
        v_log_info "Identity: $arn"
        return 0
    else
        v_log_error "AWS credentials are invalid or not configured"
        return 1
    fi
}

#
# Validate AWS profile
#
# Args:
#   $1 - Profile name
#
# Returns: 0 if valid, 1 if invalid
#
# Usage:
#   if validate_aws_profile "my-profile"; then
#       echo "Profile is valid"
#   fi
#
validate_aws_profile() {
    local profile_name="$1"

    if [[ -z "$profile_name" ]]; then
        v_log_error "Profile name is required"
        return 1
    fi

    v_log_info "Validating AWS profile: $profile_name"

    # Check if AWS CLI is available
    if ! command -v aws &>/dev/null; then
        v_log_error "AWS CLI is not installed"
        return 1
    fi

    # Check if profile exists
    if ! aws configure list-profiles 2>/dev/null | grep -q "^${profile_name}$"; then
        v_log_error "Profile '$profile_name' not found"
        return 1
    fi

    # Test profile by getting caller identity
    if aws sts get-caller-identity --profile "$profile_name" &>/dev/null; then
        v_log_success "AWS profile '$profile_name' is valid"
        return 0
    else
        v_log_error "AWS profile '$profile_name' has invalid credentials"
        return 1
    fi
}

#
# Validate S3 bucket access
#
# Args:
#   $1 - Bucket name
#   $2 - Optional subdirectory
#
# Returns: 0 if accessible, 1 if not
#
# Usage:
#   if validate_s3_bucket "my-bucket" "my-prefix"; then
#       echo "Bucket is accessible"
#   fi
#
validate_s3_bucket() {
    local bucket_name="$1"
    local subdirectory="${2:-}"

    if [[ -z "$bucket_name" ]]; then
        v_log_error "Bucket name is required"
        return 1
    fi

    v_log_info "Validating S3 bucket access: s3://$bucket_name/$subdirectory"

    # Check if s5cmd is available
    if ! command -v s5cmd &>/dev/null; then
        v_log_error "s5cmd is not installed"
        return 1
    fi

    # Test bucket access
    local s3_path="s3://$bucket_name/"
    if [[ -n "$subdirectory" ]]; then
        s3_path="s3://$bucket_name/$subdirectory/"
    fi

    if s5cmd --stat ls "$s3_path" &>/dev/null; then
        v_log_success "S3 bucket is accessible: $s3_path"
        return 0
    else
        v_log_error "Cannot access S3 bucket: $s3_path"
        v_log_error "Please check:"
        v_log_error "  - Bucket name is correct"
        v_log_error "  - AWS credentials have s3:ListBucket permission"
        v_log_error "  - Bucket exists in the expected region"
        return 1
    fi
}

#
# Validate source directory
#
# Args:
#   $1 - Directory path
#
# Returns: 0 if valid, 1 if invalid
#
# Usage:
#   if validate_source_directory "/path/to/data"; then
#       echo "Directory is valid"
#   fi
#
validate_source_directory() {
    local dir_path="$1"

    if [[ -z "$dir_path" ]]; then
        v_log_error "Directory path is required"
        return 1
    fi

    v_log_info "Validating source directory: $dir_path"

    # Check if directory exists
    if [[ ! -e "$dir_path" ]]; then
        v_log_error "Path does not exist: $dir_path"
        return 1
    fi

    # Check if it's a directory
    if [[ ! -d "$dir_path" ]]; then
        v_log_error "Path is not a directory: $dir_path"
        return 1
    fi

    # Check if readable
    if [[ ! -r "$dir_path" ]]; then
        v_log_error "Directory is not readable: $dir_path"
        return 1
    fi

    # Check if directory is empty
    if [[ ! "$(ls -A "$dir_path" 2>/dev/null)" ]]; then
        v_log_warning "Directory is empty: $dir_path"
    fi

    v_log_success "Source directory is valid: $dir_path"
    return 0
}

#
# Validate s5cmd installation
#
# Returns: 0 if valid, 1 if invalid
#
# Usage:
#   if validate_s5cmd_installation; then
#       echo "s5cmd is installed"
#   fi
#
validate_s5cmd_installation() {
    v_log_info "Validating s5cmd installation..."

    # Check if s5cmd is installed
    if ! command -v s5cmd &>/dev/null; then
        v_log_error "s5cmd is not installed or not in PATH"
        return 1
    fi

    # Check s5cmd version
    local version
    version=$(s5cmd version 2>&1 || echo "unknown")
    v_log_success "s5cmd is installed: $version"

    # Test s5cmd execution
    if s5cmd ls &>/dev/null || [[ $? -eq 1 ]]; then
        # Exit code 1 is expected if no args provided, means s5cmd works
        v_log_success "s5cmd is executable"
        return 0
    else
        v_log_error "s5cmd execution test failed"
        return 1
    fi
}

#
# Validate configuration file
#
# Args:
#   $1 - Config file path
#
# Returns: 0 if valid, 1 if invalid
#
# Usage:
#   if validate_config_file "config/production.env"; then
#       echo "Config is valid"
#   fi
#
validate_config_file() {
    local config_file="$1"

    if [[ -z "$config_file" ]]; then
        v_log_error "Config file path is required"
        return 1
    fi

    v_log_info "Validating configuration file: $config_file"

    # Check if file exists
    if [[ ! -f "$config_file" ]]; then
        v_log_error "Configuration file not found: $config_file"
        return 1
    fi

    # Check if file is readable
    if [[ ! -r "$config_file" ]]; then
        v_log_error "Configuration file is not readable: $config_file"
        return 1
    fi

    # Source the config file
    # shellcheck disable=SC1090
    if ! source "$config_file" 2>/dev/null; then
        v_log_error "Configuration file has syntax errors: $config_file"
        return 1
    fi

    v_log_success "Configuration file is valid"

    # Validate required variables
    local required_vars=("BUCKET_NAME" "SOURCE_DIR")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        v_log_error "Missing required variables: ${missing_vars[*]}"
        return 1
    fi

    v_log_success "All required variables are set"

    # Check auth method
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        v_log_info "Authentication method: AWS Profile ($AWS_PROFILE)"
    elif [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        v_log_info "Authentication method: Direct Credentials"
    else
        v_log_error "No valid AWS authentication configured"
        v_log_error "Set AWS_PROFILE or AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY"
        return 1
    fi

    return 0
}

#
# Validate complete configuration
#
# This function validates all aspects of the configuration
#
# Args:
#   $1 - Config file path (optional, uses environment if not provided)
#
# Returns: 0 if all valid, 1 if any validation fails
#
# Usage:
#   if validate_complete_configuration "config/production.env"; then
#       echo "Configuration is ready"
#   fi
#
validate_complete_configuration() {
    local config_file="${1:-}"
    local validation_failed=0

    v_log_info "Running complete configuration validation..."
    echo

    # If config file provided, validate and source it
    if [[ -n "$config_file" ]]; then
        if ! validate_config_file "$config_file"; then
            return 1
        fi
        # shellcheck disable=SC1090
        source "$config_file"
    fi

    # Validate s5cmd
    if ! validate_s5cmd_installation; then
        validation_failed=1
    fi
    echo

    # Validate AWS credentials
    if ! validate_aws_credentials; then
        validation_failed=1
    fi
    echo

    # Validate S3 bucket (if BUCKET_NAME is set)
    if [[ -n "${BUCKET_NAME:-}" ]]; then
        if ! validate_s3_bucket "$BUCKET_NAME" "${S3_SUBDIRECTORY:-}"; then
            validation_failed=1
        fi
        echo
    fi

    # Validate source directory (if SOURCE_DIR is set)
    if [[ -n "${SOURCE_DIR:-}" ]]; then
        if ! validate_source_directory "$SOURCE_DIR"; then
            validation_failed=1
        fi
        echo
    fi

    if [[ $validation_failed -eq 0 ]]; then
        v_log_success "Complete configuration validation passed!"
        return 0
    else
        v_log_error "Configuration validation failed"
        return 1
    fi
}

#
# Validate disk space
#
# Args:
#   $1 - Directory path to check
#   $2 - Minimum required space in GB (default: 1)
#
# Returns: 0 if sufficient space, 1 if not
#
# Usage:
#   if validate_disk_space "/data" 10; then
#       echo "Sufficient disk space"
#   fi
#
validate_disk_space() {
    local dir_path="${1:-.}"
    local min_space_gb="${2:-1}"

    v_log_info "Validating disk space: $dir_path (minimum: ${min_space_gb}GB)"

    # Get available space in GB
    local free_space_gb
    free_space_gb=$(df -BG "$dir_path" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")

    if [[ "$free_space_gb" -lt "$min_space_gb" ]]; then
        v_log_error "Insufficient disk space: ${free_space_gb}GB available, ${min_space_gb}GB required"
        return 1
    fi

    v_log_success "Sufficient disk space: ${free_space_gb}GB available"
    return 0
}

#
# Export functions if this script is sourced
#
# This allows other scripts to use these validation functions
#
export -f validate_aws_credentials 2>/dev/null || true
export -f validate_aws_profile 2>/dev/null || true
export -f validate_s3_bucket 2>/dev/null || true
export -f validate_source_directory 2>/dev/null || true
export -f validate_s5cmd_installation 2>/dev/null || true
export -f validate_config_file 2>/dev/null || true
export -f validate_complete_configuration 2>/dev/null || true
export -f validate_disk_space 2>/dev/null || true

# If script is executed directly (not sourced), show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "config-validator.sh - Reusable Configuration Validation Functions"
    echo
    echo "This script provides validation functions for DataSync Turbo Tools."
    echo
    echo "Usage: source config/config-validator.sh"
    echo
    echo "Available functions:"
    echo "  validate_aws_credentials"
    echo "  validate_aws_profile <profile-name>"
    echo "  validate_s3_bucket <bucket-name> [subdirectory]"
    echo "  validate_source_directory <dir-path>"
    echo "  validate_s5cmd_installation"
    echo "  validate_config_file <config-path>"
    echo "  validate_complete_configuration [config-path]"
    echo "  validate_disk_space <dir-path> [min-gb]"
    echo
    echo "Example:"
    echo "  source config/config-validator.sh"
    echo "  if validate_s3_bucket \"my-bucket\"; then"
    echo "      echo \"Bucket is accessible\""
    echo "  fi"
fi
