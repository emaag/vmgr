# Simplified Menu Replacements for Video Manager

# File Operations Menu (Consolidated)
show_file_operations_menu() {
    show_header

    echo "File Operations"
    echo ""
    echo " 1. Rename (add [Studio] brackets)"
    echo " 2. Flatten folders"
    echo " 3. Clean up formatting"
    echo " 4. Batch process folders"
    echo ""
    echo " d. Dry run: $([[ "$DRY_RUN" == true ]] && echo "ON" || echo "OFF")"
    echo " b. Back"
    echo ""
    echo -n "Choose: "
}

# Subtitle Menu (Simplified)
show_subtitle_menu() {
    show_header

    echo "Subtitles"
    echo ""
    echo " Settings: model=$WHISPER_MODEL, format=$SUBTITLE_FORMAT, GPU=$([[ "$SUBTITLE_USE_GPU" == true ]] && echo "on" || echo "off")"
    echo ""
    echo " 1. Generate subtitles"
    echo " 2. Generate (batch)"
    echo " 3. Edit subtitle file"
    echo " 4. Configure settings"
    echo ""
    echo " b. Back"
    echo ""
    echo -n "Choose: "
}

# Duplicates Menu (Simplified)
show_duplicate_menu() {
    show_header

    echo "Duplicates"
    echo ""
    echo " 1. Find duplicates (report only)"
    echo " 2. Find and delete duplicates"
    echo ""
    echo " b. Back"
    echo ""
    echo -n "Choose: "
}

# Utilities Menu (Clean)
show_utilities_menu() {
    show_header

    echo "Utilities"
    echo ""
    echo " 1. Undo last operation"
    echo " 2. Manage favorites"
    echo " 3. Manage watch folders"
    echo " 4. View logs"
    echo ""
    echo " b. Back"
    echo ""
    echo -n "Choose: "
}

# Settings Menu (Minimal)
show_settings_menu() {
    show_header

    echo "Settings"
    echo ""
    echo " Dry Run: $([[ "$DRY_RUN" == true ]] && echo "ON" || echo "OFF")"
    echo " Verbose: $([[ "$VERBOSE" == true ]] && echo "ON" || echo "OFF")"
    echo ""
    echo " 1. Toggle dry run"
    echo " 2. Toggle verbose"
    echo " 3. View extensions"
    echo ""
    echo " b. Back"
    echo ""
    echo -n "Choose: "
}
