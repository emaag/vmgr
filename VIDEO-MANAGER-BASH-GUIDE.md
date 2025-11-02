# VIDEO MANAGER ULTIMATE - BASH EDITION
## Complete User Guide

**Version:** 1.0.0  
**Date:** October 19, 2025  
**Complements:** PowerShell Ultimate Edition

---

## Table of Contents

1. [Overview](#overview)
2. [Installation & Setup](#installation--setup)
3. [Quick Start](#quick-start)
4. [Usage Modes](#usage-modes)
5. [Features Reference](#features-reference)
6. [Interactive Menu Guide](#interactive-menu-guide)
7. [Command Line Reference](#command-line-reference)
8. [Workflows](#workflows)
9. [Logging System](#logging-system)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

---

## Overview

Video Manager Ultimate - Bash Edition is a comprehensive, ultra-verbose video file management system designed specifically for Linux and WSL (Windows Subsystem for Linux) environments. It complements the PowerShell Ultimate Edition by providing bash-native features with extensive real-time feedback and logging.

### Key Features

✅ **Interactive Menu System** - Color-coded, user-friendly interface  
✅ **Command-Line Arguments** - Full automation support  
✅ **Real-Time Verbose Output** - See every operation as it happens  
✅ **Comprehensive Logging** - Timestamped audit trail of all operations  
✅ **Duplicate Detection** - SHA-256 hash-based exact duplicate finding  
✅ **Directory Flattening** - Organize scattered video collections  
✅ **Bracket Notation** - Standardized `[Studio] filename.ext` format  
✅ **Dry Run Mode** - Test operations safely before applying  
✅ **Statistics Tracking** - Detailed reports on all operations  
✅ **WSL & Linux Support** - Works with both Windows and Unix paths  
✅ **Batch Processing** - Handle multiple folders in one session  

### Supported Video Formats

- MP4, MKV, AVI, MOV, WMV
- FLV, WebM, M4V, MPG, MPEG, 3GP

---

## Installation & Setup

### Prerequisites

1. **Bash 4.0+** (Check with: `bash --version`)
2. **Basic Unix utilities** (find, sed, awk, grep)
3. **Hash utility** (sha256sum or shasum)
4. **Optional:** ffprobe (for advanced duplicate detection)

### Installation Steps

1. **Download the script:**
   ```bash
   # Place in your home directory or preferred location
   cp video-manager-ultimate.sh ~/bin/
   ```

2. **Make it executable:**
   ```bash
   chmod +x ~/bin/video-manager-ultimate.sh
   ```

3. **Optional: Add to PATH**
   ```bash
   # Add to ~/.bashrc or ~/.bash_profile
   export PATH="$HOME/bin:$PATH"
   
   # Create alias for easy access
   alias vmgr='~/bin/video-manager-ultimate.sh'
   ```

4. **Test installation:**
   ```bash
   ~/bin/video-manager-ultimate.sh --version
   ```

### First Run

On first run, the script will:
- Create log directory at `~/.video-manager-logs/`
- Initialize logging system
- Display the interactive menu (if no arguments provided)

---

## Quick Start

### Interactive Mode (Recommended for Beginners)

```bash
# Launch interactive menu
./video-manager-ultimate.sh
```

Follow the color-coded menus to:
1. Select operation type
2. Enter directory path
3. Review dry run results
4. Apply changes

### Command Line Mode (For Automation)

```bash
# Dry run first (safe!)
./video-manager-ultimate.sh --dry-run rename /mnt/c/Users/Eric/Videos

# Apply changes
./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos

# Find duplicates
./video-manager-ultimate.sh duplicates /mnt/c/Users/Eric/Videos
```

---

## Usage Modes

### 1. Interactive Menu (Default)

**Launch:** Run script without arguments or with `-i` flag

```bash
./video-manager-ultimate.sh
# or
./video-manager-ultimate.sh --interactive
```

**Features:**
- No command memorization needed
- Visual feedback at every step
- Built-in help text
- Statistics after each operation
- Settings can be toggled on-the-fly

**Best For:**
- First-time users
- Infrequent operations
- Testing new features
- Visual confirmation needed

---

### 2. Command Line Interface

**Launch:** Run script with specific command and options

```bash
./video-manager-ultimate.sh [OPTIONS] [COMMAND] [DIRECTORY]
```

**Features:**
- Fast execution
- Scriptable/automatable
- Perfect for cron jobs
- Batch operations
- CI/CD integration

**Best For:**
- Experienced users
- Automation scripts
- Scheduled tasks
- Bulk processing
- Remote execution

---

## Features Reference

### 1. Bracket Notation Renaming

Standardizes filenames by extracting the studio/brand name and wrapping it in brackets.

**Examples:**
```
vixen.24.12.25.jia.lissa.mp4          → [Vixen] 24.12.25.jia.lissa.mp4
tushy - raw - something.mp4           → [Tushy] raw something.mp4
MetArt.Anna.Something.mp4             → [MetArt] Anna.Something.mp4
brazzers_cool_scene.mp4               → [Brazzers] cool scene.mp4
```

**Process:**
1. Extracts first word (alphanumeric + underscore)
2. Capitalizes first letter
3. Wraps in brackets `[Studio]`
4. Preserves remaining filename
5. Maintains file extension

**Verbose Output:**
```
ℹ Processing: vixen.24.12.25.jia.lissa.mp4
  After dash removal: vixen.24.12.25.jia.lissa.mp4
  After bracket notation: [Vixen] 24.12.25.jia.lissa.mp4
  After spacing fix: [Vixen] 24.12.25.jia.lissa.mp4
✓ Renamed:
  From: vixen.24.12.25.jia.lissa.mp4
  To:   [Vixen] 24.12.25.jia.lissa.mp4
```

---

### 2. Dash Pattern Removal

Removes all instances of ` - ` (space-dash-space) from filenames.

**Examples:**
```
Tushy - Raw - 2024.mp4      → Tushy Raw 2024.mp4
Studio - Scene - Name.mkv   → Studio Scene Name.mkv
```

**Use Cases:**
- Cleaning up downloaded files
- Standardizing separator patterns
- Preparing for bracket notation

---

### 3. Bracket Spacing Fix

Ensures proper spacing after closing brackets.

**Examples:**
```
[Vixen]Scene.mp4        → [Vixen] Scene.mp4
[Tushy]Something.mkv    → [Tushy] Something.mkv
```

**Use Cases:**
- Fixing malformed bracket notation
- Post-processing bulk renames
- Improving visual consistency

---

### 4. Directory Flattening

Moves all video files from subdirectories to a single top-level directory.

**Before:**
```
/Videos/
├── Folder1/
│   ├── video1.mp4
│   └── Subfolder/
│       └── video2.mp4
└── Folder2/
    └── video3.mp4
```

**After:**
```
/Videos/
├── video1.mp4
├── video2.mp4
└── video3.mp4
```

**Features:**
- Automatic conflict resolution
- Preserves all files
- Detects possible duplicates (same size)
- Appends counter for conflicts: `video(1).mp4`

**Verbose Output:**
```
ℹ Found: /Videos/Folder1/video1.mp4
→ Moved: video1.mp4 → /Videos/video1.mp4

⚠ Possible duplicate (same size): video2.mp4
  Source: /Videos/Folder1/Subfolder/video2.mp4 (1234567 bytes)
  Target: /Videos/video2.mp4 (1234567 bytes)
```

---

### 5. Duplicate Detection

Identifies exact duplicates using SHA-256 cryptographic hashing.

**Features:**
- Hash-based exact matching (100% accurate)
- Groups duplicates by hash
- Calculates wasted space
- Generates detailed reports
- Optional automatic deletion
- CSV export for analysis

**Output:**
- **Text Report:** `_duplicate_report_TIMESTAMP/duplicates.txt`
- **CSV Export:** `_duplicate_report_TIMESTAMP/duplicates.csv`

**Example Report:**
```
DUPLICATE VIDEO FILES REPORT
Generated: 2025-10-19 14:30:00
Directory: /mnt/c/Users/Eric/Videos
Total Duplicates: 5
Space Wasted: 2,450 MB

========================================

=== Duplicate Group #1 ===
Hash: a1b2c3d4e5f6...
File Size: 500 MB
Original: /Videos/movie.mp4
Duplicates:
  - /Videos/Backup/movie.mp4
  - /Videos/Old/movie.mp4

=== Duplicate Group #2 ===
...
```

**Verbose Output:**
```
ℹ Scanning for duplicate video files in: /Videos
ℹ This may take a while for large collections...

Processing: [15 files] Current: movie.mp4...
ℹ Calculating SHA256 hash for: movie.mp4
⚠ Duplicate found!
  Hash: a1b2c3d4e5f6...
  Original: /Videos/movie.mp4
  Duplicate: /Videos/Backup/movie.mp4

✓ Report generated: /Videos/_duplicate_report_20251019-143000/duplicates.txt
✓ CSV export: /Videos/_duplicate_report_20251019-143000/duplicates.csv
ℹ Total space wasted by duplicates: 2450 MB
```

---

### 6. Batch Processing

Process multiple directories in a single session with accumulated statistics.

**Features:**
- Enter unlimited directories
- Windows or Unix path formats
- Validates each path before processing
- Maintains statistics across all folders
- Error handling per directory
- Combined final report

**Interactive Flow:**
```
📁 Batch Processing Mode

Enter directory paths (one per line, empty line to finish):
You can use Windows paths (C:\Users\...) or Unix paths (/mnt/c/...)

[1] Directory: /mnt/c/Users/Eric/Videos/Collection1
✓ Added: /mnt/c/Users/Eric/Videos/Collection1

[2] Directory: C:\Users\Eric\Videos\Collection2
✓ Added: /mnt/c/Users/Eric/Videos/Collection2

[3] Directory: 

Processing 2 directories:

[1/2] Processing: /mnt/c/Users/Eric/Videos/Collection1
...

[2/2] Processing: /mnt/c/Users/Eric/Videos/Collection2
...

✓ Batch processing complete!
```

---

### 7. Dry Run Mode

Preview all operations without making any changes.

**Enable:**
- **Interactive:** Toggle in Settings menu or Single Operations
- **CLI:** Use `--dry-run` or `-d` flag

**Output:**
```
[DRY RUN] Would rename:
  From: vixen.movie.mp4
  To:   [Vixen] movie.mp4

[DRY RUN] Would move: /Videos/Sub/movie.mp4 → /Videos/movie.mp4
```

**Best Practices:**
- Always dry run first for large operations
- Review output carefully
- Check for unexpected transformations
- Verify conflict resolutions

---

## Interactive Menu Guide

### Main Menu

```
╔═══════════════════════════════════════════════════════════════╗
║  VIDEO MANAGER ULTIMATE - BASH EDITION                       ║
║  Version 1.0.0 - 2025-10-19                                  ║
╚═══════════════════════════════════════════════════════════════╝

MAIN MENU

[1] Single Operations
[2] Batch Processing
[3] Automated Workflows
[4] Duplicate Detection
[5] Utilities
[6] Settings

[Q] Quit
```

---

### Single Operations Menu

Perfect for one-time tasks on a single directory.

**Options:**

**[1] Rename Files (Bracket Notation)**
- Applies full cleanup pipeline
- Removes dashes
- Applies bracket notation
- Fixes spacing

**[2] Remove Dashes Only**
- Only removes ` - ` patterns
- Preserves all other formatting

**[3] Fix Bracket Spacing Only**
- Only fixes `]word` → `] word`
- Preserves all other formatting

**[4] Flatten Directory**
- Moves all videos to top level
- Handles conflicts automatically

**[5] Full Cleanup (All Operations)**
- Comprehensive transformation
- All formatting fixes applied

**[D] Toggle Dry Run Mode**
- Quick toggle without menu navigation
- Current state shown: ON/OFF

---

### Batch Processing Menu

Process multiple directories with same operation.

**Options:**

**[1] Batch Rename Multiple Folders**
- Apply bracket notation to multiple directories
- Enter paths one by one
- Accumulated statistics

**[2] Batch Flatten Multiple Folders**
- Flatten multiple directory structures
- Useful for organizing scattered collections

**[3] Batch Full Cleanup**
- Complete cleanup across multiple folders
- Maximum efficiency for large collections

---

### Automated Workflows Menu

Pre-configured multi-step operations.

**[1] New Collection Setup**
- **Step 1:** Flatten directory structure
- **Step 2:** Apply standardized naming
- **Step 3:** Detect duplicates
- **Use Case:** Setting up a newly acquired collection

**[2] Deep Clean Existing Collection**
- **Step 1:** Remove dash patterns
- **Step 2:** Fix bracket spacing
- **Step 3:** Apply bracket notation
- **Use Case:** Cleaning up existing organized collection

---

### Duplicate Detection Menu

Find and optionally remove duplicates.

**[1] Find Duplicates (Report Only)**
- Generates text and CSV reports
- No files deleted
- Safe for exploration

**[2] Find and Delete Duplicates**
- ⚠️ **WARNING: Deletes files!**
- Requires explicit "yes" confirmation
- Keeps original, deletes duplicates
- Updates statistics with space saved

**[3] Find Duplicates (Dry Run)**
- Shows what would be deleted
- No actual changes made
- Perfect for testing

---

### Utilities Menu

System management and diagnostics.

**[1] View Last 50 Log Entries**
- Quick review of recent operations
- Displays directly in terminal
- Useful for troubleshooting

**[2] Open Log Directory**
- Opens file manager to log folder
- Works in both WSL and native Linux
- Easy access to full log files

**[3] Test Filename Transformation**
- Interactive testing tool
- Enter any filename
- See transformation pipeline step-by-step
- Perfect for verification

**[4] Display System Information**
- Script version
- Bash version
- Operating system details
- Available tools check
- Paths and configuration

---

### Settings Menu

Configure script behavior.

**Current Settings Display:**
```
Dry Run Mode:    ENABLED / DISABLED
Verbose Output:  ENABLED / DISABLED
Log Directory:   /home/user/.video-manager-logs
```

**[1] Toggle Dry Run Mode**
- Persistent for entire session
- Affects all operations

**[2] Toggle Verbose Output**
- Control detail level
- Reduce output for large operations

**[3] View Supported Extensions**
- List all recognized video formats
- Current: mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg, 3gp

---

## Command Line Reference

### Basic Syntax

```bash
./video-manager-ultimate.sh [OPTIONS] [COMMAND] [DIRECTORY]
```

### Options

| Option | Long Form | Description |
|--------|-----------|-------------|
| `-h` | `--help` | Show help message and exit |
| `-v` | `--version` | Show version information |
| `-d` | `--dry-run` | Enable dry run mode (no changes) |
| `-q` | `--quiet` | Disable verbose output |
| `-i` | `--interactive` | Launch interactive menu |

### Commands

| Command | Description | Requires Directory |
|---------|-------------|-------------------|
| `rename` | Apply bracket notation | Yes |
| `flatten` | Flatten directory structure | Yes |
| `cleanup` | Full cleanup pipeline | Yes |
| `duplicates` | Find duplicate files | Yes |
| `workflow-new` | New collection setup | Yes |
| `workflow-clean` | Deep clean workflow | Yes |
| `batch` | Batch processing mode | No (prompts for input) |

### Examples

#### Basic Operations

```bash
# Rename files with bracket notation
./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos

# Flatten directory structure
./video-manager-ultimate.sh flatten /mnt/c/Users/Eric/Videos

# Full cleanup
./video-manager-ultimate.sh cleanup /mnt/c/Users/Eric/Videos

# Find duplicates
./video-manager-ultimate.sh duplicates /mnt/c/Users/Eric/Videos
```

#### With Dry Run

```bash
# Test rename operation
./video-manager-ultimate.sh --dry-run rename /mnt/c/Users/Eric/Videos

# Preview flatten operation
./video-manager-ultimate.sh -d flatten /mnt/c/Users/Eric/Videos
```

#### Workflows

```bash
# Setup new collection
./video-manager-ultimate.sh workflow-new /mnt/c/Users/Eric/NewCollection

# Clean existing collection
./video-manager-ultimate.sh workflow-clean /mnt/c/Users/Eric/Videos
```

#### Quiet Mode (Minimal Output)

```bash
# Run with minimal console output (still logs everything)
./video-manager-ultimate.sh --quiet rename /mnt/c/Users/Eric/Videos
```

#### Batch Processing

```bash
# Launch batch mode (will prompt for directories)
./video-manager-ultimate.sh batch
```

### Path Formats

The script accepts both Windows and Unix path formats:

```bash
# Windows path (will be converted)
./video-manager-ultimate.sh rename "C:\Users\Eric\Videos"

# WSL path
./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos

# Native Linux path
./video-manager-ultimate.sh rename /home/user/Videos

# Network path (if mounted)
./video-manager-ultimate.sh rename /mnt/network/Videos
```

---

## Workflows

### Workflow 1: New Collection Setup

**Purpose:** Organize a newly acquired or downloaded video collection

**Steps:**
1. Flatten directory structure (move all to top level)
2. Apply standardized bracket notation
3. Detect and report duplicates

**When to Use:**
- Downloaded torrent with nested folders
- Received collection from friend
- Imported from external drive
- Consolidating multiple sources

**Example:**
```bash
./video-manager-ultimate.sh workflow-new /mnt/c/Users/Eric/Downloads/NewCollection
```

**Expected Results:**
- All videos in single directory
- Standardized `[Studio] filename.ext` format
- Duplicate report generated
- Ready for your media player

---

### Workflow 2: Deep Clean

**Purpose:** Clean up an existing organized collection

**Steps:**
1. Remove unwanted dash patterns
2. Fix bracket spacing issues
3. Ensure consistent bracket notation

**When to Use:**
- Collection has formatting inconsistencies
- Previous renaming left artifacts
- Imported from different system
- Standardizing old collection

**Example:**
```bash
./video-manager-ultimate.sh workflow-clean /mnt/c/Users/Eric/Videos/Vixen
```

**Expected Results:**
- Consistent formatting throughout
- Proper bracket spacing
- Cleaned filename patterns
- Professional appearance

---

## Logging System

### Log Location

```
~/.video-manager-logs/
└── video-manager-YYYYMMDD-HHMMSS.log
```

### Log Format

```
[YYYY-MM-DD HH:MM:SS] [LEVEL] Message
```

**Levels:**
- `INFO` - General information
- `SUCCESS` - Successful operations
- `WARN` - Warnings (non-critical)
- `ERROR` - Errors encountered
- `OPERATION` - Operation start/end markers
- `RENAME` - Rename operations
- `MOVE` - File move operations
- `DRYRUN` - Dry run previews

### Example Log Entries

```
[2025-10-19 14:30:00] [INFO] ==========================================
[2025-10-19 14:30:00] [INFO] Video Manager Ultimate - Bash Edition v1.0.0
[2025-10-19 14:30:00] [INFO] Session started: 2025-10-19 14:30:00
[2025-10-19 14:30:00] [INFO] ==========================================
[2025-10-19 14:30:05] [OPERATION] Started: Rename Files (Bracket Notation)
[2025-10-19 14:30:06] [INFO] Scanning directory: /mnt/c/Users/Eric/Videos
[2025-10-19 14:30:06] [RENAME] Success: vixen.movie.mp4 -> [Vixen] movie.mp4
[2025-10-19 14:30:07] [RENAME] Success: tushy.scene.mp4 -> [Tushy] scene.mp4
[2025-10-19 14:30:08] [OPERATION] Completed: Rename Files (Duration: 0m 3s)
[2025-10-19 14:30:08] [INFO] Session ended: 2025-10-19 14:30:08
```

### Log Rotation

- Maximum 50 log files kept
- Oldest automatically deleted when limit reached
- Each session creates new log file
- Prevents disk space issues

### Accessing Logs

**Via Interactive Menu:**
1. Main Menu → Utilities → View Last 50 Log Entries

**Via File Manager:**
1. Main Menu → Utilities → Open Log Directory

**Via Command Line:**
```bash
# View latest log
tail -n 100 ~/.video-manager-logs/video-manager-*.log | tail -n 1

# View all logs
ls -lt ~/.video-manager-logs/

# Search logs
grep "ERROR" ~/.video-manager-logs/*.log
```

---

## Troubleshooting

### Common Issues

#### 1. Permission Denied

**Symptom:**
```
✗ Error: Directory is not readable: /mnt/c/Users/Eric/Videos
```

**Solutions:**
```bash
# Check permissions
ls -la /mnt/c/Users/Eric/Videos

# Fix permissions (if you own the directory)
chmod -R u+rwX /mnt/c/Users/Eric/Videos

# Run with sudo (last resort)
sudo ./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos
```

---

#### 2. Hash Utility Not Found

**Symptom:**
```
✗ Error: No hash utility found (sha256sum or shasum required)
```

**Solutions:**
```bash
# Ubuntu/Debian
sudo apt-get install coreutils

# macOS (should have shasum by default)
# If not, install via Homebrew:
brew install coreutils

# Verify installation
which sha256sum || which shasum
```

---

#### 3. Windows Path Not Found

**Symptom:**
```
✗ Error: Directory does not exist: C:\Users\Eric\Videos
```

**Solutions:**
```bash
# Use WSL path format
./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos

# Or use quotes with backslashes
./video-manager-ultimate.sh rename "C:\\Users\\Eric\\Videos"

# Check if path is accessible from WSL
ls /mnt/c/Users/Eric/Videos
```

---

#### 4. Operation Too Slow

**Symptom:** Script runs slowly on large collections

**Solutions:**
```bash
# Disable verbose output
./video-manager-ultimate.sh --quiet rename /mnt/c/Users/Eric/Videos

# Or toggle in Settings menu
# Main Menu → Settings → Toggle Verbose Output

# For duplicate detection, ensure fast disk
# Consider running overnight for huge collections (10,000+ files)
```

---

#### 5. Filename Conflicts

**Symptom:**
```
⚠ Filename conflict resolved: movie(1).mp4
```

**Explanation:** Two files would have identical names after processing

**Solutions:**
- This is automatic protection
- Review the (1), (2), etc. files manually
- May indicate actual duplicates
- Run duplicate detection to verify

---

#### 6. Special Characters in Filenames

**Symptom:** Files with special characters not processing correctly

**Solutions:**
```bash
# The script handles most special characters
# If issues persist, manually rename problem files first

# Characters that may cause issues:
# Newlines, null bytes, unusual Unicode

# Check for problem characters:
find /path -name $'*\n*'  # Newlines
find /path -name '*[!-~]*'  # Non-printable
```

---

### Getting Help

1. **Check the logs:**
   ```bash
   cat ~/.video-manager-logs/video-manager-*.log | tail -n 100
   ```

2. **Run system information:**
   ```bash
   ./video-manager-ultimate.sh
   # Navigate to: Utilities → Display System Information
   ```

3. **Test with dry run:**
   ```bash
   ./video-manager-ultimate.sh --dry-run rename /path/to/directory
   ```

4. **Test single file transformation:**
   ```bash
   ./video-manager-ultimate.sh
   # Navigate to: Utilities → Test Filename Transformation
   ```

---

## Best Practices

### Before Starting

1. **Backup your collection** (always!)
   ```bash
   # Quick backup
   cp -r /mnt/c/Users/Eric/Videos /mnt/c/Users/Eric/Videos_BACKUP
   
   # Or use rsync for large collections
   rsync -av /mnt/c/Users/Eric/Videos/ /backup/Videos/
   ```

2. **Always dry run first**
   ```bash
   ./video-manager-ultimate.sh --dry-run rename /path/to/directory
   ```

3. **Start with small test folder**
   - Test on 10-20 files first
   - Verify results meet expectations
   - Then process entire collection

### During Operations

1. **Monitor the output**
   - Watch for unexpected transformations
   - Check for excessive errors
   - Verify conflict resolutions look correct

2. **Check statistics**
   - Files processed should match expectations
   - Errors should be zero or minimal
   - Skipped files should make sense

3. **Review logs in real-time** (optional)
   ```bash
   # In another terminal:
   tail -f ~/.video-manager-logs/video-manager-*.log | head -n 1
   ```

### After Operations

1. **Verify results**
   ```bash
   # Check a few renamed files
   ls /mnt/c/Users/Eric/Videos | head -n 20
   
   # Verify total count unchanged
   find /mnt/c/Users/Eric/Videos -name "*.mp4" | wc -l
   ```

2. **Review logs**
   ```bash
   # Check for errors
   grep ERROR ~/.video-manager-logs/video-manager-*.log | tail -n 20
   
   # Review statistics
   grep "Files Processed" ~/.video-manager-logs/video-manager-*.log | tail -n 1
   ```

3. **Test playback**
   - Open a few random files
   - Ensure nothing corrupted
   - Verify media player recognizes files

### Regular Maintenance

1. **Run duplicate detection monthly**
   ```bash
   ./video-manager-ultimate.sh duplicates /mnt/c/Users/Eric/Videos
   ```

2. **Check for formatting drift**
   - Run deep clean workflow quarterly
   - Maintains consistency over time

3. **Review logs periodically**
   ```bash
   # Check log disk usage
   du -sh ~/.video-manager-logs/
   
   # Old logs auto-rotate, but verify
   ls ~/.video-manager-logs/ | wc -l
   ```

### Automation

1. **Schedule regular cleanups**
   ```bash
   # Add to crontab (crontab -e)
   # Run deep clean every Sunday at 2 AM
   0 2 * * 0 /home/user/bin/video-manager-ultimate.sh workflow-clean /mnt/c/Users/Eric/Videos
   ```

2. **Post-download automation**
   ```bash
   # Create wrapper script for downloads
   #!/bin/bash
   # After download completes:
   /home/user/bin/video-manager-ultimate.sh workflow-new /home/user/Downloads/Videos
   ```

3. **Batch processing script**
   ```bash
   #!/bin/bash
   # Process all collections
   for dir in /mnt/c/Users/Eric/Videos/*/; do
       /home/user/bin/video-manager-ultimate.sh cleanup "$dir"
   done
   ```

---

## Advanced Tips

### Performance Optimization

```bash
# For very large collections (10,000+ files)
# Disable verbose output
./video-manager-ultimate.sh --quiet rename /path

# Process in smaller batches
for dir in /Videos/*/; do
    ./video-manager-ultimate.sh rename "$dir"
done
```

### Custom Extensions

Edit the script to add custom video formats:

```bash
# Line ~67 in video-manager-ultimate.sh
DEFAULT_VIDEO_EXTENSIONS=("mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "3gp" "ts" "m2ts")
```

### Integration with Other Tools

```bash
# Combine with find for selective processing
find /Videos -name "*vixen*" -type f -exec dirname {} \; | sort -u | while read dir; do
    ./video-manager-ultimate.sh rename "$dir"
done

# Combine with media info extraction
./video-manager-ultimate.sh rename /Videos && mediainfo /Videos/*.mp4 > video-info.txt
```

---

## Comparison with PowerShell Ultimate Edition

| Feature | Bash Edition | PowerShell Edition |
|---------|--------------|-------------------|
| **Platform** | Linux, WSL, macOS | Windows, PowerShell Core |
| **Interactive Menu** | ✅ Color-coded | ✅ Color-coded |
| **CLI Arguments** | ✅ Full support | ✅ Full support |
| **Verbose Output** | ✅ Ultra-verbose | ✅ Comprehensive |
| **Logging** | ✅ Timestamp & levels | ✅ Timestamp & levels |
| **Duplicate Detection** | ✅ SHA-256 based | ✅ SHA-256 + metadata |
| **Near-Duplicate Detection** | ❌ Not yet | ✅ ffprobe required |
| **Directory Flattening** | ✅ Full support | ✅ Full support |
| **Batch Processing** | ✅ Full support | ✅ Full support |
| **Workflows** | ✅ 2 workflows | ✅ Multiple workflows |
| **Path Handling** | Unix + WSL paths | Windows + UNC paths |
| **Performance** | Native bash speed | .NET optimized |

**Recommendation:** Use both! PowerShell for Windows-native operations, Bash for Linux/WSL or when you prefer shell scripting.

---

## FAQ

**Q: Can I run this on macOS?**  
A: Yes! It should work on macOS with bash 4.0+. Install sha256sum if needed via Homebrew.

**Q: Does this modify video files or just filenames?**  
A: Only filenames. Video content is never touched.

**Q: What if I accidentally delete duplicates?**  
A: Always backup first! But you can recover from the duplicate report CSV if needed.

**Q: Can I undo renames?**  
A: Not directly, but logs contain before/after information. Consider using git for version control of your collection.

**Q: Does this work with network drives?**  
A: Yes, if mounted in your filesystem. Performance depends on network speed.

**Q: Can I customize the bracket notation format?**  
A: Yes, edit the `apply_bracket_notation()` function in the script.

**Q: What about subtitle files (.srt, .sub)?**  
A: Currently only processes video files. Subtitle support can be added by extending `DEFAULT_VIDEO_EXTENSIONS`.

**Q: Is this safe for my media library?**  
A: Yes, when used with dry run first and backups. The script never modifies video content, only filenames and structure.

---

## Version History

### Version 1.0.0 (2025-10-19)
- Initial release
- Interactive menu system
- CLI argument support
- Comprehensive logging
- Duplicate detection
- Directory flattening
- Bracket notation
- Batch processing
- Automated workflows
- WSL/Linux support

---

## Credits

Created for Eric's Video Management System  
Complements PowerShell Ultimate Edition  
Built with bash, love, and verbose output ❤️

---

**End of User Guide**
