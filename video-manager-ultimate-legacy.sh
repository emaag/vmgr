#!/bin/bash

################################################################################
#
#  VIDEO MANAGER ULTIMATE - BASH EDITION
#
#  A comprehensive, ultra-verbose video file management system for Linux/WSL
#  Complements the PowerShell Ultimate Edition with bash-native features
#
#  Author: Created for Eric's Video Management System
#  Version: 1.1.0
#  Date: November 2, 2025
#
#  Features:
#  - Interactive menu system with color-coded output
#  - Command-line argument support for automation
#  - Real-time verbose progress tracking
#  - Comprehensive logging with timestamps
#  - Duplicate detection (exact hash-based)
#  - Directory flattening with conflict resolution
#  - Bracket notation standardization
#  - Dash removal and spacing fixes
#  - Automatic subtitle generation (Whisper AI)
#  - Dry-run mode for safe testing
#  - Statistics tracking and reporting
#  - WSL and native Linux path support
#  - Batch processing multiple folders
#
################################################################################

# Script metadata
SCRIPT_VERSION="1.1.0"
SCRIPT_NAME="Video Manager Ultimate - Bash Edition"
SCRIPT_DATE="2025-11-02"

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
LOG_DIR="$HOME/.video-manager-logs"
LOG_FILE="$LOG_DIR/video-manager-$(date +%Y%m%d-%H%M%S).log"
UNDO_LOG_DIR="$LOG_DIR/undo-history"
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
SUBTITLE_RESUME_FILE="$HOME/.video-manager-subtitle-resume.txt"
SUBTITLE_MIN_CONFIDENCE=0.5 # Minimum confidence score (0.0 - 1.0)
SUBTITLE_AUTO_TRANSLATE=false # Auto-translate subtitles
SUBTITLE_TRANSLATE_TO="en" # Target language for translation

# Advanced features
SUBTITLE_USE_GPU=false # Enable GPU acceleration (auto-detect CUDA)
SUBTITLE_OPTIMIZE_BATCH=true # Sort videos by size for efficiency
SUBTITLE_SPEAKER_DIARIZATION=false # Identify different speakers
SUBTITLE_INTERACTIVE_EDIT=false # Enable interactive editing mode
SUBTITLE_AUTO_EDIT=true # Automatically edit subtitles without prompting
SUBTITLE_AUTO_PUNCTUATION=true # Auto-fix punctuation and capitalization

# Recursive scanning options
SUBTITLE_RECURSIVE=false # Scan subdirectories recursively
SUBTITLE_MAX_DEPTH=10 # Maximum recursion depth (1-50)
SUBTITLE_MAX_FILES=1000 # Maximum files to process in recursive mode
SUBTITLE_MIN_DEPTH=1 # Minimum depth to start scanning (0=include current dir)
SUBTITLE_INTERACTIVE_SELECT=false # Interactively choose subdirectories

# Advanced filtering
SUBTITLE_SKIP_PATTERNS=(".*" "_*" "node_modules" ".git" ".svn" "Trash" "tmp" "temp") # Directories to skip
SUBTITLE_MIN_SIZE_MB=0 # Minimum file size in MB (0=no limit)
SUBTITLE_MAX_SIZE_MB=0 # Maximum file size in MB (0=no limit)
SUBTITLE_MODIFIED_DAYS=0 # Only process files modified in last N days (0=no limit)
SUBTITLE_SHOW_DIR_STATS=true # Show statistics per directory
SUBTITLE_SKIP_EXISTING=true # Skip videos that already have subtitles

# Quick-win features
ENABLE_UNDO=true # Enable undo/rollback functionality
UNDO_HISTORY_FILE="$HOME/.video-manager-undo.json"
FAVORITES_FILE="$HOME/.video-manager-favorites.txt"
WATCH_FOLDERS_FILE="$HOME/.video-manager-watch.txt"
RENAME_PRESETS_FILE="$HOME/.video-manager-presets.json"
ENABLE_EMAIL_NOTIFY=false # Send email notifications
EMAIL_RECIPIENT="" # Email address for notifications
ENABLE_SOUND_NOTIFY=true # Sound notifications on completion
THEME="auto" # Color theme: auto, dark, light
DRY_RUN_DIFF=true # Show before/after preview in dry-run

# Backup & Restore System
BACKUP_ENABLED=true # Enable automatic backups before operations
BACKUP_DIR="$HOME/.video-manager-backups" # Backup storage location
BACKUP_MAX_COUNT=20 # Maximum backups to keep (auto-cleanup)
BACKUP_COMPRESSION=true # Compress backups with gzip
BACKUP_INCLUDE_LOGS=true # Include operation logs in backups

# Configuration Management
CONFIG_FILE="$HOME/.video-manager.conf" # Main configuration file
CONFIG_AUTO_SAVE=true # Auto-save settings on change
CONFIG_AUTO_LOAD=true # Auto-load settings on startup
CONFIG_PROFILE="default" # Active configuration profile

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

# Supported file extensions
DEFAULT_IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "gif" "bmp" "webp" "tiff" "tif" "svg" "ico" "heic" "heif")
DEFAULT_AUDIO_EXTENSIONS=("mp3" "flac" "wav" "aac" "m4a" "ogg" "opus" "wma" "alac" "ape" "wv" "tta")

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
CURRENT_OPERATION=""
START_TIME=""
TARGET_FOLDER=""

################################################################################
# PLATFORM DETECTION & COMPATIBILITY
################################################################################

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                OS_TYPE="WSL"
            else
                OS_TYPE="Linux"
            fi
            ;;
        Darwin*)
            OS_TYPE="macOS"
            ;;
        CYGWIN*|MINGW*|MSYS*|MINGW32*|MINGW64*)
            OS_TYPE="Windows"
            ;;
        *)
            OS_TYPE="Unknown"
            ;;
    esac
    export OS_TYPE
}

# Platform-specific stat command for file size
get_file_size_bytes() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi

    case "$OS_TYPE" in
        macOS)
            stat -f%z "$file" 2>/dev/null || echo "0"
            ;;
        *)
            stat -c%s "$file" 2>/dev/null || echo "0"
            ;;
    esac
}

# Platform-specific hash calculation
calculate_file_hash() {
    local file="$1"

    # Validate input
    if [[ -z "$file" ]]; then
        log_error "calculate_file_hash: file parameter is required"
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        log_error "calculate_file_hash: file does not exist: $file"
        return 1
    fi

    case "$OS_TYPE" in
        macOS)
            if command -v shasum &>/dev/null; then
                shasum -a 256 "$file" 2>/dev/null | awk '{print $1}'
            elif command -v openssl &>/dev/null; then
                openssl sha256 "$file" 2>/dev/null | awk '{print $NF}'
            fi
            ;;
        *)
            if command -v sha256sum &>/dev/null; then
                sha256sum "$file" 2>/dev/null | awk '{print $1}'
            elif command -v shasum &>/dev/null; then
                shasum -a 256 "$file" 2>/dev/null | awk '{print $1}'
            fi
            ;;
    esac
}

# Platform-specific numfmt alternative
format_bytes() {
    local bytes="$1"

    # Validate input
    if [[ -z "$bytes" ]]; then
        echo "0B"
        return 0
    fi

    # Ensure bytes is a number
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        log_error "format_bytes: invalid number: $bytes"
        echo "0B"
        return 1
    fi

    if command -v numfmt &>/dev/null; then
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null
    else
        # Fallback manual formatting
        if (( bytes < 1024 )); then
            echo "${bytes}B"
        elif (( bytes < 1048576 )); then
            echo "$(( bytes / 1024 ))KiB"
        elif (( bytes < 1073741824 )); then
            echo "$(( bytes / 1048576 ))MiB"
        else
            echo "$(( bytes / 1073741824 ))GiB"
        fi
    fi
}

# Platform-specific file opening
open_file_manager() {
    local path="$1"

    case "$OS_TYPE" in
        macOS)
            open "$path"
            ;;
        Windows|WSL)
            if command -v explorer.exe &>/dev/null; then
                explorer.exe "$path"
            elif command -v xdg-open &>/dev/null; then
                xdg-open "$path"
            fi
            ;;
        Linux)
            if command -v xdg-open &>/dev/null; then
                xdg-open "$path"
            elif command -v nautilus &>/dev/null; then
                nautilus "$path"
            elif command -v dolphin &>/dev/null; then
                dolphin "$path"
            fi
            ;;
    esac
}

# Check for required commands and suggest installation
check_dependencies() {
    local missing_deps=()

    # Core dependencies
    if ! command -v jq &>/dev/null; then
        missing_deps+=("jq")
    fi

    # Optional but recommended
    if ! command -v ffprobe &>/dev/null; then
        log_warning "ffprobe not found - video metadata extraction will be limited"
    fi

    if ! command -v exiftool &>/dev/null && ! command -v identify &>/dev/null; then
        log_warning "exiftool or ImageMagick not found - EXIF extraction will be limited"
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${COLOR_YELLOW}${SYMBOL_WARN} Missing required dependencies: ${missing_deps[*]}${COLOR_RESET}"
        echo ""
        case "$OS_TYPE" in
            macOS)
                echo "Install with: brew install ${missing_deps[*]}"
                ;;
            Linux|WSL)
                echo "Install with: sudo apt-get install ${missing_deps[*]}"
                ;;
            Windows)
                echo "Install jq from: https://stedolan.github.io/jq/download/"
                ;;
        esac
        echo ""
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Initialize platform detection
detect_os

################################################################################
# CONFIGURATION MANAGEMENT
################################################################################

# Save current configuration
save_config() {
    local profile="${1:-default}"
    local config_file="${CONFIG_FILE%.conf}-${profile}.conf"

    log_verbose "Saving configuration to $config_file"

    cat > "$config_file" << EOF
# Video Manager Ultimate Configuration
# Profile: $profile
# Generated: $(date)

# General Settings
DRY_RUN=$DRY_RUN
VERBOSE=$VERBOSE
INTERACTIVE=$INTERACTIVE

# Granular Controls
INTERACTIVE_CONFIRM=$INTERACTIVE_CONFIRM
SHOW_PREVIEW=$SHOW_PREVIEW
STEP_BY_STEP=$STEP_BY_STEP
SELECTIVE_MODE=$SELECTIVE_MODE
AUTO_SKIP_ERRORS=$AUTO_SKIP_ERRORS
CONFIRM_DESTRUCTIVE=$CONFIRM_DESTRUCTIVE

# Filters
FILTER_BY_SIZE=$FILTER_BY_SIZE
FILTER_MIN_SIZE_MB=$FILTER_MIN_SIZE_MB
FILTER_MAX_SIZE_MB=$FILTER_MAX_SIZE_MB
FILTER_BY_DATE=$FILTER_BY_DATE
FILTER_DAYS_OLD=$FILTER_DAYS_OLD
FILTER_BY_PATTERN=$FILTER_BY_PATTERN
FILTER_PATTERN="$FILTER_PATTERN"

# Processing
MAX_FILES_PER_OPERATION=$MAX_FILES_PER_OPERATION
BATCH_SIZE=$BATCH_SIZE
PAUSE_BETWEEN_BATCHES=$PAUSE_BETWEEN_BATCHES
ENABLE_UNDO=$ENABLE_UNDO

# Catalog
CATALOG_ENABLED=$CATALOG_ENABLED
CATALOG_VIDEOS=$CATALOG_VIDEOS
CATALOG_IMAGES=$CATALOG_IMAGES
CATALOG_AUDIO=$CATALOG_AUDIO
CATALOG_INCLUDE_METADATA=$CATALOG_INCLUDE_METADATA
CATALOG_INCLUDE_HASH=$CATALOG_INCLUDE_HASH

# Subtitle
WHISPER_MODEL="$WHISPER_MODEL"
SUBTITLE_FORMAT="$SUBTITLE_FORMAT"
SUBTITLE_LANGUAGE="$SUBTITLE_LANGUAGE"
SUBTITLE_PARALLEL_JOBS=$SUBTITLE_PARALLEL_JOBS
SUBTITLE_USE_GPU=$SUBTITLE_USE_GPU
SUBTITLE_OPTIMIZE_BATCH=$SUBTITLE_OPTIMIZE_BATCH
EOF

    log_success "Configuration saved: $profile"
}

# Load configuration
load_config() {
    local profile="${1:-default}"
    local config_file="${CONFIG_FILE%.conf}-${profile}.conf"

    if [[ ! -f "$config_file" ]]; then
        log_warning "Configuration file not found: $config_file"
        return 1
    fi

    log_verbose "Loading configuration from $config_file"

    # Source the configuration file
    source "$config_file"

    log_success "Configuration loaded: $profile"
}

# List available configuration profiles
list_config_profiles() {
    local config_dir=$(dirname "$CONFIG_FILE")
    local base_name=$(basename "${CONFIG_FILE%.conf}")

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}Available Configuration Profiles:${COLOR_RESET}"
    echo ""

    local count=0
    for config in "$config_dir"/${base_name}-*.conf; do
        if [[ -f "$config" ]]; then
            ((count++))
            local profile=$(basename "$config")
            profile=${profile#${base_name}-}
            profile=${profile%.conf}

            local mod_date=$(date -r "$config" "+%Y-%m-%d %H:%M" 2>/dev/null || stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$config" 2>/dev/null)

            echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} ${COLOR_WHITE}$profile${COLOR_RESET}"
            echo -e "    ${COLOR_CYAN}Modified:${COLOR_RESET} $mod_date"
            echo -e "    ${COLOR_CYAN}File:${COLOR_RESET}     $config"
            echo ""
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "  ${COLOR_YELLOW}No saved profiles found${COLOR_RESET}"
        echo ""
    fi
}

# Delete configuration profile
delete_config_profile() {
    local profile="$1"
    local config_file="${CONFIG_FILE%.conf}-${profile}.conf"

    if [[ ! -f "$config_file" ]]; then
        log_error "Profile not found: $profile"
        return 1
    fi

    rm -f "$config_file"
    log_success "Profile deleted: $profile"
}

################################################################################
# UTILITY FUNCTIONS
################################################################################

# Initialize logging system
init_logging() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            log_verbose "Created log directory: $LOG_DIR"
        else
            echo -e "${COLOR_RED}${SYMBOL_WARN} Warning: Could not create log directory${COLOR_RESET}"
        fi
    fi
    
    # Rotate old logs if too many exist
    local log_count=$(find "$LOG_DIR" -name "video-manager-*.log" 2>/dev/null | wc -l)
    if [[ $log_count -gt 50 ]]; then
        log_verbose "Rotating old log files (found $log_count logs)..."
        find "$LOG_DIR" -name "video-manager-*.log" -type f | sort | head -n -50 | xargs rm -f 2>/dev/null
    fi
    
    # Create new log file
    touch "$LOG_FILE" 2>/dev/null
    log_message "INFO" "=========================================="
    log_message "INFO" "$SCRIPT_NAME v$SCRIPT_VERSION"
    log_message "INFO" "Session started: $(date '+%Y-%m-%d %H:%M:%S')"
    log_message "INFO" "=========================================="
}

# Write to log file
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
}

# Verbose console output with logging
log_verbose() {
    local message="$*"
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${COLOR_CYAN}${SYMBOL_INFO}${COLOR_RESET} $message"
    fi
    log_message "INFO" "$message"
}

# Success message
log_success() {
    local message="$*"
    echo -e "${COLOR_BRIGHT_GREEN}${SYMBOL_CHECK}${COLOR_RESET} $message"
    log_message "SUCCESS" "$message"
}

# Error message
log_error() {
    local message="$*"
    echo -e "${COLOR_BRIGHT_RED}${SYMBOL_CROSS}${COLOR_RESET} $message"
    log_message "ERROR" "$message"
    ((STATS[errors]++))
}

# Warning message
log_warning() {
    local message="$*"
    echo -e "${COLOR_BRIGHT_YELLOW}${SYMBOL_WARN}${COLOR_RESET} $message"
    log_message "WARN" "$message"
}

# Info message
log_info() {
    local message="$*"
    echo -e "${COLOR_BRIGHT_CYAN}${SYMBOL_INFO}${COLOR_RESET} $message"
    log_message "INFO" "$message"
}

# Operation start banner
start_operation() {
    CURRENT_OPERATION="$1"
    START_TIME=$(date +%s)
    
    echo ""
    echo -e "${COLOR_BRIGHT_MAGENTA}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_MAGENTA}${SYMBOL_STAR} ${COLOR_BOLD}$CURRENT_OPERATION${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_MAGENTA}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    
    log_message "OPERATION" "Started: $CURRENT_OPERATION"
}

# Operation end banner with statistics
end_operation() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo ""
    echo -e "${COLOR_BRIGHT_MAGENTA}───────────────────────────────────────────────────────────────${COLOR_RESET}"
    echo -e "${COLOR_BOLD}Operation Complete: $CURRENT_OPERATION${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_MAGENTA}───────────────────────────────────────────────────────────────${COLOR_RESET}"
    
    print_statistics
    
    echo ""
    echo -e "${COLOR_CYAN}Duration: ${minutes}m ${seconds}s${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_MAGENTA}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    
    log_message "OPERATION" "Completed: $CURRENT_OPERATION (Duration: ${minutes}m ${seconds}s)"
}

# Show progress bar
show_progress() {
    local current=$1
    local total=$2
    local message="${3:-Processing}"

    if [[ $total -eq 0 ]]; then
        return
    fi

    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    # Build progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done

    # Print progress bar (carriage return to overwrite)
    printf "\r${COLOR_CYAN}%s${COLOR_RESET} [%s] ${COLOR_BOLD}%3d%%${COLOR_RESET} ${COLOR_WHITE}(%d/%d)${COLOR_RESET}" \
        "$message" "$bar" "$percent" "$current" "$total"

    # New line when complete
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Show spinner for indefinite operations
show_spinner() {
    local pid=$1
    local message="${2:-Working}"
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${COLOR_CYAN}%s${COLOR_RESET} ${COLOR_YELLOW}%c${COLOR_RESET} " "$message" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done

    printf "\r${COLOR_GREEN}%s${COLOR_RESET} ${COLOR_GREEN}✓${COLOR_RESET}\n" "$message"
}

# Print statistics
print_statistics() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}📊 Statistics:${COLOR_RESET}"
    echo -e "   ${COLOR_WHITE}Files Processed:${COLOR_RESET}  ${COLOR_BRIGHT_CYAN}${STATS[files_processed]}${COLOR_RESET}"
    echo -e "   ${COLOR_WHITE}Files Renamed:${COLOR_RESET}    ${COLOR_BRIGHT_GREEN}${STATS[files_renamed]}${COLOR_RESET}"
    echo -e "   ${COLOR_WHITE}Files Moved:${COLOR_RESET}      ${COLOR_BRIGHT_GREEN}${STATS[files_moved]}${COLOR_RESET}"
    echo -e "   ${COLOR_WHITE}Files Skipped:${COLOR_RESET}    ${COLOR_BRIGHT_YELLOW}${STATS[files_skipped]}${COLOR_RESET}"

    if [[ ${STATS[subtitles_generated]} -gt 0 || ${STATS[subtitles_failed]} -gt 0 ]]; then
        echo -e "   ${COLOR_WHITE}Subtitles Generated:${COLOR_RESET} ${COLOR_BRIGHT_GREEN}${STATS[subtitles_generated]}${COLOR_RESET}"
        if [[ ${STATS[subtitles_failed]} -gt 0 ]]; then
            echo -e "   ${COLOR_WHITE}Subtitles Failed:${COLOR_RESET}    ${COLOR_BRIGHT_RED}${STATS[subtitles_failed]}${COLOR_RESET}"
        fi
        if [[ ${STATS[subtitles_translated]} -gt 0 ]]; then
            echo -e "   ${COLOR_WHITE}Subtitles Translated:${COLOR_RESET} ${COLOR_BRIGHT_CYAN}${STATS[subtitles_translated]}${COLOR_RESET}"
        fi
        if [[ ${STATS[low_confidence_count]} -gt 0 ]]; then
            echo -e "   ${COLOR_WHITE}Low Confidence:${COLOR_RESET}      ${COLOR_BRIGHT_YELLOW}${STATS[low_confidence_count]}${COLOR_RESET}"
        fi
    fi

    if [[ ${STATS[duplicates_found]} -gt 0 ]]; then
        echo -e "   ${COLOR_WHITE}Duplicates Found:${COLOR_RESET} ${COLOR_BRIGHT_MAGENTA}${STATS[duplicates_found]}${COLOR_RESET}"
        if [[ ${STATS[space_saved]} -gt 0 ]]; then
            local space_mb=$((STATS[space_saved] / 1024 / 1024))
            echo -e "   ${COLOR_WHITE}Space Saved:${COLOR_RESET}      ${COLOR_BRIGHT_GREEN}${space_mb} MB${COLOR_RESET}"
        fi
    fi

    if [[ ${STATS[errors]} -gt 0 ]]; then
        echo -e "   ${COLOR_WHITE}Errors:${COLOR_RESET}           ${COLOR_BRIGHT_RED}${STATS[errors]}${COLOR_RESET}"
    fi
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

# Get file size in bytes
get_file_size() {
    local file="$1"
    get_file_size_bytes "$file"
}

# Calculate SHA256 hash
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

# Convert Windows path to WSL path
convert_to_wsl_path() {
    local path="$1"

    # Validate input
    if [[ -z "$path" ]]; then
        log_error "convert_to_wsl_path: path parameter is required"
        return 1
    fi

    # Check if already a Unix path
    if [[ "$path" =~ ^/ ]]; then
        echo "$path"
        return 0
    fi
    
    # Convert Windows path (C:\Users\...) to WSL path (/mnt/c/Users/...)
    if [[ "$path" =~ ^([A-Za-z]): ]]; then
        local drive="${BASH_REMATCH[1],,}" # Convert to lowercase
        local rest="${path#*:}"
        rest="${rest//\\//}" # Convert backslashes to forward slashes
        echo "/mnt/$drive$rest"
    else
        echo "$path"
    fi
}

# Validate directory exists
validate_directory() {
    local dir="$1"
    
    if [[ -z "$dir" ]]; then
        log_error "No directory specified"
        return 1
    fi
    
    dir=$(convert_to_wsl_path "$dir")
    
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

################################################################################
# GRANULAR CONTROL FUNCTIONS
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

# Initialize undo system
init_undo_system() {
    if [[ "$ENABLE_UNDO" != true ]]; then
        return
    fi

    if [[ ! -f "$UNDO_HISTORY_FILE" ]]; then
        echo '{"operations": []}' > "$UNDO_HISTORY_FILE"
    fi
}

# Record operation for undo
record_undo_operation() {
    local operation_type="$1"
    local original_path="$2"
    local new_path="$3"

    if [[ "$ENABLE_UNDO" != true ]]; then
        return
    fi

    init_undo_system

    local timestamp=$(date -Iseconds)
    local operation_id=$(date +%s%N)

    # Add operation to history
    local temp_file=$(mktemp)
    jq --arg id "$operation_id" \
       --arg type "$operation_type" \
       --arg orig "$original_path" \
       --arg new "$new_path" \
       --arg ts "$timestamp" \
       '.operations += [{
           id: $id,
           type: $type,
           original: $orig,
           new: $new,
           timestamp: $ts,
           undone: false
       }]' "$UNDO_HISTORY_FILE" > "$temp_file" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$UNDO_HISTORY_FILE"
    else
        rm -f "$temp_file"
    fi
}

