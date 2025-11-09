#!/usr/bin/env bash
#
# Video Manager Ultimate - Utility Functions Module
# Part of the modular video management system
#
# This module provides general utility functions for:
# - File type detection (video, image, audio)
# - Media metadata extraction
# - Path validation and sanitization
# - Filter functions (size, date, pattern)
# - User confirmation and preview
# - Input sanitization and security checks
#
# Dependencies: core.sh, logging.sh, platform.sh
# Status: Phase 2 - Modularization
# Version: 1.2.0
#

################################################################################
# FILE TYPE DETECTION
################################################################################

# Check if file is a video
is_video_file() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}" # Convert to lowercase

    for video_ext in "${DEFAULT_VIDEO_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$video_ext" ]]; then
            return 0
        fi
    done
    return 1
}

# Check if file is an image
is_image_file() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}" # Convert to lowercase

    for img_ext in "${DEFAULT_IMAGE_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$img_ext" ]]; then
            return 0
        fi
    done
    return 1
}

# Check if file is an audio file
is_audio_file() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}" # Convert to lowercase

    for audio_ext in "${DEFAULT_AUDIO_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$audio_ext" ]]; then
            return 0
        fi
    done
    return 1
}

# Detect media type (video, image, audio, or unknown)
get_media_type() {
    local file="$1"

    if is_video_file "$file"; then
        echo "video"
    elif is_image_file "$file"; then
        echo "image"
    elif is_audio_file "$file"; then
        echo "audio"
    else
        echo "unknown"
    fi
}

################################################################################
# MEDIA METADATA FUNCTIONS
################################################################################

# Get image dimensions (requires identify from ImageMagick or file command)
get_image_dimensions() {
    local file="$1"
    local dimensions=""

    # Try ImageMagick identify command
    if command -v identify >/dev/null 2>&1; then
        dimensions=$(identify -format "%wx%h" "$file" 2>/dev/null)
    # Fallback: try file command with grep
    elif command -v file >/dev/null 2>&1; then
        local file_info=$(file "$file" 2>/dev/null)
        dimensions=$(echo "$file_info" | grep -oP '\d+\s*x\s*\d+' | head -1 | tr -d ' ')
    fi

    echo "$dimensions"
}

