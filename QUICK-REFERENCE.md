# VIDEO MANAGER ULTIMATE - BASH EDITION
## Quick Reference Card

**Version:** 1.0.0 | **Platform:** Linux, WSL, macOS

---

## Installation (One-Time Setup)

```bash
# 1. Make executable
chmod +x video-manager-ultimate.sh

# 2. Move to bin directory (optional)
mv video-manager-ultimate.sh ~/bin/vmgr

# 3. Add to PATH (add to ~/.bashrc)
export PATH="$HOME/bin:$PATH"

# 4. Create alias (add to ~/.bashrc)
alias vmgr='~/bin/vmgr'
```

---

## 🚀 Quick Start

```bash
# Launch interactive menu
./video-manager-ultimate.sh

# OR use alias (if configured)
vmgr
```

---

## 📋 Common Commands

### Always Test First!
```bash
# DRY RUN (safe preview)
vmgr --dry-run rename /mnt/c/Users/Eric/Videos
```

### Rename Files
```bash
# Apply bracket notation
vmgr rename /mnt/c/Users/Eric/Videos

# Example transformations:
# vixen.movie.mp4 → [Vixen] movie.mp4
# tushy - scene.mp4 → [Tushy] scene.mp4
```

### Flatten Directory
```bash
# Move all videos to top level
vmgr flatten /mnt/c/Users/Eric/Videos/NewCollection
```

### Full Cleanup
```bash
# Remove dashes + bracket notation + spacing fixes
vmgr cleanup /mnt/c/Users/Eric/Videos
```

### Find Duplicates
```bash
# Generate report only
vmgr duplicates /mnt/c/Users/Eric/Videos

# Report location:
# _duplicate_report_TIMESTAMP/duplicates.txt
# _duplicate_report_TIMESTAMP/duplicates.csv
```

---

## 🔄 Workflows

### New Collection Setup
```bash
# Flatten + Rename + Find Duplicates
vmgr workflow-new /mnt/c/Users/Eric/Downloads/NewCollection
```

### Deep Clean Existing
```bash
# Comprehensive cleanup of organized collection
vmgr workflow-clean /mnt/c/Users/Eric/Videos/Vixen
```

---

## ⚙️ Command Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --version` | Show version info |
| `-d, --dry-run` | Preview without changes |
| `-q, --quiet` | Minimal output |
| `-i, --interactive` | Launch menu |

---

## 📁 Path Formats

```bash
# Windows path
vmgr rename "C:\Users\Eric\Videos"

# WSL path (converted automatically)
vmgr rename /mnt/c/Users/Eric/Videos

# Linux path
vmgr rename /home/user/Videos
```

---

## 🎯 Interactive Menu Navigation

```
Main Menu
├── [1] Single Operations ← Quick one-time tasks
├── [2] Batch Processing ← Multiple folders
├── [3] Automated Workflows ← Multi-step operations
├── [4] Duplicate Detection ← Find duplicates
├── [5] Utilities ← Logs & diagnostics
└── [6] Settings ← Configure behavior
```

---

## 📊 After Operation

### View Statistics
- Displayed automatically after each operation
- Shows: processed, renamed, moved, skipped, errors

### Check Logs
```bash
# View last 50 entries
tail -n 50 ~/.video-manager-logs/video-manager-*.log

# Search for errors
grep ERROR ~/.video-manager-logs/*.log

# Via menu: Main → Utilities → View Last 50 Log Entries
```

---

## 🎬 Supported Video Formats

```
mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg, 3gp
```

---

## ⚡ Power User Tips

### Batch Multiple Folders
```bash
# Option 1: Interactive
vmgr batch

# Option 2: Script it
for dir in /Videos/*/; do
    vmgr rename "$dir"
done
```

### Test Filename Transformation
```bash
# Launch interactive menu
vmgr
# Navigate to: Utilities → Test Filename Transformation
# Enter any filename to see transformation
```

### Automation (cron)
```bash
# Add to crontab (crontab -e)
# Sunday 2 AM: Clean all collections
0 2 * * 0 /home/user/bin/vmgr workflow-clean /mnt/c/Users/Eric/Videos
```

---

## 🛡️ Best Practices

### Before ANY Operation:
1. ✅ **BACKUP your collection**
2. ✅ **Run with --dry-run first**
3. ✅ **Test on small folder first**

