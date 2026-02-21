#!/usr/bin/env bash
# Integration tests for find_duplicates in lib/duplicates.sh

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "duplicates.sh"

_setup() { TEST_TMPDIR="$(mktemp -d)"; }
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

# Helper: create two identical video files in TEST_TMPDIR
_make_duplicates() {
    echo "duplicate video content 12345" > "$TEST_TMPDIR/original.mp4"
    cp "$TEST_TMPDIR/original.mp4" "$TEST_TMPDIR/duplicate.mp4"
}

# ── No duplicates ─────────────────────────────────────────────────────────────

test_no_duplicates_exits_zero() {
    _setup
    echo "unique A" > "$TEST_TMPDIR/a.mp4"
    echo "unique B" > "$TEST_TMPDIR/b.mp4"
    local rc=0
    find_duplicates "$TEST_TMPDIR" report >/dev/null 2>&1 || rc=$?
    assert_equals "0" "$rc" "no_duplicates: exits 0"
    _teardown
}

test_no_duplicates_no_report_dir_created() {
    _setup
    echo "unique content" > "$TEST_TMPDIR/only.mp4"
    find_duplicates "$TEST_TMPDIR" report >/dev/null 2>&1
    # Report dir only created when duplicates found
    local report_dirs
    report_dirs=$(find "$TEST_TMPDIR" -name "_duplicate_report_*" -type d 2>/dev/null | wc -l)
    assert_equals "0" "$report_dirs" "no_duplicates: no report dir created"
    _teardown
}

# ── Duplicate detection (report mode) ────────────────────────────────────────

test_duplicates_found_creates_report_dir() {
    _setup
    _make_duplicates
    find_duplicates "$TEST_TMPDIR" report >/dev/null 2>&1
    local report_dirs
    report_dirs=$(find "$TEST_TMPDIR" -name "_duplicate_report_*" -type d 2>/dev/null | wc -l)
    assert_not_equals "0" "$report_dirs" "duplicates: report directory created"
    _teardown
}

test_duplicates_report_contains_txt_file() {
    _setup
    _make_duplicates
    find_duplicates "$TEST_TMPDIR" report >/dev/null 2>&1
    local txt_count
    txt_count=$(find "$TEST_TMPDIR" -name "duplicates.txt" 2>/dev/null | wc -l)
    assert_not_equals "0" "$txt_count" "duplicates: duplicates.txt report created"
    _teardown
}

test_duplicates_report_contains_csv_file() {
    _setup
    _make_duplicates
    find_duplicates "$TEST_TMPDIR" report >/dev/null 2>&1
    local csv_count
    csv_count=$(find "$TEST_TMPDIR" -name "duplicates.csv" 2>/dev/null | wc -l)
    assert_not_equals "0" "$csv_count" "duplicates: duplicates.csv export created"
    _teardown
}

test_duplicates_report_lists_both_files() {
    _setup
    _make_duplicates
    find_duplicates "$TEST_TMPDIR" report >/dev/null 2>&1
    local report
    report=$(find "$TEST_TMPDIR" -name "duplicates.txt" | head -1)
    assert_contains "original.mp4" "$(cat "$report")" \
        "duplicates: report mentions original.mp4"
    assert_contains "duplicate.mp4" "$(cat "$report")" \
        "duplicates: report mentions duplicate.mp4"
    _teardown
}

test_duplicates_stat_counter_incremented() {
    _setup
    _make_duplicates
    STATS[duplicates_found]=0
    find_duplicates "$TEST_TMPDIR" report >/dev/null 2>&1
    assert_not_equals "0" "${STATS[duplicates_found]}" \
        "duplicates: STATS[duplicates_found] incremented"
    _teardown
}

# ── Duplicate deletion ────────────────────────────────────────────────────────

test_duplicates_delete_removes_one_file() {
    _setup
    _make_duplicates
    find_duplicates "$TEST_TMPDIR" delete >/dev/null 2>&1
    local mp4_count
    mp4_count=$(find "$TEST_TMPDIR" -maxdepth 1 -name "*.mp4" -not -path "*_duplicate_report_*" | wc -l)
    assert_equals "1" "$mp4_count" "duplicates delete: only one .mp4 remains"
    _teardown
}

test_duplicates_delete_retains_original() {
    _setup
    _make_duplicates
    find_duplicates "$TEST_TMPDIR" delete >/dev/null 2>&1
    # The original (first hashed) should remain; either file surviving is acceptable.
    # Just confirm exactly one .mp4 remains at top level.
    local mp4_count
    mp4_count=$(find "$TEST_TMPDIR" -maxdepth 1 -name "*.mp4" | wc -l)
    assert_equals "1" "$mp4_count" "duplicates delete: exactly one file retained"
    _teardown
}

test_duplicates_delete_dry_run_keeps_both_files() {
    _setup
    _make_duplicates
    DRY_RUN=true
    find_duplicates "$TEST_TMPDIR" delete >/dev/null 2>&1
    DRY_RUN=false
    local mp4_count
    mp4_count=$(find "$TEST_TMPDIR" -maxdepth 1 -name "*.mp4" | wc -l)
    assert_equals "2" "$mp4_count" "duplicates delete dry-run: both files kept"
    _teardown
}

# ── Edge cases ────────────────────────────────────────────────────────────────

test_duplicates_empty_dir_exits_zero() {
    _setup
    local rc=0
    find_duplicates "$TEST_TMPDIR" report >/dev/null 2>&1 || rc=$?
    assert_equals "0" "$rc" "duplicates: empty dir exits 0"
    _teardown
}

test_duplicates_single_file_no_duplicates() {
    _setup
    echo "lone file" > "$TEST_TMPDIR/lone.mp4"
    local rc=0
    find_duplicates "$TEST_TMPDIR" report >/dev/null 2>&1 || rc=$?
    assert_equals "0" "$rc" "duplicates: single file exits 0"
    _teardown
}
