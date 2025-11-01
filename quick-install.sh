#!/bin/bash
#
# quick-install.sh - One-click installation and configuration for DataSync Turbo Tools
#
# This script provides a streamlined installation experience by:
# - Running all prerequisite checks
# - Installing s5cmd binary
# - Interactively prompting for essential configuration
# - Validating inputs in real-time
# - Creating configuration files
# - Running verification tests
# - Offering immediate dry-run testing
#
# Usage: ./quick-install.sh
#
# Author: DataSync Turbo Tools Team
# Version: 1.2.0
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Configuration paths
readonly CONFIG_DIR="$SCRIPT_DIR/config"
readonly CONFIG_FILE="$CONFIG_DIR/s5cmd.env"
readonly CONFIG_TEMPLATE="$CONFIG_DIR/production.env.template"
readonly DEPLOYMENT_CONFIG_LINK="$SCRIPT_DIR/deployment/config.env"

# Installation paths
readonly TOOLS_DIR="$SCRIPT_DIR/tools"
readonly S5CMD_INSTALLER="$TOOLS_DIR/install-s5cmd.sh"
readonly VERIFICATION_SCRIPT="$TOOLS_DIR/verify-installation.sh"
readonly VALIDATOR_SCRIPT="$CONFIG_DIR/config-validator.sh"

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_step() {
    echo -e "\n${CYAN}${BOLD}==>${NC} ${BOLD}$*${NC}\n"
}

# Display banner
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         DataSync Turbo Tools - Quick Install v1.2.0          ║
║                                                               ║
║         High-Performance S3 Data Synchronization              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    log_info "This installer will guide you through the setup process."
    log_info "Estimated time: 2-3 minutes\n"
}

# Check if running with sudo (not recommended)
check_sudo() {
    if [[ "$EUID" -eq 0 ]]; then
        log_warning "Running as root is not recommended."
        log_warning "Some installation steps may require sudo, but we'll prompt when needed."
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Installation cancelled."
            exit 1
        fi
    fi
}

# Check prerequisites
check_prerequisites() {
    log_step "Step 1/7: Checking Prerequisites"

    local missing_deps=()

    # Check Bash version
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        log_error "Bash 4.0 or higher is required (found: $BASH_VERSION)"
        missing_deps+=("bash >= 4.0")
    else
        log_success "Bash version: $BASH_VERSION"
    fi

    # Check required commands
    for cmd in curl tar gzip; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "$cmd is not installed"
            missing_deps+=("$cmd")
        else
            log_success "$cmd is installed"
        fi
    done

    # Check AWS CLI (optional but recommended)
    if ! command -v aws &>/dev/null; then
        log_warning "AWS CLI is not installed (optional, but recommended for profile management)"
    else
        log_success "AWS CLI is installed: $(aws --version 2>&1 | head -n1)"
    fi

    # Check disk space
    local free_space_gb
    free_space_gb=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ "$free_space_gb" -lt 1 ]]; then
        log_warning "Low disk space: ${free_space_gb}GB available"
    else
        log_success "Disk space: ${free_space_gb}GB available"
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install missing dependencies and try again."
        exit 1
    fi

    log_success "All prerequisites met!"
}

# Install s5cmd
install_s5cmd() {
    log_step "Step 2/7: Installing s5cmd"

    if command -v s5cmd &>/dev/null; then
        log_info "s5cmd is already installed: $(s5cmd version 2>&1 || echo 'version unknown')"
        read -p "Reinstall s5cmd? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping s5cmd installation"
            return 0
        fi
    fi

    log_info "Running s5cmd installer..."
    if [[ -x "$S5CMD_INSTALLER" ]]; then
        bash "$S5CMD_INSTALLER" --non-interactive latest || {
            log_error "s5cmd installation failed"
            exit 1
        }
        log_success "s5cmd installed successfully"
    else
        log_error "s5cmd installer not found or not executable: $S5CMD_INSTALLER"
        exit 1
    fi
}

