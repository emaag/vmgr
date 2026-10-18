#!/usr/bin/env bash
# Integration tests for subtitle generation: lib/subtitles.sh
#   generate_subtitles_in_directory, edit_subtitle_interactive

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "subtitles.sh"

# ── Per-test setup / teardown ─────────────────────────────────────────────────

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    # Predictable, minimal defaults for all subtitle tests
    SUBTITLE_PARALLEL_JOBS=1
    SUBTITLE_SKIP_EXISTING=true
    SUBTITLE_RECURSIVE=false
    SUBTITLE_MIN_SIZE_MB=0
    SUBTITLE_MAX_SIZE_MB=0
    SUBTITLE_MODIFIED_DAYS=0
    SUBTITLE_MAX_FILES=0
    SUBTITLE_USE_GPU=false
    SUBTITLE_SHOW_DIR_STATS=false
    SUBTITLE_INTERACTIVE_EDIT=false
    SUBTITLE_AUTO_PUNCTUATION=false
    # Reset relevant stats for isolation
    STATS[subtitles_generated]=0
    STATS[subtitles_failed]=0
    STATS[files_skipped]=0
    STATS[files_processed]=0
}

_teardown() {
    [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"
}

# ── Mock whisper helpers ──────────────────────────────────────────────────────

# Install a standard mock whisper into $TEST_TMPDIR/mock_bin and prepend to PATH.
# The mock creates a stub subtitle file and exits 0.
_setup_mock_whisper() {
    mkdir -p "$TEST_TMPDIR/mock_bin"
    cat > "$TEST_TMPDIR/mock_bin/whisper" << 'MOCKEOF'
#!/usr/bin/env bash
input_file=""; output_dir="."; format="srt"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output_dir)     output_dir="$2"; shift 2 ;;
        --output_format)  format="$2";     shift 2 ;;
        --model|--language|--device) shift 2 ;;
        --verbose|--fp16) shift 2 ;;
        *) input_file="$1"; shift ;;
    esac
done
base="$(basename "${input_file%.*}")"
[[ -n "${MOCK_WHISPER_FAIL:-}" && "$input_file" == *"$MOCK_WHISPER_FAIL"* ]] && exit 3
[[ -n "${MOCK_WHISPER_CALLS:-}" ]] && echo "$input_file" >> "$MOCK_WHISPER_CALLS"
if [[ -n "${MOCK_WHISPER_SLEEP:-}" ]]; then
    printf "1\n00:00:00,000 --> 00:00:02,000\npartial\n" > "${output_dir}/${base}.${format}"
    sleep "$MOCK_WHISPER_SLEEP"
fi
if [[ -n "${MOCK_WHISPER_BODY:-}" ]]; then
    printf '%b' "$MOCK_WHISPER_BODY" > "${output_dir}/${base}.${format}"
else
    printf "1\n00:00:00,000 --> 00:00:02,000\nMock subtitle\n" > "${output_dir}/${base}.${format}"
fi
exit 0
MOCKEOF
    chmod +x "$TEST_TMPDIR/mock_bin/whisper"
    _SAVED_PATH="$PATH"
    export PATH="$TEST_TMPDIR/mock_bin:$PATH"
}

_restore_path() {
    export PATH="$_SAVED_PATH"
}

# ── Tests: generate_subtitles_in_directory ────────────────────────────────────

test_subtitles_nonexistent_dir_returns_error() {
    _setup
    local rc=0
    generate_subtitles_in_directory "/nonexistent/dir/xyz_vmgr_test" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "nonexistent dir: returns 1"
    _teardown
}

test_subtitles_no_whisper_not_installed() {
    _setup
    local dir="$TEST_TMPDIR/videos"
    mkdir -p "$dir"
    touch "$dir/video.mp4"
    # Use an empty bin directory so neither whisper nor whisper.cpp is found
    mkdir -p "$TEST_TMPDIR/empty_bin"
    local saved_path="$PATH"
    export PATH="$TEST_TMPDIR/empty_bin"
    local rc=0
    generate_subtitles_in_directory "$dir" >/dev/null 2>&1 || rc=$?
    export PATH="$saved_path"
    assert_equals "1" "$rc" "no whisper: returns 1 when whisper not installed"
    _teardown
}

