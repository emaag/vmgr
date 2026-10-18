#!/usr/bin/env bash
#
# VIDEO MANAGER ULTIMATE - DIRECTORY BROWSER MODULE
# Arrow-key directory picker with folder previews, recent directories, and
# tab-completed path entry. Falls back to a plain prompt when not on a TTY.
#
# Dependencies: core.sh (colors), theme.sh (frame and hint helpers),
#               utils.sh (is_video_file, validate_directory)
#

BROWSER_RECENT_FILE="${BROWSER_RECENT_FILE:-$HOME/.video-manager-recent-dirs}"
BROWSER_RECENT_MAX=10
_BROWSER_REV=$'\033[7m'

################################################################################
# DATA HELPERS
################################################################################

# Print subdirectory names of $1 (one per line, case-insensitive sort).
# $2 = 1 to include hidden directories. Symlinks (and Windows junctions, which
# WSL reports as symlinks) are skipped: they only duplicate other folders.
browser_list_subdirs() {
    local dir="$1" show_hidden="${2:-0}" entry
    local restore
    restore="$(shopt -p nullglob dotglob)"
    shopt -s nullglob
    [[ "$show_hidden" == "1" ]] && shopt -s dotglob

    for entry in "$dir"/*/; do
        entry="${entry%/}"
        [[ -L "$entry" ]] && continue
        echo "${entry##*/}"
    done | LC_ALL=C sort -f

    eval "$restore"
}

# Print the number of video files directly inside $1.
browser_count_videos() {
    local dir="$1" f n=0
    local restore
    restore="$(shopt -p nullglob)"
    shopt -s nullglob

    for f in "$dir"/*; do
        if [[ -f "$f" ]] && is_video_file "$f"; then
            n=$(( n + 1 ))
        fi
    done

    eval "$restore"
    echo "$n"
}

# Print names of video files directly inside $1 (one per line, sorted).
browser_list_videos() {
    local dir="$1" f
    local restore
    restore="$(shopt -p nullglob)"
    shopt -s nullglob

    for f in "$dir"/*; do
        if [[ -f "$f" ]] && is_video_file "$f"; then
            echo "${f##*/}"
        fi
    done | LC_ALL=C sort -f

    eval "$restore"
}

# Print recent directories, most recent first, skipping ones that no longer exist.
browser_recent_list() {
    [[ -f "$BROWSER_RECENT_FILE" ]] || return 0
    local d
    while IFS= read -r d; do
        [[ -n "$d" && -d "$d" ]] && echo "$d"
    done < "$BROWSER_RECENT_FILE"
    return 0
}

# Record $1 as the most recently used directory (deduplicated, capped).
browser_recent_add() {
    local dir="$1" tmp
    [[ -n "$dir" ]] || return 0
    tmp="$(mktemp 2>/dev/null)" || return 0
    {
        echo "$dir"
        browser_recent_list | grep -Fxv -- "$dir" || true
    } | head -n "$BROWSER_RECENT_MAX" > "$tmp"
    mv "$tmp" "$BROWSER_RECENT_FILE" 2>/dev/null || rm -f "$tmp"
    return 0
}

################################################################################
# LISTING CACHE
################################################################################
# Directory listings are cached per (directory, hidden-flag) and validated
# against the directory's mtime, so revisiting a folder or moving the cursor
# over it costs one stat instead of a re-scan. Entries are filled in the
# current shell (never inside $(...)) so the cache survives between calls.

BROWSER_CACHE_MAX=200
declare -gA BROWSER_CACHE_MTIME=()
declare -gA BROWSER_CACHE_SUBS=()
declare -gA BROWSER_CACHE_VIDS=()
BROWSER_CACHE_HITS=0
BROWSER_CACHE_MISSES=0
BROWSER_SUBS=()
BROWSER_VIDS=()

# Drop every cached listing (used by the browser's refresh key).
browser_cache_clear() {
    BROWSER_CACHE_MTIME=()
    BROWSER_CACHE_SUBS=()
    BROWSER_CACHE_VIDS=()
}

# Print $1's modification time in epoch seconds (GNU stat, then BSD stat).
_browser_mtime() {
    stat -L -c %Y "$1" 2>/dev/null || stat -L -f %m "$1" 2>/dev/null
}

