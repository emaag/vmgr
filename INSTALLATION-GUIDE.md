# 🚀 VIDEO MANAGER ULTIMATE - BASH EDITION
## Installation & First Run Guide

**Get started in 5 minutes!**

---

## ✅ Prerequisites Check

Open your terminal and run these commands:

```bash
# Check bash version (need 4.0+)
bash --version
# Should show: GNU bash, version 4.x or higher

# Check for hash utility (need one of these)
which sha256sum || which shasum
# Should show a path like: /usr/bin/sha256sum

# Check for basic utilities
which find sed awk grep
# Should show paths for all
```

✅ **All checks passed?** Continue to installation!  
❌ **Missing something?** See troubleshooting section below.

---

## 📦 Installation Steps

### Step 1: Download & Prepare

You have three files:
- `video-manager-ultimate.sh` - The main script (48 KB)
- `VIDEO-MANAGER-BASH-GUIDE.md` - Complete user guide (28 KB)
- `QUICK-REFERENCE.md` - Quick reference card (7.4 KB)

```bash
# Create a bin directory if you don't have one
mkdir -p ~/bin

# Move the script there
cp video-manager-ultimate.sh ~/bin/vmgr

# Make it executable
chmod +x ~/bin/vmgr

# Move documentation to a safe place
mkdir -p ~/Documents/VideoManager
cp VIDEO-MANAGER-BASH-GUIDE.md ~/Documents/VideoManager/
cp QUICK-REFERENCE.md ~/Documents/VideoManager/
```

### Step 2: Add to PATH (Optional but Recommended)

```bash
# Open your bash configuration
nano ~/.bashrc

# Add these lines at the end:
export PATH="$HOME/bin:$PATH"
alias vmgr='~/bin/vmgr'

# Save and exit (Ctrl+X, then Y, then Enter)

# Reload your configuration
source ~/.bashrc
```

### Step 3: Verify Installation

```bash
# Test the script
vmgr --version
# Should show: Video Manager Ultimate - Bash Edition v1.0.0 (2025-10-19)

# Test with help
vmgr --help
# Should show usage information
```

✅ **Installation complete!**

---

## 🎯 First Run - Interactive Mode

### Launch the Script

```bash
vmgr
```

You'll see a beautiful menu:

```
╔═══════════════════════════════════════════════════════════════╗
║  VIDEO MANAGER ULTIMATE - BASH EDITION                       ║
║  Version 1.0.0 - 2025-10-19                                  ║
╚═══════════════════════════════════════════════════════════════╝

MAIN MENU

[1] Single Operations
[2] Batch Processing
[3] Automated Workflows
[4] Duplicate Detection
[5] Utilities
[6] Settings

[Q] Quit

Select option:
```

### Your First Operation - Test Run

Let's safely test the rename feature:

1. **Press `6`** (Settings)
2. **Press `1`** (Toggle Dry Run Mode - should turn ON)
3. **Press `B`** (Back to Main Menu)
4. **Press `1`** (Single Operations)
5. **Press `1`** (Rename Files)
6. **Enter a test directory path** (e.g., `/mnt/c/Users/Eric/Videos/TestFolder`)
7. **Review the output** - it shows what WOULD be renamed (no actual changes)
8. **Press Enter** to continue

If the dry run results look good:

1. **Press `1`** (Single Operations again)
2. **Press `D`** (Toggle Dry Run - turn it OFF)
3. **Press `1`** (Rename Files)
4. **Enter the same directory**
5. **Changes are now applied!**

---

## 🧪 First Run - Command Line Mode

### Test with a Small Folder

```bash
# Create a test folder with some fake files
mkdir -p ~/vmgr-test
cd ~/vmgr-test
touch vixen.test.movie.mp4
touch tushy.sample.mp4
touch "brazzers - scene - name.mp4"
ls -la
```

### Dry Run Test

```bash
# Preview what would happen
vmgr --dry-run rename ~/vmgr-test
```

Expected output:
```
═══════════════════════════════════════════════════════════════
★ Rename Files (Bracket Notation)
═══════════════════════════════════════════════════════════════

ℹ Scanning directory: /home/user/vmgr-test
ℹ Found 3 video files to process

[DRY RUN] Would rename:
  From: vixen.test.movie.mp4
  To:   [Vixen] test.movie.mp4

[DRY RUN] Would rename:
  From: tushy.sample.mp4
  To:   [Tushy] sample.mp4

[DRY RUN] Would rename:
  From: brazzers - scene - name.mp4
  To:   [Brazzers] scene name.mp4

───────────────────────────────────────────────────────────────
Operation Complete: Rename Files (Bracket Notation)
───────────────────────────────────────────────────────────────

📊 Statistics:
   Files Processed:  3
   Files Renamed:    0
   Files Moved:      0
   Files Skipped:    0

Duration: 0m 2s
═══════════════════════════════════════════════════════════════
```

