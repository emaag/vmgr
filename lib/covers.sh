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
#   COVER_MAKE             Create the missing covers (frame from the first video,
#                          or a conversion of folder.png); honors --dry-run
#   COVER_FRAME_PERCENT    Where in the video to take the frame (default 10)
#   COVER_WIDTH            Width in pixels of a created cover (0 = original)
#   COVER_QUALITY          ffmpeg JPEG quality, 2 (best) to 31 (default 3)
#
# Dependencies: core.sh, logging.sh, utils.sh
# Module: covers.sh
#
################################################################################

# Create a cover for ONE folder. Prefers converting an existing image of the
# same name in another format (folder.png -> folder.jpg); otherwise grabs a
# frame from the folder's first video. Never overwrites an existing file.
# Args: $1 - folder. Prints one line; returns 0 created/would create, 1 nothing
# to make it from, 2 ffmpeg failed.
_cover_make_one() {
    local dir="$1" rel="${1#"$COVER_ROOT"/}"
    [[ "$rel" == "$1" ]] && rel="$1"
    local target_name="${COVER_FILENAMES%%,*}"
    target_name="${target_name// /}"
    local target="$dir/$target_name" base="${target_name%.*}"
    local f lower source="" kind=""

    # An image with the cover's name but another extension
    for f in "$dir"/*; do
        [[ -f "$f" ]] || continue
        lower="${f##*/}"; lower="${lower,,}"
        case "$lower" in
            "${base,,}.png"|"${base,,}.jpeg"|"${base,,}.webp"|"${base,,}.bmp")
                source="$f"; kind="converted from ${f##*/}"; break ;;
        esac
    done
    # Otherwise the first video in the folder
    if [[ -z "$source" ]]; then
        for f in "$dir"/*; do
            [[ -f "$f" && "${f##*/}" != .* ]] || continue
            if is_video_file "$f"; then source="$f"; kind="frame at ${COVER_FRAME_PERCENT}% of ${f##*/}"; break; fi
        done
    fi
    if [[ -z "$source" ]]; then
        echo -e "  ${COLOR_YELLOW}no video or image to make it from:${COLOR_RESET} $rel"
        return 1
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would create $target_name ($kind): $rel"
        return 0
    fi

    local ss=0 dur tmp="$dir/.vmgr-cover.$$.jpg"
    local -a vf=()
    (( ${COVER_WIDTH:-0} > 0 )) && vf=(-vf "scale=min(${COVER_WIDTH}\\,iw):-2")
    if [[ "$kind" == frame* ]]; then
        dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$source" 2>/dev/null </dev/null | head -n1)
        ss=$(awk -v d="${dur:-0}" -v p="$COVER_FRAME_PERCENT" 'BEGIN { printf "%.2f", (d > 0 ? d * p / 100 : 5) }')
    fi
    if ffmpeg -v error -y -ss "$ss" -i "$source" -frames:v 1 "${vf[@]}" -q:v "${COVER_QUALITY:-3}" "$tmp" </dev/null 2>/dev/null \
       && [[ -s "$tmp" ]] && mv -n -- "$tmp" "$target" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        echo -e "  ${COLOR_GREEN}created${COLOR_RESET} $target_name ($kind): $rel"
        return 0
    fi
    rm -f "$tmp" 2>/dev/null
    echo -e "  ${COLOR_RED}failed${COLOR_RESET} to create $target_name from ${source##*/}: $rel"
    return 2
}

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

    if [[ "$COVER_MAKE" == true && ${#missing[@]} -gt 0 ]]; then
        if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
            log_error "Creating covers needs ffmpeg and ffprobe. Install them first (for example: sudo apt-get install ffmpeg)"
        else
            echo -e "${COLOR_BOLD}${COLOR_CYAN}Creating covers:${COLOR_RESET}"
            COVER_ROOT="$directory"
            local d made=0 nosrc=0 failed=0 rc
            for d in "${missing[@]}"; do
                _cover_make_one "$d"; rc=$?
                case $rc in 0) ((made++)) ;; 1) ((nosrc++)) ;; *) ((failed++)) ;; esac
            done
            echo ""
            echo -e "${COLOR_BOLD}$made $([[ "$DRY_RUN" == true ]] && echo "would be created" || echo created), $nosrc with nothing to make one from, $failed failed.${COLOR_RESET}"
            echo ""
        fi
    fi

    echo -e "${COLOR_BOLD}Checked $checked folders: ${#present[@]} with a cover, ${#missing[@]} missing (skipped $skipped)${COLOR_RESET}"
    return 0
}

# Module loaded successfully
return 0
