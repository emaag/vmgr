#!/usr/bin/env bash
# Integration tests for the multi-drive catalog (lib/catalog.sh) and the
# cross-drive duplicate report (lib/duplicates.sh). Needs jq.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"
load_module_under_test "duplicates.sh"
load_module_under_test "theme.sh"
load_module_under_test "organize.sh"
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

# Keep a copy of the real batch hasher so tests can count how many files reach it
eval "$(declare -f _catalog_hash_files | sed '1s/_catalog_hash_files/_orig_catalog_hash_files/')"

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
    # every file the scan asks to be hashed is logged, one per line
    _catalog_hash_files() { tr '\0' '\n' < "$1" >> "$HASH_CALLS"; _orig_catalog_hash_files "$@"; }
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

_filters_off() { unset CATALOG_FILTER_MIN_SIZE CATALOG_FILTER_MAX_SIZE CATALOG_FILTER_NEWER_DAYS CATALOG_FILTER_OLDER_DAYS CATALOG_FILTER_MIN_DURATION CATALOG_FILTER_MAX_DURATION; }

test_size_age_and_duration_parsers() {
    assert_equals "1073741824" "$(_catalog_parse_size 1G)" "parse: 1G is 1024^3 bytes"
    assert_equals "1536" "$(_catalog_parse_size 1.5k)" "parse: decimals and lower case"
    assert_equals "500" "$(_catalog_parse_size 500)" "parse: bare number is bytes"
    assert_exits_nonzero "_catalog_parse_size big" "parse: junk size rejected"
    assert_equals "600" "$(_catalog_parse_duration 10m)" "parse: 10m is 600 seconds"
    assert_equals "7200" "$(_catalog_parse_duration 2h)" "parse: 2h"
    assert_exits_nonzero "_catalog_parse_duration 2x" "parse: junk duration rejected"
    assert_equals "14" "$(_catalog_parse_age 2w)" "parse: 2w is 14 days"
    assert_equals "365" "$(_catalog_parse_age 1y)" "parse: 1y"
    assert_exits_nonzero "_catalog_parse_age soon" "parse: junk age rejected"
}

test_search_by_size_range_without_a_term() {
    _setup
    head -c 5000 /dev/zero > "$D1/Movies/Big.mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    CATALOG_FILTER_MIN_SIZE=2000
    local out; out="$(search_catalog "" all 2>&1 | _strip)"
    assert_contains "Big.mp4" "$out" "size filter: the big file matches"
    assert_not_contains "Film A.mp4" "$out" "size filter: smaller files are left out"
    _filters_off
    CATALOG_FILTER_MAX_SIZE=100
    out="$(search_catalog "" all 2>&1 | _strip)"
    assert_not_contains "Big.mp4" "$out" "size filter: max size leaves the big file out"
    assert_contains "Film A.mp4" "$out" "size filter: ... and keeps the small ones"
    _filters_off
    _teardown
}

test_search_by_age() {
    _setup
    touch -d "100 days ago" "$D1/Movies/Old.mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    CATALOG_FILTER_OLDER_DAYS=30
    local out; out="$(search_catalog "" all 2>&1 | _strip)"
    assert_contains "Old.mp4" "$out" "age filter: an old file matches --older"
    assert_not_contains "Film A.mp4" "$out" "age filter: a new file does not"
    _filters_off
    CATALOG_FILTER_NEWER_DAYS=30
    out="$(search_catalog "" all 2>&1 | _strip)"
    assert_not_contains "Old.mp4" "$out" "age filter: --newer leaves the old file out"
    assert_contains "Film A.mp4" "$out" "age filter: --newer keeps new files"
    _filters_off
    _teardown
}

