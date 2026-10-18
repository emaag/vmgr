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
# Undo Log
# Operation: Organize by Subfolder Names
# Operation ID: organize-$operation_id
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

# Undo a logged operation (rename, flatten, organize, ...): move every recorded
# file back to where it came from.
# Args: $1=operation_id (optional, defaults to most recent). Accepts the full ID
#       shown by list_undo_operations, or the bare timestamp of an organize run.
# Returns: 0 on success
undo_organize_operation() {
    local operation_id="$1"

    start_operation "Undo Operation"

    # Find undo log
    local undo_log
    if [[ -n "$operation_id" ]]; then
        undo_log="$UNDO_LOG_DIR/${operation_id}.log"
        [[ -f "$undo_log" ]] || undo_log="$UNDO_LOG_DIR/organize-${operation_id}.log"
    else
        # Find most recent undo log using stat instead of ls
        local latest_file=""
        local latest_time=0
        shopt -s nullglob
        for file in "$UNDO_LOG_DIR"/*.log; do
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

    # Show what is about to be undone
    echo ""
    local undo_name undo_when
    undo_name="$(grep -m1 '^# Operation:' "$undo_log" | cut -d: -f2- | xargs)"
    undo_when="$(grep -m1 '^# Timestamp:' "$undo_log" | cut -d: -f2- | xargs)"
    log_info "Operation: ${undo_name:-Organize by Subfolder Names}${undo_when:+ ($undo_when)}"

    # Count operations
    local total_ops=$(grep -v '^#' "$undo_log" | wc -l)
    log_info "Found $total_ops operation(s) to undo"

    if [[ $total_ops -eq 0 ]]; then
        log_warning "No operations to undo"
        return 1
    fi

    # Confirm
    if [[ "$INTERACTIVE" == true ]]; then
        if ! ask_yes_no "Proceed with undo?"; then
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
            if [[ "$(type -t ui_progress)" == "function" ]]; then
                ui_progress "$current" "$total_ops" "Undoing"
            else
                printf "\r${COLOR_CYAN}[%d/%d]${COLOR_RESET} Undoing..." "$current" "$total_ops"
            fi
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
                trash_prune_empty "$dest"
                ((success_count++))
            else
                log_error "Failed to restore: $(basename "$dest")"
                ((error_count++))
            fi
        fi
    done < <(grep -v '^#' "$undo_log" | awk '{ l[NR] = $0 } END { for (i = NR; i > 0; i--) print l[i] }')

    progress_break
    if [[ "$DRY_RUN" == true ]]; then
        STATS[files_previewed]=$success_count
    else
        STATS[files_restored]=$success_count
    fi
    STATS[files_skipped]=$error_count
    echo ""

    # Archive the undo log
    if [[ $success_count -gt 0 && "$DRY_RUN" == false ]]; then
        mv "$undo_log" "${undo_log}.completed"
        log_info "Undo log archived"
    fi

    end_operation
}

# Total size in bytes of the files under a directory (real sizes, not disk blocks).
_dir_bytes() {
    local total=0 f sz
    while IFS= read -r -d '' f; do
        sz="$(get_file_size "$f")"
        total=$(( total + ${sz:-0} ))
    done < <(find "$1" -type f -print0 2>/dev/null)
    echo "$total"
}

# Every trash folder the undo logs know about, one path per line (only ones that
# still exist).
_trash_roots() {
    local f root
    shopt -s nullglob
    for f in "$UNDO_LOG_DIR"/*.log; do
        grep -v '^#' "$f" | cut -d'|' -f2 | grep "/$VMGR_TRASH_DIR/" | sed "s|\(.*/$VMGR_TRASH_DIR\)/.*|\1|"
    done | sort -u | while IFS= read -r root; do
        [[ "$(basename "$root")" == "$VMGR_TRASH_DIR" && -d "$root" ]] && echo "$root"
    done
    shopt -u nullglob
}