# Get audio metadata (requires ffprobe or mediainfo)
get_audio_metadata() {
    local file="$1"
    local duration=""
    local bitrate=""
    local artist=""
    local title=""

    if command -v ffprobe >/dev/null 2>&1; then
        # Get duration in seconds
        duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | cut -d'.' -f1)

        # Get bitrate
        bitrate=$(ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)

        # Get artist and title from tags
        artist=$(ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
        title=$(ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
    fi

    echo "$duration|$bitrate|$artist|$title"
}

# Get image EXIF metadata (requires exiftool or identify)
get_image_exif() {
    local file="$1"
    local camera=""
    local date_taken=""
    local gps_lat=""
    local gps_lon=""
    local iso=""
    local focal_length=""
    local aperture=""
    local shutter_speed=""

    # Try exiftool first (most comprehensive)
    if command -v exiftool >/dev/null 2>&1; then
        camera=$(exiftool -s -s -s -Model "$file" 2>/dev/null)
        date_taken=$(exiftool -s -s -s -DateTimeOriginal "$file" 2>/dev/null)
        gps_lat=$(exiftool -s -s -s -GPSLatitude "$file" 2>/dev/null)
        gps_lon=$(exiftool -s -s -s -GPSLongitude "$file" 2>/dev/null)
        iso=$(exiftool -s -s -s -ISO "$file" 2>/dev/null)
        focal_length=$(exiftool -s -s -s -FocalLength "$file" 2>/dev/null)
        aperture=$(exiftool -s -s -s -Aperture "$file" 2>/dev/null)
        shutter_speed=$(exiftool -s -s -s -ShutterSpeed "$file" 2>/dev/null)
    # Fallback to identify from ImageMagick
    elif command -v identify >/dev/null 2>&1; then
        camera=$(identify -format "%[EXIF:Model]" "$file" 2>/dev/null)
        date_taken=$(identify -format "%[EXIF:DateTimeOriginal]" "$file" 2>/dev/null)
        iso=$(identify -format "%[EXIF:ISOSpeedRatings]" "$file" 2>/dev/null)
    fi

    echo "$camera|$date_taken|$gps_lat|$gps_lon|$iso|$focal_length|$aperture|$shutter_speed"
}

# Get file size in bytes (wrapper for platform function)
get_file_size() {
    local file="$1"
    get_file_size_bytes "$file"
}

# Calculate SHA256 hash (wrapper for platform function)
calculate_hash() {
    local file="$1"
    log_verbose "Calculating SHA256 hash for: $(basename "$file")"

    local hash=$(calculate_file_hash "$file")
    if [[ -z "$hash" ]]; then
        log_error "No hash utility found (sha256sum, shasum, or openssl required)"
        return 1
    fi
    echo "$hash"
}

################################################################################
# PATH VALIDATION AND SANITIZATION
################################################################################

# Validate directory exists
validate_directory() {
    local dir="$1"

    if [[ -z "$dir" ]]; then
        log_error "No directory specified"
        return 1
    fi

    # Convert Windows path to WSL path if needed (uses platform.sh function)
    if [[ "$(type -t convert_to_wsl_path)" == "function" ]]; then
        dir=$(convert_to_wsl_path "$dir")
    fi

    if [[ ! -d "$dir" ]]; then
        log_error "Directory does not exist: $dir"
        return 1
    fi

    if [[ ! -r "$dir" ]]; then
        log_error "Directory is not readable: $dir"
        return 1
    fi

    echo "$dir"
    return 0
}

# Sanitize string for use in sed patterns
sanitize_for_sed() {
    local input="$1"
    # Escape special sed metacharacters: / \ & [ ] * . ^ $
    printf '%s\n' "$input" | sed 's/[\/&]/\\&/g' | sed 's/[]\[*.^$]/\\&/g'
}

# Sanitize string for general shell use
sanitize_input() {
    local input="$1"
    local max_length="${2:-1024}"

    # Truncate to max length
    input="${input:0:$max_length}"

    # Remove null bytes and other control characters
    input="${input//[$'\x00'-$'\x1f'$'\x7f']/}"

    echo "$input"
}

# Validate that path doesn't escape base directory
validate_path_safety() {
    local path="$1"
    local base_dir="$2"

    # Resolve to absolute path
    local abs_path
    abs_path=$(realpath -m "$path" 2>/dev/null) || abs_path="$path"
    local abs_base
    abs_base=$(realpath -m "$base_dir" 2>/dev/null) || abs_base="$base_dir"

    # Check if path starts with base directory
    if [[ "$abs_path" != "$abs_base"* ]]; then
        log_error "Path traversal detected: $path"
        return 1
    fi

    return 0
}

# Generate safe filename if conflict exists
get_safe_filename() {
    local directory="$1"
    local filename="$2"
    local target_path="$directory/$filename"

    if [[ ! -e "$target_path" ]]; then
        echo "$filename"
        return 0
    fi

    local counter=1
    local name="${filename%.*}"
    local ext="${filename##*.}"

    [[ "$ext" == "$filename" ]] && ext="" || ext=".$ext"

    while [[ -e "$target_path" ]]; do
        filename="${name}(${counter})${ext}"
        target_path="$directory/$filename"
        ((counter++))
    done

    log_warning "Filename conflict resolved: $filename"
    echo "$filename"
}

################################################################################
# FILTER FUNCTIONS
################################################################################

# Check if file passes size filter
passes_size_filter() {
    local file="$1"

    if [[ "$FILTER_BY_SIZE" != true ]]; then
        return 0
    fi

    local size_bytes=$(get_file_size_bytes "$file")
    local size_mb=$((size_bytes / 1048576))

    if [[ $FILTER_MIN_SIZE_MB -gt 0 ]] && [[ $size_mb -lt $FILTER_MIN_SIZE_MB ]]; then
        return 1
    fi

    if [[ $FILTER_MAX_SIZE_MB -gt 0 ]] && [[ $size_mb -gt $FILTER_MAX_SIZE_MB ]]; then
        return 1
    fi

    return 0
}

# Check if file passes date filter
passes_date_filter() {
    local file="$1"

    if [[ "$FILTER_BY_DATE" != true ]]; then
        return 0
    fi

    if [[ $FILTER_DAYS_OLD -le 0 ]]; then
        return 0
    fi

    local file_mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    local current_time=$(date +%s)
    local age_days=$(( (current_time - file_mtime) / 86400 ))

    if [[ $age_days -ge $FILTER_DAYS_OLD ]]; then
        return 0
    fi

    return 1
}

# Check if file passes pattern filter
passes_pattern_filter() {
    local file="$1"

    if [[ "$FILTER_BY_PATTERN" != true ]]; then
        return 0
    fi

    if [[ -z "$FILTER_PATTERN" ]]; then
        return 0
    fi

    local filename=$(basename "$file")
    if [[ "$filename" =~ $FILTER_PATTERN ]]; then
        return 0
    fi

    return 1
}

# Check if file passes all filters
passes_all_filters() {
    local file="$1"

    passes_size_filter "$file" || return 1
    passes_date_filter "$file" || return 1
    passes_pattern_filter "$file" || return 1

    return 0
}

################################################################################
# USER INTERACTION AND PREVIEW
################################################################################

# Ask for confirmation on single file
confirm_file_operation() {
    local file="$1"
    local operation="$2"
    local preview="$3"

    if [[ "$INTERACTIVE_CONFIRM" != true ]]; then
        return 0
    fi

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╭─────────────────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_BOLD}${COLOR_YELLOW}CONFIRM OPERATION${COLOR_RESET}                             ${COLOR_BOLD}${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╰─────────────────────────────────────────────────────╯${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_WHITE}File:${COLOR_RESET}      $(basename "$file")"
    echo -e "  ${COLOR_WHITE}Action:${COLOR_RESET}    $operation"

    if [[ -n "$preview" ]]; then
        echo -e "  ${COLOR_WHITE}Preview:${COLOR_RESET}   $preview"
    fi

    echo ""
    echo -e "  ${COLOR_GREEN}[Y]${COLOR_RESET} Yes, proceed    ${COLOR_RED}[N]${COLOR_RESET} No, skip"
    echo -e "  ${COLOR_CYAN}[A]${COLOR_RESET} Apply to all    ${COLOR_YELLOW}[S]${COLOR_RESET} Skip all remaining"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Your choice: "
    read -n 1 -r
    echo ""

    case "$REPLY" in
        y|Y) return 0 ;;
        a|A) INTERACTIVE_CONFIRM=false; log_info "Applying to all remaining files"; return 0 ;;
        s|S) log_warning "Skipping all remaining files"; return 2 ;;
        *) return 1 ;;
    esac
}

# Show operation preview
show_operation_preview() {
    local original="$1"
    local transformed="$2"
    local operation="$3"

    if [[ "$SHOW_PREVIEW" != true ]]; then
        return
    fi

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}┌─ $operation${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}│${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}│${COLOR_RESET}  ${COLOR_YELLOW}Before:${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}│${COLOR_RESET}    ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} $original"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}│${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}│${COLOR_RESET}  ${COLOR_GREEN}After:${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}│${COLOR_RESET}    ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} $transformed"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}└─${COLOR_RESET}"
}

# Pause for step-by-step mode
step_pause() {
    if [[ "$STEP_BY_STEP" == true ]]; then
        echo ""
        echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        echo -n "${COLOR_YELLOW}${SYMBOL_STAR}${COLOR_RESET} Press ${COLOR_WHITE}[Enter]${COLOR_RESET} to continue, ${COLOR_WHITE}[Q]${COLOR_RESET} to disable step mode: "
        read -r
        if [[ "$REPLY" == "q" ]] || [[ "$REPLY" == "Q" ]]; then
            STEP_BY_STEP=false
            echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Step-by-step mode disabled"
        fi
        echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        echo ""
    fi
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
