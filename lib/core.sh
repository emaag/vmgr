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
# Version: 1.7.0
# Date: October 18, 2026
#
################################################################################

# Script metadata
readonly SCRIPT_VERSION="1.7.0"
readonly SCRIPT_NAME="Video Manager Ultimate - Bash Edition"
readonly SCRIPT_DATE="2026-10-18"

# Plain mode: NO_COLOR (https://no-color.org) or a dumb terminal drops all
# escape codes; a non-UTF-8 locale or the linux console falls back to ASCII glyphs.
if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]]; then _VM_NC=""; fi
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) _VM_ASCII=0 ;;
    *) _VM_ASCII=1 ;;
esac
[[ "${TERM:-}" == "dumb" || "${TERM:-}" == "linux" ]] && _VM_ASCII=1

# Color codes for beautiful output
readonly COLOR_RESET="${_VM_NC-$'\033[0m'}"
readonly COLOR_BOLD="${_VM_NC-$'\033[1m'}"
readonly COLOR_RED="${_VM_NC-$'\033[0;31m'}"
readonly COLOR_GREEN="${_VM_NC-$'\033[0;32m'}"
readonly COLOR_YELLOW="${_VM_NC-$'\033[0;33m'}"
readonly COLOR_BLUE="${_VM_NC-$'\033[0;34m'}"
readonly COLOR_MAGENTA="${_VM_NC-$'\033[0;35m'}"
readonly COLOR_CYAN="${_VM_NC-$'\033[0;36m'}"
readonly COLOR_WHITE="${_VM_NC-$'\033[0;37m'}"
readonly COLOR_BRIGHT_RED="${_VM_NC-$'\033[1;31m'}"
readonly COLOR_BRIGHT_GREEN="${_VM_NC-$'\033[1;32m'}"
readonly COLOR_BRIGHT_YELLOW="${_VM_NC-$'\033[1;33m'}"
readonly COLOR_BRIGHT_BLUE="${_VM_NC-$'\033[1;34m'}"
readonly COLOR_BRIGHT_MAGENTA="${_VM_NC-$'\033[1;35m'}"
readonly COLOR_BRIGHT_CYAN="${_VM_NC-$'\033[1;36m'}"

# Unicode characters for visual appeal (ASCII stand-ins in plain mode)
if (( _VM_ASCII )); then
    readonly SYMBOL_CHECK="+"
    readonly SYMBOL_CROSS="x"
    readonly SYMBOL_ARROW=">"
    readonly SYMBOL_BULLET="*"
    readonly SYMBOL_STAR="*"
    readonly SYMBOL_WARN="!"
    readonly SYMBOL_INFO="i"
    readonly SYMBOL_FOLDER="[D]"
    readonly SYMBOL_FILE="[F]"
    readonly SYMBOL_VIDEO="[V]"
else
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
fi

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
VERBOSE=false
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
SUBTITLE_PARALLEL_JOBS=1 # Number of parallel subtitle generation jobs (1-8); keep 1 on CPU to avoid OOM
SUBTITLE_TIMEOUT=7200    # Max seconds per file before whisper is killed (default: 2 hours)
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
CATALOG_STALE_DAYS=30       # Warn when a drive has not been scanned for this many days
CATALOG_OFFLINE_RETENTION=90 # Days to keep offline drive data (0=forever)

# Media type configuration
CATALOG_VIDEOS=true # Catalog video files
CATALOG_IMAGES=true # Catalog image files
CATALOG_AUDIO=true # Catalog audio files

