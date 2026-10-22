#!/usr/bin/env bash
#
# Video Manager Ultimate - Multi-Drive Catalog Module
# Part of the modular video management system
#
# This module provides multi-drive catalog system functionality for:
# - Scanning drives into a catalog (incremental: unchanged files are not re-hashed)
# - Searching the catalog, including drives that are currently offline
# - Cross-drive duplicate detection
# - Drive registration and tracking
# - Drive type detection (USB, NAS, Local, Network)
#
# Data: CATALOG_DB holds one record per file, CATALOG_DRIVES_DB one per drive.
# Requires jq.
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh, duplicates.sh
#

################################################################################
# DRIVE IDENTIFICATION
################################################################################

# Get unique drive identifier (UUID, Volume ID, or Serial Number)
get_drive_id() {
    local mount_point="$1"
    local drive_id=""

    if [[ -d "$mount_point" ]]; then
        # For WSL drives, use volume label + serial
        if [[ "$mount_point" =~ ^/mnt/[a-z]$ ]]; then
            local drive_letter="${mount_point##*/}"
            drive_id=$(powershell.exe -NoProfile -Command "(Get-Volume -DriveLetter ${drive_letter}).UniqueId" 2>/dev/null | tr -d '\r\n' | tr -d '{}')
            if [[ -z "$drive_id" ]]; then
                local vol_label=$(powershell.exe -NoProfile -Command "(Get-Volume -DriveLetter ${drive_letter}).FileSystemLabel" 2>/dev/null | tr -d '\r\n')
                drive_id="${drive_letter}_${vol_label}"
            fi
        else
            # Try Linux UUID method
            local dev=$(df "$mount_point" 2>/dev/null | tail -1 | awk '{print $1}')
            if [[ -n "$dev" ]]; then
                drive_id=$(blkid -s UUID -o value "$dev" 2>/dev/null)
            fi

            # Fallback: a stable hash of the mount point
            if [[ -z "$drive_id" ]]; then
                drive_id="$(_catalog_hash_string "$mount_point" | cut -c1-32)"
            fi
        fi
    fi

    echo "$drive_id"
}

# Get drive label/name
get_drive_label() {
    local mount_point="$1"
    local label=""

    if [[ "$mount_point" =~ ^/mnt/[a-z]$ ]]; then
        local drive_letter="${mount_point##*/}"
        label=$(powershell.exe -NoProfile -Command "(Get-Volume -DriveLetter ${drive_letter}).FileSystemLabel" 2>/dev/null | tr -d '\r\n')
        [[ -z "$label" ]] && label="Drive ${drive_letter^^}"
    elif [[ "$mount_point" == "/" ]]; then
        label="System drive"
    else
        label=$(basename "$mount_point")
    fi

    echo "$label"
}

# Detect drive type (USB, NAS, Local, Network)
detect_drive_type() {
    local mount_point="$1"
    local drive_type="Unknown"

    # Mount info for exactly this mount point ("dev on /path type fs" or "dev on /path (fs, ...)")
    local mount_info
    mount_info="$(mount 2>/dev/null | awk -v m="$mount_point" '$3 == m')"

    if [[ "$mount_point" =~ ^/mnt/[a-z]$ ]]; then
        # WSL drive
        local drive_letter="${mount_point##*/}"
        local bus_type=$(powershell.exe -NoProfile -Command "(Get-PhysicalDisk | Where-Object {(\$_.DeviceID -eq (Get-Partition -DriveLetter ${drive_letter}).DiskNumber)}).BusType" 2>/dev/null | tr -d '\r\n')

        case "$bus_type" in
            USB) drive_type="USB" ;;
            SATA|SAS|ATA) drive_type="Local" ;;
            NVMe|RAID) drive_type="Local" ;;
            iSCSI|FC) drive_type="NAS" ;;
            *) drive_type="Local" ;;
        esac
    elif echo "$mount_info" | grep -q "cifs\|smb"; then
        drive_type="Network"
    elif echo "$mount_info" | grep -q "nfs"; then
        drive_type="NAS"
    elif echo "$mount_info" | grep -q "fuse\|9p"; then
        drive_type="Network"
    else
        drive_type="Local"
    fi

    echo "$drive_type"
}

################################################################################
# CATALOG DATABASE MANAGEMENT
################################################################################

# UTC timestamp in a form jq can parse (date -I is not available everywhere)
_catalog_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# jq expression that writes the catalog with ONE RECORD PER LINE (still valid
# JSON). A line per record lets grep pre-filter a search and awk total a drive
# without parsing the whole file, and it keeps the file small. Every writer ends
# its jq program with "| <this>" and runs jq with -r. (It emits one output line per
# record; building one big string with join is quadratic in jq 1.6.)
_CAT_FMT='"{\"videos\":[", ((.videos | length) as $n | .videos as $v | range(0; $n) as $i | ($v[$i] | tojson) + (if $i < $n - 1 then "," else "" end)), ("],\"last_updated\":" + (.last_updated | tojson) + ",\"version\":" + ((.version // "1.0") | tojson) + "}")'

# Initialize catalog database
init_catalog_db() {
    if [[ ! -f "$CATALOG_DB" ]]; then
        printf '{"videos":[\n\n],"last_updated":"%s","version":"1.0"}\n' "$(_catalog_now)" > "$CATALOG_DB"
        log_verbose "Created catalog database: $CATALOG_DB"
    elif [[ "$(head -n 1 "$CATALOG_DB" 2>/dev/null)" != '{"videos":[' ]] && command -v jq >/dev/null 2>&1; then
        # A catalog written in another layout (pretty-printed, or on one line): rewrite it once
        local tmp; tmp="$(mktemp)" && jq -r "$_CAT_FMT" "$CATALOG_DB" > "$tmp" 2>/dev/null && _catalog_commit "$CATALOG_DB" "$tmp"
        rm -f "$tmp" 2>/dev/null
    fi

    if [[ ! -f "$CATALOG_DRIVES_DB" ]]; then
        echo '{"drives":[],"last_updated":"'"$(_catalog_now)"'"}' > "$CATALOG_DRIVES_DB"
        log_verbose "Created drives database: $CATALOG_DRIVES_DB"
    fi
}

# Replace a JSON database file with the contents of $2 (atomic, via a temp file).
_catalog_commit() {
    local target="$1" source="$2"
    [[ -s "$source" ]] || return 1
    mv -f "$source" "$target"
}

# Register a drive in the drives database
register_drive() {
    local mount_point="$1"

    init_catalog_db

    local drive_id=$(get_drive_id "$mount_point")
    local drive_label=$(get_drive_label "$mount_point")
    local drive_type=$(detect_drive_type "$mount_point")
    local timestamp=$(date -Iseconds)

    log_info "Registering drive: $drive_label ($drive_id)"
    log_verbose "  Mount point: $mount_point"
    log_verbose "  Type: $drive_type"

    echo "$drive_id"
}

################################################################################
# HELPERS
################################################################################

# Field separator for the line formats below. A file name cannot realistically
# contain it, and one that does (or contains a newline) is skipped.
_CAT_SEP=$'\x1f'

CATALOG_SEARCH_LIMIT="${CATALOG_SEARCH_LIMIT:-100}"

# Drive id / label / type per mount point. Identifying a Windows drive from WSL
# runs PowerShell several times, so a batch of scans asks once per drive.
declare -gA CAT_DRIVE_CACHE=()

_catalog_require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        log_error "The catalog needs jq. Install it first (for example: sudo apt-get install jq)"
        return 1
    fi
}

# Set CAT_ID, CAT_LABEL and CAT_TYPE for a mount point (cached). Returns 1 if the
# drive cannot be identified.
_catalog_drive_info() {
    local mp="$1" cached="${CAT_DRIVE_CACHE["$1"]-}"
    if [[ -n "$cached" ]]; then
        IFS="$_CAT_SEP" read -r CAT_ID CAT_LABEL CAT_TYPE <<< "$cached"
        return 0
    fi
    CAT_ID="$(get_drive_id "$mp")"
    [[ -n "$CAT_ID" ]] || return 1
    CAT_LABEL="$(get_drive_label "$mp")"
    CAT_TYPE="$(detect_drive_type "$mp")"
    CAT_DRIVE_CACHE["$mp"]="${CAT_ID}${_CAT_SEP}${CAT_LABEL}${_CAT_SEP}${CAT_TYPE}"
}

