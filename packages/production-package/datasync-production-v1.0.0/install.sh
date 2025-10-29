#!/bin/bash
#
# DataSync Turbo Tools - Production Package Installer
# Version: 1.0.0
#
# Quick installation script for production deployment
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

show_banner() {
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║  DataSync Turbo Tools - Production Installation          ║
║  Version: 1.0.0                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    echo ""

    local errors=0

    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        log_success "Operating System: $(uname -s)"
    else
        log_error "Unsupported operating system: $OSTYPE"
        ((errors++))
    fi

    # Check bash version
    if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
        log_success "Bash version: $BASH_VERSION"
    else
        log_warning "Bash version 4+ recommended (current: $BASH_VERSION)"
    fi

    # Check AWS CLI
    if command -v aws &> /dev/null; then
        log_success "AWS CLI installed: $(aws --version | cut -d' ' -f1)"
    else
        log_error "AWS CLI not found - please install: https://aws.amazon.com/cli/"
        ((errors++))
    fi

    # Check disk space
    local free_space=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$free_space" -gt 1 ]; then
        log_success "Disk space available: ${free_space}GB"
    else
        log_error "Insufficient disk space: ${free_space}GB"
        ((errors++))
    fi

    # Check required commands
    for cmd in curl tar gzip; do
        if command -v "$cmd" &> /dev/null; then
            log_success "$cmd installed"
        else
            log_error "$cmd not found"
            ((errors++))
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        log_success "All prerequisites met!"
        return 0
    else
        log_error "Prerequisites check failed with $errors error(s)"
        return 1
    fi
}

install_s5cmd() {
    log_step "Installing s5cmd..."
    echo ""

    if command -v s5cmd &> /dev/null; then
        log_info "s5cmd already installed: $(s5cmd version | head -1)"
        read -p "Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    chmod +x "$SCRIPT_DIR/tools/install-s5cmd.sh"
    if "$SCRIPT_DIR/tools/install-s5cmd.sh"; then
        log_success "s5cmd installed successfully"
        return 0
    else
        log_error "s5cmd installation failed"
        return 1
    fi
}

setup_configuration() {
    log_step "Setting up configuration..."
    echo ""

    local config_file="$SCRIPT_DIR/config/production.env"

    if [ ! -f "$config_file" ]; then
        log_info "Creating production configuration from template..."
        cp "$SCRIPT_DIR/config/production.env.template" "$config_file"
    fi

    log_info "Configuration file: $config_file"
    echo ""
    log_warning "IMPORTANT: You must edit this file with your settings!"
    echo ""
    log_info "Required settings:"
    log_info "  - AWS_PROFILE (your AWS profile name)"
    log_info "  - BUCKET_NAME (your S3 bucket)"
    log_info "  - SOURCE_DIR (directory to upload)"
    echo ""

    read -p "Open configuration file now? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        "${EDITOR:-nano}" "$config_file"
    fi
}

create_directories() {
    log_step "Creating directories..."
    echo ""

    local dirs=("logs" "logs/json" "config")

    for dir in "${dirs[@]}"; do
        local dir_path="$SCRIPT_DIR/$dir"
        if [ ! -d "$dir_path" ]; then
            mkdir -p "$dir_path"
            log_success "Created: $dir"
        else
            log_info "Already exists: $dir"
        fi
    done
}

setup_permissions() {
    log_step "Setting permissions..."
    echo ""

    chmod +x "$SCRIPT_DIR/scripts"/*.sh 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/tools"/*.sh 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/monitoring"/*.sh 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/deployment"/*.sh 2>/dev/null || true

    log_success "Permissions set"
}

show_next_steps() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Installation Complete!                                  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    log_step "Next Steps:"
    echo ""
    echo "1. Edit configuration:"
    echo "   ${CYAN}nano config/production.env${NC}"
    echo ""
    echo "2. Verify setup:"
    echo "   ${CYAN}./tools/verify-installation.sh${NC}"
    echo ""
    echo "3. Test with dry-run:"
    echo "   ${CYAN}source config/production.env && ./scripts/datasync-s5cmd.sh --dry-run${NC}"
    echo ""
    echo "4. Deploy to production:"
    echo "   ${CYAN}cd deployment && ./deploy.sh --validate${NC}"
    echo "   ${CYAN}cd deployment && ./deploy.sh --deploy${NC}"
    echo ""
    echo "5. Monitor status:"
    echo "   ${CYAN}./monitoring/check-status.sh${NC}"
    echo ""
    log_info "Documentation: README.md"
    log_info "Support: Check monitoring/README.md for troubleshooting"
    echo ""
}

main() {
    show_banner

    # Run installation steps
    if ! check_prerequisites; then
        log_error "Please fix prerequisites before continuing"
        exit 1
    fi

    echo ""
    read -p "Continue with installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi

    echo ""
    if ! install_s5cmd; then
        log_error "Installation failed at s5cmd step"
        exit 1
    fi

    echo ""
    create_directories

    echo ""
    setup_permissions

    echo ""
    setup_configuration

    show_next_steps
}

# Run main installation
main
