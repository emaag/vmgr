#!/usr/bin/env bash
#
# Video Manager Ultimate - Batch Processing Module
# Part of the modular video management system
#
# This module provides batch processing and workflow functionality for:
# - Batch operations across multiple directories
# - Pre-configured workflows (new collection, deep clean)
# - Multi-folder processing
# - Progress tracking across batches
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh, file-ops.sh
# Status: Phase 3 - Modularization
# Version: 1.2.0
#

################################################################################
# BATCH PROCESSING
################################################################################

# Batch process multiple folders
batch_process_folders() {
    local operation="$1"
    shift
    local folders=("$@")

    if [[ ${#folders[@]} -eq 0 ]]; then
        log_error "No folders specified for batch processing"
        return 1
    fi

    log_info "Starting batch ${operation} on ${#folders[@]} folders"

    local total_folders=${#folders[@]}
    local processed=0
    local success=0
    local failed=0

    for folder in "${folders[@]}"; do
        ((processed++))

        if [[ ! -d "$folder" ]]; then
            log_warning "Skipping non-existent folder: $folder"
            ((failed++))
            continue
        fi

        echo ""
        log_info "Processing folder [$processed/$total_folders]: $folder"

        # Execute operation based on type
        case "$operation" in
            "rename")
                if rename_files_in_directory "$folder" false; then
                    ((success++))
                else
                    ((failed++))
                fi
                ;;
            "flatten")
                if flatten_directory "$folder" false; then
                    ((success++))
                else
                    ((failed++))
                fi
                ;;
            "cleanup")
                if workflow_deep_clean "$folder"; then
                    ((success++))
                else
                    ((failed++))
                fi
                ;;
            "duplicates")
                if find_duplicates "$folder" "report"; then
                    ((success++))
                else
                    ((failed++))
                fi
                ;;
            *)
                log_error "Unknown operation: $operation"
                ((failed++))
                ;;
        esac
    done

    echo ""
    log_success "Batch processing complete"
    log_info "  Processed: $processed"
    log_info "  Successful: $success"
    [[ $failed -gt 0 ]] && log_warning "  Failed: $failed"
}

################################################################################
# BATCH WRAPPERS (for interactive menu)
################################################################################

# Batch flatten multiple folders (interactive)
batch_flatten_interactive() {
    log_info "Batch Flatten Multiple Folders"
    echo ""
    echo "Enter directories to flatten (one per line, empty line to finish):"
    echo ""

    local -a folders
    while true; do
        read -p "Directory: " dir
        [[ -z "$dir" ]] && break

        dir=$(validate_directory "$dir")
        if [[ $? -eq 0 ]]; then
            folders+=("$dir")
        fi
    done

    if [[ ${#folders[@]} -eq 0 ]]; then
        log_warning "No directories specified"
        return 1
    fi

    batch_process_folders "flatten" "${folders[@]}"
}

# Batch cleanup multiple folders (interactive)
batch_cleanup_interactive() {
    log_info "Batch Full Cleanup (Multiple Folders)"
    echo ""
    echo "Enter directories to clean (one per line, empty line to finish):"
    echo ""

    local -a folders
    while true; do
        read -p "Directory: " dir
        [[ -z "$dir" ]] && break

        dir=$(validate_directory "$dir")
        if [[ $? -eq 0 ]]; then
            folders+=("$dir")
        fi
    done

    if [[ ${#folders[@]} -eq 0 ]]; then
        log_warning "No directories specified"
        return 1
    fi

    batch_process_folders "cleanup" "${folders[@]}"
}

################################################################################
# WORKFLOWS
################################################################################

# Workflow: New Collection Setup
workflow_new_collection() {
    local directory="$1"

    log_info "Starting New Collection Workflow"
    log_info "This will: flatten → rename → deduplicate"

    echo ""
    flatten_directory "$directory" false
    echo ""
    rename_files_in_directory "$directory" false
    echo ""
    find_duplicates "$directory" "report"

    log_success "New Collection Workflow complete"
}

# Workflow: Deep Clean
workflow_deep_clean() {
    local directory="$1"

    log_info "Starting Deep Clean Workflow"
    log_info "This will: rename → deduplicate"

    echo ""
    rename_files_in_directory "$directory" false
    echo ""
    find_duplicates "$directory" "report"

    log_success "Deep Clean Workflow complete"
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
