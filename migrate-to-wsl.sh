#!/bin/bash

################################################################################
#
#  VIDEO MANAGER ULTIMATE - WSL MIGRATION SCRIPT
#
#  Helps you migrate Video Manager Ultimate from Windows to WSL
#  This script will:
#  - Clone/copy the repository to WSL
#  - Migrate configuration and settings
#  - Update paths from Windows to WSL format
#  - Set up dependencies
#  - Test the installation
#
#  Author: Video Manager Ultimate Team
#  Version: 1.0.0
#  Date: November 2025
#
################################################################################

# Colors
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BRIGHT_CYAN='\033[1;36m'
readonly COLOR_BRIGHT_GREEN='\033[1;32m'
readonly COLOR_BRIGHT_YELLOW='\033[1;33m'

# Symbols
readonly SYMBOL_CHECK="✓"
readonly SYMBOL_CROSS="✗"
readonly SYMBOL_ARROW="→"
readonly SYMBOL_STAR="★"
readonly SYMBOL_INFO="ℹ"
readonly SYMBOL_WARN="⚠"

# Script configuration
MIGRATION_LOG="$HOME/vmgr-wsl-migration-$(date +%Y%m%d-%H%M%S).log"
TEMP_DIR="/tmp/vmgr-migration-$$"
BACKUP_DIR="$HOME/vmgr-migration-backup-$(date +%Y%m%d-%H%M%S)"

# Functions
log_message() {
    local message="$1"
    echo -e "$message" | tee -a "$MIGRATION_LOG"
}

show_header() {
    clear
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╔═══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}    ${COLOR_BOLD}${COLOR_YELLOW}VIDEO MANAGER ULTIMATE - WSL MIGRATION TOOL${COLOR_RESET}        ${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╚═══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

check_wsl() {
    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Checking if running in WSL..."

    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Running in WSL"
        return 0
    else
        log_message "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Not running in WSL!"
        log_message "${COLOR_YELLOW}This script must be run from within WSL.${COLOR_RESET}"
        log_message ""
        log_message "${COLOR_CYAN}To install WSL:${COLOR_RESET}"
        log_message "  1. Open PowerShell as Administrator"
        log_message "  2. Run: ${COLOR_WHITE}wsl --install${COLOR_RESET}"
        log_message "  3. Restart your computer"
        log_message "  4. Launch WSL and run this script again"
        exit 1
    fi
}

check_git() {
    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Checking for git..."

    if command -v git &>/dev/null; then
        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} git is installed"
        return 0
    else
        log_message "${COLOR_YELLOW}${SYMBOL_WARN}${COLOR_RESET} git is not installed"
        log_message "${COLOR_CYAN}Installing git...${COLOR_RESET}"
        sudo apt-get update && sudo apt-get install -y git

        if command -v git &>/dev/null; then
            log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} git installed successfully"
            return 0
        else
            log_message "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Failed to install git"
            return 1
        fi
    fi
}

convert_windows_to_wsl_path() {
    local win_path="$1"

    # Check if already a Unix path
    if [[ "$win_path" =~ ^/ ]]; then
        echo "$win_path"
        return 0
    fi

    # Convert C:\path\to\file to /mnt/c/path/to/file
    if [[ "$win_path" =~ ^([A-Za-z]): ]]; then
        local drive_letter="${BASH_REMATCH[1],,}"  # Convert to lowercase
        local path_part="${win_path#*:}"
        path_part="${path_part//\\//}"  # Replace backslashes with forward slashes
        echo "/mnt/$drive_letter$path_part"
    else
        echo "$win_path"
    fi
}