### Apply Changes

```bash
# If dry run looked good, apply for real
vmgr rename ~/vmgr-test

# Check results
ls -la ~/vmgr-test
```

You should see:
```
[Vixen] test.movie.mp4
[Tushy] sample.mp4
[Brazzers] scene name.mp4
```

✅ **Success! The script is working perfectly.**

---

## 📚 Next Steps

### Option 1: Process Your Real Collection

**⚠️ IMPORTANT: Always backup first!**

```bash
# Backup your collection
cp -r /mnt/c/Users/Eric/Videos /mnt/c/Users/Eric/Videos_BACKUP_$(date +%Y%m%d)

# Test on one studio/folder first
vmgr --dry-run rename /mnt/c/Users/Eric/Videos/Vixen

# If good, apply
vmgr rename /mnt/c/Users/Eric/Videos/Vixen
```

### Option 2: Run a Workflow

```bash
# For new downloads
vmgr workflow-new /mnt/c/Users/Eric/Downloads/NewVideos

# For existing collection cleanup
vmgr workflow-clean /mnt/c/Users/Eric/Videos
```

### Option 3: Find Duplicates

```bash
vmgr duplicates /mnt/c/Users/Eric/Videos
# Report will be in: /mnt/c/Users/Eric/Videos/_duplicate_report_TIMESTAMP/
```

---

## 🔍 Exploring Features

### View System Information

```bash
vmgr
# Select: [5] Utilities → [4] Display System Information
```

Shows:
- Script version
- Bash version
- Operating system
- Available tools
- Configuration

### Test Filename Transformations

```bash
vmgr
# Select: [5] Utilities → [3] Test Filename Transformation
# Enter: "vixen.test.movie.mp4"
```

You'll see each transformation step:
```
Original: vixen.test.movie.mp4
After dash removal: vixen.test.movie.mp4
After bracket notation: [Vixen] test.movie.mp4
After spacing fix: [Vixen] test.movie.mp4
Final result: [Vixen] test.movie.mp4
```

### View Logs

```bash
# Via menu
vmgr
# Select: [5] Utilities → [1] View Last 50 Log Entries

# Via command line
cat ~/.video-manager-logs/video-manager-*.log | tail -n 50
```

---

## 🎓 Learn the Workflows

### Workflow: New Collection Setup

**Use when:** You download a new collection or torrent

```bash
vmgr workflow-new /path/to/new/collection
```

This will:
1. Flatten directory structure (move all videos to top)
2. Apply standardized bracket notation
3. Find and report duplicates

### Workflow: Deep Clean

**Use when:** Cleaning up an existing organized collection

```bash
vmgr workflow-clean /path/to/existing/collection
```

This will:
1. Remove dash patterns ` - `
2. Fix bracket spacing `]word` → `] word`
3. Apply bracket notation consistently

---

## 📖 Documentation Quick Links

### Complete User Guide
- Location: `~/Documents/VideoManager/VIDEO-MANAGER-BASH-GUIDE.md`
- 28 KB, ~100 pages equivalent
- Comprehensive reference for all features

### Quick Reference
- Location: `~/Documents/VideoManager/QUICK-REFERENCE.md`
- 7.4 KB, one-page cheat sheet
- Perfect for printing or quick lookups

### Help Command
```bash
vmgr --help
# Shows concise usage information
```

---

## ⚙️ Configuration

### Enable/Disable Verbose Output

**Via Menu:**
```bash
vmgr
# [6] Settings → [2] Toggle Verbose Output
```

**Via CLI:**
```bash
# Quiet mode (minimal output)
vmgr --quiet rename /path/to/directory
```

### Dry Run Mode

**Via Menu:**
```bash
vmgr
# [6] Settings → [1] Toggle Dry Run Mode
```

**Via CLI:**
```bash
# Always use --dry-run for testing
vmgr --dry-run rename /path/to/directory
```

### Supported Extensions

**Via Menu:**
```bash
vmgr
# [6] Settings → [3] View Supported Extensions
```

**Currently supported:**
mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg, 3gp

**To add more:** Edit line 67 in `video-manager-ultimate.sh`:
```bash
DEFAULT_VIDEO_EXTENSIONS=("mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "3gp" "ts" "m2ts")
```

---

## 🔧 Troubleshooting Installation

### Issue: "bash --version shows 3.x"

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install bash

# macOS
brew install bash
# Then add to /etc/shells and change default shell
```

### Issue: "sha256sum not found"

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install coreutils

# macOS (use shasum instead, should be built-in)
which shasum
# If not found:
brew install coreutils
```

### Issue: "Permission denied when running script"

**Solution:**
```bash
# Make executable
chmod +x ~/bin/vmgr

# Or run with bash explicitly
bash ~/bin/vmgr
```

### Issue: "Command not found: vmgr"

