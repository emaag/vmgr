#!/bin/bash

################################################################################
# Video Manager Ultimate - Installation Script
# Supports: Linux, macOS, Windows (Git Bash), WSL
################################################################################

# Colors
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_BRIGHT_CYAN='\033[1;36m'
readonly COLOR_BRIGHT_GREEN='\033[1;32m'

# Symbols
readonly SYMBOL_CHECK="✓"
readonly SYMBOL_CROSS="✗"
readonly SYMBOL_ARROW="→"
readonly SYMBOL_STAR="★"

# Detect OS
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
}

# Show header
show_header() {
    clear
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╔═══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}       ${COLOR_BOLD}${COLOR_YELLOW}VIDEO MANAGER ULTIMATE - INSTALLER${COLOR_RESET}              ${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╚═══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Install dependencies
install_dependencies() {
    echo -e "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Installing dependencies for ${COLOR_BOLD}$OS_TYPE${COLOR_RESET}..."
    echo ""

    case "$OS_TYPE" in
        Linux|WSL)
            echo -e "${COLOR_YELLOW}Required packages: jq${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}Optional packages: ffmpeg, libimage-exiftool-perl, imagemagick${COLOR_RESET}"
            echo ""
            read -p "Install packages? (y/n): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if command_exists sudo; then
                    sudo apt-get update
                    sudo apt-get install -y jq ffmpeg libimage-exiftool-perl imagemagick
                    echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Dependencies installed!"
                else
                    echo -e "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} sudo not available. Please install manually:"
                    echo "  apt-get install jq ffmpeg libimage-exiftool-perl imagemagick"
                fi
            fi
            ;;

        macOS)
            echo -e "${COLOR_YELLOW}Required packages: jq${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}Optional packages: ffmpeg, exiftool, imagemagick${COLOR_RESET}"
            echo ""
            if ! command_exists brew; then
                echo -e "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Homebrew not found!"
                echo ""
                echo "Install Homebrew first:"
                echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
                echo ""
                read -p "Open Homebrew installation page? (y/n): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    open "https://brew.sh"
                fi
                return 1
            fi

            read -p "Install packages with Homebrew? (y/n): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                brew install jq ffmpeg exiftool imagemagick
                echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Dependencies installed!"
            fi
            ;;

        Windows)
            echo -e "${COLOR_YELLOW}For Windows (Git Bash), you need to manually install:${COLOR_RESET}"
            echo ""
            echo "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} jq: https://stedolan.github.io/jq/download/"
            echo "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} ffmpeg: https://ffmpeg.org/download.html"
            echo ""
            echo "Place executables in: C:\\Program Files\\Git\\usr\\bin\\"
            echo ""
            read -p "Press Enter to continue..."
            ;;
    esac
}

# Setup bash completion
setup_completion() {
    echo ""
    echo -e "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Setting up bash completion..."

    case "$OS_TYPE" in
        Linux|WSL)
            # Try user completion directory first
            local completion_dir="$HOME/.bash_completion.d"
            if [[ ! -d "$completion_dir" ]]; then
                mkdir -p "$completion_dir"
            fi

            # Copy completion file
            cp vmgr-completion.bash "$completion_dir/vmgr"
            echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Completion file installed to ~/.bash_completion.d/"

            # Add sourcing to bashrc if not already there
            local shell_rc="$HOME/.bashrc"
            if ! grep -q "bash_completion.d/vmgr" "$shell_rc" 2>/dev/null; then
                echo "" >> "$shell_rc"
                echo "# Video Manager Ultimate completion" >> "$shell_rc"
                echo "[[ -f ~/.bash_completion.d/vmgr ]] && source ~/.bash_completion.d/vmgr" >> "$shell_rc"
                echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Completion added to ~/.bashrc"
            fi
            ;;

        macOS)
            # macOS uses different completion path
            local completion_dir="/usr/local/etc/bash_completion.d"
            if [[ -d "$completion_dir" ]] && [[ -w "$completion_dir" ]]; then
                cp vmgr-completion.bash "$completion_dir/vmgr"
                echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Completion file installed to $completion_dir"
            else
                # Fallback to user directory
                completion_dir="$HOME/.bash_completion.d"
                mkdir -p "$completion_dir"
                cp vmgr-completion.bash "$completion_dir/vmgr"

                local shell_rc="$HOME/.zshrc"
                [[ -f "$HOME/.bash_profile" ]] && shell_rc="$HOME/.bash_profile"

                if ! grep -q "bash_completion.d/vmgr" "$shell_rc" 2>/dev/null; then
                    echo "" >> "$shell_rc"
                    echo "# Video Manager Ultimate completion" >> "$shell_rc"
                    echo "[[ -f ~/.bash_completion.d/vmgr ]] && source ~/.bash_completion.d/vmgr" >> "$shell_rc"
                fi
                echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Completion added to $shell_rc"
            fi
            ;;

        Windows)
            # Git Bash completion
            local completion_dir="$HOME/.bash_completion.d"
            mkdir -p "$completion_dir"
            cp vmgr-completion.bash "$completion_dir/vmgr"

            local shell_rc="$HOME/.bashrc"
            if ! grep -q "bash_completion.d/vmgr" "$shell_rc" 2>/dev/null; then
                echo "" >> "$shell_rc"
                echo "# Video Manager Ultimate completion" >> "$shell_rc"
                echo "[[ -f ~/.bash_completion.d/vmgr ]] && source ~/.bash_completion.d/vmgr" >> "$shell_rc"
            fi
            echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Completion setup complete"
            ;;
    esac

    echo -e "${COLOR_YELLOW}Note:${COLOR_RESET} Restart your shell or run 'source ~/.bashrc' to enable completion"
}

