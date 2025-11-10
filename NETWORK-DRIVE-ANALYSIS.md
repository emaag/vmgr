# Video Manager Ultimate - Network Drive Navigation Analysis

## Project Overview

**Project Name:** Video Manager Ultimate (vmgr)  
**Type:** Bash-based cross-platform video file management tool  
**Version:** 1.2.0  
**Platforms:** Linux, macOS, Windows (WSL/Git Bash)

### What This Project Does
A comprehensive video management suite that provides:
- File renaming with bracket notation formatting
- Directory flattening and organization
- Duplicate file detection (SHA-256 hash-based)
- Subtitle generation (AI-powered with Whisper)
- Batch file processing
- Multi-drive cataloging system with media metadata extraction
- Undo/rollback functionality
- Cross-platform path handling

---

## Current Navigation Implementation

### 1. Simple Directory Input Method
**Location:** `video-manager-ultimate.sh` lines 4977-4988

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

**Current Behavior:**
- Users manually type the complete path
- Paths are validated using `validate_directory()` from `lib/utils.sh`
- Supports Windows path conversion (C:\path → /mnt/c/path) via `convert_to_wsl_path()` in `lib/platform.sh`
- Currently shows hardcoded examples:
  - `/mnt/c` - Windows C: drive
  - `/mnt/d` - Windows D: drive  
  - `/media/*` - USB drives

### 2. Path Validation
**Location:** `lib/utils.sh` lines 179-205

Validates:
- Directory exists and is readable
- Uses `convert_to_wsl_path()` for Windows path conversion
- Checks path traversal attacks

---

## Path and Drive Handling

### Windows Path Conversion (WSL Support)
**Location:** `lib/platform.sh` lines 164-188

```bash
convert_to_wsl_path() {
    # Converts C:\Users\file → /mnt/c/Users/file
    # Recognizes Windows path format: ^([A-Za-z]):
    # Converts drive letter to lowercase
    # Replaces backslashes with forward slashes
}
```

### Platform Detection
**Location:** `lib/platform.sh` lines 20-40

Detects OS type:
- Linux (native and WSL)
- macOS
- Windows (Cygwin, MinGW, MSYS)

---

## Existing Drive Detection and Management

### 1. Multi-Drive Catalog System
**Global Variables (core.sh lines 152-159):**
```bash
CATALOG_ENABLED=true
CATALOG_DB="$HOME/.video-manager-catalog.json"
CATALOG_DRIVES_DB="$HOME/.video-manager-drives.json"
CATALOG_AUTO_SCAN=false
CATALOG_INCLUDE_METADATA=true
CATALOG_INCLUDE_HASH=true
```

### 2. Drive Type Detection
**Location:** `video-manager-ultimate.sh` lines 3463-3497

Function: `detect_drive_type($mount_point)`

**Detection Methods:**
- **WSL Windows Drives** (`/mnt/[a-z]`): Uses PowerShell to detect bus type
  - USB, SATA/SAS/ATA (Local), NVMe/RAID (Local), iSCSI/FC (NAS)
- **Network/SMB Shares**: Detects via mount info containing "cifs|smb"
- **NAS/NFS Drives**: Detects via mount info containing "nfs"
- **Fuse/Virtual Drives**: Detects via "fuse|9p"
- **Linux Local Drives**: Default for others

**Drive Types Supported:**
- `Local` - Internal hard drives
- `USB` - External USB drives
- `Network` - SMB/CIFS network shares
- `NAS` - NFS network attached storage
- `Unknown` - Unidentified

### 3. Drive ID and Labeling
**Location:** `video-manager-ultimate.sh`

Function: `get_drive_id($mount_point)` (lines 3408-3442)
- Gets UUID for Linux drives via `blkid`
- Gets Volume ID for WSL Windows drives via PowerShell
- Falls back to mount point hash

Function: `get_drive_label($mount_point)` (lines 3445-3461)
- For WSL: Gets Windows volume label via PowerShell
- For others: Uses basename of mount point

### 4. Drive Registration System
**Location:** `video-manager-ultimate.sh` lines 3514-3574

Function: `register_drive($mount_point)`
- Stores drive metadata in JSON database (`$CATALOG_DRIVES_DB`)
- Tracks: drive_id, label, type, mount point, status (online/offline), last_seen
- Updates existing drives if already registered

