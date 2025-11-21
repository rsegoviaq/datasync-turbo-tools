# Byte-Based Progress Tracking - Implementation Plan

## Overview

**Feature**: Byte-Based Progress Tracking and Per-File Upload Indicators
**Issue**: User request - Progress tracking improvements
**Status**: In Progress
**Branch**: `feature/byte-based-progress-tracking`
**Goal**: Provide accurate progress tracking based on bytes uploaded (not file count) and show real-time progress for individual files during long uploads

## Current State Analysis

### What's Working
- Basic progress tracking exists
- File count-based progress display
- Overall upload speed calculation
- ETA estimation
- JSON metrics logging

### What's Not Working / Missing

#### Issue 1: Progress is File-Count Based, Not Byte-Based
**Location**: `scripts/datasync-s5cmd.sh:502-558`

**Current Behavior**:
- Progress calculated as: `percent = (files_uploaded * 100 / total_files)`
- Bytes uploaded are **estimated** from file count: `bytes_uploaded = count * BYTES_TRANSFERRED / TOTAL_FILES_TO_UPLOAD`
- This assumes all files are the same size

**Problem**:
- If you have 99 files @ 1KB and 1 file @ 10GB, progress shows 99% when only ~1% of data is transferred
- Upload speed and ETA are based on estimated bytes, not actual bytes

**Impact**: Misleading progress indicators, especially with mixed file sizes

#### Issue 2: No Per-File Progress During Upload
**Location**: `scripts/datasync-s5cmd.sh:508-510`

**Current Behavior**:
- Only detects file completion: `if [[ "$line" =~ ^cp[[:space:]] ]] || [[ "$line" =~ uploaded ]]; then`
- No tracking of in-progress uploads

**Problem**:
- During upload of a single large file (e.g., 50GB), there's no indication of progress
- User cannot tell if upload is stalled or progressing

**Impact**: Poor user experience during large file uploads, no way to monitor progress

#### Issue 3: Long Gaps Without Updates
**Location**: `scripts/datasync-s5cmd.sh:523-525`

**Current Behavior**:
- Updates every 10 files OR 5% progress
- No time-based updates

**Problem**:
- With few large files, long periods with no visible progress
- Example: 5 large files = updates only at 20%, 40%, 60%, 80%, 100%

**Impact**: Uncertainty whether upload is progressing or stuck

## Implementation Plan

### Phase 1: Byte-Based Progress Tracking

#### 1.1 Track Actual Bytes Uploaded
**File**: `scripts/datasync-s5cmd.sh` (lines 502-558)

**Changes**:
1. Add variable to track actual bytes uploaded:
   ```bash
   actual_bytes_uploaded=0
   ```

2. When file completes, parse file path from s5cmd output:
   ```bash
   if [[ "$line" =~ ^cp[[:space:]](.+)[[:space:]]s3:// ]]; then
       local_file="${BASH_REMATCH[1]}"
   fi
   ```

3. Get actual file size using `stat`:
   ```bash
   if [[ -f "$local_file" ]]; then
       if [[ "$OSTYPE" == "darwin"* ]]; then
           file_size=$(stat -f%z "$local_file" 2>/dev/null || echo "0")
       else
           file_size=$(stat -c%s "$local_file" 2>/dev/null || echo "0")
       fi
       actual_bytes_uploaded=$((actual_bytes_uploaded + file_size))
   fi
   ```

4. Calculate byte-based progress percentage:
   ```bash
   if [[ $BYTES_TRANSFERRED -gt 0 ]]; then
       bytes_percent=$((actual_bytes_uploaded * 100 / BYTES_TRANSFERRED))
   fi
   ```

5. Keep file-count percentage for comparison:
   ```bash
   files_percent=$((files_uploaded * 100 / total_files))
   ```

#### 1.2 Update Progress Display Function
**File**: `scripts/datasync-s5cmd.sh` (lines 92-138: `show_upload_progress()`)

**Changes**:
1. Add parameters for byte-based metrics:
   ```bash
   show_upload_progress() {
       local files_uploaded=$1
       local total_files=$2
       local actual_bytes_uploaded=$3  # NEW
       local total_bytes=$4
       local start_time=$5
   }
   ```

