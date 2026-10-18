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

# Initialize catalog database
init_catalog_db() {
    if [[ ! -f "$CATALOG_DB" ]]; then
        echo '{"videos":[],"last_updated":"'"$(_catalog_now)"'","version":"1.0"}' > "$CATALOG_DB"
        log_verbose "Created catalog database: $CATALOG_DB"
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

# Candidate drives to offer in the menu: external and Windows drives.
catalog_detect_mounts() {
    local m
    for m in /mnt/[a-z] /media/*/* /run/media/*/* /Volumes/*; do
        _catalog_mount_online "$m" && echo "$m"
    done
}

# Media type from a file extension: video, image, audio or other.
_catalog_media_type() {
    local ext="${1,,}" e
    for e in "${DEFAULT_VIDEO_EXTENSIONS[@]}"; do [[ "$e" == "$ext" ]] && { echo video; return; }; done
    for e in "${DEFAULT_IMAGE_EXTENSIONS[@]}"; do [[ "$e" == "$ext" ]] && { echo image; return; }; done
    for e in "${DEFAULT_AUDIO_EXTENSIONS[@]}"; do [[ "$e" == "$ext" ]] && { echo audio; return; }; done
    echo other
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

# Stream "relative path, size, mtime" for every matching file under $1 as
# NUL-separated fields. $2 = true to recurse. Uses GNU find -printf when it
# exists (one process); otherwise one stat per file.
_catalog_inventory() {
    local dir="$1" recursive="$2"
    local -a depth=()
    [[ "$recursive" == true ]] || depth=(-maxdepth 1)

    if find /dev/null -maxdepth 0 -printf '' 2>/dev/null; then
        find "$dir" "${depth[@]}" -type f ! -path "*/${VMGR_TRASH_DIR:-.vmgr-trash}/*" \
            \( "${CAT_FIND_NAME_ARGS[@]}" \) -printf '%P\0%s\0%T@\0' 2>/dev/null
    else
        local f st
        while IFS= read -r -d '' f; do
            st="$(_catalog_stat "$f")" || continue
            printf '%s\0%s\0%s\0' "${f#"$dir"/}" "${st% *}" "${st#* }"
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

    # What the catalog already knows about this part of the drive
    local -A known_size=() known_mtime=() known_hash=() seen=()
    local rel sz mt hs
    while IFS="$_CAT_SEP" read -r rel sz mt hs; do
        [[ -n "$rel" ]] || continue
        known_size["$rel"]="$sz"; known_mtime["$rel"]="$mt"; known_hash["$rel"]="$hs"
    done < <(jq -r --arg d "$drive_id" --arg p "$prefix" '
        .videos[] | select(.drive_id == $d and (.relative_path | startswith($p)))
        | [.relative_path, (.file_size | tostring), ((.mtime // 0) | tostring), (.hash // "")]
        | join("\u001f")' "$CATALOG_DB" 2>/dev/null)

    local work
    work="$(mktemp -d)" || { log_error "Could not create a temporary directory"; return 1; }
    : > "$work/keep"; : > "$work/new"

    _catalog_inventory "$path" "$recursive" > "$work/inventory"
    local total=$(( $(tr -cd '\0' < "$work/inventory" | wc -c) / 3 ))
    log_verbose "Found $total media file(s) to look at"

    local added=0 updated=0 unchanged=0 removed=0 skipped=0 n=0
    local relpath ext type hash now size mtime
    now="$(_catalog_now)"

    while IFS= read -r -d '' rel && IFS= read -r -d '' size && IFS= read -r -d '' mtime; do
        n=$(( n + 1 ))
        mtime="${mtime%.*}"
        relpath="${prefix}${rel}"

        if [[ "$relpath" == *$'\n'* || "$relpath" == *"$_CAT_SEP"* ]]; then
            skipped=$(( skipped + 1 )); continue
        fi
        seen["$relpath"]=1

        if [[ -n "${known_size["$relpath"]+x}" && "${known_size["$relpath"]}" == "$size" \
              && "${known_mtime["$relpath"]}" == "$mtime" \
              && ( "$CATALOG_INCLUDE_HASH" != true || -n "${known_hash["$relpath"]}" ) ]]; then
            printf '%s\n' "$relpath" >> "$work/keep"
            unchanged=$(( unchanged + 1 ))
            continue
        fi

        if [[ -n "${known_size["$relpath"]+x}" ]]; then updated=$(( updated + 1 )); else added=$(( added + 1 )); fi
        [[ "$DRY_RUN" == true ]] && continue

        ext="${rel##*.}"; [[ "$rel" == *.* ]] || ext=""
        type="$(_catalog_media_type "$ext")"
        hash=""
        if [[ "$CATALOG_INCLUDE_HASH" == true ]]; then
            hash="$(calculate_file_hash "$path/$rel")"
        fi
        _catalog_metadata "$path/$rel" "$type"

        printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
            "$relpath" "$size" "$mtime" "$hash" "$type" "${ext,,}" \
            "$CAT_DURATION" "$CAT_RES" "$CAT_DIMS" "$CAT_CODEC" "$CAT_CAMERA" "$CAT_DATE" >> "$work/new"

        if (( (added + updated) % 10 == 1 || total <= 200 )); then
            if [[ "$(type -t ui_progress)" == "function" ]]; then
                ui_progress "$n" "$total" "Cataloging" "$(basename "$rel")"
            fi
        fi
    done < "$work/inventory"
    progress_break

    # Anything the catalog has under this folder that is no longer on disk
    local k
    for k in "${!known_size[@]}"; do
        [[ -n "${seen["$k"]+x}" ]] || removed=$(( removed + 1 ))
    done

    STATS[files_processed]=$(( STATS[files_processed] + total ))
    STATS[catalog_added]=$(( ${STATS[catalog_added]:-0} + added ))
    STATS[catalog_updated]=$(( ${STATS[catalog_updated]:-0} + updated ))
    STATS[catalog_removed]=$(( ${STATS[catalog_removed]:-0} + removed ))
    STATS[catalog_unchanged]=$(( ${STATS[catalog_unchanged]:-0} + unchanged ))
    (( skipped > 0 )) && log_warning "Skipped $skipped file(s) whose names contain a newline"

    if [[ "$DRY_RUN" == true ]]; then
        STATS[files_previewed]=$(( ${STATS[files_previewed]:-0} + added + updated ))
        log_info "[DRY RUN] Would catalog: $added new, $updated updated, $removed removed, $unchanged unchanged"
        rm -rf "$work"
        return 0
    fi

    # Merge into the catalog in one pass: keep unchanged records, drop the rest of
    # this folder's records, add the new ones.
    jq -R -s --arg d "$drive_id" --arg now "$now" '
        split("\n") | map(select(length > 0) | split("\u001f") | {
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
        })' "$work/new" > "$work/new.json"

    jq --arg d "$drive_id" --arg p "$prefix" --arg now "$now" \
       --rawfile keep "$work/keep" --slurpfile new "$work/new.json" '
        ($keep | split("\n") | map(select(length > 0) | {(.): true}) | add // {}) as $k
        | .videos |= (map(select(.drive_id != $d
                                 or ((.relative_path | startswith($p)) | not)
                                 or $k[.relative_path])) + $new[0])
        | .last_updated = $now' "$CATALOG_DB" > "$work/db.json" \
        && _catalog_commit "$CATALOG_DB" "$work/db.json" || {
            log_error "Could not update the catalog database"
            rm -rf "$work"
            return 1
        }

    # Drive record: totals recomputed from the catalog
    local count size_total
    read -r count size_total < <(jq -r --arg d "$drive_id" \
        '[.videos[] | select(.drive_id == $d)] | "\(length) \(map(.file_size) | add // 0)"' "$CATALOG_DB")
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

    # Drop the files of any drive that was just forgotten
    jq --slurpfile drives "$tmp_d" '
        ($drives[0].drives | map(.drive_id)) as $keep
        | .videos |= map(select(.drive_id as $i | $keep | map(. == $i) | any))' "$CATALOG_DB" > "$tmp_c" || { rm -f "$tmp_d" "$tmp_c"; return 1; }

    _catalog_commit "$CATALOG_DRIVES_DB" "$tmp_d"
    _catalog_commit "$CATALOG_DB" "$tmp_c"
    rm -f "$tmp_d" "$tmp_c"
}

# "drives files bytes" for the whole catalog (0 0 0 when empty or jq is missing).
catalog_stats() {
    command -v jq >/dev/null 2>&1 && [[ -f "$CATALOG_DB" && -f "$CATALOG_DRIVES_DB" ]] || { echo "0 0 0"; return; }
    local d f
    d="$(jq '.drives | length' "$CATALOG_DRIVES_DB" 2>/dev/null)"
    f="$(jq -r '"\(.videos | length) \([.videos[].file_size] | add // 0)"' "$CATALOG_DB" 2>/dev/null)"
    echo "${d:-0} ${f:-0 0}"
}

# List cataloged drives with their status and totals.
list_cataloged_drives() {
    _catalog_require_jq || return 1
    init_catalog_db

    if [[ "$(jq '.drives | length' "$CATALOG_DRIVES_DB")" == "0" ]]; then
        log_info "No drives cataloged yet. Use Scan & Catalog Drive to add one."
        return 0
    fi

    local id label type mp count size scanned status dot color kinds
    while IFS="$_CAT_SEP" read -r id label type mp count size scanned; do
        if _catalog_mount_online "$mp"; then
            status="online"; dot="${UI_DOT_ON:-*}"; color="${UI_OK:-$COLOR_GREEN}"
        else
            status="offline"; dot="${UI_DOT_OFF:-o}"; color="${UI_DIM:-$COLOR_RED}"
        fi
        kinds="$(jq -r --arg d "$id" '
            [.videos[] | select(.drive_id == $d)] | group_by(.media_type)
            | map("\(.[0].media_type) \(length)") | join(" · ")' "$CATALOG_DB" 2>/dev/null)"
        printf '  %s%s%s %s%s%s  %s%s%s\n' "$color" "$dot" "$COLOR_RESET" "$COLOR_BOLD" "$label" "$COLOR_RESET" "$color" "$status" "$COLOR_RESET"
        printf '      %s%s %s %s file(s) %s %s%s\n' "${UI_DIM:-}" "$type" "${UI_SEP:-·}" "$count" "${UI_SEP:-·}" "$(format_bytes "$size")" "$COLOR_RESET"
        [[ -n "$kinds" ]] && printf '      %s%s%s\n' "${UI_DIM:-}" "$kinds" "$COLOR_RESET"
        printf '      %s%s %s scanned %s%s\n' "${UI_DIM:-}" "$mp" "${UI_SEP:-·}" "${scanned:-never}" "$COLOR_RESET"
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
search_catalog() {
    local term="$1"
    local media_filter="${2:-all}"

    _catalog_require_jq || return 1
    init_catalog_db

    if [[ -z "$term" ]]; then
        log_warning "Nothing to search for"
        return 1
    fi

    # Which drives are online right now
    local id mp online_json='{}'
    local -a on=()
    while IFS="$_CAT_SEP" read -r id mp; do
        _catalog_mount_online "$mp" && on+=("$id")
    done < <(jq -r '.drives[] | [.drive_id, .mount_point] | join("\u001f")' "$CATALOG_DRIVES_DB" 2>/dev/null)
    (( ${#on[@]} > 0 )) && online_json="$(printf '%s\n' "${on[@]}" | jq -R '{(.): true}' | jq -s 'add')"

    local tmp; tmp="$(mktemp)"
    jq -r --arg t "$term" --arg mt "$media_filter" --argjson limit "$CATALOG_SEARCH_LIMIT" \
          --argjson online "$online_json" --slurpfile drives "$CATALOG_DRIVES_DB" '
        ($t | ascii_downcase) as $q
        | ($drives[0].drives | map({(.drive_id): .drive_label}) | add // {}) as $labels
        | [.videos[]
           | select($mt == "all" or .media_type == $mt)
           | select(((.relative_path | ascii_downcase) | contains($q))
                    or (($q | test("^[0-9a-f]{6,}$")) and ((.hash // "") | startswith($q)))
                    or ((.resolution // "") == $q) or ((.dimensions // "") == $q)
                    or ((.camera // "" | ascii_downcase) | contains($q)))]
        | sort_by(.relative_path | ascii_downcase) as $all
        | ("TOTAL\u001f" + ($all | length | tostring)),
          ($all[:$limit][] | [($labels[.drive_id] // "unknown"),
                              (if $online[.drive_id] then "online" else "offline" end),
                              .relative_path, (.file_size | tostring), .media_type, (.resolution // .dimensions // "")]
                            | join("\u001f"))' "$CATALOG_DB" > "$tmp" 2>/dev/null

    local total=0 label state rel size mtype res shown=0
    while IFS="$_CAT_SEP" read -r label state rel size mtype res; do
        if [[ "$label" == "TOTAL" ]]; then total="$state"; continue; fi
        shown=$(( shown + 1 ))
        local dot color
        if [[ "$state" == online ]]; then dot="${UI_DOT_ON:-*}"; color="${UI_OK:-$COLOR_GREEN}"
        else dot="${UI_DOT_OFF:-o}"; color="${UI_DIM:-$COLOR_RED}"; fi
        printf '  %s%s%s %s%s%s  %s\n' "$color" "$dot" "$COLOR_RESET" "${UI_ACCENT:-$COLOR_CYAN}" "$label" "$COLOR_RESET" "$rel"
        printf '      %s%s %s %s%s%s\n' "${UI_DIM:-}" "$mtype" "${UI_SEP:-·}" "$(format_bytes "$size")" "${res:+ ${UI_SEP:-·} $res}" "$COLOR_RESET"
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
        jq -r '"Files: \(.videos | length)   Size: \([.videos[].file_size] | add // 0) bytes"' "$CATALOG_DB"
        echo ""
        echo "By media type:"
        jq -r '.videos | group_by(.media_type) | map("  \(.[0].media_type): \(length) files, \(map(.file_size) | add) bytes")[]' "$CATALOG_DB"
        echo ""
        echo "By extension (top 15):"
        jq -r '.videos | group_by(.extension) | map({e: .[0].extension, n: length}) | sort_by(-.n) | .[:15][] | "  .\(.e): \(.n)"' "$CATALOG_DB"
        echo ""
        echo "Largest files (top 10):"
        jq -r --slurpfile drives "$CATALOG_DRIVES_DB" '
            ($drives[0].drives | map({(.drive_id): .drive_label}) | add // {}) as $l
            | .videos | sort_by(-.file_size) | .[:10][]
            | "  \(.file_size) bytes  [\($l[.drive_id] // "unknown")] \(.relative_path)"' "$CATALOG_DB"
        echo ""
        echo "=== DUPLICATES ==="
        jq -r '[.videos[] | select((.hash // "") != "")] | group_by(.hash) | map(select(length > 1))
            | "Groups: \(length)   Extra copies: \(map(length - 1) | add // 0)   Wasted: \(map((length - 1) * .[0].file_size) | add // 0) bytes"' "$CATALOG_DB"
    } > "$out"

    echo "$out"
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