# Undo last operation
undo_last_operation() {
    if [[ "$ENABLE_UNDO" != true ]]; then
        log_error "Undo system is disabled"
        return 1
    fi

    init_undo_system

    # Get last non-undone operation
    local last_op=$(jq -r '.operations[] | select(.undone == false) | @json' "$UNDO_HISTORY_FILE" | tail -1)

    if [[ -z "$last_op" ]]; then
        log_warning "No operations to undo"
        return 1
    fi

    local op_id=$(echo "$last_op" | jq -r '.id')
    local op_type=$(echo "$last_op" | jq -r '.type')
    local original=$(echo "$last_op" | jq -r '.original')
    local new_path=$(echo "$last_op" | jq -r '.new')

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}╭─────────────────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}│${COLOR_RESET}  ${COLOR_BOLD}${COLOR_WHITE}UNDO OPERATION${COLOR_RESET}                                  ${COLOR_BOLD}${COLOR_YELLOW}│${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}╰─────────────────────────────────────────────────────╯${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}Operation Type:${COLOR_RESET} ${COLOR_WHITE}$op_type${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}File:${COLOR_RESET}           ${COLOR_WHITE}$(basename "$new_path")${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_YELLOW}Reverting:${COLOR_RESET}      ${COLOR_RED}$new_path${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}Back to:${COLOR_RESET}        ${COLOR_GREEN}$original${COLOR_RESET}"
    echo ""

    case "$op_type" in
        rename|move)
            if [[ -f "$new_path" ]] || [[ -d "$new_path" ]]; then
                mv "$new_path" "$original"
                log_success "Successfully undone operation"
            else
                log_error "Cannot undo: $new_path does not exist"
                return 1
            fi
            ;;
        *)
            log_warning "Cannot undo operation type: $op_type"
            return 1
            ;;
    esac

    # Mark as undone
    local temp_file=$(mktemp)
    jq --arg id "$op_id" \
       '(.operations[] | select(.id == $id) | .undone) = true' \
       "$UNDO_HISTORY_FILE" > "$temp_file"
    mv "$temp_file" "$UNDO_HISTORY_FILE"

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

# Rename files in directory
rename_files_in_directory() {
    local directory="$1"
    local dry_run="${2:-false}"
    
    log_info "Scanning directory: $directory"
    
    local file_count=0
    local renamed_count=0
    
    # Count total video files first
    local total_files=$(find "$directory" -maxdepth 1 -type f | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$' | wc -l)
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
        local new_filename=$(cleanup_filename "$filename")
        
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
                echo -e "${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would rename:"
                echo -e "  ${COLOR_WHITE}From:${COLOR_RESET} $filename"
                echo -e "  ${COLOR_WHITE}To:${COLOR_RESET}   $new_filename"
                log_message "DRYRUN" "Would rename: $filename -> $new_filename"
            else
                mv -- "$file" "$new_path" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} Renamed:"
                    echo -e "  ${COLOR_WHITE}From:${COLOR_RESET} $filename"
                    echo -e "  ${COLOR_WHITE}To:${COLOR_RESET}   $new_filename"
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
    
    echo -ne "\r\033[K" # Clear progress line
    
    if [[ "$dry_run" == true ]]; then
        log_info "Dry run complete - no files were actually renamed"
    else
        log_success "Renamed $renamed_count out of $file_count video files"
    fi
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
# DUPLICATE DETECTION
################################################################################

find_duplicates() {
    local directory="$1"
    local action="${2:-report}" # report or delete
    
    log_info "Scanning for duplicate video files in: $directory"
    log_verbose "This may take a while for large collections..."
    
    declare -A hash_map
    declare -A duplicate_groups
    local total_duplicates=0
    local space_wasted=0
    
    # Create output directory for reports
    local report_dir="$directory/_duplicate_report_$(date +%Y%m%d-%H%M%S)"
    
    echo ""
    
    # Find all video files and calculate hashes
    local file_count=0
    while IFS= read -r -d '' file; do
        ((file_count++))
        ((STATS[files_processed]++))
        
        local filename=$(basename "$file")
        echo -ne "\r${COLOR_CYAN}Hashing: [$file_count files] Current: ${filename:0:50}...${COLOR_RESET}"
        
        local hash=$(calculate_hash "$file")
        if [[ -z "$hash" ]]; then
            log_error "Failed to hash: $filename"
            continue
        fi
        
        if [[ -n "${hash_map[$hash]}" ]]; then
            # Duplicate found!
            log_verbose ""
            log_warning "Duplicate found!"
            log_verbose "  Hash: $hash"
            log_verbose "  Original: ${hash_map[$hash]}"
            log_verbose "  Duplicate: $file"
            
            duplicate_groups[$hash]+="$file"$'\n'
            ((total_duplicates++))
            ((STATS[duplicates_found]++))
            
            local size=$(get_file_size "$file")
            space_wasted=$((space_wasted + size))
        else
            hash_map[$hash]="$file"
        fi
    done < <(find "$directory" -type f -print0 | grep -zE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$')
    
    echo -ne "\r\033[K" # Clear line
    
    if [[ $total_duplicates -eq 0 ]]; then
        log_success "No duplicates found! Your collection is clean."
        return 0
    fi
    
    # Create report
    mkdir -p "$report_dir" 2>/dev/null
    local report_file="$report_dir/duplicates.txt"
    local csv_file="$report_dir/duplicates.csv"
    
    {
        echo "DUPLICATE VIDEO FILES REPORT"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Directory: $directory"
        echo "Total Duplicates: $total_duplicates"
        echo "Space Wasted: $((space_wasted / 1024 / 1024)) MB"
        echo ""
        echo "========================================"
        echo ""
    } > "$report_file"
    
    echo "Hash,Original File,Duplicate Files,File Size" > "$csv_file"
    
    local group_num=1
    for hash in "${!duplicate_groups[@]}"; do
        local original="${hash_map[$hash]}"
        local dupes="${duplicate_groups[$hash]}"
        local size=$(get_file_size "$original")
        local size_mb=$((size / 1024 / 1024))
        
        echo -e "${COLOR_MAGENTA}Duplicate Group #$group_num${COLOR_RESET}"
        echo "  Hash: $hash"
        echo -e "  ${COLOR_GREEN}Original:${COLOR_RESET} $original"
        echo -e "  ${COLOR_RED}Duplicates:${COLOR_RESET}"
        
        {
            echo "=== Duplicate Group #$group_num ==="
            echo "Hash: $hash"
            echo "File Size: $size_mb MB"
            echo "Original: $original"
            echo "Duplicates:"
        } >> "$report_file"
        
        while IFS= read -r dupe; do
            [[ -z "$dupe" ]] && continue
            echo "    - $dupe"
            echo "    - $dupe" >> "$report_file"
            echo "\"$hash\",\"$original\",\"$dupe\",$size" >> "$csv_file"
            
            if [[ "$action" == "delete" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    log_warning "[DRY RUN] Would delete: $dupe"
                else
                    rm -f "$dupe" 2>/dev/null
                    if [[ $? -eq 0 ]]; then
                        log_success "Deleted duplicate: $(basename "$dupe")"
                        STATS[space_saved]=$((STATS[space_saved] + size))
                    else
                        log_error "Failed to delete: $dupe"
                    fi
                fi
            fi
        done <<< "$dupes"
        
        echo "" >> "$report_file"
        echo ""
        ((group_num++))
    done
    
    log_success "Report generated: $report_file"
    log_success "CSV export: $csv_file"
    
    local space_mb=$((space_wasted / 1024 / 1024))
    log_info "Total space wasted by duplicates: ${space_mb} MB"
}

################################################################################
# ADVANCED SUBTITLE FEATURES
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

# Sort videos by size for optimal processing
sort_videos_by_size() {
    local directory="$1"
    local -a sorted_files

    # Get files with sizes, sort by size (smallest first)
    while IFS= read -r line; do
        sorted_files+=("$line")
    done < <(find "$directory" -maxdepth 1 -type f -exec du -b {} + | \
             grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$' | \
             sort -n | awk '{$1=""; print substr($0,2)}')

    printf '%s\n' "${sorted_files[@]}"
}

# Detect speaker changes in subtitle
detect_speakers() {
    local subtitle_file="$1"

    if command -v pyannote-audio &> /dev/null; then
        log_verbose "Speaker diarization available"
        # Note: This would need Python pyannote-audio package
        # Simplified placeholder for actual implementation
        return 0
    else
        log_verbose "pyannote-audio not installed, skipping speaker diarization"
        return 1
    fi
}

# Apply ML-based punctuation and capitalization fixes
fix_punctuation() {
    local subtitle_file="$1"
    local temp_file="${subtitle_file}.tmp"

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

# Interactive subtitle editor
edit_subtitle_interactive() {
    local subtitle_file="$1"

    if [[ ! -f "$subtitle_file" ]]; then
        log_error "Subtitle file not found: $subtitle_file"
        return 1
    fi

    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  INTERACTIVE SUBTITLE EDITOR${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_WHITE}File:${COLOR_RESET} $(basename "$subtitle_file")"
    echo ""
    echo -e "${COLOR_CYAN}Options:${COLOR_RESET}"
    echo "  [1] View subtitle content"
    echo "  [2] Fix punctuation automatically"
    echo "  [3] Open in text editor"
    echo "  [4] Search and replace"
    echo "  [5] Adjust all timestamps (+/- seconds)"
    echo "  [6] Remove filler words (um, uh, etc.)"
    echo "  [Q] Done editing"
    echo ""

    while true; do
        echo -n "Select option: "
        read -r choice

        case "$choice" in
            1)
                preview_subtitle "$subtitle_file" 50
                ;;
            2)
                fix_punctuation "$subtitle_file"
                log_success "Punctuation fixes applied"
                ;;
            3)
                ${EDITOR:-nano} "$subtitle_file"
                log_success "Editor closed"
                ;;
            4)
                echo -n "Search for: "
                read -r search_term
                echo -n "Replace with: "
                read -r replace_term
                # Sanitize inputs to prevent command injection
                search_term=$(sanitize_input "$search_term")
                replace_term=$(sanitize_input "$replace_term")
                # Escape for sed
                local safe_search=$(sanitize_for_sed "$search_term")
                local safe_replace=$(sanitize_for_sed "$replace_term")
                sed -i "s/${safe_search}/${safe_replace}/g" "$subtitle_file" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_success "Replaced all occurrences"
                else
                    log_error "Search and replace failed"
                fi
                ;;
            5)
                echo -n "Adjust timestamps by seconds (+/-): "
                read -r adjustment
                adjust_subtitle_timing "$subtitle_file" "$adjustment"
                ;;
            6)
                remove_filler_words "$subtitle_file"
                log_success "Filler words removed"
                ;;
            q|Q)
                log_info "Editing complete"
                break
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        echo ""
    done
}

# Adjust subtitle timing
adjust_subtitle_timing() {
    local subtitle_file="$1"
    local adjustment="$2"  # seconds to add/subtract

    if ! command -v ffmpeg &> /dev/null; then
        log_error "ffmpeg required for timing adjustments"
        return 1
    fi

    # Validate adjustment is a number
    if ! [[ "$adjustment" =~ ^[+-]?[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "Invalid adjustment value: must be a number"
        return 1
    fi

    log_verbose "Adjusting timing by ${adjustment}s"

    # Use ffmpeg to shift subtitles
    local temp_file="${subtitle_file}.adjusted"
    ffmpeg -itsoffset "$adjustment" -i "$subtitle_file" -c copy "$temp_file" 2>/dev/null

    if [[ -f "$temp_file" ]]; then
        mv "$temp_file" "$subtitle_file"
        log_success "Timing adjusted by ${adjustment}s"
        return 0
    else
        log_error "Timing adjustment failed"
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
        # Sanitize filler word for sed to prevent injection
        local safe_filler=$(sanitize_for_sed "$filler")
        sed -i "s/\b${safe_filler}\b//gi" "$subtitle_file" 2>/dev/null
    done

    # Clean up extra spaces
    sed -i 's/  \+/ /g' "$subtitle_file"

    log_success "Filler words removed"
}

# Process videos in parallel using GNU Parallel
process_videos_parallel() {
    local directory="$1"
    local model="$2"
    local format="$3"
    local language="$4"
    local jobs="${SUBTITLE_PARALLEL_JOBS:-2}"

    if ! check_parallel_support; then
        log_warning "GNU Parallel not installed, falling back to sequential processing"
        log_info "Install with: sudo apt-get install parallel"
        return 1
    fi

    log_info "Starting parallel processing with $jobs workers"

    # Export function and variables for parallel
    export -f generate_subtitle_for_file
    export -f log_success log_error log_verbose log_info log_warning log_message
    export -f is_video_processed get_video_duration get_whisper_command detect_gpu is_video_file
    export WHISPER_MODEL="$model"
    export SUBTITLE_FORMAT="$format"
    export SUBTITLE_LANGUAGE="$language"
    export SUBTITLE_RESUME_FILE SUBTITLE_USE_GPU SUBTITLE_SPEAKER_DIARIZATION
    export LOG_FILE VERBOSE DRY_RUN
    export COLOR_RESET COLOR_CYAN COLOR_BRIGHT_GREEN COLOR_BRIGHT_RED COLOR_YELLOW
    export SYMBOL_INFO SYMBOL_CHECK SYMBOL_CROSS SYMBOL_WARN
    export DEFAULT_VIDEO_EXTENSIONS
    export PATH

    # Get video files
    local video_files=()
    while IFS= read -r -d '' file; do
        if is_video_file "$file"; then
            video_files+=("$file")
        fi
    done < <(find "$directory" -maxdepth 1 -type f -print0)

    # Process in parallel
    printf '%s\n' "${video_files[@]}" | \
        parallel --jobs "$jobs" --bar \
        generate_subtitle_for_file {} "$model" "$format" "$language" false

    log_success "Parallel processing complete"
}

################################################################################
# QUICK-WIN FEATURES
################################################################################

# 1. UNDO/ROLLBACK SYSTEM

# Save operation for undo
save_undo_operation() {
    local operation="$1"
    local source="$2"
    local dest="$3"
    local timestamp=$(date +%s)

    if [[ "$ENABLE_UNDO" != true ]]; then
        return 0
    fi

    # Create undo history entry
    local undo_entry="{\"timestamp\":$timestamp,\"operation\":\"$operation\",\"source\":\"$source\",\"dest\":\"$dest\"}"

    # Append to undo file
    echo "$undo_entry" >> "$UNDO_HISTORY_FILE"

    log_verbose "Undo point saved: $operation"
}

# Undo last operation (file-based, simple implementation)
undo_last_file_operation() {
    if [[ ! -f "$UNDO_HISTORY_FILE" ]] || [[ ! -s "$UNDO_HISTORY_FILE" ]]; then
        log_error "No operations to undo"
        return 1
    fi

    # Get last operation
    local last_op=$(tail -n 1 "$UNDO_HISTORY_FILE")

    # Parse JSON (simple extraction)
    local operation=$(echo "$last_op" | grep -o '"operation":"[^"]*"' | cut -d'"' -f4)
    local source=$(echo "$last_op" | grep -o '"source":"[^"]*"' | cut -d'"' -f4)
    local dest=$(echo "$last_op" | grep -o '"dest":"[^"]*"' | cut -d'"' -f4)

    echo ""
    echo -e "${COLOR_YELLOW}Last Operation:${COLOR_RESET}"
    echo -e "  Type: ${COLOR_CYAN}$operation${COLOR_RESET}"
    echo -e "  From: ${COLOR_WHITE}$source${COLOR_RESET}"
    echo -e "  To: ${COLOR_WHITE}$dest${COLOR_RESET}"
    echo ""
    read -p "Undo this operation? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Undo cancelled"
        return 1
    fi

    # Perform undo based on operation type
    case "$operation" in
        rename)
            if [[ -f "$dest" ]]; then
                mv "$dest" "$source"
                log_success "Undone: Renamed back to $(basename "$source")"
            else
                log_error "Cannot undo: destination file not found"
                return 1
            fi
            ;;
        move)
            if [[ -f "$dest" ]]; then
                mv "$dest" "$source"
                log_success "Undone: Moved back to original location"
            else
                log_error "Cannot undo: file not found"
                return 1
            fi
            ;;
        delete)
            log_warning "Cannot undo delete operations (file is gone)"
            return 1
            ;;
        *)
            log_warning "Unknown operation type: $operation"
            return 1
            ;;
    esac

    # Remove last entry from undo history
    sed -i '$ d' "$UNDO_HISTORY_FILE"

    log_success "Operation undone successfully"
    return 0
}

# 2. FAVORITES/BOOKMARKS

# Add directory to favorites
add_favorite() {
    local directory="$1"

    if [[ ! -d "$directory" ]]; then
        log_error "Directory not found: $directory"
        return 1
    fi

    # Resolve to absolute path
    directory=$(cd "$directory" && pwd)

    # Check if already in favorites
    if grep -Fxq "$directory" "$FAVORITES_FILE" 2>/dev/null; then
        log_warning "Already in favorites: $directory"
        return 1
    fi

    echo "$directory" >> "$FAVORITES_FILE"
    log_success "Added to favorites: $directory"
}

# Remove from favorites
remove_favorite() {
    local directory="$1"

    if [[ ! -f "$FAVORITES_FILE" ]]; then
        log_error "No favorites found"
        return 1
    fi

    # Remove the line safely using grep instead of sed with variable
    local temp_file
    temp_file=$(mktemp) || {
        log_error "Failed to create temporary file"
        return 1
    }

    grep -Fxv "$directory" "$FAVORITES_FILE" > "$temp_file" 2>/dev/null
    mv "$temp_file" "$FAVORITES_FILE"
    log_success "Removed from favorites"
}

# List favorites
list_favorites() {
    if [[ ! -f "$FAVORITES_FILE" ]] || [[ ! -s "$FAVORITES_FILE" ]]; then
        echo -e "${COLOR_YELLOW}No favorites saved${COLOR_RESET}"
        return 0
    fi

    echo -e "${COLOR_BRIGHT_CYAN}${SYMBOL_STAR} Favorite Directories:${COLOR_RESET}"
    echo ""

    local num=1
    while IFS= read -r dir; do
        if [[ -d "$dir" ]]; then
            echo -e "  ${COLOR_GREEN}[$num]${COLOR_RESET} $dir"
            ((num++))
        fi
    done < "$FAVORITES_FILE"

    echo ""
}

# Select from favorites
select_favorite() {
    list_favorites

    if [[ ! -f "$FAVORITES_FILE" ]] || [[ ! -s "$FAVORITES_FILE" ]]; then
        return 1
    fi

    echo -n "Select favorite (number) or Enter to cancel: "
    read -r selection

    if [[ -z "$selection" ]]; then
        return 1
    fi

    local selected_dir=$(sed -n "${selection}p" "$FAVORITES_FILE")

    if [[ -n "$selected_dir" && -d "$selected_dir" ]]; then
        echo "$selected_dir"
        return 0
    else
        log_error "Invalid selection"
        return 1
    fi
}

# 3. WATCH FOLDERS

# Add watch folder
add_watch_folder() {
    local directory="$1"
    local operation="$2"  # rename, subtitles, etc.

    directory=$(cd "$directory" && pwd)

    echo "$directory|$operation" >> "$WATCH_FOLDERS_FILE"
    log_success "Added watch folder: $directory → $operation"
}

# Process watch folders
process_watch_folders() {
    if [[ ! -f "$WATCH_FOLDERS_FILE" ]] || [[ ! -s "$WATCH_FOLDERS_FILE" ]]; then
        log_info "No watch folders configured"
        return 0
    fi

    echo -e "${COLOR_BRIGHT_CYAN}Processing Watch Folders...${COLOR_RESET}"
    echo ""

    while IFS='|' read -r directory operation; do
        if [[ ! -d "$directory" ]]; then
            log_warning "Watch folder not found: $directory"
            continue
        fi

        # Check for new files
        local file_count=$(find "$directory" -maxdepth 1 -type f -mmin -60 | wc -l)

        if [[ $file_count -eq 0 ]]; then
            log_verbose "No new files in: $directory"
            continue
        fi

        log_info "Found $file_count new files in: $directory"
        log_info "Applying operation: $operation"

        # Execute operation
        case "$operation" in
            rename)
                rename_files_in_directory "$directory" false
                ;;
            subtitles)
                generate_subtitles_in_directory "$directory" "$WHISPER_MODEL" "$SUBTITLE_FORMAT" "$SUBTITLE_LANGUAGE" false
                ;;
            cleanup)
                workflow_deep_clean "$directory"
                ;;
            *)
                log_warning "Unknown operation: $operation"
                ;;
        esac

    done < "$WATCH_FOLDERS_FILE"

    log_success "Watch folders processed"
}

# 4. EMAIL NOTIFICATIONS

# Send email notification
send_email_notification() {
    local subject="$1"
    local message="$2"

    if [[ "$ENABLE_EMAIL_NOTIFY" != true ]] || [[ -z "$EMAIL_RECIPIENT" ]]; then
        return 0
    fi

    # Try multiple email methods
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$EMAIL_RECIPIENT" 2>/dev/null
    elif command -v sendmail &> /dev/null; then
        echo -e "Subject: $subject\n\n$message" | sendmail "$EMAIL_RECIPIENT" 2>/dev/null
    elif command -v curl &> /dev/null && [[ -n "$SMTP_SERVER" ]]; then
        # Use curl with SMTP (requires configuration)
        curl --url "smtp://$SMTP_SERVER" \
             --mail-from "video-manager@localhost" \
             --mail-rcpt "$EMAIL_RECIPIENT" \
             --upload-file - <<EOF
From: Video Manager <video-manager@localhost>
To: $EMAIL_RECIPIENT
Subject: $subject

$message
EOF
    else
        log_verbose "No email method available"
        return 1
    fi

    log_verbose "Email sent to: $EMAIL_RECIPIENT"
}

# 5. SOUND NOTIFICATIONS

# Play completion sound
play_sound_notification() {
    if [[ "$ENABLE_SOUND_NOTIFY" != true ]]; then
        return 0
    fi

    # Try multiple sound methods
    if command -v paplay &> /dev/null; then
        # PulseAudio (Linux)
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
    elif command -v aplay &> /dev/null; then
        # ALSA (Linux)
        aplay /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null &
    elif command -v afplay &> /dev/null; then
        # macOS
        afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
    elif command -v beep &> /dev/null; then
        # Beep utility
        beep -f 1000 -l 200 2>/dev/null &
    else
        # Terminal bell (universal fallback)
        echo -ne '\a'
    fi
}

# 6. BATCH RENAME PRESETS

# Save rename preset
save_rename_preset() {
    local name="$1"
    local pattern="$2"

    local preset="{\"name\":\"$name\",\"pattern\":\"$pattern\"}"
    echo "$preset" >> "$RENAME_PRESETS_FILE"

    log_success "Saved preset: $name"
}

