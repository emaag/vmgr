#!/usr/bin/env bash
# Integration tests for the multi-drive catalog (lib/catalog.sh) and the
# cross-drive duplicate report (lib/duplicates.sh). Needs jq.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"
load_module_under_test "duplicates.sh"
load_module_under_test "theme.sh"
load_module_under_test "catalog.sh"
load_module_under_test "batch.sh"
load_module_under_test "browser.sh"
# load_vmgr_core stubs the logging functions; bring the real ones back
source "$LIB_DIR/logging.sh"
LOG_FILE=/dev/null

if ! command -v jq >/dev/null 2>&1; then
    test_catalog_needs_jq() { assert_equals "1" "1" "catalog tests skipped (jq not installed)"; }
    return 0 2>/dev/null || exit 0
fi

_strip() { sed 's/\x1b\[[0-9;]*m//g'; }

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    mkdir -p "$TEST_TMPDIR/d1/Movies/Show" "$TEST_TMPDIR/d1/Photos" "$TEST_TMPDIR/d2/Backup"
    D1="$(cd "$TEST_TMPDIR/d1" && pwd -P)"
    D2="$(cd "$TEST_TMPDIR/d2" && pwd -P)"
    echo "movie one"   > "$D1/Movies/Film A.mp4"
    echo "episode one" > "$D1/Movies/Show/ep 1.mkv"
    echo "a photo"     > "$D1/Photos/IMG_001.JPG"
    echo "a song"      > "$D1/song.mp3"
    echo "notes"       > "$D1/readme.txt"
    CATALOG_DB="$TEST_TMPDIR/catalog.json"
    CATALOG_DRIVES_DB="$TEST_TMPDIR/drives.json"
    CATALOG_VIDEOS=true; CATALOG_IMAGES=true; CATALOG_AUDIO=true
    CATALOG_INCLUDE_METADATA=false; CATALOG_INCLUDE_HASH=true; CATALOG_OFFLINE_RETENTION=90
    DRY_RUN=false; VERBOSE=false
    HASH_CALLS="$TEST_TMPDIR/hash_calls"; : > "$HASH_CALLS"
    reset_statistics
    # Stand-ins so each temp folder behaves like its own drive
    catalog_mount_point() {
        local p; p="$(cd "$1" 2>/dev/null && pwd -P)" || p="$1"
        case "$p" in "$D1"|"$D1"/*) echo "$D1" ;; "$D2"|"$D2"/*) echo "$D2" ;; *) echo "$p" ;; esac
    }
    get_drive_id() { case "$1" in "$D1") echo id-one ;; "$D2") echo id-two ;; "/") echo id-root ;; *) echo "id-$(basename "$1")" ;; esac; }
    get_drive_label() { case "$1" in "$D1") echo "Drive One" ;; "$D2") echo "Drive Two" ;; *) basename "$1" ;; esac; }
    detect_drive_type() { echo Local; }
    calculate_file_hash() { echo "$1" >> "$HASH_CALLS"; _catalog_hash_string "$(cat "$1")"; }
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

_count() { jq "$1" "$CATALOG_DB"; }
_hash_calls() { wc -l < "$HASH_CALLS" | tr -d ' '; }

test_first_scan_records_media_files_with_details() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "4" "$(_count '.videos | length')" "scan: every media file is cataloged (the .txt is not)"
    assert_equals "Movies/Film A.mp4" "$(_count '.videos[] | select(.filename == "Film A.mp4") | .relative_path' | tr -d '"')" "scan: relative path from the drive root"
    assert_equals "video" "$(_count '.videos[] | select(.filename == "Film A.mp4") | .media_type' | tr -d '"')" "scan: video type"
    assert_equals "image" "$(_count '.videos[] | select(.filename == "IMG_001.JPG") | .media_type' | tr -d '"')" "scan: image type (extension case ignored)"
    assert_equals "audio" "$(_count '.videos[] | select(.filename == "song.mp3") | .media_type' | tr -d '"')" "scan: audio type"
    assert_equals "10" "$(_count '.videos[] | select(.filename == "Film A.mp4") | .file_size')" "scan: file size recorded"
    assert_equals "64" "$(_count '.videos[0].hash | length')" "scan: sha-256 hash recorded"
    assert_equals "4" "${STATS[catalog_added]}" "scan: counted as added"
    _teardown
}

test_scan_registers_the_drive_with_totals() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "1" "$(jq '.drives | length' "$CATALOG_DRIVES_DB")" "drive: one drive registered"
    assert_equals "Drive One" "$(jq -r '.drives[0].drive_label' "$CATALOG_DRIVES_DB")" "drive: label"
    assert_equals "4" "$(jq '.drives[0].file_count' "$CATALOG_DRIVES_DB")" "drive: file count"
    assert_equals "$D1" "$(jq -r '.drives[0].mount_point' "$CATALOG_DRIVES_DB")" "drive: mount point"
    _teardown
}

test_rescan_of_unchanged_files_does_no_work() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "4" "$(_hash_calls)" "rescan: first scan hashed every file"
    reset_statistics
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "4" "$(_hash_calls)" "rescan: nothing is hashed again"
    assert_equals "4" "${STATS[catalog_unchanged]}" "rescan: all unchanged"
    assert_equals "0" "${STATS[catalog_added]}" "rescan: nothing added"
    assert_equals "4" "$(_count '.videos | length')" "rescan: catalog unchanged"
    _teardown
}

test_changed_new_and_deleted_files_are_picked_up() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    reset_statistics; : > "$HASH_CALLS"
    echo "a much longer replacement" > "$D1/Movies/Film A.mp4"     # changed
    echo "brand new" > "$D1/Movies/New.mkv"                         # new
    rm -f "$D1/song.mp3"                                            # deleted
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "1" "${STATS[catalog_added]}" "changes: one new file"
    assert_equals "1" "${STATS[catalog_updated]}" "changes: one updated file"
    assert_equals "1" "${STATS[catalog_removed]}" "changes: one removed file"
    assert_equals "2" "${STATS[catalog_unchanged]}" "changes: two untouched"
    assert_equals "2" "$(_hash_calls)" "changes: only the new and changed files are hashed"
    assert_equals "0" "$(_count '[.videos[] | select(.filename == "song.mp3")] | length')" "changes: the deleted file is gone from the catalog"
    assert_equals "26" "$(_count '.videos[] | select(.filename == "Film A.mp4") | .file_size')" "changes: the updated size is stored"
    _teardown
}

test_scanning_a_subfolder_only_touches_that_folder() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    rm -f "$D1/song.mp3" "$D1/Movies/Show/ep 1.mkv"
    reset_statistics
    catalog_drive "$D1/Movies" true >/dev/null 2>&1
    assert_equals "1" "${STATS[catalog_removed]}" "subfolder scan: only the file under that folder was removed"
    assert_equals "1" "$(_count '[.videos[] | select(.filename == "song.mp3")] | length')" "subfolder scan: records outside the folder are left alone"
    assert_equals "Movies/Film A.mp4" "$(_count '.videos[] | select(.filename == "Film A.mp4") | .relative_path' | tr -d '"')" "subfolder scan: paths stay relative to the drive root"
    _teardown
}

test_media_type_switches_are_respected() {
    _setup
    CATALOG_IMAGES=false; CATALOG_AUDIO=false
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "2" "$(_count '.videos | length')" "types: only videos when images and audio are off"
    CATALOG_VIDEOS=false
    local rc=0
    catalog_drive "$D1" true >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "types: scanning with every type off is an error"
    _teardown
}

test_hash_can_be_switched_off_and_added_later() {
    _setup
    CATALOG_INCLUDE_HASH=false
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "0" "$(_count '[.videos[] | select(.hash != null)] | length')" "hash off: no hashes stored"
    assert_equals "0" "$(_hash_calls)" "hash off: nothing hashed"
    CATALOG_INCLUDE_HASH=true; reset_statistics
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "4" "${STATS[catalog_updated]}" "hash on later: records without a hash are updated"
    assert_equals "4" "$(_count '[.videos[] | select(.hash != null)] | length')" "hash on later: hashes are filled in"
    _teardown
}

test_metadata_is_read_with_ffprobe() {
    _setup
    mkdir -p "$TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nprintf "codec_name=h264\\nwidth=1920\\nheight=1080\\nduration=12.5\\n"\n' > "$TEST_TMPDIR/bin/ffprobe"
    chmod +x "$TEST_TMPDIR/bin/ffprobe"
    local saved="$PATH"; export PATH="$TEST_TMPDIR/bin:$PATH"
    CATALOG_INCLUDE_METADATA=true
    catalog_drive "$D1" true >/dev/null 2>&1
    export PATH="$saved"
    assert_equals "1920x1080" "$(_count '.videos[] | select(.filename == "Film A.mp4") | .resolution' | tr -d '"')" "metadata: resolution"
    assert_equals "h264" "$(_count '.videos[] | select(.filename == "Film A.mp4") | .codec' | tr -d '"')" "metadata: codec"
    assert_equals "12.5" "$(_count '.videos[] | select(.filename == "Film A.mp4") | .duration')" "metadata: duration is a number"
    _teardown
}

test_dry_run_changes_nothing() {
    _setup
    DRY_RUN=true
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "0" "$(_count '.videos | length')" "dry run: the catalog stays empty"
    assert_equals "0" "$(jq '.drives | length' "$CATALOG_DRIVES_DB")" "dry run: no drive is registered"
    assert_equals "4" "${STATS[files_previewed]}" "dry run: says how many would be cataloged"
    assert_equals "0" "$(_hash_calls)" "dry run: nothing is hashed"
    _teardown
}

test_trash_and_odd_names() {
    _setup
    mkdir -p "$D1/.vmgr-trash/S1"
    echo trashed > "$D1/.vmgr-trash/S1/old.mp4"
    echo uni > "$D1/Movies/Amélie 日本語.mp4"
    echo bad > "$D1/Movies/$(printf 'two\nlines').mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "0" "$(_count '[.videos[] | select(.relative_path | contains(".vmgr-trash"))] | length')" "names: the trash is not cataloged"
    assert_equals "1" "$(_count '[.videos[] | select(.filename == "Amélie 日本語.mp4")] | length')" "names: accented and non-Latin names are kept"
    assert_equals "0" "$(_count '[.videos[] | select(.filename | contains("two"))] | length')" "names: a name with a newline is skipped, not stored broken"
    _teardown
}

test_duplicates_are_found_across_drives() {
    _setup
    echo "movie one" > "$D2/Backup/Film A copy.mp4"      # same content as on drive one
    echo "only here" > "$D2/Backup/unique.mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    catalog_drive "$D2" true >/dev/null 2>&1
    local groups; groups="$(find_duplicates_in_catalog)"
    assert_equals "1" "$(jq 'length' <<< "$groups")" "duplicates: one group across the two drives"
    assert_equals "2" "$(jq '.[0].files | length' <<< "$groups")" "duplicates: two copies"
    assert_equals "2" "$(jq '[.[0].files[].drive_id] | unique | length' <<< "$groups")" "duplicates: on different drives"
    local out; out="$(show_duplicates_report 2>&1 | _strip)"
    assert_contains "Drive One" "$out" "report: names the first drive"
    assert_contains "Drive Two" "$out" "report: names the second drive"
    assert_contains "Backup/Film A copy.mp4" "$out" "report: shows the path"
    _teardown
}

test_duplicates_report_explains_when_nothing_is_hashed() {
    _setup
    CATALOG_INCLUDE_HASH=false
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_contains "Include Hash" "$(show_duplicates_report 2>&1 | _strip)" "report: tells you to turn on hashing"
    _teardown
}

test_search_by_name_type_hash_and_resolution() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    jq '(.videos[] | select(.filename == "Film A.mp4") | .resolution) = "1920x1080"' "$CATALOG_DB" > "$TEST_TMPDIR/x" && mv "$TEST_TMPDIR/x" "$CATALOG_DB"
    local out
    out="$(search_catalog "film" all 2>&1 | _strip)"
    assert_contains "Movies/Film A.mp4" "$out" "search: matches a name case-insensitively"
    out="$(search_catalog "show" video 2>&1 | _strip)"
    assert_contains "ep 1.mkv" "$out" "search: matches a folder name"
    out="$(search_catalog "song" video 2>&1 | _strip)"
    assert_contains "No matches" "$out" "search: the media filter excludes other types"
    local h; h="$(jq -r '.videos[] | select(.filename == "song.mp3") | .hash' "$CATALOG_DB")"
    out="$(search_catalog "${h:0:10}" all 2>&1 | _strip)"
    assert_contains "song.mp3" "$out" "search: matches a hash prefix"
    out="$(search_catalog "1920x1080" all 2>&1 | _strip)"
    assert_contains "Film A.mp4" "$out" "search: matches a resolution"
    _teardown
}

test_search_includes_offline_drives_and_flags_them() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    jq --arg m "$TEST_TMPDIR/unplugged" '.drives[0].mount_point = $m' "$CATALOG_DRIVES_DB" > "$TEST_TMPDIR/x" && mv "$TEST_TMPDIR/x" "$CATALOG_DRIVES_DB"
    local out; out="$(search_catalog "film" all 2>&1 | _strip)"
    assert_contains "Film A.mp4" "$out" "offline: files on an unplugged drive are still found"
    assert_contains "$UI_DOT_OFF Drive One" "$out" "offline: marked with the offline dot"
    _teardown
}

test_search_limits_the_output() {
    _setup
    local i
    for i in 1 2 3 4 5; do echo "x$i" > "$D1/Movies/clip$i.mp4"; done
    catalog_drive "$D1" true >/dev/null 2>&1
    CATALOG_SEARCH_LIMIT=3
    local out; out="$(search_catalog "clip" all 2>&1 | _strip)"
    assert_contains "Showing 3 of 5 matches" "$out" "search: long result lists are capped and say so"
    CATALOG_SEARCH_LIMIT=100
    _teardown
}

test_list_shows_online_and_offline_drives() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    catalog_drive "$D2" true >/dev/null 2>&1   # empty drive two: not online (nothing in it)
    local out; out="$(list_cataloged_drives 2>&1 | _strip)"
    assert_contains "Drive One  online" "$out" "list: a drive with files is online"
    assert_contains "4 file(s)" "$out" "list: file count"
    assert_contains "audio 1" "$out" "list: breakdown by media type"
    _teardown
}

test_list_when_the_catalog_is_empty() {
    _setup
    assert_contains "No drives cataloged yet" "$(list_cataloged_drives 2>&1 | _strip)" "list: says so when empty"
    _teardown
}

test_offline_drives_are_forgotten_after_the_retention_period() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    echo "x" > "$D2/b.mp4"; catalog_drive "$D2" true >/dev/null 2>&1
    # Drive two unplugged long ago; drive one is online but also "old"
    jq --arg m "$TEST_TMPDIR/gone" '(.drives[] | select(.drive_id == "id-two")) |= (.mount_point = $m | .last_seen = "2000-01-01T00:00:00Z")
                                    | (.drives[] | select(.drive_id == "id-one")) |= (.last_seen = "2000-01-01T00:00:00Z")' \
        "$CATALOG_DRIVES_DB" > "$TEST_TMPDIR/x" && mv "$TEST_TMPDIR/x" "$CATALOG_DRIVES_DB"
    catalog_prune_offline
    assert_equals "1" "$(jq '.drives | length' "$CATALOG_DRIVES_DB")" "prune: the long-offline drive is forgotten"
    assert_equals "id-one" "$(jq -r '.drives[0].drive_id' "$CATALOG_DRIVES_DB")" "prune: an online drive is never forgotten"
    assert_equals "0" "$(_count '[.videos[] | select(.drive_id == "id-two")] | length')" "prune: its files go with it"
    _teardown
}

test_retention_zero_keeps_offline_drives_forever() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    jq --arg m "$TEST_TMPDIR/gone" '.drives[0].mount_point = $m | .drives[0].last_seen = "2000-01-01T00:00:00Z"' "$CATALOG_DRIVES_DB" > "$TEST_TMPDIR/x" && mv "$TEST_TMPDIR/x" "$CATALOG_DRIVES_DB"
    CATALOG_OFFLINE_RETENTION=0
    catalog_prune_offline
    assert_equals "1" "$(jq '.drives | length' "$CATALOG_DRIVES_DB")" "retention 0: nothing is forgotten"
    _teardown
}

test_export_report_summarises_the_catalog() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    local file="$TEST_TMPDIR/report.txt" out
    out="$(catalog_export_report "$file")"
    assert_equals "$file" "$out" "report: prints the path it wrote"
    local text; text="$(cat "$file")"
    assert_contains "Drive One" "$text" "report: lists the drive"
    assert_contains "Files: 4" "$text" "report: totals"
    assert_contains "video: 2 files" "$text" "report: by media type"
    assert_contains "DUPLICATES" "$text" "report: duplicate summary"
    _teardown
}

test_batch_catalog_reports_each_drive() {
    _setup
    echo "x" > "$D2/b.mp4"
    batch_process_folders catalog "$D1" "$D2" >/dev/null 2>&1
    assert_equals "4 new" "${BATCH_RESULT_NOTE[0]}" "batch catalog: first drive note"
    assert_equals "1 new" "${BATCH_RESULT_NOTE[1]}" "batch catalog: second drive note"
    batch_process_folders catalog "$D1" >/dev/null 2>&1
    assert_equals "up to date (4 files)" "${BATCH_RESULT_NOTE[0]}" "batch catalog: a rescan says up to date"
    _teardown
}

test_catalog_stats_helper() {
    _setup
    assert_equals "0 0 0" "$(catalog_stats)" "stats: empty catalog"
    catalog_drive "$D1" true >/dev/null 2>&1
    local d f b; read -r d f b <<< "$(catalog_stats)"
    assert_equals "1 4" "$d $f" "stats: drive and file counts"
    assert_equals "1" "$(( b > 0 ? 1 : 0 ))" "stats: total size"
    _teardown
}

test_missing_directory_is_an_error() {
    _setup
    local rc=0
    catalog_drive "$TEST_TMPDIR/nope" true >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "scan: a missing directory is an error"
    assert_equals "0" "$(jq '.videos | length' "$CATALOG_DB" 2>/dev/null || echo 0)" "scan: nothing is written"
    _teardown
}

test_mount_point_of_a_real_path() {
    _setup
    unset -f catalog_mount_point
    source "$LIB_DIR/catalog.sh"
    local mp; mp="$(catalog_mount_point "$TEST_TMPDIR")"
    # (not "contains the path": on macOS the data volume is /System/Volumes/Data while paths start at /private)
    assert_equals "1" "$([[ -n "$mp" && -d "$mp" ]] && echo 1 || echo 0)" "mount point: a real directory"
    _teardown
}

test_paths_stay_relative_when_the_drive_is_the_root_filesystem() {
    _setup
    catalog_mount_point() { echo "/"; }
    catalog_drive "$D1" true >/dev/null 2>&1
    local rel; rel="$(_count '.videos[] | select(.filename == "Film A.mp4") | .relative_path' | tr -d '"')"
    assert_equals "${D1#/}/Movies/Film A.mp4" "$rel" "root mount: the path is relative to / (no leading slash)"
    _teardown
}

test_the_root_filesystem_gets_a_readable_label() {
    _setup
    unset -f get_drive_label
    source "$LIB_DIR/catalog.sh"
    assert_equals "System drive" "$(get_drive_label /)" "label: / is called the system drive"
    assert_equals "Backup" "$(get_drive_label /srv/Backup)" "label: other mounts use their folder name"
    _teardown
}

test_drive_type_looks_at_the_exact_mount_point() {
    _setup
    unset -f detect_drive_type
    source "$LIB_DIR/catalog.sh"
    mount() {
        printf 'rootdev on / type ext4 (rw,relatime)\n'
        printf 'drvfs on /mnt/c type 9p (rw)\n'
        printf 'nas:/export on /srv/nas type nfs4 (rw)\n'
        printf '//server/share on /srv/share type cifs (rw)\n'
    }
    assert_equals "Local" "$(detect_drive_type /)" "drive type: / is local even though other mounts are network filesystems"
    assert_equals "NAS" "$(detect_drive_type /srv/nas)" "drive type: nfs is a NAS"
    assert_equals "Network" "$(detect_drive_type /srv/share)" "drive type: cifs is a network share"
    unset -f mount
    _teardown
}

test_a_path_not_textually_under_the_mount_point_is_stored_without_a_leading_slash() {
    _setup
    catalog_mount_point() { echo "/nowhere/volume"; }   # like /System/Volumes/Data on macOS
    get_drive_id() { echo id-firm; }
    catalog_drive "$D1" true >/dev/null 2>&1
    local rel; rel="$(_count '.videos[] | select(.filename == "Film A.mp4") | .relative_path' | tr -d '"')"
    assert_equals "${D1#/}/Movies/Film A.mp4" "$rel" "firmlink: the path is stored without a leading slash"
    _teardown
}

test_drive_identification_is_cached_per_mount_point() {
    _setup
    local calls="$TEST_TMPDIR/id_calls"; : > "$calls"
    get_drive_id() { echo x >> "$calls"; echo id-one; }
    catalog_drive "$D1" true >/dev/null 2>&1
    catalog_drive "$D1/Movies" true >/dev/null 2>&1
    assert_equals "1" "$(wc -l < "$calls" | tr -d ' ')" "cache: the drive is identified once, not once per scan"
    _teardown
}
