# Tab Completion for Video Manager Ultimate

## Overview

Tab completion enables you to auto-complete commands, options, and paths by pressing the **Tab** key.

---

## Features

### ✓ Command Completion
Press Tab after `vmgr` to see available commands:
```bash
vmgr <Tab><Tab>
# Shows: rename flatten cleanup duplicates subtitles workflow-new workflow-clean batch --organize --undo-organize --list-undo
```

### ✓ Option Completion
Press Tab after a dash to see available options:
```bash
vmgr -<Tab><Tab>
# Shows: --help --version --dry-run --quiet --interactive --model --format --language --gpu --parallel --organize --organize-target --organize-search --undo-organize --list-undo
```

### ✓ Context-Aware Completion
Completions change based on previous arguments:
```bash
vmgr --model <Tab><Tab>
# Shows: tiny base small medium large

vmgr --format <Tab><Tab>
# Shows: srt vtt txt json

vmgr --language <Tab><Tab>
# Shows: auto en es fr de it pt ru ja zh ko ar
```

### ✓ Directory Path Completion
After commands, Tab completes directory paths:
```bash
vmgr rename /path/to/<Tab>
# Shows directories in /path/to/
```

---

## Installation

### Automatic (Recommended)

The installer sets up completion automatically:
```bash
./install.sh
```

### Manual Installation

#### Linux / WSL

```bash
# Create completion directory
mkdir -p ~/.bash_completion.d

# Copy completion file
cp vmgr-completion.bash ~/.bash_completion.d/vmgr

# Add to ~/.bashrc
echo '[[ -f ~/.bash_completion.d/vmgr ]] && source ~/.bash_completion.d/vmgr' >> ~/.bashrc

# Reload shell
source ~/.bashrc
```

#### macOS

```bash
# System-wide (requires permissions)
sudo cp vmgr-completion.bash /usr/local/etc/bash_completion.d/vmgr

# OR user-specific
mkdir -p ~/.bash_completion.d
cp vmgr-completion.bash ~/.bash_completion.d/vmgr
echo '[[ -f ~/.bash_completion.d/vmgr ]] && source ~/.bash_completion.d/vmgr' >> ~/.zshrc
source ~/.zshrc
```

#### Windows (Git Bash)

```bash
# Create completion directory
mkdir -p ~/.bash_completion.d

# Copy completion file
cp vmgr-completion.bash ~/.bash_completion.d/vmgr

# Add to ~/.bashrc
echo '[[ -f ~/.bash_completion.d/vmgr ]] && source ~/.bash_completion.d/vmgr' >> ~/.bashrc

# Reload
source ~/.bashrc
```

---

## Usage Examples

### Basic Command Completion

```bash
# Type partial command and press Tab
vmgr ren<Tab>
# Completes to: vmgr rename

vmgr flat<Tab>
# Completes to: vmgr flatten
```

### Option Completion

```bash
# See all options
vmgr --<Tab><Tab>

# Complete partial option
vmgr --dry<Tab>
# Completes to: vmgr --dry-run

vmgr --para<Tab>
# Completes to: vmgr --parallel
```

### Value Completion

```bash
# Whisper models
vmgr subtitles --model <Tab><Tab>
# Shows: tiny base small medium large

# Choose one
vmgr subtitles --model b<Tab>
# Completes to: vmgr subtitles --model base

# Subtitle formats
vmgr subtitles --format <Tab><Tab>
# Shows: srt vtt txt json

# Languages
vmgr subtitles --language <Tab><Tab>
# Shows: auto en es fr de it pt ru ja zh ko ar
```

### Directory Completion

```bash
# After a command, Tab completes directories
vmgr rename ~/V<Tab>
# Shows directories starting with V in home

vmgr duplicates /mnt/<Tab>
# Shows mounted drives: c d e f ...
```

### Complex Command Building

```bash
# Build complete command with Tab
vmgr <Tab>           # Select: subtitles
vmgr subtitles --<Tab>   # Select: --model
vmgr subtitles --model <Tab>  # Select: base
vmgr subtitles --model base --<Tab>  # Select: --format
vmgr subtitles --model base --format <Tab>  # Select: srt
vmgr subtitles --model base --format srt ~/Videos/<Tab>
# Final: vmgr subtitles --model base --format srt ~/Videos/MyFolder
```

---

## Supported Completions

