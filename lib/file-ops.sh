#!/usr/bin/env bash
#
# Video Manager Ultimate - File Operations Module
# Part of the modular video management system
#
# This module provides file operation functions for:
# - Bracket notation application
# - Filename cleanup and renaming
# - Directory flattening
# - Bulk file renaming operations
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh
# Status: Phase 2 - Modularization
# Version: 1.2.0
#

################################################################################
# CORE RENAMING FUNCTIONS
################################################################################

# Apply bracket notation to filename
apply_bracket_notation() {
    local filename="$1"

    # Validate input
    if [[ -z "$filename" ]]; then
        log_error "apply_bracket_notation: filename parameter is required"
        return 1
    fi

    # Separate name and extension
    local name="${filename%.*}"
    local ext="${filename##*.}"
    [[ "$ext" == "$filename" ]] && ext="" || ext=".$ext"

    # Leading whitespace would hide the first word
    name="${name#"${name%%[![:space:]]*}"}"
    # ...and trailing whitespace would end up as a space before the extension
    name="${name%"${name##*[![:space:]]}"}"

    # Match and extract first word and the rest (letters in any script count)
    if [[ "$name" =~ ^([[:alnum:]_]+)[.\ \-]?(.*)$ ]]; then
        local first_word="${BASH_REMATCH[1]}"
        local rest="${BASH_REMATCH[2]}"

        # Capitalize first letter
        first_word="${first_word^}"

        # Construct new filename
        local new_name="[$first_word]"
        [[ -n "$rest" ]] && new_name+=" $rest"
        new_name+="$ext"

        echo "$new_name"
    else
        echo "$name$ext"
    fi
}

# Remove dash patterns
remove_dashes() {
    local filename="$1"
    echo "${filename// - / }"
}

# Fix spacing after brackets
fix_bracket_spacing() {
    local filename="$1"
    # The space goes between ] and the name, never between ] and the extension
    echo "$filename" | sed -E 's/\]([^[:space:]])/] \1/g; s/\] (\.[^. ]+)$/]\1/'
}

# Full cleanup pipeline
cleanup_filename() {
    local filename="$1"

    log_verbose "  Processing: $filename"

    # Step 1: Remove dashes
    filename=$(remove_dashes "$filename")
    log_verbose "    After dash removal: $filename"

    # Step 2: Apply bracket notation
    filename=$(apply_bracket_notation "$filename")
    log_verbose "    After bracket notation: $filename"

    # Step 3: Fix spacing
    filename=$(fix_bracket_spacing "$filename")
    log_verbose "    After spacing fix: $filename"

    echo "$filename"
}

################################################################################
# NAMING PATTERNS (selected with --pattern; default: bracket)
################################################################################

RENAME_PATTERNS="bracket title-case snake_case strip-junk"

# Split "name.ext" into the globals _FN_NAME and _FN_EXT (ext includes the dot).
# A leading dot (hidden file) is not an extension.
_split_filename() {
    local filename="$1"
    _FN_NAME="${filename%.*}"
    _FN_EXT="${filename##*.}"
    if [[ "$_FN_EXT" == "$filename" || -z "$_FN_NAME" ]]; then
        _FN_NAME="$filename"
        _FN_EXT=""
    else
        _FN_EXT=".$_FN_EXT"
    fi
}

# "my_show.s01e01" -> "My Show S01e01"
title_case_filename() {
    _split_filename "$1"
    local name="${_FN_NAME//[._]/ }" out="" word
    name="${name,,}"
    for word in $name; do
        out+="${out:+ }${word^}"
    done
    echo "${out:-$_FN_NAME}$_FN_EXT"
}

# "My Show - S01E01" -> "my_show_s01e01"
snake_case_filename() {
    _split_filename "$1"
    local name="${_FN_NAME,,}"
    name=$(printf '%s' "$name" | sed -E 's/[^[:alnum:]]+/_/g; s/^_+//; s/_+$//')
    echo "${name:-$_FN_NAME}$_FN_EXT"
}

# Words that only describe how a release was encoded; matched case-insensitively
_JUNK_WORDS=" 2160p 1440p 1080p 1080i 720p 576p 480p 4k uhd hd fhd x264 x265 h264 h265 hevc avc xvid divx webrip web-dl webdl web bluray blu-ray brrip bdrip hdrip dvdrip hdtv aac aac2.0 ac3 eac3 dts dd5.1 ddp5.1 5.1 7.1 10bit 8bit hdr hdr10 sdr proper repack internal "

# "Show.Name.1080p.WEB-DL.x264.mkv" -> "Show Name.mkv"
strip_junk_filename() {
    _split_filename "$1"
    local name="${_FN_NAME//_/ }" out="" word bare
    # dots separate words, except inside numbers like 5.1
    name=$(printf '%s' "$name" | sed -E 's/([^0-9])\./\1 /g; s/\.([^0-9])/ \1/g')
    for word in $name; do
        bare="${word#[[(]}"; bare="${bare%[])]}"
        bare="${bare,,}"
        [[ "$_JUNK_WORDS" == *" $bare "* ]] && continue
        out+="${out:+ }$word"
    done
    echo "${out:-$_FN_NAME}$_FN_EXT"
}

# Rewrite every date matched by regex $1 as dd.mm.yyyy inside string $3.
# $2 says which way round the groups are: "ymd" or "dmy". Impossible dates
# (month 13, day 32, ...) are left as they were.
_reformat_dates() {
    local re="$1" order="$2" s="$3" out="" whole lead trail before d mo y
    while [[ "$s" =~ $re ]]; do
        whole="${BASH_REMATCH[0]}"; lead="${BASH_REMATCH[1]}"; trail="${BASH_REMATCH[6]}"
        if [[ "$order" == ymd ]]; then
            y="${BASH_REMATCH[2]}"; mo="${BASH_REMATCH[4]}"; d="${BASH_REMATCH[5]}"
        else
            d="${BASH_REMATCH[2]}"; mo="${BASH_REMATCH[3]}"; y="${BASH_REMATCH[4]}"
        fi
        before="${s%%"$whole"*}"
        s="${s#*"$whole"}"
        if (( 10#$mo >= 1 && 10#$mo <= 12 && 10#$d >= 1 && 10#$d <= 31 )); then
            out+="$before$lead$d.$mo.$y"
            s="$trail$s"
        else
            out+="$before$whole"
        fi
    done
    echo "$out$s"
}

# Write dates in the name as dd.mm.yyyy. Understands yyyy-mm-dd, yyyymmdd and
# dd-mm-yyyy (separators - . _); a date with the day first is read day first,
# so 03-04-2024 is 3 April.
normalize_dates_filename() {
    _split_filename "$1"
    local name="$_FN_NAME" ext="$_FN_EXT"
    name=$(_reformat_dates '(^|[^0-9])((19|20)[0-9]{2})[-._]([0-9]{2})[-._]([0-9]{2})([^0-9]|$)' ymd "$name")
    name=$(_reformat_dates '(^|[^0-9])((19|20)[0-9]{2})([0-9]{2})([0-9]{2})([^0-9]|$)' ymd "$name")
    name=$(_reformat_dates '(^|[^0-9])([0-9]{2})[-._]([0-9]{2})[-._]((19|20)[0-9]{2})([^0-9]|$)' dmy "$name")
    echo "$name$ext"
}

# The pattern's transform, then date normalization when --dates is on
_pattern_then_dates() {
    normalize_dates_filename "$("$_RENAME_BASE_FN" "$1")"
}

# Name of the transform function for a pattern; non-zero for unknown patterns
rename_transform_for_pattern() {
    case "$1" in
        bracket)     echo "cleanup_filename" ;;
        title-case)  echo "title_case_filename" ;;
        snake_case)  echo "snake_case_filename" ;;
        strip-junk)  echo "strip_junk_filename" ;;
        *) return 1 ;;
    esac
}