test_search_by_duration_and_with_a_term() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    jq -c '.videos |= map(if .filename == "Film A.mp4" then .duration = 7200 elif .filename == "ep 1.mkv" then .duration = 60 else . end)' "$CATALOG_DB" > "$TEST_TMPDIR/x" && mv "$TEST_TMPDIR/x" "$CATALOG_DB"
    CATALOG_FILTER_MIN_DURATION=3600
    local out; out="$(search_catalog "" all 2>&1 | _strip)"
    assert_contains "Film A.mp4" "$out" "duration filter: the 2 hour film matches"
    assert_contains "2:00:00" "$out" "duration filter: the length is shown"
    assert_not_contains "ep 1.mkv" "$out" "duration filter: the 1 minute episode does not"
    assert_not_contains "song.mp3" "$out" "duration filter: files with no known length are left out"
    CATALOG_FILTER_MIN_DURATION=30
    out="$(search_catalog "ep" all 2>&1 | _strip)"
    assert_contains "ep 1.mkv" "$out" "filters combine with a term"
    assert_not_contains "Film A.mp4" "$out" "filters combine with a term: the term still applies"
    _filters_off
    _teardown
}

test_search_with_no_term_and_no_filter_is_refused() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    local rc=0
    search_catalog "" all >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "search: nothing to search for returns 1"
    _teardown
}

test_export_csv_has_a_header_and_one_row_per_file() {
    _setup
    echo "odd" > "$D1/Odd, \"name\".mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    local file="$TEST_TMPDIR/out.csv" out
    out="$(catalog_export_data csv "$file")"
    assert_equals "$file" "$out" "csv: prints the path it wrote"
    assert_equals "5" "$(( $(wc -l < "$file") - 1 ))" "csv: one row per file"
    assert_contains "\"drive_label\",\"drive_id\",\"relative_path\"" "$(head -1 "$file")" "csv: header row"
    assert_contains '"Odd, ""name"".mp4"' "$(cat "$file")" "csv: commas and quotes in names are escaped"
    assert_contains '"Drive One"' "$(sed -n 2p "$file")" "csv: rows carry the drive label"
    _teardown
}

test_export_json_is_a_valid_array_of_records() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    local file="$TEST_TMPDIR/out.json"
    catalog_export_data json "$file" >/dev/null
    assert_equals "4" "$(jq 'length' "$file")" "json: one record per file"
    assert_equals "Drive One" "$(jq -r '.[0].drive_label' "$file")" "json: records carry the drive label"
    _teardown
}

test_export_format_follows_the_file_extension() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    catalog_export_data "" "$TEST_TMPDIR/a.json" >/dev/null
    assert_equals "4" "$(jq 'length' "$TEST_TMPDIR/a.json")" "export: .json file gets JSON"
    catalog_export_data "" "$TEST_TMPDIR/a.txt" >/dev/null
    assert_contains "relative_path" "$(head -1 "$TEST_TMPDIR/a.txt")" "export: any other extension gets CSV"
    _teardown
}

