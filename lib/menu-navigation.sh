#!/bin/bash
################################################################################
#
#  CURSOR MENU NAVIGATION MODULE
#
#  Provides arrow key-based menu navigation for interactive menus
#
#  Features:
#  - Up/Down arrow key navigation
#  - Enter to select
#  - Visual highlighting of selected option
#  - ESC or Q to go back
#  - Number key quick selection
#
################################################################################

# Terminal control sequences
readonly KEY_UP=$'\x1b[A'
readonly KEY_DOWN=$'\x1b[B'
readonly KEY_ENTER=$'\n'
readonly KEY_ESC=$'\x1b'

# Display a menu with cursor navigation
# Arguments:
#   $1 - Menu title
#   $2 - Array name containing menu options (format: "key:label:description")
#   $3 - (Optional) Name of variable to store selected key
# Returns:
#   Selected option key via reference variable
#   Exit code 0 on selection, 1 on cancel
cursor_menu() {
    local title="$1"
    local -n options_ref="$2"
    local -n result_ref="${3:-CURSOR_MENU_RESULT}"

    local selected=0
    local num_options=${#options_ref[@]}

    if [[ $num_options -eq 0 ]]; then
        log_error "No menu options provided"
        return 1
    fi

    # Hide cursor
    tput civis

    while true; do
        # Clear screen and move to top
        clear

        # Show header if function exists
        if declare -f show_header &>/dev/null; then
            show_header
        fi

        # Display menu title
        echo -e "${COLOR_BRIGHT_CYAN}${title}${COLOR_RESET}"
        echo ""

        # Display menu options
        local idx=0
        for option in "${options_ref[@]}"; do
            # Parse option format: "key:label:description"
            IFS=':' read -r key label desc <<< "$option"

            # Highlight selected option
            if [[ $idx -eq $selected ]]; then
                echo -e "${COLOR_BRIGHT_GREEN}${SYMBOL_ARROW} [$key]${COLOR_RESET} ${COLOR_WHITE}${COLOR_BOLD}$label${COLOR_RESET} ${COLOR_CYAN}$desc${COLOR_RESET}"
            else
                echo -e "  ${COLOR_YELLOW}[$key]${COLOR_RESET} ${COLOR_WHITE}$label${COLOR_RESET} ${COLOR_CYAN}$desc${COLOR_RESET}"
            fi

            ((idx++))
        done

        echo ""
        echo -e "${COLOR_CYAN}Use ↑↓ arrows to navigate, Enter to select, Q to go back${COLOR_RESET}"
        echo -n ""

        # Read single character
        local key_pressed
        IFS= read -rsn1 key_pressed

        # Handle escape sequences (arrow keys)
        if [[ $key_pressed == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key_pressed

            case "$key_pressed" in
                '[A') # Up arrow
                    ((selected--))
                    if [[ $selected -lt 0 ]]; then
                        selected=$((num_options - 1))
                    fi
                    ;;
                '[B') # Down arrow
                    ((selected++))
                    if [[ $selected -ge $num_options ]]; then
                        selected=0
                    fi
                    ;;
            esac
        # Handle Enter key
        elif [[ $key_pressed == "" ]]; then
            local selected_option="${options_ref[$selected]}"
            IFS=':' read -r key label desc <<< "$selected_option"
            result_ref="$key"
            tput cnorm # Show cursor
            return 0
        # Handle Q/q for quit/back
        elif [[ $key_pressed == "q" || $key_pressed == "Q" ]]; then
            result_ref="B"
            tput cnorm # Show cursor
            return 1
        # Handle number/letter direct selection
        else
            # Try to find matching option by key
            for idx in "${!options_ref[@]}"; do
                local option="${options_ref[$idx]}"
                IFS=':' read -r key label desc <<< "$option"
                if [[ ${key,,} == ${key_pressed,,} ]]; then
                    result_ref="$key"
                    tput cnorm # Show cursor
                    return 0
                fi
            done
        fi
    done

    tput cnorm # Show cursor
    return 1
}

# Create main menu with cursor navigation
show_main_menu_cursor() {
    local -a menu_options=(
        "1:Single Operations:Process one folder at a time"
        "2:Batch Operations:Process multiple folders"
        "3:Workflows:Pre-configured multi-step operations"
        "4:Find Duplicates:Detect duplicate video files"
        "5:Subtitles (Whisper AI):Generate and manage subtitles"
        "6:Organize by Subfolder:Sort files by folder names"
        "7:Media Catalog:Index and manage video library"
        "8:Utilities:Logs, stats, and system tools"
        "9:Settings:Configure application settings"
        "Q:Exit:Quit Video Manager"
    )

    local choice
    cursor_menu "Main Menu" menu_options choice
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo "$choice"
        return 0
    else
        return 1
    fi
}

# Create single operations menu with cursor navigation
show_single_operations_menu_cursor() {
    local -a menu_options=(
        "1:Rename Files:[Studio] Bracket notation"
        "2:Flatten Directory:Move files from subdirectories"
        "3:Deep Clean:Remove dashes and fix spacing"
        "4:Batch Process:Multiple folders at once"
        "D:Toggle Dry Run:Currently: $([[ "$DRY_RUN" == true ]] && echo "ON" || echo "OFF")"
        "B:Back:Return to Main Menu"
    )

    local choice
    cursor_menu "Single Operations" menu_options choice
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo "$choice"
        return 0
    else
        return 1
    fi
}

# Create batch menu with cursor navigation
show_batch_menu_cursor() {
    local -a menu_options=(
        "1:Batch Rename:Multiple Folders"
        "2:Batch Flatten:Multiple Folders"
        "3:Batch Full Cleanup:Rename + Flatten combined"
        "B:Back:Return to Main Menu"
    )

    local choice
    cursor_menu "Batch Operations" menu_options choice
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo "$choice"
        return 0
    else
        return 1
    fi
}

# Create workflow menu with cursor navigation
show_workflow_menu_cursor() {
    local -a menu_options=(
        "1:New Collection Setup:Flatten + Rename + Find Duplicates"
        "2:Deep Clean Existing:Remove Dashes + Fix Spacing + Brackets"
        "B:Back:Return to Main Menu"
    )

    local choice
    cursor_menu "Workflows" menu_options choice
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo "$choice"
        return 0
    else
        return 1
    fi
}

# Create duplicate menu with cursor navigation
show_duplicate_menu_cursor() {
    local -a menu_options=(
        "1:Find Duplicates:Report only (Safe)"
        "2:Find and Delete:Remove duplicates automatically"
        "3:Find Duplicates (Dry Run):Preview what would be found"
        "B:Back:Return to Main Menu"
    )

    local choice
    cursor_menu "Duplicate Detection" menu_options choice
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo "$choice"
        return 0
    else
        return 1
    fi
}

# Create subtitle menu with cursor navigation
show_subtitle_menu_cursor() {
    local -a menu_options=(
        "1:Generate Subtitles:Single directory"
        "2:Batch Generate:Multiple directories"
        "3:Configure Settings:Model, format, GPU, etc."
        "4:Advanced Options:Parallel, diarization, filters"
        "5:Edit Existing:Modify subtitle file"
        "6:Check Installation:Verify Whisper setup"
        "B:Back:Return to Main Menu"
    )

    local choice
    cursor_menu "Subtitle Generation (Whisper AI)" menu_options choice
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo "$choice"
        return 0
    else
        return 1
    fi
}

# Create utilities menu with cursor navigation
show_utilities_menu_cursor() {
    local -a menu_options=(
        "1:View Logs:Recent operation logs"
        "2:Show Statistics:Processing statistics"
        "3:Test Transformations:Preview filename changes"
        "4:Manage Favorites:Quick access folders"
        "5:Manage Watch Folders:Auto-process locations"
        "6:Test Filename Transform:Preview one file"
        "7:System Information:Platform and dependencies"
        "B:Back:Return to Main Menu"
    )

    local choice
    cursor_menu "Utilities" menu_options choice
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo "$choice"
        return 0
    else
        return 1
    fi
}

# Create settings menu with cursor navigation
show_settings_menu_cursor() {
    local -a menu_options=(
        "1:Organize Settings:Configure file organization"
        "2:Granular Controls:Fine-tune operations"
        "3:Subtitle Settings:Whisper configuration"
        "4:Catalog Settings:Media catalog options"
        "5:View Extensions:Supported video formats"
        "6:Save Configuration:Save current settings"
        "7:Load Configuration:Load saved profile"
        "8:List Profiles:View saved profiles"
        "9:Delete Profile:Remove saved profile"
        "B:Back:Return to Main Menu"
    )

    local choice
    cursor_menu "Settings" menu_options choice
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo "$choice"
        return 0
    else
        return 1
    fi
}

# Check if terminal supports cursor navigation
check_cursor_support() {
    # Check if we're in an interactive terminal
    if [[ ! -t 0 ]]; then
        return 1
    fi

    # Check if tput is available
    if ! command -v tput &>/dev/null; then
        return 1
    fi

    # Check if terminal supports required features
    if ! tput civis &>/dev/null; then
        return 1
    fi

    return 0
}

# Initialize cursor menu support
init_cursor_menu() {
    if check_cursor_support; then
        export CURSOR_MENU_ENABLED=true
        log_info "Cursor menu navigation enabled"
    else
        export CURSOR_MENU_ENABLED=false
        log_info "Cursor menu navigation not supported, using standard menus"
    fi
}

# Wrapper function to use cursor or standard menu based on support
smart_menu() {
    local menu_function="$1"

    if [[ "$CURSOR_MENU_ENABLED" == true ]]; then
        # Use cursor-based menu
        "${menu_function}_cursor"
    else
        # Use standard menu
        "$menu_function"
        read -r choice
        echo "$choice"
    fi
}
