# Video Manager Ultimate — Bash Edition

**Cross-platform video file management and organization tool for Linux, macOS, Windows (Git Bash), and WSL.**

[![Version](https://img.shields.io/badge/version-1.3.0-blue.svg)](https://github.com/emaag/vmgr/releases/tag/v1.3.0)
[![CI](https://github.com/emaag/vmgr/workflows/CI/badge.svg)](https://github.com/emaag/vmgr/actions)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Tests](https://img.shields.io/badge/tests-158%2F158%20passing-success.svg)](tests/)
[![Modular](https://img.shields.io/badge/architecture-modular-orange.svg)](MODULARIZATION-PROGRESS.md)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-lightgrey.svg)](#setup-instructions)

### Status at a glance — v1.3.0: Modular Architecture + Subtitle Generation

| Change | State |
|--------|-------|
| 93% smaller main script (6,590 → 465 lines) | ✅ Shipped |
| 12 independent modules for maintainability | ✅ Shipped |
| All core functionality preserved from previous versions | ✅ Shipped |
| Improved tab completion for all commands | ✅ Shipped |
| Subtitle generation (OpenAI Whisper backend, GPU, parallel jobs, skip-existing, dry-run) | ✅ Shipped |
| 158-test automated suite (full integration coverage) | ✅ Shipped |

[Read about the modularization journey →](MODULARIZATION-PROGRESS.md)

## Table of Contents

- [Setup Instructions](#setup-instructions)
- [Features](#features)
- [Usage](#usage)
- [Command Reference](#command-reference)
- [Configuration](#configuration)
- [Environment Requirements](#environment-requirements)
- [Documentation](#documentation)
- [Architectural Decisions](#architectural-decisions)
- [Development Log](#development-log)
- [License](#license)
- [Support](#support)

## Setup Instructions

```console
git clone https://github.com/emaag/vmgr.git
cd vmgr
./install.sh
```

Manual setup:
```console
chmod +x video-manager-ultimate.sh
./video-manager-ultimate.sh
```

## Features

### Core Operations (Implemented)

- **File Renaming** — bracket notation formatting (`[Studio] filename.mp4`)
- **Directory Flattening** — move files from subdirectories to top level
- **Duplicate Detection** — SHA-256 hash-based with detailed reports
- **File Organization** — automatic sorting by subfolder names with undo functionality
- **Batch Processing** — multi-directory operations with accumulated statistics
- **Image Conversion** — convert PNG/WebP/HEIC to JPG (requires ImageMagick)
- **Subtitle Generation** — OpenAI Whisper backend; GPU acceleration, parallel jobs, skip-existing, dry-run, size/date filters, interactive editing. Requires `pip install openai-whisper` (or whisper.cpp)

### Planned Features (Not Yet Implemented)

- **Multi-Drive Catalog** — index and search media across drives; UI exists but scanning is a stub.

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

## Usage

```console
# Check version
./video-manager-ultimate.sh --version

# Preview changes (dry run)
./video-manager-ultimate.sh --dry-run rename /path/to/videos

# Apply changes
./video-manager-ultimate.sh rename /path/to/videos

# Launch interactive menu
./video-manager-ultimate.sh
```

## Command Reference

### File Operations
```console
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
```console
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
```console
# Organize files by subfolder names
./video-manager-ultimate.sh --organize-target /folders --organize-search /search --organize

# Undo last operation
./video-manager-ultimate.sh --undo-organize

# List undo operations
./video-manager-ultimate.sh --list-undo
```

### Workflows
```console
# New collection setup (flatten + rename + detect duplicates)
./video-manager-ultimate.sh workflow-new /path

# Deep clean (dash removal + spacing + bracket notation)
./video-manager-ultimate.sh workflow-clean /path
```

## Configuration

Access settings through the interactive menu: Main Menu → Settings → Organize Settings

Or use command-line flags:
```console
--organize-target <path>    # Set default target folder
--organize-search <path>    # Set default search path
--dry-run                   # Preview without changes
--verbose / --quiet         # Output verbosity
```

## Environment Requirements

### Core
| Requirement | Notes |
|--------------|-------|
| Bash | 4.0+ |
| SHA-256 utility | `sha256sum` or `shasum` |
| Standard Unix utilities | `find`, `sed`, `awk`, `grep` |

### Optional
| Component | Purpose |
|-----------|---------|
| Whisper (`pip install -U openai-whisper` or whisper.cpp) | Subtitle generation |
| ffprobe | Video metadata |
| pyannote-audio | Speaker diarization |

### Platform Support

| Platform | Notes |
|----------|-------|
| Linux | Native support |
| macOS | Requires Bash 4.0+ |
| WSL | Windows Subsystem for Linux |
| Git Bash | Windows |

**Supported path formats:** Unix (`/home/user/Videos`), WSL (`/mnt/c/Users/user/Videos`), Windows (`C:\Users\user\Videos`, auto-converted).

**Supported video formats:** mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg, 3gp.

## Documentation

- **README.md** — this file (overview and quick reference)
- **INSTALLATION-GUIDE.md** — setup instructions and troubleshooting
- **VIDEO-MANAGER-BASH-GUIDE.md** — complete feature documentation
- **QUICK-REFERENCE.md** — command cheat sheet
- **ADVANCED-FEATURES-v1.2.md** — advanced configuration guide
- **SUBTITLE-FEATURE-GUIDE.md** — subtitle generation guide

## Architectural Decisions

- **Modular design** — 12 independent modules.
- **Clean separation** — Foundation, Core Features, Advanced Features.
- **Maintainable** — each module focused on a single responsibility.
- **Extensible** — easy to add new features.
- **CI/CD** — automated testing on Ubuntu and macOS via GitHub Actions.

### Logging and Undo

**Logs**
- Location: `~/.video-manager-logs/`
- Format: timestamped with operation details
- Access: via menu (Utilities → View Logs) or direct file access

**Undo operations**
- Automatic logging of organize operations
- Undo log location: `~/.video-manager-logs/undo-history/`
- Access via menu or CLI: `--undo-organize`, `--list-undo`

## Development Log

<details>
<summary>Version history — click to expand</summary>

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

</details>

## License

Created for personal video management. Free to use and modify.

## Support

Built-in help:
```console
./video-manager-ultimate.sh --help
```

Interactive menu: Utilities → System Information for diagnostics.
