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
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
