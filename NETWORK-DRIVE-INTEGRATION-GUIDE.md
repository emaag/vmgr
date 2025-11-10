# Quick Integration Guide - Network Drive Navigation

## Current Flow Diagram

```
Main Menu (line 4541)
    ↓
User selects operation (1-6)
    ↓
get_directory_input() [LINE 4977] ← ENHANCEMENT POINT #1
    ↓
user enters path manually
    ↓
validate_directory() [lib/utils.sh:179]
    ↓
Operation executes on TARGET_FOLDER
```

## Enhanced Flow (Proposed)

```
Main Menu (line 4541)
    ↓
User selects operation (1-6)
    ↓
get_directory_input_enhanced() [REPLACE LINE 4977]
    ├─ Option 1: Browse available drives [NEW]
    │   └─ show_drive_selector() [NEW in lib/navigation.sh]
    │       ├─ list_available_mount_points() [NEW]
    │       └─ detect_drive_type() [EXISTING - line 3463]
    │
    ├─ Option 2: Recent paths [NEW]
    │   └─ get_recent_paths() [NEW]
    │
    └─ Option 3: Manual path entry [EXISTING]
        └─ validate_directory() [EXISTING - lib/utils.sh:179]
    ↓
Operation executes on TARGET_FOLDER
```

---

## Code Locations Summary

### PRIMARY INTEGRATION POINTS

#### 1. Main Navigation Function (MUST MODIFY)
```
File:     video-manager-ultimate.sh
Function: get_directory_input()
Lines:    4977-4988
Purpose:  Get directory path from user
Current:  Simple read with validation
Change:   Add menu to select from available drives
```

#### 2. Catalog Menu Drive Selection (SHOULD ENHANCE)
```
File:     video-manager-ultimate.sh
Function: handle_catalog_menu() [inside interactive_menu()]
Lines:    5585-5610
Purpose:  Let user select drive to catalog
Current:  Hardcoded mount point examples
Change:   Show detected drives with types/status
```

#### 3. New Navigation Module (CREATE)
```
File:     lib/navigation.sh [NEW]
Purpose:  Provide drive discovery and selection functions
Contains: 
  - list_available_mount_points()
  - show_drive_selector()
  - get_drive_usage()
  - etc.
```

---

## Step-by-Step Implementation

### Step 1: Create lib/navigation.sh

```bash
# lib/navigation.sh
#!/bin/bash
# Navigation module for drive discovery and selection

# List all available mount points with details
list_available_mount_points() {
    local -a mounts
    local -A mount_info  # associative array
    
    # Parse df output for mounted filesystems
    # Parse /proc/mounts or mount command
    # Return array of mount points
}

# Show interactive drive selector menu
show_drive_selector() {
    # Display menu of available drives
    # Show: Name, Type, Size, Used, Available
    # Let user select one
    # Return selected mount point
}

# Get storage usage info for mount point
get_drive_usage() {
    local mount="$1"
    # Use df to get: total, used, available, percent
    # Return formatted string
}

# Browse directory contents interactively
navigate_directory() {
    local current_dir="$1"
    # Show subdirectories
    # Let user select or go up
    # Return selected path
}

# Get recently used paths
get_recent_paths() {
    # Read from config or history file
    # Return recent directories
}
```

### Step 2: Modify get_directory_input()

**Current Code (lines 4977-4988):**
```bash
get_directory_input() {
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Enter directory path: "
    read -r dir
    dir=$(validate_directory "$dir")
    if [[ $? -eq 0 ]]; then
        TARGET_FOLDER="$dir"
        return 0
    else
        return 1
    fi
}
```

