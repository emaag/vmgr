#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - PLATFORM MODULE
#
# This module handles platform detection and compatibility functions
# Cross-platform support for Linux, macOS, Windows/WSL
#
# Dependencies: core.sh, logging.sh
# Module: platform.sh
# Version: 1.2.0
# Date: November 8, 2025
#
################################################################################

# Detect operating system
# Sets OS_TYPE global variable
# Returns: 0 on success
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
# Args: $1 - file path
# Returns: file size in bytes, or 0 if file doesn't exist
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
# Args: $1 - file path
# Returns: SHA-256 hash of file
calculate_file_hash() {
    local file="$1"

    # Validate input
    if [[ -z "$file" ]]; then
        [[ "$(type -t log_error)" == "function" ]] && log_error "calculate_file_hash: file parameter is required"
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        [[ "$(type -t log_error)" == "function" ]] && log_error "calculate_file_hash: file does not exist: $file"
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
# Args: $1 - number of bytes
# Returns: formatted byte string (e.g., "1.5GiB")
format_bytes() {
    local bytes="$1"

    # Validate input
    if [[ -z "$bytes" ]]; then
        echo "0B"
        return 0
    fi

    # Ensure bytes is a number
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        [[ "$(type -t log_error)" == "function" ]] && log_error "format_bytes: invalid number: $bytes"
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
# Args: $1 - file or directory path
# Opens file/directory in native file manager
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

# Convert Windows path to WSL path
# Args: $1 - path (Windows or Unix format)
# Returns: Unix-formatted path
convert_to_wsl_path() {
    local path="$1"

    # Validate input
    if [[ -z "$path" ]]; then
        [[ "$(type -t log_error)" == "function" ]] && log_error "convert_to_wsl_path: path parameter is required"
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

# Check for required commands and suggest installation
# Checks for jq, ffprobe, exiftool, etc.
# Returns: 0 if all dependencies met, exits if user declines to continue without deps
check_dependencies() {
    local missing_deps=()

    # Core dependencies
    if ! command -v jq &>/dev/null; then
        missing_deps+=("jq")
    fi

    # Optional but recommended
    if ! command -v ffprobe &>/dev/null; then
        [[ "$(type -t log_warning)" == "function" ]] && log_warning "ffprobe not found - video metadata extraction will be limited"
    fi

    if ! command -v exiftool &>/dev/null && ! command -v identify &>/dev/null; then
        [[ "$(type -t log_warning)" == "function" ]] && log_warning "exiftool or ImageMagick not found - EXIF extraction will be limited"
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

# Initialize platform detection on module load
detect_os

# Module loaded successfully
return 0
