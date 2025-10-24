#!/bin/bash
#
# sync-now.sh - Quick wrapper for S3 uploads
#
# Automatically detects which tool to use (s5cmd or AWS CLI) and
# uploads to S3 with optimal settings.
#
# Usage:
#   ./sync-now.sh [OPTIONS]
#
# Options:
#   --tool s5cmd|awscli    Force specific tool (default: auto-detect)
#   --dry-run              Preview without uploading
#   --help                 Show this help message
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOOL=""
DRY_RUN_FLAG=""

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Quick wrapper for S3 uploads - automatically selects best tool

Options:
    --tool s5cmd|awscli    Force specific tool (default: auto-detect)
    --dry-run              Preview without uploading
    --help                 Show this help message

Auto-detection:
    1. Checks if s5cmd is installed
    2. Uses s5cmd if available (5-12x faster)
    3. Falls back to AWS CLI if s5cmd not found

Examples:
    # Auto-detect and upload
    $0

    # Force s5cmd
    $0 --tool s5cmd

    # Dry run with AWS CLI
    $0 --tool awscli --dry-run

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --tool)
            TOOL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN_FLAG="--dry-run"
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${YELLOW}[WARN]${NC} Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Auto-detect tool if not specified
if [ -z "$TOOL" ]; then
    echo -e "${BLUE}[INFO]${NC} Auto-detecting best tool..."

    if command -v s5cmd &> /dev/null; then
        TOOL="s5cmd"
        echo -e "${GREEN}[SUCCESS]${NC} s5cmd detected - using high-performance mode"
    elif command -v aws &> /dev/null; then
        TOOL="awscli"
        echo -e "${YELLOW}[WARN]${NC} s5cmd not found - falling back to AWS CLI"
        echo -e "${BLUE}[INFO]${NC} Install s5cmd for 5-12x faster uploads: ./tools/install-s5cmd.sh"
    else
        echo -e "${YELLOW}[ERROR]${NC} No upload tool found!"
        echo -e "${BLUE}[INFO]${NC} Install s5cmd: ./tools/install-s5cmd.sh"
        echo -e "${BLUE}[INFO]${NC} Or install AWS CLI: apt install awscli"
        exit 1
    fi
    echo ""
fi

# Validate tool selection
case "$TOOL" in
    s5cmd)
        if ! command -v s5cmd &> /dev/null; then
            echo -e "${YELLOW}[ERROR]${NC} s5cmd not found but was requested"
            echo -e "${BLUE}[INFO]${NC} Install with: ./tools/install-s5cmd.sh"
            exit 1
        fi
        SCRIPT="${SCRIPT_DIR}/datasync-s5cmd.sh"
        ;;
    awscli)
        if ! command -v aws &> /dev/null; then
            echo -e "${YELLOW}[ERROR]${NC} AWS CLI not found but was requested"
            echo -e "${BLUE}[INFO]${NC} Install with: apt install awscli"
            exit 1
        fi
        SCRIPT="${SCRIPT_DIR}/datasync-awscli.sh"
        ;;
    *)
        echo -e "${YELLOW}[ERROR]${NC} Invalid tool: $TOOL"
        echo -e "${BLUE}[INFO]${NC} Valid options: s5cmd, awscli"
        exit 1
        ;;
esac

# Run the selected script
echo -e "${BLUE}[INFO]${NC} Using: $TOOL"
echo -e "${BLUE}[INFO]${NC} Script: $SCRIPT"
echo ""

exec "$SCRIPT" $DRY_RUN_FLAG
