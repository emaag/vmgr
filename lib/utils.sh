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


# Get file size in bytes (wrapper for platform function)
get_file_size() {
    local file="$1"
    get_file_size_bytes "$file"
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
# INTERACTIVE PICKERS (fzf when available, read fallback)
################################################################################

# Pick a directory interactively.
# Usage: pick_directory [prompt] [start_dir]
# Prints selected path to stdout; returns 1 if nothing selected.
pick_directory() {
    local prompt="${1:-Select directory}"
    local start_dir="${2:-.}"
    local result

    local _fzf_bin; _fzf_bin=$(command -v fzf 2>/dev/null || echo "${HOME}/.fzf/bin/fzf")
    if [[ -x "$_fzf_bin" ]]; then
        local fzf_out
        fzf_out=$(find "$start_dir" -maxdepth 6 -type d 2>/dev/null | "$_fzf_bin" \
            --print-query \
            --prompt="$prompt> " \
            --preview='ls -la -- {} 2>/dev/null | head -20' \
            --preview-window=right:40%:wrap \
            --height=60% \
            --border \
            --ansi \
            --no-multi \
            < /dev/tty)
        # --print-query: line 1 = typed query, line 2 = selected item (may be absent)
        local query selected
        query=$(printf '%s\n' "$fzf_out" | head -1)
        selected=$(printf '%s\n' "$fzf_out" | tail -n +2 | head -1)
        if [[ -n "$selected" ]]; then
            result="$selected"
        elif [[ -n "$query" && -d "$query" ]]; then
            # User typed a valid absolute (or relative) path — use it directly
            result="$query"
        else
            return 1
        fi
    else
        echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} $prompt: " >&2
        read -r result < /dev/tty
    fi

    if [[ -z "$result" ]]; then
        return 1
    fi
    echo "$result"
}

# Pick a file interactively.
# Usage: pick_file [prompt] [start_dir] [name_glob]
# Prints selected path to stdout; returns 1 if nothing selected.
pick_file() {
    local prompt="${1:-Select file}"
    local start_dir="${2:-.}"
    local glob="${3:-*}"
    local result

    local _fzf_bin; _fzf_bin=$(command -v fzf 2>/dev/null || echo "${HOME}/.fzf/bin/fzf")
    if [[ -x "$_fzf_bin" ]]; then
        result=$(find "$start_dir" -maxdepth 6 -type f -name "$glob" 2>/dev/null | "$_fzf_bin" \
            --prompt="$prompt> " \
            --preview='head -20 -- {} 2>/dev/null' \
            --preview-window=right:40%:wrap \
            --height=60% \
            --border \
            --ansi \
            --no-multi \
            < /dev/tty)
    else
        echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} $prompt: " >&2
        read -r result < /dev/tty
    fi

    if [[ -z "$result" ]]; then
        return 1
    fi
    echo "$result"
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
