#!/usr/bin/env bash
#
# Video Manager Ultimate - Subtitle Generation Module
# Part of the modular video management system
#
# This module provides subtitle generation functionality using OpenAI Whisper:
# - Whisper integration and installation checking
# - GPU detection and acceleration support
# - Parallel processing for multiple videos
# - Subtitle editing and quality control
# - Resume/checkpoint system
# - Subtitle translation and formatting
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh
# Status: Phase 3 - Modularization  
# Version: 1.2.0
#

################################################################################
# GPU AND HARDWARE DETECTION
################################################################################

# Detect GPU availability
detect_gpu() {
    local gpu_available=false

    # Check for NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            gpu_available=true
            log_verbose "NVIDIA GPU detected"
        fi
    fi

    # Check for CUDA
    if [[ -d /usr/local/cuda ]] || command -v nvcc &> /dev/null; then
        log_verbose "CUDA installation found"
    fi

    if [[ "$gpu_available" == true ]]; then
        return 0
    else
        return 1
    fi
}

# Check if parallel processing is available
check_parallel_support() {
    if command -v parallel &> /dev/null; then
        return 0
    else
        return 1
    fi
}

################################################################################
# WHISPER INTEGRATION
################################################################################

# Check if whisper is installed
check_whisper_installation() {
    if command -v whisper &> /dev/null; then
        return 0
    elif command -v whisper.cpp &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Get whisper command
get_whisper_command() {
    if command -v whisper &> /dev/null; then
        echo "whisper"
    elif command -v whisper.cpp &> /dev/null; then
        echo "whisper.cpp"
    else
        echo ""
    fi
}

################################################################################
# SUBTITLE PROCESSING AND EDITING
################################################################################

# Apply ML-based punctuation and capitalization fixes
fix_punctuation() {
    local subtitle_file="$1"

    log_verbose "Applying punctuation fixes to: $(basename "$subtitle_file")"

    # Basic punctuation fixes
    sed -i.bak \
        -e 's/\bi\b/I/g' \
        -e 's/^\([a-z]\)/\U\1/' \
        -e 's/\. \([a-z]\)/. \U\1/g' \
        -e 's/\? \([a-z]\)/? \U\1/g' \
        -e 's/! \([a-z]\)/! \U\1/g' \
        "$subtitle_file" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        rm -f "${subtitle_file}.bak"
        log_verbose "Punctuation fixes applied"
        return 0
    else
        log_warning "Punctuation fix failed"
        return 1
    fi
}

# Remove filler words from subtitles
remove_filler_words() {
    local subtitle_file="$1"

    log_verbose "Removing filler words"

    # Common filler words
    local fillers=("um" "uh" "er" "ah" "like" "you know" "I mean" "sort of" "kind of")

    for filler in "${fillers[@]}"; do
        local safe_filler=$(sanitize_for_sed "$filler")
        sed -i "s/\b${safe_filler}\b//gi" "$subtitle_file" 2>/dev/null
    done

    # Clean up extra spaces
    sed -i 's/  \+/ /g' "$subtitle_file"

    log_success "Filler words removed"
}

# Show subtitle preview
preview_subtitle() {
    local subtitle_file="$1"
    local lines="${2:-10}"

    if [[ ! -f "$subtitle_file" ]]; then
        log_error "Subtitle file not found: $subtitle_file"
        return 1
    fi

    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}Preview of: $(basename "$subtitle_file")${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    head -n "$lines" "$subtitle_file"
    echo -e "${COLOR_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
}

# Verify subtitle quality
verify_subtitle_quality() {
    local subtitle_file="$1"
    local min_confidence="${2:-$SUBTITLE_MIN_CONFIDENCE}"

    if [[ ! -f "$subtitle_file" ]]; then
        return 1
    fi

    # Check file size (should be > 100 bytes for valid subtitle)
    local file_size=$(stat -f%z "$subtitle_file" 2>/dev/null || stat -c%s "$subtitle_file" 2>/dev/null)

    if [[ $file_size -lt 100 ]]; then
        log_warning "Subtitle file is too small (${file_size} bytes), might be invalid"
        return 1
    fi

    # Check for SRT format validity
    if [[ "$subtitle_file" == *.srt ]]; then
        if ! grep -qE "^[0-9]+$" "$subtitle_file" 2>/dev/null; then
            log_warning "Subtitle file appears to be malformed"
            return 1
        fi
    fi

    log_verbose "Subtitle quality check passed: $(basename "$subtitle_file")"
    return 0
}

################################################################################
# RESUME SYSTEM
################################################################################

# Save resume point
save_resume_point() {
    local video_file="$1"
    echo "$video_file" >> "$SUBTITLE_RESUME_FILE"
}

# Check if video was already processed
is_video_processed() {
    local video_file="$1"

    if [[ ! -f "$SUBTITLE_RESUME_FILE" ]]; then
        return 1
    fi

    grep -Fxq "$video_file" "$SUBTITLE_RESUME_FILE" 2>/dev/null
    return $?
}

# Clear resume file
clear_resume_file() {
    rm -f "$SUBTITLE_RESUME_FILE" 2>/dev/null
}

################################################################################
# NOTIFICATION SYSTEM
################################################################################

# Send completion notification
send_notification() {
    local title="$1"
    local message="$2"

    # Try different notification methods
    if command -v notify-send &> /dev/null; then
        notify-send "$title" "$message" 2>/dev/null
    elif command -v osascript &> /dev/null; then
        # macOS notification
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
    fi

    # Also beep if available
    if command -v beep &> /dev/null; then
        beep 2>/dev/null
    elif [[ -e /dev/console ]]; then
        echo -e "\a" 2>/dev/null
    fi
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
