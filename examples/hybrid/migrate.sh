#!/bin/bash
#
# DataSync Turbo Tools - Migration Helper
# Assist with migrating from AWS CLI to s5cmd
#
# Usage:
#   ./migrate.sh --check          # Check current setup
#   ./migrate.sh --plan           # Generate migration plan
#   ./migrate.sh --test           # Test s5cmd with existing config
#   ./migrate.sh --migrate        # Perform migration
#   ./migrate.sh --rollback       # Rollback to AWS CLI
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

show_help() {
    cat << EOF
DataSync Turbo Tools - Migration Helper

USAGE:
    ./migrate.sh [COMMAND]

COMMANDS:
    --check         Check current AWS CLI setup
    --plan          Generate migration plan
    --test          Test s5cmd with existing config
    --migrate       Perform migration to s5cmd
    --rollback      Rollback to AWS CLI
    --help          Show this help message

MIGRATION PROCESS:
    1. ./migrate.sh --check       # Verify AWS CLI setup
    2. ./migrate.sh --plan        # Review migration plan
    3. ./migrate.sh --test        # Test s5cmd
    4. ./migrate.sh --migrate     # Complete migration

If needed:
    ./migrate.sh --rollback       # Revert to AWS CLI

EXAMPLES:
    ./migrate.sh --check          # Initial assessment
    ./migrate.sh --test           # Test before migrating
    ./migrate.sh --migrate        # Complete migration

For more information, see README.md
EOF
}

# Check current setup
check_setup() {
    log_step "Checking current setup"
    echo

    local issues=0

    # Check AWS CLI
    if command -v aws &> /dev/null; then
        log_success "AWS CLI installed: $(aws --version)"
    else
        log_error "AWS CLI not installed"
        ((issues++))
    fi

    # Check s5cmd
    if command -v s5cmd &> /dev/null; then
        log_success "s5cmd installed: $(s5cmd version | head -1)"
    else
        log_warning "s5cmd not installed"
        log_info "Install with: $PROJECT_ROOT/tools/install-s5cmd.sh"
        ((issues++))
    fi

    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        log_success "AWS credentials configured"
    else
        log_error "AWS credentials not configured"
        ((issues++))
    fi

    # Check for existing datasync scripts
    if [ -f "/path/to/existing/datasync-simulator.sh" ]; then
        log_info "Found existing datasync-simulator.sh"
    else
        log_warning "No existing datasync-simulator.sh found"
    fi

    echo
    if [ $issues -eq 0 ]; then
        log_success "Setup check passed!"
        log_info "Ready to proceed with migration planning."
        return 0
    else
        log_error "Setup check found $issues issue(s)"
        log_info "Fix issues before proceeding."
        return 1
    fi
}

# Generate migration plan
generate_plan() {
    log_step "Generating migration plan"
    echo

    cat << EOF
╔════════════════════════════════════════════════════════════════╗
║                      MIGRATION PLAN                             ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  Phase 1: Preparation (Day 1)                                  ║
║  ─────────────────────────                                      ║
║  1. Install s5cmd                                              ║
║  2. Create s5cmd configuration from AWS CLI config             ║
║  3. Test s5cmd with dry-run                                    ║
║  4. Benchmark both tools side-by-side                          ║
║                                                                 ║
║  Phase 2: Pilot (Days 2-7)                                     ║
║  ─────────────────────────                                      ║
║  1. Run s5cmd alongside AWS CLI (no changes)                   ║
║  2. Monitor both tools daily                                   ║
║  3. Compare performance and reliability                        ║
║  4. Verify checksum consistency                                ║
║  5. Test error handling and retries                            ║
║                                                                 ║
║  Phase 3: Switchover (Day 8)                                   ║
║  ─────────────────────────────                                  ║
║  1. Backup AWS CLI configuration                               ║
║  2. Update scripts to use s5cmd                                ║
║  3. Update monitoring/alerting                                 ║
║  4. Update documentation                                       ║
║  5. Notify team of changes                                     ║
║                                                                 ║
║  Phase 4: Validation (Days 9-14)                               ║
║  ───────────────────────────────                                ║
║  1. Monitor s5cmd performance                                  ║
║  2. Verify all uploads succeed                                 ║
║  3. Check logs for errors                                      ║
║  4. Validate checksums                                         ║
║  5. Keep AWS CLI as fallback                                   ║
║                                                                 ║
║  Phase 5: Completion (Day 15+)                                 ║
║  ──────────────────────────────                                 ║
║  1. Document final configuration                               ║
║  2. Archive AWS CLI logs/configs                               ║
║  3. Update runbooks                                            ║
║  4. Train team on s5cmd                                        ║
║                                                                 ║
╠════════════════════════════════════════════════════════════════╣
║                     ROLLBACK PLAN                               ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  If issues occur:                                              ║
║  1. Stop s5cmd uploads                                         ║
║  2. Restore AWS CLI configuration                              ║
║  3. Resume uploads with AWS CLI                                ║
║  4. Analyze logs to identify issues                            ║
║  5. Fix issues before retrying                                 ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝

EOF

    log_info "Migration plan generated."
    log_info "Estimated timeline: 2-3 weeks"
    log_info "Next step: ./migrate.sh --test"
}