**Enhanced Version:**
```bash
get_directory_input() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}SELECT DIRECTORY${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}[1]${COLOR_RESET} ${COLOR_WHITE}Browse Available Drives${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[2]${COLOR_RESET} ${COLOR_WHITE}Recent Folders${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}[3]${COLOR_RESET} ${COLOR_WHITE}Enter Path Manually${COLOR_RESET}"
    echo ""
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Choose option: "
    read -r choice
    
    case "$choice" in
        1) 
            local selected=$(show_drive_selector)
            [[ -n "$selected" ]] && TARGET_FOLDER="$selected" && return 0
            return 1
            ;;
        2)
            local selected=$(get_recent_paths | fzf)
            [[ -n "$selected" ]] && TARGET_FOLDER="$selected" && return 0
            return 1
            ;;
        3)
            echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Enter directory path: "
            read -r dir
            dir=$(validate_directory "$dir")
            if [[ $? -eq 0 ]]; then
                TARGET_FOLDER="$dir"
                return 0
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}
```

### Step 3: Enhance Catalog Menu

**Current Code (lines 5585-5610):**
```bash
# Shows hardcoded examples
echo "Available mount points:"
echo "  /mnt/c  - Windows C: drive"
echo "  /mnt/d  - Windows D: drive"
echo "  /media/* - USB drives (if mounted)"
```

**Enhanced Version:**
```bash
# Show actual available mounts
show_available_mounts_for_catalog() {
    local -a mounts
    local count=0
    
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Available Drives:${COLOR_RESET}"
    echo ""
    
    while IFS='|' read -r mount_point drive_type size; do
        ((count++))
        local type_icon="$(get_drive_icon "$drive_type")"
        local size_formatted="$(format_bytes "$size")"
        
        echo -e "${COLOR_BRIGHT_GREEN}[$count]${COLOR_RESET} $type_icon ${COLOR_WHITE}$mount_point${COLOR_RESET}"
        echo -e "    Type: $drive_type | Size: $size_formatted"
        echo ""
    done < <(list_available_mount_points)
    
    if [[ $count -eq 0 ]]; then
        echo -e "${COLOR_YELLOW}No mounted drives detected${COLOR_RESET}"
    fi
}
```

### Step 4: Update Module Sourcing

**File:** video-manager-ultimate.sh (top of script)

Add to the module sourcing section:
```bash
source "$(dirname "$0")/lib/navigation.sh" || {
    echo "Error: Failed to load navigation module"
    exit 1
}
```

---

## Key Functions to Create

### list_available_mount_points()
**Purpose:** Detect all mounted drives
**Dependencies:** df, mount, blkid
**Returns:** Tab-separated: mount_point|drive_type|size

```bash
Example Output:
/mnt/c|Local|1099511627776
/mnt/y|Network|2199023255552
/media/usb|USB|67108864
```

### show_drive_selector()
**Purpose:** Interactive menu to select a drive
**Dependencies:** list_available_mount_points(), detect_drive_type()
**Returns:** Selected mount point or empty string

### get_drive_icon()
**Purpose:** Return emoji/symbol for drive type
**Dependencies:** None
**Returns:** Icon character

```bash
Local  → "📁"
USB    → "🔌"
Network→ "🌐"
NAS    → "💾"
```

### get_recent_paths()
**Purpose:** Return recently used directories
**Dependencies:** Config file read
**Returns:** List of paths

### get_drive_usage()
**Purpose:** Get storage usage for mount point
**Dependencies:** df
**Returns:** Used/Total/Available in bytes

---

## Integration Checklist

