#!/bin/bash

################################################################################
#
#  VIDEO MANAGER ULTIMATE - BASH EDITION
#
#  A comprehensive video file management system for Linux/WSL
#  Modular architecture with clean separation of concerns
#
#  Author: Created for Eric's Video Management System
#  Version: 1.2.0
#  Date: 2025-12-23
#
#  Features:
#  - Interactive menu system with color-coded output
#  - Command-line argument support for automation
#  - Real-time verbose progress tracking
#  - Comprehensive logging with timestamps
#  - Duplicate detection (exact hash-based)
#  - Directory flattening with conflict resolution
#  - Bracket notation standardization
#  - Automatic subtitle generation (Whisper AI)
#  - Multi-drive catalog system
#  - Batch processing and workflows
#  - Undo/rollback functionality
#
################################################################################

# Get script directory for module loading
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Load all modules in dependency order
echo "Loading Video Manager Ultimate modules..."

if ! source "$LIB_DIR/core.sh"; then
    echo "ERROR: Failed to load core.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/platform.sh"; then
    echo "ERROR: Failed to load platform.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/logging.sh"; then
    echo "ERROR: Failed to load logging.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/config.sh"; then
    echo "ERROR: Failed to load config.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/utils.sh"; then
    echo "ERROR: Failed to load utils.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/file-ops.sh"; then
    echo "ERROR: Failed to load file-ops.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/duplicates.sh"; then
    echo "ERROR: Failed to load duplicates.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/organize.sh"; then
    echo "ERROR: Failed to load organize.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/subtitles.sh"; then
    echo "ERROR: Failed to load subtitles.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/catalog.sh"; then
    echo "ERROR: Failed to load catalog.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/batch.sh"; then
    echo "ERROR: Failed to load batch.sh" >&2
    exit 1
fi

if ! source "$LIB_DIR/ui.sh"; then
    echo "ERROR: Failed to load ui.sh" >&2
    exit 1
fi

# Initialize core module
init_core

# Detect operating system
detect_os

################################################################################
# COMMAND LINE INTERFACE
################################################################################

show_usage() {
    cat << EOF
${COLOR_BOLD}$SCRIPT_NAME v$SCRIPT_VERSION${COLOR_RESET}

${COLOR_BOLD}USAGE:${COLOR_RESET}
    $0 [OPTIONS] [COMMAND] [DIRECTORY]

${COLOR_BOLD}OPTIONS:${COLOR_RESET}
    -h, --help              Show this help message
    -v, --version           Show version information
    -d, --dry-run           Enable dry run mode (no changes made)
    -q, --quiet             Disable verbose output
    -i, --interactive       Launch interactive menu (default if no command)

${COLOR_BOLD}SUBTITLE OPTIONS:${COLOR_RESET}
    --model <model>         Whisper model (tiny, base, small, medium, large)
    --format <format>       Subtitle format (srt, vtt, txt, json)
    --language <lang>       Language code (en, es, fr, etc.) or 'auto'

${COLOR_BOLD}ADVANCED SUBTITLE OPTIONS:${COLOR_RESET}
    --gpu                   Enable GPU acceleration (CUDA)
    --parallel <N>          Parallel jobs (1-8, default: 2)
    --no-optimize           Disable batch optimization
    --edit                  Enable interactive editing mode
    --speaker-diarization   Enable speaker identification
    --no-punctuation        Disable automatic punctuation fixes

${COLOR_BOLD}ORGANIZE OPTIONS:${COLOR_RESET}
    --organize-target <dir> Set default target folder for organize
    --organize-search <dir> Set default search path for organize

${COLOR_BOLD}COMMANDS:${COLOR_RESET}
    rename <dir>            Rename files with bracket notation
    flatten <dir>           Move all videos to top directory
    cleanup <dir>           Full cleanup (rename + spacing fixes)
    duplicates <dir>        Find duplicate files
    subtitles <dir>         Generate subtitles for videos
    workflow-new <dir>      New collection setup workflow
    workflow-clean <dir>    Deep clean workflow
    batch                   Batch process multiple folders
    --organize              Organize files by subfolder names
    --undo-organize [id]    Undo organize operation (optional: operation ID)
    --list-undo             List available undo operations

${COLOR_BOLD}EXAMPLES:${COLOR_RESET}
    # Interactive menu
    $0

    # Rename files in directory
    $0 rename /mnt/c/Users/Eric/Videos

    # Dry run before making changes
    $0 --dry-run rename /mnt/c/Users/Eric/Videos

    # Find duplicates
    $0 duplicates /mnt/c/Users/Eric/Videos

    # Generate subtitles (basic)
    $0 --model base subtitles /mnt/c/Users/Eric/Videos

    # Generate with GPU and parallel processing
    $0 --gpu --parallel 4 --model medium subtitles /mnt/c/Videos

    # Generate with speaker diarization
    $0 --speaker-diarization --model large subtitles /mnt/c/Videos

    # Full workflow for new collection
    $0 workflow-new /mnt/c/Users/Eric/Videos

    # Organize files by subfolder names
    $0 --organize-target /path/to/folders --organize-search /path/to/search --organize

    # Undo last organize operation
    $0 --undo-organize

    # List all available undo operations
    $0 --list-undo

${COLOR_BOLD}SUPPORTED VIDEO FORMATS:${COLOR_RESET}
    mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg, 3gp

${COLOR_BOLD}LOG FILES:${COLOR_RESET}
    Logs are stored in: $LOG_DIR

EOF
}

