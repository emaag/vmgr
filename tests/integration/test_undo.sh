#!/usr/bin/env bash
# Integration tests for the undo system: undo_record (core.sh), the hooks in
# rename/flatten (file-ops.sh), and undo_last_operation / list_undo_operations
# (organize.sh).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"
load_module_under_test "organize.sh"
load_module_under_test "theme.sh"
load_module_under_test "batch.sh"
load_module_under_test "browser.sh"
load_module_under_test "duplicates.sh"
# load_vmgr_core stubs the logging functions; bring the real ones back
source "$LIB_DIR/logging.sh"
LOG_FILE=/dev/null

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    UNDO_LOG_DIR="$TEST_TMPDIR/undo"
    ENABLE_UNDO=true
    INTERACTIVE=false
    DRY_RUN=false
    UNDO_CURRENT_LOG=""
    reset_statistics
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

_count_logs() { find "$UNDO_LOG_DIR" -maxdepth 1 -name '*.log' 2>/dev/null | wc -l | tr -d ' '; }

test_rename_is_recorded_and_undone() {
    _setup
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4" "$TEST_TMPDIR/v/two x.mkv"
    start_operation "Rename Files" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/[Studio] one.mp4" "undo: the rename happened"
    assert_equals "2" "$(undo_recorded_count)" "undo: both renames were recorded"

    undo_last_operation >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/studio one.mp4" "undo: first file has its old name again"
    assert_file_exists "$TEST_TMPDIR/v/two x.mkv" "undo: second file has its old name again"
    assert_file_not_exists "$TEST_TMPDIR/v/[Studio] one.mp4" "undo: the new name is gone"
    _teardown
}

test_flatten_is_recorded_and_undone() {
    _setup
    mkdir -p "$TEST_TMPDIR/top/season1"; touch "$TEST_TMPDIR/top/season1/ep one.mp4"
    start_operation "Flatten Directory" >/dev/null 2>&1
    flatten_directory "$TEST_TMPDIR/top" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/top/ep one.mp4" "undo: flatten moved the file up"
    undo_last_operation >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/top/season1/ep one.mp4" "undo: flatten is reversed, file is back in its subfolder"
    _teardown
}

test_one_operation_one_log_across_folders() {
    _setup
    mkdir "$TEST_TMPDIR/a" "$TEST_TMPDIR/b"
    touch "$TEST_TMPDIR/a/studio one.mp4" "$TEST_TMPDIR/b/other two.mp4"
    start_operation "Batch Rename" >/dev/null 2>&1
    batch_process_folders rename "$TEST_TMPDIR/a" "$TEST_TMPDIR/b" >/dev/null 2>&1
    assert_equals "1" "$(_count_logs)" "undo: a batch makes a single undo log"
    undo_last_operation >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a/studio one.mp4" "undo: the whole batch is undone (first folder)"
    assert_file_exists "$TEST_TMPDIR/b/other two.mp4" "undo: the whole batch is undone (second folder)"
    _teardown
}

test_separate_operations_get_separate_logs() {
    _setup
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4"
    start_operation "Rename Files" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    sleep 1
    start_operation "Remove Dashes" >/dev/null 2>&1
    touch "$TEST_TMPDIR/v/a - b.mp4"
    remove_dashes_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    assert_equals "2" "$(_count_logs)" "undo: each operation has its own log"
    _teardown
}

test_undo_off_records_nothing() {
    _setup
    ENABLE_UNDO=false
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4"
    start_operation "Rename Files" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    assert_equals "0" "$(_count_logs)" "undo off: no log is written"
    _teardown
}

test_dry_run_records_nothing() {
    _setup
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4"
    start_operation "Rename Files" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" true >/dev/null 2>&1
    assert_equals "0" "$(_count_logs)" "dry run: no undo log"
    assert_file_exists "$TEST_TMPDIR/v/studio one.mp4" "dry run: files untouched"
    _teardown
}

test_unwritable_undo_dir_does_not_break_the_operation() {
    _setup
    UNDO_LOG_DIR=/dev/null
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4"
    start_operation "Rename Files" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/[Studio] one.mp4" "undo: the rename still happens when logging is impossible"
    _teardown
}

test_undo_skips_when_the_original_name_is_taken() {
    _setup
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4"
    start_operation "Rename Files" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    touch "$TEST_TMPDIR/v/studio one.mp4"           # something new took the old name
    undo_last_operation >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/[Studio] one.mp4" "undo: does not overwrite a file that now has the old name"
    _teardown
}

test_undo_dry_run_changes_nothing() {
    _setup
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4"
    start_operation "Rename Files" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    DRY_RUN=true undo_last_operation >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/[Studio] one.mp4" "undo dry run: nothing restored"
    assert_equals "1" "$(_count_logs)" "undo dry run: the log is kept"
    _teardown
}

