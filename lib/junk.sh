#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - JUNK FILE MODULE
#
# Finds leftover files around a video collection (torrent .nfo files, .url
# links, Thumbs.db ...) and, on request, moves them to the trash so Undo can
# put them back. Reports only unless told to apply.
#
# Settings (see core.sh, saved in config profiles):
#   JUNK_EXTENSIONS          Comma-separated extensions that count as junk
#   JUNK_NAMES               Comma-separated exact file names that count as junk
#   JUNK_INCLUDE_PARTIAL     Also treat unfinished downloads as junk
#   JUNK_PARTIAL_EXTENSIONS  Extensions of unfinished downloads
#
# Dependencies: core.sh, logging.sh, utils.sh
# Module: junk.sh
#
################################################################################

# Report (and optionally trash) junk files under a directory
# Args: $1 - directory, $2 - apply (true = move to trash; default false)
# Returns: 0
clean_junk() {
    local directory="${1%/}" apply="${2:-false}"
    [[ -z "$directory" ]] && directory="/"

    local -A ext_set=() name_set=()
    local -a parts=() found=() sizes=()
    local item
    IFS=',' read -ra parts <<< "${JUNK_EXTENSIONS:-}"
    for item in "${parts[@]}"; do
        item="${item// /}"; item="${item#.}"; item="${item,,}"
        [[ -n "$item" ]] && ext_set["$item"]=1
    done
    if [[ "$JUNK_INCLUDE_PARTIAL" == true ]]; then
        IFS=',' read -ra parts <<< "${JUNK_PARTIAL_EXTENSIONS:-}"
        for item in "${parts[@]}"; do
            item="${item// /}"; item="${item#.}"; item="${item,,}"
            [[ -n "$item" ]] && ext_set["$item"]=1
        done
    fi
    IFS=',' read -ra parts <<< "${JUNK_NAMES:-}"
    for item in "${parts[@]}"; do
        item="${item,,}"
        [[ -n "$item" ]] && name_set["$item"]=1
    done

    log_info "Looking for junk files in: $directory"

    local file base lower ext total_bytes=0 size
    while IFS= read -r -d '' file; do
        base="${file##*/}"
        lower="${base,,}"
        ext=""
        [[ "$lower" == *.* ]] && ext="${lower##*.}"
        if [[ -n "${name_set[$lower]:-}" || ( -n "$ext" && -n "${ext_set[$ext]:-}" ) ]]; then
            size=$(get_file_size "$file")
            found+=("$file")
            sizes+=("${size:-0}")
            total_bytes=$(( total_bytes + ${size:-0} ))
        fi
    done < <(find "$directory" -type f ! -path '*/.vmgr-trash/*' -print0 | sort -z)

    echo ""
    if [[ ${#found[@]} -eq 0 ]]; then
        echo -e "${COLOR_BOLD}No junk files found.${COLOR_RESET}"
        return 0
    fi

    local i
    for i in "${!found[@]}"; do
        printf '  %9s  %s\n' "$(format_bytes "${sizes[$i]}")" "${found[$i]#"$directory"/}"
    done
    echo ""
    echo -e "${COLOR_BOLD}${#found[@]} junk files, $(format_bytes "$total_bytes")${COLOR_RESET}"

    if [[ "$apply" != true ]]; then
        echo -e "${COLOR_YELLOW}Report only. Run again with --apply to move them to the trash (Undo restores them).${COLOR_RESET}"
        return 0
    fi

    local stamp moved=0 failed=0
    stamp="$(date +%Y%m%d-%H%M%S)"
    for file in "${found[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would move to trash: ${file#"$directory"/}"
        elif trash_file "$file" "$directory" "$stamp"; then
            ((moved++))
        else
            ((failed++))
            log_error "Could not move to trash: $file"
        fi
    done
    if [[ "$DRY_RUN" != true ]]; then
        local note=""
        (( failed > 0 )) && note=", $failed failed"
        echo -e "${COLOR_BOLD}Moved $moved to the trash${note}.${COLOR_RESET} Undo with the Utilities menu or --undo-organize."
        STATS[files_trashed]=$(( ${STATS[files_trashed]:-0} + moved ))
    fi
    return 0
}

# Module loaded successfully
return 0
