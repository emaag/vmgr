#!/usr/bin/env bash
# Unit tests for lib/core.sh:
#   toggle_flag, toggle_flag_with_log, reset_statistics

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core

# ── toggle_flag ───────────────────────────────────────────────────────────────

test_toggle_false_to_true() {
    local MY_FLAG=false
    toggle_flag MY_FLAG
    assert_equals "true" "$MY_FLAG" "toggle_flag: false → true"
}

test_toggle_true_to_false() {
    local MY_FLAG=true
    toggle_flag MY_FLAG
    assert_equals "false" "$MY_FLAG" "toggle_flag: true → false"
}

test_toggle_roundtrip() {
    local MY_FLAG=false
    toggle_flag MY_FLAG
    toggle_flag MY_FLAG
    assert_equals "false" "$MY_FLAG" "toggle_flag: two toggles → original"
}

test_toggle_dry_run() {
    DRY_RUN=false
    toggle_flag DRY_RUN
    assert_equals "true" "$DRY_RUN" "toggle_flag: DRY_RUN false → true"
    DRY_RUN=false  # restore
}

test_toggle_verbose() {
    VERBOSE=true
    toggle_flag VERBOSE
    assert_equals "false" "$VERBOSE" "toggle_flag: VERBOSE true → false"
    VERBOSE=false  # restore
}

# ── toggle_flag_with_log ──────────────────────────────────────────────────────

test_toggle_with_log_changes_value() {
    local MY_VAR=false
    toggle_flag_with_log MY_VAR "Test flag" 2>/dev/null
    assert_equals "true" "$MY_VAR" "toggle_flag_with_log: value changed"
}

test_toggle_with_log_does_not_error() {
    local MY_VAR=true
    assert_exits_zero "toggle_flag_with_log MY_VAR 'Test flag' 2>/dev/null" \
        "toggle_flag_with_log: exits zero"
}

# ── reset_statistics ──────────────────────────────────────────────────────────

test_reset_files_processed() {
    STATS[files_processed]=99
    reset_statistics
    assert_equals "0" "${STATS[files_processed]}" "reset_stats: files_processed → 0"
}

test_reset_files_renamed() {
    STATS[files_renamed]=42
    reset_statistics
    assert_equals "0" "${STATS[files_renamed]}" "reset_stats: files_renamed → 0"
}

test_reset_errors() {
    STATS[errors]=5
    reset_statistics
    assert_equals "0" "${STATS[errors]}" "reset_stats: errors → 0"
}

test_reset_duplicates_found() {
    STATS[duplicates_found]=7
    reset_statistics
    assert_equals "0" "${STATS[duplicates_found]}" "reset_stats: duplicates_found → 0"
}

test_reset_space_saved() {
    STATS[space_saved]=999999
    reset_statistics
    assert_equals "0" "${STATS[space_saved]}" "reset_stats: space_saved → 0"
}

test_reset_all_zeroes_after_increment() {
    STATS[files_processed]=1
    STATS[files_renamed]=2
    STATS[files_moved]=3
    STATS[files_skipped]=4
    STATS[errors]=5
    reset_statistics
    local sum=$(( STATS[files_processed] + STATS[files_renamed] + STATS[files_moved] +
                  STATS[files_skipped] + STATS[errors] ))
    assert_equals "0" "$sum" "reset_stats: all counters zeroed"
}

# ── init_core directory creation ──────────────────────────────────────────────

test_init_core_creates_log_dir() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    LOG_DIR="$tmpdir/logs"
    UNDO_LOG_DIR="$tmpdir/undo"
    BACKUP_DIR="$tmpdir/backups"
    LOG_FILE="$tmpdir/logs/test.log"
    init_core
    assert_file_exists "$tmpdir/logs" "init_core: LOG_DIR created"
    assert_file_exists "$tmpdir/undo" "init_core: UNDO_LOG_DIR created"
    assert_file_exists "$tmpdir/backups" "init_core: BACKUP_DIR created"
    rm -rf "$tmpdir"
    # Restore
    LOG_DIR=/dev/null
    UNDO_LOG_DIR=/dev/null
    BACKUP_DIR="$HOME/.video-manager-backups"
}
