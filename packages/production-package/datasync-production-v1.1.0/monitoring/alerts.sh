#!/bin/bash
#
# DataSync Turbo Tools - Alert Script
# Send alerts on upload failures or performance issues
#

set -euo pipefail

# Get script directory and load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.env"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Defaults
LOG_DIR="${LOG_DIR:-/var/log/datasync-turbo}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
NOTIFICATION_METHOD="${NOTIFICATION_METHOD:-log}"

# ============================================================================
# Alert Functions
# ============================================================================

send_log_alert() {
    local level="$1"
    local message="$2"
    echo "[$(date -Iseconds)] [$level] $message" >> "$LOG_DIR/alerts.log"
}

send_email_alert() {
    local subject="$1"
    local message="$2"

    if [ -z "$ALERT_EMAIL" ]; then
        return
    fi

    if command -v sendmail &> /dev/null; then
        echo -e "Subject: $subject\n\n$message" | sendmail "$ALERT_EMAIL"
    elif command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
    fi
}

send_webhook_alert() {
    local message="$1"
    local color="$2"  # success: green (#36a64f), warning: yellow (#ffcc00), error: red (#ff0000)

    if [ -z "$ALERT_WEBHOOK_URL" ]; then
        return
    fi

    local payload=$(cat << EOF
{
    "attachments": [{
        "color": "$color",
        "title": "DataSync Turbo Tools Alert",
        "text": "$message",
        "footer": "DataSync Turbo Tools",
        "ts": $(date +%s)
    }]
}
EOF
)

    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        "$ALERT_WEBHOOK_URL" 2>/dev/null || true
}

send_alert() {
    local level="$1"  # success|warning|error
    local message="$2"

    local color="#36a64f"  # green
    if [ "$level" = "warning" ]; then
        color="#ffcc00"  # yellow
    elif [ "$level" = "error" ]; then
        color="#ff0000"  # red
    fi

    case "$NOTIFICATION_METHOD" in
        log)
            send_log_alert "$level" "$message"
            ;;
        email)
            send_email_alert "DataSync Alert: $level" "$message"
            ;;
        webhook)
            send_webhook_alert "$message" "$color"
            ;;
        all)
            send_log_alert "$level" "$message"
            send_email_alert "DataSync Alert: $level" "$message"
            send_webhook_alert "$message" "$color"
            ;;
    esac
}

# ============================================================================
# Check Functions
# ============================================================================

check_upload_failure() {
    # Check if latest sync failed
    local latest_json="$LOG_DIR/json/latest.json"

    if [ ! -f "$latest_json" ]; then
        return
    fi

    local status=$(jq -r '.status // "unknown"' "$latest_json" 2>/dev/null || echo "unknown")

    if [ "$status" = "failed" ] || [ "$status" = "error" ]; then
        local error_msg=$(jq -r '.error // "Unknown error"' "$latest_json" 2>/dev/null || echo "Unknown error")
        send_alert "error" "Upload failed: $error_msg"
    fi
}

check_low_throughput() {
    local latest_json="$LOG_DIR/json/latest.json"
    local min_throughput="${MIN_THROUGHPUT_MBPS:-500}"

    if [ ! -f "$latest_json" ]; then
        return
    fi

    local throughput=$(jq -r '.throughput_mbps // 0' "$latest_json" 2>/dev/null || echo 0)

    if (( $(echo "$throughput > 0 && $throughput < $min_throughput" | bc -l) )); then
        send_alert "warning" "Low throughput detected: ${throughput} MB/s (threshold: $min_throughput MB/s)"
    fi
}

check_long_sync_time() {
    local latest_json="$LOG_DIR/json/latest.json"
    local max_time="${MAX_SYNC_TIME:-600}"

    if [ ! -f "$latest_json" ]; then
        return
    fi

    local duration=$(jq -r '.duration_seconds // 0' "$latest_json" 2>/dev/null || echo 0)

    if [ "$duration" -gt "$max_time" ]; then
        send_alert "warning" "Sync took too long: ${duration}s (threshold: $max_time s)"
    fi
}

check_disk_space() {
    local min_space="${MIN_FREE_DISK_SPACE_GB:-10}"

    if [ -z "${SOURCE_DIR:-}" ] || [ ! -d "$SOURCE_DIR" ]; then
        return
    fi

    local free_space=$(df -BG "$SOURCE_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')

    if [ "$free_space" -lt "$min_space" ]; then
        send_alert "error" "Low disk space: ${free_space}GB (minimum: $min_space GB)"
    fi
}

check_stale_sync() {
    local health_file="${HEALTH_CHECK_FILE:-/var/run/datasync-turbo/last-sync}"
    local max_age_hours="${MAX_SYNC_AGE_HOURS:-24}"

    if [ ! -f "$health_file" ]; then
        send_alert "warning" "No sync history found"
        return
    fi

    local last_sync=$(cat "$health_file")
    local last_sync_timestamp=$(date -d "$last_sync" +%s 2>/dev/null || echo 0)
    local current_timestamp=$(date +%s)
    local age_hours=$(( (current_timestamp - last_sync_timestamp) / 3600 ))

    if [ $age_hours -gt $max_age_hours ]; then
        send_alert "warning" "No successful sync in $age_hours hours (last sync: $last_sync)"
    fi
}

# ============================================================================
# Main
# ============================================================================

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Run all checks
check_upload_failure
check_low_throughput
check_long_sync_time
check_disk_space
check_stale_sync

# Send success notification if configured
if [ "${NOTIFY_ON_SUCCESS:-false}" = "true" ]; then
    if [ -f "$LOG_DIR/json/latest.json" ]; then
        local status=$(jq -r '.status // "unknown"' "$LOG_DIR/json/latest.json" 2>/dev/null || echo "unknown")
        if [ "$status" = "success" ]; then
            local throughput=$(jq -r '.throughput_mbps // 0' "$LOG_DIR/json/latest.json")
            local duration=$(jq -r '.duration_seconds // 0' "$LOG_DIR/json/latest.json")
            send_alert "success" "Upload completed successfully (${throughput} MB/s in ${duration}s)"
        fi
    fi
fi
