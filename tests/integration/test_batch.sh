#!/usr/bin/env bash
# Integration tests for lib/batch.sh:
#   batch_process_folders results, _batch_describe, queue helpers,
#   non-interactive batch_rename_interactive

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "file-ops.sh"
load_module_under_test "duplicates.sh"
load_module_under_test "browser.sh"
load_module_under_test "theme.sh"
load_module_under_test "batch.sh"

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    mkdir -p "$TEST_TMPDIR/a" "$TEST_TMPDIR/b"
    touch "$TEST_TMPDIR/a/studio one.mp4" "$TEST_TMPDIR/a/two x.mkv" "$TEST_TMPDIR/b/[Ok] fine.mp4"
    reset_statistics
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

test_describe_summarises_changes() {
    _batch_describe "5 1 0 0 0 0" "9 3 0 0 0 0"
    assert_equals "2 renamed" "$_BATCH_NOTE" "describe: lists what was renamed"
    _batch_describe "0 0 0 0 0 0" "4 0 0 0 0 0"
    assert_equals "4 checked, no changes" "$_BATCH_NOTE" "describe: says so when nothing changed"
    _batch_describe "0 0 0 0 0 0" "3 0 0 0 1 0"
    assert_equals "1" "$_BATCH_ERRORS" "describe: counts errors"
    _batch_describe "0 0 0 0 0 0" "2 0 0 0 0 2"
    assert_equals "2 would be renamed" "$_BATCH_NOTE" "describe: previews say would be renamed"
}

test_batch_renames_every_folder() {
    _setup
    batch_process_folders rename "$TEST_TMPDIR/a" "$TEST_TMPDIR/b" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a/[Studio] one.mp4" "batch rename: first folder processed"
    assert_file_exists "$TEST_TMPDIR/a/[Two] x.mkv" "batch rename: all files in the first folder"
    assert_equals "2" "${#BATCH_RESULT_NAMES[@]}" "batch rename: one result per folder"
    assert_equals "ok:ok" "${BATCH_RESULT_STATUS[0]}:${BATCH_RESULT_STATUS[1]}" "batch rename: both folders ok"
    assert_contains "renamed" "${BATCH_RESULT_NOTE[0]}" "batch rename: result note says what happened"
    _teardown
}

test_batch_dry_run_changes_nothing_but_reports() {
    _setup
    DRY_RUN=true batch_process_folders rename "$TEST_TMPDIR/a" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a/studio one.mp4" "batch dry run: files untouched"
    assert_contains "would be renamed" "${BATCH_RESULT_NOTE[0]}" "batch dry run: reports what would change"
    _teardown
}

test_batch_missing_folder_is_a_failure() {
    _setup
    local rc=0
    batch_process_folders rename "$TEST_TMPDIR/a" "$TEST_TMPDIR/nope" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "batch: a missing folder makes the batch fail"
    assert_equals "fail" "${BATCH_RESULT_STATUS[1]}" "batch: the missing folder is marked failed"
    assert_equals "[Studio] one.mp4" "$(ls "$TEST_TMPDIR/a" | grep -i studio)" "batch: the other folders still run"
    _teardown
}

test_batch_without_folders_errors() {
    local rc=0
    batch_process_folders rename >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "batch: no folders is an error"
}

test_queue_add_dedupes_and_counts_videos() {
    _setup
    BATCH_FOLDERS=(); BATCH_VIDEO_COUNTS=()
    _batch_add_folder "$TEST_TMPDIR/a"
    local rc=0
    _batch_add_folder "$TEST_TMPDIR/a" || rc=$?
    assert_equals "1" "$rc" "queue: adding the same folder twice is refused"
    assert_equals "1" "${#BATCH_FOLDERS[@]}" "queue: stays at one entry"
    assert_equals "2" "${BATCH_VIDEO_COUNTS[$TEST_TMPDIR/a]}" "queue: video count recorded"
    _teardown
}

test_non_interactive_batch_reads_lines_and_runs() {
    _setup
    printf '%s\n%s\n\n' "$TEST_TMPDIR/a" "$TEST_TMPDIR/b" | batch_rename_interactive >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a/[Studio] one.mp4" "batch (piped): runs without prompting"
    _teardown
}

test_non_interactive_batch_ignores_bad_paths() {
    _setup
    batch_rename_interactive < <(printf '%s\n%s\n\n' "$TEST_TMPDIR/missing" "$TEST_TMPDIR/b") >/dev/null 2>&1
    assert_equals "1" "${#BATCH_FOLDERS[@]}" "batch (piped): invalid directories are skipped"
    _teardown
}

test_batch_duplicates_reports_per_folder() {
    _setup
    echo same > "$TEST_TMPDIR/a/one.mp4"; echo same > "$TEST_TMPDIR/a/two.mp4"
    echo other > "$TEST_TMPDIR/b/solo.mp4"
    batch_process_folders duplicates "$TEST_TMPDIR/a" "$TEST_TMPDIR/b" >/dev/null 2>&1
    assert_contains "duplicate" "${BATCH_RESULT_NOTE[0]}" "batch duplicates: the folder with a copy reports it"
    [[ "${BATCH_RESULT_NOTE[1]}" != *duplicate* ]]; assert_equals "0" "$?" "batch duplicates: the clean folder reports none"
    assert_file_exists "$TEST_TMPDIR/a/one.mp4" "batch duplicates: report only, nothing deleted"
    _teardown
}

test_duplicate_scan_keeps_the_first_alphabetically() {
    _setup
    echo same > "$TEST_TMPDIR/a/zzz.mp4"; echo same > "$TEST_TMPDIR/a/aaa.mp4"
    DRY_RUN=false find_duplicates "$TEST_TMPDIR/a" delete >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/a/aaa.mp4" "duplicates: the alphabetically first copy is kept"
    assert_file_not_exists "$TEST_TMPDIR/a/zzz.mp4" "duplicates: the later copy is the one removed"
    _teardown
}

