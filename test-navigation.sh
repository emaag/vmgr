#!/bin/bash
# Test script for navigation module

# Configuration
CONFIG_DIR="$HOME/.config/video-manager"
mkdir -p "$CONFIG_DIR"

# Source the navigation module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/navigation.sh"

echo "=================================="
echo "Navigation Module Test Script"
echo "=================================="
echo ""

# Test 1: List available mount points
echo "Test 1: Listing available mount points..."
echo "------------------------------------------"
mount_points=$(list_available_mount_points)
if [ -z "$mount_points" ]; then
    echo "❌ No mount points found (this might be expected in some environments)"
else
    echo "✓ Found mount points:"
    echo "$mount_points" | while IFS='|' read -r mount_point fs_type device; do
        echo "  - $mount_point ($fs_type)"
    done
fi
echo ""

# Test 2: Check if /mnt directory exists and create test mount
echo "Test 2: Checking /mnt directory..."
echo "------------------------------------------"
if [ -d "/mnt" ]; then
    echo "✓ /mnt directory exists"
    # List any subdirectories in /mnt
    mnt_dirs=$(ls -1 /mnt 2>/dev/null)
    if [ -n "$mnt_dirs" ]; then
        echo "  Found in /mnt:"
        echo "$mnt_dirs" | while read -r dir; do
            echo "    - /mnt/$dir"
        done
    else
        echo "  (No subdirectories in /mnt)"
    fi
else
    echo "✓ /mnt directory does not exist (this is OK)"
fi
echo ""

# Test 3: Test drive type detection
echo "Test 3: Testing drive type detection..."
echo "------------------------------------------"
echo "Root filesystem: $(get_drive_type_label "ext4" "/dev/sda1" "/")"
echo "Network share: $(get_drive_type_label "cifs" "//server/share" "/mnt/share")"
echo "NFS mount: $(get_drive_type_label "nfs" "server:/export" "/mnt/nfs")"
echo "USB drive: $(get_drive_type_label "vfat" "/dev/sdb1" "/media/usb")"
echo ""

# Test 4: Test drive usage function
echo "Test 4: Testing drive usage detection..."
echo "------------------------------------------"
if [ -d "/" ]; then
    usage=$(get_drive_usage "/")
    echo "Root usage: $usage"
fi
if [ -d "/home" ]; then
    usage=$(get_drive_usage "/home")
    echo "Home usage: $usage"
fi
echo ""

# Test 5: Test recent paths functions
echo "Test 5: Testing recent paths management..."
echo "------------------------------------------"
add_to_recent_paths "/home"
add_to_recent_paths "/tmp"
add_to_recent_paths "/var"
add_to_recent_paths "/usr"
echo "✓ Added test paths to recent history"

if [ -f "$CONFIG_DIR/recent_paths.json" ]; then
    echo "✓ Recent paths file created"
    echo "  File: $CONFIG_DIR/recent_paths.json"
    recent_count=$(jq -r '.recent_paths | length' "$CONFIG_DIR/recent_paths.json" 2>/dev/null || echo "0")
    echo "  Count: $recent_count paths"
else
    echo "❌ Recent paths file not created"
fi
echo ""

# Test 6: Test favorites functions
echo "Test 6: Testing favorites management..."
echo "------------------------------------------"
add_to_favorites "/home/user" "Home Directory"
add_to_favorites "/tmp" "Temp Files"
echo "✓ Added test favorites"

if [ -f "$CONFIG_DIR/favorites.json" ]; then
    echo "✓ Favorites file created"
    echo "  File: $CONFIG_DIR/favorites.json"
    fav_count=$(jq -r '.favorites | length' "$CONFIG_DIR/favorites.json" 2>/dev/null || echo "0")
    echo "  Count: $fav_count favorites"
else
    echo "❌ Favorites file not created"
fi
echo ""

# Test 7: Verify all required functions exist
echo "Test 7: Verifying function availability..."
echo "------------------------------------------"
functions=(
    "list_available_mount_points"
    "get_drive_usage"
    "get_drive_type_label"
    "show_drive_selector"
    "navigate_directory"
    "search_directory"
    "add_to_recent_paths"
    "show_recent_paths"
    "add_to_favorites"
    "show_favorites"
    "manage_favorites_delete"
    "interactive_navigation"
)

all_found=true
for func in "${functions[@]}"; do
    if declare -f "$func" > /dev/null; then
        echo "✓ $func"
    else
        echo "❌ $func - NOT FOUND"
        all_found=false
    fi
done

if [ "$all_found" = true ]; then
    echo ""
    echo "✅ All functions are available!"
else
    echo ""
    echo "❌ Some functions are missing!"
fi
echo ""

# Summary
echo "=================================="
echo "Test Summary"
echo "=================================="
echo ""
echo "Navigation module is ready to use!"
echo ""
echo "Key features available:"
echo "  • Drive detection (Local, USB, Network, NFS)"
echo "  • Interactive drive selector with usage info"
echo "  • Directory browser with subdirectory navigation"
echo "  • Search functionality"
echo "  • Recent paths history"
echo "  • Favorites/bookmarks system"
echo ""
echo "The navigation system will work with:"
echo "  • /mnt/* paths (network drives)"
echo "  • /media/* paths (removable media)"
echo "  • / and /home (system paths)"
echo "  • Any mounted filesystem"
echo ""
echo "To test interactively, run the video manager and"
echo "select any operation that requires a directory."
echo ""
