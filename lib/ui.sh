#!/usr/bin/env bash
#
# Video Manager Ultimate - Interactive UI Module
# Part of the modular video management system
#
# This module provides interactive menu system functionality for:
# - Main menu navigation
# - Subtitle generation menu
# - Settings configuration menu
# - Help and documentation display
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh
# Status: Phase 3 - Modularization
# Version: 1.2.0
#

################################################################################
# MENU DISPLAY FUNCTIONS
################################################################################

# Display menu header
display_menu_header() {
    local title="$1"

    clear
    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}╔═══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}║${COLOR_RESET}  ${COLOR_BOLD}${COLOR_YELLOW}${title}${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}╚═══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

# Display menu option
display_menu_option() {
    local key="$1"
    local description="$2"

    echo -e "  ${COLOR_GREEN}[$key]${COLOR_RESET} $description"
}

# Get user menu choice
get_menu_choice() {
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Enter your choice: "
    read -r choice
    echo "$choice"
}

################################################################################
# MAIN MENU
################################################################################

# Show main menu
show_main_menu() {
    while true; do
        display_menu_header "VIDEO MANAGER ULTIMATE - Main Menu"

        display_menu_option "1" "Rename Files (Bracket Notation)"
        display_menu_option "2" "Flatten Directory Structure"
        display_menu_option "3" "Find Duplicate Files"
        display_menu_option "4" "Generate Subtitles (Whisper AI)"
        display_menu_option "5" "Organize Files by Subfolder"
        display_menu_option "6" "Batch Processing"
        display_menu_option "7" "Workflows (New Collection, Deep Clean)"
        display_menu_option "8" "Settings"
        display_menu_option "H" "Help & Documentation"
        display_menu_option "Q" "Quit"

        local choice=$(get_menu_choice)

        case "$choice" in
            1) menu_rename_files ;;
            2) menu_flatten_directory ;;
            3) menu_find_duplicates ;;
            4) show_subtitle_menu ;;
            5) menu_organize_files ;;
            6) menu_batch_processing ;;
            7) menu_workflows ;;
            8) show_settings_menu ;;
            h|H) menu_show_help ;;
            q|Q) log_info "Goodbye!"; exit 0 ;;
            *) log_error "Invalid choice: $choice" ; sleep 2 ;;
        esac
    done
}

################################################################################
# SUBTITLE MENU
################################################################################

# Show subtitle menu
show_subtitle_menu() {
    display_menu_header "SUBTITLE GENERATION MENU"

    display_menu_option "1" "Generate Subtitles for Directory"
    display_menu_option "2" "Batch Generate (Multiple Folders)"
    display_menu_option "3" "Configure Subtitle Settings"
    display_menu_option "4" "Check Whisper Installation"
    display_menu_option "B" "Back to Main Menu"

    local choice=$(get_menu_choice)

    case "$choice" in
        1) log_info "Subtitle generation not yet implemented in modular version" ; sleep 2 ;;
        2) log_info "Batch subtitle generation not yet implemented" ; sleep 2 ;;
        3) log_info "Subtitle settings not yet implemented" ; sleep 2 ;;
        4) check_whisper_installation && log_success "Whisper is installed" || log_warning "Whisper not found" ; sleep 2 ;;
        b|B) return 0 ;;
        *) log_error "Invalid choice: $choice" ; sleep 2 ;;
    esac
}

################################################################################
# SETTINGS MENU
################################################################################

# Show settings menu
show_settings_menu() {
    display_menu_header "SETTINGS MENU"

    echo -e "${COLOR_WHITE}Current Settings:${COLOR_RESET}"
    echo -e "  Verbose: ${VERBOSE}"
    echo -e "  Dry Run: ${DRY_RUN}"
    echo -e "  Interactive: ${INTERACTIVE}"
    echo ""

    display_menu_option "1" "Toggle Verbose Mode"
    display_menu_option "2" "Toggle Dry Run Mode"
    display_menu_option "3" "Save Current Configuration"
    display_menu_option "4" "Load Configuration"
    display_menu_option "B" "Back to Main Menu"

    local choice=$(get_menu_choice)

    case "$choice" in
        1) VERBOSE=$([[ "$VERBOSE" == "true" ]] && echo "false" || echo "true") ; log_info "Verbose mode: $VERBOSE" ; sleep 1 ;;
        2) DRY_RUN=$([[ "$DRY_RUN" == "true" ]] && echo "false" || echo "true") ; log_info "Dry run mode: $DRY_RUN" ; sleep 1 ;;
        3) log_info "Configuration save not yet implemented" ; sleep 2 ;;
        4) log_info "Configuration load not yet implemented" ; sleep 2 ;;
        b|B) return 0 ;;
        *) log_error "Invalid choice: $choice" ; sleep 2 ;;
    esac
}

################################################################################
# MENU HANDLERS (STUBS)
################################################################################

menu_rename_files() {
    log_info "Rename files menu not yet fully implemented"
    sleep 2
}

menu_flatten_directory() {
    log_info "Flatten directory menu not yet fully implemented"
    sleep 2
}

menu_find_duplicates() {
    log_info "Find duplicates menu not yet fully implemented"
    sleep 2
}

menu_organize_files() {
    log_info "Organize files menu not yet fully implemented"
    sleep 2
}

menu_batch_processing() {
    log_info "Batch processing menu not yet fully implemented"
    sleep 2
}

menu_workflows() {
    log_info "Workflows menu not yet fully implemented"
    sleep 2
}

menu_show_help() {
    display_menu_header "HELP & DOCUMENTATION"
    echo -e "${COLOR_WHITE}Video Manager Ultimate - Bash Edition v${SCRIPT_VERSION}${COLOR_RESET}"
    echo ""
    echo "For detailed documentation, see:"
    echo "  - README.md"
    echo "  - VIDEO-MANAGER-BASH-GUIDE.md"
    echo "  - QUICK-REFERENCE.md"
    echo ""
    echo "Press [Enter] to continue..."
    read -r
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
