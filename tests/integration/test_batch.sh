#!/usr/bin/env bash
# Integration tests for lib/batch.sh:
#   batch_process_folders results, _batch_describe, queue helpers,
#   non-interactive batch_rename_interactive

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"
load_module_under_test "duplicates.sh"
load_module_under_test "browser.sh"
load_module_under_test "theme.sh"
load_module_under_test "batch.sh"

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    mkdir -p "$TEST_TMPDIR/a" "$TEST_TMPDIR/b"
    touch "$TEST_TMPDIR/a/studio one.mp4" "$TEST_TMPDIR/a/two x.mkv" "$TEST_TMPDIR/b/[Ok] fine.mp4"
    reset_statistics
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

test_describe_summarises_changes() {
    _batch_describe "5 1 0 0 0 0" "9 3 0 0 0 0"
    assert_equals "2 renamed" "$_BATCH_NOTE" "describe: lists what was renamed"
    _batch_describe "0 0 0 0 0 0" "4 0 0 0 0 0"
    assert_equals "4 checked, no changes" "$_BATCH_NOTE" "describe: says so when nothing changed"
    _batch_describe "0 0 0 0 0 0" "3 0 0 0 1 0"
    assert_equals "1" "$_BATCH_ERRORS" "describe: counts errors"
    _batch_describe "0 0 0 0 0 0" "2 0 0 0 0 2"
    assert_equals "2 would be renamed" "$_BATCH_NOTE" "describe: previews say would be renamed"
}

test_batch_renames_every_folder() {
    _setup
    batch_process_folders rename "$TEST_TMPDIR/a" "$TEST_TMPDIR/b" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a/[Studio] one.mp4" "batch rename: first folder processed"
    assert_file_exists "$TEST_TMPDIR/a/[Two] x.mkv" "batch rename: all files in the first folder"
    assert_equals "2" "${#BATCH_RESULT_NAMES[@]}" "batch rename: one result per folder"
    assert_equals "ok:ok" "${BATCH_RESULT_STATUS[0]}:${BATCH_RESULT_STATUS[1]}" "batch rename: both folders ok"
    assert_contains "renamed" "${BATCH_RESULT_NOTE[0]}" "batch rename: result note says what happened"
    _teardown
}

test_batch_dry_run_changes_nothing_but_reports() {
    _setup
    DRY_RUN=true batch_process_folders rename "$TEST_TMPDIR/a" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a/studio one.mp4" "batch dry run: files untouched"
    assert_contains "would be renamed" "${BATCH_RESULT_NOTE[0]}" "batch dry run: reports what would change"
    _teardown
}

test_batch_missing_folder_is_a_failure() {
    _setup
    local rc=0
    batch_process_folders rename "$TEST_TMPDIR/a" "$TEST_TMPDIR/nope" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "batch: a missing folder makes the batch fail"
    assert_equals "fail" "${BATCH_RESULT_STATUS[1]}" "batch: the missing folder is marked failed"
    assert_equals "[Studio] one.mp4" "$(ls "$TEST_TMPDIR/a" | grep -i studio)" "batch: the other folders still run"
    _teardown
}

test_batch_without_folders_errors() {
    local rc=0
    batch_process_folders rename >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "batch: no folders is an error"
}

test_queue_add_dedupes_and_counts_videos() {
    _setup
    BATCH_FOLDERS=(); BATCH_VIDEO_COUNTS=()
    _batch_add_folder "$TEST_TMPDIR/a"
    local rc=0
    _batch_add_folder "$TEST_TMPDIR/a" || rc=$?
    assert_equals "1" "$rc" "queue: adding the same folder twice is refused"
    assert_equals "1" "${#BATCH_FOLDERS[@]}" "queue: stays at one entry"
    assert_equals "2" "${BATCH_VIDEO_COUNTS[$TEST_TMPDIR/a]}" "queue: video count recorded"
    _teardown
}

test_non_interactive_batch_reads_lines_and_runs() {
    _setup
    printf '%s\n%s\n\n' "$TEST_TMPDIR/a" "$TEST_TMPDIR/b" | batch_rename_interactive >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a/[Studio] one.mp4" "batch (piped): runs without prompting"
    _teardown
}

test_non_interactive_batch_ignores_bad_paths() {
    _setup
    batch_rename_interactive < <(printf '%s\n%s\n\n' "$TEST_TMPDIR/missing" "$TEST_TMPDIR/b") >/dev/null 2>&1
    assert_equals "1" "${#BATCH_FOLDERS[@]}" "batch (piped): invalid directories are skipped"
    _teardown
}

test_batch_duplicates_reports_per_folder() {
    _setup
    echo same > "$TEST_TMPDIR/a/one.mp4"; echo same > "$TEST_TMPDIR/a/two.mp4"
    echo other > "$TEST_TMPDIR/b/solo.mp4"
    batch_process_folders duplicates "$TEST_TMPDIR/a" "$TEST_TMPDIR/b" >/dev/null 2>&1
    assert_contains "duplicate" "${BATCH_RESULT_NOTE[0]}" "batch duplicates: the folder with a copy reports it"
    [[ "${BATCH_RESULT_NOTE[1]}" != *duplicate* ]]; assert_equals "0" "$?" "batch duplicates: the clean folder reports none"
    assert_file_exists "$TEST_TMPDIR/a/one.mp4" "batch duplicates: report only, nothing deleted"
    _teardown
}

test_duplicate_scan_keeps_the_first_alphabetically() {
    _setup
    echo same > "$TEST_TMPDIR/a/zzz.mp4"; echo same > "$TEST_TMPDIR/a/aaa.mp4"
    DRY_RUN=false find_duplicates "$TEST_TMPDIR/a" delete >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a/aaa.mp4" "duplicates: the alphabetically first copy is kept"
    assert_file_not_exists "$TEST_TMPDIR/a/zzz.mp4" "duplicates: the later copy is the one removed"
    _teardown
}
