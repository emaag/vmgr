#!/usr/bin/env bash
#
# Video Manager Ultimate - Subtitle Generation Module
# Part of the modular video management system
#
# This module provides subtitle generation functionality using OpenAI Whisper.
#
# IMPLEMENTATION STATUS:
#   Implemented:  Whisper/GPU detection helpers (check_whisper_installation, detect_gpu)
#   Stub only:    generate_subtitles_in_directory, batch_generate_subtitles,
#                 edit_subtitle_interactive
#   Not started:  Resume/checkpoint system, subtitle translation, speaker diarization
#
# Dependencies: core.sh, logging.sh, platform.sh, utils.sh
# Status: Phase 3 - Modularization  
# Version: 1.2.0
#

################################################################################
# GPU AND HARDWARE DETECTION
################################################################################

# Detect GPU availability
detect_gpu() {
    local gpu_available=false

    # Check for NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            gpu_available=true
            log_verbose "NVIDIA GPU detected"
        fi
    fi

    # Check for CUDA
    if [[ -d /usr/local/cuda ]] || command -v nvcc &> /dev/null; then
        log_verbose "CUDA installation found"
    fi

    if [[ "$gpu_available" == true ]]; then
        return 0
    else
        return 1
    fi
}


################################################################################
# WHISPER INTEGRATION
################################################################################

# Check if whisper is installed
check_whisper_installation() {
    if command -v whisper &> /dev/null; then
        return 0
    elif command -v whisper.cpp &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Get whisper command
get_whisper_command() {
    if command -v whisper &> /dev/null; then
        echo "whisper"
    elif command -v whisper.cpp &> /dev/null; then
        echo "whisper.cpp"
    else
        echo ""
    fi
}

################################################################################
# SUBTITLE PROCESSING AND EDITING
################################################################################

# Apply basic punctuation and capitalization fixes to a subtitle file
# Called internally by subtitle generation once that feature is implemented
fix_punctuation() {
    local subtitle_file="$1"

    log_verbose "Applying punctuation fixes to: $(basename "$subtitle_file")"

    # Basic punctuation fixes (using platform-compatible sed)
    if sed_inplace_backup "$subtitle_file" ".bak" \
        -e 's/\bi\b/I/g' \
        -e 's/^\([a-z]\)/\U\1/' \
        -e 's/\. \([a-z]\)/. \U\1/g' \
        -e 's/\? \([a-z]\)/? \U\1/g' \
        -e 's/! \([a-z]\)/! \U\1/g' 2>/dev/null; then
        rm -f "${subtitle_file}.bak"
        log_verbose "Punctuation fixes applied"
        return 0
    else
        log_warning "Punctuation fix failed"
        return 1
    fi
}



################################################################################
# SUBTITLE GENERATION
################################################################################

# Print a progress bar line to stderr.
# Args: current total status label  (status: proc | skip | dry | fail)
_print_subtitle_progress() {
    local current="$1"
    local total="$2"
    local status="$3"
    local label="$4"
    local bar_width=25
    local filled=$(( current * bar_width / total ))
    local empty=$(( bar_width - filled ))
    local pct=$(( current * 100 / total ))
    local bar="" i
    for ((i=0; i<filled; i++)); do bar+="#"; done
    for ((i=0; i<empty; i++)); do bar+="-"; done
    printf "[%s] %d/%d (%3d%%) %-4s %s\n" \
        "$bar" "$current" "$total" "$pct" "$status" "${label:0:60}" >&2
}

# Drop cues that contain no letters or digits. Over silence, music and noise
# Whisper writes filler such as "." or "..." with long timestamps; keeping it
# makes a video look subtitled when it is not.
# Rewrites SRT/VTT files in place (SRT cues are renumbered) and checks TXT files.
# Returns 0 when real text remains, 1 when nothing but filler was found.
# Sets _SUBTITLE_REMOVED_CUES to the number of cues dropped.
_clean_subtitle_cues() {
    local file="$1" format="$2" tmp counts kept dropped
    _SUBTITLE_REMOVED_CUES=0
    [[ -f "$file" ]] || return 0

    case "$format" in
        srt|vtt) ;;
        txt) LC_ALL=C grep -q '[^[:space:][:punct:]]' "$file" 2>/dev/null; return ;;
        *) return 0 ;;
    esac

    tmp="$(mktemp)" || return 0
    counts="$(mktemp)" || { rm -f "$tmp"; return 0; }

    # Paragraph mode: one record per cue. A record without a "-->" line (the
    # WEBVTT header, notes) passes through untouched. C locale, so bytes above
    # 127 (accented and non-Latin text) count as text, not punctuation.
    LC_ALL=C awk -v RS= -v FS='\n' -v fmt="$format" -v counts="$counts" '
        {
            t = 0
            for (i = 1; i <= NF; i++) if ($i ~ /-->/) { t = i; break }
            if (t == 0) { print $0 "\n"; next }
            text = ""
            for (i = t + 1; i <= NF; i++) text = text $i
            if (text !~ /[^[:space:][:punct:]]/) { dropped++; next }
            kept++
            if (fmt == "srt") {
                print kept
                for (i = t; i <= NF; i++) print $i
            } else {
                for (i = 1; i <= NF; i++) print $i
            }
            print ""
        }
        END { print kept + 0, dropped + 0 > counts }
    ' "$file" > "$tmp" 2>/dev/null

    read -r kept dropped < "$counts"
    rm -f "$counts"
    kept="${kept:-0}"; dropped="${dropped:-0}"
    _SUBTITLE_REMOVED_CUES=$dropped

    if (( dropped > 0 && kept > 0 )); then
        cat "$tmp" > "$file"
    fi
    rm -f "$tmp"
    (( kept > 0 )) || (( dropped == 0 ))
}