test_subtitles_empty_dir_exits_zero() {
    _setup
    _setup_mock_whisper
    local dir="$TEST_TMPDIR/empty"
    mkdir -p "$dir"
    local rc=0
    generate_subtitles_in_directory "$dir" >/dev/null 2>&1 || rc=$?
    _restore_path
    assert_equals "0" "$rc" "empty dir: exits 0 when no video files found"
    _teardown
}

test_subtitles_creates_srt_file() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/movie.mp4"
    generate_subtitles_in_directory "$TEST_TMPDIR" "base" "srt" "auto" false >/dev/null 2>&1
    _restore_path
    assert_file_exists "$TEST_TMPDIR/movie.srt" "creates srt: .srt file created for .mp4"
    _teardown
}

test_subtitles_updates_stats_generated() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/movie.mp4"
    generate_subtitles_in_directory "$TEST_TMPDIR" >/dev/null 2>&1
    _restore_path
    assert_not_equals "0" "${STATS[subtitles_generated]}" \
        "stats: subtitles_generated incremented after generation"
    _teardown
}

test_subtitles_skip_existing() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/movie.mp4"
    # Must look like a valid SRT (has a timestamp line) or _is_valid_subtitle
    # treats it as an incomplete leftover and reprocesses it regardless of
    # SUBTITLE_SKIP_EXISTING.
    printf "1\n00:00:00,000 --> 00:00:02,000\nORIGINAL\n" > "$TEST_TMPDIR/movie.srt"
    SUBTITLE_SKIP_EXISTING=true
    generate_subtitles_in_directory "$TEST_TMPDIR" >/dev/null 2>&1
    _restore_path
    local content
    content=$(cat "$TEST_TMPDIR/movie.srt")
    assert_contains "ORIGINAL" "$content" "skip existing: .srt content unchanged"
    assert_not_equals "0" "${STATS[files_skipped]}" \
        "skip existing: files_skipped stat incremented"
    _teardown
}

test_subtitles_no_skip_when_flag_off() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/movie.mp4"
    echo "ORIGINAL" > "$TEST_TMPDIR/movie.srt"
    SUBTITLE_SKIP_EXISTING=false
    generate_subtitles_in_directory "$TEST_TMPDIR" >/dev/null 2>&1
    _restore_path
    local content
    content=$(cat "$TEST_TMPDIR/movie.srt")
    assert_contains "Mock subtitle" "$content" \
        "no skip flag off: .srt overwritten by mock whisper"
    _teardown
}

test_subtitles_dry_run_no_file_created() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/movie.mp4"
    local rc=0
    generate_subtitles_in_directory "$TEST_TMPDIR" "base" "srt" "auto" true >/dev/null 2>&1 || rc=$?
    _restore_path
    assert_equals "0" "$rc" "dry run: exits 0"
    assert_file_not_exists "$TEST_TMPDIR/movie.srt" "dry run: no .srt created"
    _teardown
}

test_subtitles_max_files_limits_processing() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/alpha.mp4"
    touch "$TEST_TMPDIR/beta.mp4"
    touch "$TEST_TMPDIR/gamma.mp4"
    SUBTITLE_MAX_FILES=2
    generate_subtitles_in_directory "$TEST_TMPDIR" >/dev/null 2>&1
    _restore_path
    local -a srt_files
    mapfile -t srt_files < <(find "$TEST_TMPDIR" -maxdepth 1 -name "*.srt")
    assert_equals "2" "${#srt_files[@]}" "max files: exactly 2 .srt files created"
    _teardown
}

