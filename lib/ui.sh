#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - UI MODULE
#
# This module contains all interactive menu displays and handler functions.
# It provides the complete user interface for the video manager.
#
# Author: Created for Eric's Video Management System
# Module: ui.sh
# Version: 1.2.0
# Date: 2025-12-23
#
# Dependencies: ALL modules (core, platform, logging, config, utils,
#               file-ops, duplicates, organize, subtitles, catalog, batch)
#
################################################################################

# Framed header: product name and version, then a status strip with the dry-run
# state and the folder currently selected.
show_header() {
    clear
    _ui_measure

    local dry_plain dry_styled folder folder_styled
    if [[ "$DRY_RUN" == true ]]; then
        dry_plain="${UI_DOT_ON} Dry run ON"
        dry_styled="${UI_WARN}${UI_DOT_ON} Dry run ON${COLOR_RESET}"
    else
        dry_plain="${UI_DOT_OFF} Dry run OFF"
        dry_styled="${UI_DIM}${UI_DOT_OFF} Dry run OFF${COLOR_RESET}"
    fi

    if [[ -n "${TARGET_FOLDER:-}" ]]; then
        _ui_short_path "$TARGET_FOLDER" $(( UI_W - 6 - ${#dry_plain} )) folder
        folder_styled="${COLOR_WHITE}${folder}${COLOR_RESET}"
    else
        folder="no folder selected"
        folder_styled="${UI_DIM}${folder}${COLOR_RESET}"
    fi

    ui_box_top
    ui_box_row "VIDEO MANAGER ULTIMATE" "${UI_TITLE}VIDEO MANAGER ULTIMATE${COLOR_RESET}" \
               "v${SCRIPT_VERSION}" "${UI_DIM}v${SCRIPT_VERSION}${COLOR_RESET}"
    ui_box_row "$dry_plain" "$dry_styled" "$folder" "$folder_styled"
    ui_box_bottom
    echo ""
}

# Sub-screen: cleared screen, framed header, then the screen title.
show_screen() {
    show_header
    ui_title "${1^^}"
}

show_main_menu() {
    show_header

    ui_title "MAIN MENU"
    ui_item 1 "File Operations"      "Rename, organize, flatten"
    ui_item 2 "Subtitle Generation"  "Generate, edit, translate"
    ui_item 3 "Duplicate Detection"  "Find and remove duplicates"
    ui_item 4 "Multi-Drive Catalog"  "Scan drives, search media"
    ui_item 5 "Utilities"            "Logs, system info, testing"
    ui_item 6 "Settings"             "Options and preferences"
    ui_item 7 "Reddit Downloader"    "Images from a subreddit"
    echo ""
    ui_item Q "Quit" "" back
    ui_prompt "Choose"
}

show_single_operations_menu() {
    show_header

    ui_title "FILE OPERATIONS"
    ui_item 1 "Rename Files" "Bracket Notation"
    ui_item 2 "Remove Dashes"
    ui_item 3 "Fix Bracket Spacing"
    ui_item 4 "Flatten Directory" "Move All to Top"
    ui_item 5 "Full Cleanup" "All Operations"
    ui_item 6 "Image Operations" "Convert to JPG ${SYMBOL_ARROW}"
    echo ""
    ui_section "More"
    ui_item 7 "Batch Processing" "Several folders at once ${SYMBOL_ARROW}"
    ui_item 8 "Automated Workflows" "Clean up a collection ${SYMBOL_ARROW}"
    echo ""
    ui_item_toggle D "Toggle Dry Run" "$DRY_RUN"
    echo ""
    ui_item B "Back to Main Menu" "" back
    ui_prompt
}

show_image_ops_menu() {
    show_header

    ui_title "IMAGE OPERATIONS"
    ui_item 1 "Convert JPEG to JPG" "Rename Only"
    ui_item 2 "Convert PNG to JPG"
    ui_item 3 "Convert WebP to JPG"
    ui_item 4 "Convert HEIC to JPG"
    ui_item 5 "Convert All to JPG" "All Formats"
    echo ""
    ui_item_toggle R "Toggle Recursive" "$IMAGE_RECURSIVE"
    ui_item_toggle D "Toggle Dry Run" "$DRY_RUN"
    echo ""
    ui_item B "Back" "" back
    ui_prompt
}

show_batch_menu() {
    show_header

    ui_title "BATCH PROCESSING"
    ui_item 1 "Batch Rename" "Multiple Folders"
    ui_item 2 "Batch Flatten" "Multiple Folders"
    ui_item 3 "Batch Full Cleanup"
    ui_item 4 "Batch Find Duplicates" "Report only, per folder"
    echo ""
    ui_item B "Back to Main Menu" "" back
    ui_prompt
}

show_workflow_menu() {
    show_header

    ui_title "AUTOMATED WORKFLOWS"
    ui_item 1 "New Collection Setup" "Flatten + Rename + Find Duplicates"
    ui_item 2 "Deep Clean Existing Collection" "Remove Dashes + Fix Spacing + Bracket Notation"
    echo ""
    ui_item B "Back to Main Menu" "" back
    ui_prompt
}

show_duplicate_menu() {
    show_header

    ui_title "DUPLICATE DETECTION"
    ui_item 1 "Find Duplicates" "Report Only"
    ui_item 2 "Find and Delete Duplicates"
    ui_item 3 "Find Duplicates" "Dry Run"
    echo ""
    ui_item B "Back to Main Menu" "" back
    ui_prompt
}

show_subtitle_menu() {
    show_header

    ui_title "SUBTITLE GENERATION"
    ui_section "Current Settings"
    ui_kv "Model" "$WHISPER_MODEL"
    ui_kv "Format" "$SUBTITLE_FORMAT"
    ui_kv "Language" "$SUBTITLE_LANGUAGE"
    ui_kv "Parallel Jobs" "$SUBTITLE_PARALLEL_JOBS"
    print_toggle_setting "GPU Acceleration" "$SUBTITLE_USE_GPU"
    print_toggle_setting "Batch Optimization" "$SUBTITLE_OPTIMIZE_BATCH"
    print_toggle_setting "Recursive Scan" "$SUBTITLE_RECURSIVE"

    # Count active filters
    local active_filters=0
    [[ $SUBTITLE_MIN_SIZE_MB -gt 0 ]] && ((active_filters++))
    [[ $SUBTITLE_MAX_SIZE_MB -gt 0 ]] && ((active_filters++))
    [[ $SUBTITLE_MODIFIED_DAYS -gt 0 ]] && ((active_filters++))
    [[ "$SUBTITLE_SKIP_EXISTING" == true ]] && ((active_filters++))
    [[ "$SUBTITLE_INTERACTIVE_SELECT" == true ]] && ((active_filters++))

    if [[ $active_filters -gt 0 ]]; then
        ui_kv "Active Filters" "$active_filters"
    fi
    echo ""
    ui_item 1 "Generate Subtitles" "Single Directory"
    ui_item 2 "Batch Generate Subtitles" "Multiple Directories"
    ui_item 3 "Configure Subtitle Settings"
    ui_item 4 "Advanced Settings"
    ui_item 5 "Edit Existing Subtitle"
    ui_item 6 "Check Whisper Installation"
    echo ""
    ui_item B "Back to Main Menu" "" back
    ui_prompt
}


show_catalog_menu() {
    show_header

    ui_title "MULTI-DRIVE CATALOG"

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${COLOR_YELLOW}${SYMBOL_WARN} jq is not installed. Install with: ${COLOR_WHITE}sudo apt-get install jq${COLOR_RESET}"
        echo ""
    fi

    # Show catalog stats
    if [[ -f "$CATALOG_DRIVES_DB" ]]; then
        local drive_count=$(cat "$CATALOG_DRIVES_DB" 2>/dev/null | jq '.drives | length' 2>/dev/null || echo "0")
        local video_count=$(cat "$CATALOG_DB" 2>/dev/null | jq '.videos | length' 2>/dev/null || echo "0")
        ui_section "Catalog Status"
        ui_kv "Cataloged Drives" "$drive_count"
        ui_kv "Total Media Files" "$video_count"
        echo ""
    fi

    ui_item 1 "Scan & Catalog Drive"
    ui_item 2 "List All Cataloged Drives"
    ui_item 3 "Search Catalog"
    ui_item 4 "Find Duplicate Files"
    ui_item 5 "Batch Catalog Multiple Drives"
    ui_item 6 "Export Catalog Report"
    ui_item 7 "Catalog Settings"
    echo ""
    ui_item B "Back to Main Menu" "" back
    ui_prompt
}

show_utilities_menu() {
    show_header

    ui_title "UTILITIES"
    ui_item 1 "Organize by Subfolder Names"
    ui_item 2 "List Undo Operations"
    ui_item 3 "Undo Last Operation" "Renames, flattens, organize"
    ui_item 4 "View Last 50 Log Entries"
    ui_item 5 "Open Log Directory"
    ui_item 6 "Test Filename Transformation"
    ui_item 7 "Display System Information"
    ui_item 8 "Empty Trash" "Delete trashed duplicates for good"
    echo ""
    ui_item B "Back to Main Menu" "" back
    ui_prompt
}

show_settings_menu() {
    show_header

    ui_title "SETTINGS"
    ui_section "Current Configuration"
    print_toggle_setting "Dry Run Mode" "$DRY_RUN"
    print_toggle_setting "Verbose Output" "$VERBOSE"
    ui_kv "Log Directory" "$LOG_DIR"
    echo ""
    ui_item 1 "Toggle Dry Run Mode"
    ui_item 2 "Toggle Verbose Output"
    ui_item 3 "View Supported Extensions"
    ui_item 4 "Granular Controls"
    ui_item 5 "Organize Settings"
    echo ""
    ui_section "Profiles"
    ui_item 6 "Save Configuration"  "" toggle
    ui_item 7 "Load Configuration"  "" toggle
    ui_item 8 "List Profiles"       "" toggle
    ui_item 9 "Delete Profile"      "" toggle
    echo ""
    ui_item B "Back to Main Menu" "" back
    ui_prompt
}

show_organize_settings_menu() {
    show_header

    ui_title "ORGANIZE SETTINGS"
    ui_section "Current Settings"
    ui_kv "Default Target" "$ORGANIZE_DEFAULT_TARGET"
    ui_kv "Default Search" "$ORGANIZE_DEFAULT_SEARCH"
    print_toggle_setting "Show Progress" "$ORGANIZE_SHOW_PROGRESS"
    print_toggle_setting "Log Operations" "$ORGANIZE_LOG_OPERATIONS"
    echo ""
    ui_item 1 "Set Default Target Path"
    ui_item 2 "Set Default Search Path"
    ui_item 3 "Toggle Show Progress"
    ui_item 4 "Toggle Log Operations"
    echo ""
    ui_item B "Back to Settings" "" back
    ui_prompt
}

show_granular_controls_menu() {
    show_header

    ui_title "GRANULAR CONTROLS"

    # Count active filters
    local active_count=0
    [[ "$FILTER_BY_SIZE" == true ]] && ((active_count++))
    [[ "$FILTER_BY_DATE" == true ]] && ((active_count++))
    [[ "$FILTER_BY_PATTERN" == true ]] && ((active_count++))

    ui_section "Interactive mode"
    print_toggle_setting "Per-File Confirm" "$INTERACTIVE_CONFIRM"
    print_toggle_setting "Show Preview" "$SHOW_PREVIEW"
    print_toggle_setting "Step-by-Step" "$STEP_BY_STEP"

    echo ""
    ui_section "Filters ($active_count active)"

    print_toggle_setting "Size Filter" "$FILTER_BY_SIZE" "$([[ "$FILTER_BY_SIZE" == true ]] && echo "(${FILTER_MIN_SIZE_MB}MB - ${FILTER_MAX_SIZE_MB}MB)")"
    print_toggle_setting "Date Filter" "$FILTER_BY_DATE" "$([[ "$FILTER_BY_DATE" == true ]] && echo "(${FILTER_DAYS_OLD}+ days old)")"
    print_toggle_setting "Pattern Filter" "$FILTER_BY_PATTERN" "$([[ "$FILTER_BY_PATTERN" == true ]] && echo "($FILTER_PATTERN)")"

    echo ""
    ui_section "Processing"
    print_toggle_setting "Undo System" "$ENABLE_UNDO"

    ui_kv "Batch size" "$BATCH_SIZE files"

    echo ""
    ui_section "Options"
    ui_item 1 "Per-File Confirmation"
    ui_item 2 "Preview"
    ui_item 3 "Step-by-Step Mode"
    ui_item 4 "Size Filter"
    ui_item 5 "Date Filter"
    ui_item 6 "Pattern Filter"
    echo ""
    ui_section "Undo"
    ui_item 7 "Undo System" "" toggle
    ui_item 8 "View Undo History"
    ui_item 9 "Undo Last Operation"
    echo ""
    ui_item B "Back to Settings" "" back
    ui_prompt
}

# Show count + sample of affected files and ask for confirmation.
# $1 = operation label, $2 = directory, $3 = "deep" for flatten (mindepth 2)
confirm_destructive_op() {
    local op_label="$1"
    local directory="$2"
    local depth_mode="${3:-shallow}"

    local count
    if [[ "$depth_mode" == "deep" ]]; then
        count=$(find "$directory" -mindepth 2 -type f ! -path '*/.vmgr-trash/*' | grep -ciE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$' 2>/dev/null || true)
    else
        count=$(find "$directory" -maxdepth 1 -type f | grep -ciE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$' 2>/dev/null || true)
    fi
    count=${count:-0}

    echo ""
    echo -e "${COLOR_YELLOW}${op_label}${COLOR_RESET} will affect ${COLOR_BOLD}${count}${COLOR_RESET} file(s) in:"
    echo -e "  ${COLOR_WHITE}${directory}${COLOR_RESET}"

    if [[ "${count:-0}" -eq 0 && "$depth_mode" != "deep" ]]; then
        local nested
        nested=$(find "$directory" -mindepth 2 -type f ! -path '*/.vmgr-trash/*' | grep -ciE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$' 2>/dev/null || true)
        if [[ "${nested:-0}" -gt 0 ]]; then
            echo -e "${COLOR_CYAN}Note:${COLOR_RESET} ${nested} video(s) are in subfolders; this operation only looks at files directly in this folder."
            echo -e "      Use Flatten Directory first, or pick a subfolder."
        fi
    fi

    if [[ "${count:-0}" -gt 0 ]]; then
        ui_section "Sample"
        if [[ "$depth_mode" == "deep" ]]; then
            find "$directory" -mindepth 2 -type f ! -path '*/.vmgr-trash/*' | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$' 2>/dev/null | head -5 | while IFS= read -r f; do
                echo -e "  $(basename "$f")"
            done
        else
            find "$directory" -maxdepth 1 -type f | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp)$' 2>/dev/null | head -5 | while IFS= read -r f; do
                echo -e "  $(basename "$f")"
            done
        fi
        [[ "${count:-0}" -gt 5 ]] && echo -e "  ${COLOR_CYAN}... and $((count - 5)) more${COLOR_RESET}"
    fi

    ui_confirm "Proceed?"
}

# Get directory input
get_directory_input() {
    browse_directory
}

# Handle single operations
# Choice handler for single operations menu
_handle_single_operations_choice() {
    local choice="$1"
    case "$choice" in
        1)
            if get_directory_input; then
                if [[ "$DRY_RUN" == true ]] || confirm_destructive_op "Rename Files" "$TARGET_FOLDER"; then
                    start_operation "Rename Files (Bracket Notation)"
                    rename_files_in_directory "$TARGET_FOLDER" "$DRY_RUN"
                    end_operation
                    if [[ "$DRY_RUN" == true ]]; then
                        ui_confirm "Apply these changes?" || true
                        _apply="$REPLY"
                        if [[ "${_apply,,}" == "y" ]] && confirm_destructive_op "Rename Files" "$TARGET_FOLDER"; then
                            local DRY_RUN=false
                            start_operation "Rename Files (Apply)"
                            rename_files_in_directory "$TARGET_FOLDER" false
                            end_operation
                        fi
                    fi
                    ui_pause
                fi
            fi
            return 0
            ;;
        2)
            if get_directory_input; then
                if [[ "$DRY_RUN" == true ]] || confirm_destructive_op "Remove Dashes" "$TARGET_FOLDER"; then
                    start_operation "Remove Dashes"
                    remove_dashes_in_directory "$TARGET_FOLDER" "$DRY_RUN"
                    end_operation
                    if [[ "$DRY_RUN" == true ]]; then
                        ui_confirm "Apply these changes?" || true
                        _apply="$REPLY"
                        if [[ "${_apply,,}" == "y" ]] && confirm_destructive_op "Remove Dashes" "$TARGET_FOLDER"; then
                            local DRY_RUN=false
                            start_operation "Remove Dashes (Apply)"
                            remove_dashes_in_directory "$TARGET_FOLDER" false
                            end_operation
                        fi
                    fi
                    ui_pause
                fi
            fi
            return 0
            ;;
        3)
            if get_directory_input; then
                if [[ "$DRY_RUN" == true ]] || confirm_destructive_op "Fix Bracket Spacing" "$TARGET_FOLDER"; then
                    start_operation "Fix Bracket Spacing"
                    fix_bracket_spacing_in_directory "$TARGET_FOLDER" "$DRY_RUN"
                    end_operation
                    if [[ "$DRY_RUN" == true ]]; then
                        ui_confirm "Apply these changes?" || true
                        _apply="$REPLY"
                        if [[ "${_apply,,}" == "y" ]] && confirm_destructive_op "Fix Bracket Spacing" "$TARGET_FOLDER"; then
                            local DRY_RUN=false
                            start_operation "Fix Bracket Spacing (Apply)"
                            fix_bracket_spacing_in_directory "$TARGET_FOLDER" false
                            end_operation
                        fi
                    fi
                    ui_pause
                fi
            fi
            return 0
            ;;
        4)
            if get_directory_input; then
                if [[ "$DRY_RUN" == true ]] || confirm_destructive_op "Flatten Directory" "$TARGET_FOLDER" "deep"; then
                    start_operation "Flatten Directory"
                    flatten_directory "$TARGET_FOLDER" "$DRY_RUN"
                    end_operation
                    if [[ "$DRY_RUN" == true ]]; then
                        ui_confirm "Apply these changes?" || true
                        _apply="$REPLY"
                        if [[ "${_apply,,}" == "y" ]] && confirm_destructive_op "Flatten Directory" "$TARGET_FOLDER" "deep"; then
                            local DRY_RUN=false
                            start_operation "Flatten Directory (Apply)"
                            flatten_directory "$TARGET_FOLDER" false
                            end_operation
                        fi
                    fi
                    ui_pause
                fi
            fi
            return 0
            ;;
        5)
            if get_directory_input; then
                if [[ "$DRY_RUN" == true ]] || confirm_destructive_op "Full Cleanup" "$TARGET_FOLDER"; then
                    workflow_deep_clean "$TARGET_FOLDER"
                    ui_pause
                fi
            fi
            return 0
            ;;
        6)
            handle_image_ops
            return 0
            ;;
        7)
            handle_batch_processing
            return 0
            ;;
        8)
            handle_workflows
            return 0
            ;;
        d|D)
            toggle_flag_with_log DRY_RUN "Dry run mode"
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle single operations (using generic menu loop)
handle_single_operations() {
    run_menu_loop show_single_operations_menu _handle_single_operations_choice true
}

