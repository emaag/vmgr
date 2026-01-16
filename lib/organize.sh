#!/usr/bin/env bash
#
# Video Manager Ultimate - File Organization Module
# Part of the modular video management system
#
# This module provides file organization functionality for:
# - Organizing files by subfolder name matching
# - Undo/rollback system for organization operations
# - Operation logging and tracking
# - Favorites and watch folders management
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh
# Status: Phase 2 - Modularization
# Version: 1.2.0
#

################################################################################
# OPERATION TRACKING
################################################################################

# Begin operation (wrapper for start_operation with additional context)
begin_operation() {
    local operation_name="$1"
    start_operation "$operation_name"
}


################################################################################
# ORGANIZE OPERATION HELPERS
################################################################################

# Create undo log for organize operation
# Args: $1=operation_id
# Returns: path to undo log file
_create_undo_log() {
    local operation_id="$1"

    # Create undo log directory if it doesn't exist
    mkdir -p "$UNDO_LOG_DIR"

    local undo_file="$UNDO_LOG_DIR/organize-${operation_id}.log"

    # Create log file with header
    cat > "$undo_file" <<EOF
# Organize Operation Undo Log
# Operation ID: $operation_id
# Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
# Format: source_path|destination_path
EOF

    echo "$undo_file"
}

# Log a move operation for undo
# Args: $1=undo_log_file $2=source $3=destination
_log_move_operation() {
    local undo_log="$1"
    local source="$2"
    local dest="$3"

    echo "$source|$dest" >> "$undo_log"
}

################################################################################
# ORGANIZE OPERATIONS
################################################################################