test_subtitles_language_auto_no_lang_arg() {
    _setup
    local args_log="$TEST_TMPDIR/whisper_args.log"
    # Build a logging mock whisper; embed $args_log path at write time
    mkdir -p "$TEST_TMPDIR/mock_bin"
    cat > "$TEST_TMPDIR/mock_bin/whisper" << MOCKEOF
#!/usr/bin/env bash
echo "\$@" >> "${args_log}"
input_file=""; output_dir="."; format="srt"
while [[ \$# -gt 0 ]]; do
    case "\$1" in
        --output_dir)    output_dir="\$2"; shift 2 ;;
        --output_format) format="\$2";     shift 2 ;;
        --model|--language|--device) shift 2 ;;
        --verbose|--fp16) shift 2 ;;
        *) input_file="\$1"; shift ;;
    esac
done
base="\$(basename "\${input_file%.*}")"
printf "1\n00:00:00,000 --> 00:00:02,000\nMock subtitle\n" > "\${output_dir}/\${base}.\${format}"
exit 0
MOCKEOF
    chmod +x "$TEST_TMPDIR/mock_bin/whisper"
    local saved_path="$PATH"
    export PATH="$TEST_TMPDIR/mock_bin:$PATH"

    touch "$TEST_TMPDIR/video.mp4"
    generate_subtitles_in_directory "$TEST_TMPDIR" "base" "srt" "auto" false >/dev/null 2>&1

    export PATH="$saved_path"

    local has_lang=false
    if [[ -f "$args_log" ]] && grep -q -- "--language" "$args_log" 2>/dev/null; then
        has_lang=true
    fi
    assert_equals "false" "$has_lang" \
        "auto language: --language not passed to whisper when language is auto"
    _teardown
}

# ── Tests: edit_subtitle_interactive ─────────────────────────────────────────

test_edit_subtitle_missing_file_returns_error() {
    _setup
    local rc=0
    edit_subtitle_interactive "/nonexistent/subtitle_vmgr_test.srt" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "edit missing file: returns 1"
    _teardown
}

test_edit_subtitle_calls_editor() {
    _setup
    touch "$TEST_TMPDIR/video.srt"
    local sentinel="$TEST_TMPDIR/editor_called"
    # Mock editor touches a sentinel file so we can verify it was invoked
    cat > "$TEST_TMPDIR/mock_editor.sh" << EDITOREOF
#!/usr/bin/env bash
touch "${sentinel}"
EDITOREOF
    chmod +x "$TEST_TMPDIR/mock_editor.sh"
    EDITOR="$TEST_TMPDIR/mock_editor.sh"
    edit_subtitle_interactive "$TEST_TMPDIR/video.srt" >/dev/null 2>&1
    assert_file_exists "$sentinel" "edit subtitle: editor was invoked"
    _teardown
}

# ── Filler cues and "no speech" ───────────────────────────────────────────────

_FILLER_SRT='1\n00:00:00,000 --> 00:00:07,000\n.\n\n2\n00:00:07,000 --> 00:00:14,000\n...\n\n3\n00:00:14,000 --> 00:00:21,000\n.\n'
_MIXED_SRT='1\n00:00:00,000 --> 00:00:02,000\nHello there\n\n2\n00:00:02,000 --> 00:00:09,000\n.\n\n3\n00:00:09,000 --> 00:00:11,000\nSecond line\nstill the same cue\n'

test_clean_cues_reports_no_speech_for_filler_only() {
    _setup
    printf '%b' "$_FILLER_SRT" > "$TEST_TMPDIR/a.srt"
    local rc=0
    _clean_subtitle_cues "$TEST_TMPDIR/a.srt" srt || rc=$?
    assert_equals "1" "$rc" "clean cues: filler only means no speech"
    assert_equals "3" "$_SUBTITLE_REMOVED_CUES" "clean cues: counts the filler cues"
    _teardown
}