# Test s5cmd
test_s5cmd() {
    log_step "Testing s5cmd"
    echo

    # Check if s5cmd is installed
    if ! command -v s5cmd &> /dev/null; then
        log_error "s5cmd not installed. Run: $PROJECT_ROOT/tools/install-s5cmd.sh"
        return 1
    fi

    # Create test config from AWS CLI config
    if [ -f "$SCRIPT_DIR/awscli-config.env" ]; then
        log_info "Creating s5cmd test config from AWS CLI config..."

        source "$SCRIPT_DIR/awscli-config.env"

        # Generate s5cmd config
        cat > "$SCRIPT_DIR/test-s5cmd-config.env" << EOF
# Auto-generated s5cmd test configuration
export AWS_PROFILE="$AWS_PROFILE"
export AWS_REGION="$AWS_REGION"
export BUCKET_NAME="$BUCKET_NAME"
export S3_SUBDIRECTORY="${S3_SUBDIRECTORY}-s5cmd-test"
export SOURCE_DIR="$SOURCE_DIR"
export S3_STORAGE_CLASS="$S3_STORAGE_CLASS"

# s5cmd performance settings
export S5CMD_CONCURRENCY="32"
export S5CMD_PART_SIZE="64MB"
export S5CMD_NUM_WORKERS="16"
export S5CMD_RETRY_COUNT="3"
export S5CMD_LOG_LEVEL="info"
export S5CMD_CHECKSUM_ALGORITHM="CRC64NVME"

# Logging
export ENABLE_LOGGING="true"
export LOG_DIR="./logs/s5cmd-test"
export ENABLE_JSON_OUTPUT="true"
export JSON_OUTPUT_DIR="./logs/s5cmd-test/json"
EOF

        log_success "Test config created: test-s5cmd-config.env"
    fi

    # Run dry-run
    log_info "Running s5cmd dry-run test..."
    source "$SCRIPT_DIR/test-s5cmd-config.env"
    mkdir -p "$LOG_DIR" "$JSON_OUTPUT_DIR"

    "$PROJECT_ROOT/scripts/datasync-s5cmd.sh" --dry-run

    log_success "Dry-run test completed successfully!"
    echo
    log_info "Review the output above to verify:"
    log_info "  • Correct bucket and prefix"
    log_info "  • Expected files are detected"
    log_info "  • No error messages"
    echo
    log_info "Next step: Run actual upload test"
    log_info "  source test-s5cmd-config.env"
    log_info "  $PROJECT_ROOT/scripts/datasync-s5cmd.sh"
}