### 5. Catalog Database Structure
Stores media file metadata with drive associations:
- File path, name, size, type
- Media-specific metadata (resolution, duration, dimensions, etc.)
- Hash for duplicate detection
- Links files to drives via drive_id

---

## Where Network Drive Navigation Would Be Added

### 1. **Missing: Automatic Drive Discovery**
Currently, users must know and manually enter mount points. No feature to:
- List available mounted drives
- Detect newly connected network drives
- Show available network shares on the network
- Detect network drives at known paths (/mnt/y/, /media/networkshare/, etc.)

**Integration Point:** `get_directory_input()` function (line 4977)
- Should provide menu to select from available drives
- Should list detected network drives
- Should show drive type, status, and storage info

### 2. **Missing: Network Drive Navigation Interface**
**Proposed New Function Locations:**
- `lib/navigation.sh` (new module) - Handle interactive directory selection
- Extend `get_directory_input()` with option to browse/select instead of typing

**Key Features Needed:**
```bash
# Detect all available mount points
list_available_mount_points()

# Browse mounted drives interactively
browse_drives()

# Detect network shares (SMB/NFS)
detect_network_shares()

# Show drive selector menu
show_drive_selector()

# Navigate through directory tree
navigate_directory()
```

### 3. **Missing: Network Share Detection**
Currently, code can detect network drives IF already mounted, but cannot:
- Scan for available SMB/CIFS shares on network
- Scan for NFS exports
- Mount network shares automatically
- Show user-friendly share browser

**Required Tools:**
- `mount | grep /mnt` - List all mounts
- `df` - List mounted filesystems with usage
- `smbclient` or `samba` tools for SMB discovery (if available)
- `/etc/fstab` - Check configured shares
- `nfsstat` or similar for NFS

### 4. **Menu Integration Points**
Currently, path selection happens in:
- Line 4977: `get_directory_input()` - All menu operations
- Line 5588-5589: Hardcoded mount point examples in catalog menu

**Where Network Navigation Should Appear:**
1. **Single Operations Menu** - Before file operations
2. **Batch Operations Menu** - Before batch processing
3. **Catalog Menu** (line 4830-4839) - "Scan & Catalog Drive"
   - Currently shows hardcoded examples
   - Should show interactive drive selector

### 5. **Specific Code Locations for Enhancement**

#### Location A: Main Menu Path Selection
**File:** `video-manager-ultimate.sh` line 4977-4988
```bash
# ENHANCEMENT: Replace simple read with menu to select from:
# 1. Recently used paths
# 2. Available drives (local, USB, network)
# 3. Manual path entry
```

#### Location B: Catalog Menu Drive Selection  
**File:** `video-manager-ultimate.sh` line 5588-5610
```bash
# Current: Hardcoded examples
echo "Available mount points:"
echo "  /mnt/c  - Windows C: drive"
echo "  /mnt/d  - Windows D: drive"
echo "  /media/* - USB drives (if mounted)"

# ENHANCEMENT: Should list actual available mounts with:
# - Drive name and type
# - Available storage
# - Last access time
# - Online/offline status (from catalog)
```

#### Location C: New Navigation Module
**File:** `lib/navigation.sh` (NEW)
- Should integrate with existing drive detection code
- Use `detect_drive_type()`, `get_drive_label()`, `get_drive_id()`
- Cache drive info from `$CATALOG_DRIVES_DB`
- Provide interactive selection menu

---

## Key System Components Already in Place

### 1. **Drive Detection** ✓
- Already detects: Local, USB, Network (SMB), NAS (NFS), Fuse/Virtual
- WSL/Windows drive detection via PowerShell
- Already distinguishes drive types

### 2. **Drive Registration** ✓
- JSON-based persistent storage
- Tracks drive status (online/offline)
- Stores metadata per drive

### 3. **Catalog System** ✓
- Stores all media files with drive associations
- Maintains drive database
- Supports metadata extraction

### 4. **Cross-Platform Paths** ✓
- Windows → WSL path conversion
- Platform-specific file operations
- Works with mixed path formats

### 5. **Logging System** ✓
- Comprehensive operation logging
- Error handling and recovery
- Supports verbose/quiet modes

---

## Implementation Gaps for Network Drive Navigation