test_clean_cues_drops_filler_and_renumbers() {
    _setup
    printf '%b' "$_MIXED_SRT" > "$TEST_TMPDIR/a.srt"
    _clean_subtitle_cues "$TEST_TMPDIR/a.srt" srt
    assert_equals "1" "$_SUBTITLE_REMOVED_CUES" "clean cues: one filler cue removed"
    local out; out="$(cat "$TEST_TMPDIR/a.srt")"
    assert_contains "Hello there" "$out" "clean cues: real text kept"
    assert_contains $'2\n00:00:09,000 --> 00:00:11,000\nSecond line\nstill the same cue' "$out" "clean cues: cues renumbered, multi-line cue intact"
    [[ "$out" != *"00:00:02,000 --> 00:00:09,000"* ]]
    assert_equals "0" "$?" "clean cues: the filler cue's timestamp is gone"
    _teardown
}

test_clean_cues_leaves_a_clean_file_untouched() {
    _setup
    printf '1\n00:00:00,000 --> 00:00:02,000\nHello\n\n2\n00:00:02,000 --> 00:00:04,000\nWorld\n\n' > "$TEST_TMPDIR/a.srt"
    local before; before="$(cat "$TEST_TMPDIR/a.srt")"
    _clean_subtitle_cues "$TEST_TMPDIR/a.srt" srt
    assert_equals "$before" "$(cat "$TEST_TMPDIR/a.srt")" "clean cues: a file with real text only is not rewritten"
    _teardown
}

test_clean_cues_keeps_non_latin_and_accented_text() {
    _setup
    printf '1\n00:00:00,000 --> 00:00:02,000\n日本語\n\n2\n00:00:02,000 --> 00:00:04,000\ncafé\n\n3\n00:00:04,000 --> 00:00:06,000\n...\n' > "$TEST_TMPDIR/a.srt"
    _clean_subtitle_cues "$TEST_TMPDIR/a.srt" srt
    local out; out="$(cat "$TEST_TMPDIR/a.srt")"
    assert_contains "日本語" "$out" "clean cues: Japanese text kept"
    assert_contains "café" "$out" "clean cues: accented text kept"
    assert_equals "1" "$_SUBTITLE_REMOVED_CUES" "clean cues: only the dots were removed"
    _teardown
}

test_clean_cues_vtt_keeps_header_and_cue_ids() {
    _setup
    printf 'WEBVTT\n\nintro\n00:00:00.000 --> 00:00:02.000\nHello\n\n00:00:02.000 --> 00:00:04.000\n.\n' > "$TEST_TMPDIR/a.vtt"
    _clean_subtitle_cues "$TEST_TMPDIR/a.vtt" vtt
    local out; out="$(cat "$TEST_TMPDIR/a.vtt")"
    assert_contains "WEBVTT" "$out" "clean cues (vtt): header kept"
    assert_contains "intro" "$out" "clean cues (vtt): cue identifier kept"
    assert_equals "1" "$_SUBTITLE_REMOVED_CUES" "clean cues (vtt): filler removed"
    _teardown
}

test_clean_cues_txt() {
    _setup
    printf '.\n' > "$TEST_TMPDIR/a.txt"
    local rc=0; _clean_subtitle_cues "$TEST_TMPDIR/a.txt" txt || rc=$?
    assert_equals "1" "$rc" "clean cues (txt): punctuation only is no speech"
    printf 'hello\n' > "$TEST_TMPDIR/b.txt"
    rc=0; _clean_subtitle_cues "$TEST_TMPDIR/b.txt" txt || rc=$?
    assert_equals "0" "$rc" "clean cues (txt): text is speech"
    _teardown
}

test_filler_only_output_is_reported_as_no_speech() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/quiet.mp4"
    STATS[subtitles_no_speech]=0
    MOCK_WHISPER_BODY="$_FILLER_SRT" generate_subtitles_in_directory "$TEST_TMPDIR" base srt auto false >/dev/null 2>&1
    _restore_path
    assert_file_not_exists "$TEST_TMPDIR/quiet.srt" "no speech: no subtitle file is left behind"
    assert_file_exists "$TEST_TMPDIR/.quiet.nospeech" "no speech: a hidden marker records it"
    assert_equals "1" "${STATS[subtitles_no_speech]}" "no speech: counted"
    assert_equals "0" "${STATS[subtitles_generated]}" "no speech: not counted as generated"
    _teardown
}

