#!/usr/bin/env bash
# Integration tests for rename operations in lib/file-ops.sh:
#   rename_files_in_directory, remove_dashes_in_directory, fix_bracket_spacing_in_directory

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"

# Every test gets a fresh temp directory.
_setup() {
    TEST_TMPDIR="$(mktemp -d)"
}
_teardown() {
    [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"
}

# ── rename_files_in_directory ─────────────────────────────────────────────────

test_rename_applies_bracket_notation() {
    _setup
    touch "$TEST_TMPDIR/studio filename.mp4"
    rename_files_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/[Studio] filename.mp4" \
        "rename: bracket notation applied"
    _teardown
}

test_rename_removes_dashes_in_full_cleanup() {
    _setup
    touch "$TEST_TMPDIR/studio - filename.mp4"
    rename_files_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    # cleanup_filename: remove_dashes → apply_bracket → fix_spacing
    # "studio - filename.mp4" → "studio filename.mp4" → "[Studio] filename.mp4"
    assert_file_exists "$TEST_TMPDIR/[Studio] filename.mp4" \
        "rename: dash removed and bracket applied"
    _teardown
}

test_rename_dry_run_leaves_file_unchanged() {
    _setup
    touch "$TEST_TMPDIR/studio filename.mp4"
    rename_files_in_directory "$TEST_TMPDIR" true >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/studio filename.mp4" \
        "rename dry-run: original file unchanged"
    assert_file_not_exists "$TEST_TMPDIR/[Studio] filename.mp4" \
        "rename dry-run: new file not created"
    _teardown
}

test_rename_ignores_non_video_files() {
    _setup
    touch "$TEST_TMPDIR/document.txt"
    rename_files_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/document.txt" \
        "rename: .txt file untouched"
    _teardown
}

test_rename_empty_directory_exits_cleanly() {
    _setup
    local rc=0
    rename_files_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1 || rc=$?
    assert_equals "0" "$rc" "rename: empty dir exits 0"
    _teardown
}

test_rename_already_correct_skipped() {
    _setup
    touch "$TEST_TMPDIR/[Studio] name.mp4"
    rename_files_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/[Studio] name.mp4" \
        "rename: already-correct file untouched"
    _teardown
}

test_rename_multiple_files() {
    _setup
    touch "$TEST_TMPDIR/alpha file.mp4"
    touch "$TEST_TMPDIR/beta file.mkv"
    rename_files_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/[Alpha] file.mp4" "rename: first of multiple files renamed"
    assert_file_exists "$TEST_TMPDIR/[Beta] file.mkv"  "rename: second of multiple files renamed"
    _teardown
}

# ── remove_dashes_in_directory ────────────────────────────────────────────────

test_remove_dashes_dir() {
    _setup
    touch "$TEST_TMPDIR/file - name.mp4"
    remove_dashes_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/file name.mp4" \
        "remove_dashes_dir: dash removed"
    _teardown
}

test_remove_dashes_dir_dry_run() {
    _setup
    touch "$TEST_TMPDIR/file - name.mp4"
    remove_dashes_in_directory "$TEST_TMPDIR" true >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/file - name.mp4" \
        "remove_dashes_dir dry-run: original unchanged"
    _teardown
}

test_remove_dashes_dir_no_dash_unchanged() {
    _setup
    touch "$TEST_TMPDIR/nodash.mp4"
    remove_dashes_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/nodash.mp4" \
        "remove_dashes_dir: no-dash file unchanged"
    _teardown
}

# ── fix_bracket_spacing_in_directory ─────────────────────────────────────────

test_fix_spacing_dir() {
    _setup
    touch "$TEST_TMPDIR/[Studio]name.mp4"
    fix_bracket_spacing_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/[Studio] name.mp4" \
        "fix_spacing_dir: space added after bracket"
    _teardown
}

test_fix_spacing_dir_dry_run() {
    _setup
    touch "$TEST_TMPDIR/[Studio]name.mp4"
    fix_bracket_spacing_in_directory "$TEST_TMPDIR" true >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/[Studio]name.mp4" \
        "fix_spacing_dir dry-run: original unchanged"
    _teardown
}

test_fix_spacing_dir_already_correct() {
    _setup
    touch "$TEST_TMPDIR/[Studio] name.mp4"
    fix_bracket_spacing_in_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/[Studio] name.mp4" \
        "fix_spacing_dir: correct file unchanged"
    _teardown
}
