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

    # Match and extract first word and the rest
    if [[ "$name" =~ ^([a-zA-Z0-9_]+)[.\ \-]?(.*)$ ]]; then
        local first_word="${BASH_REMATCH[1]}"
        local rest="${BASH_REMATCH[2]}"

        # Capitalize first letter
        first_word="$(tr '[:lower:]' '[:upper:]' <<< "${first_word:0:1}")${first_word:1}"

        # Construct new filename
        local new_name="[$first_word]"
        [[ -n "$rest" ]] && new_name+=" $rest"
        new_name+="$ext"

        echo "$new_name"
    else
        echo "$filename"
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
    echo "$filename" | sed -E 's/\](\S)/] \1/g'
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
# BULK RENAME OPERATIONS
################################################################################

# Generic file processing function to reduce code duplication
# Args: directory, dry_run, transform_function, operation_name
_process_files_with_transform() {
    local directory="$1"
    local dry_run="$2"
    local transform_func="$3"
    local operation_name="${4:-Transform}"

    log_info "Scanning directory: $directory"

    local file_count=0
    local renamed_count=0

    # Count total video files first
    local total_files=$(find "$directory" -maxdepth $DEFAULT_FIND_MAX_DEPTH -type f | grep -iE "$VIDEO_EXTENSIONS_PATTERN" | wc -l)
    log_info "Found $total_files video files to process"

    echo ""

    while IFS= read -r -d '' file; do
        [[ "$(basename "$file")" == .* ]] && continue

        if ! is_video_file "$file"; then
            continue
        fi

        ((file_count++))
        ((STATS[files_processed]++))

        local filename=$(basename "$file")
        local new_filename=$("$transform_func" "$filename")

        # Progress indicator
        echo -ne "\r${COLOR_CYAN}Processing: [$file_count/$total_files] ${COLOR_RESET}"

        if [[ "$filename" != "$new_filename" ]]; then
            local new_path="$directory/$new_filename"

            # Check for conflicts
            if [[ -e "$new_path" && "$new_path" != "$file" ]]; then
                new_filename=$(get_safe_filename "$directory" "$new_filename")
                new_path="$directory/$new_filename"
            fi

            echo -ne "\r\033[K" # Clear line

            if [[ "$dry_run" == true ]]; then
                echo -e "${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would $operation_name:"
                echo -e "  ${COLOR_WHITE}From:${COLOR_RESET} $filename"
                echo -e "  ${COLOR_WHITE}To:${COLOR_RESET}   $new_filename"
                log_message "DRYRUN" "Would $operation_name: $filename -> $new_filename"
            else
                if mv -- "$file" "$new_path" 2>/dev/null; then
                    echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${operation_name}ed:"
                    echo -e "  ${COLOR_WHITE}From:${COLOR_RESET} $filename"
                    echo -e "  ${COLOR_WHITE}To:${COLOR_RESET}   $new_filename"
                    log_message "RENAME" "Success: $filename -> $new_filename"
                    ((renamed_count++))
                    ((STATS[files_renamed]++))
                else
                    log_error "Failed to $operation_name: $filename"
                fi
            fi
        else
            ((STATS[files_skipped]++))
            log_verbose "Skipped (no change needed): $filename"
        fi
    done < <(find "$directory" -maxdepth $DEFAULT_FIND_MAX_DEPTH -type f -print0)

    echo -ne "\r\033[K" # Clear progress line

    if [[ "$dry_run" == true ]]; then
        log_info "Dry run complete - no files were actually changed"
    else
        log_success "${operation_name}ed $renamed_count out of $file_count video files"
    fi
}

# Rename files in directory using full cleanup pipeline
rename_files_in_directory() {
    _process_files_with_transform "$1" "${2:-false}" "cleanup_filename" "rename"
}

# Remove dashes from filenames in directory
remove_dashes_in_directory() {
    _process_files_with_transform "$1" "${2:-false}" "remove_dashes" "remove dash"
}

# Fix bracket spacing in filenames in directory
fix_bracket_spacing_in_directory() {
    _process_files_with_transform "$1" "${2:-false}" "fix_bracket_spacing" "fix spacing"
}

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
                log_message "MOVE" "Success: $file -> $target"
                ((moved_count++))
                ((STATS[files_moved]++))
            else
                log_error "Failed to move: $file"
            fi
        fi
    done < <(find "$top_dir" -mindepth 2 -type f | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$')

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

    # Build find command based on recursive setting
    local depth_args=""
    [[ "$recursive" != true ]] && depth_args="-maxdepth 1"

    # Count total files first
    local total_files=$(find "$directory" $depth_args -type f -iname "*.$source_ext" 2>/dev/null | wc -l)
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
        echo -ne "\r${COLOR_CYAN}Processing: [$file_count/$total_files] ${COLOR_RESET}"

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
                mv -- "$file" "$new_path" 2>/dev/null && success=true
            else
                # Actual conversion using ImageMagick
                convert "$file" -quality "$WHISPER_QUALITY" "$new_path" 2>/dev/null && success=true
                # Remove original if conversion succeeded
                [[ "$success" == true ]] && rm -f "$file"
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
    done < <(find "$directory" $depth_args -type f -iname "*.$source_ext" -print0 2>/dev/null)

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
