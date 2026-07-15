#!/usr/bin/env bash
#
# Video Manager Ultimate - Multi-Drive Catalog Module
# Part of the modular video management system
#
# This module provides multi-drive catalog system functionality for:
# - Cross-drive duplicate detection
# - Drive registration and tracking
# - Catalog database management
# - Drive type detection (USB, NAS, Local, Network)
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh, duplicates.sh
# Status: Phase 3 - Modularization
# Version: 1.2.0
#

################################################################################
# DRIVE IDENTIFICATION
################################################################################

# Get unique drive identifier (UUID, Volume ID, or Serial Number)
get_drive_id() {
    local mount_point="$1"
    local drive_id=""

    if [[ -d "$mount_point" ]]; then
        # For WSL drives, use volume label + serial
        if [[ "$mount_point" =~ ^/mnt/[a-z]$ ]]; then
            local drive_letter="${mount_point##*/}"
            drive_id=$(powershell.exe -NoProfile -Command "(Get-Volume -DriveLetter ${drive_letter}).UniqueId" 2>/dev/null | tr -d '\r\n' | tr -d '{}')
            if [[ -z "$drive_id" ]]; then
                local vol_label=$(powershell.exe -NoProfile -Command "(Get-Volume -DriveLetter ${drive_letter}).FileSystemLabel" 2>/dev/null | tr -d '\r\n')
                drive_id="${drive_letter}_${vol_label}"
            fi
        else
            # Try Linux UUID method
            local dev=$(df "$mount_point" 2>/dev/null | tail -1 | awk '{print $1}')
            if [[ -n "$dev" ]]; then
                drive_id=$(blkid -s UUID -o value "$dev" 2>/dev/null)
            fi

            # Fallback: use mount point hash
            if [[ -z "$drive_id" ]]; then
                drive_id=$(echo -n "$mount_point" | md5sum | awk '{print $1}')
            fi
        fi
    fi

    echo "$drive_id"
}

# Get drive label/name
get_drive_label() {
    local mount_point="$1"
    local label=""

    if [[ "$mount_point" =~ ^/mnt/[a-z]$ ]]; then
        local drive_letter="${mount_point##*/}"
        label=$(powershell.exe -NoProfile -Command "(Get-Volume -DriveLetter ${drive_letter}).FileSystemLabel" 2>/dev/null | tr -d '\r\n')
        [[ -z "$label" ]] && label="Drive ${drive_letter^^}"
    else
        label=$(basename "$mount_point")
    fi

    echo "$label"
}

# Detect drive type (USB, NAS, Local, Network)
detect_drive_type() {
    local mount_point="$1"
    local drive_type="Unknown"

    # Check mount info
    local mount_info=$(mount | grep "$mount_point")

    if [[ "$mount_point" =~ ^/mnt/[a-z]$ ]]; then
        # WSL drive
        local drive_letter="${mount_point##*/}"
        local bus_type=$(powershell.exe -NoProfile -Command "(Get-PhysicalDisk | Where-Object {(\$_.DeviceID -eq (Get-Partition -DriveLetter ${drive_letter}).DiskNumber)}).BusType" 2>/dev/null | tr -d '\r\n')

        case "$bus_type" in
            USB) drive_type="USB" ;;
            SATA|SAS|ATA) drive_type="Local" ;;
            NVMe|RAID) drive_type="Local" ;;
            iSCSI|FC) drive_type="NAS" ;;
            *) drive_type="Local" ;;
        esac
    elif echo "$mount_info" | grep -q "cifs\|smb"; then
        drive_type="Network"
    elif echo "$mount_info" | grep -q "nfs"; then
        drive_type="NAS"
    elif echo "$mount_info" | grep -q "fuse\|9p"; then
        drive_type="Network"
    else
        drive_type="Local"
    fi

    echo "$drive_type"
}

################################################################################
# CATALOG DATABASE MANAGEMENT
################################################################################

