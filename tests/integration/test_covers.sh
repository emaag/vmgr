#!/usr/bin/env bash
# Integration tests for check_cover_art in lib/covers.sh

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "covers.sh"

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    LOG_DIR="$TEST_TMPDIR/logs"
    COVER_FILENAMES="folder.jpg"; COVER_CASE_INSENSITIVE=true; COVER_LEAF_ONLY=true
    COVER_REQUIRE_VIDEOS=false; COVER_SHOW_PRESENT=false; COVER_REPORT_FILE=""
    mkdir -p "$TEST_TMPDIR/Cat/Has" "$TEST_TMPDIR/Cat/Lacks" "$TEST_TMPDIR/Cat/Upper"
    touch "$TEST_TMPDIR/Cat/Has/folder.jpg" "$TEST_TMPDIR/Cat/Upper/FOLDER.JPG"
    touch "$TEST_TMPDIR/Cat/Lacks/a.mp4"
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

test_covers_reports_missing_leaf() {
    _setup
    local out; out=$(check_cover_art "$TEST_TMPDIR" 2>&1)
    assert_contains "Cat/Lacks" "$out" "covers: missing leaf listed"
    assert_contains "2 with a cover, 1 missing" "$out" "covers: counts (case-insensitive match)"
    _teardown
}

test_covers_skips_container_by_default() {
    _setup
    local out; out=$(check_cover_art "$TEST_TMPDIR" 2>&1)
    assert_not_contains "  $TEST_TMPDIR/Cat"$'\n' "$out" "covers: container folder not reported"
    _teardown
}

test_covers_all_folders_includes_containers() {
    _setup
    COVER_LEAF_ONLY=false
    local out; out=$(check_cover_art "$TEST_TMPDIR" 2>&1)
    assert_contains "3 missing" "$out" "covers: root, Cat and Lacks missing"
    _teardown
}

test_covers_case_sensitive() {
    _setup
    COVER_CASE_INSENSITIVE=false
    local out; out=$(check_cover_art "$TEST_TMPDIR" 2>&1)
    assert_contains "1 with a cover, 2 missing" "$out" "covers: FOLDER.JPG not matched when case-sensitive"
    _teardown
}

test_covers_alternate_names() {
    _setup
    touch "$TEST_TMPDIR/Cat/Lacks/cover.jpg"
    COVER_FILENAMES="folder.jpg, cover.jpg"
    local out; out=$(check_cover_art "$TEST_TMPDIR" 2>&1)
    assert_contains "3 with a cover, 0 missing" "$out" "covers: any listed name counts"
    _teardown
}

test_covers_videos_only() {
    _setup
    mkdir -p "$TEST_TMPDIR/Cat/Empty"
    COVER_REQUIRE_VIDEOS=true
    local out; out=$(check_cover_art "$TEST_TMPDIR" 2>&1)
    assert_contains "Checked 1 folders: 0 with a cover, 1 missing" "$out" "covers: only folders holding videos checked"
    _teardown
}

test_covers_report_file() {
    _setup
    COVER_REPORT_FILE="$TEST_TMPDIR/missing.txt"
    check_cover_art "$TEST_TMPDIR" >/dev/null 2>&1
    assert_equals "$TEST_TMPDIR/Cat/Lacks" "$(cat "$COVER_REPORT_FILE")" "covers: report file lists missing folder"
    _teardown
}
