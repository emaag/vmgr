#!/usr/bin/env bash
#
# Video Manager Ultimate - Batch Processing Module
# Part of the modular video management system
#
# This module provides batch processing and workflow functionality for:
# - Batch operations across multiple directories
# - Pre-configured workflows (new collection, deep clean)
# - Multi-folder processing
# - Progress tracking across batches
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh, file-ops.sh
# Status: Phase 3 - Modularization
# Version: 1.2.0
#

################################################################################
# BATCH PROCESSING
################################################################################

# Per-folder outcome of the last batch_process_folders run, index-aligned:
# BATCH_RESULT_STATUS is ok | warn | fail, BATCH_RESULT_NOTE a short summary.
BATCH_RESULT_NAMES=()
BATCH_RESULT_STATUS=()
BATCH_RESULT_NOTE=()

# Snapshot the counters a batch cares about:
# "processed renamed moved dupes errors previewed"
_batch_snapshot() {
    printf '%s %s %s %s %s %s' "${STATS[files_processed]:-0}" "${STATS[files_renamed]:-0}" \
        "${STATS[files_moved]:-0}" "${STATS[duplicates_found]:-0}" "${STATS[errors]:-0}" \
        "${STATS[files_previewed]:-0}"
}

# Describe what changed between two snapshots ($1 before, $2 after).
# Sets _BATCH_NOTE and _BATCH_ERRORS.
_batch_describe() {
    local -a b a
    read -r -a b <<< "$1"; read -r -a a <<< "$2"
    local checked=$(( a[0] - b[0] )) renamed=$(( a[1] - b[1] )) moved=$(( a[2] - b[2] ))
    local dupes=$(( a[3] - b[3] )) errors=$(( a[4] - b[4] )) previewed=$(( a[5] - b[5] ))
    local -a parts=()
    (( previewed > 0 )) && parts+=("$previewed would be renamed")
    (( renamed > 0 )) && parts+=("$renamed renamed")
    (( moved > 0 ))   && parts+=("$moved moved")
    (( dupes > 0 ))   && parts+=("$dupes duplicates")
    (( errors > 0 ))  && parts+=("$errors error(s)")
    if (( ${#parts[@]} == 0 )); then
        _BATCH_NOTE="$checked checked, no changes"
    else
        local IFS=,; _BATCH_NOTE="${parts[*]}"; _BATCH_NOTE="${_BATCH_NOTE//,/, }"
    fi
    _BATCH_ERRORS=$errors
}

# Batch process multiple folders
batch_process_folders() {
    local operation="$1"
    shift
    local folders=("$@")

    if [[ ${#folders[@]} -eq 0 ]]; then
        log_error "No folders specified for batch processing"
        return 1
    fi

    local themed=false
    [[ "$(type -t ui_file_header)" == "function" ]] && themed=true

    $themed || log_info "Starting batch ${operation} on ${#folders[@]} folders"

    local total_folders=${#folders[@]}
    local processed=0
    local success=0
    local failed=0
    BATCH_RESULT_NAMES=(); BATCH_RESULT_STATUS=(); BATCH_RESULT_NOTE=()

    local folder before after rc status
    for folder in "${folders[@]}"; do
        ((processed++))
        BATCH_RESULT_NAMES+=("$(basename "$folder")")

        if [[ ! -d "$folder" ]]; then
            log_warning "Skipping non-existent folder: $folder"
            ((failed++))
            BATCH_RESULT_STATUS+=(fail); BATCH_RESULT_NOTE+=("folder not found")
            continue
        fi

        if $themed; then
            local short; _ui_short_path "$folder" 50 short
            ui_file_header "$(basename "$folder")" "$processed" "$total_folders" "" "$short"
        else
            echo ""
            log_info "Processing folder [$processed/$total_folders]: $folder"
        fi

        before="$(_batch_snapshot)"
        rc=0

        # Execute operation based on type
        case "$operation" in
            "rename")     rename_files_in_directory "$folder" "$DRY_RUN" || rc=1 ;;
            "flatten")    flatten_directory "$folder" "$DRY_RUN" || rc=1 ;;
            "cleanup")    workflow_deep_clean "$folder" || rc=1 ;;
            "duplicates") find_duplicates "$folder" "report" || rc=1 ;;
            *)
                log_error "Unknown operation: $operation"
                rc=1
                ;;
        esac

        after="$(_batch_snapshot)"
        _batch_describe "$before" "$after"
        status=ok
        (( _BATCH_ERRORS > 0 )) && status=warn
        if (( rc != 0 )); then status=fail; ((failed++)); else ((success++)); fi
        BATCH_RESULT_STATUS+=("$status"); BATCH_RESULT_NOTE+=("$_BATCH_NOTE")
    done

    if $themed; then
        _batch_print_results
    else
        echo ""
        log_success "Batch processing complete"
        log_info "  Processed: $processed"
        log_info "  Successful: $success"
        [[ $failed -gt 0 ]] && log_warning "  Failed: $failed"
    fi
    [[ $failed -eq 0 ]]
}

# Print one line per folder from the last run.
_batch_print_results() {
    local i mark color n=${#BATCH_RESULT_NAMES[@]}
    echo ""
    ui_section "Results"
    for (( i = 0; i < n; i++ )); do
        case "${BATCH_RESULT_STATUS[$i]}" in
            ok)   mark="$SYMBOL_CHECK"; color="$UI_OK" ;;
            warn) mark="$SYMBOL_WARN";  color="$UI_WARN" ;;
            *)    mark="$SYMBOL_CROSS"; color="$UI_ERR" ;;
        esac
        printf '  %s%s%s %-28.28s %s%s%s\n' "$color" "$mark" "$COLOR_RESET" \
            "${BATCH_RESULT_NAMES[$i]}" "$UI_DIM" "${BATCH_RESULT_NOTE[$i]}" "$COLOR_RESET"
    done
}

