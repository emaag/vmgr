#!/usr/bin/env bash
# Unit tests for lib/theme.sh and the plain-mode switches in lib/core.sh:
#   _ui_short_path, ui_box_row, ui_item, ui_item_toggle, ui_read_choice,
#   NO_COLOR / ASCII fallbacks

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "theme.sh"

_strip() { sed 's/\x1b\[[0-9;]*m//g'; }

test_short_path_home_and_ellipsis() {
    local out
    HOME=/home/tester _ui_short_path "/home/tester/Videos" 40 out
    assert_equals "~/Videos" "$out" "short_path: \$HOME becomes ~"
    _ui_short_path "/a/very/long/path/to/some/folder" 12 out
    assert_equals "12" "${#out}" "short_path: truncated to the requested width"
    assert_equals "$UI_ELLIPSIS" "${out:0:${#UI_ELLIPSIS}}" "short_path: truncation marks the cut with an ellipsis"
}

test_box_row_fills_the_width() {
    COLUMNS=100
    local row plain
    row="$(ui_box_row "left" "${COLOR_RED}left${COLOR_RESET}" "right" "${COLOR_BLUE}right${COLOR_RESET}")"
    plain="$(printf '%s' "$row" | _strip)"
    assert_equals "$UI_MAX_WIDTH" "${#plain}" "box_row: visible width equals the box width"
}

test_box_row_respects_narrow_terminal() {
    COLUMNS=40
    local row plain
    row="$(ui_box_row "a" "a" "b" "b")"
    plain="$(printf '%s' "$row" | _strip)"
    assert_equals "40" "${#plain}" "box_row: shrinks to a narrow terminal"
    COLUMNS=100
}

test_item_shows_key_label_and_desc() {
    COLUMNS=100
    local out; out="$(ui_item 3 "Search Catalog" "Find media" | _strip)"
    assert_contains "3" "$out" "item: key shown"
    assert_contains "Search Catalog" "$out" "item: label shown"
    assert_contains "Find media" "$out" "item: description shown"
}

test_item_long_description_wraps_below() {
    COLUMNS=100
    local out lines
    out="$(ui_item 2 "Deep Clean" "Remove Dashes + Fix Spacing + Bracket Notation + more words here" | _strip)"
    lines=$(( $(printf '%s\n' "$out" | wc -l) ))
    assert_equals "2" "$lines" "item: an over-wide description moves to its own line"
}

test_item_toggle_state() {
    COLUMNS=100
    local on off
    on="$(ui_item_toggle D "Dry run" true | _strip)"
    off="$(ui_item_toggle D "Dry run" false | _strip)"
    assert_contains "$UI_DOT_ON ON" "$on" "toggle: on state"
    assert_contains "$UI_DOT_OFF OFF" "$off" "toggle: off state"
}

test_read_choice_from_pipe_reads_a_line() {
    local choice=""
    ui_read_choice choice <<< "q"
    assert_equals "q" "$choice" "read_choice: non-tty input reads a line"
}

test_read_choice_eof_returns_nonzero() {
    local choice="" rc=0
    ui_read_choice choice < /dev/null || rc=$?
    assert_equals "1" "$rc" "read_choice: end of input returns 1 instead of looping"
}

test_no_color_empties_codes() {
    local out
    out="$(NO_COLOR=1 bash -c 'source "'"$LIB_DIR"'/core.sh"; printf "[%s][%s]" "$COLOR_RED" "$COLOR_RESET"')"
    assert_equals "[][]" "$out" "NO_COLOR: color codes are empty"
}

test_plain_item_uses_brackets() {
    local out
    out="$(NO_COLOR=1 COLUMNS=100 bash -c '
        source "'"$LIB_DIR"'/core.sh"; source "'"$LIB_DIR"'/theme.sh"
        ui_item 4 "Utilities" "Logs"')"
    assert_contains "[4]" "$out" "NO_COLOR: key drawn as [4] instead of a colored chip"
}

test_ascii_fallback_for_non_utf8() {
    local out
    out="$(LC_ALL=C LANG=C bash -c 'source "'"$LIB_DIR"'/core.sh"; printf "%s%s" "$SYMBOL_ARROW" "$SYMBOL_CHECK"')"
    assert_equals ">+" "$out" "ASCII: non-UTF-8 locale gets plain glyphs"
}

test_confirm_yes_and_no_from_pipe() {
    local rc=0
    ui_confirm "Go?" <<< "y" >/dev/null || rc=$?
    assert_equals "0" "$rc" "confirm: y returns 0"
    assert_equals "y" "$REPLY" "confirm: y sets REPLY"
    rc=0; ui_confirm "Go?" <<< "n" >/dev/null || rc=$?
    assert_equals "1" "$rc" "confirm: n returns 1"
    assert_equals "n" "$REPLY" "confirm: n sets REPLY"
}

test_confirm_default_on_empty_input() {
    local rc=0
    ui_confirm "Go?" <<< "" >/dev/null || rc=$?
    assert_equals "1" "$rc" "confirm: Enter picks the default (no)"
    rc=0; ui_confirm "Go?" y <<< "" >/dev/null || rc=$?
    assert_equals "0" "$rc" "confirm: Enter picks the default when it is yes"
    rc=0; ui_confirm "Go?" < /dev/null >/dev/null || rc=$?
    assert_equals "1" "$rc" "confirm: end of input falls back to the default"
}

test_confirm_shows_hint() {
    assert_contains "[y/N]" "$(ui_confirm "Go?" <<< n | _strip)" "confirm: default-no hint"
    assert_contains "[Y/n]" "$(ui_confirm "Go?" y <<< y | _strip)" "confirm: default-yes hint"
}

test_ask_reads_a_line() {
    local answer=""
    ui_ask answer "Name" <<< "hello world" >/dev/null
    assert_equals "hello world" "$answer" "ask: reads a line into the variable"
    ui_ask answer "Name" < /dev/null >/dev/null
    assert_equals "" "$answer" "ask: end of input leaves the variable empty"
}

test_pause_returns_on_any_input() {
    local rc=0
    ui_pause <<< "x" >/dev/null || rc=$?
    assert_equals "0" "$rc" "pause: returns after a line of input"
    rc=0; ui_pause < /dev/null >/dev/null || rc=$?
    assert_equals "0" "$rc" "pause: end of input does not hang or fail"
}

test_ask_yes_no_fallback_without_theme() {
    local out
    out="$(bash -c 'source "'"$LIB_DIR"'/core.sh"; ask_yes_no "Go?" <<< y; echo rc=$?' 2>&1)"
    assert_contains "rc=0" "$out" "ask_yes_no: plain fallback works without theme.sh"
}