test_export_rejects_an_unknown_format() {
    _setup
    local rc=0
    catalog_export_data xml "$TEST_TMPDIR/a.xml" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "export: unknown format fails"
    assert_file_not_exists "$TEST_TMPDIR/a.xml" "export: nothing written"
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

# ── Cleaning up duplicates across drives ──────────────────────────────────────

# Same movie on both drives, plus one file only on drive two
_dup_drives() {
    echo "the same movie" > "$D1/Movies/Same.mp4"
    echo "the same movie" > "$D2/Backup/Same copy.mp4"
    echo "only on two"    > "$D2/Backup/unique.mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    catalog_drive "$D2" true >/dev/null 2>&1
    UNDO_LOG_DIR="$TEST_TMPDIR/undo"; ENABLE_UNDO=true; UNDO_CURRENT_LOG=""
}
_trash_files() { find "$1" -path '*/.vmgr-trash/*' -type f 2>/dev/null; }

test_candidates_are_drives_with_copies_that_exist_elsewhere() {
    _setup; _dup_drives
    local out; out="$(catalog_duplicate_candidates)"
    assert_equals "2" "$(echo "$out" | wc -l | tr -d ' ')" "candidates: both drives hold a copy that exists on the other"
    assert_contains "Drive Two" "$out" "candidates: names the drive"
    _teardown
}

test_trashing_duplicates_on_one_drive_keeps_the_other_copy() {
    _setup; _dup_drives
    start_operation "Duplicates to Trash" >/dev/null 2>&1
    catalog_trash_duplicates id-two >/dev/null 2>&1
    assert_file_exists "$D1/Movies/Same.mp4" "trash dups: the copy on the other drive stays"
    assert_file_not_exists "$D2/Backup/Same copy.mp4" "trash dups: the copy on this drive is gone from its folder"
    assert_file_exists "$D2/Backup/unique.mp4" "trash dups: a file with no copy elsewhere is untouched"
    assert_equals "1" "$(_trash_files "$D2" | wc -l | tr -d ' ')" "trash dups: it is in that drive's trash"
    assert_equals "0" "$(_trash_files "$D1" | wc -l | tr -d ' ')" "trash dups: nothing is trashed on the other drive"
    assert_equals "1" "${STATS[files_trashed]}" "trash dups: counted"
    _teardown
}

test_trashing_duplicates_updates_the_catalog() {
    _setup; _dup_drives
    catalog_trash_duplicates id-two >/dev/null 2>&1
    assert_equals "0" "$(_count '[.videos[] | select(.filename == "Same copy.mp4")] | length')" "trash dups: the moved file leaves the catalog"
    assert_equals "1" "$(jq '.drives[] | select(.drive_id == "id-two") | .file_count' "$CATALOG_DRIVES_DB")" "trash dups: the drive's file count is updated"
    # and the duplicate is no longer reported
    assert_equals "0" "$(jq 'length' <<< "$(find_duplicates_in_catalog)")" "trash dups: no duplicate group remains"
    _teardown
}

test_trashed_duplicates_can_be_undone() {
    _setup; _dup_drives
    start_operation "Duplicates to Trash" >/dev/null 2>&1
    catalog_trash_duplicates id-two >/dev/null 2>&1
    undo_last_operation >/dev/null 2>&1
    assert_file_exists "$D2/Backup/Same copy.mp4" "undo: the copy is back where it was"
    assert_equals "0" "$(_trash_files "$D2" | wc -l | tr -d ' ')" "undo: the trash is empty again"
    _teardown
}

test_undo_puts_the_catalog_records_back() {
    _setup; _dup_drives
    start_operation "Duplicates to Trash" >/dev/null 2>&1
    catalog_trash_duplicates id-two >/dev/null 2>&1
    assert_equals "0" "$(_count '[.videos[] | select(.filename == "Same copy.mp4")] | length')" "undo catalog: record removed by the move"
    undo_last_operation >/dev/null 2>&1
    assert_equals "1" "$(_count '[.videos[] | select(.filename == "Same copy.mp4")] | length')" "undo catalog: record is back after undo"
    assert_equals "2" "$(jq '.drives[] | select(.drive_id == "id-two") | .file_count' "$CATALOG_DRIVES_DB")" "undo catalog: the drive's file count is restored"
    assert_equals "1" "$(jq 'length' <<< "$(find_duplicates_in_catalog)")" "undo catalog: the duplicate is reported again"
    assert_equals "0" "$(find "$UNDO_LOG_DIR" -name '*.catalog' | wc -l | tr -d ' ')" "undo catalog: the saved records are archived"
    _teardown
}

test_undo_does_not_add_records_for_files_that_did_not_come_back() {
    _setup; _dup_drives
    start_operation "Duplicates to Trash" >/dev/null 2>&1
    catalog_trash_duplicates id-two >/dev/null 2>&1
    local before; before="$(_count '.videos | length')"
    catalog_restore_records "$UNDO_LOG_DIR"/*.catalog >/dev/null 2>&1
    assert_equals "$before" "$(_count '.videos | length')" "undo catalog: nothing re-added while the file is still in the trash"
    _teardown
}

test_a_file_changed_since_the_scan_is_left_alone() {
    _setup; _dup_drives
    echo "edited after the scan, so the hash is stale" > "$D2/Backup/Same copy.mp4"
    catalog_trash_duplicates id-two >/dev/null 2>&1
    assert_file_exists "$D2/Backup/Same copy.mp4" "safety: a file that changed since the scan is not moved"
    assert_equals "0" "${STATS[files_trashed]}" "safety: nothing counted as trashed"
    assert_equals "1" "${STATS[files_skipped]}" "safety: counted as skipped"
    _teardown
}

test_a_missing_or_changed_other_copy_stops_the_move() {
    _setup; _dup_drives
    echo "the other copy was replaced" > "$D1/Movies/Same.mp4"
    catalog_trash_duplicates id-two >/dev/null 2>&1
    assert_file_exists "$D2/Backup/Same copy.mp4" "safety: not moved when the other copy changed"
    rm -f "$D1/Movies/Same.mp4"
    catalog_trash_duplicates id-two >/dev/null 2>&1
    assert_file_exists "$D2/Backup/Same copy.mp4" "safety: not moved when the other copy is gone"
    _teardown
}

test_a_copy_only_on_an_offline_drive_does_not_count() {
    _setup; _dup_drives
    # Drive one is unplugged: its copy cannot be checked, so drive two's copy must stay
    jq --arg m "$TEST_TMPDIR/unplugged" '(.drives[] | select(.drive_id == "id-one")).mount_point = $m' "$CATALOG_DRIVES_DB" > "$TEST_TMPDIR/x" && mv "$TEST_TMPDIR/x" "$CATALOG_DRIVES_DB"
    assert_equals "" "$(catalog_duplicate_candidates)" "offline: no candidates when the other copy is on an offline drive"
    catalog_trash_duplicates id-two >/dev/null 2>&1
    assert_file_exists "$D2/Backup/Same copy.mp4" "offline: nothing is moved"
    _teardown
}

test_copies_all_on_one_drive_are_not_a_cross_drive_cleanup() {
    _setup
    echo "dup" > "$D2/Backup/a.mp4"; echo "dup" > "$D2/Backup/b.mp4"
    catalog_drive "$D2" true >/dev/null 2>&1
    assert_equals "" "$(catalog_duplicate_candidates)" "same drive: duplicates within one drive are not offered"
    _teardown
}

test_trash_dry_run_moves_nothing() {
    _setup; _dup_drives
    DRY_RUN=true catalog_trash_duplicates id-two >/dev/null 2>&1
    assert_file_exists "$D2/Backup/Same copy.mp4" "dry run: the copy stays"
    assert_equals "1" "${STATS[files_previewed]}" "dry run: says how many would move"
    assert_equals "1" "$(_count '[.videos[] | select(.filename == "Same copy.mp4")] | length')" "dry run: the catalog is unchanged"
    _teardown
}

test_an_unwritable_drive_root_is_reported_and_nothing_moves() {
    _setup; _dup_drives
    if [[ "$(id -u)" == 0 ]]; then _teardown; return; fi
    chmod a-w "$D2"
    local rc=0
    catalog_trash_duplicates id-two >/dev/null 2>&1 || rc=$?
    chmod u+w "$D2"
    assert_equals "1" "$rc" "unwritable: reported as a failure"
    assert_file_exists "$D2/Backup/Same copy.mp4" "unwritable: the file is untouched"
    _teardown
}

test_a_later_scan_ignores_the_drive_trash() {
    _setup; _dup_drives
    catalog_trash_duplicates id-two >/dev/null 2>&1
    reset_statistics
    catalog_drive "$D2" true >/dev/null 2>&1
    assert_equals "0" "${STATS[catalog_added]}" "rescan: trashed files are not cataloged again"
    _teardown
}

# ── Timestamps ────────────────────────────────────────────────────────────────

_is_iso() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; }

test_a_scan_stamps_the_catalog_and_the_drive() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    _is_iso "$(jq -r '.last_updated' "$CATALOG_DB")";                      assert_equals "0" "$?" "timestamps: the catalog has a last_updated"
    _is_iso "$(jq -r '.videos[0].last_scanned' "$CATALOG_DB")";            assert_equals "0" "$?" "timestamps: each record has last_scanned"
    _is_iso "$(jq -r '.drives[0].last_scanned' "$CATALOG_DRIVES_DB")";     assert_equals "0" "$?" "timestamps: the drive has last_scanned"
    _is_iso "$(jq -r '.drives[0].last_seen' "$CATALOG_DRIVES_DB")";        assert_equals "0" "$?" "timestamps: the drive has last_seen"
    _is_iso "$(jq -r '.drives[0].first_seen' "$CATALOG_DRIVES_DB")";       assert_equals "0" "$?" "timestamps: the drive has first_seen"
    _teardown
}

test_an_unchanged_rescan_still_moves_the_drive_timestamps() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    jq '.drives[0].last_seen = "2001-01-01T00:00:00Z" | .drives[0].last_scanned = "2001-01-01T00:00:00Z"' "$CATALOG_DRIVES_DB" > "$TEST_TMPDIR/x" && mv "$TEST_TMPDIR/x" "$CATALOG_DRIVES_DB"
    local before_db; before_db="$(cat "$CATALOG_DB")"
    catalog_drive "$D1" true >/dev/null 2>&1
    _is_iso "$(jq -r '.drives[0].last_seen' "$CATALOG_DRIVES_DB")"
    assert_equals "0" "$?" "unchanged rescan: last_seen is refreshed to a real time"
    assert_not_equals "2001-01-01T00:00:00Z" "$(jq -r '.drives[0].last_scanned' "$CATALOG_DRIVES_DB")" "unchanged rescan: last_scanned moves"
    assert_equals "$before_db" "$(cat "$CATALOG_DB")" "unchanged rescan: the catalog file itself is not rewritten"
    _teardown
}

test_the_catalog_file_has_one_record_per_line_and_is_valid_json() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    jq -e . "$CATALOG_DB" >/dev/null 2>&1; assert_equals "0" "$?" "layout: valid JSON"
    assert_equals "4" "$(grep -c '^{"video_id"' "$CATALOG_DB")" "layout: one record per line"
    assert_equals '{"videos":[' "$(head -n 1 "$CATALOG_DB")" "layout: the first line opens the array"
    _teardown
}

test_a_catalog_in_another_layout_is_converted_once() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    jq . "$CATALOG_DB" > "$TEST_TMPDIR/pretty" && mv "$TEST_TMPDIR/pretty" "$CATALOG_DB"      # pretty-printed
    init_catalog_db
    assert_equals '{"videos":[' "$(head -n 1 "$CATALOG_DB")" "convert: a pretty-printed catalog is rewritten"
    assert_equals "4" "$(grep -c '^{"video_id"' "$CATALOG_DB")" "convert: every record survives"
    _teardown
}

test_names_with_quotes_and_backslashes_are_found() {
    _setup
    echo "q" > "$D1/Movies/say \"hello\" now.mp4"
    echo "b" > "$D1/Movies/back\\slash.mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_contains 'say "hello" now.mp4' "$(search_catalog 'say "hello"' all 2>&1 | _strip)" "search: a term with a quote still matches"
    assert_contains 'back\slash.mp4' "$(search_catalog 'back\slash' all 2>&1 | _strip)" "search: a term with a backslash still matches"
    # and a rescan recognises the file instead of treating it as new
    reset_statistics
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "0" "${STATS[catalog_added]}" "rescan: odd names are recognised as unchanged"
    _teardown
}

test_drives_not_scanned_for_a_while_are_flagged() {
    _setup
    catalog_drive "$D1" true >/dev/null 2>&1
    assert_equals "" "$(catalog_stale_drives)" "stale: a drive scanned just now is fine"

    local old; old="$(date -u -d '45 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-45d +%Y-%m-%dT%H:%M:%SZ)"
    jq --arg t "$old" '.drives[0].last_scanned = $t' "$CATALOG_DRIVES_DB" > "$CATALOG_DRIVES_DB.tmp" && mv "$CATALOG_DRIVES_DB.tmp" "$CATALOG_DRIVES_DB"
    assert_contains "45" "$(catalog_stale_drives)" "stale: a 45 day old scan is flagged with its age"
    assert_contains "Out of date: 45 days ago" "$(list_cataloged_drives 2>&1 | _strip)" "list: shows how old the scan is"

    CATALOG_STALE_DAYS=60
    assert_equals "" "$(catalog_stale_drives)" "stale: the limit is configurable"
    CATALOG_STALE_DAYS=30

    jq '.drives[0].last_scanned = ""' "$CATALOG_DRIVES_DB" > "$CATALOG_DRIVES_DB.tmp" && mv "$CATALOG_DRIVES_DB.tmp" "$CATALOG_DRIVES_DB"
    assert_contains "never scanned" "$(list_cataloged_drives 2>&1 | _strip)" "list: a drive with no scan is flagged"
    _teardown
}

test_hashes_that_look_like_numbers_do_not_merge_groups() {
    _setup
    echo "a" > "$D2/Backup/dupA.mp4"; echo "b" > "$D2/Backup/dupB.mp4"
    echo "c" > "$D2/Backup/third.mp4"; echo "d" > "$D1/Movies/third elsewhere.mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    catalog_drive "$D2" true >/dev/null 2>&1
    # Two copies on one drive share a hash that reads as a number (6115002e8885 is
    # 6115002 x 10^8885); the next hash in sort order is shared across both drives.
    local h1="00000000000000000000000000000000000000000000000000006115002e8885"
    local h2="000000000000000000000000000000000000000000000000000061159e660236"
    jq -r --arg h1 "$h1" --arg h2 "$h2" '
        .videos |= map(if .filename == "dupA.mp4" or .filename == "dupB.mp4" then .hash = $h1
                       elif .filename == "third.mp4" or .filename == "third elsewhere.mp4" then .hash = $h2
                       else . end) | '"$_CAT_FMT" "$CATALOG_DB" > "$CATALOG_DB.tmp" && mv "$CATALOG_DB.tmp" "$CATALOG_DB"
    local out; out="$(catalog_duplicate_candidates | tr '\037' '|')"
    assert_contains "|Drive Two|" "$out" "numeric-looking hashes: drive two still offered"
    assert_equals "1" "$(_catalog_duplicate_plan id-two | grep -c 'third.mp4')" "numeric-looking hashes: the cross-drive copy is found"
    assert_equals "0" "$(_catalog_duplicate_plan id-two | grep -c 'dup[AB].mp4')" "numeric-looking hashes: two copies on one drive are not offered"
    _teardown
}

test_the_duplicate_report_can_show_every_group_and_points_to_how() {
    _setup
    echo "one" > "$D1/Movies/a.mp4"; echo "one" > "$D2/Backup/a2.mp4"
    echo "two" > "$D1/Movies/b.mp4"; echo "two" > "$D2/Backup/b2.mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    catalog_drive "$D2" true >/dev/null 2>&1
    DUPLICATE_REPORT_GROUPS=1
    local out; out="$(show_duplicates_report all 0 2>&1 | _strip)"
    assert_equals "2" "$(grep -c 'Group [0-9]' <<< "$out")" "report all: a limit of 0 prints every group"
    out="$(show_duplicates_report 2>&1 | _strip)"
    assert_contains "catalog-duplicates --all" "$out" "report cap: the partial list says how to see everything"
    DUPLICATE_REPORT_GROUPS=200
    _teardown
}

test_the_duplicate_report_caps_the_groups_it_prints_but_counts_them_all() {
    _setup
    echo "one" > "$D1/Movies/a.mp4"; echo "one" > "$D2/Backup/a2.mp4"
    echo "two" > "$D1/Movies/b.mp4"; echo "two" > "$D2/Backup/b2.mp4"
    catalog_drive "$D1" true >/dev/null 2>&1
    catalog_drive "$D2" true >/dev/null 2>&1
    DUPLICATE_REPORT_GROUPS=1
    local out; out="$(show_duplicates_report 2>&1 | _strip)"
    assert_equals "1" "$(grep -c 'Group [0-9]' <<< "$out")" "report cap: only one group is printed"
    assert_contains "Showing the first 1 of 2 groups" "$out" "report cap: says it is a partial list"
    assert_contains "2 duplicate group(s), 2 extra copies" "$out" "report cap: the summary still counts every group"
    DUPLICATE_REPORT_GROUPS=200
    out="$(show_duplicates_report 2>&1 | _strip)"
    assert_equals "2" "$(grep -c 'Group [0-9]' <<< "$out")" "report: both groups printed under the default cap"
    _teardown
}