2. Calculate both percentages:
   ```bash
   local files_percent=$((files_uploaded * 100 / total_files))
   local bytes_percent=$((actual_bytes_uploaded * 100 / total_bytes))
   ```

3. Format human-readable byte progress:
   ```bash
   local bytes_gb=$(awk "BEGIN {printf \"%.2f\", $actual_bytes_uploaded/1073741824}")
   local total_gb=$(awk "BEGIN {printf \"%.2f\", $total_bytes/1073741824}")
   ```

4. Update display format:
   ```bash
   printf "\r${BLUE}Progress:${NC} %d/%d files ${GREEN}(%.1f%% by size, %.1f%% by count)${NC} | %sGB/%sGB | Speed: %.2f MB/s | ETA: %s" \
       "$files_uploaded" "$total_files" "$bytes_percent" "$files_percent" \
       "$bytes_gb" "$total_gb" "$speed_mbps" "$eta_formatted"
   ```

**Expected Output**:
```
Progress: 123/500 files (45.2% by size, 24.6% by count) | 2.5GB/5.5GB | Speed: 125 MB/s | ETA: 24s
```

#### 1.3 Update Progress Calculation in Upload Loop
**File**: `scripts/datasync-s5cmd.sh` (lines 502-558)

**Changes**:
1. Update call to `show_upload_progress()` with actual bytes:
   ```bash
   show_upload_progress "$count" "$TOTAL_FILES_TO_UPLOAD" "$actual_bytes_uploaded" "$BYTES_TRANSFERRED" "$START_TIME"
   ```

2. Update frequency based on bytes:
   ```bash
   # Show progress every 5 seconds OR 2% of bytes
   local bytes_percent_change=$((actual_bytes_uploaded * 100 / BYTES_TRANSFERRED - last_bytes_percent))
   local time_since_last=$((SECONDS - last_update_time))

   if [[ $bytes_percent_change -ge 2 ]] || [[ $time_since_last -ge 5 ]]; then
       show_upload_progress ...
       last_bytes_percent=$bytes_percent
       last_update_time=$SECONDS
   fi
   ```

### Phase 2: Per-File Upload Progress

#### 2.1 Add Background Progress Monitor Function
**File**: `scripts/datasync-s5cmd.sh` (new function after `show_upload_progress()`)

**New Function**:
```bash
# Monitor current file upload progress
# This function runs in background and periodically checks file upload progress
monitor_current_file_progress() {
    local s3_bucket=$1
    local s3_prefix=$2
    local check_interval=5  # Check every 5 seconds

    while true; do
        sleep $check_interval

        # Find the most recently accessed file (being uploaded)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            current_file=$(find "$SOURCE_DIR" -type f -exec stat -f "%a %N" {} \; | sort -rn | head -1 | cut -d' ' -f2-)
        else
            current_file=$(find "$SOURCE_DIR" -type f -printf "%A@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)
        fi

        if [[ -n "$current_file" ]]; then
            local file_name=$(basename "$current_file")
            local file_size=$(stat -c%s "$current_file" 2>/dev/null || stat -f%z "$current_file" 2>/dev/null)

            # Check S3 for partial upload size
            local s3_path="s3://${s3_bucket}/${s3_prefix}${file_name}"
            local s3_size=$(aws s3 ls "$s3_path" 2>/dev/null | awk '{print $3}' || echo "0")

            if [[ $s3_size -gt 0 ]] && [[ $file_size -gt 0 ]]; then
                local file_percent=$((s3_size * 100 / file_size))
                local size_mb=$(awk "BEGIN {printf \"%.2f\", $s3_size/1048576}")
                local total_mb=$(awk "BEGIN {printf \"%.2f\", $file_size/1048576}")

                printf "\r${CYAN}Current:${NC} %s ${YELLOW}(%sMB/%sMB - %.1f%%)${NC}" \
                    "$file_name" "$size_mb" "$total_mb" "$file_percent"
            fi
        fi
    done
}
```

