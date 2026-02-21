#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - CORE MODULE
#
# This module contains core initialization, constants, and global variables
# It must be loaded first before any other module.
#
# Author: Created for Eric's Video Management System
# Module: core.sh
# Version: 1.3.0
# Date: December 23, 2025
#
################################################################################

# Script metadata
readonly SCRIPT_VERSION="1.3.0"
readonly SCRIPT_NAME="Video Manager Ultimate - Bash Edition"
readonly SCRIPT_DATE="2025-12-23"

# Color codes for beautiful output
readonly COLOR_RESET=$'\033[0m'
readonly COLOR_BOLD=$'\033[1m'
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[0;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_MAGENTA=$'\033[0;35m'
readonly COLOR_CYAN=$'\033[0;36m'
readonly COLOR_WHITE=$'\033[0;37m'
readonly COLOR_BRIGHT_RED=$'\033[1;31m'
readonly COLOR_BRIGHT_GREEN=$'\033[1;32m'
readonly COLOR_BRIGHT_YELLOW=$'\033[1;33m'
readonly COLOR_BRIGHT_BLUE=$'\033[1;34m'
readonly COLOR_BRIGHT_MAGENTA=$'\033[1;35m'
readonly COLOR_BRIGHT_CYAN=$'\033[1;36m'

# Unicode characters for visual appeal
readonly SYMBOL_CHECK="✓"
readonly SYMBOL_CROSS="✗"
readonly SYMBOL_ARROW="→"
readonly SYMBOL_BULLET="•"
readonly SYMBOL_STAR="★"
readonly SYMBOL_WARN="⚠"
readonly SYMBOL_INFO="ℹ"
readonly SYMBOL_FOLDER="📁"
readonly SYMBOL_FILE="📄"
readonly SYMBOL_VIDEO="🎬"

# Configuration
DEFAULT_VIDEO_EXTENSIONS=("mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "3gp")
DEFAULT_IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "gif" "bmp" "webp" "tiff" "tif" "svg" "ico" "heic" "heif")
DEFAULT_AUDIO_EXTENSIONS=("mp3" "flac" "wav" "aac" "m4a" "ogg" "opus" "wma" "alac" "ape" "wv" "tta")

LOG_DIR="$HOME/.video-manager-logs"
LOG_FILE="$LOG_DIR/video-manager-$(date +%Y%m%d-%H%M%S).log"
UNDO_LOG_DIR="$LOG_DIR/undo-history"
BACKUP_DIR="$HOME/.video-manager-backups"
CONFIG_FILE="$HOME/.video-manager-config.conf"
MAX_LOG_ENTRIES=1000
DRY_RUN=false
VERBOSE=true
INTERACTIVE=true

# Organize by Subfolder Settings
ORGANIZE_DEFAULT_TARGET="."
ORGANIZE_DEFAULT_SEARCH="."
ORGANIZE_SHOW_PROGRESS=true
ORGANIZE_LOG_OPERATIONS=true

# Granular Control Settings
INTERACTIVE_CONFIRM=false # Ask for confirmation on each file
SHOW_PREVIEW=true # Show before/after preview
STEP_BY_STEP=false # Pause after each operation
SELECTIVE_MODE=false # Allow selecting specific files
AUTO_SKIP_ERRORS=false # Auto-skip files with errors
CONFIRM_DESTRUCTIVE=true # Always confirm destructive operations

# Granular Filters
FILTER_BY_SIZE=false # Enable file size filtering
FILTER_MIN_SIZE_MB=0 # Minimum file size in MB
FILTER_MAX_SIZE_MB=0 # Maximum file size in MB
FILTER_BY_DATE=false # Enable date filtering
FILTER_DAYS_OLD=0 # Only process files older than N days
FILTER_BY_PATTERN=false # Enable pattern filtering
FILTER_PATTERN="" # Regex pattern to match

# Processing Limits
MAX_FILES_PER_OPERATION=0 # 0 = unlimited
BATCH_SIZE=10 # Process files in batches
PAUSE_BETWEEN_BATCHES=false # Pause between batches

# Subtitle generation configuration
WHISPER_MODEL="base"  # tiny, base, small, medium, large
SUBTITLE_FORMAT="srt" # srt, vtt, txt, json
SUBTITLE_LANGUAGE="auto" # auto or language code (en, es, fr, etc.)
SUBTITLE_SUFFIX=".srt"
SUBTITLE_PARALLEL_JOBS=2 # Number of parallel subtitle generation jobs (1-8)
SUBTITLE_USE_GPU=false # Use GPU acceleration if available
SUBTITLE_OPTIMIZE_BATCH=false # Optimize batch processing order
SUBTITLE_RECURSIVE=false # Scan subdirectories recursively
SUBTITLE_MIN_DEPTH=1 # Minimum subdirectory depth for recursive scan
SUBTITLE_MAX_DEPTH=5 # Maximum subdirectory depth for recursive scan
SUBTITLE_MIN_SIZE_MB=0 # Minimum file size filter in MB (0=disabled)
SUBTITLE_MAX_SIZE_MB=0 # Maximum file size filter in MB (0=disabled)
SUBTITLE_MODIFIED_DAYS=0 # Only process files modified within N days (0=disabled)
SUBTITLE_SKIP_EXISTING=true # Skip files that already have subtitles
SUBTITLE_INTERACTIVE_SELECT=false # Interactively select files before processing
SUBTITLE_RESUME_FILE="$HOME/.video-manager-subtitle-resume.txt" # For future resume/checkpoint feature

# Advanced subtitle settings (referenced by ui.sh advanced menu)
SUBTITLE_SPEAKER_DIARIZATION=false  # Speaker diarization (future: pyannote-audio)
SUBTITLE_AUTO_PUNCTUATION=false     # Run fix_punctuation() after generation
SUBTITLE_INTERACTIVE_EDIT=false     # Open editor after each subtitle is generated
SUBTITLE_AUTO_EDIT=false            # Auto-apply fixes without interactive prompt
SUBTITLE_MAX_FILES=0                # Max files to process per run (0=unlimited)
SUBTITLE_SHOW_DIR_STATS=true        # Show per-directory stats summary
SUBTITLE_SKIP_PATTERNS=(".*" "_*" "node_modules" ".git" ".svn" "Trash" "tmp" "temp")

# Quick-win features
ENABLE_UNDO=true # Enable undo/rollback functionality
UNDO_HISTORY_FILE="$HOME/.video-manager-undo.json"
ENABLE_SOUND_NOTIFY=true # Sound notifications on completion
DRY_RUN_DIFF=true # Show before/after preview in dry-run

# Multi-Drive Catalog System
CATALOG_ENABLED=true # Enable catalog system
CATALOG_DB="$HOME/.video-manager-catalog.json" # Catalog database file
CATALOG_DRIVES_DB="$HOME/.video-manager-drives.json" # Known drives database
CATALOG_AUTO_SCAN=false # Auto-scan on drive connect
CATALOG_INCLUDE_METADATA=true # Extract metadata (duration, resolution, dimensions, etc.)
CATALOG_INCLUDE_HASH=true # Calculate file hashes (slower but detects duplicates)
CATALOG_OFFLINE_RETENTION=90 # Days to keep offline drive data (0=forever)

# Media type configuration
CATALOG_VIDEOS=true # Catalog video files
CATALOG_IMAGES=true # Catalog image files
CATALOG_AUDIO=true # Catalog audio files

# Statistics tracking
declare -A STATS
STATS[files_processed]=0
STATS[files_renamed]=0
STATS[files_moved]=0
STATS[files_skipped]=0
STATS[errors]=0
STATS[duplicates_found]=0
STATS[space_saved]=0
STATS[subtitles_generated]=0
STATS[subtitles_failed]=0
STATS[subtitles_translated]=0
STATS[low_confidence_count]=0

# Global variables
START_TIME=""
TARGET_FOLDER=""
OS_TYPE=""  # Will be set by platform.sh

################################################################################
# HELPER FUNCTIONS - Common utilities to reduce code duplication
################################################################################

# Toggle a boolean variable between true and false
# Args: $1 - variable name (without $)
# Example: toggle_flag DRY_RUN
toggle_flag() {
    local var_name="$1"
    local current_value="${!var_name}"
    if [[ "$current_value" == true ]]; then
        printf -v "$var_name" false
    else
        printf -v "$var_name" true
    fi
}

# Toggle a flag and log the result
# Args: $1 - variable name, $2 - display name for logging
# Example: toggle_flag_with_log DRY_RUN "Dry run mode"
toggle_flag_with_log() {
    local var_name="$1"
    local display_name="$2"
    toggle_flag "$var_name"
    local new_value="${!var_name}"
    if [[ "$new_value" == true ]]; then
        [[ "$(type -t log_success)" == "function" ]] && log_success "$display_name ENABLED" || echo "$display_name ENABLED"
    else
        [[ "$(type -t log_success)" == "function" ]] && log_success "$display_name DISABLED" || echo "$display_name DISABLED"
    fi
}

# Print a toggle setting with consistent formatting
# Args: $1 - label, $2 - variable value (true/false), $3 - optional extra info
# Example: print_toggle_setting "Dry Run" "$DRY_RUN"
print_toggle_setting() {
    local label="$1"
    local value="$2"
    local extra="${3:-}"

    printf "  ${COLOR_CYAN}%-22s${COLOR_RESET} " "$label:"
    if [[ "$value" == true ]]; then
        echo -e "${COLOR_GREEN}${SYMBOL_CHECK} ENABLED${COLOR_RESET}${extra:+ ${COLOR_WHITE}$extra${COLOR_RESET}}"
    else
        echo -e "${COLOR_RED}${SYMBOL_CROSS} DISABLED${COLOR_RESET}${extra:+ ${COLOR_WHITE}$extra${COLOR_RESET}}"
    fi
}


# Load a module with standardized error handling
# Args: $1 - module filename (relative to LIB_DIR)
# Returns: 0 on success, exits on failure
load_module() {
    local module="$1"
    local module_path="${LIB_DIR:-lib}/$module"

    if ! source "$module_path"; then
        echo "ERROR: Failed to load $module" >&2
        exit 1
    fi
}

# Generic menu loop handler
# Reduces boilerplate for menu-based UI patterns
# Args: $1 - menu display function, $2 - choice handler function
#       $3 - reset_stats (true/false, default true)
# The handler function receives the choice and should return:
#   0 = continue loop, 1 = break loop, 2 = invalid choice
# Example: run_menu_loop show_settings_menu handle_settings_choice true
run_menu_loop() {
    local menu_func="$1"
    local handler_func="$2"
    local reset_stats="${3:-true}"

    while true; do
        # Display the menu
        "$menu_func"

        # Read user choice
        read -r choice

        # Handle the choice
        "$handler_func" "$choice"
        local result=$?

        case $result in
            0) ;; # Continue loop
            1) break ;; # Exit loop
            2) # Invalid choice
                [[ "$(type -t log_error)" == "function" ]] && log_error "Invalid option" || echo "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac

        # Reset statistics if enabled
        if [[ "$reset_stats" == true ]] && [[ "$(type -t reset_statistics)" == "function" ]]; then
            reset_statistics
        fi
    done
}



################################################################################
# INITIALIZATION
################################################################################

# Initialize core module
init_core() {
    # Create necessary directories
    mkdir -p "$LOG_DIR" 2>/dev/null
    mkdir -p "$UNDO_LOG_DIR" 2>/dev/null
    mkdir -p "$BACKUP_DIR" 2>/dev/null

    # Set start time for statistics
    START_TIME=$(date +%s)

    return 0
}

# Reset statistics
reset_statistics() {
    STATS[files_processed]=0
    STATS[files_renamed]=0
    STATS[files_moved]=0
    STATS[files_skipped]=0
    STATS[errors]=0
    STATS[duplicates_found]=0
    STATS[space_saved]=0
    STATS[subtitles_generated]=0
    STATS[subtitles_failed]=0
    STATS[subtitles_translated]=0
    STATS[low_confidence_count]=0
}

# Module loaded successfully
return 0