# List rename presets
list_rename_presets() {
    if [[ ! -f "$RENAME_PRESETS_FILE" ]] || [[ ! -s "$RENAME_PRESETS_FILE" ]]; then
        echo -e "${COLOR_YELLOW}No rename presets saved${COLOR_RESET}"
        return 0
    fi

    echo -e "${COLOR_BRIGHT_CYAN}Rename Presets:${COLOR_RESET}"
    echo ""

    local num=1
    while IFS= read -r preset; do
        local name=$(echo "$preset" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        local pattern=$(echo "$preset" | grep -o '"pattern":"[^"]*"' | cut -d'"' -f4)

        echo -e "  ${COLOR_GREEN}[$num]${COLOR_RESET} $name"
        echo -e "      Pattern: ${COLOR_CYAN}$pattern${COLOR_RESET}"
        ((num++))
    done < "$RENAME_PRESETS_FILE"

    echo ""
}

# 7. DRY-RUN DIFF

# Show before/after diff
show_dry_run_diff() {
    local old_name="$1"
    local new_name="$2"

    if [[ "$DRY_RUN_DIFF" != true ]]; then
        return 0
    fi

    echo -e "${COLOR_RED}- $(basename "$old_name")${COLOR_RESET}"
    echo -e "${COLOR_GREEN}+ $(basename "$new_name")${COLOR_RESET}"
}

################################################################################
# SUBTITLE HELPER FUNCTIONS
################################################################################

# Draw progress bar
draw_progress_bar() {
    local current=$1
    local total=$2
    local width=50

    # Prevent division by zero
    if [[ $total -eq 0 ]]; then
        printf "\r[%${width}s] 0%% (0/0)" | tr ' ' '░'
        return
    fi

    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "\r["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%% (%d/%d)" $percentage $current $total
}

# Estimate time remaining
estimate_time_remaining() {
    local current=$1
    local total=$2
    local elapsed=$3

    if [[ $current -eq 0 ]]; then
        echo "Calculating..."
        return
    fi

    local avg_time_per_item=$((elapsed / current))
    local remaining_items=$((total - current))
    local remaining_seconds=$((avg_time_per_item * remaining_items))

    local hours=$((remaining_seconds / 3600))
    local minutes=$(((remaining_seconds % 3600) / 60))
    local seconds=$((remaining_seconds % 60))

    if [[ $hours -gt 0 ]]; then
        echo "${hours}h ${minutes}m ${seconds}s"
    elif [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Get video duration in seconds
get_video_duration() {
    local video_file="$1"

    if command -v ffprobe &> /dev/null; then
        ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null | cut -d. -f1
    else
        echo "0"
    fi
}

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

# Translate subtitle file
translate_subtitle() {
    local subtitle_file="$1"
    local target_lang="$2"
    local output_file="${subtitle_file%.*}.${target_lang}.${subtitle_file##*.}"

    log_verbose "Translating subtitle to: $target_lang"

    # Check if translation tool is available
    if command -v translate-shell &> /dev/null; then
        # Use translate-shell for translation
        trans -b :${target_lang} -i "$subtitle_file" -o "$output_file" 2>/dev/null

        if [[ -f "$output_file" ]]; then
            log_success "Translated subtitle: $(basename "$output_file")"
            ((STATS[subtitles_translated]++))
            return 0
        fi
    else
        log_warning "translate-shell not installed. Skipping translation."
        log_info "Install with: apt-get install translate-shell"
    fi

    return 1
}

# Extract confidence score from whisper output
extract_confidence_score() {
    local whisper_output="$1"

    # Try to extract confidence from whisper JSON output
    if [[ -n "$whisper_output" ]]; then
        # This is a simplified version - actual implementation depends on whisper output format
        echo "0.8"  # Default confidence if not available
    else
        echo "0.0"
    fi
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
        # Check if it has proper SRT structure (numbers, timecodes, text)
        if ! grep -qE "^[0-9]+$" "$subtitle_file" 2>/dev/null; then
            log_warning "Subtitle file appears to be malformed"
            return 1
        fi
    fi

    log_verbose "Subtitle quality check passed: $(basename "$subtitle_file")"
    return 0
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
# SUBTITLE GENERATION
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

# Validate whisper model name
validate_whisper_model() {
    local model="$1"
    local valid_models=("tiny" "base" "small" "medium" "large" "large-v2" "large-v3")

    for valid in "${valid_models[@]}"; do
        if [[ "$model" == "$valid" ]]; then
            return 0
        fi
    done

    log_error "Invalid whisper model: $model"
    return 1
}

# Validate subtitle format
validate_subtitle_format() {
    local format="$1"
    local valid_formats=("srt" "vtt" "txt" "json")

    for valid in "${valid_formats[@]}"; do
        if [[ "$format" == "$valid" ]]; then
            return 0
        fi
    done

    log_error "Invalid subtitle format: $format"
    return 1
}

# Validate language code
validate_language_code() {
    local lang="$1"

    # Allow "auto" or 2-3 letter language codes
    if [[ "$lang" == "auto" ]] || [[ "$lang" =~ ^[a-z]{2,3}$ ]]; then
        return 0
    fi

    log_error "Invalid language code: $lang"
    return 1
}

# Check if directory should be skipped based on patterns
should_skip_directory() {
    local dir_path="$1"
    local dir_name=$(basename "$dir_path")

    # Check against skip patterns
    for pattern in "${SUBTITLE_SKIP_PATTERNS[@]}"; do
        case "$dir_name" in
            $pattern)
                return 0  # Should skip
                ;;
        esac
    done

    return 1  # Don't skip
}

# Check if file meets size requirements
check_file_size_filter() {
    local file="$1"
    local min_bytes=$((SUBTITLE_MIN_SIZE_MB * 1024 * 1024))
    local max_bytes=$((SUBTITLE_MAX_SIZE_MB * 1024 * 1024))

    local file_size=$(get_file_size "$file")

    # Check minimum size
    if [[ $SUBTITLE_MIN_SIZE_MB -gt 0 && $file_size -lt $min_bytes ]]; then
        return 1  # Too small
    fi

    # Check maximum size
    if [[ $SUBTITLE_MAX_SIZE_MB -gt 0 && $file_size -gt $max_bytes ]]; then
        return 1  # Too large
    fi

    return 0  # Size is OK
}

# Check if file meets modification date requirements
check_file_date_filter() {
    local file="$1"

    # If no date filter, accept all
    if [[ $SUBTITLE_MODIFIED_DAYS -le 0 ]]; then
        return 0
    fi

    # Get file modification time in seconds since epoch
    local file_mtime=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null)
    local current_time=$(date +%s)
    local age_seconds=$((current_time - file_mtime))
    local age_days=$((age_seconds / 86400))

    if [[ $age_days -le $SUBTITLE_MODIFIED_DAYS ]]; then
        return 0  # File is recent enough
    fi

    return 1  # File is too old
}

# Check if subtitle already exists for video
has_existing_subtitle() {
    local video_file="$1"
    local video_dir=$(dirname "$video_file")
    local name="${video_file%.*}"

    # Check for common subtitle extensions
    local subtitle_exts=("srt" "vtt" "txt" "ass" "ssa" "sub")

    for ext in "${subtitle_exts[@]}"; do
        if [[ -f "${name}.${ext}" ]]; then
            return 0  # Subtitle exists
        fi
    done

    return 1  # No subtitle found
}

# Get list of subdirectories for interactive selection
list_subdirectories() {
    local base_dir="$1"
    local max_depth="${2:-$SUBTITLE_MAX_DEPTH}"
    local -a subdirs

    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}Available Subdirectories:${COLOR_RESET}"
    echo ""

    local count=0
    while IFS= read -r dir; do
        # Skip if matches skip patterns
        if should_skip_directory "$dir"; then
            continue
        fi

        ((count++))
        local rel_path="${dir#$base_dir/}"
        local depth=$(echo "$rel_path" | tr -cd '/' | wc -c)
        local indent=$(printf '%*s' $((depth * 2)) '')

        # Count videos in this directory
        local video_count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | grep -icE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$')

        echo -e "  ${COLOR_GREEN}[$count]${COLOR_RESET} ${indent}${rel_path} ${COLOR_CYAN}($video_count videos)${COLOR_RESET}"
        subdirs+=("$dir")
    done < <(find "$base_dir" -mindepth 1 -maxdepth "$max_depth" -type d 2>/dev/null | sort)

    echo ""

    # Return array through global variable (bash limitation workaround)
    SELECTED_SUBDIRS=("${subdirs[@]}")
    return $count
}

# Interactive directory selection
select_directories_interactive() {
    local base_dir="$1"
    local -n output_dirs=$2

    list_subdirectories "$base_dir" "$SUBTITLE_MAX_DEPTH"
    local total_dirs=$?

    if [[ $total_dirs -eq 0 ]]; then
        log_warning "No subdirectories found"
        return 1
    fi

    echo -e "${COLOR_YELLOW}Select directories to process:${COLOR_RESET}"
    echo "  Enter numbers separated by spaces (e.g., 1 3 5)"
    echo "  Enter 'all' to select all directories"
    echo "  Enter 'none' to cancel"
    echo ""
    echo -n "Selection: "
    read -r selection

    if [[ "$selection" == "none" ]]; then
        return 1
    elif [[ "$selection" == "all" ]]; then
        output_dirs=("${SELECTED_SUBDIRS[@]}")
        log_success "Selected all $total_dirs directories"
        return 0
    else
        # Parse space-separated numbers
        local -a indices
        read -ra indices <<< "$selection"

        for idx in "${indices[@]}"; do
            # Validate number
            if [[ ! "$idx" =~ ^[0-9]+$ ]] || [[ $idx -lt 1 ]] || [[ $idx -gt $total_dirs ]]; then
                log_warning "Invalid selection: $idx"
                continue
            fi

            # Add to output (array is 0-indexed, display is 1-indexed)
            output_dirs+=("${SELECTED_SUBDIRS[$((idx-1))]}")
        done

        log_success "Selected ${#output_dirs[@]} directories"
        return 0
    fi
}

# Collect video files recursively with advanced filtering
collect_video_files_recursive() {
    local base_dir="$1"
    local max_depth="${2:-$SUBTITLE_MAX_DEPTH}"
    local max_files="${3:-$SUBTITLE_MAX_FILES}"
    local -n result_array=$4  # nameref to output array

    # Validate depth limit (0-50, 0 means current dir only)
    if [[ $max_depth -lt 0 || $max_depth -gt 50 ]]; then
        log_error "Invalid max depth: $max_depth (must be 0-50)"
        return 1
    fi

    # Validate max files (1-10000)
    if [[ $max_files -lt 1 || $max_files -gt 10000 ]]; then
        log_error "Invalid max files: $max_files (must be 1-10000)"
        return 1
    fi

    log_info "Scanning recursively (depth: $SUBTITLE_MIN_DEPTH-$max_depth, max files: $max_files)"

    # Display active filters
    local filter_count=0
    if [[ ${#SUBTITLE_SKIP_PATTERNS[@]} -gt 0 ]]; then
        log_verbose "Skip patterns: ${SUBTITLE_SKIP_PATTERNS[*]}"
        ((filter_count++))
    fi
    if [[ $SUBTITLE_MIN_SIZE_MB -gt 0 ]]; then
        log_verbose "Min size: ${SUBTITLE_MIN_SIZE_MB}MB"
        ((filter_count++))
    fi
    if [[ $SUBTITLE_MAX_SIZE_MB -gt 0 ]]; then
        log_verbose "Max size: ${SUBTITLE_MAX_SIZE_MB}MB"
        ((filter_count++))
    fi
    if [[ $SUBTITLE_MODIFIED_DAYS -gt 0 ]]; then
        log_verbose "Modified within: ${SUBTITLE_MODIFIED_DAYS} days"
        ((filter_count++))
    fi
    if [[ "$SUBTITLE_SKIP_EXISTING" == true ]]; then
        log_verbose "Skipping videos with existing subtitles"
        ((filter_count++))
    fi

    local file_count=0
    local skipped_pattern=0
    local skipped_size=0
    local skipped_date=0
    local skipped_existing=0
    declare -A dir_stats

    # Build find command with proper depth constraints
    local find_cmd="find \"$base_dir\" -mindepth $SUBTITLE_MIN_DEPTH -maxdepth $max_depth -type f -print0 2>/dev/null"

    # Process files
    while IFS= read -r -d '' file; do
        # Get directory for this file
        local file_dir=$(dirname "$file")

        # Check if directory should be skipped
        if should_skip_directory "$file_dir"; then
            ((skipped_pattern++))
            continue
        fi

        # Verify it's a video file
        if ! is_video_file "$file"; then
            continue
        fi

        # Validate path safety
        if ! validate_path_safety "$file" "$base_dir"; then
            log_warning "Skipping file outside base directory: $file"
            continue
        fi

        # Check size filter
        if ! check_file_size_filter "$file"; then
            ((skipped_size++))
            continue
        fi

        # Check date filter
        if ! check_file_date_filter "$file"; then
            ((skipped_date++))
            continue
        fi

        # Check if subtitle already exists
        if [[ "$SUBTITLE_SKIP_EXISTING" == true ]] && has_existing_subtitle "$file"; then
            ((skipped_existing++))
            continue
        fi

        # Track per-directory stats
        if [[ ! -v dir_stats["$file_dir"] ]]; then
            dir_stats["$file_dir"]=0
        fi
        ((dir_stats["$file_dir"]++))

        # Add to results
        result_array+=("$file")
        ((file_count++))

        # Check if we've hit the max file limit
        if [[ $file_count -ge $max_files ]]; then
            log_warning "Reached maximum file limit ($max_files files)"
            log_warning "Increase SUBTITLE_MAX_FILES to process more files"
            break
        fi

        # Progress indicator every 25 files
        if [[ $((file_count % 25)) -eq 0 ]]; then
            echo -ne "\r${COLOR_CYAN}  Scanning... found $file_count videos (filtered out: $((skipped_pattern + skipped_size + skipped_date + skipped_existing)))${COLOR_RESET}"
        fi

    done < <(eval "$find_cmd")

    echo -ne "\r\033[K"  # Clear progress line

    # Display results
    log_success "Found $file_count video files to process"

    if [[ $filter_count -gt 0 ]]; then
        echo ""
        log_info "Filtering Statistics:"
        [[ $skipped_pattern -gt 0 ]] && log_verbose "  Skipped (pattern): $skipped_pattern"
        [[ $skipped_size -gt 0 ]] && log_verbose "  Skipped (size): $skipped_size"
        [[ $skipped_date -gt 0 ]] && log_verbose "  Skipped (date): $skipped_date"
        [[ $skipped_existing -gt 0 ]] && log_verbose "  Skipped (has subtitle): $skipped_existing"
    fi

    # Show per-directory statistics if enabled
    if [[ "$SUBTITLE_SHOW_DIR_STATS" == true && ${#dir_stats[@]} -gt 0 ]]; then
        echo ""
        log_info "Files per Directory:"
        for dir in "${!dir_stats[@]}"; do
            local rel_path="${dir#$base_dir}"
            [[ -z "$rel_path" ]] && rel_path="(root)"
            log_verbose "  ${rel_path}: ${dir_stats[$dir]} files"
        done
    fi

    return 0
}

# Generate subtitle for a single video file (ENHANCED)
# Validate subtitle generation inputs
# Args: $1=model $2=format $3=language
# Returns: 0 on success, 1 on failure
_validate_subtitle_inputs() {
    local model="$1"
    local format="$2"
    local language="$3"

    if ! validate_whisper_model "$model"; then
        ((STATS[subtitles_failed]++))
        return 1
    fi

    if ! validate_subtitle_format "$format"; then
        ((STATS[subtitles_failed]++))
        return 1
    fi

    if ! validate_language_code "$language"; then
        ((STATS[subtitles_failed]++))
        return 1
    fi

    return 0
}

# Get subtitle file path based on video and format
# Args: $1=video_file $2=format
# Outputs: subtitle file path
_get_subtitle_path() {
    local video_file="$1"
    local format="$2"
    local video_dir=$(dirname "$video_file")
    local filename=$(basename "$video_file")
    local name="${filename%.*}"

    case "$format" in
        srt)  echo "$video_dir/${name}.srt" ;;
        vtt)  echo "$video_dir/${name}.vtt" ;;
        txt)  echo "$video_dir/${name}.txt" ;;
        json) echo "$video_dir/${name}.json" ;;
        *)    echo "$video_dir/${name}.srt" ;;
    esac
}

# Check if subtitle generation should be skipped
# Args: $1=video_file $2=subtitle_file
# Returns: 0 if should skip, 1 if should proceed
_should_skip_subtitle() {
    local video_file="$1"
    local subtitle_file="$2"
    local filename=$(basename "$video_file")

    # Check if subtitle already exists
    if [[ -f "$subtitle_file" ]]; then
        log_warning "Subtitle already exists: $(basename "$subtitle_file")"
        ((STATS[files_skipped]++))
        return 0
    fi

    # Check if already processed (resume support)
    if is_video_processed "$video_file"; then
        log_info "Skipping previously processed: $filename"
        ((STATS[files_skipped]++))
        return 0
    fi

    return 1
}

# Build Whisper command array
# Args: $1=whisper_cmd $2=video_file $3=model $4=format $5=language $6=video_dir
# Returns: command array via nameref
_build_whisper_command() {
    local whisper_cmd="$1"
    local video_file="$2"
    local model="$3"
    local format="$4"
    local language="$5"
    local video_dir="$6"
    local -n cmd_ref=$7

    if [[ "$whisper_cmd" == "whisper" ]]; then
        # OpenAI Whisper Python implementation
        cmd_ref=("whisper" "$video_file" "--model" "$model" "--output_format" "$format" "--output_dir" "$video_dir" "--verbose" "False")

        if [[ "$language" != "auto" ]]; then
            cmd_ref+=("--language" "$language")
        fi

        # GPU acceleration
        if [[ "$SUBTITLE_USE_GPU" == true ]] && detect_gpu; then
            log_verbose "Using GPU acceleration"
            cmd_ref+=("--device" "cuda")
        fi

        # Speaker diarization
        if [[ "$SUBTITLE_SPEAKER_DIARIZATION" == true ]]; then
            cmd_ref+=("--word_timestamps" "True")
            log_verbose "Speaker diarization enabled"
        fi

    elif [[ "$whisper_cmd" == "whisper.cpp" ]]; then
        # whisper.cpp implementation
        cmd_ref=("whisper.cpp" "-m" "$model" "-f" "$video_file" "-of" "$format" "-od" "$video_dir")

        if [[ "$language" != "auto" ]]; then
            cmd_ref+=("-l" "$language")
        fi

        # GPU support for whisper.cpp (if compiled with CUDA)
        if [[ "$SUBTITLE_USE_GPU" == true ]] && detect_gpu; then
            log_verbose "GPU support enabled (if whisper.cpp compiled with CUDA)"
        fi
    fi
}

# Post-process generated subtitle (punctuation, translation, etc)
# Args: $1=subtitle_file $2=language
# Returns: 0 on success
_postprocess_subtitle() {
    local subtitle_file="$1"
    local language="$2"

    # Auto-fix punctuation if enabled
    if [[ "$SUBTITLE_AUTO_PUNCTUATION" == true ]]; then
        log_verbose "Applying punctuation fixes..."
        fix_punctuation "$subtitle_file"
    fi

    # Speaker diarization post-processing
    if [[ "$SUBTITLE_SPEAKER_DIARIZATION" == true ]]; then
        log_verbose "Applying speaker diarization..."
        detect_speakers "$subtitle_file"
    fi

    # Optional: Translate if enabled
    if [[ "$SUBTITLE_AUTO_TRANSLATE" == true && "$SUBTITLE_TRANSLATE_TO" != "$language" ]]; then
        log_verbose "Auto-translation enabled"
        translate_subtitle "$subtitle_file" "$SUBTITLE_TRANSLATE_TO"
    fi

    # Automatic editing if enabled (no prompt)
    if [[ "$SUBTITLE_AUTO_EDIT" == true && "$INTERACTIVE" == true ]]; then
        echo ""
        log_verbose "Auto-editing subtitle..."
        edit_subtitle_interactive "$subtitle_file"
    # Interactive editing with prompt if enabled
    elif [[ "$SUBTITLE_INTERACTIVE_EDIT" == true && "$INTERACTIVE" == true ]]; then
        echo ""
        echo -e "${COLOR_CYAN}Edit this subtitle? (y/n):${COLOR_RESET} "
        read -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            edit_subtitle_interactive "$subtitle_file"
        fi
    fi

    return 0
}

# Handle successful subtitle generation
# Args: $1=subtitle_file $2=elapsed $3=video_file $4=temp_output
# Returns: 0 on success
_handle_subtitle_success() {
    local subtitle_file="$1"
    local elapsed="$2"
    local video_file="$3"
    local temp_output="$4"
    local language="$5"

    echo -ne "\r\033[K"  # Clear line

    if [[ -f "$subtitle_file" ]]; then
        # Verify subtitle quality
        if verify_subtitle_quality "$subtitle_file"; then
            log_success "Generated subtitle: $(basename "$subtitle_file") (${elapsed}s)"
            log_message "SUBTITLE" "Success: $subtitle_file (${elapsed}s)"

            # Save resume point
            save_resume_point "$video_file"

            ((STATS[subtitles_generated]++))

            # Post-process subtitle
            _postprocess_subtitle "$subtitle_file" "$language"

            # Clean up temp file
            rm -f "$temp_output"
            return 0
        else
            log_warning "Subtitle quality check failed, but file was generated"
            ((STATS[low_confidence_count]++))
            ((STATS[subtitles_generated]++))
            save_resume_point "$video_file"
            rm -f "$temp_output"
            return 0
        fi
    else
        log_error "Subtitle generation completed but file not found: $subtitle_file"
        cat "$temp_output" >> "$LOG_FILE" 2>/dev/null
        ((STATS[subtitles_failed]++))
        rm -f "$temp_output"
        return 1
    fi
}

# Handle failed subtitle generation
# Args: $1=video_file $2=temp_output
# Returns: 1 (failure)
_handle_subtitle_failure() {
    local video_file="$1"
    local temp_output="$2"
    local filename=$(basename "$video_file")

    echo -ne "\r\033[K"  # Clear line
    log_error "Failed to generate subtitle for: $filename"
    log_verbose "Error details:"
    tail -5 "$temp_output" 2>/dev/null | while read line; do
        log_verbose "  $line"
    done
    log_message "ERROR" "Whisper failed for: $video_file"
    cat "$temp_output" >> "$LOG_FILE" 2>/dev/null
    ((STATS[subtitles_failed]++))
    rm -f "$temp_output"
    return 1
}

# Generate subtitle for a single video file
# Args: $1=video_file $2=model $3=format $4=language $5=dry_run
# Returns: 0 on success, 1 on failure
generate_subtitle_for_file() {
    local video_file="$1"
    local model="${2:-$WHISPER_MODEL}"
    local format="${3:-$SUBTITLE_FORMAT}"
    local language="${4:-$SUBTITLE_LANGUAGE}"
    local dry_run="${5:-false}"

    # Validate inputs
    _validate_subtitle_inputs "$model" "$format" "$language" || return 1

    # Get subtitle path
    local subtitle_file
    subtitle_file=$(_get_subtitle_path "$video_file" "$format")

    # Check if should skip
    _should_skip_subtitle "$video_file" "$subtitle_file" && return 1

    # Log video info
    local filename=$(basename "$video_file")
    local video_duration=$(get_video_duration "$video_file")
    if [[ $video_duration -gt 0 ]]; then
        local duration_min=$((video_duration / 60))
        log_verbose "Video duration: ${duration_min} minutes"
    fi

    log_verbose "Generating subtitles for: $filename"
    log_verbose "  Model: $model"
    log_verbose "  Format: $format"
    log_verbose "  Language: $language"

    # Handle dry run
    if [[ "$dry_run" == true ]]; then
        echo -e "${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would generate: $subtitle_file"
        log_message "DRYRUN" "Would generate subtitle: $subtitle_file"
        return 0
    fi

    # Check Whisper availability
    local whisper_cmd=$(get_whisper_command)
    if [[ -z "$whisper_cmd" ]]; then
        log_error "Whisper not found. Install with: pip install -U openai-whisper"
        log_error "Or install whisper.cpp from: https://github.com/ggerganov/whisper.cpp"
        ((STATS[subtitles_failed]++))
        return 1
    fi

    # Create temp file for output
    local temp_output
    temp_output=$(mktemp) || {
        log_error "Failed to create temporary file"
        ((STATS[subtitles_failed]++))
        return 1
    }

    # Build command
    local -a cmd_array
    local video_dir=$(dirname "$video_file")
    _build_whisper_command "$whisper_cmd" "$video_file" "$model" "$format" "$language" "$video_dir" cmd_array

    # Execute whisper
    log_verbose "Processing audio... This may take a while."
    echo -ne "${COLOR_CYAN}  ${SYMBOL_INFO} Converting speech to text...${COLOR_RESET}"

    local start_time=$(date +%s)

    # Execute command safely without eval
    if "${cmd_array[@]}" > "$temp_output" 2>&1; then
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        _handle_subtitle_success "$subtitle_file" "$elapsed" "$video_file" "$temp_output" "$language"
    else
        _handle_subtitle_failure "$video_file" "$temp_output"
    fi
}

# Display subtitle generation summary report
# Args: $1=actual_total $2=success_count $3=format $4=directory
_display_subtitle_summary() {
    local actual_total="$1"
    local success_count="$2"
    local format="$3"
    local directory="$4"

    log_success "Successfully generated $success_count out of $actual_total subtitle files"

    # Summary report
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  SUBTITLE GENERATION SUMMARY${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  ${COLOR_WHITE}Total Videos:${COLOR_RESET}        ${COLOR_BRIGHT_CYAN}$actual_total${COLOR_RESET}"
    echo -e "  ${COLOR_WHITE}Successful:${COLOR_RESET}          ${COLOR_BRIGHT_GREEN}${STATS[subtitles_generated]}${COLOR_RESET}"
    echo -e "  ${COLOR_WHITE}Failed:${COLOR_RESET}              ${COLOR_BRIGHT_RED}${STATS[subtitles_failed]}${COLOR_RESET}"
    echo -e "  ${COLOR_WHITE}Skipped:${COLOR_RESET}             ${COLOR_BRIGHT_YELLOW}${STATS[files_skipped]}${COLOR_RESET}"

    if [[ ${STATS[subtitles_translated]} -gt 0 ]]; then
        echo -e "  ${COLOR_WHITE}Translated:${COLOR_RESET}          ${COLOR_BRIGHT_CYAN}${STATS[subtitles_translated]}${COLOR_RESET}"
    fi

    if [[ ${STATS[low_confidence_count]} -gt 0 ]]; then
        echo -e "  ${COLOR_WHITE}Low Quality Warning:${COLOR_RESET} ${COLOR_BRIGHT_YELLOW}${STATS[low_confidence_count]}${COLOR_RESET}"
    fi

    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""

    # Send notification when complete
    if [[ $actual_total -gt 5 ]]; then
        send_notification "Subtitle Generation Complete" "Generated $success_count subtitles"
    fi

    # Offer to preview a subtitle
    if [[ $success_count -gt 0 ]]; then
        echo -e "${COLOR_CYAN}Would you like to preview a generated subtitle? (y/n):${COLOR_RESET} "
        read -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Find first generated subtitle
            local first_subtitle=$(find "$directory" -maxdepth 1 -name "*.${format}" | head -1)
            if [[ -n "$first_subtitle" ]]; then
                preview_subtitle "$first_subtitle" 20
            fi
        fi
    fi

    # Cleanup resume file on successful completion
    if [[ ${STATS[subtitles_failed]} -eq 0 ]]; then
        clear_resume_file
        log_verbose "Cleared resume file - all videos processed successfully"
    fi
}

# Check and setup subtitle generation prerequisites
# Args: $1=directory $2=model $3=format $4=language
# Returns: 0 on success, 1 on failure
_setup_subtitle_generation() {
    local directory="$1"
    local model="$2"
    local format="$3"
    local language="$4"

    # Check whisper installation
    if ! check_whisper_installation; then
        log_error "Whisper is not installed!"
        echo ""
        echo -e "${COLOR_YELLOW}To install Whisper:${COLOR_RESET}"
        echo "  Option 1 - OpenAI Whisper (Python):"
        echo "    pip install -U openai-whisper"
        echo ""
        echo "  Option 2 - whisper.cpp (C++ implementation, faster):"
        echo "    git clone https://github.com/ggerganov/whisper.cpp"
        echo "    cd whisper.cpp && make"
        echo ""
        return 1
    fi

    log_info "Scanning directory: $directory"
    log_info "Using model: $model"
    log_info "Output format: $format"
    log_info "Language: $language"

    # Display recursive mode status
    if [[ "$SUBTITLE_RECURSIVE" == true ]]; then
        log_info "Recursive mode: ENABLED (depth: $SUBTITLE_MAX_DEPTH, max files: $SUBTITLE_MAX_FILES)"
    else
        log_info "Recursive mode: DISABLED (current directory only)"
    fi

    return 0
}

# Check resume file and prompt user
# Returns: 0 if continuing, 1 if user chose fresh start
_check_resume_file() {
    if [[ -f "$SUBTITLE_RESUME_FILE" ]]; then
        local resume_count=$(wc -l < "$SUBTITLE_RESUME_FILE")
        if [[ $resume_count -gt 0 ]]; then
            echo ""
            echo -e "${COLOR_YELLOW}${SYMBOL_WARN} Found resume file with $resume_count processed videos${COLOR_RESET}"
            read -p "Resume from previous session? (y/n): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                clear_resume_file
                log_info "Starting fresh - cleared resume file"
                return 1
            else
                log_info "Resuming previous session"
            fi
        fi
    fi
    return 0
}

# Setup GPU and parallel processing
# Returns: "true" if parallel should be used, "false" otherwise
_setup_processing_mode() {
    echo ""

    # GPU detection
    if [[ "$SUBTITLE_USE_GPU" == true ]]; then
        if detect_gpu; then
            log_success "GPU acceleration enabled - expect 5-10x speedup"
        else
            log_warning "GPU not detected, using CPU"
            SUBTITLE_USE_GPU=false
        fi
    fi

    # Check for parallel processing support
    local use_parallel=false
    if [[ $SUBTITLE_PARALLEL_JOBS -gt 1 ]] && check_parallel_support; then
        use_parallel=true
        log_info "Parallel processing enabled: $SUBTITLE_PARALLEL_JOBS workers"
    fi

    echo "$use_parallel"
}

# Collect video files based on mode (recursive or not)
# Args: $1=directory $2=nameref to video_files array
# Returns: 0 on success
_collect_video_files() {
    local directory="$1"
    local -n files_ref=$2

    # Collect files based on recursive mode setting
    if [[ "$SUBTITLE_RECURSIVE" == true ]]; then
        # Use recursive collection with safety limits
        log_info "Collecting video files recursively..."
        if ! collect_video_files_recursive "$directory" "$SUBTITLE_MAX_DEPTH" "$SUBTITLE_MAX_FILES" files_ref; then
            log_error "Failed to collect video files recursively"
            return 1
        fi

        # Sort by size if batch optimization is enabled
        if [[ "$SUBTITLE_OPTIMIZE_BATCH" == true && ${#files_ref[@]} -gt 1 ]]; then
            log_info "Sorting ${#files_ref[@]} videos by size for optimal processing"
            # Create temporary array for sorted files
            local -a sorted_files
            while IFS= read -r file; do
                sorted_files+=("$file")
            done < <(for f in "${files_ref[@]}"; do
                echo "$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null) $f"
            done | sort -n | cut -d' ' -f2-)
            files_ref=("${sorted_files[@]}")
        fi
    else
        # Non-recursive mode: current directory only
        # Batch optimization: sort by size if enabled
        if [[ "$SUBTITLE_OPTIMIZE_BATCH" == true ]]; then
            log_info "Optimizing batch: sorting videos by size (smallest first)"
            while IFS= read -r file; do
                [[ "$(basename "$file")" == .* ]] && continue
                if is_video_file "$file"; then
                    files_ref+=("$file")
                fi
            done < <(sort_videos_by_size "$directory")
        else
            while IFS= read -r -d '' file; do
                [[ "$(basename "$file")" == .* ]] && continue
                if is_video_file "$file"; then
                    files_ref+=("$file")
                fi
            done < <(find "$directory" -maxdepth 1 -type f -print0)
        fi
    fi

    return 0
}

# Generate subtitles for all videos in directory (REFACTORED)
# Args: $1=directory $2=model $3=format $4=language $5=dry_run
# Returns: 0 on success, 1 on failure
generate_subtitles_in_directory() {
    local directory="$1"
    local model="${2:-$WHISPER_MODEL}"
    local format="${3:-$SUBTITLE_FORMAT}"
    local language="${4:-$SUBTITLE_LANGUAGE}"
    local dry_run="${5:-false}"

    # Setup and validation
    _setup_subtitle_generation "$directory" "$model" "$format" "$language" || return 1

    # Count total video files based on mode
    local total_files
    if [[ "$SUBTITLE_RECURSIVE" == true ]]; then
        total_files=$(find "$directory" -maxdepth "$SUBTITLE_MAX_DEPTH" -type f 2>/dev/null | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$' | wc -l)
    else
        total_files=$(find "$directory" -maxdepth 1 -type f 2>/dev/null | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$' | wc -l)
    fi

    log_info "Found $total_files video files to process"

    if [[ $total_files -eq 0 ]]; then
        log_warning "No video files found in directory"
        return 0
    fi

    # Check for resume
    _check_resume_file

    # Setup GPU and parallel processing
    local use_parallel=$(_setup_processing_mode)

    # Initialize counters
    local file_count=0
    local success_count=0
    local operation_start=$(date +%s)

    # Collect video files
    local -a video_files
    _collect_video_files "$directory" video_files || return 1

    local actual_total=${#video_files[@]}

    # If parallel processing is available and enabled, use it
    if [[ "$use_parallel" == true && $actual_total -gt 3 ]]; then
        log_info "Using parallel processing for better performance"
        process_videos_parallel "$directory" "$model" "$format" "$language"
        return $?
    fi

    # Process files sequentially
    for file in "${video_files[@]}"; do
        ((file_count++))
        ((STATS[files_processed]++))

        local filename=$(basename "$file")
        local current_time=$(date +%s)
        local elapsed=$((current_time - operation_start))

        # Progress bar
        echo ""
        draw_progress_bar $file_count $actual_total
        echo ""

        # Time estimation
        if [[ $file_count -gt 1 ]]; then
            local eta=$(estimate_time_remaining $success_count $actual_total $elapsed)
            echo -e "${COLOR_CYAN}  Estimated time remaining: $eta${COLOR_RESET}"
        fi

        echo ""
        echo -e "${COLOR_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        echo -e "${COLOR_CYAN}Processing: [$file_count/$actual_total]${COLOR_RESET} $filename"
        echo -e "${COLOR_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"

        if generate_subtitle_for_file "$file" "$model" "$format" "$language" "$dry_run"; then
            ((success_count++))
        fi
    done

    echo ""
    echo ""

    # Final progress bar
    draw_progress_bar $actual_total $actual_total
    echo ""
    echo ""

    # Display results
    if [[ "$dry_run" == true ]]; then
        log_info "Dry run complete - no subtitles were actually generated"
    else
        _display_subtitle_summary "$actual_total" "$success_count" "$format" "$directory"
    fi
}

################################################################################
# MULTI-DRIVE CATALOG SYSTEM
################################################################################

# Get unique drive identifier (UUID, Volume ID, or Serial Number)
# Args: $1=mount_point
# Returns: unique drive ID
get_drive_id() {
    local mount_point="$1"
    local drive_id=""

    # Method 1: Try to get filesystem UUID (Linux)
    if [[ -d "$mount_point" ]]; then
        # For WSL drives, use volume label + serial
        if [[ "$mount_point" =~ ^/mnt/[a-z]$ ]]; then
            # WSL drive (C:, D:, etc)
            local drive_letter="${mount_point##*/}"
            # Get Windows volume serial number via PowerShell
            drive_id=$(powershell.exe -NoProfile -Command "(Get-Volume -DriveLetter ${drive_letter}).UniqueId" 2>/dev/null | tr -d '\r\n' | tr -d '{}'  )
            if [[ -z "$drive_id" ]]; then
                # Fallback: use volume label + drive letter
                local vol_label=$(powershell.exe -NoProfile -Command "(Get-Volume -DriveLetter ${drive_letter}).FileSystemLabel" 2>/dev/null | tr -d '\r\n')
                drive_id="${drive_letter}_${vol_label}"
            fi
        else
            # Try Linux UUID method
            local dev=$(df "$mount_point" 2>/dev/null | tail -1 | awk '{print $1}')
            if [[ -n "$dev" ]]; then
                drive_id=$(blkid -s UUID -o value "$dev" 2>/dev/null)
            fi

            # Fallback: use mount point hash
            if [[ -z "$drive_id" ]]; then
                drive_id=$(echo -n "$mount_point" | md5sum | awk '{print $1}')
            fi
        fi
    fi

    echo "$drive_id"
}

# Get drive label/name
# Args: $1=mount_point
# Returns: friendly drive name
get_drive_label() {
    local mount_point="$1"
    local label=""

    if [[ "$mount_point" =~ ^/mnt/[a-z]$ ]]; then
        local drive_letter="${mount_point##*/}"
        label=$(powershell.exe -NoProfile -Command "(Get-Volume -DriveLetter ${drive_letter}).FileSystemLabel" 2>/dev/null | tr -d '\r\n')
        [[ -z "$label" ]] && label="Drive ${drive_letter^^}"
    else
        label=$(basename "$mount_point")
    fi

    echo "$label"
}

# Detect drive type (USB, NAS, Local, Network)
# Args: $1=mount_point
# Returns: drive type
detect_drive_type() {
    local mount_point="$1"
    local drive_type="Unknown"

    # Check mount info
    local mount_info=$(mount | grep "$mount_point")

    if [[ "$mount_point" =~ ^/mnt/[a-z]$ ]]; then
        # WSL drive
        local drive_letter="${mount_point##*/}"
        local bus_type=$(powershell.exe -NoProfile -Command "(Get-PhysicalDisk | Where-Object {(\$_.DeviceID -eq (Get-Partition -DriveLetter ${drive_letter}).DiskNumber)}).BusType" 2>/dev/null | tr -d '\r\n')

        case "$bus_type" in
            USB) drive_type="USB" ;;
            SATA|SAS|ATA) drive_type="Local" ;;
            NVMe|RAID) drive_type="Local" ;;
            iSCSI|FC) drive_type="NAS" ;;
            *) drive_type="Local" ;;
        esac
    elif echo "$mount_info" | grep -q "cifs\|smb"; then
        drive_type="Network"
    elif echo "$mount_info" | grep -q "nfs"; then
        drive_type="NAS"
    elif echo "$mount_info" | grep -q "fuse\|9p"; then
        drive_type="Network"
    else
        drive_type="Local"
    fi

    echo "$drive_type"
}

# Initialize catalog database
init_catalog_db() {
    if [[ ! -f "$CATALOG_DB" ]]; then
        echo '{"videos":[],"last_updated":"'$(date -Iseconds)'","version":"1.0"}' > "$CATALOG_DB"
        log_verbose "Created catalog database: $CATALOG_DB"
    fi

    if [[ ! -f "$CATALOG_DRIVES_DB" ]]; then
        echo '{"drives":[],"last_updated":"'$(date -Iseconds)'"}' > "$CATALOG_DRIVES_DB"
        log_verbose "Created drives database: $CATALOG_DRIVES_DB"
    fi
}

# Register a drive in the drives database
# Args: $1=mount_point
# Returns: drive_id
register_drive() {
    local mount_point="$1"

    init_catalog_db

    local drive_id=$(get_drive_id "$mount_point")
    local drive_label=$(get_drive_label "$mount_point")
    local drive_type=$(detect_drive_type "$mount_point")
    local timestamp=$(date -Iseconds)

    log_info "Registering drive: $drive_label ($drive_id)"
    log_verbose "  Mount point: $mount_point"
    log_verbose "  Type: $drive_type"

    # Read existing drives
    local drives_json=$(cat "$CATALOG_DRIVES_DB")

    # Check if drive already exists
    local existing=$(echo "$drives_json" | jq -r ".drives[] | select(.drive_id == \"$drive_id\") | .drive_id")

    if [[ -n "$existing" ]]; then
        # Update existing drive
        drives_json=$(echo "$drives_json" | jq \
            --arg id "$drive_id" \
            --arg mp "$mount_point" \
            --arg ts "$timestamp" \
            '(.drives[] | select(.drive_id == $id)) |= {
                drive_id: $id,
                drive_label: .drive_label,
                drive_type: .drive_type,
                last_mount_point: $mp,
                last_seen: $ts,
                status: "online",
                total_videos: .total_videos
            } | .last_updated = $ts')
    else
        # Add new drive
        drives_json=$(echo "$drives_json" | jq \
            --arg id "$drive_id" \
            --arg label "$drive_label" \
            --arg type "$drive_type" \
            --arg mp "$mount_point" \
            --arg ts "$timestamp" \
            '.drives += [{
                drive_id: $id,
                drive_label: $label,
                drive_type: $type,
                last_mount_point: $mp,
                last_seen: $ts,
                status: "online",
                total_videos: 0
            }] | .last_updated = $ts')
    fi

    echo "$drives_json" > "$CATALOG_DRIVES_DB"
    log_success "Drive registered: $drive_label"

    echo "$drive_id"
}

# Scan a drive and catalog all videos
# Args: $1=mount_point $2=recursive(true/false)
catalog_drive() {
    local mount_point="$1"
    local recursive="${2:-false}"

    if [[ ! -d "$mount_point" ]]; then
        log_error "Mount point does not exist: $mount_point"
        return 1
    fi

    log_info "Starting catalog scan: $mount_point"

    # Register drive
    local drive_id=$(register_drive "$mount_point")

    # Initialize counters
    local file_count=0
    local new_count=0
    local updated_count=0
    local video_count=0
    local image_count=0
    local audio_count=0
    local start_time=$(date +%s)

    # Build file extension pattern based on enabled media types
    local -a extensions
    [[ "$CATALOG_VIDEOS" == true ]] && extensions+=("${DEFAULT_VIDEO_EXTENSIONS[@]}")
    [[ "$CATALOG_IMAGES" == true ]] && extensions+=("${DEFAULT_IMAGE_EXTENSIONS[@]}")
    [[ "$CATALOG_AUDIO" == true ]] && extensions+=("${DEFAULT_AUDIO_EXTENSIONS[@]}")

    if [[ ${#extensions[@]} -eq 0 ]]; then
        log_error "No media types enabled for cataloging"
        return 1
    fi

    # Create regex pattern from extensions
    local ext_pattern=$(IFS='|'; echo "${extensions[*]}")

    # Find all media files
    local -a media_files
    log_info "Scanning for media files..."

    if [[ "$recursive" == true ]]; then
        while IFS= read -r -d '' file; do
            media_files+=("$file")
        done < <(find "$mount_point" -type f -print0 2>/dev/null | grep -ziE "\.($ext_pattern)$")
    else
        while IFS= read -r -d '' file; do
            media_files+=("$file")
        done < <(find "$mount_point" -maxdepth 1 -type f -print0 2>/dev/null | grep -ziE "\.($ext_pattern)$")
    fi

    local total=${#media_files[@]}
    log_info "Found $total media files to catalog"

    if [[ $total -eq 0 ]]; then
        log_warning "No media files found on this drive"
        return 0
    fi

    # Read existing catalog
    local catalog_json=$(cat "$CATALOG_DB")

    # Process each media file
    for file in "${media_files[@]}"; do
        ((file_count++))

        # Detect media type
        local media_type=$(get_media_type "$file")

        # Count by type
        case "$media_type" in
            video) ((video_count++)) ;;
            image) ((image_count++)) ;;
            audio) ((audio_count++)) ;;
        esac

        # Calculate relative path from mount point
        local rel_path="${file#$mount_point/}"
        local filename=$(basename "$file")
        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        local timestamp=$(date -Iseconds)

        # Progress indicator
        if (( file_count % 10 == 0 )); then
            echo -ne "\r${COLOR_CYAN}  Cataloging: [$file_count/$total] (V:$video_count I:$image_count A:$audio_count)${COLOR_RESET}"
        fi

        # Extract studio from bracket notation (for videos)
        local studio=""
        if [[ "$filename" =~ ^\[([^\]]+)\] ]]; then
            studio="${BASH_REMATCH[1]}"
        fi

        # Get file hash if enabled
        local file_hash=""
        if [[ "$CATALOG_INCLUDE_HASH" == true ]]; then
            file_hash=$(calculate_hash "$file")
        fi

        # Get metadata based on media type
        local duration=""
        local resolution=""
        local dimensions=""
        local bitrate=""
        local artist=""
        local title=""
        local camera=""
        local date_taken=""
        local gps_lat=""
        local gps_lon=""
        local iso=""
        local focal_length=""
        local aperture=""
        local shutter_speed=""

        if [[ "$CATALOG_INCLUDE_METADATA" == true ]]; then
            case "$media_type" in
                video)
                    duration=$(get_video_duration "$file")
                    if command -v ffprobe >/dev/null 2>&1; then
                        resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$file" 2>/dev/null)
                    fi
                    ;;
                image)
                    dimensions=$(get_image_dimensions "$file")
                    # Get EXIF data
                    local exif_meta=$(get_image_exif "$file")
                    IFS='|' read -r camera date_taken gps_lat gps_lon iso focal_length aperture shutter_speed <<< "$exif_meta"
                    ;;
                audio)
                    local audio_meta=$(get_audio_metadata "$file")
                    IFS='|' read -r duration bitrate artist title <<< "$audio_meta"
                    ;;
            esac
        fi

        # Check if file already in catalog
        local existing=$(echo "$catalog_json" | jq -r ".videos[] | select(.drive_id == \"$drive_id\" and .relative_path == \"$rel_path\") | .video_id")

        if [[ -n "$existing" ]]; then
            # Update existing entry
            catalog_json=$(echo "$catalog_json" | jq \
                --arg vid "$existing" \
                --arg size "$file_size" \
                --arg hash "$file_hash" \
                --arg dur "$duration" \
                --arg res "$resolution" \
                --arg dims "$dimensions" \
                --arg br "$bitrate" \
                --arg art "$artist" \
                --arg ttl "$title" \
                --arg cam "$camera" \
                --arg dtk "$date_taken" \
                --arg glat "$gps_lat" \
                --arg glon "$gps_lon" \
                --arg iso "$iso" \
                --arg fl "$focal_length" \
                --arg ap "$aperture" \
                --arg ss "$shutter_speed" \
                --arg type "$media_type" \
                --arg ts "$timestamp" \
                '(.videos[] | select(.video_id == ($vid|tonumber))) |= {
                    video_id: .video_id,
                    drive_id: .drive_id,
                    relative_path: .relative_path,
                    filename: .filename,
                    media_type: $type,
                    file_size: ($size|tonumber),
                    hash: $hash,
                    duration: (if $dur != "" then ($dur|tonumber) else null end),
                    resolution: $res,
                    dimensions: $dims,
                    bitrate: (if $br != "" then ($br|tonumber) else null end),
                    artist: $art,
                    title: $ttl,
                    camera: $cam,
                    date_taken: $dtk,
                    gps_latitude: $glat,
                    gps_longitude: $glon,
                    iso: $iso,
                    focal_length: $fl,
                    aperture: $ap,
                    shutter_speed: $ss,
                    studio: .studio,
                    last_scanned: $ts,
                    status: "exists"
                }')
            ((updated_count++))
        else
            # Add new entry
            local media_id=$(echo "$catalog_json" | jq '.videos | length')
            catalog_json=$(echo "$catalog_json" | jq \
                --arg mid "$media_id" \
                --arg did "$drive_id" \
                --arg rpath "$rel_path" \
                --arg fname "$filename" \
                --arg type "$media_type" \
                --arg size "$file_size" \
                --arg hash "$file_hash" \
                --arg dur "$duration" \
                --arg res "$resolution" \
                --arg dims "$dimensions" \
                --arg br "$bitrate" \
                --arg art "$artist" \
                --arg ttl "$title" \
                --arg cam "$camera" \
                --arg dtk "$date_taken" \
                --arg glat "$gps_lat" \
                --arg glon "$gps_lon" \
                --arg iso "$iso" \
                --arg fl "$focal_length" \
                --arg ap "$aperture" \
                --arg ss "$shutter_speed" \
                --arg studio "$studio" \
                --arg ts "$timestamp" \
                '.videos += [{
                    video_id: ($mid|tonumber),
                    drive_id: $did,
                    relative_path: $rpath,
                    filename: $fname,
                    media_type: $type,
                    file_size: ($size|tonumber),
                    hash: $hash,
                    duration: (if $dur != "" then ($dur|tonumber) else null end),
                    resolution: $res,
                    dimensions: $dims,
                    bitrate: (if $br != "" then ($br|tonumber) else null end),
                    artist: $art,
                    title: $ttl,
                    camera: $cam,
                    date_taken: $dtk,
                    gps_latitude: $glat,
                    gps_longitude: $glon,
                    iso: $iso,
                    focal_length: $fl,
                    aperture: $ap,
                    shutter_speed: $ss,
                    studio: $studio,
                    last_scanned: $ts,
                    status: "exists"
                }]')
            ((new_count++))
        fi
    done

    echo -ne "\r\033[K"  # Clear line

    # Update catalog
    catalog_json=$(echo "$catalog_json" | jq --arg ts "$(date -Iseconds)" '.last_updated = $ts')
    echo "$catalog_json" > "$CATALOG_DB"

    # Update drive video count
    local drives_json=$(cat "$CATALOG_DRIVES_DB")
    drives_json=$(echo "$drives_json" | jq \
        --arg id "$drive_id" \
        --arg count "$total" \
        '(.drives[] | select(.drive_id == $id)).total_videos = ($count|tonumber)')
    echo "$drives_json" > "$CATALOG_DRIVES_DB"

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    echo ""
    log_success "Catalog scan complete!"
    log_info "  Total media files: $total"
    log_info "    Videos: $video_count"
    log_info "    Images: $image_count"
    log_info "    Audio: $audio_count"
    log_info "  New entries: $new_count"
    log_info "  Updated entries: $updated_count"
    log_info "  Duration: ${elapsed}s"
}