# Setup script
setup_script() {
    echo ""
    echo -e "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Setting up Video Manager Ultimate..."
    echo ""

    # Make script executable
    chmod +x video-manager-ultimate.sh
    echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Script permissions set"

    # Create bin directory
    mkdir -p "$HOME/bin"

    # Create symlink
    local target="$HOME/bin/vmgr"
    if [[ -L "$target" ]] || [[ -f "$target" ]]; then
        rm -f "$target"
    fi

    ln -s "$(pwd)/video-manager-ultimate.sh" "$target"
    echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Created symlink: ~/bin/vmgr"

    # Setup bash completion
    setup_completion

    # Check if ~/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo ""
        echo -e "${COLOR_YELLOW}${SYMBOL_STAR} Add ~/bin to your PATH:${COLOR_RESET}"

        case "$OS_TYPE" in
            macOS)
                local shell_rc="$HOME/.zshrc"
                [[ -f "$HOME/.bash_profile" ]] && shell_rc="$HOME/.bash_profile"
                ;;
            *)
                local shell_rc="$HOME/.bashrc"
                ;;
        esac

        echo ""
        echo "  echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> $shell_rc"
        echo "  source $shell_rc"
        echo ""

        read -p "Add to PATH automatically? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo 'export PATH="$HOME/bin:$PATH"' >> "$shell_rc"
            echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} PATH updated in $shell_rc"
            echo -e "${COLOR_YELLOW}Run: ${COLOR_WHITE}source $shell_rc${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} ~/bin already in PATH"
    fi
}

# Test installation
test_installation() {
    echo ""
    echo -e "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Testing installation..."
    echo ""

    # Test if script runs
    if ./video-manager-ultimate.sh --version 2>/dev/null | grep -q "Video Manager"; then
        echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Script runs successfully"
    else
        echo -e "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Script test failed"
        return 1
    fi

    # Check dependencies
    echo ""
    echo "Dependency check:"

    command_exists jq && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} jq" || echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} jq (required)"
    command_exists ffprobe && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} ffprobe" || echo -e "  ${COLOR_YELLOW}${SYMBOL_CROSS}${COLOR_RESET} ffprobe (optional)"
    command_exists exiftool && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} exiftool" || echo -e "  ${COLOR_YELLOW}${SYMBOL_CROSS}${COLOR_RESET} exiftool (optional)"
    command_exists identify && echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} ImageMagick" || echo -e "  ${COLOR_YELLOW}${SYMBOL_CROSS}${COLOR_RESET} ImageMagick (optional)"
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_GREEN}╔═══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_GREEN}║${COLOR_RESET}                  ${COLOR_BOLD}INSTALLATION COMPLETE!${COLOR_RESET}                    ${COLOR_BOLD}${COLOR_BRIGHT_GREEN}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BRIGHT_GREEN}╚═══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}${SYMBOL_STAR} Quick Start:${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Run: ${COLOR_WHITE}vmgr${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Or: ${COLOR_WHITE}./video-manager-ultimate.sh${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}${SYMBOL_STAR} Documentation:${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}README.md${COLOR_RESET} - Overview and features"
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}CROSS-PLATFORM.md${COLOR_RESET} - Platform-specific setup"
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} ${COLOR_WHITE}INSTALLATION-GUIDE.md${COLOR_RESET} - Detailed instructions"
    echo ""
    echo -e "${COLOR_YELLOW}${SYMBOL_STAR} First Steps:${COLOR_RESET}"
    echo ""
    echo -e "  1. ${COLOR_WHITE}Check system info:${COLOR_RESET} vmgr → Utilities → System Information"
    echo -e "  2. ${COLOR_WHITE}Enable dry run:${COLOR_RESET} vmgr → Settings → Toggle Dry Run"
    echo -e "  3. ${COLOR_WHITE}Test on sample folder${COLOR_RESET}"
    echo ""
}

# Main installation
main() {
    detect_os
    show_header

    echo -e "${COLOR_CYAN}Platform detected: ${COLOR_BOLD}$OS_TYPE${COLOR_RESET}"
    echo ""

    # Check if we're in the right directory
    if [[ ! -f "video-manager-ultimate.sh" ]]; then
        echo -e "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Error: video-manager-ultimate.sh not found!"
        echo "Please run this script from the vmgr directory"
        exit 1
    fi

    echo -e "${COLOR_YELLOW}This installer will:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Install dependencies (optional)"
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Setup the script"
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Create ~/bin/vmgr symlink"
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Add ~/bin to PATH if needed"
    echo ""

    read -p "Continue with installation? (y/n): " -n 1 -r
    echo ""
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi

    # Install dependencies
    install_dependencies

    # Setup script
    setup_script

    # Test installation
    test_installation

    # Show completion
    show_completion
}

# Run installer
main "$@"