# Initialize catalog database
init_catalog_db() {
    if [[ ! -f "$CATALOG_DB" ]]; then
        echo '{"videos":[],"last_updated":"'$(date -Iseconds)'","version":"1.0"}' > "$CATALOG_DB"
        log_verbose "Created catalog database: $CATALOG_DB"
    fi

    if [[ ! -f "$CATALOG_DRIVES_DB" ]]; then
        echo '{"drives":[],"last_updated":"'$(date -Iseconds)'"}' > "$CATALOG_DRIVES_DB"
        log_verbose "Created drives database: $CATALOG_DRIVES_DB"
    fi
}

# Register a drive in the drives database without scanning files.
# Usage: register_drive <mount_point>
# Prints the drive_id on success.
register_drive() {
    local mount_point="$1"

    if [[ ! -d "$mount_point" ]]; then
        log_error "Mount point does not exist: $mount_point"
        return 1
    fi

    init_catalog_db

    local drive_id drive_label drive_type timestamp
    drive_id=$(get_drive_id "$mount_point")
    drive_label=$(get_drive_label "$mount_point")
    drive_type=$(detect_drive_type "$mount_point")
    timestamp=$(date -Iseconds)

    log_info "Registering drive: $drive_label ($drive_id)"

    local entry
    entry=$(jq -n \
        --arg id    "$drive_id" \
        --arg label "$drive_label" \
        --arg type  "$drive_type" \
        --arg mount "$mount_point" \
        --arg ts    "$timestamp" \
        '{"id":$id,"label":$label,"type":$type,"mount_point":$mount,
          "file_count":0,"last_scanned":null,"registered_at":$ts}')

    jq --arg id "$drive_id" \
       --argjson entry "$entry" \
       --arg ts "$timestamp" \
       '.drives = ([.drives[] | select(.id != $id)] + [$entry]) |
        .last_updated = $ts' \
        "$CATALOG_DRIVES_DB" > "${CATALOG_DRIVES_DB}.tmp" \
        && mv "${CATALOG_DRIVES_DB}.tmp" "$CATALOG_DRIVES_DB"

    echo "$drive_id"
}

################################################################################
# CATALOG OPERATIONS
################################################################################