find_windows_installation() {
    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Searching for existing Windows installation..."

    local common_paths=(
        "/mnt/c/Users/$USER/vmgr"
        "/mnt/c/Users/$USER/Documents/vmgr"
        "/mnt/c/Users/$USER/Desktop/vmgr"
        "/mnt/c/Users/$USER/Downloads/vmgr"
        "/mnt/c/vmgr"
        "/mnt/d/vmgr"
    )

    for path in "${common_paths[@]}"; do
        if [[ -d "$path" ]] && [[ -f "$path/video-manager-ultimate.sh" ]]; then
            log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Found installation at: $path"
            echo "$path"
            return 0
        fi
    done

    log_message "${COLOR_YELLOW}${SYMBOL_WARN}${COLOR_RESET} No existing installation found in common locations"
    return 1
}

migrate_from_directory() {
    local source_dir="$1"
    local target_dir="$2"

    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Migrating from: $source_dir"
    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} To: $target_dir"

    # Create target directory
    mkdir -p "$target_dir"

    # Copy files
    log_message "${COLOR_CYAN}Copying files...${COLOR_RESET}"
    if cp -r "$source_dir"/* "$target_dir/" 2>>"$MIGRATION_LOG"; then
        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Files copied successfully"
    else
        log_message "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Error copying files"
        return 1
    fi

    # Make scripts executable
    chmod +x "$target_dir"/*.sh 2>/dev/null

    # Migrate logs if they exist
    if [[ -d "/mnt/c/Users/$USER/.video-manager-logs" ]]; then
        log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Migrating logs..."
        mkdir -p "$HOME/.video-manager-logs"
        cp -r "/mnt/c/Users/$USER/.video-manager-logs"/* "$HOME/.video-manager-logs/" 2>/dev/null
        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Logs migrated"
    fi

    return 0
}

clone_from_git() {
    local target_dir="$1"

    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Cloning from GitHub..."

    if git clone https://github.com/emaag/vmgr.git "$target_dir" 2>>"$MIGRATION_LOG"; then
        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Repository cloned successfully"
        return 0
    else
        log_message "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Failed to clone repository"
        return 1
    fi
}

install_dependencies() {
    log_message ""
    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Installing dependencies..."

    log_message "${COLOR_CYAN}Updating package lists...${COLOR_RESET}"
    sudo apt-get update >>"$MIGRATION_LOG" 2>&1

    local packages=(
        "jq"
        "ffmpeg"
        "libimage-exiftool-perl"
        "imagemagick"
        "bc"
        "curl"
    )

    log_message "${COLOR_CYAN}Installing packages: ${packages[*]}${COLOR_RESET}"

    if sudo apt-get install -y "${packages[@]}" >>"$MIGRATION_LOG" 2>&1; then
        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Dependencies installed"
        return 0
    else
        log_message "${COLOR_YELLOW}${SYMBOL_WARN}${COLOR_RESET} Some dependencies may not have installed"
        return 1
    fi
}

setup_vmgr() {
    local install_dir="$1"

    log_message ""
    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Setting up Video Manager Ultimate..."

    # Create bin directory
    mkdir -p "$HOME/bin"

    # Create symlink
    local target="$HOME/bin/vmgr"
    if [[ -L "$target" ]] || [[ -f "$target" ]]; then
        rm -f "$target"
    fi

    ln -s "$install_dir/video-manager-ultimate.sh" "$target"
    log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Created symlink: ~/bin/vmgr"

    # Add ~/bin to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
            echo '' >> "$HOME/.bashrc"
            echo '# Video Manager Ultimate' >> "$HOME/.bashrc"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
            log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Added ~/bin to PATH in ~/.bashrc"
        fi
    else
        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} ~/bin already in PATH"
    fi

    # Setup bash completion if it exists
    if [[ -f "$install_dir/vmgr-completion.bash" ]]; then
        mkdir -p "$HOME/.bash_completion.d"
        cp "$install_dir/vmgr-completion.bash" "$HOME/.bash_completion.d/vmgr"

        if ! grep -q "bash_completion.d/vmgr" "$HOME/.bashrc" 2>/dev/null; then
            echo '' >> "$HOME/.bashrc"
            echo '# Video Manager Ultimate completion' >> "$HOME/.bashrc"
            echo '[[ -f ~/.bash_completion.d/vmgr ]] && source ~/.bash_completion.d/vmgr' >> "$HOME/.bashrc"
        fi

        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Bash completion installed"
    fi

    return 0
}

configure_wsl_settings() {
    log_message ""
    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Configuring WSL settings..."

    # Create/update .wslconfig in Windows user directory
    local wslconfig="/mnt/c/Users/$USER/.wslconfig"

    if [[ -w "/mnt/c/Users/$USER" ]]; then
        cat > "$wslconfig" << 'EOF'
[wsl2]
# Limit memory usage (recommended: half of your RAM)
memory=8GB

# Limit processors
processors=4

# Enable localhost forwarding
localhostForwarding=true

# Swap size
swap=2GB
EOF
        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Created .wslconfig with recommended settings"
        log_message "${COLOR_YELLOW}${SYMBOL_INFO}${COLOR_RESET} Restart WSL for these settings to take effect:"
        log_message "  ${COLOR_WHITE}wsl --shutdown${COLOR_RESET} (run in PowerShell)"
    else
        log_message "${COLOR_YELLOW}${SYMBOL_WARN}${COLOR_RESET} Could not write .wslconfig (run as admin if needed)"
    fi
}

test_installation() {
    local install_dir="$1"

    log_message ""
    log_message "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Testing installation..."

    # Test script execution
    if "$install_dir/video-manager-ultimate.sh" --version &>/dev/null; then
        log_message "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Script runs successfully"
    else
        log_message "${COLOR_YELLOW}${SYMBOL_WARN}${COLOR_RESET} Script test failed (may be normal)"
    fi

    # Check dependencies
    log_message ""
    log_message "${COLOR_CYAN}Dependency Check:${COLOR_RESET}"

    command -v jq &>/dev/null && \
        log_message "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} jq" || \
        log_message "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} jq (required)"

    command -v ffprobe &>/dev/null && \
        log_message "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} ffprobe" || \
        log_message "  ${COLOR_YELLOW}${SYMBOL_CROSS}${COLOR_RESET} ffprobe (optional)"

    command -v exiftool &>/dev/null && \
        log_message "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} exiftool" || \
        log_message "  ${COLOR_YELLOW}${SYMBOL_CROSS}${COLOR_RESET} exiftool (optional)"
}

show_completion_message() {
    local install_dir="$1"

    echo ""
    log_message "${COLOR_BOLD}${COLOR_BRIGHT_GREEN}╔═══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    log_message "${COLOR_BOLD}${COLOR_BRIGHT_GREEN}║${COLOR_RESET}                  ${COLOR_BOLD}MIGRATION COMPLETE!${COLOR_RESET}                       ${COLOR_BOLD}${COLOR_BRIGHT_GREEN}║${COLOR_RESET}"
    log_message "${COLOR_BOLD}${COLOR_BRIGHT_GREEN}╚═══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    log_message "${COLOR_YELLOW}${SYMBOL_STAR} Installation Location:${COLOR_RESET}"
    log_message "  ${COLOR_WHITE}$install_dir${COLOR_RESET}"
    echo ""
    log_message "${COLOR_YELLOW}${SYMBOL_STAR} Next Steps:${COLOR_RESET}"
    echo ""
    log_message "  1. ${COLOR_CYAN}Reload your shell:${COLOR_RESET}"
    log_message "     ${COLOR_WHITE}source ~/.bashrc${COLOR_RESET}"
    echo ""
    log_message "  2. ${COLOR_CYAN}Run Video Manager:${COLOR_RESET}"
    log_message "     ${COLOR_WHITE}vmgr${COLOR_RESET}"
    echo ""
    log_message "  3. ${COLOR_CYAN}Access your Windows files:${COLOR_RESET}"
    log_message "     ${COLOR_WHITE}/mnt/c/Users/$USER/Videos${COLOR_RESET}"
    echo ""
    log_message "${COLOR_YELLOW}${SYMBOL_STAR} Important Notes:${COLOR_RESET}"
    echo ""
    log_message "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Windows files are accessible via /mnt/c/, /mnt/d/, etc."
    log_message "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} WSL files are faster for operations (copy to WSL first)"
    log_message "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} You can access WSL from Windows at: ${COLOR_WHITE}\\\\wsl$\\Ubuntu${COLOR_RESET}"
    log_message "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Migration log: ${COLOR_WHITE}$MIGRATION_LOG${COLOR_RESET}"
    echo ""
    log_message "${COLOR_YELLOW}${SYMBOL_STAR} Performance Tips:${COLOR_RESET}"
    echo ""
    log_message "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Store videos in WSL filesystem for best performance:"
    log_message "     ${COLOR_WHITE}~/Videos${COLOR_RESET} instead of ${COLOR_WHITE}/mnt/c/Users/$USER/Videos${COLOR_RESET}"
    echo ""
    log_message "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Use Windows Terminal for better experience"
    log_message "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Consider WSL 2 for better performance (already default)"
    echo ""
}

# Main migration process
main() {
    show_header

    # Check if running in WSL
    check_wsl

    # Check for git
    check_git

    echo ""
    log_message "${COLOR_CYAN}This tool will help you migrate Video Manager Ultimate to WSL.${COLOR_RESET}"
    echo ""
    log_message "${COLOR_YELLOW}${SYMBOL_INFO} Migration Log: ${COLOR_WHITE}$MIGRATION_LOG${COLOR_RESET}"
    echo ""

    # Determine installation method
    log_message "${COLOR_YELLOW}${SYMBOL_STAR} Choose migration method:${COLOR_RESET}"
    echo ""
    log_message "  ${COLOR_WHITE}1)${COLOR_RESET} Copy from existing Windows installation"
    log_message "  ${COLOR_WHITE}2)${COLOR_RESET} Clone fresh from GitHub"
    log_message "  ${COLOR_WHITE}3)${COLOR_RESET} Auto-detect (search for Windows installation)"
    echo ""

    read -p "Enter choice (1-3): " -n 1 -r choice
    echo ""
    echo ""

    # Determine target directory
    local default_target="$HOME/vmgr"
    log_message "${COLOR_CYAN}Where would you like to install Video Manager?${COLOR_RESET}"
    log_message "${COLOR_YELLOW}Press Enter for default: ${COLOR_WHITE}$default_target${COLOR_RESET}"
    read -p "Installation directory: " target_dir

    target_dir="${target_dir:-$default_target}"

    # Handle the choice
    case "$choice" in
        1)
            echo ""
            log_message "${COLOR_CYAN}Enter the Windows path to your existing installation:${COLOR_RESET}"
            log_message "${COLOR_YELLOW}Example: C:\\Users\\$USER\\vmgr${COLOR_RESET}"
            read -p "Windows path: " windows_path

            local source_dir=$(convert_windows_to_wsl_path "$windows_path")

            if [[ ! -d "$source_dir" ]]; then
                log_message "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Directory not found: $source_dir"
                exit 1
            fi

            migrate_from_directory "$source_dir" "$target_dir"
            ;;

        2)
            clone_from_git "$target_dir"
            ;;

        3)
            local found_dir=$(find_windows_installation)
            if [[ -n "$found_dir" ]]; then
                migrate_from_directory "$found_dir" "$target_dir"
            else
                log_message "${COLOR_YELLOW}${SYMBOL_INFO}${COLOR_RESET} Falling back to GitHub clone..."
                clone_from_git "$target_dir"
            fi
            ;;

        *)
            log_message "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Invalid choice"
            exit 1
            ;;
    esac

    # Install dependencies
    echo ""
    read -p "Install required dependencies? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_dependencies
    fi

    # Setup vmgr
    setup_vmgr "$target_dir"

    # Configure WSL settings
    echo ""
    read -p "Configure WSL performance settings? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        configure_wsl_settings
    fi

    # Test installation
    test_installation "$target_dir"

    # Show completion message
    show_completion_message "$target_dir"
}

# Cleanup on exit
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# Run migration
main "$@"