# Choice handler for image operations menu
# Returns: 0=continue, 1=break, 2=invalid
_handle_image_ops_choice() {
    local choice="$1"
    case "$choice" in
        1)
            if get_directory_input; then
                start_operation "Convert JPEG to JPG"
                convert_jpeg_to_jpg "$TARGET_FOLDER" "$DRY_RUN" "$IMAGE_RECURSIVE"
                end_operation
                ui_pause
            fi
            return 0
            ;;
        2)
            if get_directory_input; then
                start_operation "Convert PNG to JPG"
                convert_png_to_jpg "$TARGET_FOLDER" "$DRY_RUN" "$IMAGE_RECURSIVE"
                end_operation
                ui_pause
            fi
            return 0
            ;;
        3)
            if get_directory_input; then
                start_operation "Convert WebP to JPG"
                convert_webp_to_jpg "$TARGET_FOLDER" "$DRY_RUN" "$IMAGE_RECURSIVE"
                end_operation
                ui_pause
            fi
            return 0
            ;;
        4)
            if get_directory_input; then
                start_operation "Convert HEIC to JPG"
                convert_heic_to_jpg "$TARGET_FOLDER" "$DRY_RUN" "$IMAGE_RECURSIVE"
                end_operation
                ui_pause
            fi
            return 0
            ;;
        5)
            if get_directory_input; then
                start_operation "Convert All Images to JPG"
                convert_all_images_to_jpg "$TARGET_FOLDER" "$DRY_RUN" "$IMAGE_RECURSIVE"
                end_operation
                ui_pause
            fi
            return 0
            ;;
        r|R)
            toggle_flag_with_log IMAGE_RECURSIVE "Recursive mode"
            return 0
            ;;
        d|D)
            toggle_flag_with_log DRY_RUN "Dry run mode"
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle image operations (using generic menu loop)
handle_image_ops() {
    run_menu_loop show_image_ops_menu _handle_image_ops_choice true
}