### Safety Checklist:
```bash
# 1. Backup
cp -r /path/to/videos /path/to/videos_BACKUP

# 2. Dry run
vmgr --dry-run rename /path/to/videos

# 3. Review output carefully

# 4. If good, run for real
vmgr rename /path/to/videos

# 5. Verify results
ls /path/to/videos | head -n 20
```

---

## 🐛 Troubleshooting Quick Fixes

### Permission Denied
```bash
chmod -R u+rwX /path/to/directory
```

### Hash Utility Not Found
```bash
# Ubuntu/Debian
sudo apt-get install coreutils
```

### Path Not Found (WSL)
```bash
# Use /mnt/c/ format
vmgr rename /mnt/c/Users/Eric/Videos

# NOT: C:\Users\Eric\Videos
```

### Too Slow
```bash
# Disable verbose output
vmgr --quiet rename /path/to/directory
```

---

## 📞 Quick Help

```bash
# Show help
vmgr --help

# Show version
vmgr --version

# System info (via menu)
vmgr
# Navigate to: Utilities → Display System Information
```

---

## 🔗 Key File Locations

```bash
# Script
~/bin/vmgr

# Logs
~/.video-manager-logs/

# Latest log
ls -t ~/.video-manager-logs/ | head -n 1

# Duplicate reports
# In target directory: _duplicate_report_TIMESTAMP/
```

---

## 💡 Example Workflows

### Download Cleanup
```bash
# After downloading new videos:
vmgr workflow-new ~/Downloads/Videos
```

### Monthly Maintenance
```bash
# Find duplicates
vmgr duplicates /mnt/c/Users/Eric/Videos

# Deep clean formatting
vmgr workflow-clean /mnt/c/Users/Eric/Videos
```

### Organize Old Collection
```bash
# Step 1: Flatten structure
vmgr flatten /mnt/c/Users/Eric/Videos/OldCollection

# Step 2: Standardize names
vmgr rename /mnt/c/Users/Eric/Videos/OldCollection

# Step 3: Find duplicates
vmgr duplicates /mnt/c/Users/Eric/Videos/OldCollection
```

---

## 🎨 Understanding Output Colors

| Color | Meaning |
|-------|---------|
| 🟢 Green | Success, completed |
| 🔵 Blue | Information, processing |
| 🟡 Yellow | Warning, attention needed |
| 🔴 Red | Error, failed operation |
| 🟣 Magenta | Section headers, operations |
| 🔷 Cyan | Details, verbose info |

---

## 📝 Log Entry Levels

| Level | Purpose |
|-------|---------|
| `INFO` | General information |
| `SUCCESS` | Successful operations |
| `WARN` | Non-critical warnings |
| `ERROR` | Errors encountered |
| `OPERATION` | Operation boundaries |
| `RENAME` | File rename operations |
| `MOVE` | File move operations |
| `DRYRUN` | Dry run previews |

---

## ⚠️ Important Reminders

1. 🔥 **Always backup before operations**
2. 🧪 **Always dry run first on large collections**
3. 📊 **Review statistics after operations**
4. 📜 **Check logs for errors**
5. ✅ **Verify a few files manually**

---

## 🌟 One-Liners for Pros

```bash
# Backup, dry run, execute pipeline
cp -r /Videos /Videos_BAK && \
vmgr -d rename /Videos && \
read -p "Continue? " && \
vmgr rename /Videos

# Cleanup all studio folders
for studio in /Videos/*/; do
    vmgr cleanup "$studio"
done

# Find all duplicates across collection
vmgr duplicates /mnt/c/Users/Eric/Videos > dupes.log

# Test transformation without launching menu
echo "vixen.test.mp4" | # Would need script modification for stdin

# Monitor log in real-time (separate terminal)
tail -f ~/.video-manager-logs/video-manager-$(date +%Y%m%d)*.log
```

---

## 📚 Related Commands

```bash
# Count videos
find /Videos -name "*.mp4" | wc -l

# Find videos by name
find /Videos -iname "*vixen*"

# Check disk usage
du -sh /Videos

# List largest files
find /Videos -name "*.mp4" -exec ls -lh {} \; | sort -k5 -hr | head -20

# Verify no corruption (example with one file)
ffmpeg -v error -i "file.mp4" -f null - 2>&1
```

---

**Need More Help?**
- Full guide: `VIDEO-MANAGER-BASH-GUIDE.md`
- Interactive menu: `vmgr` (then navigate to Utilities)
- Logs: `~/.video-manager-logs/`

---

**Video Manager Ultimate - Bash Edition v1.0.0**  
*Making video collection management verbose and beautiful* ✨