# Fill BROWSER_SUBS (subfolder names) and BROWSER_VIDS (video file names) for
# directory $1; $2 = 1 to include hidden folders. Served from cache when the
# directory's mtime is unchanged.
browser_dir_entries() {
    local dir="$1" hidden="${2:-0}" key mtime
    key="$dir|$hidden"
    mtime="$(_browser_mtime "$dir")"

    if [[ -n "$mtime" && "${BROWSER_CACHE_MTIME[$key]-}" == "$mtime" ]]; then
        BROWSER_CACHE_HITS=$(( BROWSER_CACHE_HITS + 1 ))
    else
        BROWSER_CACHE_MISSES=$(( BROWSER_CACHE_MISSES + 1 ))
        if (( ${#BROWSER_CACHE_MTIME[@]} >= BROWSER_CACHE_MAX )); then
            browser_cache_clear
        fi
        BROWSER_CACHE_SUBS[$key]="$(browser_list_subdirs "$dir" "$hidden")"
        BROWSER_CACHE_VIDS[$key]="$(browser_list_videos "$dir")"
        # No mtime (stat failed) means never trust the entry on the next call
        BROWSER_CACHE_MTIME[$key]="$mtime"
    fi

    BROWSER_SUBS=(); BROWSER_VIDS=()
    [[ -n "${BROWSER_CACHE_SUBS[$key]}" ]] && mapfile -t BROWSER_SUBS <<< "${BROWSER_CACHE_SUBS[$key]}"
    [[ -n "${BROWSER_CACHE_VIDS[$key]}" ]] && mapfile -t BROWSER_VIDS <<< "${BROWSER_CACHE_VIDS[$key]}"
    return 0
}

################################################################################
# INTERACTIVE BROWSER
################################################################################

# Read one keypress into the variable named $1. Arrow keys and friends come
# back as UP DOWN LEFT RIGHT PGUP PGDN ENTER ESC; anything else as the char.
_browser_read_key() {
    local _key _seq="" _extra
    IFS= read -rsn1 _key || return 1

    case "$_key" in
        $'\033')
            IFS= read -rsn2 -t 0.05 _seq || true
            case "$_seq" in
                '[A') _key=UP ;;
                '[B') _key=DOWN ;;
                '[C') _key=RIGHT ;;
                '[D') _key=LEFT ;;
                'OA') _key=UP ;;
                'OB') _key=DOWN ;;
                'OC') _key=RIGHT ;;
                'OD') _key=LEFT ;;
                'OH'|'[H') _key=HOME ;;
                'OF'|'[F') _key=END ;;
                '[5'|'[6')
                    IFS= read -rsn1 -t 0.05 _extra || true
                    [[ "$_seq" == '[5' ]] && _key=PGUP || _key=PGDN
                    ;;
                '[1'|'[4')
                    IFS= read -rsn1 -t 0.05 _extra || true
                    [[ "$_seq" == '[1' ]] && _key=HOME || _key=END
                    ;;
                '[2'|'[3')
                    IFS= read -rsn1 -t 0.05 _extra || true
                    _key=OTHER
                    ;;
                '') _key=ESC ;;
                *) _key=OTHER ;;
            esac
            ;;
        '') _key=ENTER ;;
        $'\177'|$'\b') _key=LEFT ;;
    esac

    printf -v "$1" '%s' "$_key"
}

