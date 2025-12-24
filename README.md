# Video Manager Ultimate - Bash Edition
## Version 1.3.0

Cross-platform video file management and organization tool for Linux, macOS, Windows (Git Bash), and WSL.

### 🎉 New in v1.3.0: Modular Architecture!

This release features a **complete architectural transformation**:
- ✅ **93% smaller main script** (6,590 → 465 lines)
- ✅ **12 independent modules** for better maintainability
- ✅ **100% test coverage** with comprehensive test suite
- ✅ **All functionality preserved** from previous versions
- ✅ **Improved tab completion** for all commands

[Read about the modularization journey →](MODULARIZATION-PROGRESS.md)

---

## Installation

```bash
git clone https://github.com/emaag/vmgr.git
cd vmgr
./install.sh
```

Manual setup:
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

### Architecture
- **Modular design** - 12 independent, testable modules
- **Clean separation** - Foundation, Core Features, Advanced Features
- **Maintainable** - Each module focused on single responsibility
- **Extensible** - Easy to add new features
- **Well-tested** - Comprehensive test suite (26 tests, 100% pass rate)

---

## Quick Start

```bash
# Check version
./video-manager-ultimate.sh --version

# Preview changes (dry run)
./video-manager-ultimate.sh --dry-run rename /path/to/videos

# Apply changes
./video-manager-ultimate.sh rename /path/to/videos

# Launch interactive menu
./video-manager-ultimate.sh
```

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

- **Linux** - Native support
- **macOS** - Requires Bash 4.0+
- **WSL** - Windows Subsystem for Linux
- **Git Bash** - Windows

### Supported Path Formats
- Unix: `/home/user/Videos`
- WSL: `/mnt/c/Users/user/Videos`
- Windows: `C:\Users\user\Videos` (auto-converted)

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

- **README.md** - This file (overview and quick reference)
- **INSTALLATION-GUIDE.md** - Setup instructions and troubleshooting
- **VIDEO-MANAGER-BASH-GUIDE.md** - Complete feature documentation
- **QUICK-REFERENCE.md** - Command cheat sheet
- **ADVANCED-FEATURES-v1.2.md** - Advanced configuration guide
- **SUBTITLE-FEATURE-GUIDE.md** - Subtitle generation guide

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
