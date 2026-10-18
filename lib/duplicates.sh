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

    # Reports go under the logs directory so the scanned collection stays clean;
    # if that is not writable, fall back to a folder inside the scanned directory.
    local stamp report_dir
    stamp="$(date +%Y%m%d-%H%M%S)"
    report_dir="${LOG_DIR:-$HOME/.video-manager-logs}/duplicate-reports/$(basename "$(cd "$directory" 2>/dev/null && pwd || echo "$directory")")_$stamp"
    if ! mkdir -p "$report_dir" 2>/dev/null; then
        report_dir="$directory/_duplicate_report_$stamp"
    fi

    echo ""

    # Count the videos first so the progress bar has a total (terminal only)
    local total_videos=0
    if [[ -t 1 ]]; then
        total_videos=$(find "$directory" -type f ! -path '*/.vmgr-trash/*' \( \
            -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o \
            -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o \
            -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.3gp" \) 2>/dev/null | wc -l)
        total_videos=$(( total_videos ))
    fi

    # Find all video files and calculate hashes. The scan is sorted so the copy
    # that is kept (the first one seen) is always the first alphabetically.
    local file_count=0
    while IFS= read -r -d '' file; do
        is_video_file "$file" || continue
        ((file_count++))
        ((STATS[files_processed]++))

        local filename=$(basename "$file")
        if [[ "$(type -t ui_progress)" == "function" && $total_videos -gt 0 ]]; then
            ui_progress "$file_count" "$total_videos" "Hashing" "$filename"
        else
            echo -ne "\r${COLOR_CYAN}Hashing: [$file_count files] Current: ${filename:0:50}...${COLOR_RESET}"
        fi

        local hash=$(calculate_file_hash "$file")
        if [[ -z "$hash" ]]; then
            progress_break
            log_error "Failed to hash: $filename"
            continue
        fi

        if [[ -n "${hash_map[$hash]}" ]]; then
            # Duplicate found!
            progress_break
            log_warning "Duplicate found: $filename"
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
    done < <(find "$directory" -type f ! -path '*/.vmgr-trash/*' -print0 | sort -z)

    echo -ne "\r\033[K" # Clear line

    if [[ $total_duplicates -eq 0 ]]; then
        rmdir "$report_dir" 2>/dev/null
        log_success "No duplicates found! Your collection is clean."
        return 0
    fi

    # Create report
    mkdir -p "$report_dir" 2>/dev/null
    local report_file="$report_dir/duplicates.txt"
    local csv_file="$report_dir/duplicates.csv"

    {
        echo "DUPLICATE VIDEO FILES REPORT"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Directory: $directory"
        echo "Total Duplicates: $total_duplicates"
        echo "Space Wasted: $((space_wasted / 1024 / 1024)) MB"
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
        local size_mb=$((size / 1024 / 1024))

        if [[ "$(type -t ui_dup_group)" == "function" ]]; then
            local copies=$(( $(grep -c . <<< "$dupes") + 1 ))
            ui_dup_group "$group_num" "$copies" "$(format_bytes "$size")"
            ui_dup_line keep "${original#"$directory"/}"
        else
            echo -e "${COLOR_MAGENTA}Duplicate Group #$group_num${COLOR_RESET}"
            echo "  Hash: $hash"
            echo -e "  ${COLOR_GREEN}Original:${COLOR_RESET} $original"
            echo -e "  ${COLOR_RED}Duplicates:${COLOR_RESET}"
        fi

        {
            echo "=== Duplicate Group #$group_num ==="
            echo "Hash: $hash"
            echo "File Size: $size_mb MB"
            echo "Original: $original"
            echo "Duplicates:"
        } >> "$report_file"

        while IFS= read -r dupe; do
            [[ -z "$dupe" ]] && continue
            if [[ "$(type -t ui_dup_line)" == "function" ]]; then
                ui_dup_line extra "${dupe#"$directory"/}"
            else
                echo "    - $dupe"
            fi
            echo "    - $dupe" >> "$report_file"
            echo "\"$hash\",\"$original\",\"$dupe\",$size" >> "$csv_file"

            if [[ "$action" == "delete" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    if [[ "${ENABLE_UNDO:-true}" == true ]]; then
                        log_warning "[DRY RUN] Would move to trash: $dupe"
                    else
                        log_warning "[DRY RUN] Would delete: $dupe"
                    fi
                elif [[ "${ENABLE_UNDO:-true}" == true ]]; then
                    # Undoable: move to the trash instead of deleting
                    if trash_file "$dupe" "$directory" "$stamp"; then
                        log_success "Moved to trash: $(basename "$dupe")"
                        STATS[files_trashed]=$(( ${STATS[files_trashed]:-0} + 1 ))
                        STATS[space_trashed]=$(( ${STATS[space_trashed]:-0} + size ))
                    else
                        log_error "Could not move to trash: $dupe"
                    fi
                else
                    # Undo is switched off: delete for good, as before
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

    log_info "Total space wasted by duplicates: $(format_bytes "$space_wasted")"
}

################################################################################
# CATALOG-BASED DUPLICATE DETECTION
################################################################################

# Find duplicates in catalog database (cross-drive support)
# Returns JSON array of duplicate groups
find_duplicates_in_catalog() {
    init_catalog_db

    # Group by hash and filter only groups with more than 1 file
    local duplicates=$(jq -r '
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
    ' "$CATALOG_DB")

    echo "$duplicates"
}

# Find similar images by dimensions (potential duplicates without hash match)
find_similar_images() {
    init_catalog_db

    # Group images by dimensions
    local similar=$(jq -r '
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
    ' "$CATALOG_DB")

    echo "$similar"
}

# Groups of identical files for the report, read from the catalog text (no JSON
# parsing, so it stays quick and small on huge catalogs). Args: media filter (all,
# video, image, audio). Output, fields separated by US:
#   GROUP, copies, size of each copy, "", "", ""
#   FILE, "", "", drive label, online|offline, relative path     (one per copy)
#   SUMMARY, groups, extra copies, wasted bytes, "", ""          (last line, counts every group)
# Only the first DUPLICATE_REPORT_GROUPS groups get GROUP/FILE lines.
_catalog_duplicate_report_lines() {
    local media="${1:-all}" map id mp label limit="${DUPLICATE_REPORT_GROUPS:-200}"
    map="$(mktemp)"
    local online_ids=" "
    while IFS= read -r id; do online_ids+="$id "; done < <(_catalog_online_json | jq -r 'keys[]')
    while IFS="$_CAT_SEP" read -r id label; do
        printf '%s\037%s\037%s\n' "$id" "$label" "$([[ "$online_ids" == *" $id "* ]] && echo online || echo offline)"
    done < <(jq -r '.drives[] | [.drive_id, .drive_label] | join("\u001f")' "$CATALOG_DRIVES_DB" 2>/dev/null) > "$map"

    _catalog_hash_index | LC_ALL=C awk -F"$_CAT_SEP" -v media="$media" -v map="$map" -v limit="$limit" '
        BEGIN {
            while ((getline line < map) > 0) { split(line, f, "\037"); lab[f[1]] = f[2]; st[f[1]] = f[3] }
            close(map)
        }
        function flush(   i, avg) {
            if (n > 1) {
                groups++; extra += n - 1; wasted += total - total / n
                avg = int(total / n)
                if (groups <= limit) {
                printf "GROUP\037%d\037%d\037\037\037\n", n, avg
                for (i = 1; i <= n; i++)
                    printf "FILE\037\037\037%s\037%s\037%s\n", (D[i] in lab ? lab[D[i]] : "unknown"), (D[i] in st ? st[D[i]] : "offline"), R[i]
                }
            }
            n = 0; total = 0
        }
        media != "all" && $7 != media { next }
        { if (($1 "") != cur) { flush(); cur = $1 "" }     # string compare: see _catalog_duplicate_groups
          n++; D[n] = $2; R[n] = $4; total += $5 }
        END { flush(); printf "SUMMARY\037%d\037%d\037%d\037\037\n", groups, extra, int(wasted) }'
    rm -f "$map"
}

# Display the cross-drive duplicate report: groups of files with the same hash,
# across every cataloged drive (drives that are offline are included).
show_duplicates_report() {
    local media_filter="${1:-all}"

    command -v jq >/dev/null 2>&1 || { log_error "The catalog needs jq"; return 1; }
    init_catalog_db

    local n=0 kind count size label state rel dot color
    local dup_count=0 copies=0 wasted=0 printed=false
    while IFS=$'\x1f' read -r kind count size label state rel; do
        case "$kind" in
            GROUP)
                n=$(( n + 1 ))
                if [[ "$(type -t ui_dup_group)" == "function" ]]; then
                    ui_dup_group "$n" "$count" "$(format_bytes "$size")"
                else
                    echo "Group $n: $count copies, $(format_bytes "$size") each"
                fi
                ;;
            FILE)
                if [[ "$state" == online ]]; then dot="${UI_DOT_ON:-*}"; color="${UI_OK:-$COLOR_GREEN}"
                else dot="${UI_DOT_OFF:-o}"; color="${UI_DIM:-$COLOR_RED}"; fi
                printf '    %s%s%s %s[%s]%s %s\n' "$color" "$dot" "$COLOR_RESET" "${UI_ACCENT:-$COLOR_CYAN}" "$label" "$COLOR_RESET" "$rel"
                ;;
            SUMMARY)
                dup_count="$count"; copies="$size"; wasted="$label"
                ;;
        esac
    done < <(_catalog_duplicate_report_lines "$media_filter")

    if (( dup_count == 0 )); then
        log_info "No duplicates found in the catalog"
        if ! LC_ALL=C grep -q '"hash":"[0-9a-fA-F]' "$CATALOG_DB" 2>/dev/null; then
            log_info "Nothing in the catalog has a hash yet. Turn on Include Hash in Catalog Settings and scan again."
        fi
        return 0
    fi

    if (( dup_count > n )); then
        echo ""
        log_info "Showing the first ${n} of ${dup_count} groups. Export Catalog Report lists them all; cleaning up duplicates covers every one."
    fi
    echo ""
    log_info "${dup_count} duplicate group(s), ${copies} extra cop$([[ "$copies" == 1 ]] && echo y || echo ies), $(format_bytes "${wasted:-0}") wasted"
    STATS[duplicates_found]=$(( ${STATS[duplicates_found]:-0} + ${copies:-0} ))
    return 0
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
