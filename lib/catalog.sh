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

# Register a drive in the drives database
register_drive() {
    local mount_point="$1"

    init_catalog_db

    local drive_id=$(get_drive_id "$mount_point")
    local drive_label=$(get_drive_label "$mount_point")
    local drive_type=$(detect_drive_type "$mount_point")
    local timestamp=$(date -Iseconds)

    log_info "Registering drive: $drive_label ($drive_id)"
    log_verbose "  Mount point: $mount_point"
    log_verbose "  Type: $drive_type"

    echo "$drive_id"
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