# ── Batch subtitles ───────────────────────────────────────────────────────────

_setup_batch_subtitles() {
    _setup
    load_module_under_test "subtitles.sh"
    mkdir -p "$TEST_TMPDIR/bin" "$TEST_TMPDIR/s1" "$TEST_TMPDIR/s2"
    cat > "$TEST_TMPDIR/bin/whisper" <<'MOCK'
#!/usr/bin/env bash
input=""; out="."; fmt="srt"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output_dir) out="$2"; shift 2 ;;
        --output_format) fmt="$2"; shift 2 ;;
        --model|--language|--device|--verbose|--fp16) shift 2 ;;
        *) input="$1"; shift ;;
    esac
done
base="$(basename "${input%.*}")"
if [[ "$base" == quiet* ]]; then
    printf '1\n00:00:00,000 --> 00:00:07,000\n.\n' > "$out/$base.$fmt"
else
    printf '1\n00:00:00,000 --> 00:00:02,000\nHello there\n' > "$out/$base.$fmt"
fi
MOCK
    chmod +x "$TEST_TMPDIR/bin/whisper"
    _SAVED_PATH="$PATH"; export PATH="$TEST_TMPDIR/bin:$PATH"
    touch "$TEST_TMPDIR/s1/talk one.mp4" "$TEST_TMPDIR/s1/talk two.mp4" "$TEST_TMPDIR/s2/quiet.mp4"
    SUBTITLE_PARALLEL_JOBS=1; SUBTITLE_SKIP_EXISTING=true; SUBTITLE_RECURSIVE=false
    SUBTITLE_MIN_SIZE_MB=0; SUBTITLE_MAX_SIZE_MB=0; SUBTITLE_MODIFIED_DAYS=0; SUBTITLE_MAX_FILES=0
    SUBTITLE_USE_GPU=false; SUBTITLE_SHOW_DIR_STATS=false; SUBTITLE_INTERACTIVE_EDIT=false
    SUBTITLE_AUTO_PUNCTUATION=false; SUBTITLE_INTERACTIVE_SELECT=false
    WHISPER_MODEL=base; SUBTITLE_FORMAT=srt; SUBTITLE_LANGUAGE=auto
}
_teardown_batch_subtitles() { export PATH="$_SAVED_PATH"; _teardown; }

test_batch_subtitles_reports_each_folder() {
    _setup_batch_subtitles
    batch_process_folders subtitles "$TEST_TMPDIR/s1" "$TEST_TMPDIR/s2" >/dev/null 2>&1
    assert_file_exists "$TEST_TMPDIR/s1/talk one.srt" "batch subtitles: first folder processed"
    assert_equals "2 generated" "${BATCH_RESULT_NOTE[0]}" "batch subtitles: first folder note"
    assert_equals "1 no speech" "${BATCH_RESULT_NOTE[1]}" "batch subtitles: a silent video is reported as no speech"
    assert_file_not_exists "$TEST_TMPDIR/s2/quiet.srt" "batch subtitles: no filler subtitle written"
    _teardown_batch_subtitles
}

test_batch_subtitles_second_run_reports_already_done() {
    _setup_batch_subtitles
    batch_process_folders subtitles "$TEST_TMPDIR/s1" >/dev/null 2>&1
    batch_process_folders subtitles "$TEST_TMPDIR/s1" >/dev/null 2>&1
    assert_equals "2 already done" "${BATCH_RESULT_NOTE[0]}" "batch subtitles: existing subtitles are reported as already done"
    _teardown_batch_subtitles
}

test_batch_subtitles_dry_run_previews() {
    _setup_batch_subtitles
    DRY_RUN=true batch_process_folders subtitles "$TEST_TMPDIR/s1" >/dev/null 2>&1
    assert_equals "2 would be transcribed" "${BATCH_RESULT_NOTE[0]}" "batch subtitles dry run: says how many would be transcribed"
    assert_file_not_exists "$TEST_TMPDIR/s1/talk one.srt" "batch subtitles dry run: nothing written"
    _teardown_batch_subtitles
}

test_batch_subtitles_without_whisper_fails_up_front() {
    _setup_batch_subtitles
    export PATH="$TEST_TMPDIR/empty_bin"; mkdir -p "$TEST_TMPDIR/empty_bin"
    local rc=0
    batch_subtitles_interactive >/dev/null 2>&1 < /dev/null || rc=$?
    export PATH="$_SAVED_PATH"
    assert_equals "1" "$rc" "batch subtitles: a missing Whisper is reported once, before any folder is queued"
    _teardown_batch_subtitles
}

test_subtitle_summary_line_counts_only_its_own_folder() {
    _setup_batch_subtitles
    source "$LIB_DIR/logging.sh"; LOG_FILE=/dev/null   # the summary is a log_info line; stubs print nothing
    STATS[subtitles_generated]=0; STATS[files_skipped]=0; STATS[subtitles_no_speech]=0
    local out1 out2
    out1="$(generate_subtitles_in_directory "$TEST_TMPDIR/s1" base srt auto false 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
    STATS[subtitles_generated]=2
    out2="$(generate_subtitles_in_directory "$TEST_TMPDIR/s2" base srt auto false 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
    assert_contains "complete: 2 generated, 0 skipped" "$out1" "subtitle summary: first folder"
    assert_contains "complete: 0 generated, 0 skipped, 1 with no speech" "$out2" "subtitle summary: the second folder does not repeat the first folder's total"
    stub_logging
    _teardown_batch_subtitles
}
