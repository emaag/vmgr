#!/usr/bin/env bash
#
# Video Manager Ultimate - Subtitle Generation Module
# Part of the modular video management system
#
# This module provides subtitle generation functionality using OpenAI Whisper.
#
# IMPLEMENTATION STATUS:
#   Implemented:  Whisper/GPU detection helpers (check_whisper_installation, detect_gpu)
#   Implemented:  generate_subtitles_in_directory, batch_generate_subtitles,
#                 edit_subtitle_interactive, fix_punctuation
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

# Check if a whisper backend is installed
check_whisper_installation() {
    [[ -n "$(get_whisper_command)" ]]
}

# Get whisper command. Prefers whisper-ctranslate2 (faster-whisper: ~4x faster
# on CPU, same flags as openai-whisper) unless SUBTITLE_BACKEND=whisper.
# SUBTITLE_BACKEND: auto (default) | faster | whisper
get_whisper_command() {
    local backend="${SUBTITLE_BACKEND:-auto}"
    if [[ "$backend" != "whisper" ]] && command -v whisper-ctranslate2 &> /dev/null; then
        echo "whisper-ctranslate2"
    elif [[ "$backend" != "faster" ]] && command -v whisper &> /dev/null; then
        echo "whisper"
    elif [[ "$backend" != "faster" ]] && command -v whisper.cpp &> /dev/null; then
        echo "whisper.cpp"
    else
        echo ""
    fi
}

################################################################################
# SUBTITLE PROCESSING AND EDITING
################################################################################

# Apply basic capitalization fixes to the cue text of an SRT/VTT file.
# Only text lines are touched: cue numbers, timestamp lines and the WEBVTT
# header pass through unchanged. Whisper already punctuates, so this mainly
# repairs a lowercase "i" and cues that start in lowercase after a full stop.
fix_punctuation() {
    local subtitle_file="$1" tmp
    [[ -f "$subtitle_file" ]] || { log_warning "Punctuation fix failed: file not found"; return 1; }

    log_verbose "Applying punctuation fixes to: $(basename "$subtitle_file")"
    tmp="$(mktemp)" || { log_warning "Punctuation fix failed"; return 1; }

    command -v perl &>/dev/null || { rm -f "$tmp"; log_warning "Punctuation fix needs perl"; return 1; }

    perl -pe '
        next if /^WEBVTT/ || /-->/ || /^\d+\s*$/ || /^\s*$/;
        s/(?<![\w\x27])i(?![\w\x27])/I/g;
        s/^([a-z])/\U$1/;
    ' "$subtitle_file" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]] || { rm -f "$tmp"; log_warning "Punctuation fix failed"; return 1; }

    cat "$tmp" > "$subtitle_file"
    rm -f "$tmp"
    log_verbose "Punctuation fixes applied"
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
# Returns 0 when real text remains, 1 when nothing but filler (or nothing) was found.
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
    # No cues at all (VAD removed everything) also means no speech
    (( kept > 0 ))
}