show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION ($SCRIPT_DATE)"
}

# Parse command line arguments
parse_arguments() {
    local command=""
    local directory=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                log_info "Dry run mode enabled"
                shift
                ;;
            -q|--quiet)
                VERBOSE=false
                shift
                ;;
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            --model)
                shift
                if [[ -n "$1" ]]; then
                    WHISPER_MODEL="$1"
                    log_info "Whisper model set to: $WHISPER_MODEL"
                    shift
                fi
                ;;
            --format)
                shift
                if [[ -n "$1" ]]; then
                    SUBTITLE_FORMAT="$1"
                    log_info "Subtitle format set to: $SUBTITLE_FORMAT"
                    shift
                fi
                ;;
            --language)
                shift
                if [[ -n "$1" ]]; then
                    SUBTITLE_LANGUAGE="$1"
                    log_info "Subtitle language set to: $SUBTITLE_LANGUAGE"
                    shift
                fi
                ;;
            --gpu)
                SUBTITLE_USE_GPU=true
                log_info "GPU acceleration enabled"
                shift
                ;;
            --parallel)
                shift
                if [[ -n "$1" && "$1" =~ ^[1-8]$ ]]; then
                    SUBTITLE_PARALLEL_JOBS="$1"
                    log_info "Parallel jobs set to: $SUBTITLE_PARALLEL_JOBS"
                    shift
                else
                    log_error "Invalid parallel jobs value. Must be 1-8"
                    exit 1
                fi
                ;;
            --no-optimize)
                SUBTITLE_OPTIMIZE_BATCH=false
                log_info "Batch optimization disabled"
                shift
                ;;
            --edit)
                SUBTITLE_INTERACTIVE_EDIT=true
                log_info "Interactive editing enabled"
                shift
                ;;
            --speaker-diarization)
                SUBTITLE_SPEAKER_DIARIZATION=true
                log_info "Speaker diarization enabled"
                shift
                ;;
            --no-punctuation)
                SUBTITLE_AUTO_PUNCTUATION=false
                log_info "Auto-punctuation disabled"
                shift
                ;;
            --organize)
                command="organize"
                shift
                ;;
            --organize-target)
                shift
                if [[ -n "$1" ]]; then
                    ORGANIZE_DEFAULT_TARGET="$1"
                    log_info "Organize target set to: $ORGANIZE_DEFAULT_TARGET"
                    shift
                fi
                ;;
            --organize-search)
                shift
                if [[ -n "$1" ]]; then
                    ORGANIZE_DEFAULT_SEARCH="$1"
                    log_info "Organize search path set to: $ORGANIZE_DEFAULT_SEARCH"
                    shift
                fi
                ;;
            --undo-organize)
                command="undo-organize"
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    # Operation ID provided
                    directory="$1"
                    shift
                fi
                ;;
            --list-undo)
                command="list-undo"
                shift
                ;;
            rename|flatten|cleanup|duplicates|subtitles|workflow-new|workflow-clean|batch)
                command="$1"
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    directory="$1"
                    shift
                fi
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # If no command specified, launch interactive menu
    if [[ -z "$command" ]]; then
        INTERACTIVE=true
        return 0
    fi

    # Validate directory for commands that need it
    if [[ "$command" != "batch" && "$command" != "list-undo" && "$command" != "undo-organize" && "$command" != "organize" ]]; then
        if [[ -z "$directory" ]]; then
            log_error "No directory specified for command: $command"
            show_usage
            exit 1
        fi

        directory=$(validate_directory "$directory")
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
    fi

    # Execute command
    INTERACTIVE=false
    case "$command" in
        rename)
            start_operation "Rename Files (Bracket Notation)"
            rename_files_in_directory "$directory" "$DRY_RUN"
            end_operation
            ;;
        flatten)
            start_operation "Flatten Directory"
            flatten_directory "$directory" "$DRY_RUN"
            end_operation
            ;;
        cleanup)
            workflow_deep_clean "$directory"
            ;;
        duplicates)
            start_operation "Find Duplicates"
            find_duplicates "$directory" "report"
            end_operation
            ;;
        subtitles)
            start_operation "Generate Subtitles"
            generate_subtitles_in_directory "$directory" "$WHISPER_MODEL" "$SUBTITLE_FORMAT" "$SUBTITLE_LANGUAGE" "$DRY_RUN"
            end_operation
            ;;
        workflow-new)
            workflow_new_collection "$directory"
            ;;
        workflow-clean)
            workflow_deep_clean "$directory"
            ;;
        batch)
            start_operation "Batch Processing"
            batch_process_folders
            end_operation
            ;;
        organize)
            organize_by_subfolder_names "$ORGANIZE_DEFAULT_TARGET" "$ORGANIZE_DEFAULT_SEARCH"
            ;;
        undo-organize)
            undo_organize_operation "$directory"
            ;;
        list-undo)
            list_undo_operations
            ;;
    esac
}