- [ ] Create `lib/navigation.sh` with required functions
- [ ] Source navigation.sh in video-manager-ultimate.sh
- [ ] Modify `get_directory_input()` to use new navigation menu
- [ ] Update catalog menu to show actual mounted drives
- [ ] Test with various mount types:
  - [ ] Local drives (/mnt/c in WSL)
  - [ ] USB drives (/media/*)
  - [ ] Network drives (CIFS/SMB)
  - [ ] NAS drives (NFS)
- [ ] Add configuration for recent paths storage
- [ ] Test on all platforms:
  - [ ] Linux
  - [ ] macOS
  - [ ] WSL
  - [ ] Git Bash

---

## Testing Network Drives

### Create Test Network Mount
```bash
# Create dummy NFS mount (for testing)
mkdir -p /mnt/test-nfs
sudo mount -t tmpfs none /mnt/test-nfs  # Simulates mount

# Or with actual network
sudo mount -t cifs //server/share /mnt/y -o username=user,password=pass
```

### Test Detection
```bash
# Test detect_drive_type
detect_drive_type "/mnt/y"  # Should return "Network"

# Test list_available_mount_points
list_available_mount_points

# Test show_drive_selector
show_drive_selector  # Should show interactive menu
```

---

## Related Code Already in Place

These functions ALREADY EXIST and should be reused:

1. **detect_drive_type()** - Line 3463
   - Already detects Network, NAS, Local, USB
   
2. **get_drive_id()** - Line 3408
   - Gets unique drive identifier
   
3. **get_drive_label()** - Line 3445
   - Gets friendly drive name
   
4. **register_drive()** - Line 3514
   - Stores drive in catalog
   
5. **validate_directory()** - lib/utils.sh:179
   - Already validates paths
   
6. **convert_to_wsl_path()** - lib/platform.sh:164
   - Converts Windows paths to WSL format

---

## Example: Complete show_drive_selector() Function

```bash
show_drive_selector() {
    # Load available mounts
    local -a mounts
    local -a types
    local -a labels
    local count=0
    
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╭─────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_YELLOW}AVAILABLE DRIVES${COLOR_RESET}                      ${COLOR_BOLD}${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╰─────────────────────────────────────────╯${COLOR_RESET}"
    echo ""
    
    # Use list_available_mount_points and populate arrays
    while IFS='|' read -r mount_point drive_type size; do
        ((count++))
        mounts+=("$mount_point")
        types+=("$drive_type")
        
        local label=$(get_drive_label "$mount_point")
        labels+=("$label")
        
        local usage=$(get_drive_usage "$mount_point")
        local icon=""
        
        case "$drive_type" in
            Local) icon="📁" ;;
            USB) icon="🔌" ;;
            Network) icon="🌐" ;;
            NAS) icon="💾" ;;
            *) icon="❓" ;;
        esac
        
        echo -e "${COLOR_BRIGHT_GREEN}[$count]${COLOR_RESET} $icon ${COLOR_WHITE}${label}${COLOR_RESET}"
        echo -e "    Mount: ${COLOR_CYAN}$mount_point${COLOR_RESET}"
        echo -e "    Type: $drive_type | $usage"
        echo ""
    done < <(list_available_mount_points)
    
    if [[ $count -eq 0 ]]; then
        echo -e "${COLOR_YELLOW}No mounted drives found${COLOR_RESET}"
        return 1
    fi
    
    echo -n "${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} Select drive [1-$count]: "
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le $count ]]; then
        echo "${mounts[$((choice-1))]}"
        return 0
    fi
    
    return 1
}
```

---

## File Change Summary

| File | Change | Lines | Type |
|------|--------|-------|------|
| lib/navigation.sh | Create new module | New | Add |
| video-manager-ultimate.sh | Add navigation sourcing | ~20 | Add |
| video-manager-ultimate.sh | Enhance get_directory_input() | 4977-4988 | Modify |
| video-manager-ultimate.sh | Enhance catalog menu | 5585-5610 | Modify |
| lib/core.sh | Add RECENT_PATHS config | Optional | Add |

---

## Performance Considerations

1. **Mount listing** - `df` and `mount` commands are fast (<100ms)
2. **Drive detection** - Already fast, uses cache via catalog
3. **Caching** - Consider caching mount list for 5 seconds to avoid repeated queries
4. **Network timeouts** - Network drives might timeout, add timeout handling
5. **Large directories** - Directory browsing needs pagination for 1000+ files