# List all cataloged drives
list_cataloged_drives() {
    init_catalog_db

    local drives_json=$(cat "$CATALOG_DRIVES_DB")
    local drive_count=$(echo "$drives_json" | jq '.drives | length')

    if [[ $drive_count -eq 0 ]]; then
        log_warning "No drives cataloged yet"
        return 0
    fi

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  CATALOGED DRIVES${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"

    echo "$drives_json" | jq -r '.drives[] | "\(.drive_label)|\(.drive_type)|\(.status)|\(.total_videos)|\(.last_seen)"' | \
    while IFS='|' read -r label type status videos last_seen; do
        local status_color="$COLOR_GREEN"
        [[ "$status" == "offline" ]] && status_color="$COLOR_RED"

        echo -e "  ${COLOR_WHITE}Drive:${COLOR_RESET}   ${COLOR_BRIGHT_CYAN}$label${COLOR_RESET}"
        echo -e "  ${COLOR_WHITE}Type:${COLOR_RESET}    $type"
        echo -e "  ${COLOR_WHITE}Status:${COLOR_RESET}  ${status_color}${status}${COLOR_RESET}"
        echo -e "  ${COLOR_WHITE}Videos:${COLOR_RESET}  $videos"
        echo -e "  ${COLOR_WHITE}Last Seen:${COLOR_RESET} $last_seen"
        echo ""
    done

    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
}

# Search catalog for media files
# Args: $1=search_term $2=media_type_filter (optional: video, image, audio, or all)
search_catalog() {
    local search_term="$1"
    local media_filter="${2:-all}"

    init_catalog_db

    local catalog_json=$(cat "$CATALOG_DB")

    # Build jq filter based on media type
    local type_filter=""
    if [[ "$media_filter" != "all" ]]; then
        type_filter="| select(.media_type == \"$media_filter\")"
    fi

    local results=$(echo "$catalog_json" | jq -r --arg term "$search_term" \
        ".videos[] | select(.filename | test(\$term; \"i\")) $type_filter |
        \"\(.drive_id)|\(.filename)|\(.file_size)|\(.media_type)|\(.studio)|\(.artist)|\(.dimensions)|\(.resolution)|\(.status)\"")

    if [[ -z "$results" ]]; then
        log_warning "No media files found matching: $search_term"
        return 0
    fi

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}Search Results for: \"$search_term\"${COLOR_RESET}"
    [[ "$media_filter" != "all" ]] && echo -e "${COLOR_WHITE}  Filter: ${COLOR_YELLOW}${media_filter}s${COLOR_RESET}"
    echo ""

    local count=0
    echo "$results" | while IFS='|' read -r drive_id filename size media_type studio artist dimensions resolution status; do
        ((count++))

        # Get drive info
        local drive_label=$(cat "$CATALOG_DRIVES_DB" | jq -r --arg id "$drive_id" \
            '.drives[] | select(.drive_id == $id) | .drive_label')

        local status_icon="$SYMBOL_CHECK"
        [[ "$status" != "exists" ]] && status_icon="$SYMBOL_WARN"

        # Media type icon
        local type_icon="📄"
        case "$media_type" in
            video) type_icon="🎬" ;;
            image) type_icon="🖼️" ;;
            audio) type_icon="🎵" ;;
        esac

        echo -e "${COLOR_CYAN}[$count]${COLOR_RESET} $status_icon $type_icon $filename"
        echo -e "    Type: ${COLOR_WHITE}$media_type${COLOR_RESET}"
        echo -e "    Drive: ${COLOR_BRIGHT_CYAN}$drive_label${COLOR_RESET}"

        # Type-specific metadata
        case "$media_type" in
            video)
                [[ -n "$studio" ]] && echo -e "    Studio: ${COLOR_YELLOW}$studio${COLOR_RESET}"
                [[ -n "$resolution" ]] && echo -e "    Resolution: ${COLOR_WHITE}$resolution${COLOR_RESET}"
                ;;
            image)
                [[ -n "$dimensions" ]] && echo -e "    Dimensions: ${COLOR_WHITE}$dimensions${COLOR_RESET}"
                ;;
            audio)
                [[ -n "$artist" ]] && echo -e "    Artist: ${COLOR_YELLOW}$artist${COLOR_RESET}"
                ;;
        esac

        echo -e "    Size: $(format_bytes $size)"
        echo ""
    done
}

