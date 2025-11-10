# Video Manager Ultimate - WSL Setup & Installation Guide

## Version 1.0.0

Complete guide for setting up and optimizing Video Manager Ultimate on Windows Subsystem for Linux (WSL).

---

## Table of Contents

1. [Why Use WSL?](#why-use-wsl)
2. [Installing WSL](#installing-wsl)
3. [Migrating to WSL](#migrating-to-wsl)
4. [Performance Optimization](#performance-optimization)
5. [Path Management](#path-management)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Configuration](#advanced-configuration)

---

## Why Use WSL?

### Advantages of WSL for Video Manager

- **Native Bash Support** - Full bash 4.0+ features without compatibility issues
- **Better Performance** - Faster file operations on WSL filesystem
- **Linux Tools** - Access to complete Linux ecosystem (ffmpeg, whisper, etc.)
- **Windows Integration** - Seamless access to Windows files and applications
- **Modern Tooling** - Latest versions of all dependencies via apt
- **Cross-Platform** - Same commands work on Linux servers and WSL

### WSL 1 vs WSL 2

| Feature | WSL 1 | WSL 2 | Recommended |
|---------|-------|-------|-------------|
| File System Performance (Linux) | Good | **Excellent** | WSL 2 |
| File System Performance (Windows) | **Good** | Slower | WSL 1 for /mnt access |
| Memory Usage | Low | Higher | WSL 2 (configurable) |
| Docker Support | No | **Yes** | WSL 2 |
| Full System Call Compatibility | Partial | **Full** | WSL 2 |

**Recommendation:** Use **WSL 2** for best overall experience. Store frequently accessed files in WSL filesystem for optimal performance.

---

## Installing WSL

### Quick Install (Windows 10 version 2004+ or Windows 11)

1. **Open PowerShell as Administrator**
   ```powershell
   wsl --install
   ```

2. **Restart your computer**

3. **Launch Ubuntu** (or your preferred distribution)
   - Set username and password when prompted
   - This creates your Linux user account

### Manual Install (Older Windows 10 Versions)

1. **Enable WSL Feature**
   ```powershell
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   ```

2. **Enable Virtual Machine Platform**
   ```powershell
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```

3. **Restart your computer**

4. **Download and Install WSL2 Linux Kernel**
   - https://aka.ms/wsl2kernel

5. **Set WSL 2 as Default**
   ```powershell
   wsl --set-default-version 2
   ```

6. **Install Ubuntu from Microsoft Store**
   - Search for "Ubuntu" in Microsoft Store
   - Click "Get" to install

### Verify Installation

```bash
# Check WSL version
wsl --list --verbose

# Check Linux distribution
cat /etc/os-release

# Check if running in WSL
grep -i microsoft /proc/version
```

---

## Migrating to WSL

### Option 1: Automated Migration Script

We provide an automated migration script that handles everything:

```bash
# From WSL, download and run the migration script
cd ~
curl -O https://raw.githubusercontent.com/emaag/vmgr/main/migrate-to-wsl.sh
chmod +x migrate-to-wsl.sh
./migrate-to-wsl.sh
```

The script will:
- ✅ Detect existing Windows installations
- ✅ Copy or clone the repository
- ✅ Migrate configuration and logs
- ✅ Install dependencies
- ✅ Set up symlinks and PATH
- ✅ Configure WSL optimization settings

### Option 2: Manual Migration

#### Step 1: Install Git in WSL

```bash
sudo apt update
sudo apt install -y git
```

#### Step 2: Clone Repository

```bash
# Clone to your home directory
cd ~
git clone https://github.com/emaag/vmgr.git
cd vmgr
```

#### Step 3: Install Dependencies

```bash
# Update package lists
sudo apt update

# Install required packages
sudo apt install -y \
    jq \
    ffmpeg \
    libimage-exiftool-perl \
    imagemagick \
    bc \
    curl

# Optional: Install Whisper for subtitle generation
pip install -U openai-whisper
```

#### Step 4: Run Installation Script

```bash
chmod +x install.sh
./install.sh
```

#### Step 5: Reload Shell

```bash
source ~/.bashrc
```

#### Step 6: Verify Installation

```bash
vmgr --version
```

### Migrating Configuration and Logs

If you had Video Manager installed on Windows, migrate your settings:

```bash
# Migrate logs from Windows user directory
cp -r /mnt/c/Users/YOUR_USERNAME/.video-manager-logs ~/.video-manager-logs

# Verify migration
ls -la ~/.video-manager-logs
```

---

## Performance Optimization

### File System Performance

**Critical:** WSL 2 has different performance characteristics for Linux vs Windows filesystems.

| Operation | Linux Filesystem (~/...) | Windows Filesystem (/mnt/c/...) |
|-----------|-------------------------|--------------------------------|
| Read Speed | ⚡ **Excellent** | 🐌 Slower |
| Write Speed | ⚡ **Excellent** | 🐌 Much Slower |
| Metadata Operations | ⚡ **Excellent** | 🐌 Very Slow |
| **Recommendation** | ✅ Use for processing | ❌ Avoid for large operations |

### Best Practices for Performance

#### 1. **Store Working Files in WSL Filesystem**

```bash
# ✅ GOOD: Copy to WSL filesystem first
cp -r /mnt/c/Users/Eric/Videos ~/Videos
vmgr rename ~/Videos

# ❌ BAD: Process directly on Windows filesystem
vmgr rename /mnt/c/Users/Eric/Videos
```

#### 2. **Use rsync for Large Transfers**

```bash
# Fast transfer with progress
rsync -avh --progress /mnt/c/Users/Eric/Videos/ ~/Videos/

# Copy back when done
rsync -avh --progress ~/Videos/ /mnt/c/Users/Eric/Videos/
```

#### 3. **Configure WSL Memory and CPU**

Create or edit `C:\Users\YOUR_USERNAME\.wslconfig`:

```ini
[wsl2]
# Limit memory (recommended: 50-75% of total RAM)
memory=8GB

# Limit processors (recommended: 75% of cores)
processors=6

# Swap size
swap=4GB

# Disable page reporting (can improve performance)
pageReporting=false

# Increase network packet size
localhostForwarding=true
```

Apply changes:
```powershell
# In PowerShell
wsl --shutdown
# Then restart WSL
```

#### 4. **Disable Windows Defender for WSL Filesystem**

Add exclusions in Windows Security:
- Path: `%LOCALAPPDATA%\Packages\CanonicalGroupLimited.Ubuntu*`
- This significantly improves I/O performance

### Performance Monitoring

```bash
# Check WSL resource usage
# In PowerShell:
wsl --status

# In WSL, monitor disk I/O
iostat -x 1

# Check file system type
df -Th
```

---

## Path Management

### Understanding WSL Paths

#### Windows Drives in WSL

Windows drives are mounted at `/mnt/`:

```bash
# C: drive
/mnt/c/Users/Eric/Videos

# D: drive
/mnt/d/Backup

# Network drives (if mapped)
/mnt/x/SharedVideos
```

#### WSL Home Directory in Windows

Access WSL filesystem from Windows:

```
\\wsl$\Ubuntu\home\yourusername\

# Example in File Explorer
\\wsl$\Ubuntu\home\eric\Videos
```

### Path Conversion

Video Manager Ultimate automatically handles path conversion:

```bash
# All these work:
vmgr rename /mnt/c/Users/Eric/Videos
vmgr rename C:\Users\Eric\Videos
vmgr rename ~/Videos
```

### Manual Path Conversion

```bash
# Convert Windows path to WSL path
wslpath -u "C:\Users\Eric\Videos"
# Output: /mnt/c/Users/Eric/Videos

# Convert WSL path to Windows path
wslpath -w ~/Videos
# Output: \\wsl$\Ubuntu\home\eric\Videos

# Open current directory in Windows Explorer
explorer.exe .

# Open specific directory
explorer.exe $(wslpath -w ~/Videos)
```

### Path Best Practices

1. **Use absolute paths for scripts**
   ```bash
   vmgr rename /mnt/c/Users/Eric/Videos
   ```

2. **Use ~ for WSL home directory**
   ```bash
   vmgr rename ~/Videos
   ```

3. **Avoid spaces in paths** (or quote them)
   ```bash
   vmgr rename "/mnt/c/Users/Eric/My Videos"
   ```

---

## Best Practices

### 1. Workflow Optimization

#### Recommended Workflow for Large Operations

```bash
# 1. Copy files to WSL filesystem
rsync -avh --progress /mnt/c/Users/Eric/Videos/ ~/Videos/

# 2. Process in WSL
cd ~/Videos
vmgr workflow-clean .

# 3. Verify results
ls -lah

# 4. Copy back to Windows
rsync -avh --progress ~/Videos/ /mnt/c/Users/Eric/Videos/
```

#### Quick Operations on Windows Filesystem

For small operations, you can work directly on Windows filesystem:

```bash
# Preview changes (dry run is fast)
vmgr --dry-run rename /mnt/c/Users/Eric/Videos/NewFolder

# Apply if satisfied
vmgr rename /mnt/c/Users/Eric/Videos/NewFolder
```

### 2. Backup Strategy

```bash
# Backup before major operations
cp -r ~/Videos ~/Videos_backup_$(date +%Y%m%d)

# Or use rsync to Windows backup location
rsync -avh ~/Videos/ /mnt/d/Backup/Videos_$(date +%Y%m%d)/
```

### 3. Scheduling Tasks

Use cron in WSL:

```bash
# Edit crontab
crontab -e

# Example: Weekly cleanup every Sunday at 2 AM
0 2 * * 0 /home/eric/bin/vmgr workflow-clean ~/Videos

# Example: Daily log cleanup
0 3 * * * find ~/.video-manager-logs -name "*.log" -mtime +30 -delete
```

### 4. Accessing Windows Applications

```bash
# Open video in Windows default player
cmd.exe /c start "$(wslpath -w ~/Videos/movie.mp4)"

# Open directory in Windows Explorer
explorer.exe $(wslpath -w ~/Videos)

# Run Windows applications
notepad.exe $(wslpath -w ~/Videos/notes.txt)
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Cannot access /mnt/c/"

**Cause:** Drive mounting failed

**Solution:**
```bash
# Check mounted drives
mount | grep mnt

# Remount if needed
sudo mkdir -p /mnt/c
sudo mount -t drvfs C: /mnt/c

# Or restart WSL
# In PowerShell:
wsl --shutdown
```

#### Issue: Very slow file operations on /mnt/c/

**Cause:** This is expected WSL 2 behavior

**Solutions:**
1. Copy files to WSL filesystem first (best)
2. Use WSL 1 for this specific distribution
3. Configure Windows Defender exclusions

```bash
# Convert to WSL 1 (if needed)
# In PowerShell:
wsl --set-version Ubuntu 1

# Convert back to WSL 2
wsl --set-version Ubuntu 2
```

#### Issue: Permission denied errors

**Cause:** Windows NTFS permissions

**Solution:**
```bash
# Option 1: Run with sudo (not recommended)
sudo vmgr rename /mnt/c/Users/Eric/Videos

# Option 2: Fix ownership
sudo chown -R $USER:$USER /mnt/c/Users/Eric/Videos

# Option 3: Copy to WSL filesystem
cp -r /mnt/c/Users/Eric/Videos ~/Videos
vmgr rename ~/Videos
```

#### Issue: WSL out of memory

**Cause:** WSL using too much RAM

**Solution:**
```powershell
# In PowerShell, shutdown WSL
wsl --shutdown

# Create .wslconfig with memory limit (see above)

# Restart WSL
wsl
```

#### Issue: Can't find vmgr command

**Cause:** PATH not updated

**Solution:**
```bash
# Reload bashrc
source ~/.bashrc

# Check if ~/bin is in PATH
echo $PATH | grep "$HOME/bin"

# If not, add it
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Issue: Whisper/ffmpeg not found

**Cause:** Dependencies not installed

**Solution:**
```bash
# Install system packages
sudo apt update
sudo apt install -y ffmpeg libimage-exiftool-perl

# Install Whisper
pip install -U openai-whisper

# Or use apt if available
sudo apt install -y python3-pip
pip3 install -U openai-whisper
```

---

## Advanced Configuration

### Accessing WSL from Windows

#### Method 1: Network Path

```
\\wsl$\Ubuntu\home\yourusername\vmgr
```

Map as network drive in File Explorer:
1. Right-click "This PC"
2. Choose "Map network drive"
3. Enter: `\\wsl$\Ubuntu\home\yourusername`

#### Method 2: Windows Terminal

Install Windows Terminal for better experience:
- Download from Microsoft Store
- Supports tabs, themes, and better rendering
- Automatically detects WSL installations

### Git Configuration for Windows/WSL

```bash
# Set up git credentials (shared with Windows)
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/libexec/git-core/git-credential-manager-core.exe"

# Or use WSL-specific credentials
git config --global credential.helper store
```

### File Permission Metadata

WSL can preserve Windows file permissions:

```bash
# Add to /etc/wsl.conf
sudo tee /etc/wsl.conf <<EOF
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[network]
generateResolvConf = true

[interop]
enabled = true
appendWindowsPath = true
EOF

# Restart WSL
# In PowerShell:
wsl --shutdown
```

### Optimizing for Video Work

```bash
# Install additional video tools
sudo apt install -y \
    mediainfo \
    mkvtoolnix \
    handbrake-cli \
    youtube-dl

# Install GPU-accelerated ffmpeg (if available)
sudo apt install -y ffmpeg-nvidia

# Check hardware acceleration
ffmpeg -hwaccels
```

### Network Shares

Access Windows network shares:

```bash
# Mount network share
sudo mkdir -p /mnt/share
sudo mount -t drvfs '\\server\share' /mnt/share

# Add to /etc/fstab for persistent mount
echo '\\server\share /mnt/share drvfs defaults 0 0' | sudo tee -a /etc/fstab
```

---

## Quick Reference

### Essential Commands

```bash
# Start WSL
wsl

# Shutdown WSL
wsl --shutdown

# List distributions
wsl --list --verbose

# Set default distribution
wsl --set-default Ubuntu

# Run command in WSL from Windows
wsl vmgr --version

# Access WSL files from Windows
explorer.exe .

# Convert paths
wslpath -u "C:\path"      # Windows → WSL
wslpath -w /mnt/c/path    # WSL → Windows
```

### Video Manager in WSL

```bash
# Interactive mode
vmgr

# Process Windows files
vmgr rename /mnt/c/Users/Eric/Videos

# Process WSL files (faster)
vmgr rename ~/Videos

# Open results in Windows Explorer
explorer.exe $(wslpath -w ~/Videos)
```

---

## Resources

### Official Documentation

- **WSL Documentation:** https://docs.microsoft.com/en-us/windows/wsl/
- **WSL Best Practices:** https://docs.microsoft.com/en-us/windows/wsl/best-practices
- **File System Performance:** https://docs.microsoft.com/en-us/windows/wsl/filesystems

### Video Manager Documentation

- **README.md** - Overview and features
- **INSTALLATION-GUIDE.md** - Detailed installation instructions
- **VIDEO-MANAGER-BASH-GUIDE.md** - Complete feature guide
- **QUICK-REFERENCE.md** - Command cheat sheet

### Community and Support

- **GitHub Issues:** https://github.com/emaag/vmgr/issues
- **WSL GitHub:** https://github.com/microsoft/WSL

---

## Summary Checklist

- [ ] WSL 2 installed and running
- [ ] Ubuntu (or preferred distro) installed
- [ ] Video Manager cloned/migrated to WSL
- [ ] Dependencies installed (jq, ffmpeg, etc.)
- [ ] vmgr command available in PATH
- [ ] .wslconfig created with memory limits
- [ ] Windows Defender exclusions configured
- [ ] Test run completed successfully
- [ ] Understand Windows vs WSL filesystem performance
- [ ] Backup strategy established

---

**Congratulations!** You're now ready to use Video Manager Ultimate on WSL with optimal performance.

For support, consult the troubleshooting section above or open an issue on GitHub.

**Happy video organizing!** 🎬
