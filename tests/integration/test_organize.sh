#!/usr/bin/env bash
# Integration tests for organize_by_subfolder_names + undo_organize_operation
# in lib/organize.sh

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "organize.sh"

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    # Override undo log dir to temp so tests are isolated
    UNDO_LOG_DIR="$TEST_TMPDIR/.undo"
    mkdir -p "$UNDO_LOG_DIR"
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

# ── organize_by_subfolder_names ───────────────────────────────────────────────

test_organize_moves_matching_file() {
    _setup
    mkdir -p "$TEST_TMPDIR/ActorName"
    touch "$TEST_TMPDIR/actorname_scene.mp4"
    ORGANIZE_LOG_OPERATIONS=true
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/ActorName/actorname_scene.mp4" \
        "organize: matching file moved to subfolder"
    assert_file_not_exists "$TEST_TMPDIR/actorname_scene.mp4" \
        "organize: file no longer at top level"
    _teardown
}

test_organize_case_insensitive_match() {
    _setup
    mkdir -p "$TEST_TMPDIR/MyActor"
    touch "$TEST_TMPDIR/myactor_video.mp4"
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/MyActor/myactor_video.mp4" \
        "organize: case-insensitive match works"
    _teardown
}

test_organize_dry_run_no_moves() {
    _setup
    mkdir -p "$TEST_TMPDIR/ActorName"
    touch "$TEST_TMPDIR/actorname_scene.mp4"
    DRY_RUN=true
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1
    DRY_RUN=false
    assert_file_exists "$TEST_TMPDIR/actorname_scene.mp4" \
        "organize dry-run: file stays in place"
    assert_file_not_exists "$TEST_TMPDIR/ActorName/actorname_scene.mp4" \
        "organize dry-run: file not in subfolder"
    _teardown
}

test_organize_file_already_in_subfolder_skipped() {
    _setup
    mkdir -p "$TEST_TMPDIR/ActorName"
    touch "$TEST_TMPDIR/ActorName/actorname_scene.mp4"
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1
    # File should still be there (not removed or duplicated)
    assert_file_exists "$TEST_TMPDIR/ActorName/actorname_scene.mp4" \
        "organize: file already in subfolder stays"
    _teardown
}

test_organize_no_matching_file_does_nothing() {
    _setup
    mkdir -p "$TEST_TMPDIR/ActorName"
    touch "$TEST_TMPDIR/unrelated_video.mp4"
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/unrelated_video.mp4" \
        "organize: non-matching file untouched"
    _teardown
}

test_organize_no_subfolders_returns_nonzero() {
    _setup
    touch "$TEST_TMPDIR/video.mp4"
    local rc=0
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1 || rc=$?
    assert_not_equals "0" "$rc" \
        "organize: no subfolders → non-zero exit"
    _teardown
}

test_organize_creates_undo_log() {
    _setup
    mkdir -p "$TEST_TMPDIR/ActorName"
    touch "$TEST_TMPDIR/actorname_file.mp4"
    ORGANIZE_LOG_OPERATIONS=true
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1
    local log_count
    log_count=$(find "$UNDO_LOG_DIR" -name "organize-*.log" 2>/dev/null | wc -l)
    assert_not_equals "0" "$log_count" \
        "organize: undo log file created"
    _teardown
}

test_organize_non_video_not_moved() {
    _setup
    mkdir -p "$TEST_TMPDIR/ActorName"
    touch "$TEST_TMPDIR/actorname_doc.txt"
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/actorname_doc.txt" \
        "organize: .txt file not moved"
    _teardown
}

# ── undo_organize_operation ───────────────────────────────────────────────────

test_undo_restores_file() {
    _setup
    mkdir -p "$TEST_TMPDIR/ActorName"
    touch "$TEST_TMPDIR/actorname_scene.mp4"
    ORGANIZE_LOG_OPERATIONS=true
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1
    # File is now in ActorName/
    assert_file_exists "$TEST_TMPDIR/ActorName/actorname_scene.mp4" "undo setup: file moved"
    # Undo
    undo_organize_operation >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/actorname_scene.mp4" \
        "undo: file restored to original location"
    assert_file_not_exists "$TEST_TMPDIR/ActorName/actorname_scene.mp4" \
        "undo: file removed from subfolder"
    _teardown
}

test_undo_dry_run_no_restore() {
    _setup
    mkdir -p "$TEST_TMPDIR/ActorName"
    touch "$TEST_TMPDIR/actorname_scene.mp4"
    ORGANIZE_LOG_OPERATIONS=true
    organize_by_subfolder_names "$TEST_TMPDIR" "$TEST_TMPDIR" >/dev/null 2>&1
    DRY_RUN=true
    undo_organize_operation >/dev/null 2>&1
    DRY_RUN=false
    assert_file_exists "$TEST_TMPDIR/ActorName/actorname_scene.mp4" \
        "undo dry-run: file stays in subfolder"
    _teardown
}

test_undo_no_log_returns_nonzero() {
    _setup
    # Empty undo log dir
    local rc=0
    undo_organize_operation >/dev/null 2>&1 || rc=$?
    assert_not_equals "0" "$rc" \
        "undo: no log file → non-zero exit"
    _teardown
}