# Stable hash of a string (sha256, or shasum on macOS).
_catalog_hash_string() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | awk '{print $1}'
    else
        printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
    fi
}

# "size mtime" (bytes, epoch seconds) of a file; GNU stat first, then BSD.
_catalog_stat() {
    stat -c '%s %Y' "$1" 2>/dev/null || stat -f '%z %m' "$1" 2>/dev/null
}

# The mount point of the filesystem a path lives on. Falls back to the path itself.
catalog_mount_point() {
    local path target
    path="$(cd "$1" 2>/dev/null && pwd -P)" || path="$1"
    target="$(df -P "$path" 2>/dev/null | awk 'NR==2 { $1=$2=$3=$4=$5=""; sub(/^ +/, ""); print }')"
    if [[ -n "$target" && -d "$target" ]]; then
        echo "$target"
    else
        echo "$path"
    fi
}

# A drive counts as online when its mount point exists and has something in it.
_catalog_mount_online() {
    [[ -d "$1" ]] && [[ -n "$(ls -A "$1" 2>/dev/null | head -n 1)" ]]
}

# JSON object of the drives that are online right now: {"<drive_id>": true, ...}
_catalog_online_json() {
    local id mp
    local -a on=()
    while IFS="$_CAT_SEP" read -r id mp; do
        _catalog_mount_online "$mp" && on+=("$id")
    done < <(jq -r '.drives[] | [.drive_id, .mount_point] | join("\u001f")' "$CATALOG_DRIVES_DB" 2>/dev/null)
    if (( ${#on[@]} > 0 )); then
        printf '%s\n' "${on[@]}" | jq -R '{(.): true}' | jq -s 'add'
    else
        echo '{}'
    fi
}

# Candidate drives to offer in the menu: external and Windows drives.
catalog_detect_mounts() {
    local m
    for m in /mnt/[a-z] /media/*/* /run/media/*/* /Volumes/*; do
        _catalog_mount_online "$m" && echo "$m"
    done
}

# Media type from a file extension, left in CAT_TYPE (video, image, audio or
# other). Sets a variable instead of printing so the scan loop forks nothing.
_catalog_media_type_set() {
    local ext="${1,,}" e
    for e in "${DEFAULT_VIDEO_EXTENSIONS[@]}"; do [[ "$e" == "$ext" ]] && { CAT_TYPE=video; return; }; done
    for e in "${DEFAULT_IMAGE_EXTENSIONS[@]}"; do [[ "$e" == "$ext" ]] && { CAT_TYPE=image; return; }; done
    for e in "${DEFAULT_AUDIO_EXTENSIONS[@]}"; do [[ "$e" == "$ext" ]] && { CAT_TYPE=audio; return; }; done
    CAT_TYPE=other
}

# Media type from a file extension: video, image, audio or other.
_catalog_media_type() {
    _catalog_media_type_set "$1"
    echo "$CAT_TYPE"
}

# One live status line (replaced by the next one, cleared by progress_break). Nothing
# is printed unless the output is a terminal.
_catalog_status() {
    [[ -t 1 ]] || return 0
    UI_PROGRESS_ACTIVE=1
    printf '\r  %s%s%s\033[K' "${UI_DIM:-}" "$1" "${COLOR_RESET:-}"
}

# "42s" or "3m05s" for a number of seconds.
_catalog_eta() {
    local s="$1"
    if (( s < 60 )); then printf '%ds' "$s"; else printf '%dm%02ds' $(( s / 60 )) $(( s % 60 )); fi
}

# Progress for a long loop, at most once a second. Args: done, total, label, detail, start (SECONDS)
# Shows an estimate of the time left once there is something to base it on.
_catalog_tick() {
    local n="$1" total="$2" label="$3" detail="$4" start="$5" elapsed eta=""
    [[ "$(type -t ui_progress)" == "function" ]] || return 0
    (( SECONDS == ${_CAT_LAST_TICK:--1} && n < total )) && return 0
    _CAT_LAST_TICK=$SECONDS
    elapsed=$(( SECONDS - start ))
    (( elapsed >= 3 && n > 0 && n < total )) && eta=" ~$(_catalog_eta $(( elapsed * (total - n) / n ))) left"
    ui_progress "$n" "$total" "${label}${eta}" "$detail"
}

# SHA-256 of many files with a handful of processes instead of one per file.
# $1 = file with NUL-separated absolute paths, $2 = how many there are.
# Fills the global CAT_HASHES (path -> hash); a file that could not be hashed is
# simply missing and the caller falls back to hashing it on its own.
declare -gA CAT_HASHES=()
_catalog_hash_files() {
    local list="$1" total="$2" line h f n=0 start=$SECONDS
    CAT_HASHES=()

    if command -v sha256sum >/dev/null 2>&1 && printf x | sha256sum -z >/dev/null 2>&1; then
        # -z: NUL-terminated records and no escaping of unusual names
        while IFS= read -r -d '' line; do
            h="${line%% *}"; f="${line#*  }"
            CAT_HASHES["$f"]="$h"
            n=$(( n + 1 ))
            _catalog_tick "$n" "$total" "Hashing" "${f##*/}" "$start"
        done < <(xargs -0 -n 32 sha256sum -z -- < "$list" 2>/dev/null)
    else
        local tool=(sha256sum)
        command -v sha256sum >/dev/null 2>&1 || tool=(shasum -a 256)
        # Newline-terminated; names that needed escaping (a leading backslash on
        # the hash) are skipped and hashed individually by the caller.
        while IFS= read -r line; do
            h="${line%% *}"; f="${line#*  }"
            [[ "$h" == \\* ]] && continue
            CAT_HASHES["$f"]="$h"
            n=$(( n + 1 ))
            _catalog_tick "$n" "$total" "Hashing" "${f##*/}" "$start"
        done < <(xargs -0 -n 32 "${tool[@]}" -- < "$list" 2>/dev/null)
    fi
}

# Fill CAT_FIND_NAME_ARGS with a find filter for the enabled media types.
_catalog_find_args() {
    CAT_FIND_NAME_ARGS=()
    local -a exts=()
    [[ "$CATALOG_VIDEOS" == true ]] && exts+=("${DEFAULT_VIDEO_EXTENSIONS[@]}")
    [[ "$CATALOG_IMAGES" == true ]] && exts+=("${DEFAULT_IMAGE_EXTENSIONS[@]}")
    [[ "$CATALOG_AUDIO" == true ]]  && exts+=("${DEFAULT_AUDIO_EXTENSIONS[@]}")
    local ext first=true
    for ext in "${exts[@]}"; do
        $first || CAT_FIND_NAME_ARGS+=("-o")
        first=false
        CAT_FIND_NAME_ARGS+=("-iname" "*.${ext}")
    done
}

# Stream "relative path <TAB> size <TAB> mtime" lines for every matching file
# under $1. $2 = true to recurse. Uses GNU find -printf when it exists (one
# process); otherwise one stat per file. A name containing a newline or tab
# does not parse as three fields and is counted and skipped by the caller.
_catalog_inventory() {
    local dir="$1" recursive="$2"
    local -a depth=()
    [[ "$recursive" == true ]] || depth=(-maxdepth 1)

    if find /dev/null -maxdepth 0 -printf '' 2>/dev/null; then
        find "$dir" "${depth[@]}" -type f ! -path "*/${VMGR_TRASH_DIR:-.vmgr-trash}/*" \
            \( "${CAT_FIND_NAME_ARGS[@]}" \) -printf '%P\t%s\t%T@\n' 2>/dev/null
    else
        local f st
        while IFS= read -r -d '' f; do
            st="$(_catalog_stat "$f")" || continue
            printf '%s\t%s\t%s\n' "${f#"$dir"/}" "${st% *}" "${st#* }"
        done < <(find "$dir" "${depth[@]}" -type f ! -path "*/${VMGR_TRASH_DIR:-.vmgr-trash}/*" \
                    \( "${CAT_FIND_NAME_ARGS[@]}" \) -print0 2>/dev/null)
    fi
}

# Probe a file's metadata into CAT_DURATION, CAT_RES, CAT_DIMS, CAT_CODEC,
# CAT_CAMERA and CAT_DATE (all empty when unavailable or switched off).
# Args: file, media type
_catalog_metadata() {
    local file="$1" type="$2" k v w="" h="" line
    CAT_DURATION=""; CAT_RES=""; CAT_DIMS=""; CAT_CODEC=""; CAT_CAMERA=""; CAT_DATE=""
    [[ "$CATALOG_INCLUDE_METADATA" == true ]] || return 0

    case "$type" in
        video|audio)
            command -v ffprobe >/dev/null 2>&1 || return 0
            local sel="v:0"; [[ "$type" == audio ]] && sel="a:0"
            while IFS='=' read -r k v; do
                case "$k" in
                    width) w="$v" ;;
                    height) h="$v" ;;
                    codec_name) CAT_CODEC="$v" ;;
                    duration) CAT_DURATION="$v" ;;
                esac
            done < <(ffprobe -v error -select_streams "$sel" \
                        -show_entries stream=width,height,codec_name:format=duration \
                        -of default=nw=1 "$file" 2>/dev/null)
            [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] && CAT_RES="${w}x${h}"
            [[ "$CAT_DURATION" == "N/A" ]] && CAT_DURATION=""
            ;;
        image)
            if command -v exiftool >/dev/null 2>&1; then
                line="$(exiftool -f -p '$ImageWidth|$ImageHeight|$Model|$DateTimeOriginal' "$file" 2>/dev/null | head -n 1)"
                IFS='|' read -r w h CAT_CAMERA CAT_DATE <<< "$line"
                [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] && CAT_DIMS="${w}x${h}"
                [[ "$CAT_CAMERA" == "-" ]] && CAT_CAMERA=""
                [[ "$CAT_DATE" == "-" ]] && CAT_DATE=""
            elif command -v identify >/dev/null 2>&1; then
                CAT_DIMS="$(identify -format '%wx%h' "${file}[0]" 2>/dev/null | head -n 1)"
                [[ "$CAT_DIMS" =~ ^[0-9]+x[0-9]+$ ]] || CAT_DIMS=""
            fi
            ;;
    esac
    return 0
}

