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

test_progress_silent_when_not_a_terminal() {
    local out
    out="$(ui_progress 5 10 "Working")"
    assert_equals "" "$out" "progress: prints nothing when stdout is not a tty"
}

test_change_shows_old_and_new() {
    local out; out="$(ui_change "old name.mp4" "[New] name.mp4" | _strip)"
    assert_contains "old name.mp4" "$out" "change: shows the old name"
    assert_contains "[New] name.mp4" "$out" "change: shows the new name"
    assert_contains "$UI_ARROW [New]" "$out" "change: new name follows an arrow"
}

test_summary_card_success_and_rows() {
    COLUMNS=100
    local out; out="$(ui_summary_card "Rename Files" "0m 3s" 0 "Files renamed" 4 "Files skipped" 1 | _strip)"
    assert_contains "Complete" "$out" "card: success title"
    assert_contains "Rename Files" "$out" "card: operation name"
    assert_contains "0m 3s" "$out" "card: duration"
    assert_contains "Files renamed" "$out" "card: stat label"
}

test_summary_card_reports_errors() {
    COLUMNS=100
    local out; out="$(ui_summary_card "Op" "0m 1s" 2 "Errors" 2 | _strip)"
    assert_contains "Done with 2 error(s)" "$out" "card: error count in the title"
}

test_summary_card_without_stats() {
    COLUMNS=100
    local out; out="$(ui_summary_card "Op" "0m 1s" 0 | _strip)"
    assert_contains "Nothing to report" "$out" "card: says so when there are no statistics"
}

test_summary_card_rows_fill_the_width() {
    COLUMNS=100
    local line bad=0
    while IFS= read -r line; do
        [[ "${#line}" -eq "$UI_MAX_WIDTH" ]] || bad=1
    done < <(ui_summary_card "Rename Files" "0m 3s" 1 "Errors" 1 | _strip)
    assert_equals "0" "$bad" "card: every line is exactly the box width"
}

test_operation_start_shows_dry_run() {
    local out
    out="$(DRY_RUN=true ui_operation_start "Rename" | _strip)"
    assert_contains "Rename" "$out" "start: shows the operation name"
    assert_contains "DRY RUN" "$out" "start: flags dry run"
    out="$(DRY_RUN=false ui_operation_start "Rename" | _strip)"
    [[ "$out" != *"DRY RUN"* ]]; assert_equals "0" "$?" "start: no dry-run flag when off"
}

test_file_header_shows_counter_eta_and_bar() {
    COLUMNS=100
    local out; out="$(ui_file_header "Show S01E02.mkv" 3 10 "2m5s" "base - cpu" | _strip)"
    assert_contains "Show S01E02.mkv" "$out" "file_header: item name"
    assert_contains "[3/10]" "$out" "file_header: counter"
    assert_contains "ETA 2m5s" "$out" "file_header: ETA"
    assert_contains " 20%" "$out" "file_header: bar shows the items finished before this one"
    assert_contains "base - cpu" "$out" "file_header: info line"
}

test_file_header_without_total_has_no_bar() {
    local out; out="$(ui_file_header "a.mkv" 0 0 "" "info" | _strip)"
    assert_contains "a.mkv" "$out" "file_header: name without a total"
    [[ "$out" != *"%"* ]]; assert_equals "0" "$?" "file_header: no percentage without a total"
}

test_progress_break_is_silent_off_a_terminal_with_theme() {
    local out; out="$(progress_break)"
    assert_equals "" "$out" "progress_break: nothing printed off a tty when themed"
}

test_progress_break_plain_fallback_prints_newline() {
    local out
    out="$(bash -c 'source "'"$LIB_DIR"'/core.sh"; progress_break' | wc -c)"
    assert_equals "1" "$(( out ))" "progress_break: a newline without the theme"
}

test_dup_group_and_lines() {
    local out
    out="$( { ui_dup_group 2 3 "1.0MiB"; ui_dup_line keep "a/one.mp4"; ui_dup_line extra "b/two.mp4"; } | _strip)"
    assert_contains "Group 2" "$out" "dup: group number"
    assert_contains "3 copies" "$out" "dup: copy count"
    assert_contains "keep  a/one.mp4" "$out" "dup: the kept file"
    assert_contains "extra b/two.mp4" "$out" "dup: the extra copy"
}