################################################################################
# BULK RENAME OPERATIONS
################################################################################

# Shared engine: apply transform_fn to every video file in directory
_apply_transform_to_directory() {
    local directory="$1"
    local dry_run="${2:-false}"
    local transform_fn="$3"

    log_info "Scanning directory: $directory"

    local file_count=0
    local renamed_count=0

    local total_files
    total_files=$(find "$directory" -maxdepth 1 -type f \( \
        -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o \
        -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o \
        -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.3gp" \
        \) 2>/dev/null | wc -l)
    log_info "Found $total_files video files to process"

    if [[ "$total_files" -eq 0 ]]; then
        log_info "Nothing to do"
        return 0
    fi

    echo ""

    while IFS= read -r -d '' file; do
        [[ "$(basename "$file")" == .* ]] && continue

        if ! is_video_file "$file"; then
            continue
        fi

        ((file_count++))
        ((STATS[files_processed]++))

        local filename
        filename=$(basename "$file")
        local new_filename
        new_filename=$("$transform_fn" "$filename")

        if [[ "$(type -t ui_progress)" == "function" ]]; then
            ui_progress "$file_count" "$total_files" "Processing"
        else
            echo -ne "\r${COLOR_CYAN}Processing: [$file_count/$total_files] ${COLOR_RESET}"
        fi

        if [[ "$filename" != "$new_filename" ]]; then
            local new_path="$directory/$new_filename"

            if [[ -e "$new_path" && "$new_path" != "$file" ]]; then
                new_filename=$(get_safe_filename "$directory" "$new_filename")
                new_path="$directory/$new_filename"
            fi

            echo -ne "\r\033[K"

            if [[ "$dry_run" == true ]]; then
                if [[ "$(type -t ui_change)" == "function" ]]; then
                    ui_change "$filename" "$new_filename" true
                else
                    echo -e "${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would rename:"
                    echo -e "  ${COLOR_WHITE}From:${COLOR_RESET} $filename"
                    echo -e "  ${COLOR_WHITE}To:${COLOR_RESET}   $new_filename"
                fi
                ((STATS[files_previewed]++))
                log_message "DRYRUN" "Would rename: $filename -> $new_filename"
            else
                mv -- "$file" "$new_path" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    if [[ "$(type -t ui_change)" == "function" ]]; then
                        ui_change "$filename" "$new_filename"
                    else
                        echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} Renamed:"
                        echo -e "  ${COLOR_WHITE}From:${COLOR_RESET} $filename"
                        echo -e "  ${COLOR_WHITE}To:${COLOR_RESET}   $new_filename"
                    fi
                    undo_record "$file" "$new_path"
                    log_message "RENAME" "Success: $filename -> $new_filename"
                    ((renamed_count++))
                    ((STATS[files_renamed]++))
                else
                    log_error "Failed to rename: $filename"
                fi
            fi
        else
            ((STATS[files_skipped]++))
            log_verbose "Skipped (no change needed): $filename"
        fi
    done < <(find "$directory" -maxdepth 1 -type f -print0)

    echo -ne "\r\033[K"

    if [[ "$dry_run" == true ]]; then
        log_info "Dry run complete - no files were actually renamed"
    else
        log_success "Renamed $renamed_count out of $file_count video files"
    fi
}

rename_files_in_directory() {
    local transform_fn
    if ! transform_fn=$(rename_transform_for_pattern "${RENAME_PATTERN:-bracket}"); then
        log_error "Unknown rename pattern: $RENAME_PATTERN (choose from: $RENAME_PATTERNS)"
        return 1
    fi
    if [[ "${NORMALIZE_DATES:-false}" == true ]]; then
        _RENAME_BASE_FN="$transform_fn"
        transform_fn="_pattern_then_dates"
    fi
    _apply_transform_to_directory "$1" "$2" "$transform_fn"
}
remove_dashes_in_directory()       { _apply_transform_to_directory "$1" "$2" "remove_dashes"; }
fix_bracket_spacing_in_directory() { _apply_transform_to_directory "$1" "$2" "fix_bracket_spacing"; }

################################################################################
# DIRECTORY FLATTENING
################################################################################

flatten_directory() {
    local top_dir="$1"
    local dry_run="${2:-false}"

    log_info "Flattening directory structure: $top_dir"
    log_verbose "Moving all video files from subdirectories to: $top_dir"

    local moved_count=0
    local conflict_count=0

    # Find all video files NOT in the top directory
    while IFS= read -r file; do
        ((STATS[files_processed]++))

        local base_name=$(basename "$file")
        local target="$top_dir/$base_name"

        log_verbose "Found: $file"

        # Check for conflicts
        if [[ -e "$target" ]]; then
            local file_size=$(get_file_size "$file")
            local target_size=$(get_file_size "$target")

            if [[ "$file_size" == "$target_size" ]]; then
                log_warning "Possible duplicate (same size): $base_name"
                log_verbose "  Source: $file ($file_size bytes)"
                log_verbose "  Target: $target ($target_size bytes)"
                ((STATS[files_skipped]++))
                continue
            fi

            base_name=$(get_safe_filename "$top_dir" "$base_name")
            target="$top_dir/$base_name"
            ((conflict_count++))
        fi

        if [[ "$dry_run" == true ]]; then
            echo -e "${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would move: $file ${COLOR_ARROW} $target"
            log_message "DRYRUN" "Would move: $file -> $target"
        else
            mv "$file" "$target" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} Moved: $(basename "$file") ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} $target"
                undo_record "$file" "$target"
                log_message "MOVE" "Success: $file -> $target"
                ((moved_count++))
                ((STATS[files_moved]++))
            else
                log_error "Failed to move: $file"
            fi
        fi
    done < <(find "$top_dir" -mindepth 2 -type f ! -path '*/.vmgr-trash/*' | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$')

    if [[ "$dry_run" == true ]]; then
        log_info "Dry run complete - no files were actually moved"
    else
        log_success "Moved $moved_count video files to top directory"
        if [[ $conflict_count -gt 0 ]]; then
            log_warning "Resolved $conflict_count filename conflicts"
        fi
    fi
}