# Undo the last organize operation
# Args: $1=operation_id (optional, defaults to most recent)
# Returns: 0 on success
undo_organize_operation() {
    local operation_id="$1"

    begin_operation "Undo Organize Operation"

    # Find undo log
    local undo_log
    if [[ -n "$operation_id" ]]; then
        undo_log="$UNDO_LOG_DIR/organize-${operation_id}.log"
    else
        # Find most recent undo log using stat instead of ls
        local latest_file=""
        local latest_time=0
        shopt -s nullglob
        for file in "$UNDO_LOG_DIR"/organize-*.log; do
            if [[ -f "$file" ]]; then
                local file_time=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
                if [[ "$file_time" -gt "$latest_time" ]]; then
                    latest_time="$file_time"
                    latest_file="$file"
                fi
            fi
        done
        shopt -u nullglob
        undo_log="$latest_file"
    fi

    if [[ ! -f "$undo_log" ]]; then
        log_error "No undo log found"
        return 1
    fi

    log_info "Using undo log: $(basename "$undo_log")"

    # Show log header
    echo ""
    grep '^#' "$undo_log"
    echo ""

    # Count operations
    local total_ops=$(grep -v '^#' "$undo_log" | wc -l)
    log_info "Found $total_ops operation(s) to undo"

    if [[ $total_ops -eq 0 ]]; then
        log_warning "No operations to undo"
        return 1
    fi

    # Confirm
    if [[ "$INTERACTIVE" == true ]]; then
        echo -n "Proceed with undo? (y/n): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_warning "Undo cancelled"
            return 1
        fi
    fi

    echo ""
    local success_count=0
    local error_count=0
    local current=0

    # Read undo log in reverse order and restore files
    while IFS='|' read -r source dest; do
        ((current++))

        if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
            printf "\r${COLOR_CYAN}[%d/%d]${COLOR_RESET} Undoing..." "$current" "$total_ops"
        fi

        # Check if destination still exists
        if [[ ! -f "$dest" ]]; then
            log_verbose "Skipping (file no longer exists): $(basename "$dest")"
            ((error_count++))
            continue
        fi

        # Check if source location is available
        local source_dir=$(dirname "$source")
        if [[ ! -d "$source_dir" ]]; then
            mkdir -p "$source_dir"
        fi

        if [[ -f "$source" ]]; then
            log_warning "Source already exists: $(basename "$source")"
            ((error_count++))
            continue
        fi

        # Move file back
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "\n${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would restore: $(basename "$dest") → $source"
            ((success_count++))
        else
            if mv "$dest" "$source"; then
                log_verbose "Restored: $(basename "$dest") → $source"
                ((success_count++))
            else
                log_error "Failed to restore: $(basename "$dest")"
                ((error_count++))
            fi
        fi
    done < <(tac "$undo_log" | grep -v '^#')

    echo ""

    # Summary
    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Undo Summary:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Successfully restored: ${COLOR_WHITE}$success_count${COLOR_RESET}"
    echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Failed/Skipped: ${COLOR_WHITE}$error_count${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"

    # Archive the undo log
    if [[ $success_count -gt 0 && "$DRY_RUN" == false ]]; then
        mv "$undo_log" "${undo_log}.completed"
        log_info "Undo log archived"
    fi

    end_operation
}

# List available undo operations
list_undo_operations() {
    begin_operation "Available Undo Operations"

    # Check if directory exists and has files
    if [[ ! -d "$UNDO_LOG_DIR" ]]; then
        log_info "No undo operations available"
        return 0
    fi

    # Check if directory is empty using glob pattern
    shopt -s nullglob dotglob
    local files=("$UNDO_LOG_DIR"/*)
    shopt -u nullglob dotglob

    if [[ ${#files[@]} -eq 0 ]]; then
        log_info "No undo operations available"
        return 0
    fi

    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}Available Undo Logs:${COLOR_RESET}"
    echo ""

    local count=0
    for log_file in "$UNDO_LOG_DIR"/organize-*.log; do
        [[ ! -f "$log_file" ]] && continue

        ((count++))
        local op_id=$(basename "$log_file" .log | sed 's/organize-//')
        local timestamp=$(grep '# Timestamp:' "$log_file" | cut -d':' -f2- | xargs)
        local op_count=$(grep -v '^#' "$log_file" | wc -l)

        echo -e "${COLOR_WHITE}[$count]${COLOR_RESET} ID: ${COLOR_CYAN}$op_id${COLOR_RESET}"
        echo -e "    Timestamp: $timestamp"
        echo -e "    Operations: $op_count file(s) moved"
        echo ""
    done

    if [[ $count -eq 0 ]]; then
        log_info "No undo operations available"
    fi

    end_operation
}

# Organize files by subfolder names
# Searches for files matching subfolder names and moves them to those subfolders
# Args: $1=target_folder(optional), $2=search_path(optional)
# Returns: 0 on success
organize_by_subfolder_names() {
    local target_folder="${1:-.}"
    local search_path="${2:-.}"

    begin_operation "Organize by Subfolder Names"

    # Validate target folder
    if [[ ! -d "$target_folder" ]]; then
        log_error "Target folder does not exist: $target_folder"
        return 1
    fi

    log_info "Target folder: $target_folder"
    log_info "Search path: $search_path"
    echo ""

    # Get all subdirectories (exclude hidden, "full", and common system dirs)
    local -a subfolders
    while IFS= read -r dir; do
        local basename=$(basename "$dir")
        # Skip hidden, full, and system directories
        if [[ ! "$basename" =~ ^\. ]] && \
           [[ "$basename" != "full" ]] && \
           [[ "$basename" != "Full" ]] && \
           [[ "$basename" != "FULL" ]] && \
           [[ "$basename" != "tmp" ]] && \
           [[ "$basename" != "temp" ]]; then
            subfolders+=("$dir")
        fi
    done < <(find "$target_folder" -mindepth 1 -maxdepth 1 -type d | sort)

    if [[ ${#subfolders[@]} -eq 0 ]]; then
        log_warning "No valid subfolders found in: $target_folder"
        return 1
    fi

    log_info "Found ${#subfolders[@]} subfolder(s) to match against"
    echo ""

    # Show folders
    echo -e "${COLOR_BRIGHT_CYAN}Subfolders:${COLOR_RESET}"
    for dir in "${subfolders[@]}"; do
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} $(basename "$dir")"
    done
    echo ""

    # Confirm before proceeding
    if [[ "$INTERACTIVE" == true ]]; then
        echo -n "Proceed with organizing files? (y/n): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_warning "Operation cancelled"
            return 1
        fi
    fi

    echo ""

    # Create undo log
    local operation_id=$(date +%Y%m%d-%H%M%S)
    local undo_log=""
    if [[ "$ORGANIZE_LOG_OPERATIONS" == true && "$DRY_RUN" == false ]]; then
        undo_log=$(_create_undo_log "$operation_id")
        log_info "Undo log: $(basename "$undo_log")"
        echo ""
    fi

    local moved_count=0
    local skipped_count=0
    local total_files=0

    # First pass: count total files to process
    if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
        log_verbose "Counting files to process..."
        for subfolder in "${subfolders[@]}"; do
            local subfolder_name=$(basename "$subfolder")
            local count=$(find "$search_path" -type f \( \
                -iname "*${subfolder_name}*" \
                \) 2>/dev/null | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg)$' | wc -l)
            ((total_files += count))
        done
        log_info "Total files to process: $total_files"
        echo ""
    fi

    local processed=0

    # For each subfolder, search for matching files
    for subfolder in "${subfolders[@]}"; do
        local subfolder_name=$(basename "$subfolder")
        local subfolder_name_lower=$(echo "$subfolder_name" | tr '[:upper:]' '[:lower:]')

        log_info "Searching for files matching: $subfolder_name"

        # Find all video files in search path that match the subfolder name
        local -a matching_files
        while IFS= read -r file; do
            # Skip if file doesn't exist
            [[ ! -f "$file" ]] && continue

            # Get parent directory
            local parent_dir=$(dirname "$file")
            local parent_basename=$(basename "$parent_dir")
            local parent_basename_lower=$(echo "$parent_basename" | tr '[:upper:]' '[:lower:]')

            # Skip if already in the target subfolder
            if [[ "$parent_dir" == "$subfolder" ]]; then
                log_verbose "Skipping (already in target): $(basename "$file")"
                ((skipped_count++))
                continue
            fi

            # Skip if in a "full" folder
            if [[ "$parent_basename_lower" == "full" ]] || [[ "$file" =~ /[Ff][Uu][Ll][Ll]/ ]]; then
                log_verbose "Skipping (in 'full' folder): $(basename "$file")"
                ((skipped_count++))
                continue
            fi

            matching_files+=("$file")
        done < <(find "$search_path" -type f \( \
            -iname "*${subfolder_name}*" -o \
            -iname "*${subfolder_name_lower}*" \
            \) 2>/dev/null | grep -iE '\.(mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg)$')

        # Move matching files
        if [[ ${#matching_files[@]} -gt 0 ]]; then
            log_info "Found ${#matching_files[@]} file(s) to move to: $subfolder_name"

            for file in "${matching_files[@]}"; do
                ((processed++))

                # Show progress
                if [[ "$ORGANIZE_SHOW_PROGRESS" == true && $total_files -gt 0 ]]; then
                    local percent=$((processed * 100 / total_files))
                    printf "\r${COLOR_CYAN}Progress: [%d/%d] %d%%${COLOR_RESET} " "$processed" "$total_files" "$percent"
                fi

                local filename=$(basename "$file")
                local dest="$subfolder/$filename"

                # Check if destination already exists
                if [[ -f "$dest" ]]; then
                    if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                        echo "" # New line before warning
                    fi
                    log_warning "Destination already exists: $filename"
                    ((skipped_count++))
                    continue
                fi

                # Move file
                if [[ "$DRY_RUN" == true ]]; then
                    if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                        echo "" # New line before message
                    fi
                    echo -e "${COLOR_YELLOW}[DRY RUN]${COLOR_RESET} Would move: $filename → $subfolder_name/"
                    ((moved_count++))
                else
                    if mv "$file" "$dest"; then
                        # Log for undo
                        if [[ -n "$undo_log" ]]; then
                            _log_move_operation "$undo_log" "$file" "$dest"
                        fi

                        if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                            echo "" # New line before success message
                        fi
                        log_success "Moved: $filename → $subfolder_name/"
                        ((moved_count++))
                    else
                        if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                            echo "" # New line before error
                        fi
                        log_error "Failed to move: $filename"
                        ((skipped_count++))
                    fi
                fi
            done
        else
            log_verbose "No matches for: $subfolder_name"
        fi

        echo ""
    done

    # Summary
    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Summary:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Files moved: ${COLOR_WHITE}$moved_count${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}${SYMBOL_ARROW}${COLOR_RESET} Files skipped: ${COLOR_WHITE}$skipped_count${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"

    end_operation
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