# Scan a directory/drive and index all media files into the catalog.
# Usage: catalog_drive <mount_point> [recursive=true]
catalog_drive() {
    local mount_point="$1"
    local recursive="${2:-true}"

    if [[ ! -d "$mount_point" ]]; then
        log_error "Path does not exist: $mount_point"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required. Install with: sudo apt-get install jq"
        return 1
    fi

    init_catalog_db

    local drive_id drive_label drive_type timestamp
    drive_id=$(get_drive_id "$mount_point")
    drive_label=$(get_drive_label "$mount_point")
    drive_type=$(detect_drive_type "$mount_point")
    timestamp=$(date -Iseconds)

    log_info "Cataloging: $drive_label ($mount_point)"

    # Build find args
    local -a find_args=("$mount_point")
    [[ "$recursive" != "true" ]] && find_args+=("-maxdepth" "1")
    find_args+=("-type" "f" \( \
        -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o \
        -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o \
        -iname "*.mpg" -o -iname "*.mpeg" -o -iname "*.3gp" -o \
        -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.aac" -o \
        -iname "*.m4a" -o -iname "*.ogg" -o \
        -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
        -iname "*.gif" -o -iname "*.webp" \
    \))

    local -a media_files
    mapfile -t media_files < <(find "${find_args[@]}" 2>/dev/null | sort)
    local total=${#media_files[@]}

    log_info "Found $total media file(s) — indexing..."

    # Build JSON array of file entries
    local file_entries="[]"
    local processed=0

    for file in "${media_files[@]}"; do
        ((processed++))
        printf "\r${COLOR_CYAN}[%d/%d]${COLOR_RESET} %s" \
            "$processed" "$total" "$(basename "$file")" >&2

        local filename size mtime media_type file_hash
        filename=$(basename "$file")
        size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null || echo 0)
        mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
        media_type=$(get_media_type "$file")
        file_hash=""
        [[ "${CATALOG_INCLUDE_HASH:-false}" == true ]] && file_hash=$(calculate_file_hash "$file")

        local rel_path="${file#${mount_point}/}"
        local video_id
        video_id=$(echo -n "$file" | md5sum | awk '{print $1}')

        file_entries=$(echo "$file_entries" | jq \
            --arg path      "$file" \
            --arg rel       "$rel_path" \
            --arg name      "$filename" \
            --arg type      "$media_type" \
            --argjson sz    "$size" \
            --argjson mt    "$mtime" \
            --arg hash      "$file_hash" \
            --arg drv       "$drive_id" \
            --arg vid       "$video_id" \
            --arg ts        "$timestamp" \
            '. + [{"video_id":$vid,"path":$path,"relative_path":$rel,
                   "filename":$name,"media_type":$type,
                   "file_size":$sz,"file_mtime":$mt,
                   "hash":$hash,"drive_id":$drv,"last_scanned":$ts}]')
    done
    echo "" >&2

    # Replace this drive's entries in catalog DB
    jq --arg drv "$drive_id" \
       --argjson entries "$file_entries" \
       --arg ts "$timestamp" \
       '.videos = ([.videos[] | select(.drive_id != $drv)] + $entries) |
        .last_updated = $ts' \
        "$CATALOG_DB" > "${CATALOG_DB}.tmp" && mv "${CATALOG_DB}.tmp" "$CATALOG_DB"

    # Upsert drive record
    local drive_entry
    drive_entry=$(jq -n \
        --arg id    "$drive_id" \
        --arg label "$drive_label" \
        --arg type  "$drive_type" \
        --arg mount "$mount_point" \
        --argjson n "$total" \
        --arg ts    "$timestamp" \
        '{"id":$id,"label":$label,"type":$type,"mount_point":$mount,
          "file_count":$n,"last_scanned":$ts,"registered_at":$ts}')

    jq --arg drv "$drive_id" \
       --argjson entry "$drive_entry" \
       --arg ts "$timestamp" \
       '.drives = ([.drives[] | select(.id != $drv)] + [$entry]) |
        .last_updated = $ts' \
        "$CATALOG_DRIVES_DB" > "${CATALOG_DRIVES_DB}.tmp" \
        && mv "${CATALOG_DRIVES_DB}.tmp" "$CATALOG_DRIVES_DB"

    log_success "Cataloged $total file(s) from: $drive_label"
    STATS[files_processed]=$(( ${STATS[files_processed]:-0} + total ))
    return 0
}

