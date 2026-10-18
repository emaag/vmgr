#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - THEME MODULE
#
# Shared look-and-feel helpers for the interactive menus: palette, boxed
# header pieces, menu items, status chips and single-keypress input.
#
# Modern output (256 colors, box drawing) is used when the terminal supports it.
# NO_COLOR / TERM=dumb drop every escape code (see core.sh) and a non-UTF-8
# locale or the linux console swaps the glyphs for ASCII.
#
# Module: theme.sh
# Dependencies: core.sh
#
################################################################################

# ── Palette ──────────────────────────────────────────────────────────────────
# 256-color when the terminal advertises it, otherwise the 16-color codes core.sh
# already defines. In plain mode (NO_COLOR) every one of these is empty.
if [[ -n "${_VM_NC+x}" ]]; then
    UI_ACCENT=""; UI_TITLE=""; UI_OK=""; UI_WARN=""; UI_ERR=""; UI_DIM=""
    UI_CHIP=""; UI_CHIP_TOGGLE=""; UI_CHIP_BACK=""
elif [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* || "${TERM:-}" == *256color* ]]; then
    UI_ACCENT=$'\033[38;5;81m'
    UI_TITLE=$'\033[1;38;5;222m'
    UI_OK=$'\033[38;5;114m'
    UI_WARN=$'\033[38;5;215m'
    UI_ERR=$'\033[38;5;203m'
    UI_DIM=$'\033[38;5;245m'
    UI_CHIP=$'\033[1;38;5;16;48;5;81m'
    UI_CHIP_TOGGLE=$'\033[1;38;5;16;48;5;215m'
    UI_CHIP_BACK=$'\033[1;38;5;16;48;5;245m'
else
    UI_ACCENT="$COLOR_BRIGHT_CYAN"
    UI_TITLE="$COLOR_BRIGHT_YELLOW"
    UI_OK="$COLOR_BRIGHT_GREEN"
    UI_WARN="$COLOR_YELLOW"
    UI_ERR="$COLOR_RED"
    UI_DIM=$'\033[2m'
    UI_CHIP=$'\033[1;30;46m'
    UI_CHIP_TOGGLE=$'\033[1;30;43m'
    UI_CHIP_BACK=$'\033[1;30;47m'
fi

# ── Glyphs ───────────────────────────────────────────────────────────────────
if (( _VM_ASCII )); then
    UI_TL="+"; UI_TR="+"; UI_BL="+"; UI_BR="+"; UI_H="-"; UI_V="|"
    UI_DOT_ON="*"; UI_DOT_OFF="o"; UI_BAR="|"; UI_PROMPT=">"; UI_ELLIPSIS="..."; UI_SEP="-"
    UI_BAR_FULL="#"; UI_BAR_EMPTY="-"; UI_ARROW="->"; UI_PLAY=">"; UI_WARN_MARK="!"
else
    UI_TL="╭"; UI_TR="╮"; UI_BL="╰"; UI_BR="╯"; UI_H="─"; UI_V="│"
    UI_DOT_ON="●"; UI_DOT_OFF="○"; UI_BAR="▍"; UI_PROMPT="❯"; UI_ELLIPSIS="…"; UI_SEP="·"
    UI_BAR_FULL="█"; UI_BAR_EMPTY="░"; UI_ARROW="→"; UI_PLAY="▶"; UI_WARN_MARK="⚠"
fi

UI_MAX_WIDTH=64
UI_LABEL_WIDTH=26

# ── Geometry ─────────────────────────────────────────────────────────────────

# Set UI_W to the box width: UI_MAX_WIDTH, or the terminal width if narrower.
_ui_measure() {
    local cols="${COLUMNS:-0}"
    (( cols > 0 )) || cols="$(tput cols 2>/dev/null || echo 80)"
    UI_W=$UI_MAX_WIDTH
    (( cols < UI_W )) && UI_W=$cols
    (( UI_W < 30 )) && UI_W=30
    return 0
}

# Repeat string $1 $2 times into variable $3 (no subshell).
_ui_repeat() {
    local out="" i
    for (( i = 0; i < $2; i++ )); do out+="$1"; done
    printf -v "$3" '%s' "$out"
}

