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
        *) input_file="$1"; shift ;;
    esac
done
base="$(basename "${input_file%.*}")"
printf "1\n00:00:00,000 --> 00:00:02,000\nMock subtitle\n" > "${output_dir}/${base}.${format}"
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
    echo "ORIGINAL" > "$TEST_TMPDIR/movie.srt"
    SUBTITLE_SKIP_EXISTING=true
    generate_subtitles_in_directory "$TEST_TMPDIR" >/dev/null 2>&1
    _restore_path
    local content
    content=$(cat "$TEST_TMPDIR/movie.srt")
    assert_equals "ORIGINAL" "$content" "skip existing: .srt content unchanged"
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
