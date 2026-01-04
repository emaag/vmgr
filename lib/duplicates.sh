#!/usr/bin/env bash
#
# Video Manager Ultimate - Duplicate Detection Module
# Part of the modular video management system
#
# This module provides duplicate detection functionality for:
# - Hash-based exact duplicate finding
# - Directory-based duplicate scanning
# - Catalog-based cross-drive duplicate detection
# - Similar image detection
# - Duplicate reporting and deletion
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh
# Status: Phase 2 - Modularization
# Version: 1.2.0
#

################################################################################
# DIRECTORY-BASED DUPLICATE DETECTION
################################################################################

find_duplicates() {
    local directory="$1"
    local action="${2:-report}" # report or delete

    log_info "Scanning for duplicate video files in: $directory"
    log_verbose "This may take a while for large collections..."

    declare -A hash_map
    declare -A duplicate_groups
    local total_duplicates=0
    local space_wasted=0

    # Create output directory for reports
    local report_dir="$directory/_duplicate_report_$(date +%Y%m%d-%H%M%S)"

    echo ""

    # Find all video files and calculate hashes
    local file_count=0
    while IFS= read -r -d '' file; do
        ((file_count++))
        ((STATS[files_processed]++))

        local filename=$(basename "$file")
        echo -ne "\r${COLOR_CYAN}Hashing: [$file_count files] Current: ${filename:0:50}...${COLOR_RESET}"

        local hash=$(calculate_hash "$file")
        if [[ -z "$hash" ]]; then
            log_error "Failed to hash: $filename"
            continue
        fi

        if [[ -n "${hash_map[$hash]}" ]]; then
            # Duplicate found!
            log_verbose ""
            log_warning "Duplicate found!"
            log_verbose "  Hash: $hash"
            log_verbose "  Original: ${hash_map[$hash]}"
            log_verbose "  Duplicate: $file"

            duplicate_groups[$hash]+="$file"$'\n'
            ((total_duplicates++))
            ((STATS[duplicates_found]++))

            local size=$(get_file_size "$file")
            space_wasted=$((space_wasted + size))
        else
            hash_map[$hash]="$file"
        fi
    done < <(find "$directory" -type f -print0 | grep -zE "$VIDEO_EXTENSIONS_PATTERN")

    echo -ne "\r\033[K" # Clear line

    if [[ $total_duplicates -eq 0 ]]; then
        log_success "No duplicates found! Your collection is clean."
        return 0
    fi

    # Create report directory with proper error handling
    if ! mkdir -p "$report_dir" 2>/dev/null; then
        log_error "Failed to create report directory: $report_dir"
        return 1
    fi

    local report_file="$report_dir/duplicates.txt"
    local csv_file="$report_dir/duplicates.csv"

    {
        echo "DUPLICATE VIDEO FILES REPORT"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Directory: $directory"
        echo "Total Duplicates: $total_duplicates"
        echo "Space Wasted: $((space_wasted / BYTES_PER_MB)) MB"
        echo ""
        echo "========================================"
        echo ""
    } > "$report_file"

    echo "Hash,Original File,Duplicate Files,File Size" > "$csv_file"

    local group_num=1
    for hash in "${!duplicate_groups[@]}"; do
        local original="${hash_map[$hash]}"
        local dupes="${duplicate_groups[$hash]}"
        local size=$(get_file_size "$original")
        local size_mb=$((size / BYTES_PER_MB))

        echo -e "${COLOR_MAGENTA}Duplicate Group #$group_num${COLOR_RESET}"
        echo "  Hash: $hash"
        echo -e "  ${COLOR_GREEN}Original:${COLOR_RESET} $original"
        echo -e "  ${COLOR_RED}Duplicates:${COLOR_RESET}"

        {
            echo "=== Duplicate Group #$group_num ==="
            echo "Hash: $hash"
            echo "File Size: $size_mb MB"
            echo "Original: $original"
            echo "Duplicates:"
        } >> "$report_file"

        while IFS= read -r dupe; do
            [[ -z "$dupe" ]] && continue
            echo "    - $dupe"
            echo "    - $dupe" >> "$report_file"
            echo "\"$hash\",\"$original\",\"$dupe\",$size" >> "$csv_file"

            if [[ "$action" == "delete" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    log_warning "[DRY RUN] Would delete: $dupe"
                else
                    rm -f "$dupe" 2>/dev/null
                    if [[ $? -eq 0 ]]; then
                        log_success "Deleted duplicate: $(basename "$dupe")"
                        STATS[space_saved]=$((STATS[space_saved] + size))
                    else
                        log_error "Failed to delete: $dupe"
                    fi
                fi
            fi
        done <<< "$dupes"

        echo "" >> "$report_file"
        echo ""
        ((group_num++))
    done

    log_success "Report generated: $report_file"
    log_success "CSV export: $csv_file"

    local space_mb=$((space_wasted / BYTES_PER_MB))
    log_info "Total space wasted by duplicates: ${space_mb} MB"
}

################################################################################
# CATALOG-BASED DUPLICATE DETECTION
################################################################################

# Find duplicates in catalog database (cross-drive support)
# Returns JSON array of duplicate groups
find_duplicates_in_catalog() {
    init_catalog_db

    local catalog_json=$(cat "$CATALOG_DB")

    # Group by hash and filter only groups with more than 1 file
    local duplicates=$(echo "$catalog_json" | jq -r '
        [.videos[] | select(.hash != null and .hash != "")] |
        group_by(.hash) |
        map(select(length > 1)) |
        map({
            hash: .[0].hash,
            count: length,
            total_size: (map(.file_size) | add),
            files: map({
                video_id: .video_id,
                drive_id: .drive_id,
                filename: .filename,
                relative_path: .relative_path,
                media_type: .media_type,
                file_size: .file_size,
                dimensions: .dimensions,
                resolution: .resolution,
                last_scanned: .last_scanned
            })
        })
    ')

    echo "$duplicates"
}

# Find similar images by dimensions (potential duplicates without hash match)
find_similar_images() {
    init_catalog_db

    local catalog_json=$(cat "$CATALOG_DB")

    # Group images by dimensions
    local similar=$(echo "$catalog_json" | jq -r '
        [.videos[] | select(.media_type == "image" and .dimensions != null and .dimensions != "")] |
        group_by(.dimensions) |
        map(select(length > 1)) |
        map({
            dimensions: .[0].dimensions,
            count: length,
            files: map({
                video_id: .video_id,
                drive_id: .drive_id,
                filename: .filename,
                relative_path: .relative_path,
                file_size: .file_size,
                camera: .camera,
                date_taken: .date_taken
            })
        })
    ')

    echo "$similar"
}

# Display duplicate report
show_duplicates_report() {
    local media_filter="${1:-all}"

    log_info "Scanning for duplicates..."

    local duplicates=$(find_duplicates_in_catalog)
    local dup_count=$(echo "$duplicates" | jq 'length')

    if [[ "$dup_count" -eq 0 ]] || [[ "$dup_count" == "null" ]]; then
        log_info "No duplicates found"
        return 0
    fi

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  DUPLICATE FILES REPORT${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""

    local group_num=0
    echo "$duplicates" | jq -c '.[]' | while IFS= read -r group; do
        ((group_num++))

        local hash=$(echo "$group" | jq -r '.hash' | cut -c1-16)
        local count=$(echo "$group" | jq -r '.count')
        local total_size=$(echo "$group" | jq -r '.total_size')
        local wasted_size=$((total_size - total_size / count))

        echo -e "${COLOR_BOLD}${COLOR_YELLOW}${SYMBOL_WARN} Duplicate Group #$group_num${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Hash: ${COLOR_WHITE}$hash...${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Copies: ${COLOR_RED}$count files${COLOR_RESET}"
        echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Wasted Space: ${COLOR_RED}$(format_bytes $wasted_size)${COLOR_RESET}"
        echo ""

        local file_num=0
        echo "$group" | jq -c '.files[]' | while IFS= read -r file; do
            ((file_num++))

            local filename=$(echo "$file" | jq -r '.filename')
            local media_type=$(echo "$file" | jq -r '.media_type')
            local size=$(echo "$file" | jq -r '.file_size')
            local drive_id=$(echo "$file" | jq -r '.drive_id')

            # Get drive info
            local drive_label=$(cat "$CATALOG_DRIVES_DB" | jq -r --arg id "$drive_id" \
                '.drives[] | select(.drive_id == $id) | .drive_label' 2>/dev/null || echo "Unknown")

            # Media type icon
            local type_icon="📄"
            case "$media_type" in
                video) type_icon="🎬" ;;
                image) type_icon="🖼️" ;;
                audio) type_icon="🎵" ;;
            esac

            echo -e "    ${COLOR_BRIGHT_GREEN}[$file_num]${COLOR_RESET} $type_icon ${COLOR_WHITE}$filename${COLOR_RESET}"
            echo -e "        ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Drive: ${COLOR_WHITE}$drive_label${COLOR_RESET}"
            echo -e "        ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Size: ${COLOR_WHITE}$(format_bytes $size)${COLOR_RESET}"
        done

        echo ""
    done

    # Calculate total wasted space
    local total_wasted=$(echo "$duplicates" | jq '[.[] | (.total_size - (.total_size / .count))] | add')
    local total_dupes=$(echo "$duplicates" | jq '[.[] | .count] | add')

    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Summary:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Duplicate Groups: ${COLOR_RED}$dup_count${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Total Duplicate Files: ${COLOR_RED}$total_dupes${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Wasted Space: ${COLOR_RED}$(format_bytes $total_wasted)${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
