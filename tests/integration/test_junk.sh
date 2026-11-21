#!/usr/bin/env bash
# Integration tests for clean_junk in lib/junk.sh

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "junk.sh"

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    LOG_DIR="$TEST_TMPDIR/logs"; UNDO_LOG_DIR="$TEST_TMPDIR/undo"; mkdir -p "$UNDO_LOG_DIR"
    JUNK_EXTENSIONS="nfo,parts,url,lnk"; JUNK_NAMES="Thumbs.db,.DS_Store,desktop.ini"
    JUNK_INCLUDE_PARTIAL=false; JUNK_PARTIAL_EXTENSIONS="!qb,part,crdownload,tmp,aria2,!ut"
    DRY_RUN=false
    mkdir -p "$TEST_TMPDIR/Show"
    echo v > "$TEST_TMPDIR/Show/scene.mp4"
    echo n > "$TEST_TMPDIR/Show/Torrent Downloaded.NFO"
    echo u > "$TEST_TMPDIR/Show/link.url"
    echo t > "$TEST_TMPDIR/Show/Thumbs.db"
    echo p > "$TEST_TMPDIR/Show/.abc123.parts"
    echo d > "$TEST_TMPDIR/Show/scene2.mp4.!qB"
    echo s > "$TEST_TMPDIR/Show/scene.srt"
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

test_junk_reports_without_changing_anything() {
    _setup
    local out; out=$(clean_junk "$TEST_TMPDIR" false 2>&1)
    assert_contains "4 junk files" "$out" "junk: counts nfo, url, Thumbs.db, .parts"
    assert_contains "Report only" "$out" "junk: says nothing was changed"
    assert_file_exists "$TEST_TMPDIR/Show/link.url" "junk: report leaves files in place"
    _teardown
}

test_junk_matches_case_insensitively_and_by_name() {
    _setup
    local out; out=$(clean_junk "$TEST_TMPDIR" false 2>&1)
    assert_contains "Torrent Downloaded.NFO" "$out" "junk: .NFO matched"
    assert_contains "Thumbs.db" "$out" "junk: exact name matched"
    assert_contains ".abc123.parts" "$out" "junk: hidden .parts file matched"
    _teardown
}

test_junk_leaves_videos_subtitles_and_partials_alone() {
    _setup
    local out; out=$(clean_junk "$TEST_TMPDIR" false 2>&1)
    assert_not_contains "scene.mp4" "$out" "junk: video not listed"
    assert_not_contains "scene.srt" "$out" "junk: subtitle not listed"
    assert_not_contains ".!qB" "$out" "junk: unfinished download not listed by default"
    _teardown
}

test_junk_partial_option_includes_unfinished_downloads() {
    _setup
    JUNK_INCLUDE_PARTIAL=true
    local out; out=$(clean_junk "$TEST_TMPDIR" false 2>&1)
    assert_contains "scene2.mp4.!qB" "$out" "junk: unfinished download listed when enabled"
    assert_contains "5 junk files" "$out" "junk: count includes partials"
    _teardown
}

test_junk_apply_moves_to_trash_and_keeps_the_rest() {
    _setup
    clean_junk "$TEST_TMPDIR" true >/dev/null 2>&1
    assert_file_not_exists "$TEST_TMPDIR/Show/link.url" "junk: apply removes the junk from its folder"
    assert_file_exists "$TEST_TMPDIR/Show/scene.mp4" "junk: apply keeps the video"
    assert_file_exists "$TEST_TMPDIR/Show/scene.srt" "junk: apply keeps the subtitle"
    local trashed; trashed=$(find "$TEST_TMPDIR/.vmgr-trash" -type f 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "4" "$trashed" "junk: four files are in the trash, not deleted"
    _teardown
}

test_junk_apply_respects_dry_run() {
    _setup
    DRY_RUN=true
    clean_junk "$TEST_TMPDIR" true >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/Show/link.url" "junk: dry run moves nothing"
    assert_file_not_exists "$TEST_TMPDIR/.vmgr-trash" "junk: dry run creates no trash"
    _teardown
}

test_junk_custom_extensions() {
    _setup
    JUNK_EXTENSIONS="srt"; JUNK_NAMES=""
    local out; out=$(clean_junk "$TEST_TMPDIR" false 2>&1)
    assert_contains "1 junk files" "$out" "junk: only the configured extension counts"
    _teardown
}

test_junk_clean_folder() {
    _setup
    JUNK_EXTENSIONS="xyz"; JUNK_NAMES=""
    local out; out=$(clean_junk "$TEST_TMPDIR" false 2>&1)
    assert_contains "No junk files found" "$out" "junk: clean folder reports none"
    _teardown
}

test_junk_ignores_existing_trash() {
    _setup
    mkdir -p "$TEST_TMPDIR/.vmgr-trash/x" && echo n > "$TEST_TMPDIR/.vmgr-trash/x/old.nfo"
    local out; out=$(clean_junk "$TEST_TMPDIR" false 2>&1)
    assert_not_contains "old.nfo" "$out" "junk: files already in the trash are not listed"
    _teardown
}