test_list_shows_operation_names() {
    _setup
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4"
    start_operation "Rename Files (Bracket Notation)" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    local out; out="$(list_undo_operations 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
    assert_contains "Rename Files (Bracket Notation)" "$out" "list: shows the operation name"
    assert_contains "1 file(s)" "$out" "list: shows how many files"
    _teardown
}

test_undo_by_id_and_legacy_organize_id() {
    _setup
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4"
    start_operation "Rename Files" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    local id; id="$(basename "$UNDO_CURRENT_LOG" .log)"
    undo_organize_operation "$id" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/studio one.mp4" "undo by ID: restores the files"
    # an organize-style log can still be found by its bare timestamp
    mkdir -p "$UNDO_LOG_DIR"; touch "$TEST_TMPDIR/v/moved.mp4"
    printf '# Undo Log\n%s|%s\n' "$TEST_TMPDIR/v/orig.mp4" "$TEST_TMPDIR/v/moved.mp4" > "$UNDO_LOG_DIR/organize-20260101-000000.log"
    undo_organize_operation "20260101-000000" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/v/orig.mp4" "undo: legacy organize IDs still work"
    _teardown
}

test_end_operation_mentions_undo() {
    _setup
    mkdir "$TEST_TMPDIR/v"; touch "$TEST_TMPDIR/v/studio one.mp4"
    start_operation "Rename Files" >/dev/null 2>&1
    rename_files_in_directory "$TEST_TMPDIR/v" false >/dev/null 2>&1
    local out; out="$(end_operation 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
    assert_contains "Undo: 1 change(s) recorded" "$out" "end_operation: tells you the change can be undone"
    _teardown
}

# A stand-in for ImageMagick: "convert in out" writes out (fails for files named bad*)
_fake_convert() {
    convert() { [[ "$(basename "$1")" == bad* ]] && return 1; echo "jpg of $(cat "$1")" > "${@: -1}"; }
}
_unfake_convert() { unset -f convert; }

test_png_conversion_keeps_the_original_in_the_trash_and_can_be_undone() {
    _setup; _fake_convert
    mkdir "$TEST_TMPDIR/p"; echo "pixels" > "$TEST_TMPDIR/p/pic.png"; echo "x" > "$TEST_TMPDIR/p/bad.png"
    start_operation "Convert PNG to JPG" >/dev/null 2>&1
    convert_png_to_jpg "$TEST_TMPDIR/p" false false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/p/pic.jpg" "convert: the .jpg was made"
    assert_file_not_exists "$TEST_TMPDIR/p/pic.png" "convert: the .png is no longer in the folder"
    assert_file_exists "$TEST_TMPDIR/p/bad.png" "convert: a failed conversion keeps its original"
    assert_equals "1" "$(find "$TEST_TMPDIR/p/.vmgr-trash" -name 'pic.png' | wc -l | tr -d ' ')" "convert: the original is in the trash, not deleted"

    undo_last_operation >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/p/pic.png" "undo: the .png is back"
    assert_equals "pixels" "$(cat "$TEST_TMPDIR/p/pic.png")" "undo: the .png content is intact"
    assert_file_not_exists "$TEST_TMPDIR/p/pic.jpg" "undo: the converted .jpg is moved away"
    _unfake_convert; _teardown
}

test_jpeg_rename_is_undone() {
    _setup
    mkdir "$TEST_TMPDIR/j"; echo "a" > "$TEST_TMPDIR/j/photo.jpeg"
    start_operation "Convert JPEG to JPG" >/dev/null 2>&1
    convert_jpeg_to_jpg "$TEST_TMPDIR/j" false false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/j/photo.jpg" "jpeg: renamed to .jpg"
    undo_last_operation >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/j/photo.jpeg" "undo: the .jpeg name is back"
    assert_file_not_exists "$TEST_TMPDIR/j/photo.jpg" "undo: the .jpg name is gone"
    _teardown
}

test_a_dry_run_conversion_changes_and_records_nothing() {
    _setup; _fake_convert
    mkdir "$TEST_TMPDIR/d"; echo "p" > "$TEST_TMPDIR/d/pic.png"
    start_operation "Convert PNG to JPG" >/dev/null 2>&1
    convert_png_to_jpg "$TEST_TMPDIR/d" true false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/d/pic.png" "dry run: the .png stays"
    assert_file_not_exists "$TEST_TMPDIR/d/pic.jpg" "dry run: no .jpg made"
    assert_equals "0" "$(undo_recorded_count)" "dry run: nothing recorded"
    _unfake_convert; _teardown
}