### Commands
- `rename` - Rename files with bracket notation
- `flatten` - Flatten directory structure
- `cleanup` - Full cleanup operation
- `duplicates` - Find duplicate files
- `subtitles` - Generate subtitles
- `workflow-new` - New collection workflow
- `workflow-clean` - Deep clean workflow
- `batch` - Batch processing
- `--organize` - Organize files by subfolder names
- `--undo-organize` - Undo organize operation
- `--list-undo` - List available undo operations

### Options
- `--help`, `-h` - Show help
- `--version`, `-v` - Show version
- `--dry-run`, `-d` - Enable dry run
- `--quiet`, `-q` - Quiet mode
- `--interactive`, `-i` - Interactive mode
- `--model` - Whisper model selection
- `--format` - Subtitle format
- `--language` - Language code
- `--gpu` - Enable GPU acceleration
- `--parallel` - Parallel jobs (1-8)
- `--no-optimize` - Disable optimization
- `--edit` - Interactive edit mode
- `--speaker-diarization` - Speaker identification
- `--no-punctuation` - Disable auto-punctuation
- `--organize` - Organize files by subfolder names
- `--organize-target` - Set target folder for organize
- `--organize-search` - Set search path for organize
- `--undo-organize` - Undo last organize operation
- `--list-undo` - List available undo operations

### Whisper Models
- `tiny` - Fastest, least accurate
- `base` - Good balance (default)
- `small` - Better accuracy
- `medium` - High accuracy
- `large` - Best accuracy, slowest

### Subtitle Formats
- `srt` - SubRip (default)
- `vtt` - WebVTT
- `txt` - Plain text
- `json` - JSON format

### Languages
- `auto` - Auto-detect (default)
- `en` - English
- `es` - Spanish
- `fr` - French
- `de` - German
- `it` - Italian
- `pt` - Portuguese
- `ru` - Russian
- `ja` - Japanese
- `zh` - Chinese
- `ko` - Korean
- `ar` - Arabic

---

## Troubleshooting

### Completion Not Working

**Check if sourced:**
```bash
# Add to current session
source ~/.bash_completion.d/vmgr

# Check if in bashrc/zshrc
grep vmgr ~/.bashrc
```

**Reload shell:**
```bash
# Bash
source ~/.bashrc

# Zsh (macOS)
source ~/.zshrc

# Or just restart terminal
```

### No Completions Appearing

**Check file permissions:**
```bash
ls -la ~/.bash_completion.d/vmgr
# Should be readable: -rw-r--r--

# Fix if needed
chmod 644 ~/.bash_completion.d/vmgr
```

**Test directly:**
```bash
source ~/.bash_completion.d/vmgr
vmgr <Tab><Tab>
```

### Partial Completion

If Tab only completes partially, press Tab again to see all options:
```bash
vmgr re<Tab>    # Completes to: vmgr ren
vmgr ren<Tab><Tab>  # Shows: rename (if only match)
```

---

## Advanced Usage

### Multiple Tab Presses

- **Single Tab**: Complete if only one match
- **Double Tab**: Show all matches
- **Triple Tab**: Cycle through matches (some shells)

### Case Sensitivity

Completion is case-sensitive by default:
```bash
vmgr Ren<Tab>   # Won't match 'rename'
vmgr ren<Tab>   # Matches 'rename'
```

### Escape Spaces

Paths with spaces are auto-escaped:
```bash
vmgr rename ~/My\ Videos<Tab>
# Properly escapes spaces
```

---

## Uninstallation

Remove completion:
```bash
# Remove file
rm ~/.bash_completion.d/vmgr

# Remove from shell config
# Edit ~/.bashrc or ~/.zshrc and remove the vmgr completion line

# Reload
source ~/.bashrc
```

---

## Benefits

✓ **Faster Command Entry** - Less typing
✓ **Fewer Errors** - Auto-complete prevents typos
✓ **Discover Options** - See what's available
✓ **Learn Commands** - Visual command reference
✓ **Path Assistance** - Easy directory navigation
✓ **Professional Feel** - Like system commands

---

## Compatibility

- ✅ Linux (Bash 4.0+)
- ✅ WSL (Windows Subsystem for Linux)
- ✅ macOS (Bash/Zsh)
- ✅ Git Bash (Windows)
- ✅ Most terminal emulators

---

## Contributing

Found a completion that should be added? Edit `vmgr-completion.bash` and add to the appropriate section!