# Choice handler for batch processing menu
# Returns: 0=continue, 1=break, 2=invalid
_handle_batch_choice() {
    local choice="$1"
    case "$choice" in
        1)
            batch_rename_interactive
            [[ $? -eq 2 ]] || ui_pause
            return 0
            ;;
        2)
            batch_flatten_interactive
            [[ $? -eq 2 ]] || ui_pause
            return 0
            ;;
        3)
            batch_cleanup_interactive
            [[ $? -eq 2 ]] || ui_pause
            return 0
            ;;
        4)
            batch_duplicates_interactive
            [[ $? -eq 2 ]] || ui_pause
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle batch processing (using generic menu loop)
handle_batch_processing() {
    run_menu_loop show_batch_menu _handle_batch_choice true
}

# Choice handler for workflows menu
# Returns: 0=continue, 1=break, 2=invalid
_handle_workflow_choice() {
    local choice="$1"
    case "$choice" in
        1)
            if get_directory_input; then
                if [[ "$DRY_RUN" == true ]] || ui_confirm "This will flatten, rename and look for duplicates in $TARGET_FOLDER. Continue?"; then
                    start_operation "New Collection Setup"
                    workflow_new_collection "$TARGET_FOLDER"
                    end_operation
                    ui_pause
                fi
            fi
            return 0
            ;;
        2)
            if get_directory_input; then
                if [[ "$DRY_RUN" == true ]] || ui_confirm "This will rename and look for duplicates in $TARGET_FOLDER. Continue?"; then
                    start_operation "Deep Clean"
                    workflow_deep_clean "$TARGET_FOLDER"
                    end_operation
                    ui_pause
                fi
            fi
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle workflows (using generic menu loop)
handle_workflows() {
    run_menu_loop show_workflow_menu _handle_workflow_choice true
}