# Statistics tracking
declare -gA STATS
STATS[files_processed]=0
STATS[files_renamed]=0
STATS[files_moved]=0
STATS[files_previewed]=0
STATS[files_restored]=0
STATS[files_downloaded]=0
STATS[files_trashed]=0
STATS[space_trashed]=0
STATS[catalog_added]=0
STATS[catalog_updated]=0
STATS[catalog_removed]=0
STATS[catalog_unchanged]=0
STATS[files_skipped]=0
STATS[errors]=0
STATS[duplicates_found]=0
STATS[space_saved]=0
STATS[subtitles_generated]=0
STATS[subtitles_failed]=0
STATS[subtitles_translated]=0
STATS[subtitles_no_speech]=0
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

    local on_dot="${UI_DOT_ON:-$SYMBOL_CHECK}" off_dot="${UI_DOT_OFF:-$SYMBOL_CROSS}"
    printf "  ${UI_DIM:-$COLOR_CYAN}%-22s${COLOR_RESET} " "$label"
    if [[ "$value" == true ]]; then
        echo -e "${UI_OK:-$COLOR_GREEN}${on_dot} on${COLOR_RESET}${extra:+ ${UI_DIM:-$COLOR_WHITE}$extra${COLOR_RESET}}"
    else
        echo -e "${UI_DIM:-$COLOR_RED}${off_dot} off${COLOR_RESET}${extra:+ ${UI_DIM:-$COLOR_WHITE}$extra${COLOR_RESET}}"
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

# ── Undo recording ────────────────────────────────────────────────────────────
# One undo log per user-level operation (start_operation clears the current one).
# Each line is "original_path|new_path"; undo moves the new path back.
UNDO_CURRENT_LOG=""

# Turn an operation name into a short filename-safe slug.
_undo_slug() {
    local s="${1,,}"
    s="${s//[^a-z0-9]/-}"
    while [[ "$s" == *--* ]]; do s="${s//--/-}"; done
    s="${s#-}"; s="${s%-}"
    [[ -z "$s" ]] && s="operation"
    printf '%s' "${s:0:30}"
}

# Open a new undo log for CURRENT_OPERATION and make it current.
# Returns 1 (and records nothing) if the undo directory is not writable.
_undo_start_log() {
    mkdir -p "$UNDO_LOG_DIR" 2>/dev/null || return 1
    local id file n=1
    id="$(_undo_slug "${CURRENT_OPERATION:-operation}")-$(date +%Y%m%d-%H%M%S)"
    file="$UNDO_LOG_DIR/$id.log"
    while [[ -e "$file" ]]; do
        file="$UNDO_LOG_DIR/$id-$((++n)).log"
    done
    {
        echo "# Undo Log"
        echo "# Operation: ${CURRENT_OPERATION:-operation}"
        echo "# Operation ID: $(basename "$file" .log)"
        echo "# Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Format: original_path|new_path"
    } > "$file" 2>/dev/null || return 1
    UNDO_CURRENT_LOG="$file"
}

# undo_record ORIGINAL NEW: remember that ORIGINAL was moved or renamed to NEW.
# Does nothing when the undo system is off. Call only for real changes.
undo_record() {
    [[ "${ENABLE_UNDO:-true}" == true ]] || return 0
    if [[ -z "$UNDO_CURRENT_LOG" || ! -f "$UNDO_CURRENT_LOG" ]]; then
        _undo_start_log || return 0
    fi
    printf '%s|%s\n' "$1" "$2" >> "$UNDO_CURRENT_LOG"
}

# Number of changes recorded in the current undo log.
undo_recorded_count() {
    [[ -n "$UNDO_CURRENT_LOG" && -f "$UNDO_CURRENT_LOG" ]] || { echo 0; return; }
    local n
    n=$(grep -vc '^#' "$UNDO_CURRENT_LOG" 2>/dev/null) || n=0
    echo "$n"
}

# ── Trash ─────────────────────────────────────────────────────────────────────
# Files the tool removes (duplicates) go to a hidden .vmgr-trash folder inside the
# scanned directory, which is on the same filesystem so the move is instant, and
# are recorded in the undo log. Every recursive scan skips this folder.
VMGR_TRASH_DIR=".vmgr-trash"