################################################################################
# IMAGE FORMAT CONVERSION
################################################################################

# Global setting for recursive image operations
IMAGE_RECURSIVE=${IMAGE_RECURSIVE:-false}

# Check if ImageMagick is available
check_imagemagick() {
    if ! command -v convert &>/dev/null; then
        log_error "ImageMagick is required for this operation"
        log_info "Install with: sudo apt install imagemagick"
        return 1
    fi
    return 0
}

# Generic image conversion function
# Usage: convert_images_to_jpg <directory> <extension> <dry_run> <recursive>
# For rename-only (jpeg->jpg), use rename mode
convert_images_to_jpg() {
    local directory="$1"
    local source_ext="$2"
    local dry_run="${3:-false}"
    local recursive="${4:-false}"
    local rename_only="${5:-false}"

    local ext_upper=$(echo "$source_ext" | tr '[:lower:]' '[:upper:]')
    log_info "Converting $ext_upper to JPG in: $directory"
    [[ "$recursive" == true ]] && log_info "Recursive mode: ON"

    # Check for ImageMagick if actual conversion needed
    if [[ "$rename_only" != true ]]; then
        check_imagemagick || return 1
    fi

    local file_count=0
    local converted_count=0
    local error_count=0
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"

    # Build find command based on recursive setting
    local depth_args=""
    [[ "$recursive" != true ]] && depth_args="-maxdepth 1"

    # Count total files first
    local total_files=$(find "$directory" $depth_args -type f ! -path '*/.vmgr-trash/*' -iname "*.$source_ext" 2>/dev/null | wc -l)
    log_info "Found $total_files .$source_ext files to convert"

    if [[ $total_files -eq 0 ]]; then
        log_info "No .$source_ext files found"
        return 0
    fi

    echo ""

    while IFS= read -r -d '' file; do
        [[ "$(basename "$file")" == .* ]] && continue

        ((file_count++))
        ((STATS[files_processed]++))

        local filename=$(basename "$file")
        local filedir=$(dirname "$file")
        local basename="${filename%.*}"
        local new_filename="${basename}.jpg"
        local new_path="$filedir/$new_filename"

        # Progress indicator
        if [[ "$(type -t ui_progress)" == "function" ]]; then
            ui_progress "$file_count" "$total_files" "Processing"
        else
            echo -ne "\r${COLOR_CYAN}Processing: [$file_count/$total_files] ${COLOR_RESET}"
        fi

        # Check for conflicts
        if [[ -e "$new_path" && "$new_path" != "$file" ]]; then
            new_filename=$(get_safe_filename "$filedir" "$new_filename")
            new_path="$filedir/$new_filename"
        fi

        echo -ne "\r\033[K" # Clear line

        if [[ "$dry_run" == true ]]; then
            echo -e "${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would convert:"
            echo -e "  ${COLOR_WHITE}From:${COLOR_RESET} $filename"
            echo -e "  ${COLOR_WHITE}To:${COLOR_RESET}   $new_filename"
            [[ "$recursive" == true && "$filedir" != "$directory" ]] && \
                echo -e "  ${COLOR_CYAN}In:${COLOR_RESET}   ${filedir#$directory/}"
            log_message "DRYRUN" "Would convert: $file -> $new_path"
        else
            local success=false
            if [[ "$rename_only" == true ]]; then
                # Just rename (for jpeg->jpg)
                if mv -- "$file" "$new_path" 2>/dev/null; then
                    success=true
                    undo_record "$file" "$new_path"
                fi
            else
                # Actual conversion using ImageMagick. The original goes to the trash
                # (not deleted), and the undo log also lists the new .jpg so an undo
                # puts the original back and moves the .jpg out of the way.
                if convert "$file" -quality 90 "$new_path" 2>/dev/null; then
                    if trash_file "$file" "$directory" "$stamp"; then
                        success=true
                        local jrel="${new_path#"$directory"/}" jdest jn=1
                        jdest="$directory/$VMGR_TRASH_DIR/$stamp/$jrel"
                        while [[ -e "$jdest" ]]; do jdest="$directory/$VMGR_TRASH_DIR/$stamp/$jrel.$((++jn))"; done
                        undo_record "$jdest" "$new_path"
                    else
                        log_warning "Could not move the original to the trash, leaving it in place: $filename"
                        rm -f "$new_path"
                    fi
                fi
            fi

            if [[ "$success" == true ]]; then
                echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} Converted:"
                echo -e "  ${COLOR_WHITE}From:${COLOR_RESET} $filename"
                echo -e "  ${COLOR_WHITE}To:${COLOR_RESET}   $new_filename"
                [[ "$recursive" == true && "$filedir" != "$directory" ]] && \
                    echo -e "  ${COLOR_CYAN}In:${COLOR_RESET}   ${filedir#$directory/}"
                log_message "CONVERT" "Success: $file -> $new_path"
                ((converted_count++))
                ((STATS[files_renamed]++))
            else
                log_error "Failed to convert: $filename"
                ((error_count++))
            fi
        fi
    done < <(find "$directory" $depth_args -type f ! -path '*/.vmgr-trash/*' -iname "*.$source_ext" -print0 2>/dev/null)

    echo -ne "\r\033[K" # Clear progress line

    if [[ "$dry_run" == true ]]; then
        log_info "Dry run complete - no files were actually converted"
    else
        log_success "Converted $converted_count out of $file_count .$source_ext files to .jpg"
        [[ $error_count -gt 0 ]] && log_warning "$error_count files failed to convert"
    fi
}

