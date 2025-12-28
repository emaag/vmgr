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
    echo -e "${COLOR_BRIGHT_GREEN}[6]${COLOR_RESET} ${COLOR_WHITE}Convert JPEG to JPG${COLOR_RESET} ${COLOR_CYAN}(Rename Extension)${COLOR_RESET}"
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
    print_toggle_setting "Dry Run Mode" "$DRY_RUN"
    print_toggle_setting "Verbose Output" "$VERBOSE"
    echo -e "  ${COLOR_CYAN}Log Directory:        ${COLOR_RESET} ${COLOR_WHITE}$LOG_DIR${COLOR_RESET}"
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
    echo -e "  ${COLOR_CYAN}Default Target:       ${COLOR_RESET} ${COLOR_WHITE}$ORGANIZE_DEFAULT_TARGET${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Default Search:       ${COLOR_RESET} ${COLOR_WHITE}$ORGANIZE_DEFAULT_SEARCH${COLOR_RESET}"
    print_toggle_setting "Show Progress" "$ORGANIZE_SHOW_PROGRESS"
    print_toggle_setting "Log Operations" "$ORGANIZE_LOG_OPERATIONS"
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
    print_toggle_setting "Per-File Confirm" "$INTERACTIVE_CONFIRM"
    print_toggle_setting "Show Preview" "$SHOW_PREVIEW"
    print_toggle_setting "Step-by-Step" "$STEP_BY_STEP"

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}━━━ Filters ${COLOR_RESET}${COLOR_YELLOW}($active_count active)${COLOR_RESET}${COLOR_BOLD}${COLOR_WHITE} ━━━${COLOR_RESET}"

    print_toggle_setting "Size Filter" "$FILTER_BY_SIZE" "$([[ "$FILTER_BY_SIZE" == true ]] && echo "(${FILTER_MIN_SIZE_MB}MB - ${FILTER_MAX_SIZE_MB}MB)")"
    print_toggle_setting "Date Filter" "$FILTER_BY_DATE" "$([[ "$FILTER_BY_DATE" == true ]] && echo "(${FILTER_DAYS_OLD}+ days old)")"
    print_toggle_setting "Pattern Filter" "$FILTER_BY_PATTERN" "$([[ "$FILTER_BY_PATTERN" == true ]] && echo "($FILTER_PATTERN)")"

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}━━━ Processing ━━━${COLOR_RESET}"
    print_toggle_setting "Undo System" "$ENABLE_UNDO"

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
# Choice handler for single operations menu
_handle_single_operations_choice() {
    local choice="$1"
    case "$choice" in
        1)
            if get_directory_input; then
                start_operation "Rename Files (Bracket Notation)"
                rename_files_in_directory "$TARGET_FOLDER" "$DRY_RUN"
                end_operation
                read -p "Press Enter to continue..."
            fi
            return 0
            ;;
        2)
            if get_directory_input; then
                start_operation "Remove Dashes"
                log_info "Feature coming soon!"
                end_operation
                read -p "Press Enter to continue..."
            fi
            return 0
            ;;
        3)
            if get_directory_input; then
                start_operation "Fix Bracket Spacing"
                log_info "Feature coming soon!"
                end_operation
                read -p "Press Enter to continue..."
            fi
            return 0
            ;;
        4)
            if get_directory_input; then
                start_operation "Flatten Directory"
                flatten_directory "$TARGET_FOLDER" "$DRY_RUN"
                end_operation
                read -p "Press Enter to continue..."
            fi
            return 0
            ;;
        5)
            if get_directory_input; then
                workflow_deep_clean "$TARGET_FOLDER"
                read -p "Press Enter to continue..."
            fi
            return 0
            ;;
        6)
            if get_directory_input; then
                start_operation "Convert JPEG to JPG"
                convert_jpeg_to_jpg "$TARGET_FOLDER" "$DRY_RUN"
                end_operation
                read -p "Press Enter to continue..."
            fi
            return 0
            ;;
        d|D)
            toggle_flag_with_log DRY_RUN "Dry run mode"
            read -p "Press Enter to continue..."
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

# Choice handler for batch processing menu
# Returns: 0=continue, 1=break, 2=invalid
_handle_batch_choice() {
    local choice="$1"
    case "$choice" in
        1)
            start_operation "Batch Rename Multiple Folders"
            batch_process_folders
            end_operation
            read -p "Press Enter to continue..."
            return 0
            ;;
        2|3)
            log_info "Feature coming soon!"
            read -p "Press Enter to continue..."
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
                workflow_new_collection "$TARGET_FOLDER"
                read -p "Press Enter to continue..."
            fi
            return 0
            ;;
        2)
            if get_directory_input; then
                workflow_deep_clean "$TARGET_FOLDER"
                read -p "Press Enter to continue..."
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
                read -p "Press Enter to continue..."
            fi
            return 0
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
            return 0
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
# Choice handler for utilities menu
_handle_utilities_choice() {
    local choice="$1"
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
            return 0
            ;;
        2)
            clear
            list_undo_operations
            echo ""
            read -p "Press Enter to continue..."
            return 0
            ;;
        3)
            clear
            undo_organize_operation
            echo ""
            read -p "Press Enter to continue..."
            return 0
            ;;
        4)
            clear
            echo -e "${COLOR_BRIGHT_CYAN}Last 50 Log Entries:${COLOR_RESET}"
            echo ""
            tail -n 50 "$LOG_FILE" 2>/dev/null || echo "No log entries found"
            echo ""
            read -p "Press Enter to continue..."
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
            read -p "Press Enter to continue..."
            return 0
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
            return 0
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
            return 0
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
            return 0
            ;;
        3)
            toggle_flag_with_log ORGANIZE_SHOW_PROGRESS "Progress display"
            read -p "Press Enter to continue..."
            return 0
            ;;
        4)
            toggle_flag_with_log ORGANIZE_LOG_OPERATIONS "Operation logging"
            read -p "Press Enter to continue..."
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
            read -p "Press Enter to continue..."
            return 0
            ;;
        2)
            toggle_flag_with_log VERBOSE "Verbose output"
            read -p "Press Enter to continue..."
            return 0
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
            clear
            echo -e "${COLOR_BRIGHT_CYAN}Save Configuration${COLOR_RESET}"
            echo ""
            read -p "Enter profile name (default): " profile_name
            profile_name=${profile_name:-default}
            save_config "$profile_name"
            read -p "Press Enter to continue..."
            return 0
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
            return 0
            ;;
        8)
            clear
            list_config_profiles
            read -p "Press Enter to continue..."
            return 0
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
            read -p "Press Enter to continue..."
            return 0
            ;;
        2)
            toggle_flag_with_log SHOW_PREVIEW "Preview mode"
            read -p "Press Enter to continue..."
            return 0
            ;;
        3)
            toggle_flag_with_log STEP_BY_STEP "Step-by-step mode"
            read -p "Press Enter to continue..."
            return 0
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
            return 0
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
            return 0
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
            return 0
            ;;
        7)
            toggle_flag_with_log ENABLE_UNDO "Undo system"
            read -p "Press Enter to continue..."
            return 0
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
            return 0
            ;;
        9)
            clear
            undo_last_operation
            read -p "Press Enter to continue..."
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

# Main interactive menu loop (using generic pattern but with custom invalid handling)
interactive_menu() {
    while true; do
        show_main_menu
        read -r choice
        _handle_main_menu_choice "$choice"
    done
}

# Module loaded successfully
return 0
