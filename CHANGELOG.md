# Changelog

All notable changes to Video Manager Ultimate will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.0] - 2025-12-23

### 🎉 Major Architectural Transformation

This release represents a **complete refactoring** of the video manager from a monolithic script to a clean, modular architecture.

### Added

- **Modular Architecture** - Split into 12 independent, testable modules:
  - **Phase 1 - Foundation** (896 lines)
    - `lib/core.sh` - Core initialization and constants
    - `lib/platform.sh` - Cross-platform compatibility
    - `lib/logging.sh` - Logging and progress tracking
    - `lib/config.sh` - Configuration management
  - **Phase 2 - Core Features** (1,942 lines)
    - `lib/utils.sh` - Utility functions and file type detection
    - `lib/file-ops.sh` - File operations and renaming
    - `lib/duplicates.sh` - Duplicate file detection
    - `lib/organize.sh` - File organization and undo system
  - **Phase 3 - Advanced Features** (2,024 lines)
    - `lib/subtitles.sh` - Whisper AI subtitle generation
    - `lib/catalog.sh` - Multi-drive catalog system
    - `lib/batch.sh` - Batch processing and workflows
    - `lib/ui.sh` - Interactive menu system (1,577 lines)

- **Comprehensive Test Suite** - `test-modules.sh` with 26 tests (100% pass rate)
- **Enhanced Tab Completion** - Updated for all commands including organize operations
- **Improved Documentation** - Added MODULARIZATION-PROGRESS.md tracking the journey

### Changed

- **Main Script Size** - Reduced from 6,590 lines to 465 lines (93% reduction)
- **Architecture** - Clean separation of concerns with documented dependencies
- **Maintainability** - Each module focused on single responsibility
- **Entry Point** - Main script now loads modules and orchestrates execution

### Fixed

- Tab completion now includes all organize commands (`--organize`, `--organize-target`, `--organize-search`, `--undo-organize`, `--list-undo`)
- Module loading with proper error handling
- All functionality preserved from previous versions

### Technical Details

**Metrics:**
- Main script: 6,590 → 465 lines (93% reduction)
- Total modules: 4,869 lines across 12 files
- Test coverage: 100% (26/26 tests passing)
- Modules completed: 12/12 (100%)

**Benefits:**
- ✅ Better maintainability
- ✅ Easier testing
- ✅ Clear code organization
- ✅ Simpler to extend
- ✅ Reduced complexity

**Preserved Functionality:**
- All CLI commands working
- Interactive menu fully functional
- Organize/undo operations working
- Subtitle generation working
- All original features intact

### Migration Notes

For users upgrading from v1.2.0:
- No breaking changes - all commands work exactly as before
- Legacy versions preserved as backups:
  - `video-manager-ultimate-legacy.sh` (original)
  - `video-manager-ultimate-monolithic.sh` (pre-refactor)
- Tab completion may need to be re-sourced: `source ~/.bash_completion.d/vmgr`

---

## [1.2.0] - 2025-11-08

### Added

- Subtitle generation with Whisper AI
- Multiple Whisper models support (tiny, base, small, medium, large)
- GPU acceleration for subtitle generation
- Parallel processing (1-8 workers)
- Speaker diarization support
- Auto-punctuation and editing
- Recursive directory scanning for subtitles
- File organization by subfolder names
- Undo/rollback functionality for organize operations
- Operation logging and history
- Configurable default paths for organize

### Enhanced

- Interactive menu system with color-coded output
- Comprehensive logging with timestamps
- Improved error handling
- Cross-platform compatibility (Linux, macOS, Windows, WSL)

---

## [1.1.0] - 2025-11-02

### Added

- Initial release
- File renaming with bracket notation
- Directory flattening
- Duplicate detection (SHA-256 hash-based)
- Batch processing
- Dry run mode
- Interactive menu system
- Command-line interface
- Tab completion support
- Installation script

### Features

- Cross-platform support (Linux/WSL)
- Color-coded output
- Real-time progress indicators
- Conflict resolution
- Path validation
- Comprehensive logging

---

## Development Timeline

- **2025-12-23** - v1.3.0 - Modular architecture complete (~10.6 hours of refactoring)
- **2025-11-08** - v1.2.0 - Subtitle and organize features added
- **2025-11-02** - v1.1.0 - Initial release

---

## Links

- [Modularization Progress Report](MODULARIZATION-PROGRESS.md)
- [Modularization Plan](MODULARIZATION-PLAN.md)
- [Installation Guide](INSTALLATION-GUIDE.md)
- [Tab Completion Guide](TAB-COMPLETION.md)