# Choice handler for duplicate detection menu
_handle_duplicates_choice() {
    local choice="$1"
    case "$choice" in
        1)
            if get_directory_input; then
                start_operation "Find Duplicates (Report Only)"
                find_duplicates "$TARGET_FOLDER" "report"
                end_operation
                ui_pause
            fi
            return 0
            ;;
        2)
            if get_directory_input; then
                start_operation "Find and Delete Duplicates"
                echo ""
                local go_ahead=false
                if [[ "${ENABLE_UNDO:-true}" == true ]]; then
                    log_info "Duplicates are moved to a hidden .vmgr-trash folder; Utilities > Undo Last Operation puts them back."
                    ui_confirm "Move the duplicate files to the trash?" && go_ahead=true
                else
                    log_warning "Undo is off: duplicates will be DELETED for good!"
                    ui_ask confirm "Are you sure? (type 'yes' to confirm)"
                    [[ "$confirm" == "yes" ]] && go_ahead=true
                fi
                if $go_ahead; then
                    find_duplicates "$TARGET_FOLDER" "delete"
                else
                    log_warning "Operation cancelled"
                fi
                end_operation
                ui_pause
            fi
            return 0
            ;;
        3)
            local old_dry_run="$DRY_RUN"
            DRY_RUN=true
            if get_directory_input; then
                start_operation "Find Duplicates (Dry Run)"
                find_duplicates "$TARGET_FOLDER" "delete"
                end_operation
                ui_pause
            fi
            DRY_RUN="$old_dry_run"
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle duplicate detection (using generic menu loop)

handle_duplicates() {
    run_menu_loop show_duplicate_menu _handle_duplicates_choice true
}

# Configure basic subtitle settings (model, format, language)
_handle_subtitle_configure() {
    show_screen "Configure Subtitle Settings"

    ui_section "Whisper model (now: $WHISPER_MODEL)"
    ui_item 1 "tiny"   "Fastest, least accurate"
    ui_item 2 "base"   "Balanced (default)"
    ui_item 3 "small"  "Good accuracy"
    ui_item 4 "medium" "Better accuracy"
    ui_item 5 "large"  "Best accuracy, slowest"
    ui_prompt "Model"
    ui_read_choice model_choice
    case "$model_choice" in
        1) WHISPER_MODEL="tiny" ;;
        2) WHISPER_MODEL="base" ;;
        3) WHISPER_MODEL="small" ;;
        4) WHISPER_MODEL="medium" ;;
        5) WHISPER_MODEL="large" ;;
    esac

    echo ""
    ui_section "Output format (now: $SUBTITLE_FORMAT)"
    ui_item 1 "srt"  "SubRip (default)"
    ui_item 2 "vtt"  "WebVTT"
    ui_item 3 "txt"  "Plain text"
    ui_item 4 "json" "JSON"
    ui_prompt "Format"
    ui_read_choice format_choice
    case "$format_choice" in
        1) SUBTITLE_FORMAT="srt" ;;
        2) SUBTITLE_FORMAT="vtt" ;;
        3) SUBTITLE_FORMAT="txt" ;;
        4) SUBTITLE_FORMAT="json" ;;
    esac

    echo ""
    ui_section "Language (now: $SUBTITLE_LANGUAGE)"
    printf '  %sA code such as en, es, fr, or auto to detect. Enter keeps the current one.%s\n' "$UI_DIM" "$COLOR_RESET"
    ui_ask lang_choice "Language"
    [[ -n "$lang_choice" ]] && SUBTITLE_LANGUAGE="$lang_choice"

    echo ""
    log_success "Settings updated!"
    log_info "Model: $WHISPER_MODEL | Format: $SUBTITLE_FORMAT | Language: $SUBTITLE_LANGUAGE"
    ui_pause
}

