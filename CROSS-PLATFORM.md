# Cross-Platform Support

Video Manager Ultimate now supports **Linux, macOS, Windows (Git Bash/WSL)**, and **WSL** with automatic platform detection and adaptation.

## Platform Detection

The script automatically detects your operating system and adapts accordingly:

- **Linux** - Native Linux systems
- **macOS** - Apple systems with BSD-style commands
- **Windows** - Git Bash, MSYS2, MinGW, Cygwin
- **WSL** - Windows Subsystem for Linux

Check your detected platform: `Utilities → Display System Information`

---

## Installation by Platform

### Linux (Ubuntu/Debian)

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install jq ffmpeg

# Optional but recommended
sudo apt-get install libimage-exiftool-perl imagemagick

# Download and install
cd ~
git clone https://github.com/emaag/vmgr.git
cd vmgr
chmod +x video-manager-ultimate.sh

# Create symlink (optional)
mkdir -p ~/bin
ln -s ~/vmgr/video-manager-ultimate.sh ~/bin/vmgr
```

### macOS

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install jq ffmpeg exiftool imagemagick

# Download and install
cd ~
git clone https://github.com/emaag/vmgr.git
cd vmgr
chmod +x video-manager-ultimate.sh

# Create symlink (optional)
mkdir -p ~/bin
ln -s ~/vmgr/video-manager-ultimate.sh ~/bin/vmgr

# Add ~/bin to PATH (add to ~/.zshrc or ~/.bash_profile)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Windows (Git Bash)

```bash
# Install Git for Windows (includes Git Bash)
# Download from: https://git-scm.com/download/win

# Open Git Bash and install jq
# Download jq-win64.exe from https://stedolan.github.io/jq/download/
# Rename to jq.exe and place in: C:\Program Files\Git\usr\bin\

# Install ffmpeg (optional for metadata)
# Download from: https://ffmpeg.org/download.html
# Add to PATH or place in: C:\Program Files\Git\usr\bin\

# Clone repository
cd ~
git clone https://github.com/emaag/vmgr.git
cd vmgr
chmod +x video-manager-ultimate.sh

# Create alias (add to ~/.bashrc)
echo 'alias vmgr="~/vmgr/video-manager-ultimate.sh"' >> ~/.bashrc
source ~/.bashrc
```

### Windows (WSL)

```bash
# Same as Linux installation
sudo apt-get update
sudo apt-get install jq ffmpeg libimage-exiftool-perl imagemagick

cd ~
git clone https://github.com/emaag/vmgr.git
cd vmgr
chmod +x video-manager-ultimate.sh

mkdir -p ~/bin
ln -s ~/vmgr/video-manager-ultimate.sh ~/bin/vmgr
```

---

## Platform-Specific Features

### File Size Calculation
- **Linux/WSL**: Uses `stat -c%s`
- **macOS**: Uses `stat -f%z`
- **All**: Automatic fallback

### Hash Calculation
- **Linux**: `sha256sum` (primary)
- **macOS**: `shasum` or `openssl sha256`
- **Windows**: `shasum` (from Git Bash)
- **All**: Automatic detection and fallback

### File Manager Integration
- **Linux**: `xdg-open`, `nautilus`, or `dolphin`
- **macOS**: `open`
- **Windows/WSL**: `explorer.exe`
- **All**: Automatic detection

### Byte Formatting
- **With numfmt**: Uses `numfmt --to=iec-i`
- **Without numfmt**: Manual formatting (B, KiB, MiB, GiB)
- **All**: Automatic fallback

---

## Dependencies by Platform

### Required

| Dependency | Linux | macOS | Windows (Git Bash) | WSL |
|------------|-------|-------|-------------------|-----|
| Bash 4.0+  | ✓     | ✓     | ✓                 | ✓   |
| jq         | apt   | brew  | manual            | apt |

### Optional (for full functionality)

| Tool | Purpose | Linux | macOS | Windows |
|------|---------|-------|-------|---------|
| ffmpeg/ffprobe | Video metadata | apt | brew | manual |
| exiftool | EXIF data | apt | brew | manual |
| ImageMagick | Image metadata | apt | brew | manual |
| whisper | Subtitle generation | pip | pip | pip |

---

## Testing Your Installation

Run the system information utility to verify:

```bash
./video-manager-ultimate.sh
# Navigate to: Utilities → Display System Information
```

This will show:
- **Platform**: Detected OS type (Linux, macOS, Windows, WSL)
- **Available Tools**: Which optional tools are installed
- **Paths**: Log directory and working directory

---

## Platform-Specific Notes

### macOS
- Uses BSD-style commands (different `stat` syntax)
- `shasum` is built-in, no need to install
- File paths use `/Users/` instead of `/home/`
- Homebrew packages recommended

### Windows (Git Bash)
- Limited to Git Bash command set
- Some tools require manual installation
- Windows paths (C:\) accessible via `/c/`
- Explorer integration works seamlessly

### WSL
- Full Linux compatibility
- Can access Windows drives via `/mnt/c/`, `/mnt/d/`, etc.
- PowerShell integration for Windows features
- Best cross-platform experience

### Linux
- Full native support
- All features available via package managers
- Fastest performance
- Most tested platform

---

## Troubleshooting

### Command Not Found

**Linux/WSL**:
```bash
sudo apt-get install <package-name>
```

**macOS**:
```bash
brew install <package-name>
```

**Windows (Git Bash)**:
Download from official websites and add to PATH

### Permission Denied

```bash
chmod +x video-manager-ultimate.sh
```

### jq Not Found

The script will detect missing `jq` and show installation instructions for your platform.

### Path Issues

**macOS/Linux**:
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Windows**:
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

## Verification

Test that cross-platform features work:

1. **Run the script**:
   ```bash
   ./video-manager-ultimate.sh
   ```

2. **Check platform detection**:
   - Navigate to: `Utilities → Display System Information`
   - Verify "Platform" shows correct OS

3. **Test file operations**:
   - Navigate to: `File Operations`
   - Enable dry run mode
   - Test on a sample directory

4. **Check tool availability**:
   - System Information shows which tools are available
   - Missing tools are clearly marked

---

## Performance Notes

- **Native Linux**: Fastest performance
- **macOS**: Excellent performance with native tools
- **WSL**: Near-native Linux performance
- **Git Bash**: Slightly slower due to emulation layer

---

## Getting Help

- Check detected platform: `Utilities → Display System Information`
- View logs: `~/.video-manager-logs/`
- Report issues: https://github.com/emaag/vmgr/issues

Include your platform information when reporting issues!