################################################################################
# BATCH WRAPPERS (for interactive menu)
################################################################################

BATCH_FOLDERS=()
declare -gA BATCH_VIDEO_COUNTS=()

# Add directory $1 to the queue unless it is already there. Returns 1 if added.
_batch_add_folder() {
    local dir="$1" f
    for f in "${BATCH_FOLDERS[@]}"; do [[ "$f" == "$dir" ]] && return 1; done
    BATCH_FOLDERS+=("$dir")
    BATCH_VIDEO_COUNTS[$dir]="$(browser_count_videos "$dir")"
    return 0
}

# Draw the folder queue screen.
_batch_draw_queue() {
    local title="$1" msg="$2" i n=${#BATCH_FOLDERS[@]} total=0 short shown=12
    if [[ "$(type -t show_screen)" == "function" ]]; then show_screen "$title"; else clear; fi

    ui_section "Folders to process (${n})"
    if (( n == 0 )); then
        printf '  %s(none yet)%s\n' "$UI_DIM" "$COLOR_RESET"
    fi
    for (( i = 0; i < n && i < shown; i++ )); do
        _ui_short_path "${BATCH_FOLDERS[$i]}" 44 short
        _browser_pad "$short" 44 short
        printf '  %s%2d%s  %s %s%s video(s)%s\n' "$UI_ACCENT" $(( i + 1 )) "$COLOR_RESET" \
            "$short" "$UI_DIM" "${BATCH_VIDEO_COUNTS[${BATCH_FOLDERS[$i]}]:-0}" "$COLOR_RESET"
    done
    (( n > shown )) && printf '  %s… and %d more%s\n' "$UI_DIM" $(( n - shown )) "$COLOR_RESET"
    for (( i = 0; i < n; i++ )); do total=$(( total + ${BATCH_VIDEO_COUNTS[${BATCH_FOLDERS[$i]}]:-0} )); done
    (( n > 0 )) && printf '\n  %s%d folder(s), %d video(s) in total%s\n' "$UI_DIM" "$n" "$total" "$COLOR_RESET"

    echo ""
    local UI_HINT_INDENT="  "
    ui_hint_line "A" "add a folder" "S" "add every subfolder with videos" "T" "type a path"
    ui_hint_line "X" "remove one" "C" "clear" "Enter" "run" "Q" "cancel"
    [[ -n "$msg" ]] && printf '\n  %s%s%s\n' "$UI_WARN" "$msg" "$COLOR_RESET"
}

# Build the queue interactively into BATCH_FOLDERS. Returns 0 to run, 1 to cancel.
_batch_pick_folders() {
    local title="$1" key msg="" picked added sub n saved_target="${TARGET_FOLDER:-}" start="${TARGET_FOLDER:-}"
    BATCH_FOLDERS=(); BATCH_VIDEO_COUNTS=()

    while true; do
        _batch_draw_queue "$title" "$msg"; msg=""
        _browser_read_key key || { TARGET_FOLDER="$saved_target"; return 1; }
        case "$key" in
            a|A)
                if browse_directory "$start"; then
                    picked="$TARGET_FOLDER"; start="$picked"
                    _ui_short_path "$picked" 50 sub
                    _batch_add_folder "$picked" && msg="Added $sub" || msg="Already in the list"
                fi
                TARGET_FOLDER="$saved_target"
                ;;
            s|S)
                if browse_directory "$start"; then
                    picked="$TARGET_FOLDER"; start="$picked"; added=0
                    while IFS= read -r sub; do
                        [[ -z "$sub" ]] && continue
                        [[ "$(browser_count_videos "$picked/$sub")" -gt 0 ]] || continue
                        _batch_add_folder "$picked/$sub" && ((added++))
                    done < <(browser_list_subdirs "$picked" 0)
                    _ui_short_path "$picked" 40 sub
                    msg="Added $added subfolder(s) of $sub"
                    (( added == 0 )) && msg="No subfolders with videos in $sub"
                fi
                TARGET_FOLDER="$saved_target"
                ;;
            t|T)
                printf '\n'
                ui_ask picked "Path"
                picked="${picked/#\~/$HOME}"
                if [[ -n "$picked" ]]; then
                    if added="$(validate_directory "$picked" 2>/dev/null)"; then
                        _batch_add_folder "$added" && msg="Added $added" || msg="Already in the list"
                    else
                        msg="Directory not found: $picked"
                    fi
                fi
                ;;
            x|X)
                if (( ${#BATCH_FOLDERS[@]} > 0 )); then
                    printf '\n'
                    ui_ask n "Remove which number"
                    if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#BATCH_FOLDERS[@]} )); then
                        msg="Removed ${BATCH_FOLDERS[$(( n - 1 ))]}"
                        unset 'BATCH_FOLDERS[n-1]'
                        BATCH_FOLDERS=("${BATCH_FOLDERS[@]}")
                    else
                        msg="Not a number in the list"
                    fi
                fi
                ;;
            c|C) BATCH_FOLDERS=(); BATCH_VIDEO_COUNTS=(); msg="Cleared" ;;
            ENTER|r|R)
                if (( ${#BATCH_FOLDERS[@]} > 0 )); then
                    TARGET_FOLDER="$saved_target"
                    return 0
                fi
                msg="Add at least one folder first"
                ;;
            q|Q|ESC) TARGET_FOLDER="$saved_target"; return 1 ;;
        esac
    done
}

# Plain line-by-line entry, for pipes and other non-terminals.
_batch_read_lines() {
    echo ""
    echo "Enter directories (one per line, empty line to finish):"
    echo ""
    BATCH_FOLDERS=()
    local dir
    while true; do
        read -r -p "Directory: " dir || break
        [[ -z "$dir" ]] && break
        dir=$(validate_directory "$dir") && BATCH_FOLDERS+=("$dir")
    done
}

# Gather folders, confirm, run (preview first when dry run is on), and report.
# Returns 2 when the user backs out (nothing ran, nothing to report), 1 on a
# problem, 0 otherwise.
# Args: $1 - operation (rename|flatten|cleanup|duplicates), $2 - title
_batch_interactive() {
    local operation="$1"
    local title="$2"
    local interactive=false
    [[ -t 0 && -t 1 && "$(type -t ui_confirm)" == "function" ]] && interactive=true

    if $interactive; then
        _batch_pick_folders "$title" || return 2
    else
        log_info "$title"
        _batch_read_lines
    fi

    if [[ ${#BATCH_FOLDERS[@]} -eq 0 ]]; then
        log_warning "No directories specified"
        return 1
    fi

    local -a folders=("${BATCH_FOLDERS[@]}")

    if ! $interactive; then
        start_operation "$title"
        batch_process_folders "$operation" "${folders[@]}"
        end_operation
        return
    fi

    local total=0 f
    for f in "${folders[@]}"; do total=$(( total + ${BATCH_VIDEO_COUNTS[$f]:-0} )); done

    # Report-only operations never change files, so there is nothing to confirm
    if [[ "$operation" == "duplicates" ]]; then
        start_operation "$title"
        batch_process_folders "$operation" "${folders[@]}"
        end_operation
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        start_operation "$title (Preview)"
        batch_process_folders "$operation" "${folders[@]}"
        end_operation
        if ui_confirm "Apply these changes to ${#folders[@]} folder(s)?"; then
            local DRY_RUN=false
            start_operation "$title (Apply)"
            batch_process_folders "$operation" "${folders[@]}"
            end_operation
        fi
    else
        if ui_confirm "Run on ${#folders[@]} folder(s), ${total} video(s)? This changes files"; then
            start_operation "$title"
            batch_process_folders "$operation" "${folders[@]}"
            end_operation
        else
            return 2
        fi
    fi
}

batch_rename_interactive()  { _batch_interactive "rename"  "Batch Rename Multiple Folders"; }
batch_flatten_interactive() { _batch_interactive "flatten" "Batch Flatten Multiple Folders"; }
batch_cleanup_interactive() { _batch_interactive "cleanup" "Batch Full Cleanup (Multiple Folders)"; }
batch_duplicates_interactive() { _batch_interactive "duplicates" "Batch Find Duplicates (Multiple Folders)"; }

################################################################################
# WORKFLOWS
################################################################################

# Workflow: New Collection Setup
workflow_new_collection() {
    local directory="$1"

    log_info "Starting New Collection Workflow"
    log_info "This will: flatten → rename → deduplicate"

    echo ""
    flatten_directory "$directory" "$DRY_RUN"
    echo ""
    rename_files_in_directory "$directory" "$DRY_RUN"
    echo ""
    find_duplicates "$directory" "report"

    log_success "New Collection Workflow complete"
}

# Workflow: Deep Clean
workflow_deep_clean() {
    local directory="$1"

    log_info "Starting Deep Clean Workflow"
    log_info "This will: rename → deduplicate"

    echo ""
    rename_files_in_directory "$directory" "$DRY_RUN"
    echo ""
    find_duplicates "$directory" "report"

    log_success "Deep Clean Workflow complete"
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
