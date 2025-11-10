# Video Manager Ultimate - Bash Edition
## Version 1.2.0

Cross-platform video file management and organization tool for Linux, macOS, Windows (Git Bash), and WSL.

---

## Installation

### Quick Install (Linux/macOS/WSL)

```bash
git clone https://github.com/emaag/vmgr.git
cd vmgr
./install.sh
```

### WSL Migration (Windows → WSL)

**Recommended for Windows users!** Migrate from Windows to WSL for better performance:

```bash
# From WSL terminal
cd ~
curl -O https://raw.githubusercontent.com/emaag/vmgr/main/migrate-to-wsl.sh
chmod +x migrate-to-wsl.sh
./migrate-to-wsl.sh
```

See **[WSL-SETUP-GUIDE.md](WSL-SETUP-GUIDE.md)** for complete WSL installation and optimization guide.

### Manual setup

```bash
chmod +x video-manager-ultimate.sh
./video-manager-ultimate.sh
```

---

## Features

### Core Operations
- **File Renaming** - Bracket notation formatting (`[Studio] filename.mp4`)
- **Directory Flattening** - Move files from subdirectories to top level
- **Duplicate Detection** - SHA-256 hash-based with detailed reports
- **Subtitle Generation** - AI-powered using Whisper (multiple models and formats)
- **File Organization** - Automatic sorting by subfolder names with undo functionality
- **Batch Processing** - Multi-directory operations with accumulated statistics

### Subtitle Features
- Multiple Whisper models (tiny, base, small, medium, large)
- Output formats: SRT, VTT, TXT, JSON
- Language detection and manual selection
- GPU acceleration support
- Parallel processing (1-8 workers)
- Speaker diarization
- Auto-punctuation and editing
- Recursive directory scanning

### Organization Features
- Organize files by matching subfolder names
- Exclude patterns (e.g., "full" folders)
- Undo/rollback with operation logging
- Progress tracking
- Configurable default paths
- Command-line and interactive modes

### Interface
- Interactive menu system
- Command-line interface for automation
- Color-coded output
- Real-time progress indicators
- Comprehensive logging
- Dry run mode

### Safety
- Dry run preview mode
- Conflict resolution
- Error handling and recovery
- Path validation
- Operation logging and undo support

---

## Quick Start

### First Time Setup

```bash
# Check version
./video-manager-ultimate.sh --version

# Launch interactive menu
./video-manager-ultimate.sh
```

### Basic Usage

```bash
# Preview changes (dry run)
./video-manager-ultimate.sh --dry-run rename /path/to/videos

# Apply changes
./video-manager-ultimate.sh rename /path/to/videos
```

### WSL Users - Performance Tip

For best performance, copy files to WSL filesystem first:

```bash
# Copy from Windows to WSL (much faster processing)
rsync -avh --progress /mnt/c/Users/YourName/Videos/ ~/Videos/

# Process files
./video-manager-ultimate.sh rename ~/Videos

# Copy back if needed
rsync -avh --progress ~/Videos/ /mnt/c/Users/YourName/Videos/
```

See **[WSL-SETUP-GUIDE.md](WSL-SETUP-GUIDE.md)** for detailed performance optimization.

---

## Command Reference

### File Operations
```bash
# Rename with bracket notation
./video-manager-ultimate.sh rename /path

# Flatten directory structure
./video-manager-ultimate.sh flatten /path

# Find duplicates
./video-manager-ultimate.sh duplicates /path

# Batch processing
./video-manager-ultimate.sh batch
```

### Subtitle Operations
```bash
# Basic subtitle generation
./video-manager-ultimate.sh subtitles /path

# Advanced options
./video-manager-ultimate.sh --model medium --format srt --language en subtitles /path

# GPU-accelerated with parallel processing
./video-manager-ultimate.sh --gpu --parallel 4 subtitles /path

# Enable speaker diarization
./video-manager-ultimate.sh --speaker-diarization --model large subtitles /path
```

