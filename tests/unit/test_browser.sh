#!/usr/bin/env bash
# Unit tests for lib/browser.sh:
#   browser_list_subdirs, browser_count_videos, browser_recent_add/list,
#   browse_directory non-TTY fallback

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "browser.sh"

_mk_tree() {
    local d
    d="$(mktemp -d)"
    mkdir -p "$d/beta" "$d/Alpha" "$d/.hidden"
    touch "$d/a.mp4" "$d/b.MKV" "$d/c.txt" "$d/d.jpg"
    echo "$d"
}

test_list_subdirs_sorted_no_hidden() {
    local d result; d="$(_mk_tree)"
    result="$(browser_list_subdirs "$d" 0 | tr '\n' ',')"
    assert_equals "Alpha,beta," "$result" "list_subdirs: sorted, case-insensitive, hides dotdirs"
    rm -rf "$d"
}

test_list_subdirs_hidden() {
    local d result; d="$(_mk_tree)"
    result="$(browser_list_subdirs "$d" 1 | tr '\n' ',')"
    assert_equals ".hidden,Alpha,beta," "$result" "list_subdirs: show_hidden includes dotdirs"
    rm -rf "$d"
}

test_list_subdirs_empty() {
    local d result; d="$(mktemp -d)"
    result="$(browser_list_subdirs "$d" 0)"
    assert_equals "" "$result" "list_subdirs: empty dir yields nothing"
    rm -rf "$d"
}

test_list_subdirs_space_in_name() {
    local d result; d="$(mktemp -d)"
    mkdir "$d/my videos"
    result="$(browser_list_subdirs "$d" 0)"
    assert_equals "my videos" "$result" "list_subdirs: names with spaces"
    rm -rf "$d"
}

test_count_videos() {
    local d result; d="$(_mk_tree)"
    result="$(browser_count_videos "$d")"
    assert_equals "2" "$result" "count_videos: counts only video files (case-insensitive ext)"
    rm -rf "$d"
}

test_count_videos_empty() {
    local d result; d="$(mktemp -d)"
    result="$(browser_count_videos "$d")"
    assert_equals "0" "$result" "count_videos: empty dir is 0"
    rm -rf "$d"
}

test_recent_add_order_and_dedupe() {
    local d1 d2 f result
    d1="$(mktemp -d)"; d2="$(mktemp -d)"; f="$(mktemp)"
    BROWSER_RECENT_FILE="$f"
    browser_recent_add "$d1"; browser_recent_add "$d2"; browser_recent_add "$d1"
    result="$(browser_recent_list | tr '\n' ',')"
    assert_equals "$d1,$d2," "$result" "recent: most recent first, deduplicated"
    rm -rf "$d1" "$d2" "$f"
}

test_recent_prunes_missing() {
    local d1 d2 f result
    d1="$(mktemp -d)"; d2="$(mktemp -d)"; f="$(mktemp)"
    BROWSER_RECENT_FILE="$f"
    browser_recent_add "$d1"; browser_recent_add "$d2"
    rm -rf "$d1"
    result="$(browser_recent_list | tr '\n' ',')"
    assert_equals "$d2," "$result" "recent: deleted directories are skipped"
    rm -rf "$d2" "$f"
}

test_recent_capped() {
    local f base i count
    f="$(mktemp)"; base="$(mktemp -d)"
    BROWSER_RECENT_FILE="$f"
    for i in $(seq 1 15); do mkdir "$base/d$i"; browser_recent_add "$base/d$i"; done
    count="$(browser_recent_list | wc -l | tr -d ' ')"
    assert_equals "$BROWSER_RECENT_MAX" "$count" "recent: capped at BROWSER_RECENT_MAX"
    rm -rf "$base" "$f"
}

test_browse_non_tty_select_default() {
    local d f; d="$(mktemp -d)"; f="$(mktemp)"
    BROWSER_RECENT_FILE="$f"
    TARGET_FOLDER=""
    browse_directory "$d" <<< "" >/dev/null
    local rc=$?
    assert_equals "0:$d" "$rc:$TARGET_FOLDER" "browse_directory: non-TTY empty input selects start dir"
    rm -rf "$d" "$f"
}