test_no_speech_video_is_not_retranscribed_until_the_marker_is_removed() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/quiet.mp4"
    export MOCK_WHISPER_CALLS="$TEST_TMPDIR/calls"
    MOCK_WHISPER_BODY="$_FILLER_SRT" generate_subtitles_in_directory "$TEST_TMPDIR" base srt auto false >/dev/null 2>&1
    assert_equals "1" "$(wc -l < "$TEST_TMPDIR/calls" | tr -d ' ')" "no speech: whisper ran once"
    generate_subtitles_in_directory "$TEST_TMPDIR" base srt auto false >/dev/null 2>&1
    assert_equals "1" "$(wc -l < "$TEST_TMPDIR/calls" | tr -d ' ')" "no speech: a second run skips the video"
    rm -f "$TEST_TMPDIR/.quiet.nospeech"
    generate_subtitles_in_directory "$TEST_TMPDIR" base srt auto false >/dev/null 2>&1
    assert_equals "2" "$(wc -l < "$TEST_TMPDIR/calls" | tr -d ' ')" "no speech: removing the marker retries it"
    unset MOCK_WHISPER_CALLS
    _restore_path
    _teardown
}

test_mixed_output_keeps_the_real_cues() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/talk.mp4"
    MOCK_WHISPER_BODY="$_MIXED_SRT" generate_subtitles_in_directory "$TEST_TMPDIR" base srt auto false >/dev/null 2>&1
    _restore_path
    assert_file_exists "$TEST_TMPDIR/talk.srt" "mixed: the subtitle is written"
    assert_contains "Hello there" "$(cat "$TEST_TMPDIR/talk.srt")" "mixed: real cues kept"
    assert_equals "0" "$(grep -c '^\.$' "$TEST_TMPDIR/talk.srt")" "mixed: filler cues removed"
    assert_file_not_exists "$TEST_TMPDIR/.talk.nospeech" "mixed: no no-speech marker"
    _teardown
}

test_failed_videos_are_listed_in_the_closing_report() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/good.mp4" "$TEST_TMPDIR/bad.mp4"
    local out
    out=$(MOCK_WHISPER_FAIL="bad" generate_subtitles_in_directory "$TEST_TMPDIR" base srt auto false 2>&1)
    _restore_path
    assert_contains "1 video(s) failed" "$out" "failures: count reported"
    assert_contains "bad.mp4 (whisper exited with code 3)" "$out" "failures: failed video named"
    assert_file_exists "$TEST_TMPDIR/good.srt" "failures: other videos still processed"
    assert_file_not_exists "$TEST_TMPDIR/bad.srt" "failures: no subtitle left for the failed video"
    _teardown
}

test_interrupt_stops_the_run_and_removes_the_partial_subtitle() {
    _setup
    _setup_mock_whisper
    touch "$TEST_TMPDIR/a.mp4" "$TEST_TMPDIR/b.mp4"
    export MOCK_WHISPER_CALLS="$TEST_TMPDIR/calls"
    local me=$BASHPID; ( sleep 1; kill -TERM $me ) &
    local killer=$! rc=0 start=$SECONDS
    MOCK_WHISPER_SLEEP=30 generate_subtitles_in_directory "$TEST_TMPDIR" base srt auto false >/dev/null 2>&1 || rc=$?
    local took=$(( SECONDS - start ))
    kill "$killer" 2>/dev/null
    unset MOCK_WHISPER_CALLS
    _restore_path
    assert_equals "130" "$rc" "interrupt: returns 130"
    assert_equals "0" "$(( took < 10 ? 0 : 1 ))" "interrupt: stops promptly instead of finishing the file"
    assert_file_not_exists "$TEST_TMPDIR/a.srt" "interrupt: partial subtitle removed"
    assert_equals "1" "$(wc -l < "$TEST_TMPDIR/calls" | tr -d ' ')" "interrupt: remaining videos not started"
    _teardown
}