**Solution:**
```bash
# Check if bin is in PATH
echo $PATH | grep -o "$HOME/bin"

# If empty, add to PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Or use full path
~/bin/vmgr
```

### Issue: "Cannot access /mnt/c/ paths (WSL)"

**Solution:**
```bash
# Check if Windows drives are mounted
ls /mnt/c/

# If not mounted, check WSL configuration
cat /etc/wsl.conf

# Should contain:
# [automount]
# enabled = true
# root = /mnt/

# Restart WSL if needed
wsl.exe --shutdown
# Then reopen terminal
```

---

## 💡 Tips for Success

1. **Start Small**
   - Test on 10-20 files first
   - Verify results match expectations
   - Then scale to entire collection

2. **Always Dry Run**
   - Use `--dry-run` for every new operation
   - Review output carefully
   - Look for unexpected transformations

3. **Backup Everything**
   - Before processing large collections
   - Keep backups for at least a week
   - Test restore process once

4. **Check Logs Regularly**
   - Review after each major operation
   - Look for patterns in errors
   - Use logs to troubleshoot issues

5. **Use Interactive Mode for Learning**
   - Menu system teaches you features
   - Visual feedback helps understanding
   - Switch to CLI once comfortable

---

## 🎯 Common First Tasks

### Task 1: Rename One Studio Folder
```bash
# Backup
cp -r /Videos/Vixen /Videos/Vixen_BAK

# Test
vmgr --dry-run rename /Videos/Vixen

# Apply
vmgr rename /Videos/Vixen

# Verify
ls /Videos/Vixen | head -n 10
```

### Task 2: Flatten Downloaded Collection
```bash
vmgr flatten /Downloads/NewVideoCollection
```

### Task 3: Find Duplicates Across Collection
```bash
vmgr duplicates /mnt/c/Users/Eric/Videos
# Check report: /Videos/_duplicate_report_TIMESTAMP/
```

### Task 4: Monthly Cleanup
```bash
vmgr workflow-clean /mnt/c/Users/Eric/Videos
```

---

## 🚀 Advanced: Automation Setup

### Schedule Monthly Cleanup

```bash
# Edit crontab
crontab -e

# Add this line (runs first Sunday of month at 2 AM)
0 2 1-7 * 0 /home/user/bin/vmgr workflow-clean /mnt/c/Users/Eric/Videos
```

### Post-Download Script

```bash
# Create ~/bin/process-downloads.sh
#!/bin/bash
DOWNLOAD_DIR="/home/user/Downloads/Videos"
TARGET_DIR="/mnt/c/Users/Eric/Videos"

# Process new downloads
/home/user/bin/vmgr workflow-new "$DOWNLOAD_DIR"

# Move to main collection
mv "$DOWNLOAD_DIR"/* "$TARGET_DIR"/

# Cleanup
rmdir "$DOWNLOAD_DIR"
```

---

## 📞 Getting Help

### In the Script
```bash
vmgr
# [5] Utilities → [1] View Last 50 Log Entries
# [5] Utilities → [4] Display System Information
```

### Command Line
```bash
vmgr --help
vmgr --version
```

### Documentation
- Full Guide: `~/Documents/VideoManager/VIDEO-MANAGER-BASH-GUIDE.md`
- Quick Ref: `~/Documents/VideoManager/QUICK-REFERENCE.md`

### Logs
```bash
# View logs
tail -n 100 ~/.video-manager-logs/video-manager-*.log

# Search for errors
grep ERROR ~/.video-manager-logs/*.log

# Open log directory
cd ~/.video-manager-logs/
ls -lth
```

---

## ✅ Installation Checklist

- [ ] Bash 4.0+ installed
- [ ] sha256sum or shasum available
- [ ] Script copied to `~/bin/vmgr`
- [ ] Script is executable (`chmod +x`)
- [ ] PATH updated (optional)
- [ ] Alias created (optional)
- [ ] Documentation saved
- [ ] Test run completed successfully
- [ ] Logs directory created (`~/.video-manager-logs/`)
- [ ] First real operation performed
- [ ] Backup strategy in place

---

## 🎉 You're Ready!

You now have a powerful, ultra-verbose video management system at your fingertips!

**Quick Commands to Remember:**
```bash
vmgr                    # Interactive menu
vmgr --dry-run rename   # Safe testing
vmgr duplicates         # Find duplicates
vmgr workflow-new       # Setup new collection
vmgr --help             # Show help
```

**Next Steps:**
1. Process your first real folder
2. Explore the interactive menu
3. Set up automation (optional)
4. Share with friends! 😊

---

**Welcome to Video Manager Ultimate - Bash Edition!**  
*Making video management verbose, safe, and beautiful.* ✨

**Version:** 1.0.0  
**Created:** October 19, 2025  
**Author:** Built for Eric's Video Management System

---

*Happy organizing! 🎬*
