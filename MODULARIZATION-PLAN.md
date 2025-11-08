# Modularization Plan

**Date:** 2025-11-08
**Current State:** 6,530 lines in single file
**Target State:** Modular architecture with ~10-12 files

---

## Architecture Design

```
vmgr/
├── video-manager-ultimate.sh      # Main entry point (~300 lines)
├── lib/                           # Library modules
│   ├── core.sh                    # Core initialization & globals
│   ├── platform.sh                # Platform detection & compatibility
│   ├── logging.sh                 # Logging system
│   ├── config.sh                  # Configuration management
│   ├── utils.sh                   # Utility functions
│   ├── file-ops.sh                # File operations & renaming
│   ├── duplicates.sh              # Duplicate detection
│   ├── subtitles.sh               # Subtitle generation
│   ├── catalog.sh                 # Multi-drive catalog
│   ├── organize.sh                # Organization & undo
│   ├── batch.sh                   # Batch processing & workflows
│   └── ui.sh                      # Interactive menus
├── install.sh
├── README.md
└── docs/                          # Documentation
```

---

## Module Breakdown

### 1. lib/core.sh (~150 lines)
**Purpose:** Core initialization, constants, and global variables

**Contents:**
- Script metadata (version, name, date)
- Color codes and symbols
- Configuration constants
- Default settings
- Global arrays (STATS, etc.)
- Basic initialization function

**Dependencies:** None (loaded first)

---

### 2. lib/platform.sh (~200 lines)
**Purpose:** Platform detection and compatibility functions

**Contents:**
- `detect_os()` - OS detection
- `get_file_size_bytes()` - Cross-platform file size
- `calculate_file_hash()` - Cross-platform hashing
- `format_bytes()` - Number formatting
- `open_file_manager()` - Open native file browser
- `convert_to_wsl_path()` - Windows path conversion

**Dependencies:** core.sh

**Estimated Lines:** 150-200

---

### 3. lib/logging.sh (~150 lines)
**Purpose:** Logging and output functions

**Contents:**
- `init_logging()` - Setup log directory
- `log_message()` - Base logging
- `log_verbose()`, `log_success()`, `log_error()`, `log_warning()`, `log_info()`
- `start_operation()`, `end_operation()`
- `show_progress()` - Progress indicators
- `show_spinner()` - Spinner animation
- `draw_progress_bar()` - Progress bar

**Dependencies:** core.sh, platform.sh

**Estimated Lines:** 150

---

### 4. lib/config.sh (~200 lines)
**Purpose:** Configuration management

**Contents:**
- `save_config()` - Save settings
- `load_config()` - Load settings
- `list_config_profiles()` - List profiles
- `delete_config_profile()` - Delete profile
- Configuration file handling

**Dependencies:** core.sh, logging.sh

**Estimated Lines:** 150-200

---

### 5. lib/utils.sh (~400 lines)
**Purpose:** General utility functions

**Contents:**
- `validate_directory()` - Directory validation
- `get_safe_filename()` - Sanitize filenames
- `sanitize_input()` - Input sanitization
- `validate_path_safety()` - Path security checks
- `is_video_file()`, `is_image_file()`, `is_audio_file()`
- `get_media_type()` - Media type detection
- `passes_size_filter()`, `passes_date_filter()`, `passes_pattern_filter()`
- `confirm_file_operation()` - User confirmation
- `show_operation_preview()` - Preview changes
- Media metadata functions (dimensions, EXIF, etc.)

**Dependencies:** core.sh, logging.sh, platform.sh

**Estimated Lines:** 400-500

---

### 6. lib/file-ops.sh (~500 lines)
**Purpose:** File operations and renaming

**Contents:**
- `apply_bracket_notation()` - Bracket notation
- `remove_dashes()` - Dash removal
- `fix_bracket_spacing()` - Spacing fixes
- `cleanup_filename()` - General cleanup
- `rename_files_in_directory()` - Bulk rename
- `flatten_directory()` - Directory flattening
- Granular control functions
- Undo/rollback system basics

**Dependencies:** core.sh, logging.sh, utils.sh