################################################################################
# MAIN EXECUTION
################################################################################

# Startup checks
startup_check() {
    local first_run=false

    # Check if this is first run (no log directory exists)
    if [[ ! -d "$LOG_DIR" ]]; then
        first_run=true
    fi

    # Show welcome banner on first run
    if [[ "$first_run" == true ]]; then
        clear
        echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╔═══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}           ${COLOR_BOLD}${COLOR_BRIGHT_YELLOW}WELCOME TO VIDEO MANAGER ULTIMATE${COLOR_RESET}            ${COLOR_BOLD}${COLOR_BRIGHT_CYAN}║${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_BRIGHT_CYAN}╚═══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_WHITE}First-time setup detected!${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_CYAN}${SYMBOL_INFO}${COLOR_RESET} Platform detected: ${COLOR_BRIGHT_CYAN}$OS_TYPE${COLOR_RESET}"
        echo ""
    fi

    # Check dependencies
    check_dependencies

    # Show tip on first run
    if [[ "$first_run" == true ]]; then
        echo ""
        echo -e "${COLOR_YELLOW}${SYMBOL_STAR} Quick Tips:${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Try ${COLOR_WHITE}Dry Run${COLOR_RESET} mode first to preview changes"
        echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Check ${COLOR_WHITE}System Information${COLOR_RESET} in Utilities menu"
        echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} View ${COLOR_WHITE}CROSS-PLATFORM.md${COLOR_RESET} for setup help"
        echo ""
        read -p "Press Enter to continue..."
    fi
}

main() {
    # Run startup checks
    startup_check

    # Initialize logging
    init_logging

    # Parse arguments
    if [[ $# -eq 0 ]]; then
        INTERACTIVE=true
    else
        parse_arguments "$@"
    fi

    # Launch interactive menu if needed
    if [[ "$INTERACTIVE" == true ]]; then
        interactive_menu
    fi
}

# Run main function
main "$@"
