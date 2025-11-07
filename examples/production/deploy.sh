#!/bin/bash
#
# DataSync Turbo Tools - Production Deployment Script
# Comprehensive deployment with validation, monitoring, and error handling
#
# Usage:
#   ./deploy.sh --install       # Install and configure
#   ./deploy.sh --validate      # Validate configuration
#   ./deploy.sh --deploy        # Deploy to production
#   ./deploy.sh --status        # Check deployment status
#   ./deploy.sh --undeploy      # Remove deployment
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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Find and source configuration file
# Tries multiple locations for backward compatibility
# Returns: 0 if config loaded, 1 if not found
find_and_source_config() {
    local config_locations=(
        "$PROJECT_ROOT/config/production.env"      # New location (v1.2.0+)
        "$SCRIPT_DIR/config.env"                   # Original location
        "$SCRIPT_DIR/../config/production.env"     # Relative from deployment/
        "$PROJECT_ROOT/deployment/config.env"      # Alternative deployment location
    )

    for config_file in "${config_locations[@]}"; do
        if [[ -f "$config_file" ]]; then
            # shellcheck disable=SC1090
            source "$config_file"
            return 0
        fi
    done

    return 1
}

show_help() {
    cat << EOF
DataSync Turbo Tools - Production Deployment Script

USAGE:
    ./deploy.sh [COMMAND]

COMMANDS:
    --install       Install s5cmd and dependencies
    --validate      Validate configuration and prerequisites
    --deploy        Deploy to production
    --status        Check deployment status
    --test          Run test upload (dry-run)
    --undeploy      Remove deployment
    --help          Show this help message

DEPLOYMENT PROCESS:
    1. ./deploy.sh --install      # First time only
    2. ./deploy.sh --validate     # Check everything is ready
    3. ./deploy.sh --test         # Test with dry-run
    4. ./deploy.sh --deploy       # Deploy to production

EXAMPLES:
    ./deploy.sh --install         # Initial installation
    ./deploy.sh --validate        # Pre-deployment checks
    ./deploy.sh --deploy          # Production deployment

For more information, see README.md
EOF
}

# Check if running as root (for system-wide installation)
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_warning "Not running as root. Some operations may require sudo."
        return 1
    fi
    return 0
}

# Install s5cmd and dependencies
install() {
    log_step "Installing DataSync Turbo Tools"
    echo

    # Install s5cmd
    log_info "Installing s5cmd..."
    "$PROJECT_ROOT/tools/install-s5cmd.sh"

    # Verify installation
    log_info "Verifying installation..."
    "$PROJECT_ROOT/tools/verify-installation.sh"

    # Create directories
    log_info "Creating directories..."
    if ! find_and_source_config; then
        log_warning "Config file not found, skipping directory creation"
        log_info "Run quick-install.sh or create config manually"
    else
        sudo mkdir -p "$LOG_DIR" "$JSON_OUTPUT_DIR" "$(dirname "$HEALTH_CHECK_FILE")"
        sudo chown -R "$USER:$USER" "$LOG_DIR" "$JSON_OUTPUT_DIR" "$(dirname "$HEALTH_CHECK_FILE")"
    fi

    # Configure log rotation
    log_info "Configuring log rotation..."
    sudo cp "$SCRIPT_DIR/logging/log-rotation.conf" /etc/logrotate.d/datasync-turbo

    log_success "Installation complete!"
    echo
    log_info "Next steps:"
    log_info "  1. Edit config.env with your production settings"
    log_info "  2. Run: ./deploy.sh --validate"
    log_info "  3. Run: ./deploy.sh --test"
    log_info "  4. Run: ./deploy.sh --deploy"
}

