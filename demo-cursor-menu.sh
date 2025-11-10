#!/bin/bash
################################################################################
#
#  CURSOR MENU NAVIGATION DEMO
#
#  This script demonstrates the new cursor-based menu navigation system
#  Run this to test and preview the arrow key menu navigation
#
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Load required modules
echo "Loading modules..."

# Load core (for colors and constants)
if [[ -f "$LIB_DIR/core.sh" ]]; then
    source "$LIB_DIR/core.sh"
    init_core
else
    # Fallback if core.sh not available
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_BOLD='\033[1m'
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[0;33m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_WHITE='\033[0;37m'
    readonly COLOR_BRIGHT_GREEN='\033[1;32m'
    readonly COLOR_BRIGHT_CYAN='\033[1;36m'
    readonly SYMBOL_CHECK="✓"
    readonly SYMBOL_ARROW="→"
fi

# Load logging (for log functions)
if [[ -f "$LIB_DIR/logging.sh" ]]; then
    source "$LIB_DIR/logging.sh"
    init_logging
else
    # Fallback logging
    log_info() { echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $*"; }
    log_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"; }
    log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"; }
fi

# Show header function (for menus)
show_header() {
    echo -e "${COLOR_BRIGHT_CYAN}╔════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}║${COLOR_RESET}    ${COLOR_BOLD}${COLOR_WHITE}Video Manager Ultimate - Bash Edition${COLOR_RESET}                  ${COLOR_BRIGHT_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}║${COLOR_RESET}    ${COLOR_CYAN}Cursor Menu Navigation Demo${COLOR_RESET}                            ${COLOR_BRIGHT_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}╚════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

# Load cursor menu navigation module
if [[ ! -f "$LIB_DIR/menu-navigation.sh" ]]; then
    log_error "menu-navigation.sh not found in $LIB_DIR"
    exit 1
fi

source "$LIB_DIR/menu-navigation.sh"
log_success "Cursor menu navigation module loaded"

# Initialize cursor menu
init_cursor_menu

echo ""
echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
echo -e "${COLOR_WHITE}${COLOR_BOLD}How to use cursor menu navigation:${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
echo ""
echo -e "  ${COLOR_GREEN}↑${COLOR_RESET} ${COLOR_WHITE}Up Arrow${COLOR_RESET}    - Move selection up"
echo -e "  ${COLOR_GREEN}↓${COLOR_RESET} ${COLOR_WHITE}Down Arrow${COLOR_RESET}  - Move selection down"
echo -e "  ${COLOR_GREEN}Enter${COLOR_RESET}           - Confirm selection"
echo -e "  ${COLOR_GREEN}Q${COLOR_RESET}               - Quit / Go back"
echo -e "  ${COLOR_GREEN}Number/Letter${COLOR_RESET}  - Quick select option"
echo ""
echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
echo ""
read -p "Press Enter to start demo..."

# Demo function
run_demo() {
    while true; do
        clear
        show_header

        # Show main menu
        choice=$(show_main_menu_cursor)
        result=$?

        if [[ $result -ne 0 ]]; then
            # User pressed Q or ESC
            clear
            echo -e "${COLOR_BRIGHT_CYAN}${SYMBOL_CHECK}${COLOR_RESET} ${COLOR_WHITE}Thank you for trying cursor menu navigation!${COLOR_RESET}"
            echo ""
            exit 0
        fi

        # Handle menu choice
        case "$choice" in
            1)
                # Single Operations
                while true; do
                    choice=$(show_single_operations_menu_cursor)
                    result=$?

                    if [[ $result -ne 0 ]]; then
                        break
                    fi

                    case "$choice" in
                        1|2|3|4)
                            clear
                            show_header
                            echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}Option $choice selected${COLOR_RESET}"
                            echo ""
                            echo -e "${COLOR_CYAN}This is a demo. In the full version, this would execute the selected operation.${COLOR_RESET}"
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        D|d)
                            clear
                            show_header
                            echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}Dry Run toggled${COLOR_RESET}"
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        B|b)
                            break
                            ;;
                    esac
                done
                ;;
            2)
                # Batch Operations
                while true; do
                    choice=$(show_batch_menu_cursor)
                    result=$?

                    if [[ $result -ne 0 ]]; then
                        break
                    fi

                    case "$choice" in
                        1|2|3)
                            clear
                            show_header
                            echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}Batch option $choice selected${COLOR_RESET}"
                            echo ""
                            echo -e "${COLOR_CYAN}This is a demo. In the full version, this would execute the batch operation.${COLOR_RESET}"
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        B|b)
                            break
                            ;;
                    esac
                done
                ;;
            3)
                # Workflows
                while true; do
                    choice=$(show_workflow_menu_cursor)
                    result=$?

                    if [[ $result -ne 0 ]]; then
                        break
                    fi

                    case "$choice" in
                        1|2)
                            clear
                            show_header
                            echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}Workflow $choice selected${COLOR_RESET}"
                            echo ""
                            echo -e "${COLOR_CYAN}This is a demo. In the full version, this would execute the workflow.${COLOR_RESET}"
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        B|b)
                            break
                            ;;
                    esac
                done
                ;;
            4)
                # Duplicates
                while true; do
                    choice=$(show_duplicate_menu_cursor)
                    result=$?

                    if [[ $result -ne 0 ]]; then
                        break
                    fi

                    case "$choice" in
                        1|2|3)
                            clear
                            show_header
                            echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}Duplicate detection option $choice selected${COLOR_RESET}"
                            echo ""
                            echo -e "${COLOR_CYAN}This is a demo. In the full version, this would find/delete duplicates.${COLOR_RESET}"
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        B|b)
                            break
                            ;;
                    esac
                done
                ;;
            5)
                # Subtitles
                while true; do
                    choice=$(show_subtitle_menu_cursor)
                    result=$?

                    if [[ $result -ne 0 ]]; then
                        break
                    fi

                    case "$choice" in
                        1|2|3|4|5|6)
                            clear
                            show_header
                            echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}Subtitle option $choice selected${COLOR_RESET}"
                            echo ""
                            echo -e "${COLOR_CYAN}This is a demo. In the full version, this would handle subtitle operations.${COLOR_RESET}"
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        B|b)
                            break
                            ;;
                    esac
                done
                ;;
            6|7)
                clear
                show_header
                echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}Option $choice selected${COLOR_RESET}"
                echo ""
                echo -e "${COLOR_CYAN}This is a demo. In the full version, this would execute the operation.${COLOR_RESET}"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                # Utilities
                while true; do
                    choice=$(show_utilities_menu_cursor)
                    result=$?

                    if [[ $result -ne 0 ]]; then
                        break
                    fi

                    case "$choice" in
                        1|2|3|4|5|6|7)
                            clear
                            show_header
                            echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}Utilities option $choice selected${COLOR_RESET}"
                            echo ""
                            echo -e "${COLOR_CYAN}This is a demo. In the full version, this would execute the utility.${COLOR_RESET}"
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        B|b)
                            break
                            ;;
                    esac
                done
                ;;
            9)
                # Settings
                while true; do
                    choice=$(show_settings_menu_cursor)
                    result=$?

                    if [[ $result -ne 0 ]]; then
                        break
                    fi

                    case "$choice" in
                        1|2|3|4|5|6|7|8|9)
                            clear
                            show_header
                            echo -e "${COLOR_GREEN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}Settings option $choice selected${COLOR_RESET}"
                            echo ""
                            echo -e "${COLOR_CYAN}This is a demo. In the full version, this would open the settings.${COLOR_RESET}"
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        B|b)
                            break
                            ;;
                    esac
                done
                ;;
            Q|q)
                clear
                echo -e "${COLOR_BRIGHT_CYAN}${SYMBOL_CHECK}${COLOR_RESET} ${COLOR_WHITE}Thank you for trying cursor menu navigation!${COLOR_RESET}"
                echo ""
                exit 0
                ;;
        esac
    done
}

# Run the demo
run_demo
