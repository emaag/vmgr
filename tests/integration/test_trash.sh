#!/usr/bin/env bash
# Integration tests for the duplicate trash: trash_file (core.sh), find_duplicates
# delete mode, undo of a trashed file, scans ignoring .vmgr-trash, and empty_trash.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"
load_module_under_test "duplicates.sh"
load_module_under_test "organize.sh"
load_module_under_test "theme.sh"
# load_vmgr_core stubs the logging functions; bring the real ones back
source "$LIB_DIR/logging.sh"
LOG_FILE=/dev/null

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    UNDO_LOG_DIR="$TEST_TMPDIR/undo"
    LOG_DIR="$TEST_TMPDIR/logs"
    ENABLE_UNDO=true; INTERACTIVE=false; DRY_RUN=false
    UNDO_CURRENT_LOG=""
    reset_statistics
    mkdir -p "$TEST_TMPDIR/v/sub"
    echo "same content" > "$TEST_TMPDIR/v/aaa.mp4"
    echo "same content" > "$TEST_TMPDIR/v/sub/zzz.mp4"
    echo "different" > "$TEST_TMPDIR/v/other.mp4"
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

_trashed_files() { find "$TEST_TMPDIR/v/.vmgr-trash" -type f 2>/dev/null; }

test_delete_moves_the_duplicate_to_the_trash() {
    _setup
    start_operation "Find and Delete Duplicates" >/dev/null 2>&1
    find_duplicates "$TEST_TMPDIR/v" delete >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/aaa.mp4" "trash: the kept copy stays"
    assert_file_not_exists "$TEST_TMPDIR/v/sub/zzz.mp4" "trash: the duplicate is gone from its folder"
    assert_equals "1" "$(_trashed_files | wc -l | tr -d ' ')" "trash: it is in the trash, not deleted"
    assert_contains "/.vmgr-trash/" "$(_trashed_files)" "trash: under a .vmgr-trash folder"
    assert_contains "/sub/zzz.mp4" "$(_trashed_files)" "trash: its relative path is kept"
    assert_equals "1" "${STATS[files_trashed]}" "trash: counted"
    _teardown
}

test_undo_puts_a_trashed_duplicate_back_and_tidies_up() {
    _setup
    start_operation "Find and Delete Duplicates" >/dev/null 2>&1
    find_duplicates "$TEST_TMPDIR/v" delete >/dev/null 2>&1
    undo_last_operation >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/sub/zzz.mp4" "undo: the duplicate is restored to its folder"
    assert_equals "0" "$(find "$TEST_TMPDIR/v/.vmgr-trash" 2>/dev/null | wc -l | tr -d ' ')" "undo: the emptied trash folder is removed"
    _teardown
}

test_a_rescan_does_not_treat_the_trash_as_duplicates() {
    _setup
    start_operation "Find and Delete Duplicates" >/dev/null 2>&1
    find_duplicates "$TEST_TMPDIR/v" delete >/dev/null 2>&1
    reset_statistics
    start_operation "Find Duplicates" >/dev/null 2>&1
    find_duplicates "$TEST_TMPDIR/v" report >/dev/null 2>&1
    assert_equals "0" "${STATS[duplicates_found]}" "rescan: trashed copies are not found again"
    _teardown
}

test_flatten_leaves_the_trash_alone() {
    _setup
    mkdir -p "$TEST_TMPDIR/v/.vmgr-trash/20260101-000000/sub"
    echo "trashed" > "$TEST_TMPDIR/v/.vmgr-trash/20260101-000000/sub/old.mp4"
    flatten_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/.vmgr-trash/20260101-000000/sub/old.mp4" "flatten: does not pull files out of the trash"
    assert_file_not_exists "$TEST_TMPDIR/v/old.mp4" "flatten: nothing from the trash lands in the folder"
    _teardown
}

test_undo_off_deletes_for_good() {
    _setup
    ENABLE_UNDO=false
    find_duplicates "$TEST_TMPDIR/v" delete >/dev/null 2>&1
    assert_equals "1" "$(find "$TEST_TMPDIR/v" -name '*.mp4' -not -name other.mp4 | wc -l | tr -d ' ')" "undo off: one duplicate removed"
    assert_equals "0" "$(_trashed_files | wc -l | tr -d ' ')" "undo off: nothing goes to the trash"
    _teardown
}