# Convert .jpeg files to .jpg (rename only - same format)
convert_jpeg_to_jpg() {
    local directory="$1"
    local dry_run="${2:-false}"
    local recursive="${3:-$IMAGE_RECURSIVE}"
    convert_images_to_jpg "$directory" "jpeg" "$dry_run" "$recursive" true
}

# Convert .png files to .jpg (requires ImageMagick)
convert_png_to_jpg() {
    local directory="$1"
    local dry_run="${2:-false}"
    local recursive="${3:-$IMAGE_RECURSIVE}"
    convert_images_to_jpg "$directory" "png" "$dry_run" "$recursive" false
}

# Convert .webp files to .jpg (requires ImageMagick)
convert_webp_to_jpg() {
    local directory="$1"
    local dry_run="${2:-false}"
    local recursive="${3:-$IMAGE_RECURSIVE}"
    convert_images_to_jpg "$directory" "webp" "$dry_run" "$recursive" false
}

# Convert .heic files to .jpg (requires ImageMagick with HEIC support)
convert_heic_to_jpg() {
    local directory="$1"
    local dry_run="${2:-false}"
    local recursive="${3:-$IMAGE_RECURSIVE}"
    convert_images_to_jpg "$directory" "heic" "$dry_run" "$recursive" false
}

# Convert all supported image formats to .jpg
convert_all_images_to_jpg() {
    local directory="$1"
    local dry_run="${2:-false}"
    local recursive="${3:-$IMAGE_RECURSIVE}"

    log_info "Converting all images to JPG in: $directory"
    echo ""

    # JPEG first (rename only, no ImageMagick needed)
    convert_jpeg_to_jpg "$directory" "$dry_run" "$recursive"
    echo ""

    # Check ImageMagick for the rest
    if check_imagemagick; then
        convert_png_to_jpg "$directory" "$dry_run" "$recursive"
        echo ""
        convert_webp_to_jpg "$directory" "$dry_run" "$recursive"
        echo ""
        convert_heic_to_jpg "$directory" "$dry_run" "$recursive"
    fi

    log_success "All image conversions complete"
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