# Tidy SRT timing: stretch cues shorter than SUBTITLE_MIN_CUE_SEC (default 1.0)
# where the next cue leaves room, cut cues longer than SUBTITLE_MAX_CUE_SEC
# (default 10; a very short text over the cap is dropped as a hallucination
# unless SUBTITLE_DROP_RUNAWAY=false), and trim overlaps so cues never overlap.
# SRT only; other formats are left alone. Returns 0 (also when skipped).
_tidy_subtitle_timing() {
    local file="$1" format="$2" tmp
    [[ "$format" == "srt" && -f "$file" ]] || return 0
    command -v perl &>/dev/null || return 0
    tmp="$(mktemp)" || return 0
    SUBTITLE_MIN_CUE_MS=$(awk -v s="${SUBTITLE_MIN_CUE_SEC:-1.0}" 'BEGIN{printf "%d", s*1000}') \
    SUBTITLE_MAX_CUE_MS=$(awk -v s="${SUBTITLE_MAX_CUE_SEC:-10}" 'BEGIN{printf "%d", s*1000}') \
    SUBTITLE_DROP_RUNAWAY="${SUBTITLE_DROP_RUNAWAY:-true}" \
    perl -0777 -e '
        my $min = $ENV{SUBTITLE_MIN_CUE_MS} // 1000; my $max = $ENV{SUBTITLE_MAX_CUE_MS} // 10000; my $gap = 40;
        sub ms { my ($h,$m,$s,$f)=@_; (($h*60+$m)*60+$s)*1000+$f }
        sub ts { my $t=shift; sprintf("%02d:%02d:%02d,%03d", int($t/3600000), int($t/60000)%60, int($t/1000)%60, $t%1000) }
        my $in = <STDIN>; my @cues;
        for my $blk (split /\n{2,}/, $in) {
            my @l = split /\n/, $blk;
            my $i = 0; $i++ while $i < @l && $l[$i] !~ /-->/;
            if ($i >= @l) { push @cues, { raw => $blk }; next }
            $l[$i] =~ /(\d+):(\d+):(\d+),(\d+)\s*-->\s*(\d+):(\d+):(\d+),(\d+)(.*)/ or do { push @cues, { raw => $blk }; next };
            push @cues, { s => ms($1,$2,$3,$4), e => ms($5,$6,$7,$8), tail => $9, text => [@l[$i+1..$#l]] };
        }
        # A cue that outlasts the cap and holds almost no text ("Please", "Ha, ha, ha")
        # is a hallucination stretched over music or silence: drop it. Longer lines
        # are real speech with a bad end time, so they are cut to the cap below.
        if (($ENV{SUBTITLE_DROP_RUNAWAY} // "true") eq "true") {
            @cues = grep {
                my $c = $_;
                if (!exists $c->{s} || $c->{e} - $c->{s} <= $max) { 1 }
                else {
                    my @w = map { lc } (join(" ", @{$c->{text}}) =~ /[\w\x27]+/g);
                    my %d = map { $_ => 1 } @w;
                    !(@w <= 3 || keys(%d) <= 1);
                }
            } @cues;
        }
        my @t = grep { exists $_->{s} } @cues;
        for my $k (0..$#t) {
            my $c = $t[$k]; my $next = $k < $#t ? $t[$k+1]{s} : undef;
            # Whisper sometimes stretches a line over minutes of music or silence
            $c->{e} = $c->{s} + $max if $c->{e} - $c->{s} > $max;
            if ($c->{e} - $c->{s} < $min) {
                my $want = $c->{s} + $min;
                $want = $next - $gap if defined $next && $want > $next - $gap;
                $c->{e} = $want if $want > $c->{e};
            }
            if (defined $next && $c->{e} > $next - $gap) {
                my $trim = $next - $gap;
                $c->{e} = $trim if $trim > $c->{s};
            }
        }
        my $n = 0; my @out;
        for my $c (@cues) {
            if (!exists $c->{s}) { push @out, $c->{raw}; next }
            $n++;
            push @out, join("\n", $n, ts($c->{s}) . " --> " . ts($c->{e}) . $c->{tail}, @{$c->{text}});
        }
        print join("\n\n", @out), "\n\n";
    ' < "$file" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]] && cat "$tmp" > "$file"
    rm -f "$tmp"
    return 0
}

# Pick a model by video length for --model auto: shorter videos get a bigger model.
# Args: video_file. Prints the model name.
_auto_model_for() {
    local dur=0
    if command -v ffprobe &>/dev/null; then
        dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null | head -n1)"
        dur="${dur%%.*}"
    fi
    [[ "$dur" =~ ^[0-9]+$ ]] || dur=0
    if   (( dur > 0 && dur <= 600 ));  then echo "medium"
    elif (( dur > 0 && dur <= 2700 )); then echo "small"
    else                                    echo "base"
    fi
}

# Path a finished subtitle should end up at. With SUBTITLE_LANG_TAG=true and an
# explicit language, srt/vtt files get a language tag (video.en.srt) that players
# recognise. Args: video_file format language
_subtitle_final_path() {
    local base="${1%.*}" format="$2" language="$3"
    if [[ "${SUBTITLE_LANG_TAG:-false}" == true && "$language" != "auto" && ( "$format" == srt || "$format" == vtt ) ]]; then
        echo "${base}.${language}.${format}"
    else
        echo "${base}.${format}"
    fi
}

# Whisper prints a tqdm bar on stderr, e.g. " 3%|███| 51.4/1749.7 [01:21<44:47, 1.58s/seconds]".
# Read the newest frame from a log file. Prints "pct elapsed eta" (eta may be "?")
# and returns 1 when no frame has been written yet.
_whisper_progress_parse() {
    local frame
    frame="$(tail -c 2000 "$1" 2>/dev/null | tr '\r' '\n' | grep -E '[0-9]+%\|' | tail -n1)"
    [[ -n "$frame" ]] || return 1
    if [[ "$frame" =~ ([0-9]+)%\| ]]; then
        local pct="${BASH_REMATCH[1]}" elapsed="" eta="?"
        if [[ "$frame" =~ \[([0-9:]+)\<([0-9:?]+) ]]; then
            elapsed="${BASH_REMATCH[1]}"; eta="${BASH_REMATCH[2]}"
        fi
        echo "$pct ${elapsed:-?} $eta"
        return 0
    fi
    return 1
}

# Draw one live line for the file being transcribed (stderr, overwrites itself).
# Args: pct elapsed_text eta_text label
_subtitle_draw_progress() {
    local pct="$1" elapsed="$2" eta="$3" label="${4:-Transcribing}"
    local width=24 filled bar_on bar_off full="${UI_BAR_FULL:-█}" empty="${UI_BAR_EMPTY:-░}" i
    (( pct > 100 )) && pct=100
    filled=$(( pct * width / 100 ))
    bar_on=""; bar_off=""
    for ((i=0; i<filled; i++)); do bar_on+="$full"; done
    for ((i=filled; i<width; i++)); do bar_off+="$empty"; done
    printf '\r    %s%s%s%s%s%s %3d%%  %s%s  elapsed %s  ETA %s%s\033[K' \
        "${UI_ACCENT:-}" "$bar_on" "${COLOR_RESET:-}" "${UI_DIM:-}" "$bar_off" "${COLOR_RESET:-}" \
        "$pct" "${UI_DIM:-}" "$label" "$elapsed" "$eta" "${COLOR_RESET:-}" >&2
}

# Slow fallback for _detect_language: one whisper-ctranslate2 run per sample. Whisper alone looks only at the
# first 30 s, which is often music or silence and can pick a wrong language that
# then makes it invent text. Sample 30 s at 20%, 50% and 80% of the video with
# the tiny model, add up the probabilities per language, and use the winner.
# Prints a language name (accepted by whisper-ctranslate2) and returns 0, or
# prints the fallback language and returns 1 when confidence is too low or the
# tools are missing. Args: video_file whisper_cmd
_detect_language_cli() {
    local video="$1" cmd="$2" fallback="${SUBTITLE_FALLBACK_LANGUAGE:-en}"
    command -v ffmpeg &>/dev/null && command -v ffprobe &>/dev/null || { echo "$fallback"; return 1; }
    local dur
    dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$video" 2>/dev/null | head -n1)"
    dur="${dur%%.*}"
    [[ "$dur" =~ ^[0-9]+$ && $dur -gt 0 ]] || { echo "$fallback"; return 1; }

    local tmp frac pos out lang prob samples=0
    local -A score=()
    tmp="$(mktemp -d 2>/dev/null)" || { echo "$fallback"; return 1; }
    for frac in 20 50 80; do
        pos=$(( dur * frac / 100 ))
        (( dur < 40 )) && pos=0
        ffmpeg -nostdin -loglevel error -y -ss "$pos" -t 30 -i "$video" -vn -ac 1 -ar 16000 "$tmp/s.wav" 2>/dev/null || continue
        out="$(run_with_timeout 300 "$cmd" "$tmp/s.wav" --model tiny --output_format txt \
                --output_dir "$tmp" --verbose True 2>&1 </dev/null | grep -m1 -E "Detected language")"
        if [[ "$out" =~ Detected\ language\ \'([^\']+)\'\ with\ probability\ ([0-9.]+) ]]; then
            lang="${BASH_REMATCH[1]}"; prob="${BASH_REMATCH[2]}"
            score[$lang]="$(awk -v a="${score[$lang]:-0}" -v b="$prob" 'BEGIN{print a+b}')"
            samples=$(( samples + 1 ))
        fi
        (( dur < 40 )) && break
    done
    rm -rf "$tmp"

    local best="" best_score=0 l
    for l in "${!score[@]}"; do
        if awk -v a="${score[$l]}" -v b="$best_score" 'BEGIN{exit !(a>b)}'; then best="$l"; best_score="${score[$l]}"; fi
    done
    # Average probability of the winner across all samples must reach 0.2
    if [[ -n "$best" ]] && awk -v a="$best_score" -v n="$samples" 'BEGIN{exit !(n>0 && a/n>=0.2)}'; then
        echo "$best"; return 0
    fi
    echo "$fallback"; return 1
}

# Guess the spoken language for --language auto. Whisper alone looks only at the
# first 30 s, which is often music or silence and can pick a wrong language that
# then makes it invent text. Sample 30 s at 20%, 50% and 80% of the video, run
# the tiny model once over all three (model loaded a single time), add up the
# probabilities per language, and use the winner.
# Prints a language code and returns 0, or prints the fallback language and
# returns 1 when confidence is too low or the tools are missing.
# Falls back to _detect_language_cli when faster_whisper cannot be imported.
# Args: video_file whisper_cmd
_detect_language() {
    local video="$1" cmd="$2" fallback="${SUBTITLE_FALLBACK_LANGUAGE:-en}"
    command -v ffmpeg &>/dev/null && command -v ffprobe &>/dev/null || { echo "$fallback"; return 1; }
    python3 -c 'import faster_whisper' &>/dev/null || { _detect_language_cli "$@"; return $?; }

    local dur
    dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$video" 2>/dev/null | head -n1)"
    dur="${dur%%.*}"
    [[ "$dur" =~ ^[0-9]+$ && $dur -gt 0 ]] || { echo "$fallback"; return 1; }

    local tmp frac pos i=0
    local -a clips=()
    tmp="$(mktemp -d 2>/dev/null)" || { echo "$fallback"; return 1; }
    for frac in 20 50 80; do
        pos=$(( dur * frac / 100 ))
        (( dur < 40 )) && pos=0
        i=$(( i + 1 ))
        ffmpeg -nostdin -loglevel error -y -ss "$pos" -t 30 -i "$video" -vn -ac 1 -ar 16000 "$tmp/s$i.wav" 2>/dev/null \
            && clips+=("$tmp/s$i.wav")
        (( dur < 40 )) && break
    done

    local result=""
    if (( ${#clips[@]} > 0 )); then
        result="$(run_with_timeout 300 python3 -c '
import sys
from faster_whisper import WhisperModel
from faster_whisper.audio import decode_audio
m = WhisperModel("tiny", device="cpu", compute_type="int8")
score, n = {}, 0
for p in sys.argv[1:]:
    lang, prob, _ = m.detect_language(decode_audio(p, sampling_rate=16000))
    score[lang] = score.get(lang, 0.0) + prob
    n += 1
if n:
    best = max(score, key=score.get)
    print(best, score[best] / n)
' "${clips[@]}" 2>/dev/null </dev/null | tail -n1)"
    fi
    rm -rf "$tmp"

    # Average probability of the winner across all samples must reach 0.2
    local best="${result%% *}" avg="${result##* }"
    if [[ -n "$best" && "$best" != "$result" ]] && awk -v a="$avg" 'BEGIN{exit !(a>=0.2)}'; then
        echo "$best"; return 0
    fi
    echo "$fallback"; return 1
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

    [[ "$model" == "auto" ]] && model="$(_auto_model_for "$video_file")"

    # whisper-ctranslate2 has no plain "large"; openai-whisper treats it as large-v3
    if [[ "$whisper_cmd" == "whisper-ctranslate2" && "$model" == "large" ]]; then
        model="large-v3"
    fi

    # Auto language: guess from several samples (faster-whisper only; the guess is
    # used for transcription, but never for --lang-tag file names)
    local spoken="$language"
    if [[ "$language" == "auto" && "$whisper_cmd" == "whisper-ctranslate2" && "${SUBTITLE_DETECT_LANGUAGE:-true}" == true ]]; then
        if spoken="$(_detect_language "$video_file" "$whisper_cmd")"; then
            log_info "Detected language: $spoken"
        else
            log_warning "Could not detect the language with confidence; using ${spoken}. Set --language to override."
        fi
    fi

    # Build language args inside helper to avoid array-passing issues in subshells
    local -a lang_args=()
    if [[ "$spoken" != "auto" ]]; then
        lang_args=("--language" "$spoken")
    fi

    # CPU precision: openai-whisper needs --fp16 False; faster-whisper uses int8
    local -a fp16_args=()
    if [[ "$device" == "cpu" ]]; then
        if [[ "$whisper_cmd" == "whisper-ctranslate2" ]]; then
            fp16_args=("--compute_type" "int8" "--threads" "${SUBTITLE_THREADS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}")
        else
            fp16_args=("--fp16" "False")
        fi
    fi

    # Anti-hallucination and cue-shaping options (shared by both backends).
    # condition_on_previous_text False stops repeat loops; the thresholds reject
    # low-confidence segments over silence and music.
    local -a quality_args=(
        --condition_on_previous_text False
        --no_speech_threshold "${SUBTITLE_NO_SPEECH_THRESHOLD:-0.6}"
        --logprob_threshold "${SUBTITLE_LOGPROB_THRESHOLD:--1.0}"
        --compression_ratio_threshold "${SUBTITLE_COMPRESSION_THRESHOLD:-2.4}"
    )
    [[ -n "${SUBTITLE_INITIAL_PROMPT:-}" ]] && quality_args+=(--initial_prompt "$SUBTITLE_INITIAL_PROMPT")
    if [[ "${SUBTITLE_SPLIT_LINES:-true}" == true ]]; then
        quality_args+=(--word_timestamps True
                       --max_line_width "${SUBTITLE_MAX_LINE_WIDTH:-42}"
                       --max_line_count "${SUBTITLE_MAX_LINE_COUNT:-2}")
    fi
    [[ "$whisper_cmd" == "whisper-ctranslate2" && "${SUBTITLE_VAD_FILTER:-true}" == true ]] \
        && quality_args+=(--vad_filter True)
    [[ "${SUBTITLE_TRANSLATE:-false}" == true ]] && quality_args+=(--task translate)
    if [[ "$whisper_cmd" == "whisper-ctranslate2" && "${SUBTITLE_BATCHED:-false}" == true ]]; then
        quality_args+=(--batched True --batch_size "${SUBTITLE_BATCH_SIZE:-8}")
    fi
    if [[ "${SUBTITLE_SPEAKER_DIARIZATION:-false}" == true ]]; then
        local hf_token="${SUBTITLE_HF_TOKEN:-${HF_TOKEN:-}}"
        if [[ "$whisper_cmd" != "whisper-ctranslate2" ]]; then
            log_warning "Speaker labels need the faster-whisper backend (whisper-ctranslate2); skipping"
        elif [[ -z "$hf_token" ]]; then
            log_warning "Speaker labels need a Hugging Face token (SUBTITLE_HF_TOKEN or HF_TOKEN); skipping"
        elif ! python3 -c 'import pyannote.audio' &>/dev/null; then
            log_warning "Speaker labels need pyannote.audio (pip install pyannote.audio); skipping"
        else
            quality_args+=(--hf_token "$hf_token")
        fi
    fi

    # Decode once to 16 kHz mono WAV: whisper then skips its own ffmpeg pass over
    # the whole video, and the temp file is named so the output name is unchanged.
    local input_file="$video_file" audio_dir=""
    if [[ "${SUBTITLE_EXTRACT_AUDIO:-true}" == true ]] && command -v ffmpeg &>/dev/null; then
        audio_dir="$(mktemp -d 2>/dev/null)" || audio_dir=""
        if [[ -n "$audio_dir" ]]; then
            local wav="${audio_dir}/$(basename "${video_file%.*}").wav"
            if ffmpeg -nostdin -loglevel error -y -i "$video_file" -vn -ac 1 -ar 16000 "$wav" 2>/dev/null; then
                input_file="$wav"
            else
                log_verbose "Audio extraction failed; passing the video to whisper directly"
                rm -rf "$audio_dir"; audio_dir=""
            fi
        fi
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
    # stdout suppressed (raw transcription text). When one file runs at a time on a
    # terminal, stderr goes to a log and is shown as one live progress line;
    # otherwise it passes straight through.
    # Run in the background and wait, so Ctrl-C is handled straight away.
    local wlog="" live=false
    if [[ "${SUBTITLE_LIVE_PROGRESS:-true}" == true && "${SUBTITLE_PARALLEL_JOBS:-1}" -le 1 && -t 2 ]]; then
        wlog="$(mktemp 2>/dev/null)" && live=true || wlog=""
    fi
    trap _subtitle_on_interrupt INT TERM
    run_with_timeout "${SUBTITLE_TIMEOUT:-7200}" \
        "$whisper_cmd" "$input_file" \
        --model "$model" \
        --output_format "$format" \
        "${lang_args[@]}" \
        --output_dir "$output_dir" \
        --device "$device" \
        --verbose False \
        "${quality_args[@]}" \
        "${fp16_args[@]}" >/dev/null 2>"${wlog:-/dev/stderr}" &
    _SUBTITLE_WPID=$!
    local rc=0
    if [[ "$live" == true ]]; then
        local prog pct elapsed eta started
        started=$(date +%s)
        while kill -0 "$_SUBTITLE_WPID" 2>/dev/null && [[ "$_SUBTITLE_INTERRUPTED" != true ]]; do
            if prog="$(_whisper_progress_parse "$wlog")"; then
                read -r pct elapsed eta <<< "$prog"
                _subtitle_draw_progress "$pct" "$elapsed" "$eta"
            else
                local waited=$(( $(date +%s) - started ))
                _subtitle_draw_progress 0 "$(printf '%02d:%02d' $(( waited / 60 )) $(( waited % 60 )))" "?" "Loading model / detecting speech"
            fi
            sleep 1 & wait $!
        done
    fi
    wait "$_SUBTITLE_WPID" || rc=$?
    if [[ "$live" == true ]]; then
        printf '\r\033[K' >&2
        if [[ $rc -ne 0 && $rc -ne 124 && "$_SUBTITLE_INTERRUPTED" != true ]]; then
            # Show why it failed, without tqdm frames or the harmless GPU-probe noise
            tr '\r' '\n' < "$wlog" | grep -Ev '[0-9]+%\||onnxruntime|^[[:space:]]*$' | tail -n 15 >&2
        fi
        rm -f "$wlog"
    fi
    if [[ "$_SUBTITLE_INTERRUPTED" == true ]]; then
        kill -TERM "$_SUBTITLE_WPID" 2>/dev/null
        wait "$_SUBTITLE_WPID" 2>/dev/null
        _SUBTITLE_WPID=""
        [[ -n "$audio_dir" ]] && rm -rf "$audio_dir"
        rm -f "$expected_subtitle"
        return 130
    fi
    _SUBTITLE_WPID=""
    [[ -n "$audio_dir" ]] && rm -rf "$audio_dir"

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

    if [[ "${SUBTITLE_TIDY_TIMING:-true}" == true && -f "$subtitle_file" ]]; then
        _tidy_subtitle_timing "$subtitle_file" "$format"
    fi

    local final_file
    final_file="$(_subtitle_final_path "$video_file" "$format" "$language")"
    if [[ "$final_file" != "$subtitle_file" && -f "$subtitle_file" ]]; then
        mv -f "$subtitle_file" "$final_file" && subtitle_file="$final_file"
    fi

    if [[ "${SUBTITLE_INTERACTIVE_EDIT:-false}" == true && -f "$subtitle_file" && -t 0 ]]; then
        edit_subtitle_interactive "$subtitle_file"
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
# timestamp line (SRT hh:mm:ss,ms --> ...; VTT uses "." and may omit hours).
# Partial files written by a killed whisper process pass the -f/-s tests but
# fail the timestamp check. Formats without timestamps (txt, json) only need
# to be non-empty.
# Args: file [format]
_is_valid_subtitle() {
    local file="$1" format="${2:-srt}"
    [[ -f "$file" && -s "$file" ]] || return 1
    case "$format" in
        srt) grep -qE '[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3} --> ' "$file" 2>/dev/null ;;
        vtt) grep -qE '([0-9]{2}:)?[0-9]{2}:[0-9]{2}\.[0-9]{3} --> ' "$file" 2>/dev/null ;;
        *) return 0 ;;
    esac
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

    if [[ "$device" == "cpu" && "${SUBTITLE_PARALLEL_JOBS:-1}" -gt 1 ]]; then
        log_warning "Parallel jobs on CPU compete for cores and RAM; ${SUBTITLE_PARALLEL_JOBS} jobs is rarely faster than 1"
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
        local tagged_file
        tagged_file="$(_subtitle_final_path "$video_file" "$format" "$language")"

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
            if _is_valid_subtitle "$tagged_file" "$format" || _is_valid_subtitle "$subtitle_file" "$format"; then
                log_verbose "Skipping (exists): $(basename "$tagged_file")"
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
