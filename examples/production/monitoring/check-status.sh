#!/bin/bash
#
# DataSync Turbo Tools - Status Check Script
# Monitor upload health and performance
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory and load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.env"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Defaults
LOG_DIR="${LOG_DIR:-/var/log/datasync-turbo}"
HEALTH_CHECK_FILE="${HEALTH_CHECK_FILE:-/var/run/datasync-turbo/last-sync}"
MIN_THROUGHPUT_MBPS="${MIN_THROUGHPUT_MBPS:-500}"
MAX_SYNC_TIME="${MAX_SYNC_TIME:-600}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# Status Checks
# ============================================================================

echo "DataSync Turbo Tools - Status Check"
echo "===================================="
echo

# Check if s5cmd is installed
if command -v s5cmd &> /dev/null; then
    log_success "s5cmd installed: $(s5cmd version | head -1)"
else
    log_error "s5cmd not installed"
fi

# Check last sync time
if [ -f "$HEALTH_CHECK_FILE" ]; then
    last_sync=$(cat "$HEALTH_CHECK_FILE")
    last_sync_timestamp=$(date -d "$last_sync" +%s 2>/dev/null || echo 0)
    current_timestamp=$(date +%s)
    age_seconds=$((current_timestamp - last_sync_timestamp))
    age_minutes=$((age_seconds / 60))

    if [ $age_minutes -lt 60 ]; then
        log_success "Last sync: $age_minutes minutes ago"
    elif [ $age_minutes -lt 1440 ]; then
        log_warning "Last sync: $((age_minutes / 60)) hours ago"
    else
        log_error "Last sync: $((age_minutes / 1440)) days ago"
    fi
else
    log_warning "No sync history found"
fi

# Check recent logs
if [ -d "$LOG_DIR" ]; then
    latest_log=$(find "$LOG_DIR" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [ -n "$latest_log" ]; then
        log_info "Latest log: $latest_log"

        # Check for recent errors
        error_count=$(grep -c "ERROR" "$latest_log" 2>/dev/null || echo 0)
        if [ "$error_count" -gt 0 ]; then
            log_error "Found $error_count error(s) in latest log"
        else
            log_success "No errors in latest log"
        fi

        # Check last sync performance
        if [ -f "$LOG_DIR/json/latest.json" ]; then
            throughput=$(jq -r '.throughput_mbps // 0' "$LOG_DIR/json/latest.json" 2>/dev/null || echo 0)
            duration=$(jq -r '.duration_seconds // 0' "$LOG_DIR/json/latest.json" 2>/dev/null || echo 0)

            if [ "$throughput" != "0" ]; then
                if (( $(echo "$throughput < $MIN_THROUGHPUT_MBPS" | bc -l) )); then
                    log_warning "Throughput: ${throughput} MB/s (below threshold: $MIN_THROUGHPUT_MBPS MB/s)"
                else
                    log_success "Throughput: ${throughput} MB/s"
                fi
            fi

            if [ "$duration" != "0" ]; then
                if [ "$duration" -gt "$MAX_SYNC_TIME" ]; then
                    log_warning "Duration: ${duration}s (exceeds threshold: $MAX_SYNC_TIME s)"
                else
                    log_success "Duration: ${duration}s"
                fi
            fi
        fi
    else
        log_warning "No log files found"
    fi
else
    log_warning "Log directory not found: $LOG_DIR"
fi

# Check disk space
if [ -n "${SOURCE_DIR:-}" ] && [ -d "$SOURCE_DIR" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use -g flag (lowercase)
        free_space=$(df -g "$SOURCE_DIR" | awk 'NR==2 {print $4}')
    else
        # Linux: use -BG flag
        free_space=$(df -BG "$SOURCE_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    fi
    if [ "$free_space" -lt "${MIN_FREE_DISK_SPACE_GB:-10}" ]; then
        log_error "Low disk space: ${free_space}GB (minimum: ${MIN_FREE_DISK_SPACE_GB:-10}GB)"
    else
        log_success "Disk space: ${free_space}GB available"
    fi
fi

# Check AWS credentials
if [ -n "${AWS_PROFILE:-}" ]; then
    if aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        log_success "AWS credentials valid"
    else
        log_error "AWS credentials expired or invalid"
    fi
fi

echo
echo "Status check complete"