test_dry_run_moves_nothing() {
    _setup
    DRY_RUN=true find_duplicates "$TEST_TMPDIR/v" delete >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/sub/zzz.mp4" "dry run: the duplicate stays"
    assert_equals "0" "$(_trashed_files | wc -l | tr -d ' ')" "dry run: nothing trashed"
    _teardown
}

test_trash_file_avoids_name_collisions() {
    _setup
    echo one > "$TEST_TMPDIR/v/x.mp4"; trash_file "$TEST_TMPDIR/v/x.mp4" "$TEST_TMPDIR/v" "S1"
    echo two > "$TEST_TMPDIR/v/x.mp4"; trash_file "$TEST_TMPDIR/v/x.mp4" "$TEST_TMPDIR/v" "S1"
    assert_equals "2" "$(find "$TEST_TMPDIR/v/.vmgr-trash/S1" -type f | wc -l | tr -d ' ')" "trash_file: a second file with the same path does not overwrite the first"
    _teardown
}

test_trash_file_failure_leaves_the_original() {
    if on_windows_shell; then _pass "unwritable trash folder: skipped (no POSIX permissions/symlinks in Git Bash)"; return 0; fi
    _setup
    local rc=0
    trash_file "$TEST_TMPDIR/v/missing.mp4" "$TEST_TMPDIR/v" "S1" || rc=$?
    assert_equals "1" "$rc" "trash_file: a missing file is an error"
    echo keep > "$TEST_TMPDIR/v/keep.mp4"
    chmod a-w "$TEST_TMPDIR/v"
    rc=0; trash_file "$TEST_TMPDIR/v/keep.mp4" "$TEST_TMPDIR/v" "S1" 2>/dev/null || rc=$?
    chmod u+w "$TEST_TMPDIR/v"
    if [[ "$(id -u)" != 0 ]]; then
        assert_equals "1" "$rc" "trash_file: an unwritable folder is an error"
        assert_file_exists "$TEST_TMPDIR/v/keep.mp4" "trash_file: the original is left alone on failure"
    fi
    _teardown
}

test_one_operation_one_undo_log_for_many_trashed_files() {
    _setup
    echo same content > "$TEST_TMPDIR/v/sub/more.mp4"
    start_operation "Find and Delete Duplicates" >/dev/null 2>&1
    find_duplicates "$TEST_TMPDIR/v" delete >/dev/null 2>&1
    assert_equals "1" "$(find "$UNDO_LOG_DIR" -name '*.log' | wc -l | tr -d ' ')" "trash: all files of one operation share one undo log"
    assert_equals "2" "$(undo_recorded_count)" "trash: both removals recorded"
    _teardown
}

test_empty_trash_when_there_is_nothing() {
    _setup
    local out; out="$(empty_trash 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
    assert_contains "The trash is empty" "$out" "empty trash: says so when there is nothing"
    _teardown
}

test_empty_trash_deletes_for_good_and_retires_the_undo_log() {
    _setup
    start_operation "Find and Delete Duplicates" >/dev/null 2>&1
    find_duplicates "$TEST_TMPDIR/v" delete >/dev/null 2>&1
    empty_trash <<< "y" >/dev/null 2>&1
    assert_equals "0" "$(find "$TEST_TMPDIR/v" -name '.vmgr-trash' | wc -l | tr -d ' ')" "empty trash: the trash folder is gone"
    assert_file_exists "$TEST_TMPDIR/v/aaa.mp4" "empty trash: the kept copy is untouched"
    assert_equals "0" "$(find "$UNDO_LOG_DIR" -name '*.log' | wc -l | tr -d ' ')" "empty trash: the undo log that pointed into it is retired"
    assert_equals "1" "$(find "$UNDO_LOG_DIR" -name '*.log.expired' | wc -l | tr -d ' ')" "empty trash: ... and kept as .expired"
    _teardown
}

test_empty_trash_declined_changes_nothing() {
    _setup
    start_operation "Find and Delete Duplicates" >/dev/null 2>&1
    find_duplicates "$TEST_TMPDIR/v" delete >/dev/null 2>&1
    local rc=0
    empty_trash <<< "n" >/dev/null 2>&1 || rc=$?
    assert_equals "2" "$rc" "empty trash: declining returns 2"
    assert_equals "1" "$(_trashed_files | wc -l | tr -d ' ')" "empty trash: declining keeps the files"
    assert_equals "1" "$(find "$UNDO_LOG_DIR" -name '*.log' | wc -l | tr -d ' ')" "empty trash: declining keeps the undo log"
    _teardown
}