# Configure advanced subtitle settings (GPU, parallel, toggles, filters)
_handle_subtitle_advanced() {
    show_screen "Advanced Subtitle Settings"

    ui_item_toggle 1 "Toggle GPU Acceleration" "$SUBTITLE_USE_GPU"
    ui_item 2 "Set Parallel Jobs" "now: $SUBTITLE_PARALLEL_JOBS"
    ui_item_toggle 3 "Toggle Batch Optimization" "$SUBTITLE_OPTIMIZE_BATCH"
    ui_item_toggle 4 "Toggle Speaker Diarization" "$SUBTITLE_SPEAKER_DIARIZATION"
    ui_item_toggle 5 "Toggle Auto-Punctuation" "$SUBTITLE_AUTO_PUNCTUATION"
    ui_item_toggle 6 "Toggle Interactive Editing" "$SUBTITLE_INTERACTIVE_EDIT"
    ui_item_toggle 7 "Toggle Auto-Edit" "$SUBTITLE_AUTO_EDIT"
    echo ""
    ui_section "Recursive Scanning"
    ui_item_toggle 8 "Toggle Recursive Mode" "$SUBTITLE_RECURSIVE"
    ui_item 9 "Set Max Depth" "now: $SUBTITLE_MAX_DEPTH"
    ui_item 10 "Set Max Files" "now: $SUBTITLE_MAX_FILES"
    ui_item 11 "Configure Filters & Selection"
    echo ""
    ui_ask adv_choice "Select option (or Enter to skip)"

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
            ui_ask jobs "Enter number of parallel jobs (1-8)"
            if [[ $jobs -ge 1 && $jobs -le 8 ]]; then
                SUBTITLE_PARALLEL_JOBS=$jobs
                log_success "Parallel jobs set to: $jobs"
            else
                log_error "Invalid number. Must be 1-8"
            fi
            ;;
        3)
            [[ "$SUBTITLE_OPTIMIZE_BATCH" == true ]] && SUBTITLE_OPTIMIZE_BATCH=false || SUBTITLE_OPTIMIZE_BATCH=true
            log_success "Batch optimization toggled"
            ;;
        4)
            [[ "$SUBTITLE_SPEAKER_DIARIZATION" == true ]] && SUBTITLE_SPEAKER_DIARIZATION=false || SUBTITLE_SPEAKER_DIARIZATION=true
            log_success "Speaker diarization toggled"
            ;;
        5)
            [[ "$SUBTITLE_AUTO_PUNCTUATION" == true ]] && SUBTITLE_AUTO_PUNCTUATION=false || SUBTITLE_AUTO_PUNCTUATION=true
            log_success "Auto-punctuation toggled"
            ;;
        6)
            [[ "$SUBTITLE_INTERACTIVE_EDIT" == true ]] && SUBTITLE_INTERACTIVE_EDIT=false || SUBTITLE_INTERACTIVE_EDIT=true
            log_success "Interactive editing toggled"
            ;;
        7)
            [[ "$SUBTITLE_AUTO_EDIT" == true ]] && SUBTITLE_AUTO_EDIT=false || SUBTITLE_AUTO_EDIT=true
            log_success "Auto-edit toggled"
            ;;
        8)
            if [[ "$SUBTITLE_RECURSIVE" == true ]]; then
                SUBTITLE_RECURSIVE=false
                log_info "Recursive mode DISABLED - will only scan current directory"
            else
                SUBTITLE_RECURSIVE=true
                log_success "Recursive mode ENABLED - will scan subdirectories"
                log_info "Max depth: $SUBTITLE_MAX_DEPTH levels | Max files: $SUBTITLE_MAX_FILES files"
            fi
            ;;
        9)
            ui_ask depth "Enter maximum recursion depth (1-50)"
            if [[ $depth -ge 1 && $depth -le 50 ]]; then
                SUBTITLE_MAX_DEPTH=$depth
                log_success "Max depth set to: $depth"
            else
                log_error "Invalid depth. Must be 1-50"
            fi
            ;;
        10)
            ui_ask max_files "Enter maximum files to process (1-10000)"
            if [[ $max_files -ge 1 && $max_files -le 10000 ]]; then
                SUBTITLE_MAX_FILES=$max_files
                log_success "Max files set to: $max_files"
            else
                log_error "Invalid number. Must be 1-10000"
            fi
            ;;
        11)
            # Filters & Selection submenu
            show_screen "Advanced Filters & Selection"
            ui_section "Current Filters"
            ui_kv "Min Size" "${SUBTITLE_MIN_SIZE_MB} MB"
            ui_kv "Max Size" "${SUBTITLE_MAX_SIZE_MB} MB (0=unlimited)"
            ui_kv "Modified" "${SUBTITLE_MODIFIED_DAYS} days (0=all)"
            print_toggle_setting "Skip Existing" "$SUBTITLE_SKIP_EXISTING"
            print_toggle_setting "Show Dir Stats" "$SUBTITLE_SHOW_DIR_STATS"
            print_toggle_setting "Interactive Select" "$SUBTITLE_INTERACTIVE_SELECT"
            ui_kv "Min Depth" "${SUBTITLE_MIN_DEPTH}"
            ui_kv "Skip Patterns" "${#SUBTITLE_SKIP_PATTERNS[@]} patterns"
            echo ""
            ui_item 1 "Set Minimum File Size (MB)"
            ui_item 2 "Set Maximum File Size (MB)"
            ui_item 3 "Set Modified Days Filter"
            ui_item 4 "Toggle Skip Existing Subtitles"
            ui_item 5 "Toggle Show Directory Stats"
            ui_item 6 "Toggle Interactive Directory Selection"
            ui_item 7 "Set Minimum Depth"
            ui_item 8 "Manage Skip Patterns"
            ui_item 9 "Reset All Filters to Default"
            echo ""
            ui_ask filter_choice "Select option"

            case "$filter_choice" in
                1)
                    ui_ask min_size "Enter minimum file size in MB (0=no limit)"
                    if [[ $min_size -ge 0 ]]; then
                        SUBTITLE_MIN_SIZE_MB=$min_size
                        log_success "Minimum size set to: ${min_size}MB"
                    else
                        log_error "Invalid size"
                    fi
                    ;;
                2)
                    ui_ask max_size "Enter maximum file size in MB (0=no limit)"
                    if [[ $max_size -ge 0 ]]; then
                        SUBTITLE_MAX_SIZE_MB=$max_size
                        log_success "Maximum size set to: ${max_size}MB"
                    else
                        log_error "Invalid size"
                    fi
                    ;;
                3)
                    ui_ask days "Process files modified in last N days (0=all files)"
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
                    [[ "$SUBTITLE_SHOW_DIR_STATS" == true ]] && SUBTITLE_SHOW_DIR_STATS=false || SUBTITLE_SHOW_DIR_STATS=true
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
                    ui_ask min_depth "Enter minimum depth (0=include current dir, 1=subdirs only)"
                    if [[ $min_depth -ge 0 && $min_depth -le 50 ]]; then
                        SUBTITLE_MIN_DEPTH=$min_depth
                        log_success "Minimum depth set to: $min_depth"
                    else
                        log_error "Invalid depth. Must be 0-50"
                    fi
                    ;;
                8)
                    echo ""
                    ui_section "Current Skip Patterns"
                    for i in "${!SUBTITLE_SKIP_PATTERNS[@]}"; do
                        printf '  %s%2d%s  %s\n' "$UI_ACCENT" "$i" "$COLOR_RESET" "${SUBTITLE_SKIP_PATTERNS[$i]}"
                    done
                    echo ""
                    echo "Common patterns: .* (hidden), _* (underscore), tmp, temp, Trash"
                    echo "Leave empty to keep current patterns"
                    echo ""
                    ui_ask new_patterns "Enter new patterns (space-separated)"
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
            ;;
    esac
    ui_pause
}

