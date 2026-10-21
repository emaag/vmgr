#!/usr/bin/env bash
# Unit tests for lib/config.sh: save_config, load_config, list_config_profiles, delete_config_profile

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "config.sh"

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    CONFIG_FILE="$TEST_TMPDIR/.video-manager-config.conf"
    USER="${USER:-$(id -un)}"
    DRY_RUN=false; VERBOSE=false; INTERACTIVE=false
    WHISPER_MODEL=base; SUBTITLE_FORMAT=srt; FILTER_PATTERN=""
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

test_save_config_writes_the_profile_file() {
    _setup
    save_config work >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/.video-manager-config-work.conf" "save: profile file created"
    assert_contains "# Profile: work" "$(cat "$TEST_TMPDIR/.video-manager-config-work.conf")" "save: profile name in header"
    assert_contains "WHISPER_MODEL=\"base\"" "$(cat "$TEST_TMPDIR/.video-manager-config-work.conf")" "save: settings written"
    _teardown
}

test_save_config_defaults_to_the_default_profile() {
    _setup
    save_config >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/.video-manager-config-default.conf" "save: no name means the default profile"
    _teardown
}

test_load_config_restores_saved_values() {
    _setup
    DRY_RUN=true; WHISPER_MODEL=large; FILTER_PATTERN="*.mkv"
    save_config roundtrip >/dev/null 2>&1
    DRY_RUN=false; WHISPER_MODEL=tiny; FILTER_PATTERN=""
    load_config roundtrip >/dev/null 2>&1
    assert_equals "true" "$DRY_RUN" "load: boolean restored"
    assert_equals "large" "$WHISPER_MODEL" "load: quoted value restored"
    assert_equals "*.mkv" "$FILTER_PATTERN" "load: pattern with a glob character restored"
    _teardown
}

test_load_config_missing_profile_fails() {
    _setup
    local rc=0
    load_config nope >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "load: missing profile returns 1"
    _teardown
}

test_load_config_refuses_a_file_owned_by_someone_else() {
    _setup
    save_config shared >/dev/null 2>&1
    DRY_RUN=false
    printf 'DRY_RUN=true\n' > "$TEST_TMPDIR/.video-manager-config-shared.conf"
    local rc=0
    USER="not-the-owner" load_config shared >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "load: foreign-owned profile refused"
    assert_equals "false" "$DRY_RUN" "load: refused profile is not applied"
    _teardown
}

test_list_config_profiles_shows_saved_profiles() {
    _setup
    save_config alpha >/dev/null 2>&1
    save_config beta >/dev/null 2>&1
    local out; out="$(list_config_profiles 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
    assert_contains "alpha" "$out" "list: first profile shown"
    assert_contains "beta" "$out" "list: second profile shown"
    _teardown
}

test_list_config_profiles_when_none_saved() {
    _setup
    local out; out="$(list_config_profiles 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
    assert_contains "No saved profiles found" "$out" "list: says so when empty"
    _teardown
}

test_delete_config_profile_removes_the_file() {
    _setup
    save_config gone >/dev/null 2>&1
    delete_config_profile gone >/dev/null 2>&1
    assert_file_not_exists "$TEST_TMPDIR/.video-manager-config-gone.conf" "delete: file removed"
    local rc=0
    delete_config_profile gone >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "delete: a second delete reports not found"
    _teardown
}
