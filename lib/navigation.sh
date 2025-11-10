#!/bin/bash
# navigation.sh - Interactive navigation system for Video Manager Ultimate
# Provides drive discovery, directory browsing, favorites, and search

# Configuration
RECENT_PATHS_FILE="${CONFIG_DIR:-$HOME/.config/video-manager}/recent_paths.json"
FAVORITES_FILE="${CONFIG_DIR:-$HOME/.config/video-manager}/favorites.json"
MAX_RECENT_PATHS=20

# Ensure config directory exists
mkdir -p "$(dirname "$RECENT_PATHS_FILE")"

#######################################
# List all available mount points with detailed information
# Returns: Array of mount points with type, device, and usage info
#######################################
list_available_mount_points() {
    local mount_points=()
    local line device mount_point fs_type

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS mount point detection
        while IFS= read -r line; do
            device=$(echo "$line" | awk '{print $1}')
            mount_point=$(echo "$line" | awk '{print $3}')
            fs_type=$(echo "$line" | awk '{print $4}' | tr -d '()')

            # Skip system mounts
            [[ "$mount_point" == "/dev" || "$mount_point" == "/System"* ]] && continue

            mount_points+=("$mount_point|$fs_type|$device")
        done < <(mount | grep -E "^/dev/|^//")
    else
        # Linux mount point detection
        while IFS= read -r line; do
            device=$(echo "$line" | awk '{print $1}')
            mount_point=$(echo "$line" | awk '{print $3}')
            fs_type=$(echo "$line" | awk '{print $5}')

            # Skip system mounts
            [[ "$mount_point" =~ ^/(proc|sys|dev|run) ]] && continue
            [[ "$mount_point" == "/boot"* ]] && continue
            [[ "$mount_point" == "/snap"* ]] && continue

            # Include: /, /home, /mnt/*, /media/*, network shares, USB drives
            if [[ "$mount_point" == "/" ]] || \
               [[ "$mount_point" == "/home" ]] || \
               [[ "$mount_point" =~ ^/mnt/ ]] || \
               [[ "$mount_point" =~ ^/media/ ]] || \
               [[ "$fs_type" =~ (cifs|smb|nfs|fuse) ]]; then
                mount_points+=("$mount_point|$fs_type|$device")
            fi
        done < <(mount)
    fi

    printf '%s\n' "${mount_points[@]}"
}

#######################################
# Get drive usage information
# Arguments:
#   $1 - Mount point path
# Returns: Usage string (e.g., "45G / 100G (45%)")
#######################################
get_drive_usage() {
    local mount_point="$1"
    local usage

    if ! [ -d "$mount_point" ]; then
        echo "N/A"
        return 1
    fi

    if command -v df &> /dev/null; then
        usage=$(df -h "$mount_point" 2>/dev/null | tail -1 | awk '{print $3 " / " $2 " (" $5 ")"}')
        echo "${usage:-N/A}"
    else
        echo "N/A"
    fi
}

#######################################
# Determine drive type from filesystem and device info
# Arguments:
#   $1 - Filesystem type
#   $2 - Device name
#   $3 - Mount point
# Returns: Human-readable drive type
#######################################
get_drive_type_label() {
    local fs_type="$1"
    local device="$2"
    local mount_point="$3"

    case "$fs_type" in
        cifs|smb|smbfs)
            echo "Network (SMB/CIFS)"
            ;;
        nfs|nfs4)
            echo "Network (NFS)"
            ;;
        fuse*|9p)
            echo "Virtual/Fuse"
            ;;
        vfat|exfat|ntfs|fuseblk)
            if [[ "$device" =~ (sd[b-z]|mmcblk|nvme) ]]; then
                echo "USB/External"
            else
                echo "Local Drive"
            fi
            ;;
        ext4|ext3|btrfs|xfs)
            if [[ "$mount_point" == "/" ]] || [[ "$mount_point" == "/home" ]]; then
                echo "System Drive"
            else
                echo "Local Drive"
            fi
            ;;
        *)
            echo "Other ($fs_type)"
            ;;
    esac
}

