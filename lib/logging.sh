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
    local -a log_files
    mapfile -t log_files < <(find "$LOG_DIR" -name "video-manager-*.log" -type f 2>/dev/null | sort)
    local log_count=${#log_files[@]}
    if [[ $log_count -gt 50 ]]; then
        log_verbose "Rotating old log files (found $log_count logs)..."
        local excess=$(( log_count - 50 ))
        local i
        for ((i=0; i<excess; i++)); do
            rm -f "${log_files[$i]}" 2>/dev/null
        done
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

# Wipe a live ui_progress line before printing, so messages do not land on it.
_clear_progress_line() {
    [[ "${UI_PROGRESS_ACTIVE:-0}" == 1 ]] && ui_progress_clear
    return 0
}

# Verbose console output with logging
# Args: $* - message
# Note: Output goes to stderr to avoid polluting stdout (used for return values)
log_verbose() {
    local message="$*"
    if [[ "$VERBOSE" == true ]]; then
        _clear_progress_line
        echo -e "${COLOR_CYAN}${SYMBOL_INFO}${COLOR_RESET} $message" >&2
    fi
    log_message "INFO" "$message"
}

# Success message
# Args: $* - message
log_success() {
    local message="$*"
    _clear_progress_line
    echo -e "${COLOR_BRIGHT_GREEN}${SYMBOL_CHECK}${COLOR_RESET} $message" >&2
    log_message "SUCCESS" "$message"
}

# Error message
# Args: $* - message
log_error() {
    local message="$*"
    _clear_progress_line
    echo -e "${COLOR_BRIGHT_RED}${SYMBOL_CROSS}${COLOR_RESET} $message" >&2
    log_message "ERROR" "$message"
    ((STATS[errors]++))
}

# Warning message
# Args: $* - message
log_warning() {
    local message="$*"
    _clear_progress_line
    echo -e "${COLOR_BRIGHT_YELLOW}${SYMBOL_WARN}${COLOR_RESET} $message" >&2
    log_message "WARN" "$message"
}

# Info message
# Args: $* - message
log_info() {
    local message="$*"
    _clear_progress_line
    echo -e "${COLOR_BRIGHT_CYAN}${SYMBOL_INFO}${COLOR_RESET} $message" >&2
    log_message "INFO" "$message"
}

# Operation start banner
# Args: $1 - operation name
# Sets CURRENT_OPERATION and START_TIME globals
start_operation() {
    CURRENT_OPERATION="$1"
    START_TIME=$(date +%s)
    # Each operation reports its own numbers, not a running total, and its own undo log
    [[ "$(type -t reset_statistics)" == "function" ]] && reset_statistics
    UNDO_CURRENT_LOG=""

    if [[ "$(type -t ui_operation_start)" == "function" ]]; then
        ui_operation_start "$CURRENT_OPERATION"
    else
        echo ""
        echo -e "${COLOR_BRIGHT_MAGENTA}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
        echo -e "${COLOR_BRIGHT_MAGENTA}${SYMBOL_STAR} ${COLOR_BOLD}$CURRENT_OPERATION${COLOR_RESET}"
        echo -e "${COLOR_BRIGHT_MAGENTA}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
        echo ""
    fi

    log_message "OPERATION" "Started: $CURRENT_OPERATION"
}

# Operation end banner with statistics
# Displays operation summary and duration
end_operation() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    if [[ "$(type -t ui_summary_card)" == "function" ]]; then
        echo ""
        _print_summary_card "${minutes}m ${seconds}s"
        echo ""
    else
        echo ""
        echo -e "${COLOR_BRIGHT_MAGENTA}───────────────────────────────────────────────────────────────${COLOR_RESET}"
        echo -e "${COLOR_BOLD}Operation Complete: $CURRENT_OPERATION${COLOR_RESET}"
        echo -e "${COLOR_BRIGHT_MAGENTA}───────────────────────────────────────────────────────────────${COLOR_RESET}"

        print_statistics

        echo ""
        echo -e "${COLOR_CYAN}Duration: ${minutes}m ${seconds}s${COLOR_RESET}"
        echo -e "${COLOR_BRIGHT_MAGENTA}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
        echo ""
    fi

    local undo_n
    undo_n="$(undo_recorded_count)"
    if (( undo_n > 0 )); then
        printf '  %s%s%s\n\n' "${UI_DIM:-$COLOR_CYAN}" \
            "Undo: ${undo_n} change(s) recorded. Utilities > Undo Last Operation puts them back." "$COLOR_RESET"
    fi

    log_message "OPERATION" "Completed: $CURRENT_OPERATION (Duration: ${minutes}m ${seconds}s)"
}

