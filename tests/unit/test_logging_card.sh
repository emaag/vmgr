#!/usr/bin/env bash
# Unit tests for the themed operation banner and summary card in lib/logging.sh:
#   start_operation, end_operation, show_progress

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "theme.sh"
# load_vmgr_core stubs the logging functions; bring the real ones back
source "$LIB_DIR/logging.sh"
LOG_FILE=/dev/null

_strip() { sed 's/\x1b\[[0-9;]*m//g'; }

test_end_operation_lists_nonzero_stats_only() {
    COLUMNS=100
    reset_statistics 2>/dev/null
    STATS[files_processed]=5; STATS[files_renamed]=3; STATS[files_skipped]=2
    CURRENT_OPERATION="Rename Files"; START_TIME=$(date +%s)
    local out; out="$(end_operation 2>&1 | _strip)"
    assert_contains "Complete" "$out" "end_operation: card title"
    assert_contains "Files renamed" "$out" "end_operation: non-zero stat shown"
    [[ "$out" != *"Files moved"* ]]; assert_equals "0" "$?" "end_operation: zero stat hidden"
}

test_end_operation_flags_errors() {
    COLUMNS=100
    reset_statistics 2>/dev/null
    STATS[errors]=3
    CURRENT_OPERATION="Op"; START_TIME=$(date +%s)
    assert_contains "Done with 3 error(s)" "$(end_operation 2>&1 | _strip)" "end_operation: errors in the title"
}

test_end_operation_shows_space_saved_in_mb() {
    COLUMNS=100
    reset_statistics 2>/dev/null
    STATS[duplicates_found]=2; STATS[space_saved]=$(( 5 * 1024 * 1024 ))
    CURRENT_OPERATION="Dupes"; START_TIME=$(date +%s)
    assert_contains "MiB" "$(end_operation 2>&1 | _strip)" "end_operation: space saved shown with a unit"
}

test_start_operation_prints_name() {
    DRY_RUN=false
    assert_contains "Rename Files" "$(start_operation "Rename Files" 2>&1 | _strip)" "start_operation: prints the operation name"
}

test_show_progress_completes_with_newline_on_tty_only() {
    local out; out="$(show_progress 10 10 "Working")"
    assert_equals "" "$out" "show_progress: silent when not on a terminal"
}

test_start_operation_resets_statistics() {
    STATS[files_processed]=9; STATS[errors]=2
    DRY_RUN=false
    start_operation "Fresh" >/dev/null 2>&1
    assert_equals "0:0" "${STATS[files_processed]}:${STATS[errors]}" "start_operation: each operation starts from zero"
}

test_dry_run_card_title() {
    COLUMNS=100
    reset_statistics
    CURRENT_OPERATION="Op"; START_TIME=$(date +%s)
    assert_contains "Dry run complete" "$(DRY_RUN=true end_operation 2>&1 | _strip)" "end_operation: dry runs say so in the title"
}

test_messages_wipe_a_live_progress_line() {
    local flag
    UI_PROGRESS_ACTIVE=1
    log_info "hello" >/dev/null 2>&1
    assert_equals "0" "$UI_PROGRESS_ACTIVE" "log_info: clears the progress flag"
    UI_PROGRESS_ACTIVE=1; VERBOSE=true
    log_verbose "hello" >/dev/null 2>&1
    assert_equals "0" "$UI_PROGRESS_ACTIVE" "log_verbose: clears the progress flag when it prints"
    UI_PROGRESS_ACTIVE=1; VERBOSE=false
    log_verbose "hello" >/dev/null 2>&1
    assert_equals "1" "$UI_PROGRESS_ACTIVE" "log_verbose: leaves the bar alone when it prints nothing"
    UI_PROGRESS_ACTIVE=0
}
