#!/usr/bin/env bash
# Integration tests for catalog.sh:
#   init_catalog_db, register_drive, catalog_drive, list_cataloged_drives,
#   search_catalog, find_duplicates_in_catalog (hash-warning path)

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "platform.sh"
load_module_under_test "duplicates.sh"
load_module_under_test "catalog.sh"

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    CATALOG_DB="$TEST_TMPDIR/catalog.json"
    CATALOG_DRIVES_DB="$TEST_TMPDIR/drives.json"
    CATALOG_INCLUDE_HASH=false
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

# ── init_catalog_db ───────────────────────────────────────────────────────────

test_init_creates_catalog_file() {
    _setup
    init_catalog_db >/dev/null 2>&1
    assert_file_exists "$CATALOG_DB" "init: catalog.json created"
    _teardown
}

test_init_creates_drives_file() {
    _setup
    init_catalog_db >/dev/null 2>&1
    assert_file_exists "$CATALOG_DRIVES_DB" "init: drives.json created"
    _teardown
}

test_init_catalog_is_valid_json() {
    _setup
    init_catalog_db >/dev/null 2>&1
    local rc=0
    jq empty "$CATALOG_DB" 2>/dev/null || rc=$?
    assert_equals "0" "$rc" "init: catalog.json is valid JSON"
    _teardown
}

test_init_idempotent() {
    _setup
    init_catalog_db >/dev/null 2>&1
    init_catalog_db >/dev/null 2>&1
    local rc=0
    jq empty "$CATALOG_DB" 2>/dev/null || rc=$?
    assert_equals "0" "$rc" "init: second call leaves valid JSON"
    _teardown
}

# ── register_drive ────────────────────────────────────────────────────────────

test_register_drive_adds_entry() {
    _setup
    register_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local count
    count=$(jq '.drives | length' "$CATALOG_DRIVES_DB")
    assert_equals "1" "$count" "register: one drive entry created"
    _teardown
}

test_register_drive_nonexistent_fails() {
    _setup
    local rc=0
    register_drive "/nonexistent/vmgr_test_path" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "register: returns 1 for nonexistent path"
    _teardown
}

test_register_drive_idempotent() {
    _setup
    register_drive "$TEST_TMPDIR" >/dev/null 2>&1
    register_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local count
    count=$(jq '.drives | length' "$CATALOG_DRIVES_DB")
    assert_equals "1" "$count" "register: re-registering same drive doesn't duplicate"
    _teardown
}

test_register_drive_stores_mount_point() {
    _setup
    register_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local mount
    mount=$(jq -r '.drives[0].mount_point' "$CATALOG_DRIVES_DB")
    assert_equals "$TEST_TMPDIR" "$mount" "register: mount_point stored correctly"
    _teardown
}

# ── catalog_drive ─────────────────────────────────────────────────────────────

test_catalog_drive_nonexistent_fails() {
    _setup
    local rc=0
    catalog_drive "/nonexistent/vmgr_test_path" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "catalog: returns 1 for nonexistent path"
    _teardown
}

test_catalog_drive_indexes_video_files() {
    _setup
    touch "$TEST_TMPDIR/movie.mp4" "$TEST_TMPDIR/clip.mkv"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local count
    count=$(jq '.videos | length' "$CATALOG_DB")
    assert_equals "2" "$count" "catalog: 2 video files indexed"
    _teardown
}

test_catalog_drive_indexes_image_files() {
    _setup
    touch "$TEST_TMPDIR/photo.jpg" "$TEST_TMPDIR/pic.png"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local count
    count=$(jq '.videos | length' "$CATALOG_DB")
    assert_equals "2" "$count" "catalog: image files indexed"
    _teardown
}

test_catalog_drive_empty_dir_exits_zero() {
    _setup
    local rc=0
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1 || rc=$?
    assert_equals "0" "$rc" "catalog: empty dir exits 0"
    _teardown
}

test_catalog_drive_stores_filename() {
    _setup
    touch "$TEST_TMPDIR/myvideo.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local name
    name=$(jq -r '.videos[0].filename' "$CATALOG_DB")
    assert_equals "myvideo.mp4" "$name" "catalog: filename stored"
    _teardown
}

test_catalog_drive_stores_drive_id() {
    _setup
    touch "$TEST_TMPDIR/clip.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local drive_id
    drive_id=$(jq -r '.videos[0].drive_id' "$CATALOG_DB")
    assert_not_equals "" "$drive_id" "catalog: drive_id stored"
    _teardown
}