### Organization Operations
```bash
# Organize files by subfolder names
./video-manager-ultimate.sh --organize-target /folders --organize-search /search --organize

# Undo last operation
./video-manager-ultimate.sh --undo-organize

# List undo operations
./video-manager-ultimate.sh --list-undo
```

### Workflows
```bash
# New collection setup (flatten + rename + detect duplicates)
./video-manager-ultimate.sh workflow-new /path

# Deep clean (dash removal + spacing + bracket notation)
./video-manager-ultimate.sh workflow-clean /path
```

---

## Configuration

Access settings through the interactive menu:
- Main Menu → Settings → Organize Settings

Or use command-line flags:
```bash
--organize-target <path>    # Set default target folder
--organize-search <path>    # Set default search path
--dry-run                   # Preview without changes
--verbose / --quiet         # Output verbosity
```

---

## Platform Support

### Recommended: WSL (Windows Subsystem for Linux)

**Best experience for Windows users!**

- ✅ **Best Performance** - WSL 2 with native Linux filesystem
- ✅ **Complete Features** - All Linux tools and dependencies
- ✅ **Windows Integration** - Seamless access to Windows files
- ✅ **Easy Migration** - Automated migration script included

📖 **[Complete WSL Setup Guide](WSL-SETUP-GUIDE.md)** - Installation, migration, and optimization

### Other Platforms

- **Linux** - Native support with full features
- **macOS** - Requires Bash 4.0+
- **Git Bash** - Windows (limited features, WSL recommended)

### Supported Path Formats
- **Unix:** `/home/user/Videos`
- **WSL:** `/mnt/c/Users/user/Videos` (Windows drives)
- **WSL Native:** `~/Videos` (best performance)
- **Windows:** `C:\Users\user\Videos` (auto-converted in WSL)

### Supported Video Formats
mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg, 3gp

---

## Requirements

### Core
- Bash 4.0+
- SHA-256 utility (sha256sum or shasum)
- Standard Unix utilities (find, sed, awk, grep)

### Optional
- **Whisper** - For subtitle generation
  - OpenAI Whisper: `pip install -U openai-whisper`
  - OR whisper.cpp: https://github.com/ggerganov/whisper.cpp
- **ffprobe** - For video metadata
- **pyannote-audio** - For speaker diarization

---

## Documentation

### Getting Started
- **README.md** - This file (overview and quick reference)
- **[WSL-SETUP-GUIDE.md](WSL-SETUP-GUIDE.md)** - **⭐ WSL installation, migration, and optimization**
- **INSTALLATION-GUIDE.md** - General setup instructions and troubleshooting
- **QUICK-REFERENCE.md** - Command cheat sheet

### Complete Guides
- **VIDEO-MANAGER-BASH-GUIDE.md** - Complete feature documentation
- **ADVANCED-FEATURES-v1.2.md** - Advanced configuration guide
- **SUBTITLE-FEATURE-GUIDE.md** - Subtitle generation guide
- **CROSS-PLATFORM.md** - Platform-specific details

---

## Logging and Undo

### Logs
- Location: `~/.video-manager-logs/`
- Format: Timestamped with operation details
- Access: Via menu (Utilities → View Logs) or direct file access

### Undo Operations
- Automatic logging of organize operations
- Undo log location: `~/.video-manager-logs/undo-history/`
- Access via menu or CLI: `--undo-organize`, `--list-undo`

---

## Version History

### v1.2.0 (November 2025)
- File organization by subfolder names
- Undo/rollback functionality
- Progress bar for operations
- Command-line flags for organization
- Configurable default paths
- Auto-edit mode for subtitles

### v1.1.0 (November 2025)
- Whisper-based subtitle generation
- GPU acceleration
- Parallel processing
- Speaker diarization
- Multiple output formats

### v1.0.0 (October 2025)
- Initial release
- Bracket notation renaming
- Directory flattening
- Duplicate detection
- Batch processing

---

## License

Created for personal video management. Free to use and modify.

---

## Support

Built-in help:
```bash
./video-manager-ultimate.sh --help
```

Interactive menu: Utilities → System Information for diagnostics

---
