#!/usr/bin/env bash
# Integration tests for install.sh. Only the safe paths are exercised: the
# installer is interactive and edits ~/.bashrc, so every run uses a throwaway HOME.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"

_setup() { TEST_TMPDIR="$(mktemp -d)"; }
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

test_install_script_has_valid_syntax() {
    local rc=0
    bash -n "$VMGR_ROOT/install.sh" 2>/dev/null || rc=$?
    assert_equals "0" "$rc" "install: install.sh parses"
}

test_install_declined_changes_nothing() {
    _setup
    local out rc
    out="$(cd "$VMGR_ROOT" && HOME="$TEST_TMPDIR" bash install.sh <<< "n" 2>&1)"
    rc=$?
    assert_equals "0" "$rc" "install: declining exits 0"
    assert_contains "Installation cancelled" "$out" "install: declining says so"
    assert_equals "0" "$(find "$TEST_TMPDIR" -mindepth 1 | wc -l | tr -d ' ')" "install: declining leaves HOME untouched"
    _teardown
}

test_install_must_run_from_the_project_directory() {
    _setup
    local out rc
    out="$(cd "$TEST_TMPDIR" && HOME="$TEST_TMPDIR" bash "$VMGR_ROOT/install.sh" <<< "y" 2>&1)"
    rc=$?
    assert_equals "1" "$rc" "install: wrong directory exits 1"
    assert_contains "video-manager-ultimate.sh not found" "$out" "install: wrong directory explained"
    _teardown
}