#######################################
# Show interactive drive selector menu
# Returns: Selected mount point path or empty if cancelled
#######################################
show_drive_selector() {
    local mount_points=()
    local display_items=()
    local line mount_point fs_type device drive_type usage
    local selection

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                        AVAILABLE DRIVES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Collect mount points
    while IFS= read -r line; do
        mount_point=$(echo "$line" | cut -d'|' -f1)
        fs_type=$(echo "$line" | cut -d'|' -f2)
        device=$(echo "$line" | cut -d'|' -f3)

        drive_type=$(get_drive_type_label "$fs_type" "$device" "$mount_point")
        usage=$(get_drive_usage "$mount_point")

        mount_points+=("$mount_point")
        display_items+=("$mount_point|$drive_type|$usage")
    done < <(list_available_mount_points)

    if [ ${#mount_points[@]} -eq 0 ]; then
        echo "No accessible drives found."
        echo ""
        return 1
    fi

    # Display drives with numbers
    local i=1
    for item in "${display_items[@]}"; do
        mount_point=$(echo "$item" | cut -d'|' -f1)
        drive_type=$(echo "$item" | cut -d'|' -f2)
        usage=$(echo "$item" | cut -d'|' -f3)

        printf "[%2d] %-30s  %-20s  %s\n" "$i" "$mount_point" "$drive_type" "$usage"
        ((i++))
    done

    echo ""
    echo "[0] Cancel"
    echo ""
    echo -n "Select drive [0-${#mount_points[@]}]: "
    read -r selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#mount_points[@]}" ]; then
        echo "${mount_points[$((selection-1))]}"
        return 0
    else
        echo ""
        return 1
    fi
}

#######################################
# Navigate through directories interactively
# Arguments:
#   $1 - Starting directory path
# Returns: Selected directory path or empty if cancelled
#######################################
navigate_directory() {
    local current_dir="$1"
    local selection item
    local items=()

    # Validate starting directory
    if ! [ -d "$current_dir" ]; then
        echo "Error: Directory does not exist: $current_dir" >&2
        return 1
    fi

    while true; do
        items=()

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Current: $current_dir"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Add parent directory option if not at root
        if [ "$current_dir" != "/" ]; then
            echo "[↑] Parent Directory ($(dirname "$current_dir"))"
        fi

        echo "[✓] Select Current Directory"
        echo "[⌕] Search in this directory"
        echo "[0] Cancel"
        echo ""

        # List subdirectories
        local i=1
        while IFS= read -r item; do
            if [ -d "$item" ]; then
                items+=("$item")
                local basename=$(basename "$item")
                printf "[%2d] 📁 %s\n" "$i" "$basename"
                ((i++))
            fi
        done < <(find "$current_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

        if [ ${#items[@]} -eq 0 ]; then
            echo "(No subdirectories found)"
        fi

        echo ""
        echo -n "Selection [↑/✓/⌕/0-${#items[@]}]: "
        read -r selection

        case "$selection" in
            "↑"|".."|"up")
                if [ "$current_dir" != "/" ]; then
                    current_dir=$(dirname "$current_dir")
                fi
                ;;
            "✓"|""|".")
                echo "$current_dir"
                return 0
                ;;
            "⌕"|"search"|"s")
                local search_result
                search_result=$(search_directory "$current_dir")
                if [ -n "$search_result" ]; then
                    echo "$search_result"
                    return 0
                fi
                ;;
            0)
                echo ""
                return 1
                ;;
            *)
                if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#items[@]}" ]; then
                    current_dir="${items[$((selection-1))]}"
                else
                    echo "Invalid selection."
                    sleep 1
                fi
                ;;
        esac
    done
}