# Validate configuration
validate() {
    log_step "Validating configuration"
    echo

    local errors=0

    # Load configuration
    if ! find_and_source_config; then
        log_error "Configuration file not found"
        log_error "Expected locations:"
        log_error "  - $PROJECT_ROOT/config/production.env"
        log_error "  - $SCRIPT_DIR/config.env"
        log_error "Run quick-install.sh to create configuration"
        return 1
    fi

    # Check s5cmd
    if ! command -v s5cmd &> /dev/null; then
        log_error "s5cmd is not installed. Run: ./deploy.sh --install"
        ((errors++))
    else
        log_success "s5cmd is installed"
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        log_error "AWS credentials not configured for profile: $AWS_PROFILE"
        ((errors++))
    else
        log_success "AWS credentials are valid"
    fi

    # Check S3 bucket access
    if ! aws s3 ls "s3://$BUCKET_NAME" --profile "$AWS_PROFILE" &> /dev/null; then
        log_error "Cannot access S3 bucket: $BUCKET_NAME"
        ((errors++))
    else
        log_success "S3 bucket is accessible"
    fi

    # Check source directory
    if [ ! -d "$SOURCE_DIR" ]; then
        log_warning "Source directory does not exist: $SOURCE_DIR"
        log_info "Creating source directory..."
        mkdir -p "$SOURCE_DIR"
    else
        log_success "Source directory exists"
    fi

    # Check log directories
    if [ ! -d "$LOG_DIR" ]; then
        log_warning "Log directory does not exist: $LOG_DIR"
        log_info "Creating log directory..."
        sudo mkdir -p "$LOG_DIR"
        sudo chown -R "$USER:$USER" "$LOG_DIR"
    else
        log_success "Log directory exists"
    fi

    # Check disk space
    local free_space
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use -g flag (lowercase)
        free_space=$(df -g "$SOURCE_DIR" | awk 'NR==2 {print $4}')
    else
        # Linux: use -BG flag
        free_space=$(df -BG "$SOURCE_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    fi
    if [ "$free_space" -lt "${MIN_FREE_DISK_SPACE_GB:-10}" ]; then
        log_error "Insufficient disk space: ${free_space}GB (minimum: ${MIN_FREE_DISK_SPACE_GB}GB)"
        ((errors++))
    else
        log_success "Sufficient disk space: ${free_space}GB"
    fi

    # Check monitoring scripts
    if [ ! -f "$SCRIPT_DIR/monitoring/check-status.sh" ]; then
        log_warning "Status check script not found"
    else
        log_success "Monitoring scripts found"
    fi

    echo
    if [ $errors -eq 0 ]; then
        log_success "All validation checks passed!"
        return 0
    else
        log_error "Validation failed with $errors error(s)"
        return 1
    fi
}

# Test deployment (dry-run)
test_upload() {
    log_step "Testing upload (dry-run)"
    echo

    if ! find_and_source_config; then
        log_error "Configuration file not found"
        return 1
    fi

    log_info "Running dry-run upload..."
    "$PROJECT_ROOT/scripts/datasync-s5cmd.sh" --dry-run

    log_success "Test complete - review output above"
}

# Deploy to production
deploy() {
    log_step "Deploying to production"
    echo

    # Validate first
    if ! validate; then
        log_error "Validation failed. Fix errors before deploying."
        return 1
    fi

    echo
    log_warning "This will deploy DataSync Turbo Tools to production."
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Deployment cancelled."
        return 0
    fi

    if ! find_and_source_config; then
        log_error "Configuration file not found"
        return 1
    fi

    # Create systemd service (optional)
    log_info "Would you like to create a systemd service for automatic uploads?"
    read -p "(yes/no): " create_service

    if [ "$create_service" = "yes" ]; then
        create_systemd_service
    fi

    log_success "Deployment complete!"
    echo
    log_info "Next steps:"
    log_info "  • Monitor logs: tail -f $LOG_DIR/datasync.log"
    log_info "  • Check status: ./deploy.sh --status"
    log_info "  • View monitoring: ./monitoring/check-status.sh"
}

# Create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."

    # Determine config file location
    local config_file=""
    if [[ -f "$PROJECT_ROOT/config/production.env" ]]; then
        config_file="$PROJECT_ROOT/config/production.env"
    elif [[ -f "$SCRIPT_DIR/config.env" ]]; then
        config_file="$SCRIPT_DIR/config.env"
    elif [[ -f "$SCRIPT_DIR/../config/production.env" ]]; then
        config_file="$SCRIPT_DIR/../config/production.env"
    fi

    local service_file="/etc/systemd/system/datasync-turbo.service"

    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=DataSync Turbo Tools - S3 Upload Service
After=network.target

[Service]
Type=oneshot
User=$USER
WorkingDirectory=$PROJECT_ROOT
EnvironmentFile=$config_file
ExecStart=$PROJECT_ROOT/scripts/datasync-s5cmd.sh

[Install]
WantedBy=multi-user.target
EOF

    # Create timer for scheduled uploads
    local timer_file="/etc/systemd/system/datasync-turbo.timer"

    sudo tee "$timer_file" > /dev/null << EOF
[Unit]
Description=DataSync Turbo Tools - Upload Timer
Requires=datasync-turbo.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable datasync-turbo.timer

    log_success "Systemd service created"
    log_info "Start timer: sudo systemctl start datasync-turbo.timer"
}

