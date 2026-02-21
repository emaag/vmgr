#!/usr/bin/env bash
# Integration tests for flatten_directory in lib/file-ops.sh

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"

_setup() { TEST_TMPDIR="$(mktemp -d)"; }
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

# ── basic flatten ─────────────────────────────────────────────────────────────

test_flatten_moves_nested_file_to_top() {
    _setup
    mkdir -p "$TEST_TMPDIR/sub"
    touch "$TEST_TMPDIR/sub/video.mp4"
    flatten_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/video.mp4" \
        "flatten: file moved to top level"
    assert_file_not_exists "$TEST_TMPDIR/sub/video.mp4" \
        "flatten: file removed from subdirectory"
    _teardown
}

test_flatten_top_level_files_untouched() {
    _setup
    touch "$TEST_TMPDIR/top.mp4"
    flatten_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/top.mp4" \
        "flatten: top-level file stays"
    _teardown
}

test_flatten_dry_run_leaves_structure_intact() {
    _setup
    mkdir -p "$TEST_TMPDIR/sub"
    touch "$TEST_TMPDIR/sub/video.mp4"
    flatten_directory "$TEST_TMPDIR" true >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/sub/video.mp4" \
        "flatten dry-run: nested file unchanged"
    assert_file_not_exists "$TEST_TMPDIR/video.mp4" \
        "flatten dry-run: no file created at top"
    _teardown
}

test_flatten_non_video_files_ignored() {
    _setup
    mkdir -p "$TEST_TMPDIR/sub"
    touch "$TEST_TMPDIR/sub/document.txt"
    flatten_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_not_exists "$TEST_TMPDIR/document.txt" \
        "flatten: .txt not moved to top"
    assert_file_exists "$TEST_TMPDIR/sub/document.txt" \
        "flatten: .txt stays in subdir"
    _teardown
}

test_flatten_empty_dir_exits_cleanly() {
    _setup
    local rc=0
    flatten_directory "$TEST_TMPDIR" false >/dev/null 2>&1 || rc=$?
    assert_equals "0" "$rc" "flatten: empty dir exits 0"
    _teardown
}

test_flatten_multiple_levels() {
    _setup
    mkdir -p "$TEST_TMPDIR/a/b"
    touch "$TEST_TMPDIR/a/b/deep.mp4"
    flatten_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/deep.mp4" \
        "flatten: deeply nested file moved to top"
    _teardown
}

# ── conflict resolution ───────────────────────────────────────────────────────

test_flatten_conflict_same_size_skipped() {
    # flatten_directory skips same-size conflicts (treats as potential duplicates)
    _setup
    mkdir -p "$TEST_TMPDIR/sub"
    touch "$TEST_TMPDIR/video.mp4"       # 0 bytes
    touch "$TEST_TMPDIR/sub/video.mp4"   # 0 bytes (same size)
    flatten_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    # Original top-level file must survive
    assert_file_exists "$TEST_TMPDIR/video.mp4" \
        "flatten same-size conflict: top-level file kept"
    # Same-size → skipped, so subdir file remains
    assert_file_exists "$TEST_TMPDIR/sub/video.mp4" \
        "flatten same-size conflict: same-size subdir file skipped (not moved)"
    _teardown
}

test_flatten_conflict_different_size_renamed() {
    # Different-size conflict → subdir file moved with a safe name
    _setup
    mkdir -p "$TEST_TMPDIR/sub"
    echo "top level"       > "$TEST_TMPDIR/video.mp4"     # different content
    echo "sub level data"  > "$TEST_TMPDIR/sub/video.mp4" # different size
    flatten_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    # Original top-level file must survive
    assert_file_exists "$TEST_TMPDIR/video.mp4" \
        "flatten diff-size conflict: original top-level file kept"
    # Subdir file moved with safe name (video(1).mp4)
    assert_file_not_exists "$TEST_TMPDIR/sub/video.mp4" \
        "flatten diff-size conflict: subdir file moved"
    assert_file_exists "$TEST_TMPDIR/video(1).mp4" \
        "flatten diff-size conflict: renamed file at top level"
    _teardown
}

test_flatten_multiple_subdirs() {
    _setup
    mkdir -p "$TEST_TMPDIR/sub1" "$TEST_TMPDIR/sub2"
    touch "$TEST_TMPDIR/sub1/a.mp4"
    touch "$TEST_TMPDIR/sub2/b.mkv"
    flatten_directory "$TEST_TMPDIR" false >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a.mp4" "flatten multi-subdir: a.mp4 at top"
    assert_file_exists "$TEST_TMPDIR/b.mkv" "flatten multi-subdir: b.mkv at top"
    _teardown
}