# Choice handler for subtitle generation menu
# Returns: 0=continue, 1=break, 2=invalid
_handle_subtitles_choice() {
    local choice="$1"
    case "$choice" in
        1)
            if get_directory_input; then
                start_operation "Generate Subtitles"
                generate_subtitles_in_directory "$TARGET_FOLDER" "$WHISPER_MODEL" "$SUBTITLE_FORMAT" "$SUBTITLE_LANGUAGE" "$DRY_RUN"
                end_operation
                ui_pause
            fi
            return 0
            ;;
        2)
            batch_generate_subtitles
            [[ $? -eq 2 ]] || ui_pause
            return 0
            ;;
        3)
            _handle_subtitle_configure
            return 0
            ;;
        4)
            _handle_subtitle_advanced
            return 0
            ;;
        5)
            # Edit existing subtitle
            show_screen "Edit Existing Subtitle"
            ui_ask subtitle_path "Enter subtitle file path"

            if [[ -f "$subtitle_path" ]]; then
                edit_subtitle_interactive "$subtitle_path"
            else
                log_error "File not found: $subtitle_path"
            fi
            ui_pause
            return 0
            ;;
        6)
            # Check whisper installation
            show_screen "Checking Whisper Installation"

            if check_whisper_installation; then
                local whisper_cmd=$(get_whisper_command)
                local whisper_out whisper_rc=0
                echo -e "${COLOR_WHITE}Testing ${whisper_cmd}...${COLOR_RESET}"
                whisper_out="$(run_with_timeout 30 "$whisper_cmd" --help 2>&1)" || whisper_rc=$?
                if [[ $whisper_rc -eq 0 ]]; then
                    log_success "Whisper is installed and working: $whisper_cmd"
                else
                    log_error "Found '$whisper_cmd', but it fails to run"
                    printf '  %s%s%s\n' "$UI_DIM" "$(printf '%s\n' "$whisper_out" | sed '/^[[:space:]]*$/d' | tail -n 1)" "$COLOR_RESET"
                    echo ""
                    echo "  Reinstall it with:  pip install -U openai-whisper"
                fi
            else
                log_error "Whisper is not installed!"
                echo ""
                ui_section "Installation Instructions"
                echo ""
                ui_section "Option 1 - OpenAI Whisper (Python)"
                echo "  pip install -U openai-whisper"
                echo ""
                ui_section "Option 2 - whisper.cpp (C++, faster)"
                echo "  git clone https://github.com/ggerganov/whisper.cpp"
                echo "  cd whisper.cpp && make"
                echo "  # Add to PATH or create symlink"
                echo ""
            fi
            ui_pause
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle subtitle generation (using generic menu loop)
handle_subtitles() {
    run_menu_loop show_subtitle_menu _handle_subtitles_choice true
}