# Hidden marker that records "this video had no speech", so skip-existing does
# not send it through Whisper again on every run. Delete it to retry.
_no_speech_marker() {
    local video_file="$1"
    printf '%s/.%s.nospeech' "$(dirname "$video_file")" "$(basename "${video_file%.*}")"
}

# Ctrl-C / SIGTERM handling. whisper runs in the background (see
# _generate_single_subtitle) so the trap fires at once instead of after the file.
_SUBTITLE_INTERRUPTED=false
_SUBTITLE_WPID=""
_SUBTITLE_JOB_PIDS=()

_subtitle_on_interrupt() {
    _SUBTITLE_INTERRUPTED=true
    local p
    [[ -n "$_SUBTITLE_WPID" ]] && kill -TERM "$_SUBTITLE_WPID" 2>/dev/null
    for p in "${_SUBTITLE_JOB_PIDS[@]}"; do kill -TERM "$p" 2>/dev/null; done
}

# Record a failed video for the closing report. Args: video_file reason
_subtitle_note_failure() {
    [[ -n "${SUBTITLE_FAIL_LOG:-}" ]] && printf '%s\t%s\n' "$1" "$2" >> "$SUBTITLE_FAIL_LOG"
}

# Internal helper: run whisper on a single file and update stats.
# Args: video_file whisper_cmd model format language device output_dir [file_idx] [file_total]
# Language "auto" omits --language entirely (older whisper versions error otherwise).
# Note: STATS updates here only propagate when called inline (sequential mode);
#       in background subshells the parent increments stats at dispatch time.
_generate_single_subtitle() {
    local video_file="$1"
    local whisper_cmd="$2"
    local model="$3"
    local format="$4"
    local language="$5"
    local device="$6"
    local output_dir="$7"
    local file_idx="${8:-0}"
    local file_total="${9:-0}"
    local elapsed_sum="${10:-0}"
    local files_done="${11:-0}"

    # Build language args inside helper to avoid array-passing issues in subshells
    local -a lang_args=()
    if [[ "$language" != "auto" ]]; then
        lang_args=("--language" "$language")
    fi

    # --fp16 False: prevent fp16 on CPU (avoids memory spikes in some whisper versions)
    local -a fp16_args=()
    if [[ "$device" == "cpu" ]]; then
        fp16_args=("--fp16" "False")
    fi

    # Print per-file header
    local filename
    filename="$(basename "$video_file")"
    local file_size
    file_size=$(du -sh "$video_file" 2>/dev/null | cut -f1 || echo "?")
    local counter_str=""
    [[ $file_total -gt 0 ]] && counter_str="${file_idx}/${file_total}"
    local file_start_time
    file_start_time=$(date +%s)

    local eta_str="" eta_plain=""
    if [[ $files_done -gt 0 && $file_total -gt 0 ]]; then
        local avg=$(( elapsed_sum / files_done ))
        local remaining=$(( (file_total - file_idx) * avg ))
        if [[ $remaining -ge 60 ]]; then
            eta_plain="$(( remaining / 60 ))m$(( remaining % 60 ))s"
            eta_str="  ETA ${COLOR_CYAN}${eta_plain}${COLOR_RESET}"
        elif [[ $remaining -gt 0 ]]; then
            eta_plain="${remaining}s"
            eta_str="  ETA ${COLOR_CYAN}${eta_plain}${COLOR_RESET}"
        fi
    fi

    if [[ "$(type -t ui_file_header)" == "function" ]]; then
        ui_file_header "$filename" "$file_idx" "$file_total" "$eta_plain" \
            "${model} ${UI_SEP:-·} ${device} ${UI_SEP:-·} ${format} ${UI_SEP:-·} ${file_size}" >&2
    else
    {
        echo ""
        echo -e "${COLOR_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        if [[ -n "$counter_str" ]]; then
            printf " ${COLOR_BOLD}${COLOR_WHITE}%s${COLOR_RESET}  ${COLOR_BRIGHT_YELLOW}[%s]${COLOR_RESET}%b\n" "$filename" "$counter_str" "$eta_str"
        else
            printf " ${COLOR_BOLD}${COLOR_WHITE}%s${COLOR_RESET}\n" "$filename"
        fi
        printf " ${COLOR_WHITE}Model:${COLOR_RESET} ${COLOR_BRIGHT_CYAN}%-8s${COLOR_RESET}  ${COLOR_WHITE}Device:${COLOR_RESET} ${COLOR_BRIGHT_CYAN}%-6s${COLOR_RESET}  ${COLOR_WHITE}Format:${COLOR_RESET} ${COLOR_BRIGHT_CYAN}%-5s${COLOR_RESET}  ${COLOR_WHITE}Size:${COLOR_RESET} ${COLOR_BRIGHT_CYAN}%s${COLOR_RESET}\n" \
            "$model" "$device" "$format" "$file_size"
        echo -e "${COLOR_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    } >&2
    fi

    log_message "INFO" "Processing: $filename [${counter_str:-?}] model=$model device=$device"

    # Compute expected output path before running whisper so we can clean it up
    # if the process is killed or exits with an error.
    local expected_subtitle="${output_dir}/$(basename "${video_file%.*}").${format}"

    # timeout: kill whisper if it hangs (default 2 hours per file)
    # stdout suppressed (raw transcription text); stderr shown live for progress
    # Run in the background and wait, so Ctrl-C is handled straight away.
    trap _subtitle_on_interrupt INT TERM
    run_with_timeout "${SUBTITLE_TIMEOUT:-7200}" \
        "$whisper_cmd" "$video_file" \
        --model "$model" \
        --output_format "$format" \
        "${lang_args[@]}" \
        --output_dir "$output_dir" \
        --device "$device" \
        --verbose False \
        "${fp16_args[@]}" >/dev/null &
    _SUBTITLE_WPID=$!
    local rc=0
    wait "$_SUBTITLE_WPID" || rc=$?
    if [[ "$_SUBTITLE_INTERRUPTED" == true ]]; then
        kill -TERM "$_SUBTITLE_WPID" 2>/dev/null
        wait "$_SUBTITLE_WPID" 2>/dev/null
        _SUBTITLE_WPID=""
        rm -f "$expected_subtitle"
        return 130
    fi
    _SUBTITLE_WPID=""

    # On failure or timeout, remove any partial file whisper may have written so
    # the next run does not mistake it for a completed subtitle.
    if [[ $rc -eq 124 ]]; then
        log_warning "Whisper timed out after ${SUBTITLE_TIMEOUT:-7200}s: $(basename "$video_file")"
        [[ -f "$expected_subtitle" ]] && rm -f "$expected_subtitle"
        STATS[subtitles_failed]=$(( STATS[subtitles_failed] + 1 ))
        _subtitle_note_failure "$video_file" "timed out"
        return 1
    elif [[ $rc -ne 0 ]]; then
        log_warning "Whisper failed for: $(basename "$video_file")"
        [[ -f "$expected_subtitle" ]] && rm -f "$expected_subtitle"
        STATS[subtitles_failed]=$(( STATS[subtitles_failed] + 1 ))
        _subtitle_note_failure "$video_file" "whisper exited with code $rc"
        return 1
    fi

    local subtitle_file="${video_file%.*}.${format}"
    if [[ ! -f "$subtitle_file" ]]; then
        log_warning "Expected subtitle not found (whisper.cpp naming?): $(basename "$subtitle_file")"
    fi

    # Remove filler cues; if nothing but filler was found, there was no speech
    if [[ -f "$subtitle_file" ]]; then
        if _clean_subtitle_cues "$subtitle_file" "$format"; then
            (( _SUBTITLE_REMOVED_CUES > 0 )) && log_verbose "Removed ${_SUBTITLE_REMOVED_CUES} empty cue(s) from $(basename "$subtitle_file")"
        else
            rm -f "$subtitle_file"
            : > "$(_no_speech_marker "$video_file")" 2>/dev/null
            log_warning "No speech found in $(basename "$video_file"); no subtitle written"
            STATS[subtitles_no_speech]=$(( ${STATS[subtitles_no_speech]:-0} + 1 ))
            STATS[files_processed]=$(( STATS[files_processed] + 1 ))
            return 0
        fi
    fi

    if [[ "${SUBTITLE_AUTO_PUNCTUATION:-false}" == true && -f "$subtitle_file" ]]; then
        fix_punctuation "$subtitle_file"
    fi

    STATS[subtitles_generated]=$(( STATS[subtitles_generated] + 1 ))
    STATS[files_processed]=$(( STATS[files_processed] + 1 ))

    local file_end_time elapsed elapsed_str
    file_end_time=$(date +%s)
    elapsed=$(( file_end_time - file_start_time ))
    if [[ $elapsed -ge 60 ]]; then
        elapsed_str="$(( elapsed / 60 ))m $(( elapsed % 60 ))s"
    else
        elapsed_str="${elapsed}s"
    fi
    log_success "Generated: $(basename "$subtitle_file")  ${COLOR_WHITE}(${elapsed_str})${COLOR_RESET}"
    return 0
}

# Return 0 if a subtitle file exists, is non-empty, and contains at least one
# SRT timestamp line (hh:mm:ss,ms --> hh:mm:ss,ms).  Partial files written by a
# killed whisper process pass the -f/-s tests but fail the timestamp check.
_is_valid_subtitle() {
    local file="$1"
    [[ -f "$file" && -s "$file" ]] || return 1
    grep -qE '[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3} --> ' "$file" 2>/dev/null
}

# Generate subtitles for all videos in a directory using OpenAI Whisper.
# Args: directory [model] [format] [language] [dry_run]
generate_subtitles_in_directory() {
    local directory="$1"
    local model="${2:-base}"
    local format="${3:-srt}"
    local language="${4:-auto}"
    local dry_run="${5:-false}"

    # Counters at the start, so the closing summary covers only this directory
    local gen_before="${STATS[subtitles_generated]:-0}" skip_before="${STATS[files_skipped]:-0}" nospeech_before="${STATS[subtitles_no_speech]:-0}"

    # 1. Validate directory
    if [[ ! -d "$directory" ]]; then
        log_error "Directory not found: $directory"
        return 1
    fi

    # 2. Check whisper installation
    if ! check_whisper_installation; then
        log_error "Whisper is not installed"
        echo ""
        echo -e "${COLOR_YELLOW}Install with:${COLOR_RESET} pip install openai-whisper"
        return 1
    fi

    # 3. Get whisper command
    local whisper_cmd
    whisper_cmd=$(get_whisper_command)

    # 4. Determine compute device
    local device="cpu"
    if [[ "${SUBTITLE_USE_GPU:-false}" == true ]] && detect_gpu; then
        device="cuda"
    fi

    # 5. Build find arguments
    local -a find_args=("$directory")
    if [[ "${SUBTITLE_RECURSIVE:-false}" == true ]]; then
        find_args+=("-maxdepth" "${SUBTITLE_MAX_DEPTH:-5}" "-mindepth" "${SUBTITLE_MIN_DEPTH:-1}")
    else
        find_args+=("-maxdepth" "1")
    fi
    find_args+=("-type" "f" "!" "-path" "*/.vmgr-trash/*")

    # Build video extension name filter
    local -a name_filter=()
    for ext in "${DEFAULT_VIDEO_EXTENSIONS[@]}"; do
        if [[ ${#name_filter[@]} -gt 0 ]]; then
            name_filter+=("-o")
        fi
        name_filter+=("-iname" "*.${ext}")
    done
    find_args+=("(" "${name_filter[@]}" ")")

    # Optional size and date filters
    if [[ "${SUBTITLE_MIN_SIZE_MB:-0}" -gt 0 ]]; then
        find_args+=("-size" "+${SUBTITLE_MIN_SIZE_MB}M")
    fi
    if [[ "${SUBTITLE_MAX_SIZE_MB:-0}" -gt 0 ]]; then
        find_args+=("-size" "-${SUBTITLE_MAX_SIZE_MB}M")
    fi
    if [[ "${SUBTITLE_MODIFIED_DAYS:-0}" -gt 0 ]]; then
        find_args+=("-mtime" "-${SUBTITLE_MODIFIED_DAYS}")
    fi

    # 6. Collect video files
    local -a video_files
    mapfile -t video_files < <(find "${find_args[@]}" 2>/dev/null | sort)

    # 7. Apply SUBTITLE_MAX_FILES limit
    local max_files="${SUBTITLE_MAX_FILES:-0}"
    if [[ "$max_files" -gt 0 && ${#video_files[@]} -gt "$max_files" ]]; then
        video_files=("${video_files[@]:0:$max_files}")
    fi

    # 8. Nothing to do?
    local total=${#video_files[@]}
    if [[ $total -eq 0 ]]; then
        log_info "No video files found in: $directory"
        return 0
    fi

    # 9. Per-directory summary
    if [[ "${SUBTITLE_SHOW_DIR_STATS:-true}" == true ]]; then
        log_info "Found $total video file(s) in: $directory"
    fi

    # 10. Process each file
    local -a pids=()
    _SUBTITLE_INTERRUPTED=false
    _SUBTITLE_JOB_PIDS=()
    SUBTITLE_FAIL_LOG=$(mktemp 2>/dev/null) || SUBTITLE_FAIL_LOG=""
    trap _subtitle_on_interrupt INT TERM
    local file_idx=0
    local _eta_elapsed_sum=0
    local _eta_files_done=0
    for video_file in "${video_files[@]}"; do
        [[ "$_SUBTITLE_INTERRUPTED" == true ]] && break
        file_idx=$(( file_idx + 1 ))
        local output_dir
        output_dir="$(dirname "$video_file")"
        local subtitle_file="${video_file%.*}.${format}"

        # Skip a video that was already found to have no speech
        if [[ "${SUBTITLE_SKIP_EXISTING:-true}" == true && -f "$(_no_speech_marker "$video_file")" ]]; then
            log_verbose "Skipping (no speech last time; delete $(basename "$(_no_speech_marker "$video_file")") to retry): $(basename "$video_file")"
            STATS[files_skipped]=$(( STATS[files_skipped] + 1 ))
            continue
        fi

        # Skip when a valid subtitle already exists.
        # If the file is present but invalid (empty or no timestamps), it was
        # likely left behind by a previously interrupted whisper run — delete it
        # and fall through to reprocess.
        if [[ "${SUBTITLE_SKIP_EXISTING:-true}" == true ]]; then
            if _is_valid_subtitle "$subtitle_file"; then
                log_verbose "Skipping (exists): $(basename "$subtitle_file")"
                STATS[files_skipped]=$(( STATS[files_skipped] + 1 ))
                continue
            elif [[ -f "$subtitle_file" ]]; then
                log_warning "Incomplete subtitle removed, will reprocess: $(basename "$subtitle_file")"
                rm -f "$subtitle_file"
            fi
        fi

        # Dry run: log intent only
        if [[ "$dry_run" == true ]]; then
            log_info "[DRY RUN] Would generate: $(basename "$video_file")"
            STATS[files_previewed]=$(( ${STATS[files_previewed]:-0} + 1 ))
            continue
        fi

        # Parallel dispatch (only when interactive edit is off)
        if [[ "${SUBTITLE_PARALLEL_JOBS:-1}" -gt 1 && "${SUBTITLE_INTERACTIVE_EDIT:-false}" != true ]]; then
            # Wait for an available job slot
            while [[ ${#pids[@]} -ge "${SUBTITLE_PARALLEL_JOBS}" && "$_SUBTITLE_INTERRUPTED" != true ]]; do
                local new_pids=()
                for pid in "${pids[@]}"; do
                    if kill -0 "$pid" 2>/dev/null; then
                        new_pids+=("$pid")
                    fi
                done
                pids=("${new_pids[@]}")
                _SUBTITLE_JOB_PIDS=("${pids[@]}")
                [[ ${#pids[@]} -ge "${SUBTITLE_PARALLEL_JOBS}" ]] && sleep 0.2
            done
            [[ "$_SUBTITLE_INTERRUPTED" == true ]] && break
            # Count at dispatch time; STATS won't propagate from background subshell
            STATS[subtitles_generated]=$(( STATS[subtitles_generated] + 1 ))
            STATS[files_processed]=$(( STATS[files_processed] + 1 ))
            {
                _SUBTITLE_JOB_PIDS=()
                _generate_single_subtitle \
                    "$video_file" "$whisper_cmd" "$model" "$format" \
                    "$language" "$device" "$output_dir" "$file_idx" "$total"
            } &
            pids+=($!)
            _SUBTITLE_JOB_PIDS=("${pids[@]}")
        else
            # Sequential: track elapsed for ETA
            local _iter_start
            _iter_start=$(date +%s)
            _generate_single_subtitle \
                "$video_file" "$whisper_cmd" "$model" "$format" \
                "$language" "$device" "$output_dir" "$file_idx" "$total" \
                "$_eta_elapsed_sum" "$_eta_files_done"
            _eta_elapsed_sum=$(( _eta_elapsed_sum + $(date +%s) - _iter_start ))
            (( _eta_files_done++ ))
            [[ "$_SUBTITLE_INTERRUPTED" == true ]] && break
        fi
    done

    # 11. Wait for all background jobs
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    trap - INT TERM
    _SUBTITLE_JOB_PIDS=()

    # Failures are listed here because background jobs cannot update STATS
    local fail_count=0
    if [[ -n "${SUBTITLE_FAIL_LOG:-}" && -s "$SUBTITLE_FAIL_LOG" ]]; then
        fail_count=$(wc -l < "$SUBTITLE_FAIL_LOG" | tr -d ' ')
        echo -e "${COLOR_YELLOW}${fail_count} video(s) failed; no subtitle was written:${COLOR_RESET}" >&2
        local f_path f_reason
        while IFS=$'\t' read -r f_path f_reason; do
            echo "    - $(basename "$f_path") (${f_reason})" >&2
        done < "$SUBTITLE_FAIL_LOG"
    fi
    [[ -n "${SUBTITLE_FAIL_LOG:-}" ]] && rm -f "$SUBTITLE_FAIL_LOG"
    SUBTITLE_FAIL_LOG=""

    if [[ "$_SUBTITLE_INTERRUPTED" == true ]]; then
        log_warning "Interrupted; unfinished subtitle files were removed. Run again to continue: finished videos are skipped."
        _SUBTITLE_INTERRUPTED=false
        return 130
    fi

    # 12. Summary
    local no_speech_note="" nospeech_here=$(( ${STATS[subtitles_no_speech]:-0} - nospeech_before ))
    (( nospeech_here > 0 )) && no_speech_note=", ${nospeech_here} with no speech"
    log_info "Subtitle generation complete: $(( ${STATS[subtitles_generated]:-0} - gen_before )) generated, $(( ${STATS[files_skipped]:-0} - skip_before )) skipped${no_speech_note}"
    return 0
}

# Interactively collect directories from the user and run subtitle generation on each.
batch_generate_subtitles() {
    batch_subtitles_interactive
}

# Open a subtitle file in the user's preferred editor.
# Args: subtitle_file
edit_subtitle_interactive() {
    local subtitle_file="$1"

    if [[ -z "$subtitle_file" ]]; then
        log_error "No subtitle file specified"
        return 1
    fi
    if [[ ! -f "$subtitle_file" ]]; then
        log_error "Subtitle file not found: $subtitle_file"
        return 1
    fi

    local editor="${EDITOR:-nano}"
    log_info "Opening in $editor: $(basename "$subtitle_file")"
    "$editor" "$subtitle_file"
    log_success "Editing complete"
    return 0
}

################################################################################
# MODULE INITIALIZATION
################################################################################

# Return success to indicate module loaded
return 0
