# Cursor Menu Navigation

**Version:** 1.0.0
**Date:** November 10, 2025
**Module:** `lib/menu-navigation.sh`

---

## Overview

The cursor menu navigation module adds interactive arrow key-based menu navigation to Video Manager Ultimate. Instead of typing numbers and pressing Enter, users can now use arrow keys to highlight options and Enter to select.

---

## Features

### Navigation Methods

1. **Arrow Keys**
   - ↑ (Up) - Move selection up
   - ↓ (Down) - Move selection down
   - Wraps around: pressing up at the top goes to bottom, and vice versa

2. **Quick Selection**
   - Type the option number/letter directly for instant selection
   - Works the same as the traditional method

3. **Confirmation**
   - Enter - Confirm and execute the selected option
   - Q - Go back to previous menu or quit

4. **Visual Feedback**
   - Selected option is highlighted with an arrow (→) and bright colors
   - Unselected options are dimmed
   - Clear instructions shown at the bottom of each menu

---

## Usage

### Demo Mode

Try out the cursor menu navigation with the included demo:

```bash
./demo-cursor-menu.sh
```

This demo shows all the cursor-enabled menus without actually executing operations.

### In Your Scripts

To use cursor menu navigation in your scripts:

```bash
# Load required modules
source lib/core.sh
source lib/logging.sh
source lib/menu-navigation.sh

# Initialize
init_core
init_logging
init_cursor_menu

# Use cursor menu
choice=$(show_main_menu_cursor)
result=$?

if [[ $result -eq 0 ]]; then
    echo "User selected: $choice"
else
    echo "User cancelled"
fi
```

---

## Available Menus

All major menus have cursor-enabled versions:

1. **`show_main_menu_cursor`** - Main menu with all operations
2. **`show_single_operations_menu_cursor`** - Single folder operations
3. **`show_batch_menu_cursor`** - Batch processing options
4. **`show_workflow_menu_cursor`** - Pre-configured workflows
5. **`show_duplicate_menu_cursor`** - Duplicate detection
6. **`show_subtitle_menu_cursor`** - Subtitle generation
7. **`show_utilities_menu_cursor`** - Utility functions
8. **`show_settings_menu_cursor`** - Settings configuration

---

## Automatic Fallback

The module automatically detects if the terminal supports cursor navigation:

- **Supported:** Interactive terminals with `tput` command available
- **Fallback:** Non-interactive environments use standard number-based menus

```bash
# Check if cursor navigation is supported
if check_cursor_support; then
    echo "Cursor navigation available"
else
    echo "Using standard menus"
fi
```

---

## Integration Examples

### Simple Integration

```bash
# Smart wrapper that chooses appropriate menu
choice=$(smart_menu show_main_menu)
```

### Custom Menu

```bash
# Define your menu options
local -a my_menu=(
    "1:First Option:Does something cool"
    "2:Second Option:Does something else"
    "3:Third Option:Another feature"
    "Q:Quit:Exit menu"
)

# Display and get selection
local result
cursor_menu "My Custom Menu" my_menu result
echo "User selected: $result"
```

### Option Format

Each menu option follows the format: `"key:label:description"`

- **key:** The selection key (number, letter)
- **label:** The main text displayed
- **description:** Optional additional info

---

## Terminal Requirements

### Minimum Requirements

- Interactive terminal (stdin connected to a tty)
- `tput` command available (usually part of ncurses)
- ANSI escape sequence support

### Tested Terminals

✓ **Linux**
- GNOME Terminal
- Konsole
- xterm
- Alacritty

✓ **macOS**
- Terminal.app
- iTerm2

✓ **Windows**
- WSL2 with Windows Terminal
- Git Bash (limited support)

### Non-Interactive Environments

The module gracefully falls back to standard input in:
- SSH sessions with limited terminal
- Piped input/output
- Automated scripts
- CI/CD pipelines

---

## API Reference

### Functions

#### `cursor_menu(title, options_ref, result_ref)`

Display an interactive cursor-based menu.