# Batch subtitle generation for multiple directories
batch_generate_subtitles() {
    echo -e "${COLOR_BRIGHT_CYAN}${SYMBOL_FOLDER} Batch Subtitle Generation${COLOR_RESET}"
    echo ""
    echo "Enter directory paths (one per line, empty line to finish):"
    echo ""

    local folders=()
    local line_num=1

    while true; do
        echo -n "[$line_num] Directory: "
        read -r folder

        if [[ -z "$folder" ]]; then
            break
        fi

        folder=$(validate_directory "$folder")
        if [[ $? -eq 0 ]]; then
            folders+=("$folder")
            log_success "Added: $folder"
            ((line_num++))
        fi
    done

    if [[ ${#folders[@]} -eq 0 ]]; then
        log_warning "No valid directories provided"
        return 1
    fi

    echo ""
    echo -e "${COLOR_BOLD}Processing ${#folders[@]} directories:${COLOR_RESET}"
    echo ""

    local folder_num=1
    for folder in "${folders[@]}"; do
        echo -e "${COLOR_BRIGHT_MAGENTA}[$folder_num/${#folders[@]}] Processing: $folder${COLOR_RESET}"
        echo ""

        generate_subtitles_in_directory "$folder" "$WHISPER_MODEL" "$SUBTITLE_FORMAT" "$SUBTITLE_LANGUAGE" false

        echo ""
        ((folder_num++))
    done

    log_success "Batch subtitle generation complete!"
}

################################################################################
# BATCH PROCESSING
################################################################################

batch_process_folders() {
    echo -e "${COLOR_BRIGHT_CYAN}${SYMBOL_FOLDER} Batch Processing Mode${COLOR_RESET}"
    echo ""
    echo "Enter directory paths (one per line, empty line to finish):"
    echo "You can use Windows paths (C:\\Users\\...) or Unix paths (/mnt/c/...)"
    echo ""
    
    local folders=()
    local line_num=1
    
    while true; do
        echo -n "[$line_num] Directory: "
        read -r folder
        
        if [[ -z "$folder" ]]; then
            break
        fi
        
        folder=$(validate_directory "$folder")
        if [[ $? -eq 0 ]]; then
            folders+=("$folder")
            log_success "Added: $folder"
            ((line_num++))
        fi
    done
    
    if [[ ${#folders[@]} -eq 0 ]]; then
        log_warning "No valid directories provided"
        return 1
    fi
    
    echo ""
    echo -e "${COLOR_BOLD}Processing ${#folders[@]} directories:${COLOR_RESET}"
    echo ""
    
    local folder_num=1
    for folder in "${folders[@]}"; do
        echo -e "${COLOR_BRIGHT_MAGENTA}[$folder_num/${#folders[@]}] Processing: $folder${COLOR_RESET}"
        echo ""
        
        rename_files_in_directory "$folder" false
        
        echo ""
        ((folder_num++))
    done
    
    log_success "Batch processing complete!"
}

################################################################################
# AUTOMATED WORKFLOWS
################################################################################

workflow_new_collection() {
    local directory="$1"
    
    start_operation "New Collection Setup Workflow"
    
    log_info "This workflow will:"
    echo "  1. Flatten directory structure"
    echo "  2. Apply standardized naming"
    echo "  3. Detect duplicates"
    echo ""
    
    if [[ "$DRY_RUN" == false ]]; then
        read -p "Continue? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Workflow cancelled"
            return 1
        fi
    fi
    
    # Step 1: Flatten
    echo ""
    log_info "Step 1/3: Flattening directory structure..."
    flatten_directory "$directory" "$DRY_RUN"
    
    # Step 2: Rename
    echo ""
    log_info "Step 2/3: Applying standardized naming..."
    rename_files_in_directory "$directory" "$DRY_RUN"
    
    # Step 3: Find duplicates
    echo ""
    log_info "Step 3/3: Detecting duplicates..."
    find_duplicates "$directory" "report"
    
    end_operation
}

workflow_deep_clean() {
    local directory="$1"
    
    start_operation "Deep Clean Workflow"
    
    log_info "This workflow will:"
    echo "  1. Remove dash patterns"
    echo "  2. Fix bracket spacing"
    echo "  3. Apply bracket notation"
    echo ""
    
    if [[ "$DRY_RUN" == false ]]; then
        read -p "Continue? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Workflow cancelled"
            return 1
        fi
    fi
    
    rename_files_in_directory "$directory" "$DRY_RUN"
    
    end_operation
}

# Create undo log for organize operation
# Args: $1=operation_id
# Returns: path to undo log file
_create_undo_log() {
    local operation_id="$1"

    # Create undo log directory if it doesn't exist
    mkdir -p "$UNDO_LOG_DIR"

    local undo_file="$UNDO_LOG_DIR/organize-${operation_id}.log"

    # Create log file with header
    cat > "$undo_file" <<EOF
# Organize Operation Undo Log
# Operation ID: $operation_id
# Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
# Format: source_path|destination_path
EOF

    echo "$undo_file"
}

# Log a move operation for undo
# Args: $1=undo_log_file $2=source $3=destination
_log_move_operation() {
    local undo_log="$1"
    local source="$2"
    local dest="$3"

    echo "$source|$dest" >> "$undo_log"
}

# Undo the last organize operation
# Args: $1=operation_id (optional, defaults to most recent)
# Returns: 0 on success
undo_organize_operation() {
    local operation_id="$1"

    begin_operation "Undo Organize Operation"

    # Find undo log
    local undo_log
    if [[ -n "$operation_id" ]]; then
        undo_log="$UNDO_LOG_DIR/organize-${operation_id}.log"
    else
        # Find most recent undo log using stat instead of ls
        local latest_file=""
        local latest_time=0
        shopt -s nullglob
        for file in "$UNDO_LOG_DIR"/organize-*.log; do
            if [[ -f "$file" ]]; then
                local file_time=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
                if [[ "$file_time" -gt "$latest_time" ]]; then
                    latest_time="$file_time"
                    latest_file="$file"
                fi
            fi
        done
        shopt -u nullglob
        undo_log="$latest_file"
    fi

    if [[ ! -f "$undo_log" ]]; then
        log_error "No undo log found"
        return 1
    fi

    log_info "Using undo log: $(basename "$undo_log")"

    # Show log header
    echo ""
    grep '^#' "$undo_log"
    echo ""

    # Count operations
    local total_ops=$(grep -v '^#' "$undo_log" | wc -l)
    log_info "Found $total_ops operation(s) to undo"

    if [[ $total_ops -eq 0 ]]; then
        log_warning "No operations to undo"
        return 1
    fi

    # Confirm
    if [[ "$INTERACTIVE" == true ]]; then
        echo -n "Proceed with undo? (y/n): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_warning "Undo cancelled"
            return 1
        fi
    fi

    echo ""
    local success_count=0
    local error_count=0
    local current=0

    # Read undo log in reverse order and restore files
    while IFS='|' read -r source dest; do
        ((current++))

        if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
            printf "\r${COLOR_CYAN}[%d/%d]${COLOR_RESET} Undoing..." "$current" "$total_ops"
        fi

        # Check if destination still exists
        if [[ ! -f "$dest" ]]; then
            log_verbose "Skipping (file no longer exists): $(basename "$dest")"
            ((error_count++))
            continue
        fi

        # Check if source location is available
        local source_dir=$(dirname "$source")
        if [[ ! -d "$source_dir" ]]; then
            mkdir -p "$source_dir"
        fi

        if [[ -f "$source" ]]; then
            log_warning "Source already exists: $(basename "$source")"
            ((error_count++))
            continue
        fi

        # Move file back
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "\n${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would restore: $(basename "$dest") → $source"
            ((success_count++))
        else
            if mv "$dest" "$source"; then
                log_verbose "Restored: $(basename "$dest") → $source"
                ((success_count++))
            else
                log_error "Failed to restore: $(basename "$dest")"
                ((error_count++))
            fi
        fi
    done < <(tac "$undo_log" | grep -v '^#')

    echo ""

    # Summary
    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Undo Summary:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Successfully restored: ${COLOR_WHITE}$success_count${COLOR_RESET}"
    echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Failed/Skipped: ${COLOR_WHITE}$error_count${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"

    # Archive the undo log
    if [[ $success_count -gt 0 && "$DRY_RUN" == false ]]; then
        mv "$undo_log" "${undo_log}.completed"
        log_info "Undo log archived"
    fi

    end_operation
}

# List available undo operations
list_undo_operations() {
    begin_operation "Available Undo Operations"

    # Check if directory exists and has files
    if [[ ! -d "$UNDO_LOG_DIR" ]]; then
        log_info "No undo operations available"
        return 0
    fi

    # Check if directory is empty using glob pattern
    shopt -s nullglob dotglob
    local files=("$UNDO_LOG_DIR"/*)
    shopt -u nullglob dotglob

    if [[ ${#files[@]} -eq 0 ]]; then
        log_info "No undo operations available"
        return 0
    fi

    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}Available Undo Logs:${COLOR_RESET}"
    echo ""

    local count=0
    for log_file in "$UNDO_LOG_DIR"/organize-*.log; do
        [[ ! -f "$log_file" ]] && continue

        ((count++))
        local op_id=$(basename "$log_file" .log | sed 's/organize-//')
        local timestamp=$(grep '# Timestamp:' "$log_file" | cut -d':' -f2- | xargs)
        local op_count=$(grep -v '^#' "$log_file" | wc -l)

        echo -e "${COLOR_WHITE}[$count]${COLOR_RESET} ID: ${COLOR_CYAN}$op_id${COLOR_RESET}"
        echo -e "    Timestamp: $timestamp"
        echo -e "    Operations: $op_count file(s) moved"
        echo ""
    done

    if [[ $count -eq 0 ]]; then
        log_info "No undo operations available"
    fi

    end_operation
}

# Organize files by subfolder names
# Searches for files matching subfolder names and moves them to those subfolders
# Args: $1=target_folder(optional), $2=search_path(optional)
# Returns: 0 on success
organize_by_subfolder_names() {
    local target_folder="${1:-.}"
    local search_path="${2:-.}"

    begin_operation "Organize by Subfolder Names"

    # Validate target folder
    if [[ ! -d "$target_folder" ]]; then
        log_error "Target folder does not exist: $target_folder"
        return 1
    fi

    log_info "Target folder: $target_folder"
    log_info "Search path: $search_path"
    echo ""

    # Get all subdirectories (exclude hidden, "full", and common system dirs)
    local -a subfolders
    while IFS= read -r dir; do
        local basename=$(basename "$dir")
        # Skip hidden, full, and system directories
        if [[ ! "$basename" =~ ^\. ]] && \
           [[ "$basename" != "full" ]] && \
           [[ "$basename" != "Full" ]] && \
           [[ "$basename" != "FULL" ]] && \
           [[ "$basename" != "tmp" ]] && \
           [[ "$basename" != "temp" ]]; then
            subfolders+=("$dir")
        fi
    done < <(find "$target_folder" -mindepth 1 -maxdepth 1 -type d | sort)

    if [[ ${#subfolders[@]} -eq 0 ]]; then
        log_warning "No valid subfolders found in: $target_folder"
        return 1
    fi

    log_info "Found ${#subfolders[@]} subfolder(s) to match against"
    echo ""

    # Show folders
    echo -e "${COLOR_BRIGHT_CYAN}Subfolders:${COLOR_RESET}"
    for dir in "${subfolders[@]}"; do
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} $(basename "$dir")"
    done
    echo ""

    # Confirm before proceeding
    if [[ "$INTERACTIVE" == true ]]; then
        echo -n "Proceed with organizing files? (y/n): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_warning "Operation cancelled"
            return 1
        fi
    fi

    echo ""

    # Create undo log
    local operation_id=$(date +%Y%m%d-%H%M%S)
    local undo_log=""
    if [[ "$ORGANIZE_LOG_OPERATIONS" == true && "$DRY_RUN" == false ]]; then
        undo_log=$(_create_undo_log "$operation_id")
        log_info "Undo log: $(basename "$undo_log")"
        echo ""
    fi

    local moved_count=0
    local skipped_count=0
    local total_files=0

    # First pass: count total files to process
    if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
        log_verbose "Counting files to process..."
        for subfolder in "${subfolders[@]}"; do
            local subfolder_name=$(basename "$subfolder")
            local count=$(find "$search_path" -type f \( \
                -iname "*${subfolder_name}*" \
                \) 2>/dev/null | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg)$' | wc -l)
            ((total_files += count))
        done
        log_info "Total files to process: $total_files"
        echo ""
    fi

    local processed=0

    # For each subfolder, search for matching files
    for subfolder in "${subfolders[@]}"; do
        local subfolder_name=$(basename "$subfolder")
        local subfolder_name_lower=$(echo "$subfolder_name" | tr '[:upper:]' '[:lower:]')

        log_info "Searching for files matching: $subfolder_name"

        # Find all video files in search path that match the subfolder name
        local -a matching_files
        while IFS= read -r file; do
            # Skip if file doesn't exist
            [[ ! -f "$file" ]] && continue

            # Get parent directory
            local parent_dir=$(dirname "$file")
            local parent_basename=$(basename "$parent_dir")
            local parent_basename_lower=$(echo "$parent_basename" | tr '[:upper:]' '[:lower:]')

            # Skip if already in the target subfolder
            if [[ "$parent_dir" == "$subfolder" ]]; then
                log_verbose "Skipping (already in target): $(basename "$file")"
                ((skipped_count++))
                continue
            fi

            # Skip if in a "full" folder
            if [[ "$parent_basename_lower" == "full" ]] || [[ "$file" =~ /[Ff][Uu][Ll][Ll]/ ]]; then
                log_verbose "Skipping (in 'full' folder): $(basename "$file")"
                ((skipped_count++))
                continue
            fi

            matching_files+=("$file")
        done < <(find "$search_path" -type f \( \
            -iname "*${subfolder_name}*" -o \
            -iname "*${subfolder_name_lower}*" \
            \) 2>/dev/null | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg)$')

        # Move matching files
        if [[ ${#matching_files[@]} -gt 0 ]]; then
            log_info "Found ${#matching_files[@]} file(s) to move to: $subfolder_name"

            for file in "${matching_files[@]}"; do
                ((processed++))

                # Show progress
                if [[ "$ORGANIZE_SHOW_PROGRESS" == true && $total_files -gt 0 ]]; then
                    local percent=$((processed * 100 / total_files))
                    printf "\r${COLOR_CYAN}Progress: [%d/%d] %d%%${COLOR_RESET} " "$processed" "$total_files" "$percent"
                fi

                local filename=$(basename "$file")
                local dest="$subfolder/$filename"

                # Check if destination already exists
                if [[ -f "$dest" ]]; then
                    if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                        echo "" # New line before warning
                    fi
                    log_warning "Destination already exists: $filename"
                    ((skipped_count++))
                    continue
                fi

                # Move file
                if [[ "$DRY_RUN" == true ]]; then
                    if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                        echo "" # New line before message
                    fi
                    echo -e "${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would move: $filename → $subfolder_name/"
                    ((moved_count++))
                else
                    if mv "$file" "$dest"; then
                        # Log for undo
                        if [[ -n "$undo_log" ]]; then
                            _log_move_operation "$undo_log" "$file" "$dest"
                        fi

                        if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                            echo "" # New line before success message
                        fi
                        log_success "Moved: $filename → $subfolder_name/"
                        ((moved_count++))
                    else
                        if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                            echo "" # New line before error
                        fi
                        log_error "Failed to move: $filename"
                        ((skipped_count++))
                    fi
                fi
            done
        else
            log_verbose "No matches for: $subfolder_name"
        fi

        echo ""
    done

    # Summary
    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Summary:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Files moved: ${COLOR_WHITE}$moved_count${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}${SYMBOL_ARROW}${COLOR_RESET} Files skipped: ${COLOR_WHITE}$skipped_count${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"

    end_operation
}

################################################################################
# INTERACTIVE MENU SYSTEM
################################################################################

show_header() {
    clear
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╔═══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}  ${COLOR_BOLD}${COLOR_BRIGHT_YELLOW}VIDEO MANAGER ULTIMATE${COLOR_RESET}  ${COLOR_WHITE}v$SCRIPT_VERSION${COLOR_RESET}                    ${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╚═══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

show_main_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}MAIN MENU${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}File Operations${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Rename, organize, flatten directories"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}Subtitle Generation${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Generate, edit, translate subtitles"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Duplicate Detection${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Find and remove duplicate files"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[4]${COLOR_RESET} ${COLOR_WHITE}Multi-Drive Catalog${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Scan drives, search media, find duplicates"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[5]${COLOR_RESET} ${COLOR_WHITE}Utilities${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Logs, system info, testing"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[6]${COLOR_RESET} ${COLOR_WHITE}Settings${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Configure options and preferences"
    echo ""
    echo -e "${COLOR_RED}[Q]${COLOR_RESET} ${COLOR_WHITE}Quit${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Choose option: "
}

show_single_operations_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}FILE OPERATIONS${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Rename Files${COLOR_RESET} ${COLOR_CYAN}(Bracket Notation)${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}Remove Dashes${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Fix Bracket Spacing${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[4]${COLOR_RESET} ${COLOR_WHITE}Flatten Directory${COLOR_RESET} ${COLOR_CYAN}(Move All to Top)${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[5]${COLOR_RESET} ${COLOR_WHITE}Full Cleanup${COLOR_RESET} ${COLOR_CYAN}(All Operations)${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}[D]${COLOR_RESET} ${COLOR_WHITE}Toggle Dry Run${COLOR_RESET} ${COLOR_CYAN}(Current: $([[ "$DRY_RUN" == true ]] && echo "${COLOR_GREEN}${SYMBOL_CHECK} ON${COLOR_RESET}" || echo "${COLOR_RED}${SYMBOL_CROSS} OFF${COLOR_RESET}"))${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Main Menu${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

show_batch_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}BATCH PROCESSING${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Batch Rename${COLOR_RESET} ${COLOR_CYAN}(Multiple Folders)${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}Batch Flatten${COLOR_RESET} ${COLOR_CYAN}(Multiple Folders)${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Batch Full Cleanup${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Main Menu${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

show_workflow_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}AUTOMATED WORKFLOWS${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}New Collection Setup${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Flatten + Rename + Find Duplicates"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}Deep Clean Existing Collection${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Remove Dashes + Fix Spacing + Bracket Notation"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Main Menu${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

show_duplicate_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}DUPLICATE DETECTION${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Find Duplicates${COLOR_RESET} ${COLOR_CYAN}(Report Only)${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}Find and Delete Duplicates${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Find Duplicates${COLOR_RESET} ${COLOR_CYAN}(Dry Run)${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Main Menu${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

show_subtitle_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}SUBTITLE GENERATION${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Current Settings:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Model: ${COLOR_WHITE}$WHISPER_MODEL${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Format: ${COLOR_WHITE}$SUBTITLE_FORMAT${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Language: ${COLOR_WHITE}$SUBTITLE_LANGUAGE${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Parallel Jobs: ${COLOR_WHITE}$SUBTITLE_PARALLEL_JOBS${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} GPU Acceleration: $([[ "$SUBTITLE_USE_GPU" == true ]] && echo "${COLOR_GREEN}${SYMBOL_CHECK} ON${COLOR_RESET}" || echo "${COLOR_RED}${SYMBOL_CROSS} OFF${COLOR_RESET}")"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Batch Optimization: $([[ "$SUBTITLE_OPTIMIZE_BATCH" == true ]] && echo "${COLOR_GREEN}${SYMBOL_CHECK} ON${COLOR_RESET}" || echo "${COLOR_RED}${SYMBOL_CROSS} OFF${COLOR_RESET}")"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Recursive Scan: $([[ "$SUBTITLE_RECURSIVE" == true ]] && echo "${COLOR_GREEN}${SYMBOL_CHECK} ON${COLOR_RESET} ${COLOR_CYAN}(depth: $SUBTITLE_MIN_DEPTH-$SUBTITLE_MAX_DEPTH)${COLOR_RESET}" || echo "${COLOR_RED}${SYMBOL_CROSS} OFF${COLOR_RESET}")"

    # Count active filters
    local active_filters=0
    [[ $SUBTITLE_MIN_SIZE_MB -gt 0 ]] && ((active_filters++))
    [[ $SUBTITLE_MAX_SIZE_MB -gt 0 ]] && ((active_filters++))
    [[ $SUBTITLE_MODIFIED_DAYS -gt 0 ]] && ((active_filters++))
    [[ "$SUBTITLE_SKIP_EXISTING" == true ]] && ((active_filters++))
    [[ "$SUBTITLE_INTERACTIVE_SELECT" == true ]] && ((active_filters++))

    if [[ $active_filters -gt 0 ]]; then
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Active Filters: ${COLOR_YELLOW}$active_filters${COLOR_RESET}"
    fi
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Generate Subtitles${COLOR_RESET} ${COLOR_CYAN}(Single Directory)${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}Batch Generate Subtitles${COLOR_RESET} ${COLOR_CYAN}(Multiple Directories)${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Configure Subtitle Settings${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[4]${COLOR_RESET} ${COLOR_WHITE}Advanced Settings${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[5]${COLOR_RESET} ${COLOR_WHITE}Edit Existing Subtitle${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[6]${COLOR_RESET} ${COLOR_WHITE}Check Whisper Installation${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Main Menu${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

# Find duplicate files by hash in catalog
# Returns JSON array of duplicate groups
find_duplicates_in_catalog() {
    init_catalog_db

    local catalog_json=$(cat "$CATALOG_DB")

    # Group by hash and filter only groups with more than 1 file
    local duplicates=$(echo "$catalog_json" | jq -r '
        [.videos[] | select(.hash != null and .hash != "")] |
        group_by(.hash) |
        map(select(length > 1)) |
        map({
            hash: .[0].hash,
            count: length,
            total_size: (map(.file_size) | add),
            files: map({
                video_id: .video_id,
                drive_id: .drive_id,
                filename: .filename,
                relative_path: .relative_path,
                media_type: .media_type,
                file_size: .file_size,
                dimensions: .dimensions,
                resolution: .resolution,
                last_scanned: .last_scanned
            })
        })
    ')

    echo "$duplicates"
}

# Find similar images by dimensions (potential duplicates without hash match)
find_similar_images() {
    init_catalog_db

    local catalog_json=$(cat "$CATALOG_DB")

    # Group images by dimensions
    local similar=$(echo "$catalog_json" | jq -r '
        [.videos[] | select(.media_type == "image" and .dimensions != null and .dimensions != "")] |
        group_by(.dimensions) |
        map(select(length > 1)) |
        map({
            dimensions: .[0].dimensions,
            count: length,
            files: map({
                video_id: .video_id,
                drive_id: .drive_id,
                filename: .filename,
                relative_path: .relative_path,
                file_size: .file_size,
                camera: .camera,
                date_taken: .date_taken
            })
        })
    ')

    echo "$similar"
}

# Display duplicate report
show_duplicates_report() {
    local media_filter="${1:-all}"

    log_info "Scanning for duplicates..."

    local duplicates=$(find_duplicates_in_catalog)
    local dup_count=$(echo "$duplicates" | jq 'length')

    if [[ "$dup_count" -eq 0 ]] || [[ "$dup_count" == "null" ]]; then
        log_info "No duplicates found"
        return 0
    fi

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  DUPLICATE FILES REPORT${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""

    local group_num=0
    echo "$duplicates" | jq -c '.[]' | while IFS= read -r group; do
        ((group_num++))

        local hash=$(echo "$group" | jq -r '.hash' | cut -c1-16)
        local count=$(echo "$group" | jq -r '.count')
        local total_size=$(echo "$group" | jq -r '.total_size')
        local wasted_size=$((total_size - total_size / count))

        echo -e "${COLOR_BOLD}${COLOR_YELLOW}${SYMBOL_WARN} Duplicate Group #$group_num${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Hash: ${COLOR_WHITE}$hash...${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Copies: ${COLOR_RED}$count files${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Wasted Space: ${COLOR_RED}$(format_bytes $wasted_size)${COLOR_RESET}"
        echo ""

        local file_num=0
        echo "$group" | jq -c '.files[]' | while IFS= read -r file; do
            ((file_num++))

            local filename=$(echo "$file" | jq -r '.filename')
            local media_type=$(echo "$file" | jq -r '.media_type')
            local size=$(echo "$file" | jq -r '.file_size')
            local drive_id=$(echo "$file" | jq -r '.drive_id')

            # Get drive info
            local drive_label=$(cat "$CATALOG_DRIVES_DB" | jq -r --arg id "$drive_id" \
                '.drives[] | select(.drive_id == $id) | .drive_label' 2>/dev/null || echo "Unknown")

            # Media type icon
            local type_icon="📄"
            case "$media_type" in
                video) type_icon="🎬" ;;
                image) type_icon="🖼️" ;;
                audio) type_icon="🎵" ;;
            esac

            echo -e "    ${COLOR_BRIGHT_GREEN}[$file_num]${COLOR_RESET} $type_icon ${COLOR_WHITE}$filename${COLOR_RESET}"
            echo -e "        ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Drive: ${COLOR_WHITE}$drive_label${COLOR_RESET}"
            echo -e "        ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Size: ${COLOR_WHITE}$(format_bytes $size)${COLOR_RESET}"
        done

        echo ""
    done

    # Calculate total wasted space
    local total_wasted=$(echo "$duplicates" | jq '[.[] | (.total_size - (.total_size / .count))] | add')
    local total_dupes=$(echo "$duplicates" | jq '[.[] | .count] | add')

    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Summary:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Duplicate Groups: ${COLOR_RED}$dup_count${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Total Duplicate Files: ${COLOR_RED}$total_dupes${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Wasted Space: ${COLOR_RED}$(format_bytes $total_wasted)${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

show_catalog_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}MULTI-DRIVE CATALOG${COLOR_RESET}"
    echo ""

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${COLOR_YELLOW}${SYMBOL_WARN} jq is not installed. Install with: ${COLOR_WHITE}sudo apt-get install jq${COLOR_RESET}"
        echo ""
    fi

    # Show catalog stats
    if [[ -f "$CATALOG_DRIVES_DB" ]]; then
        local drive_count=$(cat "$CATALOG_DRIVES_DB" 2>/dev/null | jq '.drives | length' 2>/dev/null || echo "0")
        local video_count=$(cat "$CATALOG_DB" 2>/dev/null | jq '.videos | length' 2>/dev/null || echo "0")
        echo -e "${COLOR_BOLD}${COLOR_WHITE}Catalog Status:${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Cataloged Drives: ${COLOR_WHITE}$drive_count${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Total Media Files: ${COLOR_WHITE}$video_count${COLOR_RESET}"
        echo ""
    fi

    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Scan & Catalog Drive${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}List All Cataloged Drives${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Search Catalog${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[4]${COLOR_RESET} ${COLOR_WHITE}Find Duplicate Files${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[5]${COLOR_RESET} ${COLOR_WHITE}Batch Catalog Multiple Drives${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[6]${COLOR_RESET} ${COLOR_WHITE}Export Catalog Report${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[7]${COLOR_RESET} ${COLOR_WHITE}Catalog Settings${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Main Menu${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

show_utilities_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}UTILITIES${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Organize by Subfolder Names${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}List Undo Operations${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Undo Last Organize Operation${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[4]${COLOR_RESET} ${COLOR_WHITE}View Last 50 Log Entries${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[5]${COLOR_RESET} ${COLOR_WHITE}Open Log Directory${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[6]${COLOR_RESET} ${COLOR_WHITE}Test Filename Transformation${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[7]${COLOR_RESET} ${COLOR_WHITE}Display System Information${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Main Menu${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

show_settings_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}SETTINGS${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Current Configuration:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Dry Run Mode: $([[ "$DRY_RUN" == true ]] && echo "${COLOR_GREEN}${SYMBOL_CHECK} ENABLED${COLOR_RESET}" || echo "${COLOR_RED}${SYMBOL_CROSS} DISABLED${COLOR_RESET}")"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Verbose Output: $([[ "$VERBOSE" == true ]] && echo "${COLOR_GREEN}${SYMBOL_CHECK} ENABLED${COLOR_RESET}" || echo "${COLOR_RED}${SYMBOL_CROSS} DISABLED${COLOR_RESET}")"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Log Directory: ${COLOR_WHITE}$LOG_DIR${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Toggle Dry Run Mode${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}Toggle Verbose Output${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}View Supported Extensions${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[4]${COLOR_RESET} ${COLOR_WHITE}Granular Controls${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[5]${COLOR_RESET} ${COLOR_WHITE}Organize Settings${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}[6]${COLOR_RESET} ${COLOR_WHITE}Save Configuration${COLOR_RESET}       ${COLOR_YELLOW}[7]${COLOR_RESET} ${COLOR_WHITE}Load Configuration${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}[8]${COLOR_RESET} ${COLOR_WHITE}List Profiles${COLOR_RESET}            ${COLOR_YELLOW}[9]${COLOR_RESET} ${COLOR_WHITE}Delete Profile${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Main Menu${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

show_organize_settings_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}ORGANIZE SETTINGS${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Current Settings:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Default Target:  ${COLOR_WHITE}$ORGANIZE_DEFAULT_TARGET${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Default Search:  ${COLOR_WHITE}$ORGANIZE_DEFAULT_SEARCH${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Show Progress:   $([[ "$ORGANIZE_SHOW_PROGRESS" == true ]] && echo "${COLOR_GREEN}${SYMBOL_CHECK} ENABLED${COLOR_RESET}" || echo "${COLOR_RED}${SYMBOL_CROSS} DISABLED${COLOR_RESET}")"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Log Operations:  $([[ "$ORGANIZE_LOG_OPERATIONS" == true ]] && echo "${COLOR_GREEN}${SYMBOL_CHECK} ENABLED${COLOR_RESET}" || echo "${COLOR_RED}${SYMBOL_CROSS} DISABLED${COLOR_RESET}")"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Set Default Target Path${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}Set Default Search Path${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Toggle Show Progress${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[4]${COLOR_RESET} ${COLOR_WHITE}Toggle Log Operations${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Settings${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

show_granular_controls_menu() {
    show_header

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}GRANULAR CONTROLS${COLOR_RESET}"
    echo ""

    # Count active filters
    local active_count=0
    [[ "$FILTER_BY_SIZE" == true ]] && ((active_count++))
    [[ "$FILTER_BY_DATE" == true ]] && ((active_count++))
    [[ "$FILTER_BY_PATTERN" == true ]] && ((active_count++))

    echo -e "${COLOR_BOLD}${COLOR_WHITE}━━━ Interactive Mode ━━━${COLOR_RESET}"
    printf "  ${COLOR_CYAN}%-22s${COLOR_RESET} " "Per-File Confirm:"
    [[ "$INTERACTIVE_CONFIRM" == true ]] && echo -e "${COLOR_GREEN}${SYMBOL_CHECK} ENABLED${COLOR_RESET}" || echo -e "${COLOR_RED}${SYMBOL_CROSS} DISABLED${COLOR_RESET}"

    printf "  ${COLOR_CYAN}%-22s${COLOR_RESET} " "Show Preview:"
    [[ "$SHOW_PREVIEW" == true ]] && echo -e "${COLOR_GREEN}${SYMBOL_CHECK} ENABLED${COLOR_RESET}" || echo -e "${COLOR_RED}${SYMBOL_CROSS} DISABLED${COLOR_RESET}"

    printf "  ${COLOR_CYAN}%-22s${COLOR_RESET} " "Step-by-Step:"
    [[ "$STEP_BY_STEP" == true ]] && echo -e "${COLOR_GREEN}${SYMBOL_CHECK} ENABLED${COLOR_RESET}" || echo -e "${COLOR_RED}${SYMBOL_CROSS} DISABLED${COLOR_RESET}"

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}━━━ Filters ${COLOR_RESET}${COLOR_YELLOW}($active_count active)${COLOR_RESET}${COLOR_BOLD}${COLOR_WHITE} ━━━${COLOR_RESET}"

    printf "  ${COLOR_CYAN}%-22s${COLOR_RESET} " "Size Filter:"
    if [[ "$FILTER_BY_SIZE" == true ]]; then
        echo -e "${COLOR_GREEN}${SYMBOL_CHECK} ON${COLOR_RESET} ${COLOR_WHITE}(${FILTER_MIN_SIZE_MB}MB - ${FILTER_MAX_SIZE_MB}MB)${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}${SYMBOL_CROSS} OFF${COLOR_RESET}"
    fi

    printf "  ${COLOR_CYAN}%-22s${COLOR_RESET} " "Date Filter:"
    if [[ "$FILTER_BY_DATE" == true ]]; then
        echo -e "${COLOR_GREEN}${SYMBOL_CHECK} ON${COLOR_RESET} ${COLOR_WHITE}(${FILTER_DAYS_OLD}+ days old)${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}${SYMBOL_CROSS} OFF${COLOR_RESET}"
    fi

    printf "  ${COLOR_CYAN}%-22s${COLOR_RESET} " "Pattern Filter:"
    if [[ "$FILTER_BY_PATTERN" == true ]]; then
        echo -e "${COLOR_GREEN}${SYMBOL_CHECK} ON${COLOR_RESET} ${COLOR_WHITE}($FILTER_PATTERN)${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}${SYMBOL_CROSS} OFF${COLOR_RESET}"
    fi

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}━━━ Processing ━━━${COLOR_RESET}"

    printf "  ${COLOR_CYAN}%-22s${COLOR_RESET} " "Undo System:"
    [[ "$ENABLE_UNDO" == true ]] && echo -e "${COLOR_GREEN}${SYMBOL_CHECK} ENABLED${COLOR_RESET}" || echo -e "${COLOR_RED}${SYMBOL_CROSS} DISABLED${COLOR_RESET}"

    printf "  ${COLOR_CYAN}%-22s${COLOR_RESET} " "Batch Size:"
    echo -e "${COLOR_WHITE}$BATCH_SIZE files${COLOR_RESET}"

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}━━━ Options ━━━${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Toggle Per-File Confirmation${COLOR_RESET}  ${COLOR_CYAN}[2]${COLOR_RESET} ${COLOR_WHITE}Toggle Preview${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Toggle Step-by-Step Mode${COLOR_RESET}     ${COLOR_CYAN}[4]${COLOR_RESET} ${COLOR_WHITE}Size Filter${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[5]${COLOR_RESET} ${COLOR_WHITE}Date Filter${COLOR_RESET}                  ${COLOR_CYAN}[6]${COLOR_RESET} ${COLOR_WHITE}Pattern Filter${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}[7]${COLOR_RESET} ${COLOR_WHITE}Toggle Undo System${COLOR_RESET}            ${COLOR_YELLOW}[8]${COLOR_RESET} ${COLOR_WHITE}View Undo History${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}[9]${COLOR_RESET} ${COLOR_WHITE}Undo Last Operation${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}[B]${COLOR_RESET} ${COLOR_WHITE}Back to Settings${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select option: "
}

# Get directory input
get_directory_input() {
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Enter directory path: "
    read -r dir

    dir=$(validate_directory "$dir")
    if [[ $? -eq 0 ]]; then
        TARGET_FOLDER="$dir"
        return 0
    else
        return 1
    fi
}

# Handle single operations
handle_single_operations() {
    while true; do
        show_single_operations_menu
        read -r choice
        
        case "$choice" in
            1)
                if get_directory_input; then
                    start_operation "Rename Files (Bracket Notation)"
                    rename_files_in_directory "$TARGET_FOLDER" "$DRY_RUN"
                    end_operation
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                if get_directory_input; then
                    start_operation "Remove Dashes"
                    # Would implement dash-only removal here
                    log_info "Feature coming soon!"
                    end_operation
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                if get_directory_input; then
                    start_operation "Fix Bracket Spacing"
                    # Would implement spacing-only fix here
                    log_info "Feature coming soon!"
                    end_operation
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                if get_directory_input; then
                    start_operation "Flatten Directory"
                    flatten_directory "$TARGET_FOLDER" "$DRY_RUN"
                    end_operation
                    read -p "Press Enter to continue..."
                fi
                ;;
            5)
                if get_directory_input; then
                    workflow_deep_clean "$TARGET_FOLDER"
                    read -p "Press Enter to continue..."
                fi
                ;;
            d|D)
                if [[ "$DRY_RUN" == true ]]; then
                    DRY_RUN=false
                    log_success "Dry run mode DISABLED - changes will be applied"
                else
                    DRY_RUN=true
                    log_success "Dry run mode ENABLED - no changes will be made"
                fi
                read -p "Press Enter to continue..."
                ;;
            b|B)
                break
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
        
        reset_statistics
    done
}

# Handle batch processing
handle_batch_processing() {
    while true; do
        show_batch_menu
        read -r choice
        
        case "$choice" in
            1)
                start_operation "Batch Rename Multiple Folders"
                batch_process_folders
                end_operation
                read -p "Press Enter to continue..."
                ;;
            2)
                log_info "Feature coming soon!"
                read -p "Press Enter to continue..."
                ;;
            3)
                log_info "Feature coming soon!"
                read -p "Press Enter to continue..."
                ;;
            b|B)
                break
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
        
        reset_statistics
    done
}

# Handle workflows
handle_workflows() {
    while true; do
        show_workflow_menu
        read -r choice
        
        case "$choice" in
            1)
                if get_directory_input; then
                    workflow_new_collection "$TARGET_FOLDER"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                if get_directory_input; then
                    workflow_deep_clean "$TARGET_FOLDER"
                    read -p "Press Enter to continue..."
                fi
                ;;
            b|B)
                break
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
        
        reset_statistics
    done
}

# Handle duplicate detection
handle_duplicates() {
    while true; do
        show_duplicate_menu
        read -r choice
        
        case "$choice" in
            1)
                if get_directory_input; then
                    start_operation "Find Duplicates (Report Only)"
                    find_duplicates "$TARGET_FOLDER" "report"
                    end_operation
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                if get_directory_input; then
                    start_operation "Find and Delete Duplicates"
                    echo ""
                    log_warning "This will DELETE duplicate files!"
                    read -p "Are you sure? (type 'yes' to confirm): " confirm
                    if [[ "$confirm" == "yes" ]]; then
                        find_duplicates "$TARGET_FOLDER" "delete"
                    else
                        log_warning "Operation cancelled"
                    fi
                    end_operation
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                local old_dry_run="$DRY_RUN"
                DRY_RUN=true
                if get_directory_input; then
                    start_operation "Find Duplicates (Dry Run)"
                    find_duplicates "$TARGET_FOLDER" "delete"
                    end_operation
                    read -p "Press Enter to continue..."
                fi
                DRY_RUN="$old_dry_run"
                ;;
            b|B)
                break
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
        
        reset_statistics
    done
}

# Handle subtitle generation
handle_subtitles() {
    while true; do
        show_subtitle_menu
        read -r choice

        case "$choice" in
            1)
                if get_directory_input; then
                    start_operation "Generate Subtitles"
                    generate_subtitles_in_directory "$TARGET_FOLDER" "$WHISPER_MODEL" "$SUBTITLE_FORMAT" "$SUBTITLE_LANGUAGE" "$DRY_RUN"
                    end_operation
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                start_operation "Batch Subtitle Generation"
                batch_generate_subtitles
                end_operation
                read -p "Press Enter to continue..."
                ;;
            3)
                # Configure subtitle settings
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Configure Subtitle Settings${COLOR_RESET}"
                echo ""

                # Select model
                echo -e "${COLOR_WHITE}Select Whisper Model:${COLOR_RESET}"
                echo "  [1] tiny   - Fastest, least accurate"
                echo "  [2] base   - Balanced (default)"
                echo "  [3] small  - Good accuracy"
                echo "  [4] medium - Better accuracy"
                echo "  [5] large  - Best accuracy, slowest"
                echo -n "Choice [1-5]: "
                read -r model_choice

                case "$model_choice" in
                    1) WHISPER_MODEL="tiny" ;;
                    2) WHISPER_MODEL="base" ;;
                    3) WHISPER_MODEL="small" ;;
                    4) WHISPER_MODEL="medium" ;;
                    5) WHISPER_MODEL="large" ;;
                esac

                echo ""
                echo -e "${COLOR_WHITE}Select Output Format:${COLOR_RESET}"
                echo "  [1] srt  - SubRip (default)"
                echo "  [2] vtt  - WebVTT"
                echo "  [3] txt  - Plain text"
                echo "  [4] json - JSON format"
                echo -n "Choice [1-4]: "
                read -r format_choice

                case "$format_choice" in
                    1) SUBTITLE_FORMAT="srt" ;;
                    2) SUBTITLE_FORMAT="vtt" ;;
                    3) SUBTITLE_FORMAT="txt" ;;
                    4) SUBTITLE_FORMAT="json" ;;
                esac

                echo ""
                echo -e "${COLOR_WHITE}Language (enter code or 'auto'):${COLOR_RESET}"
                echo "  Examples: en (English), es (Spanish), fr (French), auto (detect)"
                echo -n "Language: "
                read -r lang_choice

                if [[ -n "$lang_choice" ]]; then
                    SUBTITLE_LANGUAGE="$lang_choice"
                fi

                echo ""
                log_success "Settings updated!"
                log_info "Model: $WHISPER_MODEL"
                log_info "Format: $SUBTITLE_FORMAT"
                log_info "Language: $SUBTITLE_LANGUAGE"
                read -p "Press Enter to continue..."
                ;;
            4)
                # Advanced Settings
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Advanced Subtitle Settings${COLOR_RESET}"
                echo ""

                echo -e "${COLOR_WHITE}[1]${COLOR_RESET} Toggle GPU Acceleration (Current: $([[ "$SUBTITLE_USE_GPU" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}"))"
                echo -e "${COLOR_WHITE}[2]${COLOR_RESET} Set Parallel Jobs (Current: ${COLOR_CYAN}$SUBTITLE_PARALLEL_JOBS${COLOR_RESET})"
                echo -e "${COLOR_WHITE}[3]${COLOR_RESET} Toggle Batch Optimization (Current: $([[ "$SUBTITLE_OPTIMIZE_BATCH" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}"))"
                echo -e "${COLOR_WHITE}[4]${COLOR_RESET} Toggle Speaker Diarization (Current: $([[ "$SUBTITLE_SPEAKER_DIARIZATION" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}"))"
                echo -e "${COLOR_WHITE}[5]${COLOR_RESET} Toggle Auto-Punctuation (Current: $([[ "$SUBTITLE_AUTO_PUNCTUATION" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}"))"
                echo -e "${COLOR_WHITE}[6]${COLOR_RESET} Toggle Interactive Editing (Current: $([[ "$SUBTITLE_INTERACTIVE_EDIT" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}"))"
                echo -e "${COLOR_WHITE}[7]${COLOR_RESET} Toggle Auto-Edit (Current: $([[ "$SUBTITLE_AUTO_EDIT" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}"))"
                echo ""
                echo -e "${COLOR_YELLOW}Recursive Scanning:${COLOR_RESET}"
                echo -e "${COLOR_WHITE}[8]${COLOR_RESET} Toggle Recursive Mode (Current: $([[ "$SUBTITLE_RECURSIVE" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}"))"
                echo -e "${COLOR_WHITE}[9]${COLOR_RESET} Set Max Depth (Current: ${COLOR_CYAN}$SUBTITLE_MAX_DEPTH${COLOR_RESET})"
                echo -e "${COLOR_WHITE}[10]${COLOR_RESET} Set Max Files (Current: ${COLOR_CYAN}$SUBTITLE_MAX_FILES${COLOR_RESET})"
                echo -e "${COLOR_WHITE}[11]${COLOR_RESET} Configure Filters & Selection"
                echo ""
                echo -n "Select option (or Enter to skip): "
                read -r adv_choice

                case "$adv_choice" in
                    1)
                        if [[ "$SUBTITLE_USE_GPU" == true ]]; then
                            SUBTITLE_USE_GPU=false
                            log_info "GPU acceleration disabled"
                        else
                            SUBTITLE_USE_GPU=true
                            if detect_gpu; then
                                log_success "GPU acceleration enabled"
                            else
                                log_warning "GPU not detected on this system"
                            fi
                        fi
                        ;;
                    2)
                        echo -n "Enter number of parallel jobs (1-8): "
                        read -r jobs
                        if [[ $jobs -ge 1 && $jobs -le 8 ]]; then
                            SUBTITLE_PARALLEL_JOBS=$jobs
                            log_success "Parallel jobs set to: $jobs"
                        else
                            log_error "Invalid number. Must be 1-8"
                        fi
                        ;;
                    3)
                        if [[ "$SUBTITLE_OPTIMIZE_BATCH" == true ]]; then
                            SUBTITLE_OPTIMIZE_BATCH=false
                        else
                            SUBTITLE_OPTIMIZE_BATCH=true
                        fi
                        log_success "Batch optimization toggled"
                        ;;
                    4)
                        if [[ "$SUBTITLE_SPEAKER_DIARIZATION" == true ]]; then
                            SUBTITLE_SPEAKER_DIARIZATION=false
                        else
                            SUBTITLE_SPEAKER_DIARIZATION=true
                        fi
                        log_success "Speaker diarization toggled"
                        ;;
                    5)
                        if [[ "$SUBTITLE_AUTO_PUNCTUATION" == true ]]; then
                            SUBTITLE_AUTO_PUNCTUATION=false
                        else
                            SUBTITLE_AUTO_PUNCTUATION=true
                        fi
                        log_success "Auto-punctuation toggled"
                        ;;
                    6)
                        if [[ "$SUBTITLE_INTERACTIVE_EDIT" == true ]]; then
                            SUBTITLE_INTERACTIVE_EDIT=false
                        else
                            SUBTITLE_INTERACTIVE_EDIT=true
                        fi
                        log_success "Interactive editing toggled"
                        ;;
                    7)
                        if [[ "$SUBTITLE_AUTO_EDIT" == true ]]; then
                            SUBTITLE_AUTO_EDIT=false
                        else
                            SUBTITLE_AUTO_EDIT=true
                        fi
                        log_success "Auto-edit toggled"
                        ;;
                    8)
                        if [[ "$SUBTITLE_RECURSIVE" == true ]]; then
                            SUBTITLE_RECURSIVE=false
                            log_info "Recursive mode DISABLED - will only scan current directory"
                        else
                            SUBTITLE_RECURSIVE=true
                            log_success "Recursive mode ENABLED - will scan subdirectories"
                            log_info "Max depth: $SUBTITLE_MAX_DEPTH levels"
                            log_info "Max files: $SUBTITLE_MAX_FILES files"
                        fi
                        ;;
                    9)
                        echo -n "Enter maximum recursion depth (1-50): "
                        read -r depth
                        if [[ $depth -ge 1 && $depth -le 50 ]]; then
                            SUBTITLE_MAX_DEPTH=$depth
                            log_success "Max depth set to: $depth"
                        else
                            log_error "Invalid depth. Must be 1-50"
                        fi
                        ;;
                    10)
                        echo -n "Enter maximum files to process (1-10000): "
                        read -r max_files
                        if [[ $max_files -ge 1 && $max_files -le 10000 ]]; then
                            SUBTITLE_MAX_FILES=$max_files
                            log_success "Max files set to: $max_files"
                        else
                            log_error "Invalid number. Must be 1-10000"
                        fi
                        ;;
                    11)
                        # Filters & Selection submenu
                        clear
                        echo -e "${COLOR_BRIGHT_CYAN}Advanced Filters & Selection${COLOR_RESET}"
                        echo ""
                        echo -e "${COLOR_YELLOW}Current Filters:${COLOR_RESET}"
                        echo -e "  Min Size: ${COLOR_CYAN}${SUBTITLE_MIN_SIZE_MB}${COLOR_RESET} MB"
                        echo -e "  Max Size: ${COLOR_CYAN}${SUBTITLE_MAX_SIZE_MB}${COLOR_RESET} MB (0=unlimited)"
                        echo -e "  Modified: ${COLOR_CYAN}${SUBTITLE_MODIFIED_DAYS}${COLOR_RESET} days (0=all)"
                        echo -e "  Skip Existing: $([[ "$SUBTITLE_SKIP_EXISTING" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}")"
                        echo -e "  Show Dir Stats: $([[ "$SUBTITLE_SHOW_DIR_STATS" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}")"
                        echo -e "  Interactive Select: $([[ "$SUBTITLE_INTERACTIVE_SELECT" == true ]] && echo "${COLOR_GREEN}ON${COLOR_RESET}" || echo "${COLOR_RED}OFF${COLOR_RESET}")"
                        echo -e "  Min Depth: ${COLOR_CYAN}${SUBTITLE_MIN_DEPTH}${COLOR_RESET}"
                        echo -e "  Skip Patterns: ${COLOR_CYAN}${#SUBTITLE_SKIP_PATTERNS[@]}${COLOR_RESET} patterns"
                        echo ""
                        echo -e "${COLOR_WHITE}[1]${COLOR_RESET} Set Minimum File Size (MB)"
                        echo -e "${COLOR_WHITE}[2]${COLOR_RESET} Set Maximum File Size (MB)"
                        echo -e "${COLOR_WHITE}[3]${COLOR_RESET} Set Modified Days Filter"
                        echo -e "${COLOR_WHITE}[4]${COLOR_RESET} Toggle Skip Existing Subtitles"
                        echo -e "${COLOR_WHITE}[5]${COLOR_RESET} Toggle Show Directory Stats"
                        echo -e "${COLOR_WHITE}[6]${COLOR_RESET} Toggle Interactive Directory Selection"
                        echo -e "${COLOR_WHITE}[7]${COLOR_RESET} Set Minimum Depth"
                        echo -e "${COLOR_WHITE}[8]${COLOR_RESET} Manage Skip Patterns"
                        echo -e "${COLOR_WHITE}[9]${COLOR_RESET} Reset All Filters to Default"
                        echo ""
                        echo -n "Select option: "
                        read -r filter_choice

                        case "$filter_choice" in
                            1)
                                echo -n "Enter minimum file size in MB (0=no limit): "
                                read -r min_size
                                if [[ $min_size -ge 0 ]]; then
                                    SUBTITLE_MIN_SIZE_MB=$min_size
                                    log_success "Minimum size set to: ${min_size}MB"
                                else
                                    log_error "Invalid size"
                                fi
                                ;;
                            2)
                                echo -n "Enter maximum file size in MB (0=no limit): "
                                read -r max_size
                                if [[ $max_size -ge 0 ]]; then
                                    SUBTITLE_MAX_SIZE_MB=$max_size
                                    log_success "Maximum size set to: ${max_size}MB"
                                else
                                    log_error "Invalid size"
                                fi
                                ;;
                            3)
                                echo -n "Process files modified in last N days (0=all files): "
                                read -r days
                                if [[ $days -ge 0 ]]; then
                                    SUBTITLE_MODIFIED_DAYS=$days
                                    log_success "Date filter set to: ${days} days"
                                else
                                    log_error "Invalid number of days"
                                fi
                                ;;
                            4)
                                if [[ "$SUBTITLE_SKIP_EXISTING" == true ]]; then
                                    SUBTITLE_SKIP_EXISTING=false
                                    log_info "Will process videos even if subtitles exist"
                                else
                                    SUBTITLE_SKIP_EXISTING=true
                                    log_success "Will skip videos that already have subtitles"
                                fi
                                ;;
                            5)
                                if [[ "$SUBTITLE_SHOW_DIR_STATS" == true ]]; then
                                    SUBTITLE_SHOW_DIR_STATS=false
                                else
                                    SUBTITLE_SHOW_DIR_STATS=true
                                fi
                                log_success "Directory statistics toggled"
                                ;;
                            6)
                                if [[ "$SUBTITLE_INTERACTIVE_SELECT" == true ]]; then
                                    SUBTITLE_INTERACTIVE_SELECT=false
                                    log_info "Interactive selection DISABLED - will process all subdirectories"
                                else
                                    SUBTITLE_INTERACTIVE_SELECT=true
                                    log_success "Interactive selection ENABLED - you'll choose which folders to process"
                                fi
                                ;;
                            7)
                                echo -n "Enter minimum depth (0=include current dir, 1=subdirs only): "
                                read -r min_depth
                                if [[ $min_depth -ge 0 && $min_depth -le 50 ]]; then
                                    SUBTITLE_MIN_DEPTH=$min_depth
                                    log_success "Minimum depth set to: $min_depth"
                                else
                                    log_error "Invalid depth. Must be 0-50"
                                fi
                                ;;
                            8)
                                echo ""
                                echo -e "${COLOR_CYAN}Current Skip Patterns:${COLOR_RESET}"
                                for i in "${!SUBTITLE_SKIP_PATTERNS[@]}"; do
                                    echo "  [$i] ${SUBTITLE_SKIP_PATTERNS[$i]}"
                                done
                                echo ""
                                echo "Common patterns: .* (hidden), _* (underscore), tmp, temp, Trash"
                                echo "Leave empty to keep current patterns"
                                echo ""
                                echo -n "Enter new patterns (space-separated): "
                                read -r new_patterns
                                if [[ -n "$new_patterns" ]]; then
                                    read -ra SUBTITLE_SKIP_PATTERNS <<< "$new_patterns"
                                    log_success "Skip patterns updated: ${SUBTITLE_SKIP_PATTERNS[*]}"
                                fi
                                ;;
                            9)
                                SUBTITLE_MIN_SIZE_MB=0
                                SUBTITLE_MAX_SIZE_MB=0
                                SUBTITLE_MODIFIED_DAYS=0
                                SUBTITLE_SKIP_EXISTING=true
                                SUBTITLE_SHOW_DIR_STATS=true
                                SUBTITLE_INTERACTIVE_SELECT=false
                                SUBTITLE_MIN_DEPTH=1
                                SUBTITLE_SKIP_PATTERNS=(".*" "_*" "node_modules" ".git" ".svn" "Trash" "tmp" "temp")
                                log_success "All filters reset to default values"
                                ;;
                        esac
                        read -p "Press Enter to continue..."
                        ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            5)
                # Edit existing subtitle
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Edit Existing Subtitle${COLOR_RESET}"
                echo ""
                echo -n "Enter subtitle file path: "
                read -r subtitle_path

                if [[ -f "$subtitle_path" ]]; then
                    edit_subtitle_interactive "$subtitle_path"
                else
                    log_error "File not found: $subtitle_path"
                    read -p "Press Enter to continue..."
                fi
                ;;
            6)
                # Check whisper installation
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Checking Whisper Installation${COLOR_RESET}"
                echo ""

                if check_whisper_installation; then
                    local whisper_cmd=$(get_whisper_command)
                    log_success "Whisper is installed: $whisper_cmd"

                    echo ""
                    echo -e "${COLOR_WHITE}Testing whisper command...${COLOR_RESET}"
                    if [[ "$whisper_cmd" == "whisper" ]]; then
                        whisper --help | head -n 10
                    elif [[ "$whisper_cmd" == "whisper.cpp" ]]; then
                        whisper.cpp --help 2>&1 | head -n 10
                    fi
                else
                    log_error "Whisper is not installed!"
                    echo ""
                    echo -e "${COLOR_YELLOW}Installation Instructions:${COLOR_RESET}"
                    echo ""
                    echo -e "${COLOR_WHITE}Option 1 - OpenAI Whisper (Python):${COLOR_RESET}"
                    echo "  pip install -U openai-whisper"
                    echo ""
                    echo -e "${COLOR_WHITE}Option 2 - whisper.cpp (C++, faster):${COLOR_RESET}"
                    echo "  git clone https://github.com/ggerganov/whisper.cpp"
                    echo "  cd whisper.cpp && make"
                    echo "  # Add to PATH or create symlink"
                    echo ""
                fi
                read -p "Press Enter to continue..."
                ;;
            b|B)
                break
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac

        reset_statistics
    done
}

# Handle catalog operations
handle_catalog() {
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is not installed. Please install it first:"
        echo "  sudo apt-get install jq"
        read -p "Press Enter to continue..."
        return 1
    fi

    while true; do
        show_catalog_menu
        read -r choice

        case "$choice" in
            1)
                # Scan & catalog a drive
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Scan & Catalog a Drive${COLOR_RESET}"
                echo ""
                echo "Available mount points:"
                echo "  /mnt/c  - Windows C: drive"
                echo "  /mnt/d  - Windows D: drive"
                echo "  /media/* - USB drives (if mounted)"
                echo ""
                read -p "Enter mount point to catalog: " mount_point

                if [[ -z "$mount_point" ]]; then
                    log_error "No mount point specified"
                    read -p "Press Enter to continue..."
                    continue
                fi

                read -p "Scan recursively? (y/n): " -n 1 -r
                echo ""
                local recursive=false
                [[ $REPLY =~ ^[Yy]$ ]] && recursive=true

                start_operation "Catalog Drive: $mount_point"
                catalog_drive "$mount_point" "$recursive"
                end_operation
                read -p "Press Enter to continue..."
                ;;

            2)
                # List all cataloged drives
                clear
                start_operation "List Cataloged Drives"
                list_cataloged_drives
                end_operation
                read -p "Press Enter to continue..."
                ;;

            3)
                # Search catalog
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Search Catalog${COLOR_RESET}"
                echo ""
                echo -e "${COLOR_WHITE}Filter by media type:${COLOR_RESET}"
                echo "  [1] All media"
                echo "  [2] Videos only"
                echo "  [3] Images only"
                echo "  [4] Audio only"
                echo ""
                read -p "Choose filter [1-4]: " filter_choice

                local media_filter="all"
                case "$filter_choice" in
                    2) media_filter="video" ;;
                    3) media_filter="image" ;;
                    4) media_filter="audio" ;;
                    *) media_filter="all" ;;
                esac

                echo ""
                read -p "Enter search term: " search_term

                if [[ -n "$search_term" ]]; then
                    start_operation "Search Catalog"
                    search_catalog "$search_term" "$media_filter"
                    end_operation
                fi
                read -p "Press Enter to continue..."
                ;;

            4)
                # Find duplicate files
                clear
                start_operation "Find Duplicate Files"
                show_duplicates_report
                end_operation
                read -p "Press Enter to continue..."
                ;;

            5)
                # Catalog multiple drives (batch)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Batch Catalog Multiple Drives${COLOR_RESET}"
                echo ""
                echo "Enter mount points to catalog (one per line, empty line to finish):"
                echo ""

                local -a mount_points
                while true; do
                    read -p "Mount point: " mp
                    [[ -z "$mp" ]] && break
                    mount_points+=("$mp")
                done

                if [[ ${#mount_points[@]} -eq 0 ]]; then
                    log_warning "No mount points specified"
                    read -p "Press Enter to continue..."
                    continue
                fi

                read -p "Scan recursively? (y/n): " -n 1 -r
                echo ""
                local recursive=false
                [[ $REPLY =~ ^[Yy]$ ]] && recursive=true

                start_operation "Batch Catalog Drives"
                for mp in "${mount_points[@]}"; do
                    echo ""
                    catalog_drive "$mp" "$recursive"
                done
                end_operation
                read -p "Press Enter to continue..."
                ;;

            6)
                # Export catalog report
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Export Catalog Report${COLOR_RESET}"
                echo ""

                local report_file="$HOME/video-catalog-report-$(date +%Y%m%d-%H%M%S).txt"
                {
                    echo "Video Catalog Report"
                    echo "Generated: $(date)"
                    echo ""
                    echo "=== CATALOGED DRIVES ==="
                    echo ""
                    cat "$CATALOG_DRIVES_DB" | jq -r '.drives[] | "Drive: \(.drive_label)\nType: \(.drive_type)\nStatus: \(.status)\nVideos: \(.total_videos)\nLast Seen: \(.last_seen)\n"'
                    echo ""
                    echo "=== VIDEO SUMMARY ==="
                    echo ""
                    echo "Total Videos: $(cat "$CATALOG_DB" | jq '.videos | length')"
                    echo ""
                    echo "By Studio:"
                    cat "$CATALOG_DB" | jq -r '.videos[].studio' | sort | uniq -c | sort -rn | head -20
                } > "$report_file"

                log_success "Report exported to: $report_file"
                read -p "Press Enter to continue..."
                ;;

            7)
                # Catalog settings
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Catalog Settings${COLOR_RESET}"
                echo ""
                echo -e "${COLOR_WHITE}Media Types to Catalog:${COLOR_RESET}"
                echo -e "  Videos: $([[ "$CATALOG_VIDEOS" == true ]] && echo "${COLOR_GREEN}ENABLED${COLOR_RESET}" || echo "${COLOR_RED}DISABLED${COLOR_RESET}")"
                echo -e "  Images: $([[ "$CATALOG_IMAGES" == true ]] && echo "${COLOR_GREEN}ENABLED${COLOR_RESET}" || echo "${COLOR_RED}DISABLED${COLOR_RESET}")"
                echo -e "  Audio:  $([[ "$CATALOG_AUDIO" == true ]] && echo "${COLOR_GREEN}ENABLED${COLOR_RESET}" || echo "${COLOR_RED}DISABLED${COLOR_RESET}")"
                echo ""
                echo -e "${COLOR_WHITE}Other Settings:${COLOR_RESET}"
                echo -e "  Include Metadata: $([[ "$CATALOG_INCLUDE_METADATA" == true ]] && echo "${COLOR_GREEN}YES${COLOR_RESET}" || echo "${COLOR_RED}NO${COLOR_RESET}")"
                echo -e "  Include Hash: $([[ "$CATALOG_INCLUDE_HASH" == true ]] && echo "${COLOR_GREEN}YES${COLOR_RESET}" || echo "${COLOR_RED}NO${COLOR_RESET}")"
                echo -e "  Offline Retention: ${COLOR_CYAN}$CATALOG_OFFLINE_RETENTION${COLOR_RESET} days"
                echo ""
                echo -e "${COLOR_WHITE}[1]${COLOR_RESET} Toggle Video Cataloging"
                echo -e "${COLOR_WHITE}[2]${COLOR_RESET} Toggle Image Cataloging"
                echo -e "${COLOR_WHITE}[3]${COLOR_RESET} Toggle Audio Cataloging"
                echo -e "${COLOR_WHITE}[4]${COLOR_RESET} Toggle Include Metadata"
                echo -e "${COLOR_WHITE}[5]${COLOR_RESET} Toggle Include Hash"
                echo -e "${COLOR_WHITE}[6]${COLOR_RESET} Set Offline Retention Days"
                echo ""
                echo -n "Select option (or Enter to skip): "
                read -r setting_choice

                case "$setting_choice" in
                    1)
                        CATALOG_VIDEOS=$([[ "$CATALOG_VIDEOS" == true ]] && echo "false" || echo "true")
                        log_success "Video cataloging: $CATALOG_VIDEOS"
                        ;;
                    2)
                        CATALOG_IMAGES=$([[ "$CATALOG_IMAGES" == true ]] && echo "false" || echo "true")
                        log_success "Image cataloging: $CATALOG_IMAGES"
                        ;;
                    3)
                        CATALOG_AUDIO=$([[ "$CATALOG_AUDIO" == true ]] && echo "false" || echo "true")
                        log_success "Audio cataloging: $CATALOG_AUDIO"
                        ;;
                    4)
                        if [[ "$CATALOG_INCLUDE_METADATA" == true ]]; then
                            CATALOG_INCLUDE_METADATA=false
                        else
                            CATALOG_INCLUDE_METADATA=true
                        fi
                        log_success "Metadata inclusion toggled"
                        ;;
                    5)
                        if [[ "$CATALOG_INCLUDE_HASH" == true ]]; then
                            CATALOG_INCLUDE_HASH=false
                        else
                            CATALOG_INCLUDE_HASH=true
                        fi
                        log_success "Hash inclusion toggled"
                        ;;
                    6)
                        read -p "Enter offline retention days (0=forever): " days
                        if [[ $days -ge 0 ]]; then
                            CATALOG_OFFLINE_RETENTION=$days
                            log_success "Offline retention set to: $days days"
                        fi
                        ;;
                esac
                read -p "Press Enter to continue..."
                ;;

            b|B)
                break
                ;;

            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac

        reset_statistics
    done
}

# Handle utilities
handle_utilities() {
    while true; do
        show_utilities_menu
        read -r choice
        
        case "$choice" in
            1)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Organize by Subfolder Names${COLOR_RESET}"
                echo ""
                echo "This feature will:"
                echo "  1. Scan a target folder for subfolders"
                echo "  2. Search for video files matching those subfolder names"
                echo "  3. Move matching files into their respective subfolders"
                echo "  4. Skip files in 'full' folders or already in place"
                echo ""
                echo -n "Enter target folder with subfolders (or . for current): "
                read -r target_folder
                target_folder="${target_folder:-.}"

                echo -n "Enter search path (or . for current, or enter for target): "
                read -r search_path
                search_path="${search_path:-$target_folder}"

                organize_by_subfolder_names "$target_folder" "$search_path"

                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                clear
                list_undo_operations
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                clear
                undo_organize_operation
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Last 50 Log Entries:${COLOR_RESET}"
                echo ""
                tail -n 50 "$LOG_FILE" 2>/dev/null || echo "No log entries found"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                if command -v xdg-open &> /dev/null; then
                    xdg-open "$LOG_DIR" 2>/dev/null
                elif command -v explorer.exe &> /dev/null; then
                    explorer.exe "$(wslpath -w "$LOG_DIR")" 2>/dev/null
                else
                    log_info "Log directory: $LOG_DIR"
                fi
                read -p "Press Enter to continue..."
                ;;
            6)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Test Filename Transformation:${COLOR_RESET}"
                echo ""
                echo -n "Enter filename to test: "
                read -r test_file

                echo ""
                echo -e "${COLOR_WHITE}Original:${COLOR_RESET} $test_file"

                local result=$(remove_dashes "$test_file")
                echo -e "${COLOR_WHITE}After dash removal:${COLOR_RESET} $result"

                result=$(apply_bracket_notation "$result")
                echo -e "${COLOR_WHITE}After bracket notation:${COLOR_RESET} $result"

                result=$(fix_bracket_spacing "$result")
                echo -e "${COLOR_WHITE}Final result:${COLOR_RESET} $result"

                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}System Information:${COLOR_RESET}"
                echo ""
                echo -e "${COLOR_BOLD}${COLOR_WHITE}Environment:${COLOR_RESET}"
                echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Script Version: ${COLOR_WHITE}$SCRIPT_VERSION${COLOR_RESET}"
                echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Platform: ${COLOR_WHITE}$OS_TYPE${COLOR_RESET}"
                echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Bash Version: ${COLOR_WHITE}$BASH_VERSION${COLOR_RESET}"
                echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} OS: ${COLOR_WHITE}$(uname -s)${COLOR_RESET}"
                echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Kernel: ${COLOR_WHITE}$(uname -r)${COLOR_RESET}"
                echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Hostname: ${COLOR_WHITE}$(hostname)${COLOR_RESET}"
                echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} User: ${COLOR_WHITE}$(whoami)${COLOR_RESET}"
                echo ""
                echo -e "${COLOR_BOLD}${COLOR_WHITE}Directories:${COLOR_RESET}"
                echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Working: ${COLOR_WHITE}$(pwd)${COLOR_RESET}"
                echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Logs: ${COLOR_WHITE}$LOG_DIR${COLOR_RESET}"
                echo ""
                echo -e "${COLOR_BOLD}${COLOR_WHITE}Available Tools:${COLOR_RESET}"
                command -v jq &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} jq" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} jq"
                command -v sha256sum &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} sha256sum" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} sha256sum"
                command -v shasum &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} shasum" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} shasum"
                command -v ffprobe &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} ffprobe" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} ffprobe"
                command -v exiftool &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} exiftool" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} exiftool"
                command -v identify &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} identify (ImageMagick)" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} identify (ImageMagick)"
                command -v whisper &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} whisper" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} whisper"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            b|B)
                break
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Handle organize settings
handle_organize_settings() {
    while true; do
        show_organize_settings_menu
        read -r choice

        case "$choice" in
            1)
                echo ""
                echo -n "Enter default target folder path: "
                read -r target_path
                if [[ -d "$target_path" ]]; then
                    ORGANIZE_DEFAULT_TARGET="$target_path"
                    log_success "Default target set to: $target_path"
                else
                    log_warning "Path does not exist, but setting anyway: $target_path"
                    ORGANIZE_DEFAULT_TARGET="$target_path"
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                echo ""
                echo -n "Enter default search path: "
                read -r search_path
                if [[ -d "$search_path" ]]; then
                    ORGANIZE_DEFAULT_SEARCH="$search_path"
                    log_success "Default search path set to: $search_path"
                else
                    log_warning "Path does not exist, but setting anyway: $search_path"
                    ORGANIZE_DEFAULT_SEARCH="$search_path"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                    ORGANIZE_SHOW_PROGRESS=false
                    log_success "Progress display DISABLED"
                else
                    ORGANIZE_SHOW_PROGRESS=true
                    log_success "Progress display ENABLED"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                if [[ "$ORGANIZE_LOG_OPERATIONS" == true ]]; then
                    ORGANIZE_LOG_OPERATIONS=false
                    log_success "Operation logging DISABLED (undo will not be available)"
                else
                    ORGANIZE_LOG_OPERATIONS=true
                    log_success "Operation logging ENABLED (allows undo)"
                fi
                read -p "Press Enter to continue..."
                ;;
            b|B)
                break
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Handle settings
handle_settings() {
    while true; do
        show_settings_menu
        read -r choice
        
        case "$choice" in
            1)
                if [[ "$DRY_RUN" == true ]]; then
                    DRY_RUN=false
                    log_success "Dry run mode DISABLED"
                else
                    DRY_RUN=true
                    log_success "Dry run mode ENABLED"
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                if [[ "$VERBOSE" == true ]]; then
                    VERBOSE=false
                    log_success "Verbose output DISABLED"
                else
                    VERBOSE=true
                    log_success "Verbose output ENABLED"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Supported Video Extensions:${COLOR_RESET}"
                echo ""
                for ext in "${DEFAULT_VIDEO_EXTENSIONS[@]}"; do
                    echo "  ${SYMBOL_BULLET} .$ext"
                done
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                handle_granular_controls
                ;;
            5)
                handle_organize_settings
                ;;
            6)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Save Configuration${COLOR_RESET}"
                echo ""
                read -p "Enter profile name (default): " profile_name
                profile_name=${profile_name:-default}
                save_config "$profile_name"
                read -p "Press Enter to continue..."
                ;;
            7)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Load Configuration${COLOR_RESET}"
                echo ""
                list_config_profiles
                read -p "Enter profile name to load (default): " profile_name
                profile_name=${profile_name:-default}
                load_config "$profile_name"
                read -p "Press Enter to continue..."
                ;;
            8)
                clear
                list_config_profiles
                read -p "Press Enter to continue..."
                ;;
            9)
                clear
                list_config_profiles
                echo ""
                read -p "Enter profile name to delete: " profile_name
                if [[ -n "$profile_name" ]]; then
                    read -p "Are you sure? (y/n): " -n 1 -r
                    echo ""
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        delete_config_profile "$profile_name"
                    fi
                fi
                read -p "Press Enter to continue..."
                ;;
            b|B)
                break
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Handle granular controls menu
handle_granular_controls() {
    while true; do
        show_granular_controls_menu
        read -r choice

        case "$choice" in
            1)
                INTERACTIVE_CONFIRM=$([[ "$INTERACTIVE_CONFIRM" == true ]] && echo "false" || echo "true")
                log_success "Per-file confirmation: $INTERACTIVE_CONFIRM"
                read -p "Press Enter to continue..."
                ;;
            2)
                SHOW_PREVIEW=$([[ "$SHOW_PREVIEW" == true ]] && echo "false" || echo "true")
                log_success "Preview mode: $SHOW_PREVIEW"
                read -p "Press Enter to continue..."
                ;;
            3)
                STEP_BY_STEP=$([[ "$STEP_BY_STEP" == true ]] && echo "false" || echo "true")
                log_success "Step-by-step mode: $STEP_BY_STEP"
                read -p "Press Enter to continue..."
                ;;
            4)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Configure Size Filter${COLOR_RESET}"
                echo ""
                read -p "Enable size filter? (y/n): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    FILTER_BY_SIZE=true
                    read -p "Minimum size in MB (0 for no minimum): " FILTER_MIN_SIZE_MB
                    read -p "Maximum size in MB (0 for no maximum): " FILTER_MAX_SIZE_MB
                    log_success "Size filter enabled: ${FILTER_MIN_SIZE_MB}MB - ${FILTER_MAX_SIZE_MB}MB"
                else
                    FILTER_BY_SIZE=false
                    log_success "Size filter disabled"
                fi
                read -p "Press Enter to continue..."
                ;;
            5)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Configure Date Filter${COLOR_RESET}"
                echo ""
                read -p "Enable date filter? (y/n): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    FILTER_BY_DATE=true
                    read -p "Process files older than N days: " FILTER_DAYS_OLD
                    log_success "Date filter enabled: ${FILTER_DAYS_OLD}+ days old"
                else
                    FILTER_BY_DATE=false
                    log_success "Date filter disabled"
                fi
                read -p "Press Enter to continue..."
                ;;
            6)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Configure Pattern Filter${COLOR_RESET}"
                echo ""
                read -p "Enable pattern filter? (y/n): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    FILTER_BY_PATTERN=true
                    read -p "Enter regex pattern: " FILTER_PATTERN
                    log_success "Pattern filter enabled: $FILTER_PATTERN"
                else
                    FILTER_BY_PATTERN=false
                    FILTER_PATTERN=""
                    log_success "Pattern filter disabled"
                fi
                read -p "Press Enter to continue..."
                ;;
            7)
                ENABLE_UNDO=$([[ "$ENABLE_UNDO" == true ]] && echo "false" || echo "true")
                log_success "Undo system: $ENABLE_UNDO"
                read -p "Press Enter to continue..."
                ;;
            8)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}Undo History${COLOR_RESET}"
                echo ""
                if [[ -f "$UNDO_HISTORY_FILE" ]]; then
                    local operations=$(jq -r '.operations[] | select(.undone == false) | "\(.timestamp) - \(.type): \(.original) -> \(.new)"' "$UNDO_HISTORY_FILE" 2>/dev/null)
                    if [[ -n "$operations" ]]; then
                        echo "$operations"
                    else
                        echo "No operations in history"
                    fi
                else
                    echo "No undo history file found"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
                clear
                undo_last_operation
                read -p "Press Enter to continue..."
                ;;
            b|B)
                break
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Main interactive menu loop
interactive_menu() {
    while true; do
        show_main_menu
        read -r choice

        case "$choice" in
            1)
                handle_single_operations  # File Operations
                ;;
            2)
                handle_subtitles
                ;;
            3)
                handle_duplicates
                ;;
            4)
                handle_catalog
                ;;
            5)
                handle_utilities
                ;;
            6)
                handle_settings
                ;;
            q|Q)
                echo ""
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid choice"
                sleep 1
                ;;
        esac
    done
}

################################################################################
# COMMAND LINE INTERFACE
################################################################################

show_usage() {
    cat << EOF
${COLOR_BOLD}$SCRIPT_NAME v$SCRIPT_VERSION${COLOR_RESET}

${COLOR_BOLD}USAGE:${COLOR_RESET}
    $0 [OPTIONS] [COMMAND] [DIRECTORY]

${COLOR_BOLD}OPTIONS:${COLOR_RESET}
    -h, --help              Show this help message
    -v, --version           Show version information
    -d, --dry-run           Enable dry run mode (no changes made)
    -q, --quiet             Disable verbose output
    -i, --interactive       Launch interactive menu (default if no command)

${COLOR_BOLD}SUBTITLE OPTIONS:${COLOR_RESET}
    --model <model>         Whisper model (tiny, base, small, medium, large)
    --format <format>       Subtitle format (srt, vtt, txt, json)
    --language <lang>       Language code (en, es, fr, etc.) or 'auto'

${COLOR_BOLD}ADVANCED SUBTITLE OPTIONS:${COLOR_RESET}
    --gpu                   Enable GPU acceleration (CUDA)
    --parallel <N>          Parallel jobs (1-8, default: 2)
    --no-optimize           Disable batch optimization
    --edit                  Enable interactive editing mode
    --speaker-diarization   Enable speaker identification
    --no-punctuation        Disable automatic punctuation fixes

${COLOR_BOLD}ORGANIZE OPTIONS:${COLOR_RESET}
    --organize-target <dir> Set default target folder for organize
    --organize-search <dir> Set default search path for organize

${COLOR_BOLD}COMMANDS:${COLOR_RESET}
    rename <dir>            Rename files with bracket notation
    flatten <dir>           Move all videos to top directory
    cleanup <dir>           Full cleanup (rename + spacing fixes)
    duplicates <dir>        Find duplicate files
    subtitles <dir>         Generate subtitles for videos
    workflow-new <dir>      New collection setup workflow
    workflow-clean <dir>    Deep clean workflow
    batch                   Batch process multiple folders
    --organize              Organize files by subfolder names
    --undo-organize [id]    Undo organize operation (optional: operation ID)
    --list-undo             List available undo operations

${COLOR_BOLD}EXAMPLES:${COLOR_RESET}
    # Interactive menu
    $0

    # Rename files in directory
    $0 rename /mnt/c/Users/Eric/Videos

    # Dry run before making changes
    $0 --dry-run rename /mnt/c/Users/Eric/Videos

    # Find duplicates
    $0 duplicates /mnt/c/Users/Eric/Videos

    # Generate subtitles (basic)
    $0 --model base subtitles /mnt/c/Users/Eric/Videos

    # Generate with GPU and parallel processing
    $0 --gpu --parallel 4 --model medium subtitles /mnt/c/Videos

    # Generate with speaker diarization
    $0 --speaker-diarization --model large subtitles /mnt/c/Videos

    # Full workflow for new collection
    $0 workflow-new /mnt/c/Users/Eric/Videos

    # Organize files by subfolder names
    $0 --organize-target /path/to/folders --organize-search /path/to/search --organize

    # Undo last organize operation
    $0 --undo-organize

    # List all available undo operations
    $0 --list-undo

${COLOR_BOLD}SUPPORTED VIDEO FORMATS:${COLOR_RESET}
    mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg, 3gp

${COLOR_BOLD}LOG FILES:${COLOR_RESET}
    Logs are stored in: $LOG_DIR

EOF
}

show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION ($SCRIPT_DATE)"
}

# Parse command line arguments
parse_arguments() {
    local command=""
    local directory=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                log_info "Dry run mode enabled"
                shift
                ;;
            -q|--quiet)
                VERBOSE=false
                shift
                ;;
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            --model)
                shift
                if [[ -n "$1" ]]; then
                    WHISPER_MODEL="$1"
                    log_info "Whisper model set to: $WHISPER_MODEL"
                    shift
                fi
                ;;
            --format)
                shift
                if [[ -n "$1" ]]; then
                    SUBTITLE_FORMAT="$1"
                    log_info "Subtitle format set to: $SUBTITLE_FORMAT"
                    shift
                fi
                ;;
            --language)
                shift
                if [[ -n "$1" ]]; then
                    SUBTITLE_LANGUAGE="$1"
                    log_info "Subtitle language set to: $SUBTITLE_LANGUAGE"
                    shift
                fi
                ;;
            --gpu)
                SUBTITLE_USE_GPU=true
                log_info "GPU acceleration enabled"
                shift
                ;;
            --parallel)
                shift
                if [[ -n "$1" && "$1" =~ ^[1-8]$ ]]; then
                    SUBTITLE_PARALLEL_JOBS="$1"
                    log_info "Parallel jobs set to: $SUBTITLE_PARALLEL_JOBS"
                    shift
                else
                    log_error "Invalid parallel jobs value. Must be 1-8"
                    exit 1
                fi
                ;;
            --no-optimize)
                SUBTITLE_OPTIMIZE_BATCH=false
                log_info "Batch optimization disabled"
                shift
                ;;
            --edit)
                SUBTITLE_INTERACTIVE_EDIT=true
                log_info "Interactive editing enabled"
                shift
                ;;
            --speaker-diarization)
                SUBTITLE_SPEAKER_DIARIZATION=true
                log_info "Speaker diarization enabled"
                shift
                ;;
            --no-punctuation)
                SUBTITLE_AUTO_PUNCTUATION=false
                log_info "Auto-punctuation disabled"
                shift
                ;;
            --organize)
                command="organize"
                shift
                ;;
            --organize-target)
                shift
                if [[ -n "$1" ]]; then
                    ORGANIZE_DEFAULT_TARGET="$1"
                    log_info "Organize target set to: $ORGANIZE_DEFAULT_TARGET"
                    shift
                fi
                ;;
            --organize-search)
                shift
                if [[ -n "$1" ]]; then
                    ORGANIZE_DEFAULT_SEARCH="$1"
                    log_info "Organize search path set to: $ORGANIZE_DEFAULT_SEARCH"
                    shift
                fi
                ;;
            --undo-organize)
                command="undo-organize"
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    # Operation ID provided
                    directory="$1"
                    shift
                fi
                ;;
            --list-undo)
                command="list-undo"
                shift
                ;;
            rename|flatten|cleanup|duplicates|subtitles|workflow-new|workflow-clean|batch)
                command="$1"
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    directory="$1"
                    shift
                fi
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # If no command specified, launch interactive menu
    if [[ -z "$command" ]]; then
        INTERACTIVE=true
        return 0
    fi

    # Validate directory for commands that need it
    if [[ "$command" != "batch" && "$command" != "list-undo" && "$command" != "undo-organize" && "$command" != "organize" ]]; then
        if [[ -z "$directory" ]]; then
            log_error "No directory specified for command: $command"
            show_usage
            exit 1
        fi

        directory=$(validate_directory "$directory")
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
    fi

    # Execute command
    INTERACTIVE=false
    case "$command" in
        rename)
            start_operation "Rename Files (Bracket Notation)"
            rename_files_in_directory "$directory" "$DRY_RUN"
            end_operation
            ;;
        flatten)
            start_operation "Flatten Directory"
            flatten_directory "$directory" "$DRY_RUN"
            end_operation
            ;;
        cleanup)
            workflow_deep_clean "$directory"
            ;;
        duplicates)
            start_operation "Find Duplicates"
            find_duplicates "$directory" "report"
            end_operation
            ;;
        subtitles)
            start_operation "Generate Subtitles"
            generate_subtitles_in_directory "$directory" "$WHISPER_MODEL" "$SUBTITLE_FORMAT" "$SUBTITLE_LANGUAGE" "$DRY_RUN"
            end_operation
            ;;
        workflow-new)
            workflow_new_collection "$directory"
            ;;
        workflow-clean)
            workflow_deep_clean "$directory"
            ;;
        batch)
            start_operation "Batch Processing"
            batch_process_folders
            end_operation
            ;;
        organize)
            organize_by_subfolder_names "$ORGANIZE_DEFAULT_TARGET" "$ORGANIZE_DEFAULT_SEARCH"
            ;;
        undo-organize)
            undo_organize_operation "$directory"
            ;;
        list-undo)
            list_undo_operations
            ;;
    esac
}

################################################################################
# MAIN EXECUTION
################################################################################

# Startup checks
startup_check() {
    local first_run=false

    # Check if this is first run (no log directory exists)
    if [[ ! -d "$LOG_DIR" ]]; then
        first_run=true
    fi

    # Show welcome banner on first run
    if [[ "$first_run" == true ]]; then
        clear
        echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╔═══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}           ${COLOR_BOLD}${COLOR_BRIGHT_YELLOW}WELCOME TO VIDEO MANAGER ULTIMATE${COLOR_RESET}            ${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╚═══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_WHITE}First-time setup detected!${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_CYAN}${SYMBOL_INFO}${COLOR_RESET} Platform detected: ${COLOR_BRIGHT_CYAN}$OS_TYPE${COLOR_RESET}"
        echo ""
    fi

    # Check dependencies
    check_dependencies

    # Show tip on first run
    if [[ "$first_run" == true ]]; then
        echo ""
        echo -e "${COLOR_YELLOW}${SYMBOL_STAR} Quick Tips:${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Try ${COLOR_WHITE}Dry Run${COLOR_RESET} mode first to preview changes"
        echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Check ${COLOR_WHITE}System Information${COLOR_RESET} in Utilities menu"
        echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} View ${COLOR_WHITE}CROSS-PLATFORM.md${COLOR_RESET} for setup help"
        echo ""
        read -p "Press Enter to continue..."
    fi
}

main() {
    # Run startup checks
    startup_check

    # Initialize logging
    init_logging

    # Parse arguments
    if [[ $# -eq 0 ]]; then
        INTERACTIVE=true
    else
        parse_arguments "$@"
    fi

    # Launch interactive menu if needed
    if [[ "$INTERACTIVE" == true ]]; then
        interactive_menu
    fi
}

# Run main function
main "$@"
