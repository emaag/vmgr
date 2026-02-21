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

# Internal helper: run whisper on a single file and update stats.
# Args: video_file whisper_cmd model format language device output_dir
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

    # Build language args inside helper to avoid array-passing issues in subshells
    local -a lang_args=()
    if [[ "$language" != "auto" ]]; then
        lang_args=("--language" "$language")
    fi

    "$whisper_cmd" "$video_file" \
        --model "$model" \
        --output_format "$format" \
        "${lang_args[@]}" \
        --output_dir "$output_dir" \
        --device "$device" >/dev/null 2>&1
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        log_warning "Whisper failed for: $(basename "$video_file")"
        STATS[subtitles_failed]=$(( STATS[subtitles_failed] + 1 ))
        return 1
    fi

    local subtitle_file="${video_file%.*}.${format}"
    if [[ ! -f "$subtitle_file" ]]; then
        log_warning "Expected subtitle not found (whisper.cpp naming?): $(basename "$subtitle_file")"
    fi

    if [[ "${SUBTITLE_AUTO_PUNCTUATION:-false}" == true && -f "$subtitle_file" ]]; then
        fix_punctuation "$subtitle_file"
    fi

    STATS[subtitles_generated]=$(( STATS[subtitles_generated] + 1 ))
    STATS[files_processed]=$(( STATS[files_processed] + 1 ))
    log_success "Generated: $(basename "$subtitle_file")"
    return 0
}

# Generate subtitles for all videos in a directory using OpenAI Whisper.
# Args: directory [model] [format] [language] [dry_run]
generate_subtitles_in_directory() {
    local directory="$1"
    local model="${2:-base}"
    local format="${3:-srt}"
    local language="${4:-auto}"
    local dry_run="${5:-false}"

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
    find_args+=("-type" "f")

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
    for video_file in "${video_files[@]}"; do
        local output_dir
        output_dir="$(dirname "$video_file")"
        local subtitle_file="${video_file%.*}.${format}"

        # Skip when subtitle already exists
        if [[ "${SUBTITLE_SKIP_EXISTING:-true}" == true && -f "$subtitle_file" ]]; then
            log_verbose "Skipping (exists): $(basename "$subtitle_file")"
            STATS[files_skipped]=$(( STATS[files_skipped] + 1 ))
            continue
        fi

        # Dry run: log intent only
        if [[ "$dry_run" == true ]]; then
            log_info "[DRY RUN] Would generate: $(basename "$video_file")"
            continue
        fi

        # Parallel dispatch (only when interactive edit is off)
        if [[ "${SUBTITLE_PARALLEL_JOBS:-1}" -gt 1 && "${SUBTITLE_INTERACTIVE_EDIT:-false}" != true ]]; then
            # Wait for an available job slot
            while [[ ${#pids[@]} -ge "${SUBTITLE_PARALLEL_JOBS}" ]]; do
                local new_pids=()
                for pid in "${pids[@]}"; do
                    if kill -0 "$pid" 2>/dev/null; then
                        new_pids+=("$pid")
                    fi
                done
                pids=("${new_pids[@]}")
                [[ ${#pids[@]} -ge "${SUBTITLE_PARALLEL_JOBS}" ]] && sleep 0.2
            done
            # Count at dispatch time; STATS won't propagate from background subshell
            STATS[subtitles_generated]=$(( STATS[subtitles_generated] + 1 ))
            STATS[files_processed]=$(( STATS[files_processed] + 1 ))
            {
                _generate_single_subtitle \
                    "$video_file" "$whisper_cmd" "$model" "$format" \
                    "$language" "$device" "$output_dir"
            } &
            pids+=($!)
        else
            # Sequential: _generate_single_subtitle updates STATS inline
            _generate_single_subtitle \
                "$video_file" "$whisper_cmd" "$model" "$format" \
                "$language" "$device" "$output_dir"
        fi
    done

    # 11. Wait for all background jobs
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done

    # 12. Summary
    log_info "Subtitle generation complete: ${STATS[subtitles_generated]} generated, ${STATS[files_skipped]} skipped"
    return 0
}

# Interactively collect directories from the user and run subtitle generation on each.
batch_generate_subtitles() {
    echo -e "${COLOR_BRIGHT_CYAN}Batch Subtitle Generation${COLOR_RESET}"
    echo "Enter directories to process (one per line, empty line to start):"

    local -a dirs=()
    local dir
    while true; do
        echo -n "Directory: "
        read -r dir
        [[ -z "$dir" ]] && break
        if [[ -d "$dir" ]]; then
            dirs+=("$dir")
        else
            log_warning "Not found, skipping: $dir"
        fi
    done

    if [[ ${#dirs[@]} -eq 0 ]]; then
        log_warning "No directories specified"
        return 0
    fi

    local total_dirs=${#dirs[@]}
    log_info "Processing $total_dirs director(ies)..."

    local i=0
    for dir in "${dirs[@]}"; do
        i=$(( i + 1 ))
        log_info "[$i/$total_dirs] Processing: $dir"
        generate_subtitles_in_directory "$dir" \
            "$WHISPER_MODEL" "$SUBTITLE_FORMAT" "$SUBTITLE_LANGUAGE" "$DRY_RUN"
    done

    log_success "Batch complete: $total_dirs director(ies) processed"
    return 0
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