#######################################
# Search for directories within a path
# Arguments:
#   $1 - Base directory to search in
# Returns: Selected directory path or empty if cancelled
#######################################
search_directory() {
    local base_dir="$1"
    local search_term
    local results=()
    local selection

    echo ""
    echo -n "Enter search term (directory name): "
    read -r search_term

    if [ -z "$search_term" ]; then
        return 1
    fi

    echo ""
    echo "Searching for '*$search_term*' in $base_dir..."
    echo ""

    # Search for matching directories (max depth 5)
    while IFS= read -r item; do
        results+=("$item")
    done < <(find "$base_dir" -maxdepth 5 -type d -iname "*$search_term*" 2>/dev/null | sort)

    if [ ${#results[@]} -eq 0 ]; then
        echo "No matching directories found."
        sleep 2
        return 1
    fi

    echo "Found ${#results[@]} matching directories:"
    echo ""

    local i=1
    for item in "${results[@]}"; do
        printf "[%2d] %s\n" "$i" "$item"
        ((i++))

        # Limit display to 20 results
        if [ $i -gt 20 ]; then
            echo "... (showing first 20 of ${#results[@]} results)"
            break
        fi
    done

    echo ""
    echo "[0] Cancel"
    echo ""
    echo -n "Select directory [0-$([ ${#results[@]} -lt 20 ] && echo ${#results[@]} || echo 20)]: "
    read -r selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#results[@]}" ]; then
        echo "${results[$((selection-1))]}"
        return 0
    else
        return 1
    fi
}

#######################################
# Add path to recent history
# Arguments:
#   $1 - Directory path to add
#######################################
add_to_recent_paths() {
    local new_path="$1"
    local recent_paths=()

    # Load existing recent paths
    if [ -f "$RECENT_PATHS_FILE" ]; then
        while IFS= read -r line; do
            recent_paths+=("$line")
        done < <(jq -r '.recent_paths[]' "$RECENT_PATHS_FILE" 2>/dev/null || echo "")
    fi

    # Remove duplicates of new path
    local filtered_paths=()
    for path in "${recent_paths[@]}"; do
        [ "$path" != "$new_path" ] && filtered_paths+=("$path")
    done

    # Add new path to front
    filtered_paths=("$new_path" "${filtered_paths[@]}")

    # Limit to MAX_RECENT_PATHS
    if [ ${#filtered_paths[@]} -gt $MAX_RECENT_PATHS ]; then
        filtered_paths=("${filtered_paths[@]:0:$MAX_RECENT_PATHS}")
    fi

    # Save to file
    local json_array=$(printf '%s\n' "${filtered_paths[@]}" | jq -R . | jq -s .)
    echo "{\"recent_paths\": $json_array}" > "$RECENT_PATHS_FILE"
}

#######################################
# Show recent paths menu
# Returns: Selected path or empty if cancelled
#######################################
show_recent_paths() {
    local recent_paths=()
    local selection

    if ! [ -f "$RECENT_PATHS_FILE" ]; then
        echo ""
        echo "No recent paths found."
        sleep 1
        return 1
    fi

    while IFS= read -r line; do
        recent_paths+=("$line")
    done < <(jq -r '.recent_paths[]' "$RECENT_PATHS_FILE" 2>/dev/null || echo "")

    if [ ${#recent_paths[@]} -eq 0 ]; then
        echo ""
        echo "No recent paths found."
        sleep 1
        return 1
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                        RECENT PATHS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local i=1
    for path in "${recent_paths[@]}"; do
        printf "[%2d] %s\n" "$i" "$path"
        ((i++))
    done

    echo ""
    echo "[0] Cancel"
    echo ""
    echo -n "Select recent path [0-${#recent_paths[@]}]: "
    read -r selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#recent_paths[@]}" ]; then
        echo "${recent_paths[$((selection-1))]}"
        return 0
    else
        echo ""
        return 1
    fi
}

#######################################
# Add directory to favorites
# Arguments:
#   $1 - Directory path
#   $2 - Optional label/name
#######################################
add_to_favorites() {
    local dir_path="$1"
    local label="${2:-$(basename "$dir_path")}"
    local favorites=()

    # Load existing favorites
    if [ -f "$FAVORITES_FILE" ]; then
        while IFS='|' read -r saved_label saved_path; do
            favorites+=("$saved_label|$saved_path")
        done < <(jq -r '.favorites[] | .label + "|" + .path' "$FAVORITES_FILE" 2>/dev/null || echo "")
    fi

    # Check for duplicates
    for fav in "${favorites[@]}"; do
        if [[ "$fav" == *"|$dir_path" ]]; then
            echo "Path already in favorites."
            return 1
        fi
    done

    # Add new favorite
    favorites+=("$label|$dir_path")

    # Save to file
    local json_items=""
    for fav in "${favorites[@]}"; do
        local fav_label=$(echo "$fav" | cut -d'|' -f1)
        local fav_path=$(echo "$fav" | cut -d'|' -f2-)
        json_items="$json_items{\"label\": \"$fav_label\", \"path\": \"$fav_path\"},"
    done
    json_items="${json_items%,}"  # Remove trailing comma

    echo "{\"favorites\": [$json_items]}" > "$FAVORITES_FILE"
    echo "Added to favorites: $label"
}

#######################################
# Show favorites menu
# Returns: Selected path or empty if cancelled
#######################################
show_favorites() {
    local favorites_labels=()
    local favorites_paths=()
    local selection

    if ! [ -f "$FAVORITES_FILE" ]; then
        echo ""
        echo "No favorites found."
        echo ""
        echo -n "Press Enter to continue..."
        read -r
        return 1
    fi

    while IFS='|' read -r label path; do
        favorites_labels+=("$label")
        favorites_paths+=("$path")
    done < <(jq -r '.favorites[] | .label + "|" + .path' "$FAVORITES_FILE" 2>/dev/null || echo "")

    if [ ${#favorites_paths[@]} -eq 0 ]; then
        echo ""
        echo "No favorites found."
        echo ""
        echo -n "Press Enter to continue..."
        read -r
        return 1
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                        FAVORITES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local i=1
    for idx in "${!favorites_labels[@]}"; do
        printf "[%2d] %-30s  %s\n" "$i" "${favorites_labels[$idx]}" "${favorites_paths[$idx]}"
        ((i++))
    done

    echo ""
    echo "[D] Delete a favorite"
    echo "[0] Cancel"
    echo ""
    echo -n "Selection [0-${#favorites_paths[@]}/D]: "
    read -r selection

    if [[ "$selection" =~ ^[Dd]$ ]]; then
        manage_favorites_delete
        return 1
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#favorites_paths[@]}" ]; then
        echo "${favorites_paths[$((selection-1))]}"
        return 0
    else
        echo ""
        return 1
    fi
}

#######################################
# Delete a favorite
#######################################
manage_favorites_delete() {
    local favorites_labels=()
    local favorites_paths=()
    local selection

    while IFS='|' read -r label path; do
        favorites_labels+=("$label")
        favorites_paths+=("$path")
    done < <(jq -r '.favorites[] | .label + "|" + .path' "$FAVORITES_FILE" 2>/dev/null || echo "")

    if [ ${#favorites_paths[@]} -eq 0 ]; then
        return
    fi

    echo ""
    echo "Select favorite to delete:"
    echo ""

    local i=1
    for idx in "${!favorites_labels[@]}"; do
        printf "[%2d] %-30s  %s\n" "$i" "${favorites_labels[$idx]}" "${favorites_paths[$idx]}"
        ((i++))
    done

    echo ""
    echo "[0] Cancel"
    echo ""
    echo -n "Delete [0-${#favorites_paths[@]}]: "
    read -r selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#favorites_paths[@]}" ]; then
        local idx=$((selection-1))

        # Remove selected favorite
        unset "favorites_labels[$idx]"
        unset "favorites_paths[$idx]"

        # Rebuild arrays
        favorites_labels=("${favorites_labels[@]}")
        favorites_paths=("${favorites_paths[@]}")

        # Save to file
        local json_items=""
        for i in "${!favorites_labels[@]}"; do
            json_items="$json_items{\"label\": \"${favorites_labels[$i]}\", \"path\": \"${favorites_paths[$i]}\"},"
        done
        json_items="${json_items%,}"

        echo "{\"favorites\": [$json_items]}" > "$FAVORITES_FILE"
        echo ""
        echo "Favorite deleted."
        sleep 1
    fi
}

#######################################
# Main navigation interface - unified entry point
# Returns: Selected directory path or empty if cancelled
#######################################
interactive_navigation() {
    local selection selected_path

    while true; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "                    NAVIGATION MENU"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "[1] Browse Available Drives (Local, Network, USB)"
        echo "[2] Recent Paths"
        echo "[3] Favorites"
        echo "[4] Enter Path Manually"
        echo "[0] Cancel"
        echo ""
        echo -n "Select option [0-4]: "
        read -r selection

        case "$selection" in
            1)
                selected_path=$(show_drive_selector)
                if [ -n "$selected_path" ]; then
                    selected_path=$(navigate_directory "$selected_path")
                    if [ -n "$selected_path" ]; then
                        echo "$selected_path"
                        return 0
                    fi
                fi
                ;;
            2)
                selected_path=$(show_recent_paths)
                if [ -n "$selected_path" ] && [ -d "$selected_path" ]; then
                    echo "$selected_path"
                    return 0
                elif [ -n "$selected_path" ]; then
                    echo "Path no longer exists: $selected_path"
                    sleep 2
                fi
                ;;
            3)
                selected_path=$(show_favorites)
                if [ -n "$selected_path" ] && [ -d "$selected_path" ]; then
                    echo "$selected_path"
                    return 0
                elif [ -n "$selected_path" ]; then
                    echo "Path no longer exists: $selected_path"
                    sleep 2
                fi
                ;;
            4)
                echo ""
                echo -n "Enter directory path: "
                read -r selected_path
                if [ -n "$selected_path" ]; then
                    echo "$selected_path"
                    return 0
                fi
                ;;
            0)
                echo ""
                return 1
                ;;
            *)
                echo "Invalid selection."
                sleep 1
                ;;
        esac
    done
}