**Estimated Lines:** 500-600

---

### 7. lib/duplicates.sh (~300 lines)
**Purpose:** Duplicate detection

**Contents:**
- `find_duplicates()` - Directory-based duplicate finder
- `find_duplicates_in_catalog()` - Catalog-based finder
- `find_similar_images()` - Image similarity
- `show_duplicates_report()` - Display duplicates
- Hash comparison functions

**Dependencies:** core.sh, logging.sh, platform.sh, utils.sh

**Estimated Lines:** 300-400

---

### 8. lib/subtitles.sh (~1,200 lines)
**Purpose:** Subtitle generation with Whisper AI

**Contents:**
- `check_whisper_installation()` - Check dependencies
- `validate_whisper_model()`, `validate_subtitle_format()`, `validate_language_code()`
- `generate_subtitle_for_file()` - Single file generation
- `generate_subtitles_in_directory()` - Batch generation
- `collect_video_files_recursive()` - File collection
- GPU detection and parallel processing
- Speaker diarization
- Subtitle editing and preview
- Resume functionality
- All subtitle helper functions

**Dependencies:** core.sh, logging.sh, platform.sh, utils.sh

**Estimated Lines:** 1,200-1,500

---

### 9. lib/catalog.sh (~800 lines)
**Purpose:** Multi-drive catalog system

**Contents:**
- `init_catalog_db()` - Database initialization
- `get_drive_id()`, `get_drive_label()`, `detect_drive_type()`
- `register_drive()` - Drive registration
- `catalog_drive()` - Catalog creation
- `list_cataloged_drives()` - List drives
- `search_catalog()` - Search functionality
- JSON database operations

**Dependencies:** core.sh, logging.sh, platform.sh, utils.sh

**Estimated Lines:** 800-1,000

---

### 10. lib/organize.sh (~400 lines)
**Purpose:** File organization and undo system

**Contents:**
- `organize_by_subfolder_names()` - Main organize function
- `init_undo_system()` - Undo initialization
- `record_undo_operation()`, `save_undo_operation()`
- `undo_last_operation()` - Advanced undo
- `undo_last_file_operation()` - Simple undo
- `undo_organize_operation()` - Organize-specific undo
- `list_undo_operations()` - List undo history
- Favorites/bookmarks system
- Watch folders

**Dependencies:** core.sh, logging.sh, utils.sh

**Estimated Lines:** 400-500

---

### 11. lib/batch.sh (~300 lines)
**Purpose:** Batch processing and workflows

**Contents:**
- `batch_generate_subtitles()` - Batch subtitle generation
- `batch_process_folders()` - Multi-folder processing
- `workflow_new_collection()` - New collection workflow
- `workflow_deep_clean()` - Deep clean workflow
- Print statistics

**Dependencies:** core.sh, logging.sh, file-ops.sh, duplicates.sh, subtitles.sh

**Estimated Lines:** 300-400

---

### 12. lib/ui.sh (~1,200 lines)
**Purpose:** Interactive menu system

**Contents:**
- `show_header()` - Display header
- All menu functions (main, single-ops, batch, workflows, etc.)
- All handler functions (handle_single_operations, handle_batch_processing, etc.)
- `get_directory_input()` - Directory input
- Interactive mode management

**Dependencies:** All other modules

**Estimated Lines:** 1,200-1,500

---

### 13. video-manager-ultimate.sh (~300 lines)
**Purpose:** Main entry point

