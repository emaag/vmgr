#!/usr/bin/env bash
# Integration tests for the command line: argument parsing and exit codes of
# video-manager-ultimate.sh. Each run uses a throwaway HOME.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"

VMGR_MAIN="$VMGR_ROOT/video-manager-ultimate.sh"

_setup() { TEST_TMPDIR="$(mktemp -d)"; mkdir -p "$TEST_TMPDIR/m"; }
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

# _vmgr ARGS...: run the script, output in $OUT (colours stripped), exit code in $RC
_vmgr() {
    local raw
    raw="$(HOME="$TEST_TMPDIR" bash "$VMGR_MAIN" "$@" 2>&1 </dev/null)"
    RC=$?
    OUT="$(sed 's/\x1b\[[0-9;]*[A-Za-z]//g' <<< "$raw")"
}

test_version_flag() {
    _setup
    _vmgr --version
    assert_equals "0" "$RC" "cli: --version exits 0"
    assert_contains "Video Manager Ultimate" "$OUT" "cli: --version names the program"
    assert_contains "$(grep -m1 '^readonly SCRIPT_VERSION=' "$LIB_DIR/core.sh" | cut -d'"' -f2)" "$OUT" "cli: --version shows the real version"
    _teardown
}

test_help_flag() {
    _setup
    _vmgr --help
    assert_equals "0" "$RC" "cli: --help exits 0"
    assert_contains "--empty-trash" "$OUT" "cli: --help lists options"
    _teardown
}

test_unknown_option_fails() {
    _setup
    _vmgr --no-such-flag
    assert_equals "1" "$RC" "cli: unknown option exits 1"
    assert_contains "Unknown option: --no-such-flag" "$OUT" "cli: unknown option is named"
    _teardown
}

test_command_without_directory_fails() {
    _setup
    _vmgr rename
    assert_equals "1" "$RC" "cli: rename without a directory exits 1"
    assert_contains "No directory specified" "$OUT" "cli: missing directory explained"
    _teardown
}

test_command_with_missing_directory_fails() {
    _setup
    _vmgr rename "$TEST_TMPDIR/nope"
    assert_equals "1" "$RC" "cli: a nonexistent directory exits 1"
    _teardown
}

test_invalid_sort_and_time_values_fail() {
    _setup
    _vmgr --sort sideways reddit
    assert_equals "1" "$RC" "cli: bad --sort exits 1"
    assert_contains "Invalid --sort value" "$OUT" "cli: bad --sort explained"
    _vmgr --time forever reddit
    assert_equals "1" "$RC" "cli: bad --time exits 1"
    assert_contains "Invalid --time value" "$OUT" "cli: bad --time explained"
    _teardown
}

test_rename_command_renames_and_dry_run_does_not() {
    _setup
    touch "$TEST_TMPDIR/m/a - b.mp4"
    _vmgr --dry-run rename "$TEST_TMPDIR/m"
    assert_equals "0" "$RC" "cli: dry-run rename exits 0"
    assert_file_exists "$TEST_TMPDIR/m/a - b.mp4" "cli: --dry-run leaves the file alone"
    _vmgr rename "$TEST_TMPDIR/m"
    assert_file_not_exists "$TEST_TMPDIR/m/a - b.mp4" "cli: rename changes the file"
    assert_file_exists "$TEST_TMPDIR/m/[A] b.mp4" "cli: rename uses bracket notation"
    _teardown
}

test_option_order_does_not_matter() {
    _setup
    touch "$TEST_TMPDIR/m/a - b.mp4"
    _vmgr rename "$TEST_TMPDIR/m" --dry-run
    assert_file_exists "$TEST_TMPDIR/m/a - b.mp4" "cli: --dry-run after the command still applies"
    _teardown
}

test_list_undo_with_nothing_recorded() {
    _setup
    _vmgr --list-undo
    assert_equals "0" "$RC" "cli: --list-undo exits 0"
    assert_contains "No undo operations available" "$OUT" "cli: --list-undo says so when empty"
    _teardown
}

test_empty_trash_options() {
    _setup
    _vmgr --empty-trash
    assert_equals "0" "$RC" "cli: --empty-trash exits 0 with nothing to do"
    assert_contains "The trash is empty" "$OUT" "cli: --empty-trash says the trash is empty"
    _vmgr --empty-trash 30
    assert_equals "0" "$RC" "cli: --empty-trash 30 is accepted"
    _vmgr --empty-trash abc
    assert_equals "1" "$RC" "cli: --empty-trash with a non-number is rejected"
    _teardown
}

test_parallel_option_only_accepts_1_to_8() {
    _setup
    touch "$TEST_TMPDIR/m/a.mp4"
    _vmgr --parallel 4 --dry-run rename "$TEST_TMPDIR/m"
    assert_equals "0" "$RC" "cli: --parallel 4 accepted"
    _teardown
}

test_catalog_export_command_writes_the_requested_format() {
    _setup
    mkdir -p "$TEST_TMPDIR/lib"; touch "$TEST_TMPDIR/lib/a.mp4"
    _vmgr catalog "$TEST_TMPDIR/lib"
    _vmgr catalog-export "$TEST_TMPDIR/out.json"
    assert_equals "0" "$RC" "cli: catalog-export exits 0"
    assert_file_exists "$TEST_TMPDIR/out.json" "cli: catalog-export writes the file"
    _vmgr catalog-export csv "$TEST_TMPDIR/out.csv"
    assert_contains "relative_path" "$(head -1 "$TEST_TMPDIR/out.csv")" "cli: a format word and a file can be given"
    _teardown
}
