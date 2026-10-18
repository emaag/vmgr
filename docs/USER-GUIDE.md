# VIDEO MANAGER ULTIMATE - BASH EDITION
## Complete User Guide

**Version:** 1.6.0  
**Date:** October 2026  
**Complements:** PowerShell Ultimate Edition

---

## Table of Contents

1. [Overview](#overview)
2. [Installation & Setup](#installation--setup)
3. [Quick Start](#quick-start)
4. [Usage Modes](#usage-modes)
5. [Features Reference](#features-reference)
6. [Interactive Menu Guide](#interactive-menu-guide)
7. [Command Line Reference](#command-line-reference)
8. [Workflows](#workflows)
9. [Logging System](#logging-system)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

---

## Overview

Video Manager Ultimate - Bash Edition is a video file management system for Linux, macOS, WSL (Windows Subsystem for Linux) and Git Bash. It renames and organizes video collections, finds duplicates, generates subtitles with Whisper, catalogs your drives, and downloads from Reddit, with a dry-run preview and an undo log behind every change it makes to your files. It complements the PowerShell Ultimate Edition by providing bash-native features.

### Key Features

✅ **Interactive Menus** - single-key menus, a directory browser with a live preview, progress bars and a summary after every operation  
✅ **Command-Line Mode** - every operation is scriptable; quiet by default, `--verbose` for every step  
✅ **Dry Run First** - preview any operation, then apply it  
✅ **Undo** - renames, dash/spacing fixes, flattening and organize runs are logged and can be put back  
✅ **Duplicate Trash** - deleted duplicates go to an undoable trash; Empty Trash deletes them for good  
✅ **Duplicate Detection** - SHA-256 exact matching, per folder or across every drive in the catalog  
✅ **Bracket Notation & Cleanup** - standardized `[Studio] filename.ext`, dash removal, spacing fixes, flattening  
✅ **Batch Processing** - queue many folders (or every subfolder with videos), with a per-folder results list  
✅ **Subtitle Generation** - OpenAI Whisper, with filler cleanup and "no speech" detection  
✅ **Multi-Drive Catalog** - incremental scans, search that works for unplugged drives, duplicates across drives  
✅ **Reddit Downloader** - images, videos and (with the API) galleries, with a guided API setup  
✅ **Comprehensive Logging** - a timestamped audit trail of everything the tool does  
✅ **Cross-Platform** - Linux, macOS, WSL and Git Bash, with Windows or Unix paths  

### Supported Video Formats

- MP4, MKV, AVI, MOV, WMV
- FLV, WebM, M4V, MPG, MPEG, 3GP

---

## Installation & Setup

### Prerequisites

1. **Bash 4.0+** (Check with: `bash --version`)
2. **Basic Unix utilities** (find, sed, awk, grep)
3. **Hash utility** (sha256sum or shasum)
4. **Optional:** ffprobe (for advanced duplicate detection)

### Installation Steps

1. **Download the script:**
   ```bash
   # Place in your home directory or preferred location
   cp video-manager-ultimate.sh ~/bin/
   ```

2. **Make it executable:**
   ```bash
   chmod +x ~/bin/video-manager-ultimate.sh
   ```

3. **Optional: Add to PATH**
   ```bash
   # Add to ~/.bashrc or ~/.bash_profile
   export PATH="$HOME/bin:$PATH"
   
   # Create alias for easy access
   alias vmgr='~/bin/video-manager-ultimate.sh'
   ```

4. **Test installation:**
   ```bash
   ~/bin/video-manager-ultimate.sh --version
   ```

### First Run

On first run, the script will:
- Create log directory at `~/.video-manager-logs/`
- Initialize logging system
- Display the interactive menu (if no arguments provided)

---

## Quick Start

### Interactive Mode (Recommended for Beginners)

```bash
# Launch interactive menu
./video-manager-ultimate.sh
```

Press a single key to choose (no Enter needed; `Esc` goes back). A typical rename looks like this:
1. Press `1` (File Operations), then `D` to turn **Dry run** on (the header shows it).
2. Press `1` (Rename Files). The directory browser opens: arrows to move, `→` to open a folder, `S` to choose the folder you are in, `T` to type a path.
3. Read the preview (`○ old name` / `→ [New] name`) and the summary card. Nothing has changed yet.
4. Answer `y` to "Apply these changes?" and `y` to "Proceed?". The files are renamed and the summary says how many changes were recorded.
5. Changed your mind? **Utilities → Undo Last Operation** puts every file back.

### Command Line Mode (For Automation)

```bash
# Dry run first (safe!)
./video-manager-ultimate.sh --dry-run rename /mnt/c/Users/Eric/Videos

# Apply changes
./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos

# Find duplicates
./video-manager-ultimate.sh duplicates /mnt/c/Users/Eric/Videos
```

---

## Usage Modes

### 1. Interactive Menu (Default)

**Launch:** Run script without arguments or with `-i` flag

```bash
./video-manager-ultimate.sh
# or
./video-manager-ultimate.sh --interactive
```

**Features:**
- No command memorization needed
- Visual feedback at every step
- Built-in help text
- Statistics after each operation
- Settings can be toggled on-the-fly

**Best For:**
- First-time users
- Infrequent operations
- Testing new features
- Visual confirmation needed

---

### 2. Command Line Interface

**Launch:** Run script with specific command and options

```bash
./video-manager-ultimate.sh [OPTIONS] [COMMAND] [DIRECTORY]
```

**Features:**
- Fast execution
- Scriptable/automatable
- Perfect for cron jobs
- Batch operations
- CI/CD integration

**Best For:**
- Experienced users
- Automation scripts
- Scheduled tasks
- Bulk processing
- Remote execution

---

## Features Reference

### 1. Bracket Notation Renaming

Standardizes filenames by extracting the studio/brand name and wrapping it in brackets.

**Examples:**
```
vixen.24.12.25.jia.lissa.mp4          → [Vixen] 24.12.25.jia.lissa.mp4
tushy - raw - something.mp4           → [Tushy] raw something.mp4
MetArt.Anna.Something.mp4             → [MetArt] Anna.Something.mp4
brazzers_cool_scene.mp4               → [Brazzers] cool scene.mp4
```

**Process:**
1. Extracts first word (alphanumeric + underscore)
2. Capitalizes first letter
3. Wraps in brackets `[Studio]`
4. Preserves remaining filename
5. Maintains file extension

**Verbose Output:**
```
ℹ Processing: vixen.24.12.25.jia.lissa.mp4
  After dash removal: vixen.24.12.25.jia.lissa.mp4
  After bracket notation: [Vixen] 24.12.25.jia.lissa.mp4
  After spacing fix: [Vixen] 24.12.25.jia.lissa.mp4
✓ Renamed:
  From: vixen.24.12.25.jia.lissa.mp4
  To:   [Vixen] 24.12.25.jia.lissa.mp4
```

---

### 2. Dash Pattern Removal

Removes all instances of ` - ` (space-dash-space) from filenames.

**Examples:**
```
Tushy - Raw - 2024.mp4      → Tushy Raw 2024.mp4
Studio - Scene - Name.mkv   → Studio Scene Name.mkv
```

**Use Cases:**
- Cleaning up downloaded files
- Standardizing separator patterns
- Preparing for bracket notation

---

### 3. Bracket Spacing Fix

Ensures proper spacing after closing brackets.

**Examples:**
```
[Vixen]Scene.mp4        → [Vixen] Scene.mp4
[Tushy]Something.mkv    → [Tushy] Something.mkv
```

**Use Cases:**
- Fixing malformed bracket notation
- Post-processing bulk renames
- Improving visual consistency

---

### 4. Directory Flattening

Moves all video files from subdirectories to a single top-level directory.

**Before:**
```
/Videos/
├── Folder1/
│   ├── video1.mp4
│   └── Subfolder/
│       └── video2.mp4
└── Folder2/
    └── video3.mp4
```

**After:**
```
/Videos/
├── video1.mp4
├── video2.mp4
└── video3.mp4
```

**Features:**
- Automatic conflict resolution
- Preserves all files
- Detects possible duplicates (same size)
- Appends counter for conflicts: `video(1).mp4`

**Verbose Output:**
```
ℹ Found: /Videos/Folder1/video1.mp4
→ Moved: video1.mp4 → /Videos/video1.mp4

⚠ Possible duplicate (same size): video2.mp4
  Source: /Videos/Folder1/Subfolder/video2.mp4 (1234567 bytes)
  Target: /Videos/video2.mp4 (1234567 bytes)
```

---

### 5. Duplicate Detection

Identifies exact duplicates using SHA-256 cryptographic hashing.

**Features:**
- Hash-based exact matching (100% accurate)
- Groups duplicates by hash and shows the wasted space
- Scans are sorted, so the copy that is **kept** is always the first one alphabetically
- Text and CSV reports, written to the logs folder (not into the folder you scanned)
- Optional removal: **duplicates are moved to a hidden `.vmgr-trash` folder, not deleted**, so they can be put back (see *Undo and Trash* below)

**Output:**
- **Text Report:** `~/.video-manager-logs/duplicate-reports/FOLDER_TIMESTAMP/duplicates.txt`
- **CSV Export:** `~/.video-manager-logs/duplicate-reports/FOLDER_TIMESTAMP/duplicates.csv`

**What you see:**
```
  Group 1  · 3 copies · 500MiB each
    ✓ keep  movie.mp4
    ✗ extra Backup/movie.mp4
    ✗ extra Old/movie.mp4
✓ Moved to trash: Backup/movie.mp4
✓ Moved to trash: Old/movie.mp4

╭─ ✓ Complete ──────────────────────────────────────────────╮
│ Find and Delete Duplicates                          0m 41s │
│ Moved to trash                                           2 │
│ To reclaim (empty trash)                           1000MiB │
╰────────────────────────────────────────────────────────────╯
  Undo: 2 change(s) recorded. Utilities > Undo Last Operation puts them back.
```

The text report lists each group with its hash, size, the kept original and the duplicates. Paths in the on-screen groups are
relative to the folder you scanned.

---

### 6. Batch Processing

Run one operation over several folders in a single session. Reach it from **File Operations > [7] Batch
Processing**, or run `vmgr batch` from the command line.

**Building the folder list** (a queue screen with live video counts):

| Key | Action |
|-----|--------|
| `A` | Add a folder using the directory browser |
| `S` | Pick a parent folder and add **every subfolder that contains videos** (handy for `Season 1`, `Season 2`, ...) |
| `T` | Type a path |
| `X` | Remove one entry by number |
| `C` | Clear the list |
| `Enter` | Run |
| `Q` / `Esc` | Cancel (nothing runs) |

**Running it**
- With **Dry run on**, it previews every folder first, then asks whether to apply the changes.
- With dry run off it asks for confirmation (it tells you how many folders and videos will change) before touching files.
- Each folder gets a header with an overall progress bar, and the run ends with a per-folder **Results** list
  (`✓ Alpha  2 renamed`) followed by the usual summary card.
- A folder that cannot be found is marked failed; the rest still run.
- When input is piped (not a terminal), it reads one directory per line (empty line to finish) and runs without prompting.

---

### 7. Dry Run Mode

Preview all operations without making any changes.

**Enable:**
- **Interactive:** press `D` in File Operations, or Settings > Toggle Dry Run
- **CLI:** Use `--dry-run` or `-d` flag

**Output:**
```
[DRY RUN] Would rename:
  From: vixen.movie.mp4
  To:   [Vixen] movie.mp4

[DRY RUN] Would move: /Videos/Sub/movie.mp4 → /Videos/movie.mp4
```

**Best Practices:**
- Always dry run first for large operations
- Review output carefully
- Check for unexpected transformations
- Verify conflict resolutions

---

### 8. Undo and Trash

**What is recorded.** Rename Files, Remove Dashes, Fix Bracket Spacing, Flatten, "organize by subfolder", the batch versions of
these, duplicate removal and the catalog's "move duplicates to trash" write an **undo log** as they work: one log per operation
(a batch is one operation), listing every `original path | new path`. Logs live in `~/.video-manager-logs/undo-history/`. When an
operation ends the summary tells you how many changes were recorded.

**Putting things back.** *Utilities → Undo Last Operation* moves every file of the most recent operation back (asking first, and
previewing when Dry run is on). *Utilities → List Undo Operations* shows each operation by name, date and file count, and
`--undo-organize <ID>` undoes a specific one. Undo never overwrites: a file whose old name has been taken since is skipped.

**The trash.** Removing duplicates moves the extra copies into a hidden `.vmgr-trash/<timestamp>/` folder inside the folder you
scanned (on the same drive, so it is instant even for large videos), keeping each file's relative path. Every scan the tool runs
(duplicates, flatten, image conversion, subtitles, organize, the catalog) skips `.vmgr-trash`. *Utilities → Empty Trash* (or
`--empty-trash`) lists each trash with its size, asks, and then deletes for good; the undo logs that pointed into it are retired.

**Limits.** Image conversion is not undoable. If you switch **Settings → Granular Controls → Undo System** off, nothing is recorded
and duplicates are deleted permanently (with a typed `yes`). Undo restores files to their places but does not re-add them to the
catalog: rescan the drive.

---

## Interactive Menu Guide

### Main Menu

```
╭──────────────────────────────────────────────────────────────╮
│ VIDEO MANAGER ULTIMATE                                v1.6.0 │
│ ○ Dry run OFF                             ~/Videos/Series    │
╰──────────────────────────────────────────────────────────────╯

  ▍ MAIN MENU

   1   File Operations            Rename, organize, flatten
   2   Subtitle Generation        Generate, edit, translate
   3   Duplicate Detection        Find and remove duplicates
   4   Multi-Drive Catalog        Scan drives, search media
   5   Utilities                  Logs, system info, testing
   6   Settings                   Options and preferences
   7   Reddit Downloader          Images from a subreddit

   Q   Quit
```

**Using the menus**
- Press a single key to choose: no Enter needed. `Esc` goes back one level (it does nothing on the main menu).
- The header always shows whether **Dry run** is on and which folder is currently selected.
- Colors and box drawing adapt to your terminal. Set `NO_COLOR=1` (or use `TERM=dumb`) for plain output with
  no colors, and a non-UTF-8 locale falls back to ASCII glyphs.

---

### File Operations Menu

Main menu **[1]**. Every operation asks which folder to work on with the directory browser (see below), then:
- With **Dry run on**, it runs a preview first (`○ old name` / `→ [New] name`), shows a summary card, and asks "Apply these changes?".
- With Dry run off, it shows how many files will change and a sample, and asks "Proceed? [y/N]" before touching anything.
- When it finishes you get a progress bar while it ran, a summary card (what was renamed or skipped, and how long it took), and a
  note that the changes are recorded for undo.

These operations act on the files **directly inside the folder you choose** (Flatten is the exception, because it reaches into
subfolders). If the folder only contains subfolders of videos, the prompt says so and suggests Flatten or picking a subfolder.

**[1] Rename Files (Bracket Notation)**: dash removal, bracket notation and spacing fix in one pass
**[2] Remove Dashes**: only the ` - ` patterns
**[3] Fix Bracket Spacing**: only `]word` → `] word`
**[4] Flatten Directory**: moves every video from the subfolders up into the folder (name conflicts get a `(1)` suffix)
**[5] Full Cleanup**: rename, then a duplicate report
**[6] Image Operations**: convert JPEG/PNG/WebP/HEIC (or all) to JPG; needs ImageMagick; has its own Recursive and Dry run toggles; not undoable
**[7] Batch Processing**: the same operations over several folders (below)
**[8] Automated Workflows**: multi-step clean-ups (below)
**[D] Toggle Dry Run**: the header shows the state

---

### Batch Processing Menu

File Operations **[7]**. Run one operation over several folders. All four options use the same queue screen: add folders with the
browser (`A`), add **every subfolder that contains videos** (`S`), or type a path (`T`); remove one (`X`), clear (`C`), run (`Enter`),
cancel (`Q`). Each folder gets a progress header and the run ends with a per-folder results list.

**[1] Batch Rename Multiple Folders**: bracket notation for each folder
**[2] Batch Flatten Multiple Folders**: flatten each folder's subfolders
**[3] Batch Full Cleanup**: rename and duplicate report for each folder
**[4] Batch Find Duplicates**: report only, per folder (duplicates are not compared between folders; use the catalog for that)

With Dry run on it previews every folder and then asks whether to apply; with it off it asks for confirmation (it tells you how many
folders and videos will change). One undo log covers the whole batch.

---

### Automated Workflows Menu

File Operations **[8]**. Pre-configured multi-step operations; both ask before running and show a summary card.

**[1] New Collection Setup**
- **Step 1:** Flatten directory structure
- **Step 2:** Apply standardized naming
- **Step 3:** Detect duplicates
- **Use Case:** Setting up a newly acquired collection

**[2] Deep Clean Existing Collection**
- **Step 1:** Remove dash patterns
- **Step 2:** Fix bracket spacing
- **Step 3:** Apply bracket notation
- **Use Case:** Cleaning up existing organized collection

---

### Duplicate Detection Menu

Main menu **[3]**. Finds exact duplicates inside one folder (and its subfolders).

**[1] Find Duplicates (Report Only)**
- Shows the groups and writes text and CSV reports to the logs folder
- Nothing is moved or deleted

**[2] Find and Delete Duplicates**
- Moves the extra copies to the folder's hidden `.vmgr-trash` (see *Undo and Trash*): a single-key confirmation, fully undoable
- Keeps the first copy alphabetically
- If the Undo System is off, it deletes permanently and asks you to type `yes`

**[3] Find Duplicates (Dry Run)**
- Shows what would be moved, changes nothing

To compare **across drives**, use the catalog (below).

---

### Subtitle Generation Menu

Main menu **[2]**. Needs Whisper (`pip install openai-whisper`); the full guide is in [SUBTITLE-FEATURE-GUIDE.md](SUBTITLE-FEATURE-GUIDE.md).

**[1] Generate Subtitles** (one folder), **[2] Batch Generate Subtitles** (the folder queue screen, one results line per folder),
**[3] Configure Subtitle Settings** (model, format, language, one key each), **[4] Advanced Settings** (GPU, parallel jobs, filters),
**[5] Edit Existing Subtitle** (opens it in `$EDITOR`), **[6] Check Whisper Installation** (runs the command and reports a broken install).

Existing subtitles are skipped. Whisper writes filler such as `.` over silence and music; those cues are removed, and a video with
nothing but filler gets no subtitle file, is counted as **No speech found**, and is skipped on later runs (delete the hidden
`.<name>.nospeech` file to retry).

---

### Multi-Drive Catalog Menu

Main menu **[4]**. The catalog is an index of every media file on your drives (name, folder, size, hash, and for video/audio
the resolution, codec and duration; for images the dimensions and camera). It lives in `~/.video-manager-catalog.json` (files)
and `~/.video-manager-drives.json` (drives), needs `jq`, and keeps working when a drive is unplugged.

**[1] Scan & Catalog Drive**: pick a detected drive (`/mnt/d`, `/media/...`, `/Volumes/...`), browse for a folder, or type a path.
- Scans are **incremental**: a file whose size and modification time are unchanged is not hashed or probed again, so rescanning a
  large drive takes seconds. The result reads `3 new, 1 updated, 0 removed, 120 unchanged`.
- Files that disappeared from the scanned folder are removed from the catalog. A scan only touches records **under the folder
  you scanned**, so scanning one subfolder never forgets the rest of the drive.
- Paths are stored relative to the drive's mount point, so the same file found through different folders lines up.
- The trash folder (`.vmgr-trash`) is never cataloged. A file name containing a newline is skipped with a warning.

**[2] Cataloged Drives**: each drive with `online` / `offline`, type (Local, USB, NAS, Network), file count, size, a per-media-type
breakdown, mount point and last scan.

**[3] Search Catalog**: type a name or folder (case-insensitive), a **hash prefix** (6+ hex characters), an exact **resolution**
such as `1920x1080`, or a **camera** name, optionally limited to video, images or audio. Files on drives that are offline are
included and shown with a hollow dot, so you can find out *which* drive a file is on before plugging it in. Long result lists are
capped at 100 and say how many matched.

**[4] Find Duplicate Files**: groups of files with the same hash across **all** drives, with the drive each copy is on. This
reports first, then offers **Clean up**: pick a drive and the extra copies on it are moved to that drive's own `.vmgr-trash` (undoable), but only
copies that also exist on **another drive that is online right now**, and only if both files still match the size and modification
time the catalog recorded (anything that changed since the scan is left alone with a note to rescan). It needs hashes, so leave
*Include Hash* on.

**[5] Catalog Several Drives**: the same queue screen as Batch Processing, one results line per drive.

**[6] Export Catalog Report**: a text report (drives, totals by type and extension, the ten largest files, duplicate summary)
written to your home folder.

**[7] Catalog Settings**: which media types to catalog, whether to read metadata (needs `ffprobe`; `exiftool` or ImageMagick for
images), whether to hash files (slower, but required for duplicate detection), and how many days an offline drive is remembered
(0 keeps it forever).

From the command line:
```bash
vmgr catalog /mnt/d                       # scan (incremental)
vmgr catalog-list                         # drives and status
vmgr catalog-search "season 2" video      # search, offline drives included
vmgr catalog-duplicates                   # duplicates across all drives
vmgr catalog-report [file]                # write a text report
vmgr --dry-run catalog /mnt/d             # preview: how many files would be added or updated
```

---

### Utilities Menu

Main menu **[5]**. System management, diagnostics and undo.

**[1] Organize by Subfolder Names**: moves files into the subfolder whose name they match (logged for undo)
**[2] List Undo Operations**: each logged operation by name, date and file count, newest first
**[3] Undo Last Operation**: puts back every file of the most recent renamed, flattened, organized or trashed operation; asks first, previews when Dry run is on
**[4] View Last 50 Log Entries**
**[5] Open Log Directory**: file manager on the logs folder (WSL and Linux)
**[6] Test Filename Transformation**: type a filename and see each step of the pipeline
**[7] Display System Information**: versions, paths and which optional tools are installed
**[8] Empty Trash**: lists every `.vmgr-trash` the undo logs know about with its size and deletes the contents for good after you confirm

---

### Settings Menu

Main menu **[6]**. Settings last for the session; save them as a profile to keep them.

**Current Settings Display:**
```
  Dry Run Mode           ● on
  Verbose Output         ○ off
  Log directory          /home/user/.video-manager-logs
```

**[1] Toggle Dry Run Mode**: affects every operation (the header shows it)
**[2] Toggle Verbose Output**: off by default; on shows every intermediate step per file
**[3] View Supported Extensions**
**[4] Granular Controls**: per-file confirmation, preview and step-by-step modes; size, date and pattern filters; the **Undo System** switch; batch size; undo history
**[5] Organize Settings**: default target and search paths, progress and logging for organize
**[6] Save Configuration / [7] Load Configuration / [8] List Profiles / [9] Delete Profile**: named profiles in `~/.video-manager-config-<name>.conf`

---

### Choosing a Directory (Directory Browser)

Whenever a menu asks which folder to work on, you get a two-column browser: folders on the left, and a
live preview of the highlighted folder (its subfolders and videos) on the right.

```
Location: /home/you/Videos
Here: 3 folder(s), 1 video(s)  (hidden: off)
FOLDERS                      │ PREVIEW: alpha/
                             │ Folders (2)
▸ alpha/                     │ inner/
  beta/                      │ second/
  gamma/                     │
                             │ Videos (2)
                             │ a.mkv
                             │ b.mkv
```

| Key | Action |
|-----|--------|
| `↑` `↓` (or `k` `j`) | Move the highlight; `PgUp` / `PgDn` page through long lists |
| `→` (or `l`) | Open the highlighted folder |
| `Enter` | **Choose the highlighted folder** and continue (with no subfolders, chooses the current one) |
| `←` / `Backspace` (or `h`) | Go up one level, keeping the folder you came from highlighted |
| `S` / `Space` | **Choose the current directory** (the `Location:` line) and continue |
| `Q` / `Esc` / `C` | Cancel |
| `Home` / `End` | Jump to the first / last folder |
| `~` | Go to your home directory |
| `-` | Go back to the previous directory |
| `R` | Pick from recently used directories (numbered `1`-`9`) |
| `T` or `/` | Type a path; Tab completes and the arrow keys recall history |
| `.` | Show or hide hidden folders |
| `F` | Refresh (listings are cached and re-checked automatically; this forces a re-scan) |

**Good to know**
- It starts in the directory you used last; on a first run it tries `~/Videos`, `~/Movies`, your Windows `Videos` folder (under WSL), then your home. Recent directories are stored in `~/.video-manager-recent-dirs`
  (10 entries; folders that no longer exist are dropped).
- Symlinks and Windows junctions are not listed; use `T` to type a path into one.
- Terminals narrower than 70 columns show a single list without the preview.
- When input is piped (not a terminal) it falls back to a plain `Directory [default]:` prompt.

---

### Reddit Downloader

Main menu option **[7]**, or from the command line:

```bash
./video-manager-ultimate.sh reddit EarthPorn ~/Pictures/earthporn 100
./video-manager-ultimate.sh reddit pics ~/Pictures/pics 50 --sort top --time week
```

The subreddit can be given as `EarthPorn`, `r/EarthPorn`, `/r/EarthPorn/` or a pasted reddit.com URL.
`--sort` is one of `hot`, `new`, `top`, `rising`, `controversial`; `--time` (`hour`, `day`, `week`,
`month`, `year`, `all`) applies to `top` and `controversial`. The limit counts files, so a gallery of
10 images counts as 10.

**What it downloads:** images (`.jpg` / `.png` / `.gif` / `.webp`, `.jpeg` is saved as `.jpg`), direct
`.mp4` / `.webm` links, Imgur `.gifv` (saved as `.mp4`), and Reddit-hosted videos (`v.redd.it`). Reddit
videos are stored as separate video and audio streams, so install `ffmpeg` to have them merged; without
it they are saved without sound. Files that already exist are skipped. Requires `curl` and `jq`.

**With or without API credentials**

| | With credentials | Without credentials |
|---|---|---|
| Source | Reddit OAuth API | Public RSS feed |
| Speed | Normal | About one request per minute (Reddit rate limits it; the downloader waits and retries) |
| Galleries | All images downloaded | **Skipped** (the feed does not list a gallery's images); a summary tells you how many |
| Images / videos | Yes | Yes |

**Setting up the API (guided).** Reddit menu **[2] Reddit API Setup**, or `vmgr reddit-setup`:

1. It shows the three steps: open <https://www.reddit.com/prefs/apps> (it can open the page for you), click "create another app...",
   choose type **script** with redirect URI `http://localhost:8080`.
2. Paste the **client ID** (the short text under the app name) and the **secret** (typed hidden, never shown or logged).
3. It **checks the login with a real request to Reddit before saving anything**. If Reddit rejects it, it says what to look at and
   lets you try again; nothing is written. When it works, `~/.vmgr-reddit.conf` is created readable only by you (mode 600), and
   galleries and normal speed apply from the next download.

When credentials are already saved the same screen can **test** them, **replace** them or **delete** them. Other settings in the
file (`REDDIT_RATE_LIMIT_DELAY`, `REDDIT_MAX_RETRIES`, `REDDIT_MAX_WAIT`) are kept. The credentials are handed to `curl` on stdin,
so they never show up in the process list. The Reddit menu shows whether a login is saved, and a download without one reminds you.

To do it by hand instead, create `~/.vmgr-reddit.conf` owned by you:

```bash
cat > ~/.vmgr-reddit.conf <<'EOF'
REDDIT_CLIENT_ID="your_client_id"          # shown under the app name
REDDIT_CLIENT_SECRET="your_client_secret"
# Optional tuning:
# REDDIT_RATE_LIMIT_DELAY=1   # seconds between downloads
# REDDIT_MAX_RETRIES=3        # times to wait out an HTTP 429
# REDDIT_MAX_WAIT=120         # longest single wait, in seconds
EOF
chmod 600 ~/.vmgr-reddit.conf
```

Errors report Reddit's real HTTP status (for example 403 for a private or banned subreddit, 404 for a
subreddit that does not exist, 429 for rate limiting).

---

## Command Line Reference

### Basic Syntax

```bash
./video-manager-ultimate.sh [OPTIONS] [COMMAND] [DIRECTORY]
```

### Options

| Option | Long Form | Description |
|--------|-----------|-------------|
| `-h` | `--help` | Show help message and exit |
| `-v` | `--version` | Show version information |
| `-d` | `--dry-run` | Enable dry run mode (no changes) |
| | `--verbose` | Show every intermediate step per file |
| `-q` | `--quiet` | Minimal output (the default) |
| `-i` | `--interactive` | Launch interactive menu |

### Commands

| Command | Description | Requires |
|---------|-------------|----------|
| `rename <dir>` | Apply bracket notation | directory |
| `flatten <dir>` | Flatten directory structure | directory |
| `cleanup <dir>` | Full cleanup pipeline | directory |
| `duplicates <dir>` | Find duplicate files (report) | directory |
| `subtitles <dir>` | Generate subtitles with Whisper | directory |
| `workflow-new <dir>` | New collection setup workflow | directory |
| `workflow-clean <dir>` | Deep clean workflow | directory |
| `batch` | Batch rename; reads one directory per line when input is piped | none |
| `--organize` | Organize files by subfolder names | none |
| `--undo-organize [ID]` | Undo a logged operation (default: the most recent) | none |
| `--list-undo` | List the logged operations | none |
| `--empty-trash` | Permanently delete files moved to trash | none |
| `catalog <dir>` | Scan a drive or folder into the catalog | directory |
| `catalog-list` | Cataloged drives, online/offline | none |
| `catalog-search <term> [type]` | Search the catalog (video, image or audio) | term |
| `catalog-duplicates` | Duplicates across all cataloged drives | none |
| `catalog-report [file]` | Text report of the catalog | none |
| `reddit <sub> <dir> [max]` | Download from a subreddit | subreddit, directory |
| `reddit-setup` | Guided Reddit API setup | terminal |

### Examples

#### Basic Operations

```bash
# Rename files with bracket notation
./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos

# Flatten directory structure
./video-manager-ultimate.sh flatten /mnt/c/Users/Eric/Videos

# Full cleanup
./video-manager-ultimate.sh cleanup /mnt/c/Users/Eric/Videos

# Find duplicates
./video-manager-ultimate.sh duplicates /mnt/c/Users/Eric/Videos
```

#### With Dry Run

```bash
# Test rename operation
./video-manager-ultimate.sh --dry-run rename /mnt/c/Users/Eric/Videos

# Preview flatten operation
./video-manager-ultimate.sh -d flatten /mnt/c/Users/Eric/Videos
```

#### Workflows

```bash
# Setup new collection
./video-manager-ultimate.sh workflow-new /mnt/c/Users/Eric/NewCollection

# Clean existing collection
./video-manager-ultimate.sh workflow-clean /mnt/c/Users/Eric/Videos
```

#### Quiet Mode (Minimal Output)

```bash
# Run with minimal console output (still logs everything)
./video-manager-ultimate.sh --quiet rename /mnt/c/Users/Eric/Videos
```

#### Batch Processing

```bash
# Launch batch mode (will prompt for directories)
./video-manager-ultimate.sh batch
```

### Path Formats

The script accepts both Windows and Unix path formats:

```bash
# Windows path (will be converted)
./video-manager-ultimate.sh rename "C:\Users\Eric\Videos"

# WSL path
./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos

# Native Linux path
./video-manager-ultimate.sh rename /home/user/Videos

# Network path (if mounted)
./video-manager-ultimate.sh rename /mnt/network/Videos
```

---

## Workflows

### Workflow 1: New Collection Setup

**Purpose:** Organize a newly acquired or downloaded video collection

**Steps:**
1. Flatten directory structure (move all to top level)
2. Apply standardized bracket notation
3. Detect and report duplicates

**When to Use:**
- Downloaded torrent with nested folders
- Received collection from friend
- Imported from external drive
- Consolidating multiple sources

**Example:**
```bash
./video-manager-ultimate.sh workflow-new /mnt/c/Users/Eric/Downloads/NewCollection
```

**Expected Results:**
- All videos in single directory
- Standardized `[Studio] filename.ext` format
- Duplicate report generated
- Ready for your media player

---

### Workflow 2: Deep Clean

**Purpose:** Clean up an existing organized collection

**Steps:**
1. Remove unwanted dash patterns
2. Fix bracket spacing issues
3. Ensure consistent bracket notation

**When to Use:**
- Collection has formatting inconsistencies
- Previous renaming left artifacts
- Imported from different system
- Standardizing old collection

**Example:**
```bash
./video-manager-ultimate.sh workflow-clean /mnt/c/Users/Eric/Videos/Vixen
```

**Expected Results:**
- Consistent formatting throughout
- Proper bracket spacing
- Cleaned filename patterns
- Professional appearance

---

## Logging System

### Log Location

```
~/.video-manager-logs/
└── video-manager-YYYYMMDD-HHMMSS.log
```

### Log Format

```
[YYYY-MM-DD HH:MM:SS] [LEVEL] Message
```

**Levels:**
- `INFO` - General information
- `SUCCESS` - Successful operations
- `WARN` - Warnings (non-critical)
- `ERROR` - Errors encountered
- `OPERATION` - Operation start/end markers
- `RENAME` - Rename operations
- `MOVE` - File move operations
- `DRYRUN` - Dry run previews
- Everything the tool prints to the screen is also logged, including the verbose detail that is hidden by default

### Example Log Entries

```
[2025-10-19 14:30:00] [INFO] ==========================================
[2025-10-19 14:30:00] [INFO] Video Manager Ultimate - Bash Edition v1.6.0
[2025-10-19 14:30:00] [INFO] Session started: 2025-10-19 14:30:00
[2025-10-19 14:30:00] [INFO] ==========================================
[2025-10-19 14:30:05] [OPERATION] Started: Rename Files (Bracket Notation)
[2025-10-19 14:30:06] [INFO] Scanning directory: /mnt/c/Users/Eric/Videos
[2025-10-19 14:30:06] [RENAME] Success: vixen.movie.mp4 -> [Vixen] movie.mp4
[2025-10-19 14:30:07] [RENAME] Success: tushy.scene.mp4 -> [Tushy] scene.mp4
[2025-10-19 14:30:08] [OPERATION] Completed: Rename Files (Duration: 0m 3s)
[2025-10-19 14:30:08] [INFO] Session ended: 2025-10-19 14:30:08
```

### Log Rotation

- Maximum 50 log files kept
- Oldest automatically deleted when limit reached
- Each session creates new log file
- Prevents disk space issues

### Accessing Logs

**Via Interactive Menu:**
1. Main Menu → Utilities → View Last 50 Log Entries

**Via File Manager:**
1. Main Menu → Utilities → Open Log Directory

**Via Command Line:**
```bash
# View latest log
tail -n 100 ~/.video-manager-logs/video-manager-*.log | tail -n 1

# View all logs
ls -lt ~/.video-manager-logs/

# Search logs
grep "ERROR" ~/.video-manager-logs/*.log
```

---

## Troubleshooting

### Common Issues

#### 1. Permission Denied

**Symptom:**
```
✗ Error: Directory is not readable: /mnt/c/Users/Eric/Videos
```

**Solutions:**
```bash
# Check permissions
ls -la /mnt/c/Users/Eric/Videos

# Fix permissions (if you own the directory)
chmod -R u+rwX /mnt/c/Users/Eric/Videos

# Run with sudo (last resort)
sudo ./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos
```

---

#### 2. Hash Utility Not Found

**Symptom:**
```
✗ Error: No hash utility found (sha256sum or shasum required)
```

**Solutions:**
```bash
# Ubuntu/Debian
sudo apt-get install coreutils

# macOS (should have shasum by default)
# If not, install via Homebrew:
brew install coreutils

# Verify installation
which sha256sum || which shasum
```

---

#### 3. Windows Path Not Found

**Symptom:**
```
✗ Error: Directory does not exist: C:\Users\Eric\Videos
```

**Solutions:**
```bash
# Use WSL path format
./video-manager-ultimate.sh rename /mnt/c/Users/Eric/Videos

# Or use quotes with backslashes
./video-manager-ultimate.sh rename "C:\\Users\\Eric\\Videos"

# Check if path is accessible from WSL
ls /mnt/c/Users/Eric/Videos
```

---

#### 4. Operation Too Slow

**Symptom:** Script runs slowly on large collections

**Solutions:**
```bash
# Disable verbose output
./video-manager-ultimate.sh --quiet rename /mnt/c/Users/Eric/Videos

# Or toggle in Settings menu
# Main Menu → Settings → Toggle Verbose Output

# For duplicate detection, ensure fast disk
# Consider running overnight for huge collections (10,000+ files)
```

---

#### 5. Filename Conflicts

**Symptom:**
```
⚠ Filename conflict resolved: movie(1).mp4
```

**Explanation:** Two files would have identical names after processing

**Solutions:**
- This is automatic protection
- Review the (1), (2), etc. files manually
- May indicate actual duplicates
- Run duplicate detection to verify

---

#### 6. Special Characters in Filenames

**Symptom:** Files with special characters not processing correctly

**Solutions:**
```bash
# The script handles most special characters
# If issues persist, manually rename problem files first

# Characters that may cause issues:
# Newlines, null bytes, unusual Unicode

# Check for problem characters:
find /path -name $'*\n*'  # Newlines
find /path -name '*[!-~]*'  # Non-printable
```

---

### Getting Help

1. **Check the logs:**
   ```bash
   cat ~/.video-manager-logs/video-manager-*.log | tail -n 100
   ```

2. **Run system information:**
   ```bash
   ./video-manager-ultimate.sh
   # Navigate to: Utilities → Display System Information
   ```

3. **Test with dry run:**
   ```bash
   ./video-manager-ultimate.sh --dry-run rename /path/to/directory
   ```

4. **Test single file transformation:**
   ```bash
   ./video-manager-ultimate.sh
   # Navigate to: Utilities → Test Filename Transformation
   ```

---

## Best Practices

### Before Starting

1. **Backup your collection** (always!)
   ```bash
   # Quick backup
   cp -r /mnt/c/Users/Eric/Videos /mnt/c/Users/Eric/Videos_BACKUP
   
   # Or use rsync for large collections
   rsync -av /mnt/c/Users/Eric/Videos/ /backup/Videos/
   ```

2. **Always dry run first**
   ```bash
   ./video-manager-ultimate.sh --dry-run rename /path/to/directory
   ```

3. **Start with small test folder**
   - Test on 10-20 files first
   - Verify results meet expectations
   - Then process entire collection

### During Operations

1. **Monitor the output**
   - Watch for unexpected transformations
   - Check for excessive errors
   - Verify conflict resolutions look correct

2. **Check statistics**
   - Files processed should match expectations
   - Errors should be zero or minimal
   - Skipped files should make sense

3. **Review logs in real-time** (optional)
   ```bash
   # In another terminal:
   tail -f ~/.video-manager-logs/video-manager-*.log | head -n 1
   ```

### After Operations

1. **Verify results**
   ```bash
   # Check a few renamed files
   ls /mnt/c/Users/Eric/Videos | head -n 20
   
   # Verify total count unchanged
   find /mnt/c/Users/Eric/Videos -name "*.mp4" | wc -l
   ```

2. **Review logs**
   ```bash
   # Check for errors
   grep ERROR ~/.video-manager-logs/video-manager-*.log | tail -n 20
   
   # Review statistics
   grep "Files Processed" ~/.video-manager-logs/video-manager-*.log | tail -n 1
   ```

3. **Test playback**
   - Open a few random files
   - Ensure nothing corrupted
   - Verify media player recognizes files

### Regular Maintenance

1. **Run duplicate detection monthly**
   ```bash
   ./video-manager-ultimate.sh duplicates /mnt/c/Users/Eric/Videos
   ```

2. **Check for formatting drift**
   - Run deep clean workflow quarterly
   - Maintains consistency over time

3. **Review logs periodically**
   ```bash
   # Check log disk usage
   du -sh ~/.video-manager-logs/
   
   # Old logs auto-rotate, but verify
   ls ~/.video-manager-logs/ | wc -l
   ```

### Automation

1. **Schedule regular cleanups**
   ```bash
   # Add to crontab (crontab -e)
   # Run deep clean every Sunday at 2 AM
   0 2 * * 0 /home/user/bin/video-manager-ultimate.sh workflow-clean /mnt/c/Users/Eric/Videos
   ```

2. **Post-download automation**
   ```bash
   # Create wrapper script for downloads
   #!/bin/bash
   # After download completes:
   /home/user/bin/video-manager-ultimate.sh workflow-new /home/user/Downloads/Videos
   ```

3. **Batch processing script**
   ```bash
   #!/bin/bash
   # Process all collections
   for dir in /mnt/c/Users/Eric/Videos/*/; do
       /home/user/bin/video-manager-ultimate.sh cleanup "$dir"
   done
   ```

---

## Advanced Tips

### Performance Optimization

```bash
# For very large collections (10,000+ files)
# Disable verbose output
./video-manager-ultimate.sh --quiet rename /path

# Process in smaller batches
for dir in /Videos/*/; do
    ./video-manager-ultimate.sh rename "$dir"
done
```

### Custom Extensions

Edit the script to add custom video formats:

```bash
# Line ~67 in video-manager-ultimate.sh
DEFAULT_VIDEO_EXTENSIONS=("mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "3gp" "ts" "m2ts")
```

### Integration with Other Tools

```bash
# Combine with find for selective processing
find /Videos -name "*vixen*" -type f -exec dirname {} \; | sort -u | while read dir; do
    ./video-manager-ultimate.sh rename "$dir"
done

# Combine with media info extraction
./video-manager-ultimate.sh rename /Videos && mediainfo /Videos/*.mp4 > video-info.txt
```

---

## Comparison with PowerShell Ultimate Edition

| Feature | Bash Edition | PowerShell Edition |
|---------|--------------|-------------------|
| **Platform** | Linux, WSL, macOS | Windows, PowerShell Core |
| **Interactive Menu** | ✅ Color-coded | ✅ Color-coded |
| **CLI Arguments** | ✅ Full support | ✅ Full support |
| **Detailed Output** | ✅ Quiet by default, `--verbose` for every step | ✅ Comprehensive |
| **Logging** | ✅ Timestamp & levels | ✅ Timestamp & levels |
| **Duplicate Detection** | ✅ SHA-256 based | ✅ SHA-256 + metadata |
| **Near-Duplicate Detection** | ❌ Not yet | ✅ ffprobe required |
| **Directory Flattening** | ✅ Full support | ✅ Full support |
| **Batch Processing** | ✅ Full support | ✅ Full support |
| **Workflows** | ✅ 2 workflows | ✅ Multiple workflows |
| **Path Handling** | Unix + WSL paths | Windows + UNC paths |
| **Performance** | Native bash speed | .NET optimized |

**Recommendation:** Use both! PowerShell for Windows-native operations, Bash for Linux/WSL or when you prefer shell scripting.

---

## FAQ

**Q: Can I run this on macOS?**  
A: Yes! It should work on macOS with bash 4.0+. Install sha256sum if needed via Homebrew.

**Q: Does this modify video files or just filenames?**  
A: Only names and locations. Video content is never touched (image conversion creates new JPG files).

**Q: What if I accidentally remove duplicates?**  
A: They are moved to a hidden `.vmgr-trash` folder, not deleted, so **Utilities → Undo Last Operation** puts them back. They are only gone for good after **Utilities → Empty Trash**, or if you switch the Undo System off.

**Q: Can I undo renames?**  
A: Yes. Renames, dash removal, spacing fixes, flattening, "organize by subfolder" and duplicate removal are recorded in an undo log as they happen, one log per operation (a batch counts as one). After an operation the summary tells you how many changes were recorded. Use **Utilities → Undo Last Operation** to put the files back, **Utilities → List Undo Operations** to see them, or `--undo-organize [ID]` from the command line. Undo skips any file whose old name has been taken since. Converting images cannot be undone, so back those up first.

**Q: Can it find the same file on two different drives?**  
A: Yes: scan each drive with the **Multi-Drive Catalog** ([4]); then *Find Duplicate Files* compares hashes across all of them, and the catalog can be searched even when a drive is unplugged.

**Q: Why did the Reddit downloader skip galleries?**  
A: Without API credentials Reddit's public feed does not list a gallery's images. Run **Reddit → Reddit API Setup** (or `vmgr reddit-setup`): it checks your login before saving it.

**Q: Does this work with network drives?**  
A: Yes, if mounted in your filesystem. Performance depends on network speed.

**Q: Can I customize the bracket notation format?**  
A: Yes, edit the `apply_bracket_notation()` function in the script.

**Q: What about subtitle files (.srt, .vtt)?**  
A: The tool can generate them with Whisper (Subtitle Generation, main menu [2]) and skips videos that already have one. It does not rename existing subtitle files along with their videos.

**Q: Is this safe for my media library?**  
A: Yes, when used with dry run first. The script never modifies video content, only names and locations, and nearly everything it changes can be undone; keep backups of irreplaceable media anyway.

---

## Version History

### Version 1.6.0 (October 2026)
- Multi-drive catalog: incremental scans, search that works for unplugged drives, duplicates across drives (with undoable cleanup)
- Guided Reddit API setup; Reddit downloader no longer leaves empty folders; log messages print Windows paths literally

### Version 1.5.0 (October 2026)
- Deleted duplicates go to an undoable trash; Empty Trash
- Whisper filler cleanup and "no speech" detection; batch subtitle generation

### Version 1.4.0 (October 2026)
- New interface: framed header, single-key menus, themed directory browser, progress bars and summary cards
- Undo for renames and flattens; Batch Processing and Workflows reachable from the menu; quiet output by default

### Version 1.3.0 (December 2025)
- Modular architecture, tab completion, automated test suite

### Version 1.2.0 / 1.1.0 (November 2025)
- Organize by subfolder with undo; Whisper subtitle generation with GPU and parallel jobs

### Version 1.0.0 (October 2025)
- Initial release: interactive menu, CLI, logging, duplicate detection, flattening, bracket notation, batch processing, workflows

---

## Credits

Created for Eric's Video Management System  
Complements PowerShell Ultimate Edition  
Built with bash and a lot of dry runs ❤️

---

**End of User Guide**