# Choice handler for catalog operations menu
# Returns: 0=continue, 1=break, 2=invalid
_handle_catalog_choice() {
    local choice="$1"
    case "$choice" in
        1)
            # Scan & catalog a drive
            show_screen "Scan & Catalog a Drive"
            echo "Available mount points:"
            echo "  /mnt/c  - Windows C: drive"
            echo "  /mnt/d  - Windows D: drive"
            echo "  /media/* - USB drives (if mounted)"
            echo ""
            ui_ask mount_point "Enter mount point to catalog"

            if [[ -z "$mount_point" ]]; then
                log_error "No mount point specified"
                ui_pause
                return 0
            fi

            ui_confirm "Scan recursively?" || true
            local recursive=false
            [[ $REPLY =~ ^[Yy]$ ]] && recursive=true

            start_operation "Catalog Drive: $mount_point"
            catalog_drive "$mount_point" "$recursive"
            end_operation
            ui_pause
            return 0
            ;;
        2)
            # List all cataloged drives
            clear
            start_operation "List Cataloged Drives"
            list_cataloged_drives
            end_operation
            ui_pause
            return 0
            ;;
        3)
            # Search catalog
            show_screen "Search Catalog"
            ui_section "Filter by media type"
            ui_item 1 "All media"
            ui_item 2 "Videos only"
            ui_item 3 "Images only"
            ui_item 4 "Audio only"
            ui_prompt "Filter"
            ui_read_choice filter_choice

            local media_filter="all"
            case "$filter_choice" in
                2) media_filter="video" ;;
                3) media_filter="image" ;;
                4) media_filter="audio" ;;
                *) media_filter="all" ;;
            esac

            echo ""
            ui_ask search_term "Enter search term"

            if [[ -n "$search_term" ]]; then
                start_operation "Search Catalog"
                search_catalog "$search_term" "$media_filter"
                end_operation
            fi
            ui_pause
            return 0
            ;;
        4)
            # Find duplicate files
            clear
            start_operation "Find Duplicate Files"
            show_duplicates_report
            end_operation
            ui_pause
            return 0
            ;;
        5)
            # Catalog multiple drives (batch)
            show_screen "Batch Catalog Multiple Drives"
            echo "Enter mount points to catalog (one per line, empty line to finish):"
            echo ""

            local -a mount_points
            while true; do
                ui_ask mp "Mount point"
                [[ -z "$mp" ]] && break
                mount_points+=("$mp")
            done

            if [[ ${#mount_points[@]} -eq 0 ]]; then
                log_warning "No mount points specified"
                ui_pause
                return 0
            fi

            ui_confirm "Scan recursively?" || true
            local recursive=false
            [[ $REPLY =~ ^[Yy]$ ]] && recursive=true

            start_operation "Batch Catalog Drives"
            for mp in "${mount_points[@]}"; do
                echo ""
                catalog_drive "$mp" "$recursive"
            done
            end_operation
            ui_pause
            return 0
            ;;
        6)
            # Export catalog report
            show_screen "Export Catalog Report"

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
            ui_pause
            return 0
            ;;
        7)
            # Catalog settings
            show_screen "Catalog Settings"
            ui_section "Media Types to Catalog"
            print_toggle_setting "Videos" "$CATALOG_VIDEOS"
            print_toggle_setting "Images" "$CATALOG_IMAGES"
            print_toggle_setting "Audio" "$CATALOG_AUDIO"
            echo ""
            ui_section "Other Settings"
            print_toggle_setting "Include Metadata" "$CATALOG_INCLUDE_METADATA"
            print_toggle_setting "Include Hash" "$CATALOG_INCLUDE_HASH"
            ui_kv "Offline Retention" "$CATALOG_OFFLINE_RETENTION days"
            echo ""
            ui_item 1 "Toggle Video Cataloging"
            ui_item 2 "Toggle Image Cataloging"
            ui_item 3 "Toggle Audio Cataloging"
            ui_item 4 "Toggle Include Metadata"
            ui_item 5 "Toggle Include Hash"
            ui_item 6 "Set Offline Retention Days"
            echo ""
            ui_ask setting_choice "Select option (or Enter to skip)"

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
                    ui_ask days "Enter offline retention days (0=forever)"
                    if [[ $days -ge 0 ]]; then
                        CATALOG_OFFLINE_RETENTION=$days
                        log_success "Offline retention set to: $days days"
                    fi
                    ;;
            esac
            ui_pause
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle catalog operations (using generic menu loop)
handle_catalog() {
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is not installed. Please install it first:"
        echo "  sudo apt-get install jq"
        ui_pause
        return 1
    fi

    run_menu_loop show_catalog_menu _handle_catalog_choice true
}

# Handle utilities
# Choice handler for utilities menu
_handle_utilities_choice() {
    local choice="$1"
    case "$choice" in
        1)
            show_screen "Organize by Subfolder Names"
            echo "This feature will:"
            echo "  1. Scan a target folder for subfolders"
            echo "  2. Search for video files matching those subfolder names"
            echo "  3. Move matching files into their respective subfolders"
            echo "  4. Skip files in 'full' folders or already in place"
            echo ""
            ui_ask target_folder "Enter target folder with subfolders (or . for current)"
            target_folder="${target_folder:-.}"

            ui_ask search_path "Enter search path (or . for current, or enter for target)"
            search_path="${search_path:-$target_folder}"

            organize_by_subfolder_names "$target_folder" "$search_path"

            echo ""
            ui_pause
            return 0
            ;;
        2)
            clear
            list_undo_operations
            ui_pause
            return 0
            ;;
        3)
            clear
            undo_organize_operation
            echo ""
            ui_pause
            return 0
            ;;
        4)
            show_screen "Last 50 Log Entries"
            tail -n 50 "$LOG_FILE" 2>/dev/null || echo "No log entries found"
            ui_pause
            return 0
            ;;
        5)
            if command -v xdg-open &> /dev/null; then
                xdg-open "$LOG_DIR" 2>/dev/null
            elif command -v explorer.exe &> /dev/null; then
                explorer.exe "$(wslpath -w "$LOG_DIR")" 2>/dev/null
            else
                log_info "Log directory: $LOG_DIR"
            fi
            return 0
            ;;
        6)
            show_screen "Test Filename Transformation"
            ui_ask test_file "Enter filename to test"

            echo ""
            ui_kv "Original" "$test_file"

            local result=$(remove_dashes "$test_file")
            ui_kv "After dash removal" "$result"

            result=$(apply_bracket_notation "$result")
            ui_kv "After bracket notation" "$result"

            result=$(fix_bracket_spacing "$result")
            ui_kv "Final result" "$result"
            ui_pause
            return 0
            ;;
        7)
            show_screen "System Information"
            echo -e "${COLOR_BOLD}${COLOR_WHITE}Environment:${COLOR_RESET}"
            ui_kv "Script Version" "$SCRIPT_VERSION"
            ui_kv "Platform" "$OS_TYPE"
            ui_kv "Bash Version" "$BASH_VERSION"
            echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} OS: ${COLOR_WHITE}$(uname -s)${COLOR_RESET}"
            echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Kernel: ${COLOR_WHITE}$(uname -r)${COLOR_RESET}"
            echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Hostname: ${COLOR_WHITE}$(hostname)${COLOR_RESET}"
            echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} User: ${COLOR_WHITE}$(whoami)${COLOR_RESET}"
            echo ""
            echo -e "${COLOR_BOLD}${COLOR_WHITE}Directories:${COLOR_RESET}"
            echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Working: ${COLOR_WHITE}$(pwd)${COLOR_RESET}"
            ui_kv "Logs" "$LOG_DIR"
            echo ""
            echo -e "${COLOR_BOLD}${COLOR_WHITE}Available Tools:${COLOR_RESET}"
            command -v jq &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} jq" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} jq"
            command -v sha256sum &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} sha256sum" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} sha256sum"
            command -v shasum &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} shasum" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} shasum"
            command -v ffprobe &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} ffprobe" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} ffprobe"
            command -v exiftool &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} exiftool" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} exiftool"
            command -v identify &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} identify (ImageMagick)" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} identify (ImageMagick)"
            command -v whisper &> /dev/null && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} whisper" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} whisper"
            ui_pause
            return 0
            ;;
        8)
            clear
            empty_trash
            [[ $? -eq 2 ]] || ui_pause
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle utilities (using generic menu loop)
handle_utilities() {
    run_menu_loop show_utilities_menu _handle_utilities_choice false
}

# Choice handler for organize settings menu
_handle_organize_settings_choice() {
    local choice="$1"
    case "$choice" in
        1)
            echo ""
            ui_ask target_path "Enter default target folder path"
            if [[ -d "$target_path" ]]; then
                ORGANIZE_DEFAULT_TARGET="$target_path"
                log_success "Default target set to: $target_path"
            else
                log_warning "Path does not exist, but setting anyway: $target_path"
                ORGANIZE_DEFAULT_TARGET="$target_path"
            fi
            return 0
            ;;
        2)
            echo ""
            ui_ask search_path "Enter default search path"
            if [[ -d "$search_path" ]]; then
                ORGANIZE_DEFAULT_SEARCH="$search_path"
                log_success "Default search path set to: $search_path"
            else
                log_warning "Path does not exist, but setting anyway: $search_path"
                ORGANIZE_DEFAULT_SEARCH="$search_path"
            fi
            return 0
            ;;
        3)
            toggle_flag_with_log ORGANIZE_SHOW_PROGRESS "Progress display"
            return 0
            ;;
        4)
            toggle_flag_with_log ORGANIZE_LOG_OPERATIONS "Operation logging"
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle organize settings (using generic menu loop)
handle_organize_settings() {
    run_menu_loop show_organize_settings_menu _handle_organize_settings_choice false
}