test_catalog_drive_stores_relative_path() {
    _setup
    touch "$TEST_TMPDIR/clip.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local rel
    rel=$(jq -r '.videos[0].relative_path' "$CATALOG_DB")
    assert_equals "clip.mp4" "$rel" "catalog: relative_path stored correctly"
    _teardown
}

test_catalog_drive_upserts_on_rescan() {
    _setup
    touch "$TEST_TMPDIR/a.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    touch "$TEST_TMPDIR/b.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local count
    count=$(jq '.videos | length' "$CATALOG_DB")
    assert_equals "2" "$count" "catalog: rescan replaces old entries, no duplicates"
    _teardown
}

test_catalog_drive_updates_drives_db() {
    _setup
    touch "$TEST_TMPDIR/x.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local count
    count=$(jq '.drives | length' "$CATALOG_DRIVES_DB")
    assert_equals "1" "$count" "catalog: drive registered in drives.json"
    _teardown
}

test_catalog_drive_updates_file_count() {
    _setup
    touch "$TEST_TMPDIR/a.mp4" "$TEST_TMPDIR/b.mp4" "$TEST_TMPDIR/c.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local n
    n=$(jq '.drives[0].file_count' "$CATALOG_DRIVES_DB")
    assert_equals "3" "$n" "catalog: file_count in drives.json matches"
    _teardown
}

# ── search_catalog ────────────────────────────────────────────────────────────

test_search_catalog_empty_term_fails() {
    _setup
    local rc=0
    search_catalog "" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "search: empty term returns 1"
    _teardown
}

test_search_catalog_finds_match() {
    _setup
    touch "$TEST_TMPDIR/nature_walk.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local out
    out=$(search_catalog "nature" 2>/dev/null)
    assert_contains "nature_walk.mp4" "$out" "search: finds file by name"
    _teardown
}

test_search_catalog_case_insensitive() {
    _setup
    touch "$TEST_TMPDIR/SummerTrip.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local out
    out=$(search_catalog "summertrip" 2>/dev/null)
    assert_contains "SummerTrip.mp4" "$out" "search: case-insensitive match"
    _teardown
}

test_search_catalog_no_match() {
    _setup
    touch "$TEST_TMPDIR/beach.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local out
    out=$(search_catalog "zzznomatch" 2>/dev/null)
    assert_contains "0 found" "$out" "search: no match shows 0 results"
    _teardown
}

test_search_catalog_media_filter_video() {
    _setup
    touch "$TEST_TMPDIR/file.mp4" "$TEST_TMPDIR/file.jpg"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local out
    out=$(search_catalog "file" "video" 2>/dev/null)
    assert_contains "file.mp4" "$out" "search: video filter includes mp4"
    _teardown
}

# ── list_cataloged_drives ─────────────────────────────────────────────────────

test_list_drives_empty() {
    _setup
    local out
    out=$(list_cataloged_drives 2>/dev/null)
    assert_contains "0 registered" "$out" "list drives: shows 0 when empty"
    _teardown
}

test_list_drives_shows_registered_drive() {
    _setup
    touch "$TEST_TMPDIR/vid.mp4"
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local out
    out=$(list_cataloged_drives 2>/dev/null)
    assert_contains "1 registered" "$out" "list drives: shows 1 after catalog"
    _teardown
}

# ── find_duplicates_in_catalog (hash-warning path) ────────────────────────────

test_find_duplicates_empty_catalog_returns_array() {
    _setup
    init_catalog_db >/dev/null 2>&1
    local out
    out=$(find_duplicates_in_catalog 2>/dev/null)
    assert_equals "[]" "$out" "dupes: empty catalog returns []"
    _teardown
}

test_find_duplicates_warns_when_no_hashes() {
    _setup
    touch "$TEST_TMPDIR/clip.mp4"
    CATALOG_INCLUDE_HASH=false
    catalog_drive "$TEST_TMPDIR" >/dev/null 2>&1
    local warn
    warn=$(find_duplicates_in_catalog 2>&1 >/dev/null)
    assert_contains "CATALOG_INCLUDE_HASH" "$warn" "dupes: warns when hashes missing"
    _teardown
}

test_find_duplicates_no_warn_on_empty_catalog() {
    _setup
    init_catalog_db >/dev/null 2>&1
    local warn
    warn=$(find_duplicates_in_catalog 2>&1 >/dev/null)
    assert_equals "" "$warn" "dupes: no warning on empty catalog"
    _teardown
}