**Parameters:**
- `title` - Menu title string
- `options_ref` - Name of array containing menu options
- `result_ref` - (Optional) Name of variable to store result

**Returns:**
- Exit code 0 on selection, 1 on cancel
- Selected key via reference variable

**Example:**
```bash
local -a options=("1:Option A:" "2:Option B:" "3:Option C:")
local choice
cursor_menu "Select One" options choice
if [[ $? -eq 0 ]]; then
    echo "Selected: $choice"
fi
```

#### `check_cursor_support()`

Check if terminal supports cursor navigation.

**Returns:**
- Exit code 0 if supported, 1 if not

**Example:**
```bash
if check_cursor_support; then
    # Use cursor menus
else
    # Use standard menus
fi
```

#### `init_cursor_menu()`

Initialize cursor menu system and set `CURSOR_MENU_ENABLED` variable.

**Side Effects:**
- Sets `$CURSOR_MENU_ENABLED` environment variable
- Logs initialization status

**Example:**
```bash
init_cursor_menu
echo "Cursor menus: $CURSOR_MENU_ENABLED"
```

#### `smart_menu(menu_function)`

Automatically choose cursor or standard menu based on support.

**Parameters:**
- `menu_function` - Base name of menu function (without _cursor suffix)

**Example:**
```bash
# Calls show_main_menu_cursor if supported, otherwise show_main_menu
choice=$(smart_menu show_main_menu)
```

---

## Implementation Details

### Key Handling

The module reads single characters using `read -rsn1` and detects escape sequences:

- **Arrow Keys:** Sent as 3-character sequence: `\x1b[A` (up), `\x1b[B` (down)
- **Enter:** Newline character `\n`
- **Letters/Numbers:** Single character matching

### Screen Management

- Uses `clear` to redraw entire menu on each navigation
- Hides cursor during navigation with `tput civis`
- Restores cursor when exiting with `tput cnorm`
- Calls `show_header()` if available for consistent branding

### Color Scheme

- **Selected:** Bright green arrow, white bold text
- **Unselected:** Yellow key, white text, cyan description
- **Title:** Bright cyan
- **Instructions:** Cyan

---

## Performance

- **Minimal overhead:** Menu redraws are instant on modern terminals
- **No external dependencies:** Uses only bash built-ins and `tput`
- **Graceful degradation:** Falls back without errors in unsupported environments

---

## Troubleshooting

### Arrow keys not working

**Problem:** Arrow keys insert escape sequences instead of navigating

**Solution:**
- Ensure terminal is in interactive mode
- Try a different terminal emulator
- Check that `$TERM` is set correctly

### Menu flickers

**Problem:** Screen flickers during navigation

**Solution:**
- This is normal in some terminals
- Try a terminal with better redraw performance
- Use quick selection (type numbers) instead

### Module not loading

**Problem:** "menu-navigation.sh not found" error

**Solution:**
```bash
# Check module exists
ls -la lib/menu-navigation.sh

# Verify loading path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Looking in: $SCRIPT_DIR/lib/"
```

---

## Future Enhancements

Potential improvements for future versions:

- [ ] Mouse support for terminal emulators that support it
- [ ] Search/filter within menus
- [ ] Multiple column layouts for large menus
- [ ] Keyboard shortcuts (e.g., Alt+key)
- [ ] Menu history (go back with Backspace)
- [ ] Customizable color schemes
- [ ] Help text overlay (press ?)

---

## Testing

Run the comprehensive test suite:

```bash
./test-modules.sh
```

This tests:
- Module loading
- Cursor support detection
- Initialization
- Graceful fallback behavior

---

## License

Part of Video Manager Ultimate - Bash Edition
Free to use and modify

---

## See Also

- **README.md** - Main documentation
- **MODULARIZATION-PROGRESS.md** - Architecture details
- **VIDEO-MANAGER-BASH-GUIDE.md** - Feature guide
- **demo-cursor-menu.sh** - Interactive demo

---

**Module Status:** ✓ Complete and Tested
**Phase:** 3 - UI Enhancements
**Integration:** Ready for production