# Create directory structure
create_directories() {
    log_step "Step 3/7: Creating Directory Structure"

    local dirs=(
        "$CONFIG_DIR"
        "$SCRIPT_DIR/logs"
        "$SCRIPT_DIR/logs/json"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_success "Created: $dir"
        else
            log_info "Already exists: $dir"
        fi
    done
}

# Prompt for AWS authentication
configure_aws_auth() {
    log_info "Choose AWS authentication method:"
    echo
    echo "  1) AWS Profile (recommended for local/development)"
    echo "     Requires: aws configure --profile <name>"
    echo
    echo "  2) Direct Credentials (recommended for CI/CD)"
    echo "     Requires: Access Key ID and Secret Access Key"
    echo

    local auth_method
    while true; do
        read -p "Select method [1-2]: " auth_method
        case "$auth_method" in
            1)
                configure_aws_profile
                break
                ;;
            2)
                configure_aws_credentials
                break
                ;;
            *)
                log_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Configure AWS profile
configure_aws_profile() {
    echo
    log_info "Configuring AWS Profile authentication"

    # Check if AWS CLI is installed
    if ! command -v aws &>/dev/null; then
        log_error "AWS CLI is not installed. Cannot use profile authentication."
        log_error "Please install AWS CLI or choose direct credentials method."
        exit 1
    fi

    # List available profiles
    log_info "Available AWS profiles:"
    aws configure list-profiles 2>/dev/null | sed 's/^/  - /' || echo "  (none found)"
    echo

    while true; do
        read -p "Enter AWS profile name: " AWS_PROFILE_INPUT

        if [[ -z "$AWS_PROFILE_INPUT" ]]; then
            log_error "Profile name cannot be empty"
            continue
        fi

        # Validate profile
        log_info "Validating AWS profile: $AWS_PROFILE_INPUT"
        if aws sts get-caller-identity --profile "$AWS_PROFILE_INPUT" &>/dev/null; then
            log_success "AWS profile validated successfully"
            AWS_AUTH_METHOD="profile"
            AWS_PROFILE_VALUE="$AWS_PROFILE_INPUT"
            break
        else
            log_error "Failed to validate profile '$AWS_PROFILE_INPUT'"
            log_error "Please check the profile exists and has valid credentials"
            read -p "Try again? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                exit 1
            fi
        fi
    done
}