# Check deployment status
check_status() {
    log_step "Checking deployment status"
    echo

    find_and_source_config 2>/dev/null || true

    # Check s5cmd
    if command -v s5cmd &> /dev/null; then
        log_success "s5cmd: $(s5cmd version | head -1)"
    else
        log_error "s5cmd: Not installed"
    fi

    # Check last sync
    if [ -f "${HEALTH_CHECK_FILE:-/var/run/datasync-turbo/last-sync}" ]; then
        local last_sync=$(cat "$HEALTH_CHECK_FILE")
        log_info "Last sync: $last_sync"
    else
        log_warning "No sync history found"
    fi

    # Check systemd service
    if systemctl list-unit-files | grep -q datasync-turbo.timer; then
        local status=$(systemctl is-active datasync-turbo.timer)
        if [ "$status" = "active" ]; then
            log_success "Systemd timer: active"
        else
            log_warning "Systemd timer: $status"
        fi
    else
        log_info "Systemd timer: not configured"
    fi

    # Check logs
    if [ -d "${LOG_DIR:-/var/log/datasync-turbo}" ]; then
        local log_count=$(find "${LOG_DIR:-/var/log/datasync-turbo}" -type f 2>/dev/null | wc -l)
        log_info "Log files: $log_count"
    fi

    # Run monitoring check if available
    if [ -f "$SCRIPT_DIR/monitoring/check-status.sh" ]; then
        echo
        "$SCRIPT_DIR/monitoring/check-status.sh"
    fi
}

# Undeploy from production
undeploy() {
    log_step "Removing deployment"
    echo

    log_warning "This will remove DataSync Turbo Tools from production."
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Undeploy cancelled."
        return 0
    fi

    # Stop and disable systemd service
    if systemctl list-unit-files | grep -q datasync-turbo; then
        log_info "Stopping systemd service..."
        sudo systemctl stop datasync-turbo.timer 2>/dev/null || true
        sudo systemctl disable datasync-turbo.timer 2>/dev/null || true
        sudo rm -f /etc/systemd/system/datasync-turbo.{service,timer}
        sudo systemctl daemon-reload
    fi

    # Remove log rotation
    sudo rm -f /etc/logrotate.d/datasync-turbo

    log_success "Deployment removed"
    log_info "Note: Logs and data have been preserved"
}

# ============================================================================
# Main
# ============================================================================

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    --install)
        install
        ;;
    --validate)
        validate
        ;;
    --test)
        test_upload
        ;;
    --deploy)
        deploy
        ;;
    --status)
        check_status
        ;;
    --undeploy)
        undeploy
        ;;
    --help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