# Choice handler for settings menu
_handle_settings_choice() {
    local choice="$1"
    case "$choice" in
        1)
            toggle_flag_with_log DRY_RUN "Dry run mode"
            return 0
            ;;
        2)
            toggle_flag_with_log VERBOSE "Verbose output"
            return 0
            ;;
        3)
            show_screen "Supported Video Extensions"
            for ext in "${DEFAULT_VIDEO_EXTENSIONS[@]}"; do
                echo "  ${SYMBOL_BULLET} .$ext"
            done
            ui_pause
            return 0
            ;;
        4)
            handle_granular_controls
            return 0
            ;;
        5)
            handle_organize_settings
            return 0
            ;;
        6)
            show_screen "Save Configuration"
            ui_ask profile_name "Enter profile name (default)"
            profile_name=${profile_name:-default}
            save_config "$profile_name"
            ui_pause
            return 0
            ;;
        7)
            show_screen "Load Configuration"
            list_config_profiles
            ui_ask profile_name "Enter profile name to load (default)"
            profile_name=${profile_name:-default}
            load_config "$profile_name"
            ui_pause
            return 0
            ;;
        8)
            show_screen "Configuration Profiles"
            list_config_profiles
            ui_pause
            return 0
            ;;
        9)
            show_screen "Delete Profile"
            list_config_profiles
            echo ""
            ui_ask profile_name "Enter profile name to delete"
            if [[ -n "$profile_name" ]]; then
                ui_confirm "Delete profile '$profile_name'?" || true
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    delete_config_profile "$profile_name"
                fi
            fi
            ui_pause
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle settings (using generic menu loop)
handle_settings() {
    run_menu_loop show_settings_menu _handle_settings_choice false
}

# Choice handler for granular controls menu
_handle_granular_controls_choice() {
    local choice="$1"
    case "$choice" in
        1)
            toggle_flag_with_log INTERACTIVE_CONFIRM "Per-file confirmation"
            return 0
            ;;
        2)
            toggle_flag_with_log SHOW_PREVIEW "Preview mode"
            return 0
            ;;
        3)
            toggle_flag_with_log STEP_BY_STEP "Step-by-step mode"
            return 0
            ;;
        4)
            show_screen "Configure Size Filter"
            ui_confirm "Enable size filter?" || true
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                FILTER_BY_SIZE=true
                ui_ask FILTER_MIN_SIZE_MB "Minimum size in MB (0 for no minimum)"
                ui_ask FILTER_MAX_SIZE_MB "Maximum size in MB (0 for no maximum)"
                log_success "Size filter enabled: ${FILTER_MIN_SIZE_MB}MB - ${FILTER_MAX_SIZE_MB}MB"
            else
                FILTER_BY_SIZE=false
                log_success "Size filter disabled"
            fi
            ui_pause
            return 0
            ;;
        5)
            show_screen "Configure Date Filter"
            ui_confirm "Enable date filter?" || true
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                FILTER_BY_DATE=true
                ui_ask FILTER_DAYS_OLD "Process files older than N days"
                log_success "Date filter enabled: ${FILTER_DAYS_OLD}+ days old"
            else
                FILTER_BY_DATE=false
                log_success "Date filter disabled"
            fi
            ui_pause
            return 0
            ;;
        6)
            show_screen "Configure Pattern Filter"
            ui_confirm "Enable pattern filter?" || true
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                FILTER_BY_PATTERN=true
                ui_ask FILTER_PATTERN "Enter regex pattern"
                log_success "Pattern filter enabled: $FILTER_PATTERN"
            else
                FILTER_BY_PATTERN=false
                FILTER_PATTERN=""
                log_success "Pattern filter disabled"
            fi
            ui_pause
            return 0
            ;;
        7)
            toggle_flag_with_log ENABLE_UNDO "Undo system"
            return 0
            ;;
        8)
            clear
            list_undo_operations
            ui_pause
            return 0
            ;;
        9)
            clear
            undo_last_operation
            ui_pause
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

# Handle granular controls (using generic menu loop)
handle_granular_controls() {
    run_menu_loop show_granular_controls_menu _handle_granular_controls_choice false
}

# Choice handler for main menu
_handle_main_menu_choice() {
    local choice="$1"
    case "$choice" in
        1)
            handle_single_operations
            return 0
            ;;
        2)
            handle_subtitles
            return 0
            ;;
        3)
            handle_duplicates
            return 0
            ;;
        4)
            handle_catalog
            return 0
            ;;
        5)
            handle_utilities
            return 0
            ;;
        6)
            handle_settings
            return 0
            ;;
        7)
            handle_reddit
            return 0
            ;;
        q|Q)
            echo ""
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice"
            sleep 1
            return 0
            ;;
    esac
}

show_reddit_menu() {
    show_header

    ui_title "REDDIT IMAGE DOWNLOADER"
    ui_item 1 "Download Images from Subreddit"
    echo ""
    ui_item B "Back to Main Menu" "" back
    ui_prompt
}

_handle_reddit_choice() {
    local choice="$1"
    case "$choice" in
        1)
            show_screen "Reddit Image Downloader"
            ui_ask subreddit "Subreddit name (e.g. EarthPorn)"
            if [[ -z "$subreddit" ]]; then
                log_error "No subreddit specified"
                ui_pause
                return 0
            fi

            local default_dir="$HOME/Pictures/reddit/${subreddit}"
            ui_ask output_dir "Output directory [${default_dir}]"
            [[ -z "$output_dir" ]] && output_dir="$default_dir"

            ui_ask max_images "Max images to download [200]"
            [[ -z "$max_images" || ! "$max_images" =~ ^[0-9]+$ ]] && max_images=200

            echo ""
            start_operation "Reddit Download: r/${subreddit}"
            download_subreddit_images "$subreddit" "$output_dir" "$max_images"
            end_operation
            ui_pause
            return 0
            ;;
        b|B) return 1 ;;
        *) return 2 ;;
    esac
}

handle_reddit() {
    run_menu_loop show_reddit_menu _handle_reddit_choice true
}

# Main interactive menu loop (simple number-based input)
interactive_menu() {
    local choice
    while true; do
        show_main_menu
        ui_read_choice choice || { echo ""; exit 0; }
        [[ "$choice" == ESC ]] && continue
        _handle_main_menu_choice "$choice"
    done
}

# Module loaded successfully
return 0