#### 2.2 Launch Background Monitor
**File**: `scripts/datasync-s5cmd.sh` (in upload section, before s5cmd execution)

**Changes**:
```bash
# Start background progress monitor for per-file tracking
monitor_current_file_progress "$BUCKET_NAME" "$S3_PREFIX" &
MONITOR_PID=$!

# Ensure monitor is killed on script exit
trap "kill $MONITOR_PID 2>/dev/null" EXIT
```

### Phase 3: Enhanced JSON Logging

#### 3.1 Add Progress History Tracking
**File**: `scripts/datasync-s5cmd.sh` (global variables section)

**Changes**:
1. Add array to track progress snapshots:
   ```bash
   declare -a PROGRESS_HISTORY=()
   ```

2. In upload loop, capture periodic snapshots:
   ```bash
   # Every 5% progress, save snapshot
   if [[ $((bytes_percent / 5)) -gt $((last_snapshot_percent / 5)) ]]; then
       timestamp=$(date +%s)
       PROGRESS_HISTORY+=("{\"time\":$timestamp,\"bytes\":$actual_bytes_uploaded,\"files\":$count,\"percent\":$bytes_percent}")
       last_snapshot_percent=$bytes_percent
   fi
   ```

#### 3.2 Update JSON Output Function
**File**: `scripts/datasync-s5cmd.sh` (lines 585-653: `generate_json_output()`)

**Changes**:
1. Add progress_history field:
   ```bash
   "progress_history": [
       ${PROGRESS_HISTORY[@]}
   ],
   ```

2. Add byte-based metrics:
   ```bash
   "actual_bytes_transferred": $ACTUAL_BYTES_UPLOADED,
   "estimated_bytes_transferred": $BYTES_TRANSFERRED,
   "progress_accuracy": "$((ACTUAL_BYTES_UPLOADED * 100 / BYTES_TRANSFERRED))%",
   ```

**Expected JSON**:
```json
{
    "timestamp": "2025-11-21T12:34:56Z",
    "files_synced": 500,
    "actual_bytes_transferred": 5368709120,
    "estimated_bytes_transferred": 5500000000,
    "progress_accuracy": "97%",
    "progress_history": [
        {"time": 1700000000, "bytes": 268435456, "files": 25, "percent": 5},
        {"time": 1700000030, "bytes": 536870912, "files": 50, "percent": 10}
    ],
    "throughput_mbps": 125.5,
    "duration_seconds": 245
}
```

## Testing Plan

### Test Scenarios

#### Test 1: Many Small Files
**Purpose**: Verify byte-based progress accuracy with uniform file sizes

**Setup**:
```bash
# Create 1000 files of 1MB each
mkdir -p test-data/small-files
for i in {1..1000}; do
    dd if=/dev/urandom of=test-data/small-files/file_$i.dat bs=1M count=1 2>/dev/null
done
```

**Expected**:
- File-count percentage ≈ Byte-based percentage
- Both should progress together
- Regular updates every ~20 files (2% of 1000)

#### Test 2: Few Large Files
**Purpose**: Verify per-file progress tracking during long uploads

**Setup**:
```bash
# Create 5 files of 1GB each
mkdir -p test-data/large-files
for i in {1..5}; do
    dd if=/dev/urandom of=test-data/large-files/large_$i.dat bs=1M count=1024 2>/dev/null
done
```

**Expected**:
- Per-file progress shown during each 1GB upload
- Updates every 5 seconds
- Byte-based progress more accurate than file-count

#### Test 3: Mixed File Sizes
**Purpose**: Verify accuracy with highly variable file sizes

**Setup**:
```bash
# Create mixed: 99 small (1MB) + 1 large (10GB)
mkdir -p test-data/mixed-files
for i in {1..99}; do
    dd if=/dev/urandom of=test-data/mixed-files/small_$i.dat bs=1M count=1 2>/dev/null
done
dd if=/dev/urandom of=test-data/mixed-files/huge.dat bs=1M count=10240 2>/dev/null
```

**Expected**:
- File-count shows 99% after small files (misleading)
- Byte-based shows ~9% after small files (accurate)
- Per-file progress shown during 10GB file upload
- Large discrepancy between file-count % and byte %

