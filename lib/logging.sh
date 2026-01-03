#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - LOGGING MODULE
#
# This module handles all logging, progress display, and output functions
#
# Dependencies: core.sh
# Module: logging.sh
# Version: 1.2.0
# Date: November 8, 2025
#
################################################################################

# Initialize logging system
# Creates log directory and sets up log rotation
# Returns: 0 on success
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
# Args: $1 - log level, $2+ - message
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
}

# Verbose console output with logging
# Args: $* - message
# Note: Output goes to stderr to avoid polluting stdout (used for return values)
log_verbose() {
    local message="$*"
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${COLOR_CYAN}${SYMBOL_INFO}${COLOR_RESET} $message" >&2
    fi
    log_message "INFO" "$message"
}

# Success message
# Args: $* - message
log_success() {
    local message="$*"
    echo -e "${COLOR_BRIGHT_GREEN}${SYMBOL_CHECK}${COLOR_RESET} $message" >&2
    log_message "SUCCESS" "$message"
}

# Error message
# Args: $* - message
log_error() {
    local message="$*"
    echo -e "${COLOR_BRIGHT_RED}${SYMBOL_CROSS}${COLOR_RESET} $message" >&2
    log_message "ERROR" "$message"
    ((STATS[errors]++))
}

# Warning message
# Args: $* - message
log_warning() {
    local message="$*"
    echo -e "${COLOR_BRIGHT_YELLOW}${SYMBOL_WARN}${COLOR_RESET} $message" >&2
    log_message "WARN" "$message"
}

# Info message
# Args: $* - message
log_info() {
    local message="$*"
    echo -e "${COLOR_BRIGHT_CYAN}${SYMBOL_INFO}${COLOR_RESET} $message" >&2
    log_message "INFO" "$message"
}

# Operation start banner
# Args: $1 - operation name
# Sets CURRENT_OPERATION and START_TIME globals
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
# Displays operation summary and duration
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
# Args: $1 - current count, $2 - total count, $3 - message (optional)
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
# Args: $1 - PID to monitor, $2 - message (optional)
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

# Draw simple progress bar
# Args: $1 - current count, $2 - total count
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

# Print statistics summary
# Displays current STATS array values
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

# Module loaded successfully
return 0
