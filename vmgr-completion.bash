#!/bin/bash
# Bash completion for Video Manager Ultimate
# Source this file or copy to /etc/bash_completion.d/

_vmgr_completion() {
    local cur prev opts base
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Main commands
    local commands="rename flatten cleanup duplicates subtitles workflow-new workflow-clean batch"

    # Options
    local options="
        --help -h
        --version -v
        --dry-run -d
        --quiet -q
        --interactive -i
        --model
        --format
        --language
        --gpu
        --parallel
        --no-optimize
        --edit
        --speaker-diarization
        --no-punctuation
    "

    # Whisper models
    local models="tiny base small medium large"

    # Subtitle formats
    local formats="srt vtt txt json"

    # Language codes (common ones)
    local languages="auto en es fr de it pt ru ja zh ko ar"

    case "${prev}" in
        --model)
            COMPREPLY=( $(compgen -W "${models}" -- ${cur}) )
            return 0
            ;;
        --format)
            COMPREPLY=( $(compgen -W "${formats}" -- ${cur}) )
            return 0
            ;;
        --language)
            COMPREPLY=( $(compgen -W "${languages}" -- ${cur}) )
            return 0
            ;;
        --parallel)
            COMPREPLY=( $(compgen -W "1 2 3 4 5 6 7 8" -- ${cur}) )
            return 0
            ;;
        vmgr|video-manager-ultimate.sh)
            # First argument - offer commands and options
            COMPREPLY=( $(compgen -W "${commands} ${options}" -- ${cur}) )
            return 0
            ;;
        rename|flatten|cleanup|duplicates|subtitles|workflow-new|workflow-clean)
            # After a command, offer directory completion
            COMPREPLY=( $(compgen -d -- ${cur}) )
            return 0
            ;;
    esac

    # If current word starts with -, complete options
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${options}" -- ${cur}) )
        return 0
    fi

    # Check if we already have a command
    local has_command=0
    for word in "${COMP_WORDS[@]}"; do
        if [[ " ${commands} " =~ " ${word} " ]]; then
            has_command=1
            break
        fi
    done

    if [[ ${has_command} -eq 1 ]]; then
        # We have a command, complete with directories
        COMPREPLY=( $(compgen -d -- ${cur}) )
    else
        # No command yet, offer commands and options
        COMPREPLY=( $(compgen -W "${commands} ${options}" -- ${cur}) )
    fi

    return 0
}

# Register completion
complete -F _vmgr_completion vmgr
complete -F _vmgr_completion video-manager-ultimate.sh
complete -F _vmgr_completion ./video-manager-ultimate.sh