# List all drives registered in the catalog.
list_cataloged_drives() {
    init_catalog_db

    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required. Install with: sudo apt-get install jq"
        return 1
    fi

    local drive_count
    drive_count=$(jq '.drives | length' "$CATALOG_DRIVES_DB" 2>/dev/null || echo 0)

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Cataloged Drives${COLOR_RESET}  ${COLOR_WHITE}(${drive_count} registered)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}────────────────────────────────────────────────────────────────${COLOR_RESET}"

    if [[ "$drive_count" -eq 0 ]]; then
        echo -e "  ${COLOR_YELLOW}${SYMBOL_INFO} No drives cataloged yet.${COLOR_RESET}"
        echo -e "  Use ${COLOR_WHITE}[1] Scan & Catalog Drive${COLOR_RESET} to add one."
        echo ""
        return 0
    fi

    local total_files=0

    while IFS= read -r drive_json; do
        local label type mount file_count last_scanned registered status_str status_color
        label=$(echo "$drive_json"       | jq -r '.label')
        type=$(echo "$drive_json"        | jq -r '.type')
        mount=$(echo "$drive_json"       | jq -r '.mount_point')
        file_count=$(echo "$drive_json"  | jq -r '.file_count')
        last_scanned=$(echo "$drive_json"| jq -r '.last_scanned // "Never"')
        registered=$(echo "$drive_json"  | jq -r '.registered_at' | cut -c1-10)

        [[ "$last_scanned" != "Never" ]] && last_scanned="${last_scanned:0:10}"

        if [[ -d "$mount" ]] && df "$mount" >/dev/null 2>&1; then
            status_str="Online "; status_color="${COLOR_BRIGHT_GREEN}"
        else
            status_str="Offline"; status_color="${COLOR_RED}"
        fi

        total_files=$(( total_files + file_count ))

        printf "  ${status_color}${SYMBOL_BULLET}${COLOR_RESET} ${COLOR_BOLD}${COLOR_WHITE}%-20s${COLOR_RESET}" "$label"
        printf " ${status_color}[%s]${COLOR_RESET}" "$status_str"
        printf "  %-8s" "$type"
        printf "  ${COLOR_CYAN}%5s files${COLOR_RESET}" "$file_count"
        printf "  Scanned: ${COLOR_WHITE}%s${COLOR_RESET}" "$last_scanned"
        printf "  Added: ${COLOR_WHITE}%s${COLOR_RESET}\n" "$registered"
        echo -e "    ${COLOR_WHITE}${mount}${COLOR_RESET}"
    done < <(jq -c '.drives[]' "$CATALOG_DRIVES_DB" 2>/dev/null)

    echo -e "${COLOR_CYAN}────────────────────────────────────────────────────────────────${COLOR_RESET}"
    echo -e "  ${COLOR_WHITE}Total files cataloged: ${COLOR_BRIGHT_CYAN}${total_files}${COLOR_RESET}"
    echo ""
}

# Search catalog for media files by filename.
# Usage: search_catalog <term> [all|video|image|audio]
search_catalog() {
    local search_term="$1"
    local media_filter="${2:-all}"

    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required. Install with: sudo apt-get install jq"
        return 1
    fi

    if [[ -z "$search_term" ]]; then
        log_error "Usage: search_catalog <term> [all|video|image|audio]"
        return 1
    fi

    init_catalog_db

    local results count
    results=$(jq -c \
        --arg term   "${search_term,,}" \
        --arg filter "$media_filter" \
        '[.videos[] |
          select((.filename | ascii_downcase) | contains($term)) |
          select($filter == "all" or .media_type == $filter)]' \
        "$CATALOG_DB" 2>/dev/null)

    if ! echo "$results" | jq empty 2>/dev/null; then
        log_error "Catalog may be corrupt — run a scan to rebuild it"
        return 1
    fi

    count=$(echo "$results" | jq 'length')

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Results for \"${search_term}\"${COLOR_RESET}  ${COLOR_CYAN}(${count} found)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}────────────────────────────────────────────────────────────────${COLOR_RESET}"

    if [[ "$count" -eq 0 ]]; then
        echo -e "  ${COLOR_YELLOW}No matches found.${COLOR_RESET}"
        echo ""
        return 0
    fi

    echo "$results" | jq -r '.[] | [.filename, .path, .media_type, (.file_size | tostring)] | @tsv' | \
    while IFS=$'\t' read -r filename path media_type size; do
        local size_mb=$(( size / 1048576 ))
        local online_tag
        if [[ -f "$path" ]]; then
            online_tag="${COLOR_BRIGHT_GREEN}[Online] ${COLOR_RESET}"
        else
            online_tag="${COLOR_RED}[Offline]${COLOR_RESET}"
        fi
        echo -e "  ${online_tag} ${COLOR_BOLD}${COLOR_WHITE}${filename}${COLOR_RESET}  ${COLOR_CYAN}${media_type}${COLOR_RESET}  ${size_mb}MB"
        echo -e "    ${COLOR_WHITE}${path}${COLOR_RESET}"
        echo ""
    done

    return 0
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