# Build the themed end-of-operation card from the non-zero counters in STATS.
# Args: $1 - duration text
_print_summary_card() {
    local -a rows=()
    [[ ${STATS[files_processed]:-0}       -gt 0 ]] && rows+=("Files processed" "${STATS[files_processed]}")
    [[ ${STATS[files_renamed]:-0}         -gt 0 ]] && rows+=("Files renamed" "${STATS[files_renamed]}")
    [[ ${STATS[files_previewed]:-0}       -gt 0 ]] && rows+=("Would change" "${STATS[files_previewed]}")
    [[ ${STATS[files_moved]:-0}           -gt 0 ]] && rows+=("Files moved" "${STATS[files_moved]}")
    [[ ${STATS[files_restored]:-0}        -gt 0 ]] && rows+=("Files restored" "${STATS[files_restored]}")
    [[ ${STATS[files_skipped]:-0}         -gt 0 ]] && rows+=("Files skipped" "${STATS[files_skipped]}")
    [[ ${STATS[subtitles_generated]:-0}   -gt 0 ]] && rows+=("Subtitles generated" "${STATS[subtitles_generated]}")
    [[ ${STATS[subtitles_translated]:-0}  -gt 0 ]] && rows+=("Subtitles translated" "${STATS[subtitles_translated]}")
    [[ ${STATS[subtitles_no_speech]:-0}   -gt 0 ]] && rows+=("No speech found" "${STATS[subtitles_no_speech]}")
    [[ ${STATS[low_confidence_count]:-0}  -gt 0 ]] && rows+=("Low confidence" "${STATS[low_confidence_count]}")
    [[ ${STATS[subtitles_failed]:-0}      -gt 0 ]] && rows+=("Subtitles failed" "${STATS[subtitles_failed]}")
    [[ ${STATS[duplicates_found]:-0}      -gt 0 ]] && rows+=("Duplicates found" "${STATS[duplicates_found]}")
    [[ ${STATS[space_saved]:-0}           -gt 0 ]] && rows+=("Space saved" "$(format_bytes "${STATS[space_saved]}")")
    [[ ${STATS[errors]:-0}                -gt 0 ]] && rows+=("Errors" "${STATS[errors]}")
    ui_summary_card "$CURRENT_OPERATION" "$1" "${STATS[errors]:-0}" "${rows[@]}"
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

    if [[ "$(type -t ui_progress)" == "function" ]]; then
        ui_progress "$current" "$total" "$message"
        [[ $current -eq $total && -t 1 ]] && echo ""
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


# Print statistics summary — only shows counters that are non-zero
print_statistics() {
    local _any=0
    for k in files_processed files_renamed files_moved files_skipped \
              subtitles_generated subtitles_failed duplicates_found errors; do
        [[ ${STATS[$k]:-0} -gt 0 ]] && _any=1 && break
    done
    [[ $_any -eq 0 ]] && return

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}Statistics:${COLOR_RESET}"
    [[ ${STATS[files_processed]:-0} -gt 0 ]] && echo -e "   ${COLOR_WHITE}Files Processed:${COLOR_RESET}  ${COLOR_BRIGHT_CYAN}${STATS[files_processed]}${COLOR_RESET}"
    [[ ${STATS[files_renamed]:-0}   -gt 0 ]] && echo -e "   ${COLOR_WHITE}Files Renamed:${COLOR_RESET}    ${COLOR_BRIGHT_GREEN}${STATS[files_renamed]}${COLOR_RESET}"
    [[ ${STATS[files_moved]:-0}     -gt 0 ]] && echo -e "   ${COLOR_WHITE}Files Moved:${COLOR_RESET}      ${COLOR_BRIGHT_GREEN}${STATS[files_moved]}${COLOR_RESET}"
    [[ ${STATS[files_skipped]:-0}   -gt 0 ]] && echo -e "   ${COLOR_WHITE}Files Skipped:${COLOR_RESET}    ${COLOR_BRIGHT_YELLOW}${STATS[files_skipped]}${COLOR_RESET}"

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