#### Test 4: Dry Run Validation
**Purpose**: Ensure changes don't break dry-run mode

**Command**:
```bash
source config/s5cmd.env
./scripts/datasync-s5cmd.sh --dry-run
```

**Expected**:
- No errors
- Progress display works correctly
- JSON output generated

#### Test 5: JSON Log Validation
**Purpose**: Verify JSON output is well-formed and contains new fields

**Command**:
```bash
# After upload completes
cat logs/datasync-s5cmd-*.json | jq .
```

**Expected**:
- Valid JSON structure
- Contains `actual_bytes_transferred`, `progress_history` fields
- Progress history array has multiple snapshots

## Files to Modify

1. ✏️ `scripts/datasync-s5cmd.sh` - Core upload script
   - Lines 92-138: Update `show_upload_progress()` function
   - After line 138: Add `monitor_current_file_progress()` function
   - Lines 502-558: Update upload loop with byte tracking
   - Lines 585-653: Update `generate_json_output()` with new fields

2. ✏️ `CHANGELOG.md` - Version history
   - Add version 1.4.0 entry with new features

3. ✏️ `docs/S5CMD_GUIDE.md` - User documentation
   - Update progress tracking section
   - Add examples of new progress display format

4. ✏️ `docs/features/byte-based-progress-tracking/IMPLEMENTATION_PLAN.md` - This file
   - Update status to "Completed" when done

## Git Workflow

### Branch Strategy
```bash
# Create feature branch (DONE)
git checkout -b feature/byte-based-progress-tracking

# Make changes incrementally
git add scripts/datasync-s5cmd.sh
git commit -m "feat: add byte-based progress tracking"

git add scripts/datasync-s5cmd.sh
git commit -m "feat: add per-file upload progress monitoring"

git add scripts/datasync-s5cmd.sh
git commit -m "feat: enhance JSON logging with progress history"

# Update documentation
git add CHANGELOG.md docs/
git commit -m "docs: update documentation for byte-based progress tracking"

# Push feature branch
git push -u origin feature/byte-based-progress-tracking
```

### Merge Strategy
```bash
# After testing and validation
git checkout master
git merge feature/byte-based-progress-tracking
git push origin master

# Tag new version
git tag -a v1.4.0 -m "Version 1.4.0: Byte-based progress tracking"
git push origin v1.4.0
```

## Success Criteria

- [ ] Byte-based progress percentage calculated from actual file sizes
- [ ] Progress display shows both byte-based and file-count percentages
- [ ] Human-readable byte progress (e.g., "2.5GB/5.5GB")
- [ ] Per-file progress shown during large file uploads
- [ ] Progress updates occur every 5 seconds OR 2% progress
- [ ] Background monitor tracks current file upload
- [ ] JSON logs include `actual_bytes_transferred` field
- [ ] JSON logs include `progress_history` array
- [ ] All test scenarios pass
- [ ] Dry-run mode works correctly
- [ ] JSON output validates with `jq`
- [ ] Documentation updated (CHANGELOG, S5CMD_GUIDE)
- [ ] Cross-platform compatibility (Linux, macOS, WSL2)
- [ ] No performance degradation
- [ ] Code follows bash best practices from DEVELOPMENT.md

## Implementation Notes

### Cross-Platform Considerations
- Use `$OSTYPE` detection for platform-specific commands
- macOS: `stat -f%z` for file size, `stat -f "%a %N"` for access time
- Linux: `stat -c%s` for file size, `find -printf` for access time

### Performance Considerations
- `stat` calls add minimal overhead (~1ms per file)
- Background monitor runs in separate process (no blocking)
- Progress history limited to 5% intervals (max 20 entries)
- No impact on s5cmd performance

### Error Handling
- Handle missing files gracefully (file deleted during upload)
- Handle `stat` failures (return 0 size)
- Kill background monitor on script exit
- Validate division by zero (bytes_transferred > 0)

---

**Last Updated:** 2025-11-21
**Document Version:** 1.0
**Status:** In Progress