# Shorten path $1 to at most $2 characters: ~ for $HOME, leading … when cut.
# Result goes into the variable named $3.
_ui_short_path() {
    local p="$1" max="$2"
    [[ -n "${HOME:-}" && "$p" == "$HOME"* ]] && p="~${p#"$HOME"}"
    if (( ${#p} > max )); then
        p="${UI_ELLIPSIS}${p: -$(( max - ${#UI_ELLIPSIS} ))}"
    fi
    printf -v "$3" '%s' "$p"
}

# ── Boxes ────────────────────────────────────────────────────────────────────

# ui_box_top / ui_box_bottom: the frame edges, in the accent color.
ui_box_top() {
    local rule label=""
    _ui_measure
    if [[ -n "${1:-}" ]]; then
        label=" $1 "
        _ui_repeat "$UI_H" $(( UI_W - 3 - ${#label} )) rule
        printf '%s%s%s%s%s%s%s%s%s%s%s\n' "$UI_ACCENT" "$UI_TL" "$UI_H" "$COLOR_RESET" \
            "$UI_TITLE" "$label" "$COLOR_RESET" "$UI_ACCENT" "$rule" "$UI_TR" "$COLOR_RESET"
    else
        _ui_repeat "$UI_H" $(( UI_W - 2 )) rule
        printf '%s%s%s%s%s\n' "$UI_ACCENT" "$UI_TL" "$rule" "$UI_TR" "$COLOR_RESET"
    fi
}
ui_box_bottom() {
    local rule; _ui_measure; _ui_repeat "$UI_H" $(( UI_W - 2 )) rule
    printf '%s%s%s%s%s\n' "$UI_ACCENT" "$UI_BL" "$rule" "$UI_BR" "$COLOR_RESET"
}

# ui_box_row PLAIN_LEFT STYLED_LEFT PLAIN_RIGHT STYLED_RIGHT
# One framed row with text at both edges. The plain strings give the visible
# width (escape codes excluded); the styled strings are what gets printed.
ui_box_row() {
    local pl="$1" sl="$2" pr="$3" sr="$4" gap
    _ui_measure
    gap=$(( UI_W - 4 - ${#pl} - ${#pr} ))
    (( gap < 1 )) && gap=1
    printf '%s%s%s %s%*s%s %s%s%s\n' \
        "$UI_ACCENT" "$UI_V" "$COLOR_RESET" "$sl" "$gap" "" "$sr" \
        "$UI_ACCENT" "$UI_V" "$COLOR_RESET"
}

# ── Menu pieces ──────────────────────────────────────────────────────────────

# ui_title TEXT: section heading with an accent bar.
ui_title() {
    printf '  %s%s%s %s%s%s\n\n' "$UI_ACCENT" "$UI_BAR" "$COLOR_RESET" "$UI_TITLE" "$1" "$COLOR_RESET"
}

# ui_section TEXT: small dim label above a group of items.
ui_section() {
    printf '  %s%s%s\n' "$UI_DIM" "$1" "$COLOR_RESET"
}

# ui_item KEY LABEL [DESC] [KIND]
# One selectable row. KIND: default | toggle | back. The key is drawn as a
# colored chip, or as [K] when colors are off.
ui_item() {
    local key="$1" label="$2" desc="${3:-}" kind="${4:-default}" chip
    case "$kind" in
        toggle) chip="$UI_CHIP_TOGGLE" ;;
        back)   chip="$UI_CHIP_BACK" ;;
        *)      chip="$UI_CHIP" ;;
    esac
    if [[ -n "$chip" ]]; then
        printf '  %s %s %s  ' "$chip" "$key" "$COLOR_RESET"
    else
        printf '  [%s]  ' "$key"
    fi
    if [[ -n "$desc" ]]; then
        _ui_measure
        if (( 7 + UI_LABEL_WIDTH + 1 + ${#desc} > UI_W )); then
            # Too wide for one line: label here, description beneath it
            printf '%s%s%s\n       %s%s%s\n' "$COLOR_BOLD" "$label" "$COLOR_RESET" "$UI_DIM" "$desc" "$COLOR_RESET"
        else
            printf '%s%-*s%s %s%s%s\n' "$COLOR_BOLD" "$UI_LABEL_WIDTH" "$label" "$COLOR_RESET" "$UI_DIM" "$desc" "$COLOR_RESET"
        fi
    else
        printf '%s%s%s\n' "$COLOR_BOLD" "$label" "$COLOR_RESET"
    fi
}

# ui_item_toggle KEY LABEL STATE: an on/off row; STATE is "true" for on.
ui_item_toggle() {
    local state
    if [[ "$3" == true ]]; then
        state="${UI_OK}${UI_DOT_ON} ON${COLOR_RESET}"
    else
        state="${UI_DIM}${UI_DOT_OFF} OFF${COLOR_RESET}"
    fi
    ui_item "$1" "$2" "$state" toggle
}

# ui_hint_line KEY LABEL [KEY LABEL ...]: one footer line of key hints, with
# the keys in the accent color and their labels dimmed.
ui_hint_line() {
    local line=""
    while (( $# >= 2 )); do
        line+="${UI_ACCENT}${1}${COLOR_RESET} ${UI_DIM}${2}${COLOR_RESET}  "
        shift 2
    done
    printf '%s\033[K\n' "$line"
}

# ui_prompt [TEXT]: the line shown before a single keypress is read.
ui_prompt() {
    printf '\n  %s%s%s %s %s(press a key)%s ' \
        "$UI_ACCENT" "$UI_PROMPT" "$COLOR_RESET" "${1:-Select option}" "$UI_DIM" "$COLOR_RESET"
}

# ── Progress and results ─────────────────────────────────────────────────────

# ui_progress CURRENT TOTAL [LABEL] [DETAIL]: redraw one progress line in place
#   Processing  ████████░░░░░░░░  50%  (25/50)  current-file.mp4
# Does nothing when stdout is not a terminal, so logs and pipes stay clean.
# Call ui_progress_clear to wipe the line when you are done with it.
ui_progress() {
    [[ -t 1 ]] || return 0
    local current="$1" total="$2" label="${3:-Processing}" detail="${4:-}" pct width filled bar_on bar_off
    (( total > 0 )) || return 0
    (( current > total )) && current=$total
    _ui_measure
    pct=$(( current * 100 / total ))
    width=$(( UI_W - 36 ))
    (( width < 10 )) && width=10
    (( width > 30 )) && width=30
    filled=$(( pct * width / 100 ))
    _ui_repeat "$UI_BAR_FULL" "$filled" bar_on
    _ui_repeat "$UI_BAR_EMPTY" $(( width - filled )) bar_off
    [[ -n "$detail" ]] && detail="  ${detail:0:30}"
    printf '\r  %s%s%s  %s%s%s%s%s%s %3d%%  %s(%d/%d)%s%s\033[K' \
        "$UI_DIM" "$label" "$COLOR_RESET" \
        "$UI_ACCENT" "$bar_on" "$COLOR_RESET" "$UI_DIM" "$bar_off" "$COLOR_RESET" \
        "$pct" "$UI_DIM" "$current" "$total" "$detail" "$COLOR_RESET"
}

ui_progress_clear() { [[ -t 1 ]] && printf '\r\033[K'; return 0; }

# ui_file_header NAME INDEX TOTAL ETA INFO: header for one item in a long batch.
#   ▶ name.mp4  [3/10]  ETA 2m5s
#     ████████░░░░░░░░░░░░  20%   model base · cpu · srt
# INDEX is the item being started, so the bar shows the items finished before it.
ui_file_header() {
    local name="$1" idx="${2:-0}" total="${3:-0}" eta="${4:-}" info="${5:-}"
    local counter="" etatxt="" width=20 filled pct bar_on bar_off
    (( total > 0 )) && counter="  ${UI_TITLE}[${idx}/${total}]${COLOR_RESET}"
    [[ -n "$eta" ]] && etatxt="  ${UI_DIM}ETA ${COLOR_RESET}${UI_ACCENT}${eta}${COLOR_RESET}"
    printf '\n  %s%s%s %s%s%s%s%s\n' "$UI_ACCENT" "$UI_PLAY" "$COLOR_RESET" "$COLOR_BOLD" "$name" "$COLOR_RESET" "$counter" "$etatxt"
    if (( total > 0 )); then
        pct=$(( (idx - 1) * 100 / total ))
        (( pct < 0 )) && pct=0
        filled=$(( pct * width / 100 ))
        _ui_repeat "$UI_BAR_FULL" "$filled" bar_on
        _ui_repeat "$UI_BAR_EMPTY" $(( width - filled )) bar_off
        printf '    %s%s%s%s%s%s %3d%%   %s%s%s\n' "$UI_ACCENT" "$bar_on" "$COLOR_RESET" "$UI_DIM" "$bar_off" "$COLOR_RESET" "$pct" "$UI_DIM" "$info" "$COLOR_RESET"
    elif [[ -n "$info" ]]; then
        printf '    %s%s%s\n' "$UI_DIM" "$info" "$COLOR_RESET"
    fi
}

# ui_change OLD NEW [DRY]: a before/after pair on two lines. DRY is "true" to
# mark it as a preview rather than something that happened.
ui_change() {
    local mark="${UI_OK}${SYMBOL_CHECK}${COLOR_RESET}" arrow="${UI_OK}"
    if [[ "${3:-false}" == true ]]; then
        mark="${UI_WARN}${UI_DOT_OFF}${COLOR_RESET}"; arrow="${UI_WARN}"
    fi
    printf '  %s %s%s%s\n' "$mark" "$UI_DIM" "$1" "$COLOR_RESET"
    printf '    %s%s %s%s\n' "$arrow" "$UI_ARROW" "$2" "$COLOR_RESET"
}

# ui_operation_start NAME: banner at the top of a running operation.
ui_operation_start() {
    local rule badge=""
    _ui_measure
    _ui_repeat "$UI_H" $(( UI_W - 2 )) rule
    if [[ "${DRY_RUN:-false}" == true ]]; then
        if [[ -n "$UI_CHIP_TOGGLE" ]]; then
            badge="  ${UI_CHIP_TOGGLE} DRY RUN ${COLOR_RESET}"
        else
            badge="  [DRY RUN]"
        fi
    fi
    printf '\n  %s%s%s %s%s%s%s\n  %s%s%s\n\n' \
        "$UI_ACCENT" "$UI_PLAY" "$COLOR_RESET" "$COLOR_BOLD" "$1" "$COLOR_RESET" "$badge" \
        "$UI_DIM" "$rule" "$COLOR_RESET"
}

# ui_summary_card NAME DURATION ERRORS LABEL VALUE [LABEL VALUE ...]
# The end-of-operation card: a title that reflects success or errors, the
# operation and its duration, then one row per statistic. Pass pairs with a
# non-zero VALUE only; with none it says nothing changed.
ui_summary_card() {
    local name="$1" duration="$2" errors="$3" title label value
    shift 3
    if (( errors > 0 )); then
        title="${UI_WARN_MARK} Done with ${errors} error(s)"
    else
        title="${SYMBOL_CHECK} Complete"
    fi
    ui_box_top "$title"
    ui_box_row "$name" "${COLOR_BOLD}${name}${COLOR_RESET}" "$duration" "${UI_DIM}${duration}${COLOR_RESET}"
    if (( $# == 0 )); then
        ui_box_row "Nothing to report" "${UI_DIM}Nothing to report${COLOR_RESET}" "" ""
    fi
    while (( $# >= 2 )); do
        label="$1"; value="$2"; shift 2
        local color="$COLOR_WHITE"
        case "$label" in
            *rror*|*ailed*)   color="$UI_ERR" ;;
            *kipped*|*Low*)   color="$UI_WARN" ;;
            *)                color="$UI_OK" ;;
        esac
        ui_box_row "$label" "${UI_DIM}${label}${COLOR_RESET}" "$value" "${color}${value}${COLOR_RESET}"
    done
    ui_box_bottom
}

# ── Input ────────────────────────────────────────────────────────────────────

# ui_read_choice VAR: read one keypress into VAR, without waiting for Enter.
#   - Esc becomes "ESC"; Enter and arrow/function keys are ignored.
#   - Falls back to reading a whole line when stdin is not a terminal.
#   - Returns 1 on end of input, so callers can stop instead of spinning.
ui_read_choice() {
    local _k _c
    if [[ ! -t 0 ]]; then
        IFS= read -r _k || return 1
        printf -v "$1" '%s' "$_k"
        return 0
    fi
    while true; do
        IFS= read -rsn1 _k || return 1
        case "$_k" in
            $'\033')
                IFS= read -rsn1 -t 0.05 _c || { _k=ESC; break; }
                # Swallow the rest of an arrow/function-key sequence
                if [[ "$_c" == '[' || "$_c" == 'O' ]]; then
                    while IFS= read -rsn1 -t 0.05 _c; do
                        [[ "$_c" == [A-Za-z~] ]] && break
                    done
                fi
                continue
                ;;
            '') continue ;;
            *) break ;;
        esac
    done
    [[ "$_k" == ESC ]] || printf '%s' "$_k"
    printf '\n'
    printf -v "$1" '%s' "$_k"
}

# ui_ask VAR TEXT: prompt for a line of text into the variable named VAR.
# Leaves VAR empty at end of input.
ui_ask() {
    printf '  %s%s%s %s ' "$UI_ACCENT" "$UI_PROMPT" "$COLOR_RESET" "$2"
    IFS= read -r "$1" || printf -v "$1" '%s' ""
}

# ui_confirm QUESTION [DEFAULT]: single-keypress yes/no. DEFAULT is y or n
# (n if omitted) and is what Enter picks; Esc means no. Sets REPLY to y or n and
# returns 0 for yes. Reads a whole line when stdin is not a terminal.
ui_confirm() {
    local question="$1" default="${2:-n}" hint key answer _ui_c
    [[ "$default" == y ]] && hint="Y/n" || hint="y/N"
    printf '\n  %s%s%s %s %s[%s]%s ' "$UI_ACCENT" "$UI_PROMPT" "$COLOR_RESET" "$question" "$UI_DIM" "$hint" "$COLOR_RESET"

    if [[ ! -t 0 ]]; then
        IFS= read -r key || key=""
        key="${key:0:1}"
        [[ -z "$key" ]] && key="$default"
    else
        while true; do
            IFS= read -rsn1 key || { key="$default"; break; }
            case "$key" in
                [yY]) key=y; break ;;
                [nN]) key=n; break ;;
                '')   key="$default"; break ;;
                $'\033')
                    # A lone Esc means no; anything longer is an arrow key, ignore it
                    if IFS= read -rsn1 -t 0.05 _ui_c; then
                        while IFS= read -rsn1 -t 0.05 _ui_c; do
                            [[ "$_ui_c" == [A-Za-z~] ]] && break
                        done
                    else
                        key=n; break
                    fi
                    ;;
            esac
        done
    fi

    case "$key" in
        [yY]) answer=yes; REPLY=y ;;
        *)    answer=no;  REPLY=n ;;
    esac
    printf '%s%s%s\n' "$UI_DIM" "$answer" "$COLOR_RESET"
    [[ "$REPLY" == y ]]
}

# ui_pause [TEXT]: wait for any key (a line when stdin is not a terminal).
ui_pause() {
    local key
    printf '\n  %s%s%s ' "$UI_DIM" "${1:-Press any key to continue}" "$COLOR_RESET"
    if [[ -t 0 ]]; then
        IFS= read -rsn1 key || true
        if [[ "$key" == $'\033' ]]; then
            # Swallow the rest of an arrow/function-key sequence
            while IFS= read -rsn1 -t 0.05 key; do
                [[ "$key" == [A-Za-z~] ]] && break
            done
        fi
    else
        IFS= read -r key || true
    fi
    printf '\n'
}

return 0