**Contents:**
- Module sourcing (load all lib/*.sh files)
- `parse_arguments()` - Command-line parsing
- `show_usage()`, `show_version()` - Help functions
- `startup_check()` - Pre-flight checks
- `main()` - Main execution
- Error handling and cleanup

**Dependencies:** All lib modules

**Estimated Lines:** 300-400

---

## Module Loading Order

```bash
# In video-manager-ultimate.sh

# 1. Core (must be first)
source "${LIB_DIR}/core.sh"

# 2. Platform & Logging (no inter-dependencies)
source "${LIB_DIR}/platform.sh"
source "${LIB_DIR}/logging.sh"

# 3. Configuration & Utilities
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/utils.sh"

# 4. Feature modules (can load in any order)
source "${LIB_DIR}/file-ops.sh"
source "${LIB_DIR}/duplicates.sh"
source "${LIB_DIR}/subtitles.sh"
source "${LIB_DIR}/catalog.sh"
source "${LIB_DIR}/organize.sh"
source "${LIB_DIR}/batch.sh"

# 5. UI (must be last, depends on all features)
source "${LIB_DIR}/ui.sh"
```

---

## Implementation Strategy

### Phase 1: Setup (Day 1)
1. Create lib/ directory
2. Create core.sh with constants and globals
3. Test that main script can source core.sh

### Phase 2: Extract Core Modules (Day 1-2)
1. Extract platform.sh
2. Extract logging.sh
3. Extract config.sh
4. Extract utils.sh
5. Test after each extraction

### Phase 3: Extract Feature Modules (Day 2-3)
1. Extract file-ops.sh
2. Extract duplicates.sh
3. Extract organize.sh
4. Test after each extraction

### Phase 4: Extract Large Modules (Day 3-4)
1. Extract subtitles.sh
2. Extract catalog.sh
3. Extract batch.sh
4. Test after each extraction

### Phase 5: Extract UI & Finalize (Day 4-5)
1. Extract ui.sh
2. Streamline main script
3. Update install.sh
4. Final testing

### Phase 6: Documentation & Testing (Day 5)
1. Add module headers
2. Update README
3. Create module documentation
4. Comprehensive testing

---

## Testing Checklist

After each module extraction:
- [ ] Syntax check: `bash -n video-manager-ultimate.sh`
- [ ] Version check: `./video-manager-ultimate.sh --version`
- [ ] Help check: `./video-manager-ultimate.sh --help`
- [ ] Interactive menu: `./video-manager-ultimate.sh`
- [ ] Feature test: Test one command from extracted module

Final testing:
- [ ] All menu options work
- [ ] All CLI commands work
- [ ] Dry-run mode works
- [ ] Logging works
- [ ] Configuration saving/loading works

---

## Benefits of Modularization

1. **Maintainability:** Each module < 500 lines (except subtitles, catalog, UI)
2. **Testability:** Can test modules independently
3. **Readability:** Clear separation of concerns
4. **Collaboration:** Multiple developers can work on different modules
5. **Debugging:** Easier to isolate issues
6. **Extensibility:** New features can be added as new modules
7. **Performance:** Modules can be lazy-loaded if needed

---

## Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking existing functionality | Test after each extraction |
| Module dependency issues | Follow strict loading order |
| Variable scope problems | Use explicit exports/globals |
| Path issues with sourcing | Use absolute paths from $SCRIPT_DIR |
| Increased complexity | Clear documentation and comments |

---

## File Size Estimates

| File | Current | Target | Reduction |
|------|---------|--------|-----------|
| video-manager-ultimate.sh | 6,530 | 300 | -95% |
| lib/core.sh | - | 150 | - |
| lib/platform.sh | - | 200 | - |
| lib/logging.sh | - | 150 | - |
| lib/config.sh | - | 200 | - |
| lib/utils.sh | - | 400 | - |
| lib/file-ops.sh | - | 500 | - |
| lib/duplicates.sh | - | 300 | - |
| lib/subtitles.sh | - | 1,200 | - |
| lib/catalog.sh | - | 800 | - |
| lib/organize.sh | - | 400 | - |
| lib/batch.sh | - | 300 | - |
| lib/ui.sh | - | 1,200 | - |
| **TOTAL** | 6,530 | ~6,100 | -430* |

*Note: Total may be slightly less due to removing redundant comments/headers

---

## Next Steps

1. Review this plan
2. Create backup: `cp video-manager-ultimate.sh video-manager-ultimate-legacy.sh`
3. Create lib/ directory
4. Begin Phase 1: Extract core.sh

---

**Created By:** Claude Code
**Status:** Ready for implementation
**Estimated Time:** 4-5 days