################################################################################
# CATALOG OPERATIONS
################################################################################

# Catalog a drive (or any folder on one): index every media file, with size,
# modification time, hash and metadata. Incremental: a file whose size and
# modification time are unchanged keeps its record without being hashed or
# probed again. Files that disappeared from the scanned folder are removed; a
# scan only ever touches records under the folder it scanned.
# Args: path [recursive=true]
catalog_drive() {
    local path="$1"
    local recursive="${2:-true}"

    _catalog_require_jq || return 1
    if [[ ! -d "$path" ]]; then
        log_error "Directory not found: $path"
        return 1
    fi

    _catalog_find_args
    if [[ ${#CAT_FIND_NAME_ARGS[@]} -eq 0 ]]; then
        log_error "Nothing to catalog: video, image and audio cataloging are all switched off"
        return 1
    fi

    init_catalog_db
    path="$(cd "$path" && pwd -P)"

    local mount_point drive_id drive_label drive_type prefix
    mount_point="$(catalog_mount_point "$path")"
    if ! _catalog_drive_info "$mount_point"; then
        log_error "Could not identify the drive for: $path"
        return 1
    fi
    drive_id="$CAT_ID"; drive_label="$CAT_LABEL"; drive_type="$CAT_TYPE"
    # (a mount point of "/" needs its trailing slash dropped before stripping)
    # (on macOS the data volume is mounted at /System/Volumes/Data but paths start at /Users:
    #  a path that is not textually under the mount point is stored without its leading slash)
    local mount_base="${mount_point%/}"
    if [[ "$path" == "$mount_point" ]]; then
        prefix=""
    elif [[ "$path" == "$mount_base"/* ]]; then
        prefix="${path#"$mount_base"/}/"
    else
        prefix="${path#/}/"
    fi

    log_info "Cataloging $drive_label ($drive_type): $path"

    local work
    work="$(mktemp -d)" || { log_error "Could not create a temporary directory"; return 1; }
    : > "$work/keep"; : > "$work/todo"

    # What the catalog already knows about this part of the drive
    _catalog_known_index "$drive_id" "$prefix" > "$work/known"

    # The listing can take minutes on a big drive: run it in the background and show
    # how many media files it has found so far.
    if [[ -t 1 ]]; then
        _catalog_inventory "$path" "$recursive" > "$work/inventory" &
        local lpid=$! found=0
        while kill -0 "$lpid" 2>/dev/null; do
            found="$(wc -l < "$work/inventory" 2>/dev/null | tr -d ' ')"
            _catalog_status "Looking for media files...  ${found:-0} found"
            sleep 0.3
        done
        wait "$lpid" 2>/dev/null
        progress_break
    else
        _catalog_inventory "$path" "$recursive" > "$work/inventory"
    fi

    # Sort every file into "unchanged" or "needs work" in one awk pass (a file is
    # unchanged when its size and modification time match the catalog's record and,
    # if hashing is on, it already has a hash).
    local need_hash=0
    [[ "$CATALOG_INCLUDE_HASH" == true ]] && need_hash=1
    local added updated unchanged removed skipped total
    local relpath ext hash size mtime now
    now="$(_catalog_now)"
    read -r added updated unchanged removed skipped total < <(LC_ALL=C awk -F'\t' \
        -v prefix="$prefix" -v needhash="$need_hash" -v known="$work/known" \
        -v keepf="$work/keep" -v todof="$work/todo" '
        BEGIN {
            US = "\037"
            while ((getline line < known) > 0) {
                n = split(line, f, US)
                if (n < 3) continue
                ks[f[1]] = f[2]; km[f[1]] = f[3]; kh[f[1]] = (n >= 4 ? f[4] : "")
            }
            close(known)
        }
        {
            if (NF != 3 || $2 !~ /^[0-9]+$/ || $3 !~ /^[0-9]+(\.[0-9]*)?$/ || index($1, US)) { bad++; next }
            total++
            rel = $1; sz = $2; mt = $3; sub(/\..*$/, "", mt)
            rp = prefix rel
            seen[rp] = 1
            if ((rp in ks) && ks[rp] == sz && km[rp] == mt && (needhash != 1 || kh[rp] != "")) {
                print rp > keepf; same++; next
            }
            if (rp in ks) upd++; else add++
            print rel US sz US mt > todof
        }
        END {
            for (k in ks) if (!(k in seen)) rem++
            printf "%d %d %d %d %d %d\n", add + 0, upd + 0, same + 0, rem + 0, bad + 0, total + 0
        }' "$work/inventory")
    log_verbose "Found $total media file(s) to look at"

    STATS[files_processed]=$(( STATS[files_processed] + total ))
    STATS[catalog_added]=$(( ${STATS[catalog_added]:-0} + added ))
    STATS[catalog_updated]=$(( ${STATS[catalog_updated]:-0} + updated ))
    STATS[catalog_removed]=$(( ${STATS[catalog_removed]:-0} + removed ))
    STATS[catalog_unchanged]=$(( ${STATS[catalog_unchanged]:-0} + unchanged ))
    (( skipped > 0 )) && log_warning "Skipped $skipped line(s) of the file list: a name with a newline or tab in it cannot be cataloged"

    if [[ "$DRY_RUN" == true ]]; then
        STATS[files_previewed]=$(( ${STATS[files_previewed]:-0} + added + updated ))
        log_info "[DRY RUN] Would catalog: $added new, $updated updated, $removed removed, $unchanged unchanged"
        rm -rf "$work"
        return 0
    fi

    # Phase 2: hash everything that needs it, many files per process
    CAT_HASHES=()
    local todo_count=$(( added + updated ))
    if [[ "$DRY_RUN" != true && "$CATALOG_INCLUDE_HASH" == true && $todo_count -gt 0 ]]; then
        LC_ALL=C awk -F'\037' -v p="$path/" '{ print p $1 }' "$work/todo" | tr '\n' '\0' > "$work/hashlist"
        _catalog_hash_files "$work/hashlist" "$todo_count"
    fi

    # Phase 3: build the records (metadata, when switched on, costs one probe per file)
    local total_todo=$todo_count i=0 vanished=0 build_start=$SECONDS
    while IFS="$_CAT_SEP" read -r rel size mtime; do
        i=$(( i + 1 ))
        # a file that disappeared since the listing (or a name that did not parse) is skipped
        if [[ ! -f "$path/$rel" ]]; then vanished=$(( vanished + 1 )); continue; fi
        relpath="${prefix}${rel}"
        ext="${rel##*.}"; [[ "$rel" == *.* ]] || ext=""
        _catalog_media_type_set "$ext"
        hash=""
        if [[ "$CATALOG_INCLUDE_HASH" == true ]]; then
            hash="${CAT_HASHES["$path/$rel"]-}"
            [[ -n "$hash" ]] || hash="$(calculate_file_hash "$path/$rel")"   # the rare file the batch missed
        fi
        _catalog_metadata "$path/$rel" "$CAT_TYPE"

        printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
            "$relpath" "$size" "$mtime" "$hash" "$CAT_TYPE" "${ext,,}" \
            "$CAT_DURATION" "$CAT_RES" "$CAT_DIMS" "$CAT_CODEC" "$CAT_CAMERA" "$CAT_DATE"

        _catalog_tick "$i" "$total_todo" "$([[ "$CATALOG_INCLUDE_METADATA" == true ]] && echo "Reading metadata" || echo "Preparing records")" "${rel##*/}" "$build_start"
    done < "$work/todo" > "$work/new"
    progress_break
    (( vanished > 0 )) && log_verbose "$vanished file(s) vanished while scanning"

    local drive_known=false
    jq -e --arg d "$drive_id" '.drives[] | select(.drive_id == $d)' "$CATALOG_DRIVES_DB" >/dev/null 2>&1 && drive_known=true

    if (( added + updated + removed == 0 )) && $drive_known; then
        # Nothing changed: the catalog file is left alone, only the drive's timestamps move
        jq --arg id "$drive_id" --arg now "$now" '
            (.drives[] | select(.drive_id == $id)) |= (.last_seen = $now | .last_scanned = $now)
            | .last_updated = $now' "$CATALOG_DRIVES_DB" > "$work/drives.json" \
            && _catalog_commit "$CATALOG_DRIVES_DB" "$work/drives.json"
        rm -rf "$work"
        log_success "Catalog is up to date: ${unchanged} file(s) unchanged"
        return 0
    fi

    # Merge into the catalog as a text pass: keep the records of other drives and
    # folders and this folder's unchanged records, drop the rest of this folder's
    # records, add the new ones. Nothing is parsed, so memory stays small however
    # large the catalog is.
    _catalog_status "Updating the catalog..."
    jq -R -c --arg d "$drive_id" --arg now "$now" '
        split("\u001f") | {
            video_id: ($d + ":" + .[0]),
            drive_id: $d,
            filename: (.[0] | split("/") | .[-1]),
            relative_path: .[0],
            media_type: .[4],
            extension: .[5],
            file_size: (.[1] | tonumber),
            mtime: (.[2] | tonumber),
            hash: (.[3] | if . == "" then null else . end),
            duration: (.[6] | (try tonumber catch null)),
            resolution: (.[7] | if . == "" then null else . end),
            dimensions: (.[8] | if . == "" then null else . end),
            codec: (.[9] | if . == "" then null else . end),
            camera: (.[10] | if . == "" then null else . end),
            date_taken: (.[11] | if . == "" then null else . end),
            last_scanned: $now
        }' "$work/new" > "$work/new.ndjson" || { log_error "Could not build the new records"; rm -rf "$work"; return 1; }

    {
        LC_ALL=C awk -v d="$drive_id" -v p="$prefix" -v keepf="$work/keep" "
            $_CAT_AWK_UNESCAPE"'
            BEGIN { while ((getline l < keepf) > 0) k[l] = 1; close(keepf); needle = "\"drive_id\":\"" d "\"" }
            /^\{"video_id"/ {
                line = $0; sub(/,$/, "", line)
                if (index(line, needle) == 0 || !match(line, /"relative_path":"([^"\\]|\\.)*"/)) { print line; next }
                rel = unescape(substr(line, RSTART + 17, RLENGTH - 18))
                if (substr(rel, 1, length(p)) != p) { print line; next }
                if (rel in k) print line
            }' "$CATALOG_DB"
        cat "$work/new.ndjson"
    } | sed '$!s/$/,/' > "$work/records"
    {
        echo '{"videos":['
        cat "$work/records"
        printf '],"last_updated":"%s","version":"1.0"}\n' "$now"
    } > "$work/db.json"
    _catalog_commit "$CATALOG_DB" "$work/db.json" || {
        log_error "Could not update the catalog database"
        rm -rf "$work"
        return 1
    }

    progress_break
    # Drive record: totals recomputed from the catalog
    local count size_total
    read -r count size_total < <(_catalog_drive_totals "$drive_id")
    jq --arg id "$drive_id" --arg dlabel "$drive_label" --arg dtype "$drive_type" --arg mp "$mount_point" \
       --arg now "$now" --argjson count "${count:-0}" --argjson size "${size_total:-0}" '
        ((.drives[] | select(.drive_id == $id) | .first_seen) // $now) as $first
        | .drives = ((.drives | map(select(.drive_id != $id))) + [{
            drive_id: $id, drive_label: $dlabel, drive_type: $dtype, mount_point: $mp,
            first_seen: $first, last_seen: $now, last_scanned: $now,
            file_count: $count, total_size: $size }])
        | .last_updated = $now' "$CATALOG_DRIVES_DB" > "$work/drives.json" \
        && _catalog_commit "$CATALOG_DRIVES_DB" "$work/drives.json" || {
            log_error "Could not update the drive list"
            rm -rf "$work"
            return 1
        }

    rm -rf "$work"
    catalog_prune_offline

    log_success "Catalog updated: ${added} new, ${updated} updated, ${removed} removed, ${unchanged} unchanged"
    return 0
}

# Forget drives that have been offline longer than CATALOG_OFFLINE_RETENTION days
# (0 keeps them forever). A drive that is online right now is marked as seen first.
catalog_prune_offline() {
    [[ -f "$CATALOG_DRIVES_DB" ]] || return 0
    local days="${CATALOG_OFFLINE_RETENTION:-0}" id mp now
    now="$(_catalog_now)"

    local -a online=()
    while IFS="$_CAT_SEP" read -r id mp; do
        _catalog_mount_online "$mp" && online+=("$id")
    done < <(jq -r '.drives[] | [.drive_id, .mount_point] | join("\u001f")' "$CATALOG_DRIVES_DB" 2>/dev/null)

    local online_json="[]"
    (( ${#online[@]} > 0 )) && online_json="$(printf '%s\n' "${online[@]}" | jq -R . | jq -s .)"

    local tmp_d tmp_c
    tmp_d="$(mktemp)"; tmp_c="$(mktemp)"
    jq --argjson online "$online_json" --arg now "$now" --argjson days "$days" '
        .drives |= map(if (.drive_id as $i | $online | map(. == $i) | any) then .last_seen = $now else . end)
        | if $days > 0 then
              .drives |= map(select((.drive_id as $i | $online | map(. == $i) | any)
                                    or ((now - ((.last_seen // $now) | fromdateiso8601)) <= ($days * 86400))))
          else . end' "$CATALOG_DRIVES_DB" > "$tmp_d" || { rm -f "$tmp_d" "$tmp_c"; return 1; }

    # Only when a drive was actually forgotten does the (large) catalog file need rewriting
    local before after
    before="$(jq '.drives | length' "$CATALOG_DRIVES_DB")"
    after="$(jq '.drives | length' "$tmp_d")"
    if [[ "$after" != "$before" ]]; then
        jq -r --slurpfile drives "$tmp_d" '
            ($drives[0].drives | map(.drive_id)) as $keep
            | .videos |= map(select(.drive_id as $i | $keep | map(. == $i) | any)) | '"$_CAT_FMT" "$CATALOG_DB" > "$tmp_c" || { rm -f "$tmp_d" "$tmp_c"; return 1; }
        _catalog_commit "$CATALOG_DB" "$tmp_c"
    fi
    _catalog_commit "$CATALOG_DRIVES_DB" "$tmp_d"
    rm -f "$tmp_d" "$tmp_c"
}

# awk function text: undo the JSON string escapes jq writes in a path (\\ and \" and
# \/). Other escapes (control characters) are left as they are, so such a file simply
# looks new on the next scan; that is harmless.
_CAT_AWK_UNESCAPE='
    function unescape(s,   out, i, n, c) {
        if (index(s, "\\") == 0) return s            # the common case: nothing to undo
        out = ""; n = length(s)
        for (i = 1; i <= n; i++) {
            c = substr(s, i, 1)
            if (c == "\\" && i < n) {
                i++; c = substr(s, i, 1)
                if (c == "\"" || c == "\\" || c == "/") out = out c; else out = out "\\" c
            } else out = out c
        }
        return out
    }'

# Print "relative_path US size US mtime US hash" for this drive's records under a
# folder prefix, straight from the catalog text (no JSON parsing). Args: drive_id, prefix
_catalog_known_index() {
    LC_ALL=C grep -F "\"drive_id\":\"$1\"" "$CATALOG_DB" 2>/dev/null | LC_ALL=C awk -v p="$2" "
        $_CAT_AWK_UNESCAPE"'
        /^\{"video_id"/ {
            if (!match($0, /"relative_path":"([^"\\]|\\.)*"/)) next
            rel = unescape(substr($0, RSTART + 17, RLENGTH - 18))
            if (substr(rel, 1, length(p)) != p) next
            size = 0; mt = 0; h = ""
            if (match($0, /"file_size":[0-9]+/)) size = substr($0, RSTART + 12, RLENGTH - 12)
            if (match($0, /"mtime":[0-9]+/)) mt = substr($0, RSTART + 8, RLENGTH - 8)
            if (match($0, /"hash":"[0-9a-fA-F]+"/)) h = substr($0, RSTART + 8, RLENGTH - 9)
            printf "%s\037%s\037%s\037%s\n", rel, size, mt, h
        }'
}

# "count bytes" for one drive, read from the one-record-per-line catalog with
# grep and awk (no JSON parsing).
_catalog_drive_totals() {
    LC_ALL=C grep -F "\"drive_id\":\"$1\"" "$CATALOG_DB" 2>/dev/null | LC_ALL=C awk '
        { if (match($0, /"file_size":[0-9]+/)) { n++; b += substr($0, RSTART + 12, RLENGTH - 12) } }
        END { printf "%d %.0f\n", n, b }'
}

# "video 120 · image 3" for one drive (media types and their counts).
_catalog_type_counts() {
    LC_ALL=C grep -F "\"drive_id\":\"$1\"" "$CATALOG_DB" 2>/dev/null | LC_ALL=C awk '
        { if (match($0, /"media_type":"[a-z]+"/)) c[substr($0, RSTART + 14, RLENGTH - 15)]++ }
        END { for (t in c) print t, c[t] }' | sort | awk '{ printf "%s%s %d", (NR > 1 ? " · " : ""), $1, $2 } END { if (NR) print "" }'
}

# "drives files bytes" for the whole catalog (0 0 0 when empty or jq is missing).
catalog_stats() {
    command -v jq >/dev/null 2>&1 && [[ -f "$CATALOG_DRIVES_DB" ]] || { echo "0 0 0"; return; }
    # The drive records carry their own totals, so the (large) catalog file is not read
    jq -r '"\(.drives | length) \([.drives[].file_count] | add // 0) \([.drives[].total_size] | add // 0)"' "$CATALOG_DRIVES_DB" 2>/dev/null || echo "0 0 0"
}

# Days since a drive's last scan, per drive, for drives scanned at least
# CATALOG_STALE_DAYS ago (or never). One line per drive: id, label, days ("" = never).
catalog_stale_drives() {
    [[ -f "$CATALOG_DRIVES_DB" ]] && command -v jq >/dev/null 2>&1 || return 0
    jq -r --argjson limit "${CATALOG_STALE_DAYS:-30}" '
        .drives[]
        | (if (.last_scanned // "") == "" then null
           else ((now - (.last_scanned | fromdateiso8601? // now)) / 86400 | floor) end) as $d
        | select($d == null or $d >= $limit)
        | [.drive_id, .drive_label, ($d // "" | tostring)] | join("\u001f")' "$CATALOG_DRIVES_DB" 2>/dev/null
}

# List cataloged drives with their status and totals.
list_cataloged_drives() {
    _catalog_require_jq || return 1
    init_catalog_db

    if [[ "$(jq '.drives | length' "$CATALOG_DRIVES_DB")" == "0" ]]; then
        log_info "No drives cataloged yet. Use Scan & Catalog Drive to add one."
        return 0
    fi

    local id label type mp count size scanned status dot color kinds stale
    while IFS="$_CAT_SEP" read -r id label type mp count size scanned; do
        if _catalog_mount_online "$mp"; then
            status="online"; dot="${UI_DOT_ON:-*}"; color="${UI_OK:-$COLOR_GREEN}"
        else
            status="offline"; dot="${UI_DOT_OFF:-o}"; color="${UI_DIM:-$COLOR_RED}"
        fi
        kinds="$(_catalog_type_counts "$id")"
        printf '  %s%s%s %s%s%s  %s%s%s\n' "$color" "$dot" "$COLOR_RESET" "$COLOR_BOLD" "$label" "$COLOR_RESET" "$color" "$status" "$COLOR_RESET"
        printf '      %s%s %s %s file(s) %s %s%s\n' "${UI_DIM:-}" "$type" "${UI_SEP:-·}" "$count" "${UI_SEP:-·}" "$(format_bytes "$size")" "$COLOR_RESET"
        [[ -n "$kinds" ]] && printf '      %s%s%s\n' "${UI_DIM:-}" "$kinds" "$COLOR_RESET"
        printf '      %s%s %s scanned %s%s\n' "${UI_DIM:-}" "$mp" "${UI_SEP:-·}" "${scanned:-never}" "$COLOR_RESET"
        stale="$(catalog_stale_drives | awk -F"$_CAT_SEP" -v i="$id" '$1 == i { print ($3 == "" ? "never scanned" : $3 " days ago"); exit }')"
        [[ -n "$stale" ]] && printf '      %s%s Out of date: %s%s\n' "${UI_WARN:-$COLOR_YELLOW}" "${SYMBOL_WARN:-!}" "$stale" "$COLOR_RESET"
        echo ""
    done < <(jq -r '.drives | sort_by(.drive_label | ascii_downcase)[]
        | [.drive_id, .drive_label, .drive_type, .mount_point, (.file_count | tostring), (.total_size | tostring), (.last_scanned // "")]
        | join("\u001f")' "$CATALOG_DRIVES_DB")
    return 0
}

# Search the catalog. The term matches file names and folders (case-insensitive),
# a hash prefix (6+ hex characters), an exact resolution or dimensions such as
# 1920x1080, or a camera name. Files on drives that are offline are included.
# Args: term [all|video|image|audio]
# Parse "500", "10K", "1.5G"... into bytes (binary units). Prints nothing and
# returns 1 when the text is not a size.
_catalog_parse_size() {
    LC_ALL=C awk -v s="$1" 'BEGIN {
        if (!match(s, /^[0-9]+(\.[0-9]+)?[KkMmGgTt]?[Bb]?$/)) exit 1
        u = toupper(s); sub(/B$/, "", u)
        m = 1; c = substr(u, length(u))
        if (c == "K") m = 1024; else if (c == "M") m = 1024^2; else if (c == "G") m = 1024^3; else if (c == "T") m = 1024^4
        if (m > 1) u = substr(u, 1, length(u) - 1)
        printf "%.0f\n", u * m }'
}

# Parse "90", "90s", "10m", "2h" into seconds. Returns 1 when not a duration.
_catalog_parse_duration() {
    LC_ALL=C awk -v s="$1" 'BEGIN {
        if (!match(s, /^[0-9]+(\.[0-9]+)?[smhSMH]?$/)) exit 1
        c = tolower(substr(s, length(s))); m = 1
        if (c == "m") m = 60; else if (c == "h") m = 3600
        if (c ~ /[smh]/) s = substr(s, 1, length(s) - 1)
        printf "%.0f\n", s * m }'
}

# Parse "30d", "2w", "6m", "1y" (a bare number is days) into days. Returns 1 when not an age.
_catalog_parse_age() {
    LC_ALL=C awk -v s="$1" 'BEGIN {
        if (!match(s, /^[0-9]+[dDwWmMyY]?$/)) exit 1
        c = tolower(substr(s, length(s))); m = 1
        if (c == "w") m = 7; else if (c == "m") m = 30; else if (c == "y") m = 365
        if (c ~ /[dwmy]/) s = substr(s, 1, length(s) - 1)
        printf "%d\n", s * m }'
}

# Search the catalog by name, hash, resolution or camera, optionally narrowed by
# CATALOG_FILTER_MIN_SIZE / _MAX_SIZE (bytes), _NEWER_DAYS / _OLDER_DAYS (by file
# modification time) and _MIN_DURATION / _MAX_DURATION (seconds, needs metadata).
# With at least one filter set the search term may be empty.
search_catalog() {
    local term="$1"
    local media_filter="${2:-all}"

    _catalog_require_jq || return 1
    init_catalog_db

    local f_min_size="${CATALOG_FILTER_MIN_SIZE:-null}" f_max_size="${CATALOG_FILTER_MAX_SIZE:-null}"
    local f_newer="${CATALOG_FILTER_NEWER_DAYS:-null}" f_older="${CATALOG_FILTER_OLDER_DAYS:-null}"
    local f_min_dur="${CATALOG_FILTER_MIN_DURATION:-null}" f_max_dur="${CATALOG_FILTER_MAX_DURATION:-null}"
    local filtered=false
    [[ "$f_min_size$f_max_size$f_newer$f_older$f_min_dur$f_max_dur" != "nullnullnullnullnullnull" ]] && filtered=true

    if [[ -z "$term" && "$filtered" == false ]]; then
        log_warning "Nothing to search for"
        return 1
    fi

    local online_json
    online_json="$(_catalog_online_json)"

    # Pre-filter: the catalog has one record per line, so grep can cut it down to the
    # records that mention the term anywhere (a superset of the real matches) before
    # jq does the exact matching. A term with a quote or backslash is written
    # differently inside the JSON, so it skips the pre-filter.
    local tmp cand
    tmp="$(mktemp)"; cand="$(mktemp)"
    if [[ -z "$term" || "$term" == *\"* || "$term" == *\\* ]]; then
        grep '^{"video_id"' "$CATALOG_DB" | sed 's/,$//' > "$cand"
    else
        grep -iF -- "$term" "$CATALOG_DB" | grep '^{"video_id"' | sed 's/,$//' > "$cand"
    fi
    jq -r -s --arg t "$term" --arg mt "$media_filter" --argjson limit "$CATALOG_SEARCH_LIMIT" \
          --argjson online "$online_json" --slurpfile drives "$CATALOG_DRIVES_DB" \
          --argjson minsz "$f_min_size" --argjson maxsz "$f_max_size" --argjson newer "$f_newer" --argjson older "$f_older" \
          --argjson mindur "$f_min_dur" --argjson maxdur "$f_max_dur" '
        ($t | ascii_downcase) as $q
        | now as $now
        | ($drives[0].drives | map({(.drive_id): .drive_label}) | add // {}) as $labels
        | [.[]
           | select($mt == "all" or .media_type == $mt)
           | select($minsz == null or .file_size >= $minsz)
           | select($maxsz == null or .file_size <= $maxsz)
           | select($newer == null or (.mtime // 0) >= ($now - $newer * 86400))
           | select($older == null or (.mtime // 0) <= ($now - $older * 86400))
           | select($mindur == null or ((.duration // -1) >= $mindur))
           | select($maxdur == null or (.duration != null and .duration <= $maxdur))
           | select($q == "" or ((.relative_path | ascii_downcase) | contains($q))
                    or (($q | test("^[0-9a-f]{6,}$")) and ((.hash // "") | startswith($q)))
                    or ((.resolution // "") == $q) or ((.dimensions // "") == $q)
                    or ((.camera // "" | ascii_downcase) | contains($q)))]
        | sort_by(.relative_path | ascii_downcase) as $all
        | ("TOTAL\u001f" + ($all | length | tostring)),
          ($all[:$limit][] | [($labels[.drive_id] // "unknown"),
                              (if $online[.drive_id] then "online" else "offline" end),
                              .relative_path, (.file_size | tostring), .media_type, (.resolution // .dimensions // ""),
                              (if .duration then (.duration | floor | tostring) else "" end)]
                            | join("\u001f"))' "$cand" > "$tmp" 2>/dev/null
    rm -f "$cand"

    local total=0 label state rel size mtype res dur shown=0
    while IFS="$_CAT_SEP" read -r label state rel size mtype res dur; do
        if [[ "$label" == "TOTAL" ]]; then total="$state"; continue; fi
        shown=$(( shown + 1 ))
        local dot color
        if [[ "$state" == online ]]; then dot="${UI_DOT_ON:-*}"; color="${UI_OK:-$COLOR_GREEN}"
        else dot="${UI_DOT_OFF:-o}"; color="${UI_DIM:-$COLOR_RED}"; fi
        printf '  %s%s%s %s%s%s  %s\n' "$color" "$dot" "$COLOR_RESET" "${UI_ACCENT:-$COLOR_CYAN}" "$label" "$COLOR_RESET" "$rel"
        [[ -n "$dur" ]] && dur="$(printf '%d:%02d:%02d' $(( dur / 3600 )) $(( dur % 3600 / 60 )) $(( dur % 60 )))"
        printf '      %s%s %s %s%s%s%s\n' "${UI_DIM:-}" "$mtype" "${UI_SEP:-·}" "$(format_bytes "$size")" "${res:+ ${UI_SEP:-·} $res}" "${dur:+ ${UI_SEP:-·} $dur}" "$COLOR_RESET"
    done < "$tmp"
    rm -f "$tmp"

    echo ""
    if (( total == 0 )); then
        log_info "No matches for \"$term\""
    elif (( total > shown )); then
        log_info "Showing $shown of $total matches; narrow the search to see the rest"
    else
        log_info "$total match(es)"
    fi
    return 0
}

# Every hashed record as "hash US drive US video_id US relative_path US size US mtime US media_type",
# sorted by hash (stable, so records of one hash keep their catalog order). Read from
# the one-record-per-line catalog with awk; no JSON parsing.
_catalog_hash_index() {
    LC_ALL=C grep -F '"hash":"' "$CATALOG_DB" 2>/dev/null | LC_ALL=C awk "
        $_CAT_AWK_UNESCAPE"'
        # The raw text of a string value ("key" includes the opening quote), found with
        # index() instead of a regex: much faster than backtracking on long records.
        function strval(key,   p, rest, q, i, n) {
            p = index($0, key)
            if (!p) return ""
            rest = substr($0, p + length(key))
            q = index(rest, "\"")
            while (q > 1) {                                 # skip quotes preceded by a backslash
                n = 0; i = q - 1
                while (i > 0 && substr(rest, i, 1) == "\\") { n++; i-- }
                if (n % 2 == 0) break
                i = index(substr(rest, q + 1), "\"")
                if (!i) return ""
                q += i
            }
            return q ? substr(rest, 1, q - 1) : ""
        }
        function numval(key,   p, rest) {
            p = index($0, key)
            if (!p) return 0
            rest = substr($0, p + length(key))
            return match(rest, /^[0-9]+/) ? substr(rest, 1, RLENGTH) : 0
        }
        /^\{"video_id"/ {
            h = strval("\"hash\":\"")
            if (h == "") next
            drive = unescape(strval("\"drive_id\":\""))
            vid   = unescape(strval("\"video_id\":\""))
            rel   = unescape(strval("\"relative_path\":\""))
            size  = numval("\"file_size\":")
            mt    = numval("\"mtime\":")
            media = strval("\"media_type\":\"")
            printf "%s\037%s\037%s\037%s\037%s\037%s\037%s\n", h, drive, vid, rel, size, mt, media
        }' | LC_ALL=C sort -s -t "$_CAT_SEP" -k1,1
}

# Groups of identical files (same hash) read from _catalog_hash_index. A copy on drive X
# is removable when the same hash exists on another drive that is online now.
# Args: mode (plan|count), target drive (plan only)
#   plan:  one line per removable copy on the target drive:
#          video_id, relative_path, size, mtime, keeper_drive, keeper_path, keeper_size, keeper_mtime
#   count: "drive_id US copies US bytes" for every online drive with removable copies
_catalog_duplicate_groups() {
    local mode="$1" target="$2" on="" id
    while IFS= read -r id; do on+="$_CAT_SEP$id"; done < <(_catalog_online_json | jq -r 'keys[]')
    on+="$_CAT_SEP"
    _catalog_hash_index | LC_ALL=C awk -F"$_CAT_SEP" -v mode="$mode" -v target="$target" -v on="$on" '
        function online(d) { return index(on, "\037" d "\037") > 0 }
        function flush(   i, j, k, x) {
            if (n < 2) { n = 0; return }
            for (i = 1; i <= n; i++) {
                x = D[i]
                if (mode == "plan" ? x != target : !online(x)) continue
                k = 0
                for (j = 1; j <= n; j++) if (D[j] != x && online(D[j])) { k = j; break }
                if (!k) continue
                if (mode == "plan")
                    printf "%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\n", V[i], R[i], S[i], M[i], D[k], R[k], S[k], M[k]
                else { cnt[x]++; bytes[x] += S[i] }
            }
            n = 0
        }
        { # string compare: a hash such as 61e5002e8885 would otherwise be read as a number
          if (($1 "") != cur) { flush(); cur = $1 "" }
          n++; D[n] = $2; V[n] = $3; R[n] = $4; S[n] = $5; M[n] = $6 }
        END { flush(); if (mode == "count") for (x in cnt) printf "%s\037%d\037%d\n", x, cnt[x], bytes[x] }'
}

# Copies on drive $1 that have an identical copy (same hash) on another drive that
# is online now. One line per copy, fields separated by US:
#   video_id, relative_path, size, mtime, keeper_drive_id, keeper_relative_path, keeper_size, keeper_mtime
_catalog_duplicate_plan() {
    _catalog_duplicate_groups plan "$1"
}

# Online drives that hold removable duplicate copies, one per line:
#   drive_id, label, mount_point, copies, bytes
catalog_duplicate_candidates() {
    _catalog_require_jq || return 1
    init_catalog_db
    local id label mp copies bytes
    local -A ncopies=() nbytes=()
    while IFS="$_CAT_SEP" read -r id copies bytes; do
        ncopies["$id"]="$copies"; nbytes["$id"]="$bytes"
    done < <(_catalog_duplicate_groups count)
    while IFS="$_CAT_SEP" read -r id label mp; do
        (( ${ncopies[$id]:-0} > 0 )) || continue
        printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$id" "$label" "$mp" "${ncopies[$id]}" "${nbytes[$id]}"
    done < <(jq -r '.drives | sort_by(.drive_label | ascii_downcase)[] | [.drive_id, .drive_label, .mount_point] | join("\u001f")' "$CATALOG_DRIVES_DB")
}

# Move the duplicate copies on one drive to that drive's trash (undoable). A copy
# is moved only when an identical copy exists on another drive that is online, and
# both files still match the size and modification time the catalog recorded.
# Args: drive_id
catalog_trash_duplicates() {
    local drive="$1"
    _catalog_require_jq || return 1
    init_catalog_db

    local root label
    root="$(jq -r --arg d "$drive" '.drives[] | select(.drive_id == $d) | .mount_point' "$CATALOG_DRIVES_DB")"
    label="$(jq -r --arg d "$drive" '.drives[] | select(.drive_id == $d) | .drive_label' "$CATALOG_DRIVES_DB")"
    if [[ -z "$root" ]]; then
        log_error "Unknown drive"
        return 1
    fi
    if ! _catalog_mount_online "$root"; then
        log_error "$label is not online"
        return 1
    fi
    if [[ "$DRY_RUN" != true && ! -w "$root" ]]; then
        log_error "Cannot create a trash on $label: $root is not writable"
        return 1
    fi

    local -A mp=()
    local id m
    while IFS="$_CAT_SEP" read -r id m; do mp["$id"]="$m"; done < <(jq -r '.drives[] | [.drive_id, .mount_point] | join("\u001f")' "$CATALOG_DRIVES_DB")

    local work stamp vid rel size mtime kdrive krel ksize kmtime file keeper st kst
    local moved=0 bytes=0 previewed=0 changed=0 keeper_gone=0 missing=0 failed=0
    work="$(mktemp -d)" || return 1
    : > "$work/removed"
    stamp="$(date +%Y%m%d-%H%M%S)"

    while IFS="$_CAT_SEP" read -r vid rel size mtime kdrive krel ksize kmtime; do
        file="$root/$rel"
        keeper="${mp["$kdrive"]}/$krel"

        st="$(_catalog_stat "$file")" || { missing=$(( missing + 1 )); log_verbose "Gone since the scan: $rel"; continue; }
        if [[ "${st% *}" != "$size" || "${st#* }" != "$mtime" ]]; then
            changed=$(( changed + 1 )); log_warning "Changed since the scan, left alone (rescan first): $rel"; continue
        fi
        kst="$(_catalog_stat "$keeper")" || { keeper_gone=$(( keeper_gone + 1 )); log_warning "The other copy is gone, left alone: $rel"; continue; }
        if [[ "${kst% *}" != "$ksize" || "${kst#* }" != "$kmtime" ]]; then
            keeper_gone=$(( keeper_gone + 1 )); log_warning "The other copy changed since the scan, left alone: $rel"; continue
        fi

        if [[ "$DRY_RUN" == true ]]; then
            previewed=$(( previewed + 1 )); bytes=$(( bytes + size ))
            log_info "[DRY RUN] Would move to trash: $rel"
            continue
        fi
        if trash_file "$file" "$root" "$stamp"; then
            moved=$(( moved + 1 )); bytes=$(( bytes + size ))
            printf '%s\n' "$vid" >> "$work/removed"
            log_success "Moved to trash: $rel"
        else
            failed=$(( failed + 1 )); log_error "Could not move to trash: $rel"
        fi
    done < <(_catalog_duplicate_plan "$drive")

    # The moved files are no longer at those paths: drop them from the catalog now.
    # Their records are kept beside the undo log so Undo can put them back.
    if (( moved > 0 )); then
        if [[ -n "${UNDO_CURRENT_LOG:-}" && -f "$UNDO_CURRENT_LOG" ]]; then
            jq -c --rawfile ids "$work/removed" '
                ($ids | split("\n") | map(select(length > 0) | {(.): true}) | add // {}) as $r
                | .videos[] | select($r[.video_id])' "$CATALOG_DB" >> "${UNDO_CURRENT_LOG%.log}.catalog"
        fi
        jq -r --rawfile ids "$work/removed" --arg now "$(_catalog_now)" '
            ($ids | split("\n") | map(select(length > 0) | {(.): true}) | add // {}) as $r
            | .videos |= map(select($r[.video_id] | not)) | .last_updated = $now | '"$_CAT_FMT" "$CATALOG_DB" > "$work/db.json" \
            && _catalog_commit "$CATALOG_DB" "$work/db.json"
        local count size_total
        read -r count size_total < <(_catalog_drive_totals "$drive")
        jq --arg d "$drive" --argjson c "${count:-0}" --argjson s "${size_total:-0}" \
            '(.drives[] | select(.drive_id == $d)) |= (.file_count = $c | .total_size = $s)' "$CATALOG_DRIVES_DB" > "$work/drives.json" \
            && _catalog_commit "$CATALOG_DRIVES_DB" "$work/drives.json"
    fi
    rm -rf "$work"

    STATS[files_trashed]=$(( ${STATS[files_trashed]:-0} + moved ))
    STATS[space_trashed]=$(( ${STATS[space_trashed]:-0} + bytes ))
    STATS[files_previewed]=$(( ${STATS[files_previewed]:-0} + previewed ))
    STATS[files_skipped]=$(( ${STATS[files_skipped]:-0} + changed + keeper_gone + missing ))

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would move $previewed cop$([[ $previewed == 1 ]] && echo y || echo ies) ($(format_bytes "$bytes")) on $label to its trash"
    else
        log_info "$moved moved to the trash of $label ($(format_bytes "$bytes")); $(( changed + keeper_gone + missing )) skipped"
        (( moved > 0 )) && log_info "Undo with Utilities > Undo Last Operation, or empty the trash for good with Utilities > Empty Trash"
    fi
    (( failed == 0 ))
}

# Put catalog records back after an undo restored their files. Only records whose
# file is back in place are re-added, and each drive's totals are refreshed.
# Args: file of removed records (one JSON record per line, as catalog_trash_duplicates writes it)
catalog_restore_records() {
    local side="$1"
    [[ -s "$side" ]] || return 0
    _catalog_require_jq || return 1
    init_catalog_db

    local work; work="$(mktemp -d)" || return 1
    : > "$work/back"; : > "$work/drives"
    local vid drive path
    while IFS="$_CAT_SEP" read -r vid drive path; do
        [[ -e "$path" ]] || continue
        printf '%s\n' "$vid" >> "$work/back"
        printf '%s\n' "$drive" >> "$work/drives"
    done < <(jq -r --slurpfile d "$CATALOG_DRIVES_DB" '
        ($d[0].drives | map({(.drive_id): .mount_point}) | add // {}) as $mp
        | select($mp[.drive_id] != null)
        | [.video_id, .drive_id, ($mp[.drive_id] + "/" + .relative_path)] | join("\u001f")' "$side")

    local restored=0
    if [[ -s "$work/back" ]]; then
        restored=$(wc -l < "$work/back" | tr -d ' ')
        jq -r --rawfile ids "$work/back" --slurpfile add "$side" --arg now "$(_catalog_now)" '
            ($ids | split("\n") | map(select(length > 0) | {(.): true}) | add // {}) as $b
            | (.videos | map({(.video_id): true}) | add // {}) as $have
            | .videos += ($add | map(select($b[.video_id] and ($have[.video_id] | not))))
            | .last_updated = $now | '"$_CAT_FMT" "$CATALOG_DB" > "$work/db.json" \
            && _catalog_commit "$CATALOG_DB" "$work/db.json"
        local d count size_total
        while IFS= read -r d; do
            read -r count size_total < <(_catalog_drive_totals "$d")
            jq --arg d "$d" --argjson c "${count:-0}" --argjson s "${size_total:-0}" \
                '(.drives[] | select(.drive_id == $d)) |= (.file_count = $c | .total_size = $s)' "$CATALOG_DRIVES_DB" > "$work/drives.json" \
                && _catalog_commit "$CATALOG_DRIVES_DB" "$work/drives.json"
        done < <(sort -u "$work/drives")
        log_info "Put $restored record(s) back in the catalog"
    fi
    rm -rf "$work"
}

# Export every catalog record as CSV or JSON for spreadsheets and scripts. Each
# record carries its drive's label. Prints the file path.
# Args: [format csv|json] [output file]. The format defaults to the file's
# extension, then to csv.
catalog_export_data() {
    local format="${1:-}" out="${2:-}"
    if [[ -z "$format" && -n "$out" ]]; then
        case "${out##*.}" in json|JSON) format=json ;; *) format=csv ;; esac
    fi
    format="${format:-csv}"
    if [[ "$format" != csv && "$format" != json ]]; then
        log_error "Unknown export format: $format (use csv or json)"
        return 1
    fi
    _catalog_require_jq || return 1
    init_catalog_db
    out="${out:-$HOME/video-catalog-$(date +%Y%m%d-%H%M%S).$format}"

    local tmp; tmp="$(mktemp)" || return 1
    if [[ "$format" == csv ]]; then
        jq -r --slurpfile drives "$CATALOG_DRIVES_DB" '
            ($drives[0].drives | map({(.drive_id): .drive_label}) | add // {}) as $l
            | ["drive_label","drive_id","relative_path","filename","extension","media_type","file_size","modified","hash","duration","resolution","dimensions","codec","camera","date_taken","last_scanned"],
              (.videos | sort_by([$l[.drive_id] // "", .relative_path])[]
               | [$l[.drive_id], .drive_id, .relative_path, .filename, .extension, .media_type, .file_size,
                  (.mtime | if . then todate else null end), .hash, .duration, .resolution, .dimensions, .codec, .camera, .date_taken, .last_scanned])
            | @csv' "$CATALOG_DB" > "$tmp"
    else
        jq --slurpfile drives "$CATALOG_DRIVES_DB" '
            ($drives[0].drives | map({(.drive_id): .drive_label}) | add // {}) as $l
            | .videos | sort_by([$l[.drive_id] // "", .relative_path])
            | map(. + {drive_label: $l[.drive_id]})' "$CATALOG_DB" > "$tmp"
    fi
    if [[ $? -ne 0 || ! -s "$tmp" ]]; then
        rm -f "$tmp"; log_error "Could not build the export"; return 1
    fi
    mv -f "$tmp" "$out" || { rm -f "$tmp"; return 1; }
    echo "$out"
}

# Write a plain-text report of the catalog. Prints the report path.
# Args: [output file]
catalog_export_report() {
    local out="${1:-$HOME/video-catalog-report-$(date +%Y%m%d-%H%M%S).txt}"
    _catalog_require_jq || return 1
    init_catalog_db

    {
        echo "Video Catalog Report"
        echo "Generated: $(date)"
        echo ""
        echo "=== DRIVES ==="
        jq -r '.drives | sort_by(.drive_label | ascii_downcase)[]
            | "\(.drive_label)  [\(.drive_type)]  \(.mount_point)\n  files: \(.file_count)   size: \(.total_size) bytes   last scanned: \(.last_scanned // "never")"' "$CATALOG_DRIVES_DB"
        echo ""
        echo "=== TOTALS ==="
        # One pass over the catalog for every section below
        jq -r --slurpfile drives "$CATALOG_DRIVES_DB" '
            ($drives[0].drives | map({(.drive_id): .drive_label}) | add // {}) as $l
            | .videos as $v
            | "Files: \($v | length)   Size: \([$v[].file_size] | add // 0) bytes",
              "",
              "By media type:",
              ($v | group_by(.media_type) | map("  \(.[0].media_type): \(length) files, \(map(.file_size) | add) bytes")[]),
              "",
              "By extension (top 15):",
              ($v | group_by(.extension) | map({e: .[0].extension, n: length}) | sort_by(-.n) | .[:15][] | "  .\(.e): \(.n)"),
              "",
              "Largest files (top 10):",
              ($v | sort_by(-.file_size) | .[:10][] | "  \(.file_size) bytes  [\($l[.drive_id] // "unknown")] \(.relative_path)"),
              "",
              "=== DUPLICATES ===",
              ([$v[] | select((.hash // "") != "")] | group_by(.hash) | map(select(length > 1))
               | "Groups: \(length)   Extra copies: \(map(length - 1) | add // 0)   Wasted: \(map((length - 1) * .[0].file_size) | add // 0) bytes")
            ' "$CATALOG_DB"
    } > "$out"

    echo "$out"
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