# Permanently delete everything the tool has moved to trash. This is the point of
# no return: the matching undo logs are retired because they can no longer work.
empty_trash() {
    start_operation "Empty Trash"

    local -a roots=()
    mapfile -t roots < <(_trash_roots)
    if [[ ${#roots[@]} -eq 0 ]]; then
        log_info "The trash is empty"
        end_operation
        return 0
    fi

    local root bytes total=0 files total_files=0 short
    for root in "${roots[@]}"; do
        bytes="$(_dir_bytes "$root")"
        files=$(find "$root" -type f 2>/dev/null | wc -l)
        files=$(( files ))
        total=$(( total + bytes )); total_files=$(( total_files + files ))
        _ui_short_path "$(dirname "$root")" 52 short 2>/dev/null || short="$(dirname "$root")"
        printf '  %s%s%s %s(%d file(s), %s)%s\n' "${UI_ACCENT:-}" "$short" "$COLOR_RESET" "${UI_DIM:-}" "$files" "$(format_bytes "$bytes")" "$COLOR_RESET"
    done
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would permanently delete ${total_files} file(s) (~$(format_bytes "$total"))"
        end_operation
        return 0
    fi

    if ! ask_yes_no "Permanently delete ${total_files} file(s) ($(format_bytes "$total"))? This cannot be undone"; then
        return 2
    fi

    local f
    for root in "${roots[@]}"; do
        [[ "$(basename "$root")" == "$VMGR_TRASH_DIR" ]] || continue
        if rm -rf -- "$root"; then
            log_success "Emptied: $(dirname "$root")/$VMGR_TRASH_DIR"
        else
            log_error "Could not remove: $root"
        fi
    done
    STATS[space_saved]=$(( ${STATS[space_saved]:-0} + total ))

    # The undo logs that pointed into the trash can no longer restore anything
    shopt -s nullglob
    for f in "$UNDO_LOG_DIR"/*.log; do
        if grep -v '^#' "$f" | cut -d'|' -f2 | grep -q "/$VMGR_TRASH_DIR/"; then
            mv "$f" "${f}.expired" 2>/dev/null
        fi
    done
    shopt -u nullglob

    end_operation
}

# Undo the most recent logged operation of any kind.
undo_last_operation() {
    undo_organize_operation ""
}

# List available undo operations (newest first)
list_undo_operations() {
    start_operation "Available Undo Operations"

    shopt -s nullglob
    local -a logs=("$UNDO_LOG_DIR"/*.log)
    shopt -u nullglob

    if [[ ${#logs[@]} -eq 0 ]]; then
        log_info "No undo operations available"
        return 0
    fi

    # Newest first, by modification time
    local -a sorted=()
    mapfile -t sorted < <(ls -1t "${logs[@]}" 2>/dev/null)

    local count=0 log_file op_id name stamp n
    for log_file in "${sorted[@]}"; do
        ((count++))
        op_id="$(basename "$log_file" .log)"
        name="$(grep -m1 '^# Operation:' "$log_file" | cut -d: -f2- | xargs)"
        stamp="$(grep -m1 '^# Timestamp:' "$log_file" | cut -d: -f2- | xargs)"
        n=$(grep -vc '^#' "$log_file" 2>/dev/null) || n=0
        printf '  %s%2d%s  %s%s%s\n' "${UI_ACCENT:-$COLOR_CYAN}" "$count" "$COLOR_RESET" \
            "$COLOR_BOLD" "${name:-Organize by Subfolder Names}" "$COLOR_RESET"
        printf '      %s%s %s %s file(s) %s %s%s\n' "${UI_DIM:-}" "$stamp" "${UI_SEP:--}" "$n" "${UI_SEP:--}" "$op_id" "$COLOR_RESET"
    done
    echo ""
    log_info "Undo the most recent one from Utilities > Undo Last Operation, or by ID with --undo-organize <ID>"

}

# Organize files by subfolder names
# Searches for files matching subfolder names and moves them to those subfolders
# Args: $1=target_folder(optional), $2=search_path(optional)
# Returns: 0 on success
organize_by_subfolder_names() {
    local target_folder="${1:-.}"
    local search_path="${2:-.}"

    start_operation "Organize by Subfolder Names"

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
        if ! ask_yes_no "Proceed with organizing files?"; then
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
            local count=$(find "$search_path" -type f ! -path '*/.vmgr-trash/*' \( \
                -iname "*${subfolder_name}*" \
                \) \( \
                -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o \
                -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o \
                -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.3gp" \
                \) 2>/dev/null | wc -l)
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
        done < <(find "$search_path" -type f ! -path '*/.vmgr-trash/*' \( \
            -iname "*${subfolder_name}*" -o \
            -iname "*${subfolder_name_lower}*" \
            \) \( \
            -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o \
            -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o \
            -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.3gp" \
            \) 2>/dev/null)

        # Move matching files
        if [[ ${#matching_files[@]} -gt 0 ]]; then
            log_info "Found ${#matching_files[@]} file(s) to move to: $subfolder_name"

            for file in "${matching_files[@]}"; do
                ((processed++))

                # Show progress
                if [[ "$ORGANIZE_SHOW_PROGRESS" == true && $total_files -gt 0 ]]; then
                    if [[ "$(type -t ui_progress)" == "function" ]]; then
                        ui_progress "$processed" "$total_files" "Organizing"
                    else
                        local percent=$((processed * 100 / total_files))
                        printf "\r${COLOR_CYAN}Progress: [%d/%d] %d%%${COLOR_RESET} " "$processed" "$total_files" "$percent"
                    fi
                fi

                local filename=$(basename "$file")
                local dest="$subfolder/$filename"

                # Check if destination already exists
                if [[ -f "$dest" ]]; then
                    if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                        progress_break
                    fi
                    log_warning "Destination already exists: $filename"
                    ((skipped_count++))
                    continue
                fi

                # Move file
                if [[ "$DRY_RUN" == true ]]; then
                    if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                        progress_break
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
                            progress_break
                        fi
                        log_success "Moved: $filename → $subfolder_name/"
                        ((moved_count++))
                    else
                        if [[ "$ORGANIZE_SHOW_PROGRESS" == true ]]; then
                            progress_break
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