test_empty_trash_dry_run_changes_nothing() {
    _setup
    start_operation "Find and Delete Duplicates" >/dev/null 2>&1
    find_duplicates "$TEST_TMPDIR/v" delete >/dev/null 2>&1
    DRY_RUN=true empty_trash >/dev/null 2>&1
    assert_equals "1" "$(_trashed_files | wc -l | tr -d ' ')" "empty trash dry run: nothing deleted"
    _teardown
}

test_subtitle_scan_skips_the_trash() {
    _setup
    mkdir -p "$TEST_TMPDIR/bin" "$TEST_TMPDIR/s/.vmgr-trash/S1"
    printf '#!/usr/bin/env bash\necho "$1" >> "%s/calls"\nexit 0\n' "$TEST_TMPDIR" > "$TEST_TMPDIR/bin/whisper"
    chmod +x "$TEST_TMPDIR/bin/whisper"
    touch "$TEST_TMPDIR/s/real.mp4" "$TEST_TMPDIR/s/.vmgr-trash/S1/trashed.mp4"
    load_module_under_test "subtitles.sh"
    local saved="$PATH"; export PATH="$TEST_TMPDIR/bin:$PATH"
    SUBTITLE_RECURSIVE=true; SUBTITLE_MAX_DEPTH=5; SUBTITLE_MIN_DEPTH=1; SUBTITLE_PARALLEL_JOBS=1
    SUBTITLE_SKIP_EXISTING=false; SUBTITLE_MIN_SIZE_MB=0; SUBTITLE_MAX_SIZE_MB=0; SUBTITLE_MODIFIED_DAYS=0
    SUBTITLE_MAX_FILES=0; SUBTITLE_USE_GPU=false; SUBTITLE_SHOW_DIR_STATS=false; SUBTITLE_INTERACTIVE_EDIT=false
    generate_subtitles_in_directory "$TEST_TMPDIR/s" base srt auto false >/dev/null 2>&1
    export PATH="$saved"
    assert_equals "1" "$(wc -l < "$TEST_TMPDIR/calls" | tr -d ' ')" "subtitles: only the real video is processed"
    assert_not_equals "" "$(grep -c real "$TEST_TMPDIR/calls")" "subtitles: it is the real one"
    _teardown
}

# Two trashed batches, one aged 10 days, each with its own undo log.
_two_batches() {
    local t="$TEST_TMPDIR/v/.vmgr-trash"
    mkdir -p "$t/old" "$t/new" "$UNDO_LOG_DIR"
    echo old > "$t/old/o.mp4"; echo new > "$t/new/n.mp4"
    printf '# Operation: old\n%s|%s\n' "$TEST_TMPDIR/v/o.mp4" "$t/old/o.mp4" > "$UNDO_LOG_DIR/op-old.log"
    printf '# Operation: new\n%s|%s\n' "$TEST_TMPDIR/v/n.mp4" "$t/new/n.mp4" > "$UNDO_LOG_DIR/op-new.log"
    touch_days_ago 10 "$t/old"
}

test_empty_trash_with_days_keeps_newer_batches_and_their_undo() {
    _setup
    _two_batches
    empty_trash 7 <<< "y" >/dev/null 2>&1
    assert_file_not_exists "$TEST_TMPDIR/v/.vmgr-trash/old/o.mp4" "empty trash days: the old batch is deleted"
    assert_file_exists "$TEST_TMPDIR/v/.vmgr-trash/new/n.mp4" "empty trash days: the new batch is kept"
    assert_file_exists "$UNDO_LOG_DIR/op-new.log" "empty trash days: the kept batch can still be undone"
    assert_file_exists "$UNDO_LOG_DIR/op-old.log.expired" "empty trash days: the deleted batch's undo log is retired"
    _teardown
}

test_empty_trash_with_days_reports_when_nothing_is_old_enough() {
    _setup
    _two_batches
    local out; out="$(empty_trash 30 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
    assert_contains "Nothing in the trash is 30 day(s) old yet" "$out" "empty trash days: says nothing qualifies"
    assert_equals "2" "$(_trashed_files | wc -l | tr -d ' ')" "empty trash days: nothing deleted"
    _teardown
}

test_empty_trash_rejects_a_bad_day_count() {
    _setup
    local rc=0
    empty_trash "abc" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "empty trash days: a non-number is an error"
    _teardown
}