# Configure direct AWS credentials
configure_aws_credentials() {
    echo
    log_info "Configuring Direct Credentials authentication"

    while true; do
        read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID_INPUT

        if [[ -z "$AWS_ACCESS_KEY_ID_INPUT" ]]; then
            log_error "Access Key ID cannot be empty"
            continue
        fi

        if [[ ! "$AWS_ACCESS_KEY_ID_INPUT" =~ ^AKIA[0-9A-Z]{16}$ ]]; then
            log_warning "Access Key ID format looks unusual (expected: AKIA followed by 16 characters)"
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                continue
            fi
        fi

        break
    done

    while true; do
        read -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY_INPUT
        echo

        if [[ -z "$AWS_SECRET_ACCESS_KEY_INPUT" ]]; then
            log_error "Secret Access Key cannot be empty"
            continue
        fi

        if [[ ${#AWS_SECRET_ACCESS_KEY_INPUT} -lt 20 ]]; then
            log_warning "Secret Access Key seems too short"
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                continue
            fi
        fi

        break
    done

    # Optional session token
    read -s -p "AWS Session Token (optional, press Enter to skip): " AWS_SESSION_TOKEN_INPUT
    echo

    # Test credentials
    log_info "Testing AWS credentials..."
    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID_INPUT"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY_INPUT"
    if [[ -n "$AWS_SESSION_TOKEN_INPUT" ]]; then
        export AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN_INPUT"
    fi

    if aws sts get-caller-identity &>/dev/null; then
        log_success "AWS credentials validated successfully"
        AWS_AUTH_METHOD="credentials"
    else
        log_error "Failed to validate AWS credentials"
        log_error "Please check your Access Key ID and Secret Access Key"
        exit 1
    fi
}

# Configure S3 settings
configure_s3() {
    echo
    log_info "Configuring S3 settings"

    # S3 Bucket
    while true; do
        read -p "S3 Bucket Name: " BUCKET_NAME_INPUT

        if [[ -z "$BUCKET_NAME_INPUT" ]]; then
            log_error "Bucket name cannot be empty"
            continue
        fi

        # Validate bucket name format
        if [[ ! "$BUCKET_NAME_INPUT" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
            log_error "Invalid bucket name format"
            log_error "Must be 3-63 characters, lowercase, numbers, dots, hyphens only"
            continue
        fi

        # Test bucket access
        log_info "Testing S3 bucket access: $BUCKET_NAME_INPUT"
        if s5cmd --stat ls "s3://$BUCKET_NAME_INPUT/" &>/dev/null; then
            log_success "S3 bucket access validated successfully"
            break
        else
            log_error "Cannot access S3 bucket: $BUCKET_NAME_INPUT"
            log_error "Please check bucket name and permissions"
            read -p "Try again? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                exit 1
            fi
        fi
    done

    # S3 Subdirectory (optional)
    read -p "S3 Subdirectory (optional, e.g., 'datasync/uploads'): " S3_SUBDIRECTORY_INPUT
    if [[ -n "$S3_SUBDIRECTORY_INPUT" ]]; then
        # Remove leading/trailing slashes
        S3_SUBDIRECTORY_INPUT="${S3_SUBDIRECTORY_INPUT#/}"
        S3_SUBDIRECTORY_INPUT="${S3_SUBDIRECTORY_INPUT%/}"
    fi
}

# Configure source directory
configure_source() {
    echo
    log_info "Configuring source directory"

    while true; do
        read -e -p "Source Directory Path: " SOURCE_DIR_INPUT

        # Expand tilde
        SOURCE_DIR_INPUT="${SOURCE_DIR_INPUT/#\~/$HOME}"

        if [[ -z "$SOURCE_DIR_INPUT" ]]; then
            log_error "Source directory cannot be empty"
            continue
        fi

        if [[ ! -d "$SOURCE_DIR_INPUT" ]]; then
            log_error "Directory does not exist: $SOURCE_DIR_INPUT"
            read -p "Try again? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                exit 1
            fi
            continue
        fi

        if [[ ! -r "$SOURCE_DIR_INPUT" ]]; then
            log_error "Directory is not readable: $SOURCE_DIR_INPUT"
            continue
        fi

        log_success "Source directory validated: $SOURCE_DIR_INPUT"
        break
    done
}

# Interactive configuration
interactive_configuration() {
    log_step "Step 4/7: Configuration"

    echo
    log_info "This installer will prompt you for essential configuration."
    log_info "You can modify additional settings in $CONFIG_FILE later."
    echo

    # AWS Authentication
    configure_aws_auth

    # S3 Settings
    configure_s3

    # Source Directory
    configure_source

    log_success "Configuration complete!"
}

# Write configuration file
write_configuration() {
    log_step "Step 5/7: Writing Configuration"

    # Backup existing config if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        log_info "Backed up existing config to: $backup_file"
    fi

    # Start with template if it exists
    if [[ -f "$CONFIG_TEMPLATE" ]]; then
        cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
        log_info "Created config from template"
    else
        touch "$CONFIG_FILE"
        log_warning "Template not found, creating minimal config"
    fi

    # Update configuration values
    log_info "Writing configuration values..."

    {
        echo "# Generated by quick-install.sh on $(date)"
        echo "# DataSync Turbo Tools v1.2.0"
        echo

        # AWS Authentication
        if [[ "$AWS_AUTH_METHOD" == "profile" ]]; then
            echo "# AWS Authentication - Profile Method"
            echo "AWS_PROFILE=\"$AWS_PROFILE_VALUE\""
            echo "#AWS_ACCESS_KEY_ID=\"\""
            echo "#AWS_SECRET_ACCESS_KEY=\"\""
            echo "#AWS_SESSION_TOKEN=\"\""
        else
            echo "# AWS Authentication - Direct Credentials Method"
            echo "#AWS_PROFILE=\"\""
            echo "AWS_ACCESS_KEY_ID=\"$AWS_ACCESS_KEY_ID_INPUT\""
            echo "AWS_SECRET_ACCESS_KEY=\"$AWS_SECRET_ACCESS_KEY_INPUT\""
            if [[ -n "$AWS_SESSION_TOKEN_INPUT" ]]; then
                echo "AWS_SESSION_TOKEN=\"$AWS_SESSION_TOKEN_INPUT\""
            else
                echo "#AWS_SESSION_TOKEN=\"\""
            fi
        fi

        echo
        echo "# S3 Configuration"
        echo "S3_BUCKET=\"$BUCKET_NAME_INPUT\""
        if [[ -n "$S3_SUBDIRECTORY_INPUT" ]]; then
            echo "S3_SUBDIRECTORY=\"$S3_SUBDIRECTORY_INPUT\""
        else
            echo "#S3_SUBDIRECTORY=\"\""
        fi

        echo
        echo "# Source Directory"
        echo "SOURCE_DIR=\"$SOURCE_DIR_INPUT\""

        echo
        echo "# Performance Settings (optimized for 3+ Gbps networks)"
        echo "S5CMD_CONCURRENCY=\"64\""
        echo "S5CMD_NUM_WORKERS=\"32\""
        echo "S5CMD_PART_SIZE=\"128MB\""
        echo "S5CMD_CHECKSUM_ALGORITHM=\"CRC64NVME\""

        echo
        echo "# Storage Class"
        echo "S3_STORAGE_CLASS=\"INTELLIGENT_TIERING\""

        echo
        echo "# Logging"
        echo "ENABLE_LOGGING=\"true\""
        echo "LOG_DIR=\"$SCRIPT_DIR/logs\""
        echo "ENABLE_JSON_OUTPUT=\"true\""
        echo "JSON_OUTPUT_DIR=\"$SCRIPT_DIR/logs/json\""

    } > "$CONFIG_FILE"

    # Set proper permissions
    chmod 600 "$CONFIG_FILE"

    # Create symlink for deployment script compatibility
    if [[ ! -e "$DEPLOYMENT_CONFIG_LINK" ]]; then
        ln -sf "../config/s5cmd.env" "$DEPLOYMENT_CONFIG_LINK"
        log_success "Created deployment config symlink"
    fi

    log_success "Configuration written to: $CONFIG_FILE"
    log_info "File permissions: 600 (read/write for owner only)"
}

# Run verification
run_verification() {
    log_step "Step 6/7: Verification"

    if [[ ! -x "$VERIFICATION_SCRIPT" ]]; then
        log_warning "Verification script not found or not executable: $VERIFICATION_SCRIPT"
        return 0
    fi

    log_info "Running installation verification..."

    # Source the config for verification
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    if bash "$VERIFICATION_SCRIPT"; then
        log_success "Verification passed!"
    else
        log_warning "Some verification checks failed"
        log_warning "You may need to review the configuration"
        read -p "Continue anyway? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            exit 1
        fi
    fi
}

# Offer dry-run test
offer_dry_run() {
    log_step "Step 7/7: Testing"

    echo
    log_info "Installation complete! You can now:"
    echo
    echo "  1) Run a dry-run test (recommended)"
    echo "     This will simulate the upload without transferring data"
    echo
    echo "  2) Skip testing and exit"
    echo "     You can test manually later with:"
    echo "     ./scripts/datasync-s5cmd.sh --dry-run"
    echo

    read -p "Run dry-run test now? [Y/n] " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "Running dry-run test..."
        echo

        # shellcheck disable=SC1090
        source "$CONFIG_FILE"

        if bash "$SCRIPT_DIR/scripts/datasync-s5cmd.sh" --dry-run; then
            log_success "Dry-run test passed!"
        else
            log_warning "Dry-run test encountered issues"
            log_info "Please review the output above"
        fi
    fi
}

# Display summary
show_summary() {
    echo
    echo -e "${GREEN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                  Installation Complete!                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    log_info "Configuration saved to: $CONFIG_FILE"
    echo
    log_info "Next steps:"
    echo
    echo "  1. Test upload (dry-run):"
    echo "     ./scripts/datasync-s5cmd.sh --dry-run"
    echo
    echo "  2. Perform actual upload:"
    echo "     ./scripts/datasync-s5cmd.sh"
    echo
    echo "  3. Deploy for automated execution:"
    echo "     cd deployment && ./deploy.sh --deploy"
    echo
    echo "  4. View logs:"
    echo "     tail -f logs/datasync-s5cmd-*.log"
    echo
    log_info "Documentation: README.md"
    log_info "Configuration: $CONFIG_FILE"
    echo
    log_success "Happy syncing!"
    echo
}

# Main installation flow
main() {
    show_banner
    check_sudo
    check_prerequisites
    install_s5cmd
    create_directories
    interactive_configuration
    write_configuration
    run_verification
    offer_dry_run
    show_summary
}

# Trap errors
trap 'log_error "Installation failed at line $LINENO. Please check the output above."; exit 1' ERR

# Run main function
main "$@"