| Feature | Status | Location | Gap |
|---------|--------|----------|-----|
| Detect drive type | ✓ Complete | Line 3463 | Can identify network drives |
| Register drives | ✓ Complete | Line 3514 | Stores metadata |
| Get drive info | ✓ Complete | Line 3408-3461 | Labels, IDs, types |
| **List available mounts** | ✗ Missing | - | Need function to `mount \| grep` |
| **Interactive drive selector** | ✗ Missing | - | Need menu UI for drive selection |
| **Network share discovery** | ✗ Missing | - | SMB/NFS share browsing |
| **Automatic mount detection** | ✗ Missing | - | Auto-detect /mnt/y/, /media/, etc. |
| **Recently used paths** | ✗ Missing | - | Remember/suggest previous folders |
| **Drive health/status** | ✓ Partial | Line 3850-3880 | Shows cataloged drives but not real-time |
| **User-friendly drive browser** | ✗ Missing | - | Need UI menu for navigation |

---

## Recommended Integration Strategy

### Phase 1: Automatic Mount Point Detection
1. Create `lib/navigation.sh` with drive listing functions
2. Modify `get_directory_input()` to offer menu choice
3. Implement `list_available_mount_points()` using `df` and `mount`
4. Show drives with type, label, and usage info

### Phase 2: Interactive Drive Navigation
1. Create `show_drive_selector()` menu similar to other menus
2. Display detected drives from catalog + real-time mount detection
3. Allow user to select drive, then optionally browse subdirectories
4. Store selection in configuration for quick access

### Phase 3: Network Share Discovery
1. Add SMB/NFS share detection (if samba tools available)
2. Allow mounting of network shares before cataloging
3. Add network share browsing to drive selector

### Phase 4: Enhanced UX
1. Implement recently used paths
2. Add drive bookmarks/favorites
3. Show real-time storage usage on drives
4. Add drive status indicators (online/offline)

---

## Files Summary

### Main Script
- **video-manager-ultimate.sh** (6590 lines)
  - Main navigation: `get_directory_input()` (line 4977)
  - Drive detection: `detect_drive_type()` (line 3463)
  - Drive registration: `register_drive()` (line 3514)
  - Catalog operations: `catalog_drive()` (line 3576)

### Modular Libraries
- **lib/core.sh** - Constants, configuration, initialization
- **lib/platform.sh** - OS detection, path conversion, utilities
- **lib/utils.sh** - Path validation, file operations
- **lib/file-ops.sh** - Rename, flatten, file manipulation
- **lib/organize.sh** - File organization and undo system
- **lib/config.sh** - Configuration save/load
- **lib/logging.sh** - Logging utilities
- **lib/duplicates.sh** - Duplicate detection

### Configuration
- **~/.video-manager.conf** - Main config
- **~/.video-manager-drives.json** - Drive database
- **~/.video-manager-catalog.json** - Media catalog

---

## Network Drive Example Paths

### Linux/WSL Network Mounts
- `/mnt/y/` - Network drive Y (if mounted)
- `/mnt/networkshare/` - NFS/SMB mount
- `/media/networkname/` - Media network mount

### How They're Mounted
```bash
# SMB/CIFS (Windows share)
sudo mount -t cifs //server/share /mnt/y -o credentials=~/.smbcreds

# NFS (Linux/Unix share)
sudo mount -t nfs server:/export /mnt/nfs

# Check mounts
mount | grep -E "cifs|nfs|fuse"

# List all mounts
df -h
```

### Detection Method
Already implemented in `detect_drive_type()`:
```bash
elif echo "$mount_info" | grep -q "cifs\|smb"; then
    drive_type="Network"
elif echo "$mount_info" | grep -q "nfs"; then
    drive_type="NAS"
elif echo "$mount_info" | grep -q "fuse\|9p"; then
    drive_type="Network"
```

---

## Summary

The Video Manager is well-designed for managing files on mounted drives with:
- Comprehensive drive type detection
- Persistent drive catalog
- Network drive identification (if already mounted)
- Cross-platform path handling

What's **missing** for true "network drive navigation" is:
1. **User-friendly drive discovery UI** - Browse and select from available drives
2. **Automatic mount point detection** - Find all mounted drives without manual entry
3. **Network share browsing** - Discover and mount network shares
4. **Interactive directory selector** - Navigate folder hierarchy instead of typing full paths

The foundation is solid; the navigation interface just needs to be enhanced to make network drive access more discoverable and user-friendly.
