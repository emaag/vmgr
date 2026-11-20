#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - COVER ART MODULE
#
# Reports which folders have a cover image (folder.jpg by default) and which
# do not. Report only: nothing is created, moved or deleted.
#
# Settings (see core.sh, saved in config profiles):
#   COVER_FILENAMES        Comma-separated names that count as a cover
#   COVER_CASE_INSENSITIVE Match Folder.JPG, FOLDER.jpg ...
#   COVER_LEAF_ONLY        Only check folders with no subfolders
#   COVER_REQUIRE_VIDEOS   Only check folders that directly hold a video
#   COVER_SHOW_PRESENT     Also list the folders that already have a cover
#   COVER_REPORT_FILE      Also write the missing folders to this file
#
# Dependencies: core.sh, logging.sh, utils.sh
# Module: covers.sh
#
################################################################################

# Report folders under a directory that lack a cover image
# Args: $1 - directory to scan
# Returns: 0 (report only)
check_cover_art() {
    local directory="${1%/}"
    [[ -z "$directory" ]] && directory="/"

    local -a wanted=() all_dirs=() missing=() present=()
    local name
    IFS=',' read -ra wanted <<< "${COVER_FILENAMES:-folder.jpg}"
    local i
    for i in "${!wanted[@]}"; do
        name="${wanted[$i]// /}"
        [[ "$COVER_CASE_INSENSITIVE" == true ]] && name="${name,,}"
        wanted[$i]="$name"
    done

    log_info "Looking for ${COVER_FILENAMES:-folder.jpg} in: $directory"

    # One pass over directories, one over files (cheap on network shares)
    local -A has_cover=() has_video=() is_parent=()
    local dir file base
    while IFS= read -r -d '' dir; do
        all_dirs+=("$dir")
        is_parent["${dir%/*}"]=1
    done < <(find "$directory" -type d ! -path '*/.vmgr-trash*' -print0 | sort -z)

    while IFS= read -r -d '' file; do
        dir="${file%/*}"
        base="${file##*/}"
        [[ "$COVER_CASE_INSENSITIVE" == true ]] && base="${base,,}"
        for name in "${wanted[@]}"; do
            if [[ "$base" == "$name" ]]; then
                has_cover["$dir"]=1
                break
            fi
        done
        if [[ "$COVER_REQUIRE_VIDEOS" == true && -z "${has_video[$dir]:-}" ]]; then
            is_video_file "$file" && has_video["$dir"]=1
        fi
    done < <(find "$directory" -type f ! -path '*/.vmgr-trash*' -print0)

    local checked=0 skipped=0
    for dir in "${all_dirs[@]}"; do
        if [[ "$COVER_LEAF_ONLY" == true && -n "${is_parent[$dir]:-}" ]] ||
           [[ "$COVER_REQUIRE_VIDEOS" == true && -z "${has_video[$dir]:-}" ]]; then
            ((skipped++))
            continue
        fi
        ((checked++))
        if [[ -n "${has_cover[$dir]:-}" ]]; then
            present+=("$dir")
        else
            missing+=("$dir")
        fi
    done

    echo ""
    if [[ "$COVER_SHOW_PRESENT" == true && ${#present[@]} -gt 0 ]]; then
        echo -e "${COLOR_BOLD}${COLOR_GREEN}Folders WITH a cover:${COLOR_RESET}"
        printf '  %s\n' "${present[@]}"
        echo ""
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${COLOR_BOLD}${COLOR_YELLOW}Folders MISSING ${COVER_FILENAMES:-folder.jpg}:${COLOR_RESET}"
        printf '  %s\n' "${missing[@]}"
        echo ""
    fi

    if [[ -n "$COVER_REPORT_FILE" ]]; then
        if printf '%s\n' "${missing[@]}" > "$COVER_REPORT_FILE" 2>/dev/null; then
            log_info "Missing-cover list written to: $COVER_REPORT_FILE"
        else
            log_error "Could not write report: $COVER_REPORT_FILE"
        fi
    fi

    echo -e "${COLOR_BOLD}Checked $checked folders: ${#present[@]} with a cover, ${#missing[@]} missing (skipped $skipped)${COLOR_RESET}"
    return 0
}

# Module loaded successfully
return 0