test_browse_non_tty_typed_path() {
    local d d2 f; d="$(mktemp -d)"; d2="$(mktemp -d)"; f="$(mktemp)"
    BROWSER_RECENT_FILE="$f"
    TARGET_FOLDER=""
    browse_directory "$d" <<< "$d2" >/dev/null
    assert_equals "$d2" "$TARGET_FOLDER" "browse_directory: non-TTY typed path is selected"
    rm -rf "$d" "$d2" "$f"
}

test_browse_non_tty_bad_path() {
    local d f; d="$(mktemp -d)"; f="$(mktemp)"
    BROWSER_RECENT_FILE="$f"
    browse_directory "$d" <<< "/no/such/dir/xyz" >/dev/null
    local rc=$?
    assert_equals "1" "$rc" "browse_directory: non-TTY bad path fails"
    rm -rf "$d" "$f"
}

test_list_videos() {
    local d result; d="$(_mk_tree)"
    result="$(browser_list_videos "$d" | tr '\n' ',')"
    assert_equals "a.mp4,b.MKV," "$result" "list_videos: only videos, sorted"
    rm -rf "$d"
}

# ── listing cache ────────────────────────────────────────────────────────────

# touch -t pins the mtime to the past so a later change is always detectable
_mk_cached_tree() {
    local d; d="$(mktemp -d)"
    mkdir "$d/one" "$d/two"; touch "$d/v.mp4"
    touch -t 200001010000 "$d"
    echo "$d"
}

test_cache_entries_content() {
    local d; d="$(_mk_cached_tree)"
    browser_cache_clear
    browser_dir_entries "$d" 0
    assert_equals "one,two|v.mp4" "$(IFS=,; echo "${BROWSER_SUBS[*]}")|${BROWSER_VIDS[*]}" "cache: entries returned"
    rm -rf "$d"
}

test_cache_hit_on_second_call() {
    local d; d="$(_mk_cached_tree)"
    browser_cache_clear; BROWSER_CACHE_HITS=0; BROWSER_CACHE_MISSES=0
    browser_dir_entries "$d" 0
    browser_dir_entries "$d" 0
    assert_equals "1:1" "$BROWSER_CACHE_HITS:$BROWSER_CACHE_MISSES" "cache: second call is a hit"
    rm -rf "$d"
}

test_cache_invalidated_when_dir_changes() {
    local d; d="$(_mk_cached_tree)"
    browser_cache_clear
    browser_dir_entries "$d" 0
    mkdir "$d/three"
    browser_dir_entries "$d" 0
    assert_equals "3" "${#BROWSER_SUBS[@]}" "cache: new folder seen after dir mtime changes"
    rm -rf "$d"
}

test_cache_hidden_flag_is_separate_key() {
    local d; d="$(_mk_cached_tree)"
    mkdir "$d/.dot"; touch -t 200001010000 "$d"
    browser_cache_clear
    browser_dir_entries "$d" 0; local plain=${#BROWSER_SUBS[@]}
    browser_dir_entries "$d" 1; local all=${#BROWSER_SUBS[@]}
    assert_equals "2:3" "$plain:$all" "cache: hidden and non-hidden listings cached separately"
    rm -rf "$d"
}

test_cache_clear_forces_rescan() {
    local d; d="$(_mk_cached_tree)"
    browser_cache_clear; BROWSER_CACHE_MISSES=0
    browser_dir_entries "$d" 0
    browser_cache_clear
    browser_dir_entries "$d" 0
    assert_equals "2" "$BROWSER_CACHE_MISSES" "cache: clear forces a re-scan"
    rm -rf "$d"
}

test_cache_empty_dir() {
    local d; d="$(mktemp -d)"
    browser_cache_clear
    browser_dir_entries "$d" 0
    assert_equals "0:0" "${#BROWSER_SUBS[@]}:${#BROWSER_VIDS[@]}" "cache: empty dir yields empty arrays"
    rm -rf "$d"
}

test_cache_bounded() {
    local base i; base="$(mktemp -d)"
    browser_cache_clear
    BROWSER_CACHE_MAX=5
    for i in 1 2 3 4 5 6 7 8; do mkdir "$base/d$i"; browser_dir_entries "$base/d$i" 0; done
    local n=${#BROWSER_CACHE_MTIME[@]}
    BROWSER_CACHE_MAX=200
    assert_equals "1" "$(( n <= 5 ? 1 : 0 ))" "cache: size stays within BROWSER_CACHE_MAX"
    rm -rf "$base"
}
