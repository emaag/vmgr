# Video Manager - Architecture Overview

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    INTERACTIVE MENU SYSTEM                     │
│                  (video-manager-ultimate.sh)                   │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   File Ops   │  │  Subtitles   │  │  Duplicates  │  ...    │
│  │   Menu (1)   │  │   Menu (2)   │  │   Menu (3)   │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                 │                  │
│         └─────────────────┼─────────────────┘                  │
│                           │                                    │
│                    get_directory_input() ◄─── ENHANCEMENT     │
│                    (line 4977) [CURRENT]     POINT #1         │
│                           │                                    │
│         ┌─────────────────┼─────────────────┐                  │
│         │                 │                 │                  │
│    [1] Browse      [2] Recent      [3] Manual Input           │
│    Drives          Folders        (Current only)              │
│         │                 │                 │                  │
│         └─────────────────┼─────────────────┘                  │
│                           │                                    │
│                    TARGET_FOLDER variable                      │
│                           │                                    │
│         ┌─────────────────┴─────────────────┐                  │
│         │                                   │                  │
│      FILE OPS                           CATALOG                │
│   (rename/flatten/                   (catalog/search)          │
│    organize/etc)                  [ENHANCEMENT POINT #2]       │
│                                      (line 5585)               │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Module Structure

```
video-manager-ultimate.sh (6590 lines)
│
├── lib/core.sh
│   ├── Constants (colors, symbols, extensions)
│   ├── Configuration variables
│   └── Logging functions
│
├── lib/platform.sh
│   ├── OS detection (Linux/macOS/Windows/WSL)
│   ├── convert_to_wsl_path()
│   ├── File operations (platform-specific)
│   └── Dependency checking
│
├── lib/utils.sh
│   ├── validate_directory()
│   ├── Path sanitization
│   ├── File type detection
│   ├── Media metadata extraction
│   └── Filters and confirmation
│
├── lib/file-ops.sh
│   ├── apply_bracket_notation()
│   ├── rename_files_in_directory()
│   └── flatten_directory()
│
├── lib/organize.sh
│   ├── Undo system (JSON-based)
│   ├── Operation logging
│   └── File organization helpers
│
├── lib/config.sh
│   ├── save_config()
│   ├── load_config()
│   └── Configuration profiles
│
├── lib/logging.sh
│   ├── log_info(), log_error(), etc.
│   └── Operation tracking
│
├── lib/duplicates.sh
│   ├── Duplicate detection
│   └── Hash-based comparison
│
└── lib/navigation.sh [NEW - TO BE CREATED]
    ├── list_available_mount_points()
    ├── show_drive_selector()
    ├── get_drive_usage()
    ├── get_recent_paths()
    └── navigate_directory()
```

## Data Flow: Path Selection

### CURRENT FLOW
```
User selects operation (1-6)
    ↓
get_directory_input()
    ├─ Show prompt
    ├─ Read user input
    └─ validate_directory(path)
        ├─ convert_to_wsl_path(path)
        ├─ Check if -d (directory exists)
        ├─ Check if -r (readable)
        └─ Return validated path
    ↓
TARGET_FOLDER = validated_path
    ↓
Operation executes on TARGET_FOLDER
```

### ENHANCED FLOW
```
User selects operation (1-6)
    ↓
get_directory_input_enhanced()
    ├─ Show menu options
    │   ├─ [1] Browse drives
    │   ├─ [2] Recent folders
    │   └─ [3] Manual entry
    │
    ├─ [Option 1: Browse Drives]
    │   └─ show_drive_selector()
    │       ├─ list_available_mount_points()
    │       │   ├─ Parse mount command output
    │       │   ├─ Get size from df
    │       │   └─ Detect type via detect_drive_type()
    │       ├─ Display menu with icons
    │       └─ Return selected mount point
    │
    ├─ [Option 2: Recent Folders]
    │   └─ get_recent_paths()
    │       ├─ Read from config file
    │       └─ Return recent directories
    │
    └─ [Option 3: Manual Entry]
        └─ Current get_directory_input() behavior
    ↓
validate_directory(selected_path)
    ↓
TARGET_FOLDER = validated_path
    ↓
Operation executes on TARGET_FOLDER
```

## Drive Detection System

```
┌─────────────────────────────────────┐
│   Mount Point (e.g., /mnt/y)        │
└────────────────┬────────────────────┘
                 │
        detect_drive_type()
        (line 3463)
                 │
        ┌────────┴────────┐
        │                 │
    Check mount info:      Check path pattern:
    ├─ cifs|smb      │    ├─ /mnt/[a-z]
    ├─ nfs          │    │  (WSL Windows drive)
    ├─ fuse|9p      │    └─ Others
    └─ Others        │
        │            │
        ├────────────┤
        │
        ↓
    ┌────────────────────┐
    │  Drive Type Result  │
    ├────────────────────┤
    │ "Network" (SMB)    │
    │ "NAS" (NFS)        │
    │ "Local" (HDD/SSD)  │
    │ "USB" (USB drive)  │
    │ "Unknown"          │
    └────────────────────┘
```

## Multi-Drive Catalog System

```
┌─────────────────────────────────────────────┐
│  File System (mounted at various points)    │
├─────────────────────────────────────────────┤
│  /mnt/c/Videos  /mnt/y  /media/usb1  etc    │
└──────────────────────┬──────────────────────┘
                       │
            catalog_drive(mount_point)
            (line 3576)
                       │
        ┌──────────────┴──────────────┐
        │                             │
    register_drive()           Find all media files
    (line 3514)               (videos, images, audio)
        │                             │
    ┌───┴────────────────┐           │
    │                    │           │
 get_drive_id()  get_drive_label()   │
 (line 3408)     (line 3445)         │
    │                    │           │
    │  detect_drive_type()│          │
    │  (line 3463)       │          │
    │                    │           │
    └───┬────────────────┘           │
        │                            │
        └────────────┬───────────────┘
                     │
    ┌────────────────┴────────────────┐
    │                                 │
    ↓                                 ↓
Store in:                      Extract metadata:
~/.video-manager-               ├─ Video duration
  drives.json                   ├─ Resolution
                                ├─ File hash
    ├─ drive_id                 ├─ Image dimensions
    ├─ drive_label              ├─ Artist/Title
    ├─ drive_type               └─ EXIF data
    ├─ status                        │
    ├─ last_seen                     │
    └─ total_videos             Store in:
                                ~/.video-manager-
                                  catalog.json
```

## Path Handling Pipeline

```
User Input (any format)
    │
    ├─ Windows: C:\Users\Videos
    ├─ WSL: /mnt/c/Users/Videos
    ├─ Linux: /home/user/Videos
    └─ Network: /mnt/y/shared
    │
    ↓
convert_to_wsl_path()
(lib/platform.sh:164)
    │
    ├─ Detects platform
    └─ Converts to Unix format if needed
    │
    ↓
validate_directory()
(lib/utils.sh:179)
    │
    ├─ Check exists: -d
    ├─ Check readable: -r
    └─ Path traversal safety check
    │
    ↓
Validated Path
    │
    └─ Ready for operations
```

## Network Drive Integration Points

```
┌────────────────────────────────────────────────────────┐
│             ENHANCEMENT AREAS                          │
├────────────────────────────────────────────────────────┤
│                                                        │
│ POINT 1: Directory Selection Interface                │
│ ─────────────────────────────────────                 │
│ Function: get_directory_input()                       │
│ File: video-manager-ultimate.sh (4977)               │
│ Change: Add menu for selecting drives                │
│ Status: MISSING - Needs lib/navigation.sh            │
│                                                        │
│ POINT 2: Catalog Menu Drive Selection                │
│ ──────────────────────────────────────                │
│ Function: handle_catalog_menu()                       │
│ File: video-manager-ultimate.sh (5585)               │
│ Change: Show actual drives not hardcoded             │
│ Status: MISSING - Needs list display                 │
│                                                        │
│ POINT 3: Navigation Module                           │
│ ──────────────────────────────                       │
│ File: lib/navigation.sh [NEW]                        │
│ Functions:                                            │
│   - list_available_mount_points()                    │
│   - show_drive_selector()                            │
│   - get_drive_usage()                                │
│   - get_recent_paths()                               │
│ Status: MISSING - Needs creation                     │
│                                                        │
└────────────────────────────────────────────────────────┘
```

## Configuration Files

```
Home Directory (~/)
├── .video-manager.conf
│   ├── DRY_RUN, VERBOSE, INTERACTIVE
│   ├── Subtitle settings
│   ├── Catalog settings
│   └── Other preferences
│
├── .video-manager-drives.json
│   └── Array of known drives:
│       ├─ drive_id (UUID or hash)
│       ├─ drive_label (friendly name)
│       ├─ drive_type (Local/USB/Network/NAS)
│       ├─ last_mount_point
│       ├─ last_seen (timestamp)
│       ├─ status (online/offline)
│       └─ total_videos
│
├── .video-manager-catalog.json
│   └── Array of cataloged files:
│       ├─ filename
│       ├─ drive_id (links to drives)
│       ├─ file_size
│       ├─ media_type (video/image/audio)
│       ├─ duration (for videos)
│       ├─ resolution (for videos)
│       ├─ dimensions (for images)
│       ├─ hash (SHA-256)
│       └─ metadata
│
├── .video-manager-undo.json
│   └── Undo history
│
└── .video-manager-logs/
    ├── Main logs
    └── undo-history/
        └── Organize operation undos
```

## Function Dependency Graph

### Current (Incomplete)
```
get_directory_input()
    └─ validate_directory()
        └─ convert_to_wsl_path()
```

### Enhanced (Proposed)
```
get_directory_input_enhanced()
    ├─ show_drive_selector() [NEW]
    │   ├─ list_available_mount_points() [NEW]
    │   │   ├─ detect_drive_type() [EXISTING]
    │   │   └─ get_drive_usage() [NEW]
    │   ├─ get_drive_label() [EXISTING]
    │   └─ get_drive_id() [EXISTING]
    │
    ├─ get_recent_paths() [NEW]
    │   └─ Load from config file
    │
    └─ Manual path option (CURRENT)
        └─ validate_directory()
            └─ convert_to_wsl_path()
```

## Technology Stack

| Layer | Component | Status |
|-------|-----------|--------|
| **UI/UX** | Bash menus with color codes | Complete |
| **Navigation** | Path input, validation | Partial |
| **Drive Detection** | Network/Local/USB/NAS | Complete |
| **Cataloging** | JSON database | Complete |
| **File Ops** | Rename, flatten, organize | Complete |
| **Metadata** | Video/Image/Audio extraction | Complete |
| **Logging** | Comprehensive operation logs | Complete |
| **Platform Support** | Linux/macOS/Windows/WSL | Complete |
| **Drive Navigation** | Interactive selection | **MISSING** |
| **Recent Paths** | History/bookmarks | **MISSING** |

## Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| List mount points | <100ms | Uses `df` and `mount` |
| Detect drive type | <50ms | Checks mount info |
| Register drive | <10ms | JSON update |
| Catalog directory (1000 files) | 1-5s | Includes hash calculation |
| Get drive usage | <100ms | Uses `df` |
| Show menu | <50ms | Just display |

## Security Considerations

1. **Path Traversal** - validate_directory() checks base directory
2. **Input Sanitization** - sanitize_input() removes control chars
3. **Permissions** - Checks -r (readable) for directories
4. **Shell Injection** - Uses quoted variables and arrays
5. **Hash Calculation** - SHA-256 for duplicate detection

---

## Summary: Component Readiness

| Component | Ready | Notes |
|-----------|-------|-------|
| OS Detection | ✓ | Full platform support |
| Path Conversion | ✓ | Windows to WSL working |
| Drive Type Detection | ✓ | SMB/NFS/USB/Local/NAS |
| File Operations | ✓ | Rename/flatten/organize |
| Cataloging | ✓ | JSON-based with metadata |
| Configuration | ✓ | Profile-based system |
| Logging | ✓ | Comprehensive tracking |
| **Directory Navigation** | ✗ | **Needs implementation** |
| **Mount Discovery** | ✗ | **Needs implementation** |
| **Drive Selection UI** | ✗ | **Needs implementation** |
| **Recent Paths** | ✗ | **Needs implementation** |