# Perform migration
perform_migration() {
    log_step "Performing migration to s5cmd"
    echo

    log_warning "This will migrate from AWS CLI to s5cmd."
    log_info "Ensure you have:"
    log_info "  • Tested s5cmd successfully"
    log_info "  • Backed up AWS CLI configuration"
    log_info "  • Notified team members"
    echo
    read -p "Continue with migration? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Migration cancelled."
        return 0
    fi

    # Backup AWS CLI config
    if [ -f "$SCRIPT_DIR/awscli-config.env" ]; then
        local backup_file="$SCRIPT_DIR/awscli-config.env.backup-$(date +%Y%m%d)"
        cp "$SCRIPT_DIR/awscli-config.env" "$backup_file"
        log_success "AWS CLI config backed up to: $backup_file"
    fi

    # Convert AWS CLI config to s5cmd config
    if [ -f "$SCRIPT_DIR/awscli-config.env" ]; then
        source "$SCRIPT_DIR/awscli-config.env"

        # Determine optimal concurrency based on AWS CLI settings
        local aws_requests="${AWS_MAX_CONCURRENT_REQUESTS:-10}"
        local s5cmd_concurrency=$((aws_requests * 3))  # 3x AWS CLI concurrency

        cat > "$SCRIPT_DIR/s5cmd-config.env" << EOF
# Migrated from AWS CLI configuration on $(date -Iseconds)
# Original config backed up to: $backup_file

# AWS SETTINGS
export AWS_PROFILE="$AWS_PROFILE"
export AWS_REGION="$AWS_REGION"

# S3 SETTINGS
export BUCKET_NAME="$BUCKET_NAME"
export S3_SUBDIRECTORY="$S3_SUBDIRECTORY"
export S3_STORAGE_CLASS="$S3_STORAGE_CLASS"

# SOURCE SETTINGS
export SOURCE_DIR="$SOURCE_DIR"

# S5CMD PERFORMANCE SETTINGS (auto-tuned from AWS CLI settings)
export S5CMD_CONCURRENCY="$s5cmd_concurrency"
export S5CMD_PART_SIZE="${AWS_MULTIPART_CHUNKSIZE:-64MB}"
export S5CMD_NUM_WORKERS="$((s5cmd_concurrency / 2))"
export S5CMD_RETRY_COUNT="3"
export S5CMD_LOG_LEVEL="info"
export S5CMD_CHECKSUM_ALGORITHM="CRC64NVME"

# LOGGING
export ENABLE_LOGGING="${ENABLE_LOGGING:-true}"
export LOG_DIR="${LOG_DIR:-./logs/s5cmd}"
export ENABLE_JSON_OUTPUT="${ENABLE_JSON_OUTPUT:-true}"
export JSON_OUTPUT_DIR="${JSON_OUTPUT_DIR:-./logs/s5cmd/json}"
EOF

        log_success "Created s5cmd-config.env from AWS CLI configuration"
    fi

    # Create migration info file
    cat > "$SCRIPT_DIR/MIGRATION_INFO.txt" << EOF
DataSync Migration Information
==============================

Migration Date: $(date -Iseconds)

Original Tool: AWS CLI
New Tool: s5cmd

Configuration Backup: $backup_file
New Configuration: s5cmd-config.env

Rollback Instructions:
1. Stop s5cmd uploads
2. Restore AWS CLI config:
   cp $backup_file awscli-config.env
3. Resume uploads with AWS CLI

Performance Expectations:
- AWS CLI throughput: ~200-320 MB/s
- s5cmd throughput: ~800-1200 MB/s
- Expected improvement: 3-6x faster

Monitoring:
- Check logs in: \${LOG_DIR}
- Monitor performance for first week
- Keep AWS CLI config as backup

Support:
- See: $PROJECT_ROOT/docs/TROUBLESHOOTING.md
- Rollback command: ./migrate.sh --rollback
EOF

    log_success "Migration complete!"
    echo
    log_info "Migration information saved to: MIGRATION_INFO.txt"
    echo
    log_info "Next steps:"
    log_info "  1. Test upload: source s5cmd-config.env && $PROJECT_ROOT/scripts/datasync-s5cmd.sh"
    log_info "  2. Monitor performance for 1 week"
    log_info "  3. Keep AWS CLI config as backup"
    echo
    log_warning "Rollback available if needed: ./migrate.sh --rollback"
}

# Rollback to AWS CLI
rollback_migration() {
    log_step "Rolling back to AWS CLI"
    echo

    log_warning "This will rollback to AWS CLI configuration."
    read -p "Continue with rollback? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Rollback cancelled."
        return 0
    fi

    # Find backup
    local backup_file=$(ls -t "$SCRIPT_DIR"/awscli-config.env.backup-* 2>/dev/null | head -1)

    if [ -z "$backup_file" ]; then
        log_error "No AWS CLI backup found!"
        log_info "Cannot rollback without backup."
        return 1
    fi

    log_info "Found backup: $backup_file"

    # Restore backup
    cp "$backup_file" "$SCRIPT_DIR/awscli-config.env"

    log_success "AWS CLI configuration restored"
    echo
    log_info "Rollback complete. You can now use AWS CLI:"
    log_info "  source awscli-config.env"
    log_info "  $PROJECT_ROOT/scripts/datasync-awscli.sh"
}

# ============================================================================
# Main
# ============================================================================

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    --check)
        check_setup
        ;;
    --plan)
        generate_plan
        ;;
    --test)
        test_s5cmd
        ;;
    --migrate)
        perform_migration
        ;;
    --rollback)
        rollback_migration
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