# trash_file FILE ROOT STAMP: move FILE to ROOT/.vmgr-trash/STAMP/ (keeping its path
# relative to ROOT) and record it for undo. The new path is left in TRASH_LAST_DEST
# (not printed, so callers need no subshell and the undo log stays shared).
# Returns 1 if the file could not be moved; the original is left alone.
TRASH_LAST_DEST=""
trash_file() {
    local file="$1" root="${2%/}" stamp="$3" rel dest n=1
    rel="${file#"$root"/}"
    [[ "$rel" == "$file" ]] && rel="$(basename "$file")"
    dest="$root/$VMGR_TRASH_DIR/$stamp/$rel"
    while [[ -e "$dest" ]]; do
        dest="$root/$VMGR_TRASH_DIR/$stamp/$rel.$((++n))"
    done
    mkdir -p "$(dirname "$dest")" 2>/dev/null || return 1
    mv -- "$file" "$dest" 2>/dev/null || return 1
    undo_record "$file" "$dest"
    TRASH_LAST_DEST="$dest"
}

# Remove now-empty folders left in a trash after files were restored from it.
# Args: the path a file was restored from.
trash_prune_empty() {
    local dir
    dir="$(dirname "$1")"
    while [[ "$dir" == *"/$VMGR_TRASH_DIR/"* || "$dir" == *"/$VMGR_TRASH_DIR" ]]; do
        rmdir "$dir" 2>/dev/null || break
        dir="$(dirname "$dir")"
    done
}

# Yes/no prompt: the themed single-key ui_confirm when theme.sh is loaded, a
# plain line prompt otherwise. Returns 0 for yes.
ask_yes_no() {
    if [[ "$(type -t ui_confirm)" == "function" ]]; then
        ui_confirm "$@"
    else
        local _answer
        read -r -p "$1 (y/n): " _answer
        [[ "$_answer" =~ ^[Yy]$ ]]
    fi
}

# Wait for a key: ui_pause when theme.sh is loaded, "Press Enter" otherwise.
pause_for_key() {
    if [[ "$(type -t ui_pause)" == "function" ]]; then
        ui_pause "$@"
    else
        read -r -p "Press Enter to continue..." _
    fi
}

# Move off an in-place progress line before printing a message: wipes the bar
# when the theme is loaded, a plain newline otherwise.
progress_break() {
    if [[ "$(type -t ui_progress_clear)" == "function" ]]; then
        ui_progress_clear
    else
        echo ""
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

        # Read user choice: one keypress when the theme module is loaded
        if [[ "$(type -t ui_read_choice)" == "function" ]]; then
            ui_read_choice choice || break
            [[ "$choice" == ESC ]] && choice=b
        else
            read -r choice || break
        fi

        # Handle the choice
        "$handler_func" "$choice"
        local result=$?

        case $result in
            0) ;; # Continue loop
            1) break ;; # Exit loop
            2) # Invalid choice
                if [[ "$(type -t log_error)" == "function" ]]; then
                    log_error "Invalid option"
                else
                    echo "Invalid option"
                fi
                # On a terminal the message flashes and the menu redraws; elsewhere wait
                if [[ -t 0 && -t 1 ]]; then sleep 1; else pause_for_key; fi
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
    STATS[files_previewed]=0
    STATS[files_restored]=0
    STATS[files_downloaded]=0
    STATS[files_trashed]=0
    STATS[space_trashed]=0
    STATS[catalog_added]=0
    STATS[catalog_updated]=0
    STATS[catalog_removed]=0
    STATS[catalog_unchanged]=0
    STATS[files_skipped]=0
    STATS[errors]=0
    STATS[duplicates_found]=0
    STATS[space_saved]=0
    STATS[subtitles_generated]=0
    STATS[subtitles_failed]=0
    STATS[subtitles_translated]=0
    STATS[subtitles_no_speech]=0
    STATS[low_confidence_count]=0
}

# Module loaded successfully
return 0
