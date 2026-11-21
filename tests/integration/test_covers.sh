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

# ── Creating covers (needs ffmpeg) ────────────────────────────────────────────

_have_ffmpeg() { command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1; }

_make_setup() {
    _setup
    COVER_MAKE=true; COVER_FRAME_PERCENT=10; COVER_WIDTH=640; COVER_QUALITY=3; DRY_RUN=false
    mkdir -p "$TEST_TMPDIR/Make/Plain" "$TEST_TMPDIR/Make/Png" "$TEST_TMPDIR/Make/Empty"
    ffmpeg -v error -y -f lavfi -i testsrc=duration=10:size=1280x720:rate=10 "$TEST_TMPDIR/Make/Plain/scene.mp4" </dev/null
    ffmpeg -v error -y -f lavfi -i testsrc=duration=1:size=300x200:rate=1 -frames:v 1 "$TEST_TMPDIR/Make/Png/folder.png" </dev/null
    echo note > "$TEST_TMPDIR/Make/Empty/notes.txt"
}

test_covers_make_creates_from_video_frame() {
    if ! _have_ffmpeg; then assert_equals "1" "1" "covers make: skipped (no ffmpeg)"; return; fi
    _make_setup
    check_cover_art "$TEST_TMPDIR/Make" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/Make/Plain/folder.jpg" "covers make: cover created from the video"
    local w; w=$(ffprobe -v error -show_entries stream=width -of csv=p=0 "$TEST_TMPDIR/Make/Plain/folder.jpg" 2>/dev/null)
    assert_equals "640" "$w" "covers make: wide frame scaled down to COVER_WIDTH"
    _teardown
}

test_covers_make_converts_png_without_upscaling() {
    if ! _have_ffmpeg; then assert_equals "1" "1" "covers make: skipped (no ffmpeg)"; return; fi
    _make_setup
    check_cover_art "$TEST_TMPDIR/Make" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/Make/Png/folder.jpg" "covers make: folder.png converted to folder.jpg"
    local w; w=$(ffprobe -v error -show_entries stream=width -of csv=p=0 "$TEST_TMPDIR/Make/Png/folder.jpg" 2>/dev/null)
    assert_equals "300" "$w" "covers make: a small image is not enlarged"
    assert_file_exists "$TEST_TMPDIR/Make/Png/folder.png" "covers make: the original png is kept"
    _teardown
}

test_covers_make_skips_folder_with_nothing_to_use() {
    if ! _have_ffmpeg; then assert_equals "1" "1" "covers make: skipped (no ffmpeg)"; return; fi
    _make_setup
    local out; out=$(check_cover_art "$TEST_TMPDIR/Make" 2>&1)
    assert_file_not_exists "$TEST_TMPDIR/Make/Empty/folder.jpg" "covers make: no cover invented without a source"
    assert_contains "nothing to make one from" "$out" "covers make: reports folders it could not fill"
    _teardown
}

test_covers_make_never_overwrites() {
    if ! _have_ffmpeg; then assert_equals "1" "1" "covers make: skipped (no ffmpeg)"; return; fi
    _make_setup
    echo keep > "$TEST_TMPDIR/Make/Plain/folder.jpg"
    check_cover_art "$TEST_TMPDIR/Make" >/dev/null 2>&1
    assert_equals "keep" "$(cat "$TEST_TMPDIR/Make/Plain/folder.jpg")" "covers make: an existing cover is left alone"
    _teardown
}

test_covers_make_dry_run_writes_nothing() {
    if ! _have_ffmpeg; then assert_equals "1" "1" "covers make: skipped (no ffmpeg)"; return; fi
    _make_setup
    DRY_RUN=true
    local out; out=$(check_cover_art "$TEST_TMPDIR/Make" 2>&1)
    assert_file_not_exists "$TEST_TMPDIR/Make/Plain/folder.jpg" "covers make: dry run creates nothing"
    assert_contains "Would create" "$out" "covers make: dry run says what it would do"
    _teardown
}

test_covers_make_off_by_default_reports_only() {
    if ! _have_ffmpeg; then assert_equals "1" "1" "covers make: skipped (no ffmpeg)"; return; fi
    _make_setup
    COVER_MAKE=false
    check_cover_art "$TEST_TMPDIR/Make" >/dev/null 2>&1
    assert_file_not_exists "$TEST_TMPDIR/Make/Plain/folder.jpg" "covers make: nothing created unless asked"
    _teardown
}
