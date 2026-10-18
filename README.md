# Video Manager Ultimate — Bash Edition

**Cross-platform video file management and organization tool for Linux, macOS, Windows (Git Bash), and WSL.**

[![Version](https://img.shields.io/badge/version-1.8.0-blue.svg)](https://github.com/emaag/vmgr/releases/tag/v1.8.0)
[![CI](https://github.com/emaag/vmgr/workflows/CI/badge.svg)](https://github.com/emaag/vmgr/actions)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Tests](https://img.shields.io/badge/tests-657%2F657%20passing-success.svg)](tests/)
[![Modular](https://img.shields.io/badge/architecture-modular-orange.svg)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-lightgrey.svg)](#setup-instructions)

### Status at a glance — v1.8.0: Several Subreddits, Catalog Freshness

| Change | State |
|--------|-------|
| Multi-drive catalog: incremental scans, search that works for unplugged drives, duplicates across drives | ✅ Shipped |
| Guided Reddit API setup that checks the login before saving; galleries and full-speed downloads | ✅ Shipped |
| Reddit downloader no longer leaves empty folders and explains why nothing downloaded | ✅ Shipped |
| Duplicates are moved to an undoable `.vmgr-trash` (Empty Trash deletes them for good) | ✅ Shipped |
| Whisper filler cues removed; silent videos reported as "no speech" | ✅ Shipped |
| Batch Subtitle Generation with the folder queue and per-folder results | ✅ Shipped |
| Undo for renames and flattens (single and batch) | ✅ Shipped |
| Batch Processing with a folder queue, preview, confirmation and per-folder results | ✅ Shipped |
| Redesigned interface: framed header, single-key menus, themed directory browser | ✅ Shipped |
| Progress bars and a summary card after every operation | ✅ Shipped |
| Quiet output by default (`--verbose` for detail); `NO_COLOR` and ASCII fallbacks | ✅ Shipped |
| Subtitle generation (OpenAI Whisper backend, GPU, parallel jobs, skip-existing, dry-run) | ✅ Shipped |
| 657-test automated suite, including pseudo-terminal tests of the menus and browser | ✅ Shipped |

[See the changelog →](CHANGELOG.md)

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

- **File Renaming** — bracket notation formatting (`[Studio] filename.mp4`), with undo
- **Directory Flattening** — move files from subdirectories to top level, with undo
- **Duplicate Detection** — SHA-256 hash-based; reports are written to `~/.video-manager-logs/duplicate-reports/`
- **File Organization** — automatic sorting by subfolder names with undo functionality
- **Batch Processing** — queue several folders (or every subfolder with videos), preview, confirm, and get a per-folder results list
- **Image Conversion** — convert PNG/WebP/HEIC to JPG (requires ImageMagick)
- **Multi-Drive Catalog** — scan drives into a catalog (incremental, with hashes and metadata), search it even when a drive is unplugged, and find duplicates across drives. Requires `jq`
- **Subtitle Generation** — OpenAI Whisper backend; GPU acceleration, parallel jobs, skip-existing, dry-run, size/date filters, interactive editing. Requires `pip install openai-whisper` (or whisper.cpp)

### Organization Features

- Organize files by matching subfolder names
- Exclude patterns (e.g., "full" folders)
- Undo/rollback with operation logging
- Progress tracking
- Configurable default paths
- Command-line and interactive modes

### Interface

- Single-key menus (no Enter); `Esc` goes back
- Directory browser with a live preview pane, recent folders and typed paths
- Progress bars, `old → new` rename pairs and a summary card for every operation
- Quiet by default; `--verbose` shows every intermediate step
- `NO_COLOR` and `TERM=dumb` give plain output; non-UTF-8 locales use ASCII glyphs
- Command-line interface for automation
- Comprehensive logging
- Dry run mode

### Safety

- Dry run preview mode, and a confirmation before real changes
- Undo log for renames, flattens and organize runs
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

### Multi-Drive Catalog
```console
# Scan a drive or folder into the catalog (incremental: unchanged files are not re-hashed)
./video-manager-ultimate.sh catalog /mnt/d

# Drives with online/offline status and totals
./video-manager-ultimate.sh catalog-list

# Search by name, hash prefix, resolution or camera; drives that are unplugged are included
./video-manager-ultimate.sh catalog-search "season 2" video

# Duplicates across every cataloged drive, and a text report
./video-manager-ultimate.sh catalog-duplicates
./video-manager-ultimate.sh catalog-report
```

### Reddit
```console
# Download images and videos from a subreddit
./video-manager-ultimate.sh reddit EarthPorn ~/Pictures/earthporn 100

# Guided API setup: unlocks galleries and full-speed downloads (checks the login before saving)
./video-manager-ultimate.sh reddit-setup
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

- **README.md** — This file (overview and quick reference)
- **docs/INSTALLATION-GUIDE.md** — Setup instructions and troubleshooting
- **docs/USER-GUIDE.md** — Complete feature documentation
- **docs/QUICK-REFERENCE.md** — Command cheat sheet
- **docs/SUBTITLE-FEATURE-GUIDE.md** — Subtitle generation guide
- **docs/CROSS-PLATFORM.md** — Platform-specific setup
- **docs/TAB-COMPLETION.md** — Shell tab completion
- **CHANGELOG.md** / **CONTRIBUTING.md**

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
- Renames, flattens and organize runs are logged automatically (one undo log per operation; a batch is one operation)
- Undo log location: `~/.video-manager-logs/undo-history/`
- Undo from the menu (Utilities → Undo Last Operation) or CLI: `--undo-organize [ID]`, `--list-undo`
- Deleting duplicates moves them to a hidden `.vmgr-trash` folder (undoable; Utilities → Empty Trash deletes them for good). Image conversion is not undoable. Turn the log off with Settings → Granular Controls → Undo System; duplicates are then deleted permanently

## Development Log

<details>
<summary>Version history — click to expand</summary>

### v1.8.0 (October 2026)
- Download several subreddits in one run
- Catalog freshness warnings

### v1.7.0 (October 2026)
- Catalog scales to large libraries (batched hashing, one-record-per-line storage, fast search)
- Clean up duplicates across drives (undoable)
- Documentation refreshed

### v1.6.0 (October 2026)
- Multi-drive catalog (incremental scans, offline search, cross-drive duplicates)
- Guided Reddit API setup; Reddit downloader leaves no empty folders
- Log messages print Windows paths literally

### v1.5.0 (October 2026)
- Deleted duplicates move to an undoable trash; Empty Trash for permanent deletion
- Whisper filler cues removed; "no speech" reporting with a skip marker
- Batch Subtitle Generation uses the folder queue and results list

### v1.4.0 (October 2026)
- Undo for renames and flattens, single and batch
- Batch Processing reachable from the menu, with a folder queue, preview, confirmation and results list
- Redesigned interface: framed header, single-key menus, themed directory browser, progress bars, summary card
- Quiet by default (`--verbose`), `NO_COLOR` and ASCII fallbacks
- Duplicate reports moved out of the scanned folder

### v1.3.0 (December 2025)
- Modular architecture (12 modules), tab completion, 200-test suite

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
