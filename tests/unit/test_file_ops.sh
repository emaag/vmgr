#!/usr/bin/env bash
# Unit tests for lib/file-ops.sh pure functions:
#   apply_bracket_notation, remove_dashes, fix_bracket_spacing, cleanup_filename

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"

# ── apply_bracket_notation ────────────────────────────────────────────────────

test_bracket_basic() {
    local result
    result=$(apply_bracket_notation "studio filename.mp4")
    assert_equals "[Studio] filename.mp4" "$result" "bracket: basic studio filename"
}

test_bracket_single_word() {
    local result
    result=$(apply_bracket_notation "word.mp4")
    assert_equals "[Word].mp4" "$result" "bracket: single word filename"
}

test_bracket_capitalizes_first_letter() {
    local result
    result=$(apply_bracket_notation "abc rest.mkv")
    assert_contains "[Abc]" "$result" "bracket: first letter capitalised"
}

test_bracket_preserves_extension() {
    local result
    result=$(apply_bracket_notation "studio file.mkv")
    assert_contains ".mkv" "$result" "bracket: extension preserved"
}

test_bracket_dash_separator() {
    local result
    result=$(apply_bracket_notation "studio-rest.mp4")
    assert_contains "[Studio]" "$result" "bracket: dash separator handled"
}

test_bracket_dot_separator() {
    local result
    result=$(apply_bracket_notation "studio.rest.mp4")
    # first_word = "studio", separator = ".", rest = "rest"  ext = ".mp4"
    assert_contains "[Studio]" "$result" "bracket: dot separator handled"
}

test_bracket_underscore_in_name() {
    local result
    result=$(apply_bracket_notation "my_studio rest.mp4")
    assert_contains "[My_studio]" "$result" "bracket: underscore included in first word"
}

test_bracket_empty_filename_returns_nonzero() {
    local result
    result=$(apply_bracket_notation "" 2>/dev/null)
    local rc=$?
    assert_not_equals "0" "$rc" "bracket: empty filename returns non-zero"
}

test_bracket_no_extension() {
    local result
    result=$(apply_bracket_notation "studioname")
    assert_contains "[Studioname]" "$result" "bracket: no extension handled"
}

test_bracket_already_bracketed_passthrough() {
    # If the name already starts with [, the regex won't match [
    # (since [ is not in [a-zA-Z0-9_]) so the original is returned.
    local result
    result=$(apply_bracket_notation "[Studio] name.mp4")
    assert_equals "[Studio] name.mp4" "$result" "bracket: already-bracketed passthrough"
}

# ── remove_dashes ────────────────────────────────────────────────────────────

test_remove_dashes_basic() {
    local result
    result=$(remove_dashes "file - name.mp4")
    assert_equals "file name.mp4" "$result" "dashes: ' - ' replaced with ' '"
}

test_remove_dashes_no_dashes() {
    local result
    result=$(remove_dashes "nodash.mp4")
    assert_equals "nodash.mp4" "$result" "dashes: unchanged when no ' - '"
}

test_remove_dashes_multiple() {
    local result
    result=$(remove_dashes "a - b - c.mp4")
    assert_equals "a b c.mp4" "$result" "dashes: multiple ' - ' removed"
}

test_remove_dashes_hyphen_in_word_unchanged() {
    local result
    result=$(remove_dashes "well-known.mp4")
    assert_equals "well-known.mp4" "$result" "dashes: hyphen-in-word not removed (no spaces)"
}

test_remove_dashes_empty_string() {
    local result
    result=$(remove_dashes "")
    assert_equals "" "$result" "dashes: empty string stays empty"
}

# ── fix_bracket_spacing ───────────────────────────────────────────────────────

test_spacing_missing_space_after_bracket() {
    local result
    result=$(fix_bracket_spacing "[Studio]name.mp4")
    assert_equals "[Studio] name.mp4" "$result" "spacing: adds space after ]"
}

test_spacing_already_correct() {
    local result
    result=$(fix_bracket_spacing "[Studio] name.mp4")
    assert_equals "[Studio] name.mp4" "$result" "spacing: unchanged when correct"
}

test_spacing_no_brackets() {
    local result
    result=$(fix_bracket_spacing "filename.mp4")
    assert_equals "filename.mp4" "$result" "spacing: unchanged when no brackets"
}

test_spacing_multiple_brackets() {
    local result
    result=$(fix_bracket_spacing "[A]B [C]D.mp4")
    assert_equals "[A] B [C] D.mp4" "$result" "spacing: multiple bracket fixes"
}

# ── cleanup_filename (full pipeline) ─────────────────────────────────────────

test_cleanup_full_pipeline() {
    local result
    result=$(cleanup_filename "studio - rest.mp4")
    # After remove_dashes: "studio rest.mp4"
    # After apply_bracket_notation: "[Studio] rest.mp4"
    # After fix_bracket_spacing: "[Studio] rest.mp4"
    assert_equals "[Studio] rest.mp4" "$result" "cleanup: full pipeline"
}

test_cleanup_no_change_needed() {
    local result
    # Already in bracket notation with no dashes
    result=$(cleanup_filename "[Studio] rest.mp4")
    assert_equals "[Studio] rest.mp4" "$result" "cleanup: no change when already clean"
}

test_cleanup_preserves_extension() {
    local result
    result=$(cleanup_filename "studio name.mkv")
    assert_contains ".mkv" "$result" "cleanup: extension preserved"
}