# Move the browser to directory $1. Relies on the caller's (dynamically
# scoped) locals: current_dir, prev_dir, sel, top, reload.
_browser_goto() {
    local target
    target="$(cd "$1" 2>/dev/null && pwd)" || return 1
    [[ "$target" == //* && "$target" != ///* ]] && target="/${target#//}"
    [[ "$target" == "$current_dir" ]] && return 0
    prev_dir="$current_dir"
    current_dir="$target"
    sel=0
    top=0
    reload=1
}

# Pick from recent directories; echoes the chosen path (nothing if cancelled).
_browser_pick_recent() {
    local -a recent=()
    mapfile -t recent < <(browser_recent_list)

    printf '\033[H\033[J' >&2
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}RECENT DIRECTORIES${COLOR_RESET}" >&2
    echo "" >&2
    if [[ ${#recent[@]} -eq 0 ]]; then
        echo "  (none yet)" >&2
    else
        local i
        for (( i = 0; i < ${#recent[@]} && i < 9; i++ )); do
            echo -e "  ${COLOR_BRIGHT_GREEN}[$(( i + 1 ))]${COLOR_RESET} ${recent[$i]}" >&2
        done
    fi
    echo "" >&2
    echo -e "  Press a number to jump there, any other key to go back" >&2

    local key
    _browser_read_key key || return 0
    if [[ "$key" =~ ^[1-9]$ ]] && (( key <= ${#recent[@]} )); then
        echo "${recent[$(( key - 1 ))]}"
    fi
}

# Pad $1 with spaces to $2 characters (printf widths count bytes, not
# characters). Result goes into the variable named $3, not stdout, so the
# redraw loop forks nothing.
_browser_pad() {
    local _text="$1" _n=$(( $2 - ${#1} ))
    (( _n > 0 )) && printf -v _text '%s%*s' "$_text" "$_n" ""
    printf -v "$3" '%s' "$_text"
}

# Truncate $1 to $2 characters, ending in "…" when cut. Result goes into the
# variable named $3.
_browser_fit() {
    local _text="$1" _width="$2"
    if (( ${#_text} > _width )); then
        if (( _width < 1 )); then _text=""; else _text="${_text:0:_width-1}…"; fi
    fi
    printf -v "$3" '%s' "$_text"
}

# Fill rtext/rkind (caller's locals) with the preview pane for directory $1:
# a "Folders" section then a "Videos" section. kinds: h heading, d folder,
# v video, m muted note, b blank.
_browser_build_preview() {
    local dir="$1" show_hidden="$2" name
    local -a subs vids
    rtext=(); rkind=()
    browser_dir_entries "$dir" "$show_hidden"
    subs=("${BROWSER_SUBS[@]}")
    vids=("${BROWSER_VIDS[@]}")

    if (( ${#subs[@]} == 0 && ${#vids[@]} == 0 )); then
        rkind+=(m); rtext+=("(no folders or videos)")
        return
    fi
    if (( ${#subs[@]} > 0 )); then
        rkind+=(h); rtext+=("Folders (${#subs[@]})")
        for name in "${subs[@]}"; do rkind+=(d); rtext+=("$name/"); done
    fi
    if (( ${#vids[@]} > 0 )); then
        (( ${#subs[@]} > 0 )) && { rkind+=(b); rtext+=(""); }
        rkind+=(h); rtext+=("Videos (${#vids[@]})")
        for name in "${vids[@]}"; do rkind+=(v); rtext+=("$name"); done
    fi
}

_browser_interactive() {
    local current_dir="$1" prev_dir="" show_hidden=0
    local -a dirs=()
    local sel=0 top=0 reload=1 key msg="" n_videos=0 rows cols visible count i
    local preview_path="" rtext=() rkind=() resized=1 first_screen=1
    trap 'resized=1' WINCH

    printf '\033[2J'

    while true; do
        if (( reload )); then
            browser_dir_entries "$current_dir" "$show_hidden"
            dirs=("${BROWSER_SUBS[@]}")
            n_videos=${#BROWSER_VIDS[@]}
            reload=0
            preview_path=""
            # Nothing to browse here on the first screen: say how to get somewhere
            if (( first_screen && ${#dirs[@]} == 0 && n_videos == 0 )); then
                msg="Nothing here yet. Press T to type a path, or ← to go up."
            fi
            first_screen=0
        fi

        count=${#dirs[@]}
        (( sel >= count )) && sel=$(( count > 0 ? count - 1 : 0 ))

        if (( resized )); then
            rows="$(tput lines 2>/dev/null || echo 24)"
            cols="$(tput cols 2>/dev/null || echo 80)"
            resized=0
            printf '\033[2J'
        fi
        visible=$(( rows - 12 ))
        (( visible < 3 )) && visible=3
        (( sel < top )) && top=$sel
        (( sel >= top + visible )) && top=$(( sel - visible + 1 ))

        # Pane widths: two columns when there is room, otherwise just the list
        local two_col=0 lw rw
        if (( cols >= 70 )); then
            two_col=1
            lw=$(( (cols - 3) * 2 / 5 ))
            rw=$(( cols - 3 - lw - 1 ))
        else
            lw=$(( cols - 2 ))
            rw=0
        fi

        # Preview pane follows the highlighted folder (cached until it changes)
        if (( two_col )); then
            local pp="$current_dir"
            (( count > 0 )) && pp="$current_dir/${dirs[$sel]}"
            if [[ "$pp" != "$preview_path" ]]; then
                _browser_build_preview "$pp" "$show_hidden"
                preview_path="$pp"
            fi
        fi

        # Keys already queued (held arrow, fast typing): handle them first and
        # paint once at the end instead of once per key.
        if (( ! reload )) && IFS= read -rs -t 0 -n 0 2>/dev/null; then
            :
        else
        # ── Draw (repaint in place; no clear, so no flicker) ────────────────
        # Frame width follows the terminal so the box lines up with the panes
        local UI_MAX_WIDTH=$(( cols > 140 ? 140 : cols ))
        local hid_plain hid_styled loc here_plain
        if (( show_hidden )); then
            hid_plain="${UI_DOT_ON} hidden shown"; hid_styled="${UI_WARN}${hid_plain}${COLOR_RESET}"
        else
            hid_plain="${UI_DOT_OFF} hidden off"; hid_styled="${UI_DIM}${hid_plain}${COLOR_RESET}"
        fi
        here_plain="${count} folder(s) ${UI_SEP} ${n_videos} video(s)"
        _ui_short_path "$current_dir" $(( UI_MAX_WIDTH - 6 - ${#hid_plain} )) loc

        printf '\033[H'
        ui_box_top "SELECT DIRECTORY"
        ui_box_row "$loc" "${COLOR_WHITE}${loc}${COLOR_RESET}" "$hid_plain" "$hid_styled"
        ui_box_row "$here_plain" "${UI_DIM}${here_plain}${COLOR_RESET}" "" ""
        ui_box_bottom

        local head_l head_r
        local head_txt="FOLDERS"
        (( top > 0 )) && head_txt="FOLDERS  ↑ ${top} above"
        _browser_fit "$head_txt" "$lw" head_l
        if (( two_col )); then
            if (( count > 0 )); then
                _browser_fit "PREVIEW  ${dirs[$sel]}/" "$rw" head_r
            else
                _browser_fit "PREVIEW" "$rw" head_r
            fi
            _browser_pad "$head_l" "$lw" head_l
            printf '%s%s%s %s│%s %s%s%s\033[K\n' "$UI_TITLE" "$head_l" "$COLOR_RESET" "$UI_DIM" "$COLOR_RESET" "$UI_TITLE" "$head_r" "$COLOR_RESET"
        else
            printf '%s%s%s\033[K\n' "$UI_TITLE" "$head_l" "$COLOR_RESET"
        fi

        # Grid rows: visible items, then a down-indicator row
        local grid=$(( visible + 1 )) r idx ltxt lcell rcell rk rt
        local rn=${#rtext[@]} hl="${UI_CHIP:-$_BROWSER_REV}"
        for (( r = 0; r < grid; r++ )); do
            # left cell
            ltxt=""; lcell=""
            idx=$(( top + r ))
            if (( r == grid - 1 )); then
                (( top + visible < count )) && ltxt="  ↓ $(( count - top - visible )) more"
                _browser_pad "$ltxt" "$lw" ltxt
                lcell="${UI_DIM}${ltxt}${COLOR_RESET}"
            elif (( count == 0 )); then
                (( r == 0 )) && ltxt="  (no subdirectories)"
                _browser_pad "$ltxt" "$lw" ltxt
                lcell="${UI_DIM}${ltxt}${COLOR_RESET}"
            elif (( idx < count )); then
                if (( idx == sel )); then
                    _browser_fit "${UI_PROMPT} ${dirs[$idx]}/" "$lw" ltxt
                    _browser_pad "$ltxt" "$lw" ltxt
                    lcell="${hl}${ltxt}${COLOR_RESET}"
                else
                    _browser_fit "  ${dirs[$idx]}/" "$lw" ltxt
                    _browser_pad "$ltxt" "$lw" ltxt
                    lcell="${COLOR_WHITE}${ltxt}${COLOR_RESET}"
                fi
            else
                _browser_pad "" "$lw" lcell
            fi

            # right cell
            rcell=""
            if (( two_col )); then
                rk=""; rt=""
                if (( rn > grid && r == grid - 1 )); then
                    rk=m; rt="… $(( rn - grid + 1 )) more"
                elif (( r < rn )); then
                    rk="${rkind[$r]}"; rt="${rtext[$r]}"
                fi
                _browser_fit "$rt" "$rw" rt
                case "$rk" in
                    h) rcell="${UI_TITLE}${rt}${COLOR_RESET}" ;;
                    d) rcell="${UI_ACCENT}${rt}${COLOR_RESET}" ;;
                    v) rcell="${UI_OK}${rt}${COLOR_RESET}" ;;
                    m) rcell="${UI_DIM}${rt}${COLOR_RESET}" ;;
                    *) rcell="$rt" ;;
                esac
                printf '%s %s│%s %s\033[K\n' "$lcell" "$UI_DIM" "$COLOR_RESET" "$rcell"
            else
                printf '%s\033[K\n' "$lcell"
            fi
        done

        ui_hint_line "↑↓" "move" "→" "open" "←" "up" "Home/End" "first/last" "PgUp/PgDn" "page"
        ui_hint_line "Enter" "choose highlighted" "S" "choose this location" "Q" "cancel"
        ui_hint_line "~" "home" "-" "previous" "R" "recent" "T" "type path" "." "hidden" "F" "refresh"
        printf '%s%s%s\033[K' "${UI_WARN}" "${msg}" "${COLOR_RESET}"
        printf '\033[J'
        msg=""
        fi

        # ── Input ───────────────────────────────────────────────────────────
        _browser_read_key key || return 1

        case "$key" in
            UP|k)   (( sel > 0 )) && sel=$(( sel - 1 )) ;;
            DOWN|j) (( sel < count - 1 )) && sel=$(( sel + 1 )) ;;
            HOME)   sel=0 ;;
            END)    sel=$(( count > 0 ? count - 1 : 0 )) ;;
            PGUP)   sel=$(( sel - visible )); (( sel < 0 )) && sel=0 ;;
            PGDN)   sel=$(( sel + visible )); (( sel > count - 1 )) && sel=$(( count > 0 ? count - 1 : 0 )) ;;
            RIGHT|l)
                if (( count > 0 )); then
                    _browser_goto "$current_dir/${dirs[$sel]}" || msg="Cannot open ${dirs[$sel]}/"
                fi
                ;;
            ENTER)
                # Choose the highlighted folder; with none, choose this one
                if (( count > 0 )); then
                    TARGET_FOLDER="$current_dir/${dirs[$sel]}"
                else
                    TARGET_FOLDER="$current_dir"
                fi
                browser_recent_add "$TARGET_FOLDER"
                return 0
                ;;
            LEFT|h)
                local parent
                parent="$(dirname "$current_dir")"
                if [[ "$parent" != "$current_dir" ]]; then
                    local came_from="${current_dir##*/}"
                    _browser_goto "$parent"
                    # Re-highlight the folder we just left
                    browser_dir_entries "$current_dir" "$show_hidden"
                    dirs=("${BROWSER_SUBS[@]}")
                    for (( i = 0; i < ${#dirs[@]}; i++ )); do
                        [[ "${dirs[$i]}" == "$came_from" ]] && { sel=$i; break; }
                    done
                fi
                ;;
            s|S|' ')
                TARGET_FOLDER="$current_dir"
                browser_recent_add "$current_dir"
                return 0
                ;;
            q|Q|c|C|ESC)
                return 1
                ;;
            f|F)
                browser_cache_clear
                reload=1; preview_path=""
                msg="Refreshed"
                ;;
            '.')
                show_hidden=$(( 1 - show_hidden ))
                sel=0; top=0; reload=1
                ;;
            '~')
                _browser_goto "$HOME" || msg="Home directory not available"
                ;;
            '-')
                if [[ -n "$prev_dir" ]]; then
                    _browser_goto "$prev_dir" || msg="Previous directory is gone"
                else
                    msg="No previous directory yet"
                fi
                ;;
            r|R)
                local picked
                picked="$(_browser_pick_recent)"
                [[ -n "$picked" ]] && { _browser_goto "$picked" || msg="Directory not found: $picked"; }
                printf '\033[2J'
                ;;
            t|T|/)
                local typed validated
                printf '\n\033[?25h'
                IFS= read -e -r -p "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Path: " -i "$current_dir/" typed
                printf '\033[?25l'
                typed="${typed/#\~/$HOME}"
                if [[ -n "$typed" ]]; then
                    if validated="$(validate_directory "$typed" 2>/dev/null)" && _browser_goto "$validated"; then
                        :
                    else
                        msg="Directory not found: $typed"
                    fi
                fi
                printf '\033[2J'
                ;;
        esac
    done
}

# Plain prompt for non-interactive terminals (pipes, CI, dumb terminals).
_browser_simple() {
    local current_dir="$1" typed validated
    echo -n "Directory [${current_dir}]: "
    IFS= read -r typed || return 1
    if [[ -z "$typed" ]]; then
        validated="$current_dir"
    else
        typed="${typed/#\~/$HOME}"
        validated="$(validate_directory "$typed" 2>/dev/null)" || {
            echo "Directory not found."
            return 1
        }
    fi
    TARGET_FOLDER="$validated"
    browser_recent_add "$validated"
    return 0
}

# Where the Windows user profiles live when running under WSL (overridable for tests).
BROWSER_WIN_USERS_DIR="${BROWSER_WIN_USERS_DIR:-/mnt/c/Users}"

# Best folder to open the browser in when nothing was asked for: the most recent
# directory, then a Videos / Movies folder, then (under WSL) a Windows user's
# Videos folder, then home.
browser_default_start() {
    local d c
    d="$(browser_recent_list | head -n1)"
    if [[ -n "$d" && -d "$d" ]]; then echo "$d"; return; fi

    for c in "$HOME/Videos" "$HOME/Movies"; do
        if [[ -d "$c" ]]; then echo "$c"; return; fi
    done

    if [[ -d "$BROWSER_WIN_USERS_DIR" ]]; then
        for c in "$BROWSER_WIN_USERS_DIR/${USER:-}/Videos" "$BROWSER_WIN_USERS_DIR"/*/Videos; do
            case "$c" in */Public/*|*/Default*/*|*"/All Users/"*) continue ;; esac
            if [[ -d "$c" ]]; then echo "$c"; return; fi
        done
    fi

    echo "$HOME"
}

# Interactive directory browser. Sets TARGET_FOLDER and returns 0 on select,
# returns 1 on cancel. Optional $1 = starting directory.
browse_directory() {
    local start="${1:-${TARGET_FOLDER:-}}"
    [[ -z "$start" ]] && start="$(browser_default_start)"

    local current_dir
    current_dir="$(cd "$start" 2>/dev/null && pwd)" || current_dir="$HOME"
    [[ "$current_dir" == //* && "$current_dir" != ///* ]] && current_dir="/${current_dir#//}"

    if [[ ! -t 0 || ! -t 1 ]]; then
        _browser_simple "$current_dir"
        return $?
    fi

    # Keep the tty non-canonical for the whole session. `read -n` only does that
    # while it runs, so a key arriving mid-redraw would otherwise be handled by
    # the line discipline (a backspace is swallowed as "erase").
    local saved_tty
    saved_tty="$(stty -g 2>/dev/null)" || saved_tty=""
    [[ -n "$saved_tty" ]] && stty -icanon -echo min 1 time 0 2>/dev/null

    printf '\033[?25l'
    _browser_interactive "$current_dir"
    local rc=$?
    [[ -n "$saved_tty" ]] && stty "$saved_tty" 2>/dev/null
    trap - WINCH
    printf '\033[?25h\033[2J\033[H'
    return $rc
}
