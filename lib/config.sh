#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - CONFIGURATION MODULE
#
# This module handles configuration management (save, load, profiles)
#
# Dependencies: core.sh, logging.sh
# Module: config.sh
# Version: 1.2.0
# Date: November 8, 2025
#
################################################################################

# Save current configuration to profile
# Args: $1 - profile name (default: "default")
# Returns: 0 on success
save_config() {
    local profile="${1:-default}"
    local config_file="${CONFIG_FILE%.conf}-${profile}.conf"

    log_verbose "Saving configuration to $config_file"

    cat > "$config_file" << EOF
# Video Manager Ultimate Configuration
# Profile: $profile
# Generated: $(date)

# General Settings
DRY_RUN=$DRY_RUN
VERBOSE=$VERBOSE
INTERACTIVE=$INTERACTIVE

# Granular Controls
INTERACTIVE_CONFIRM=$INTERACTIVE_CONFIRM
SHOW_PREVIEW=$SHOW_PREVIEW
STEP_BY_STEP=$STEP_BY_STEP
SELECTIVE_MODE=$SELECTIVE_MODE
AUTO_SKIP_ERRORS=$AUTO_SKIP_ERRORS
CONFIRM_DESTRUCTIVE=$CONFIRM_DESTRUCTIVE

# Filters
FILTER_BY_SIZE=$FILTER_BY_SIZE
FILTER_MIN_SIZE_MB=$FILTER_MIN_SIZE_MB
FILTER_MAX_SIZE_MB=$FILTER_MAX_SIZE_MB
FILTER_BY_DATE=$FILTER_BY_DATE
FILTER_DAYS_OLD=$FILTER_DAYS_OLD
FILTER_BY_PATTERN=$FILTER_BY_PATTERN
FILTER_PATTERN="$FILTER_PATTERN"

# Processing
MAX_FILES_PER_OPERATION=$MAX_FILES_PER_OPERATION
BATCH_SIZE=$BATCH_SIZE
PAUSE_BETWEEN_BATCHES=$PAUSE_BETWEEN_BATCHES
ENABLE_UNDO=$ENABLE_UNDO

# Catalog
CATALOG_ENABLED=$CATALOG_ENABLED
CATALOG_VIDEOS=$CATALOG_VIDEOS
CATALOG_IMAGES=$CATALOG_IMAGES
CATALOG_AUDIO=$CATALOG_AUDIO
CATALOG_INCLUDE_METADATA=$CATALOG_INCLUDE_METADATA
CATALOG_INCLUDE_HASH=$CATALOG_INCLUDE_HASH

# Subtitle
WHISPER_MODEL="$WHISPER_MODEL"
SUBTITLE_FORMAT="$SUBTITLE_FORMAT"
SUBTITLE_LANGUAGE="$SUBTITLE_LANGUAGE"
SUBTITLE_PARALLEL_JOBS=$SUBTITLE_PARALLEL_JOBS
SUBTITLE_USE_GPU=$SUBTITLE_USE_GPU
SUBTITLE_OPTIMIZE_BATCH=$SUBTITLE_OPTIMIZE_BATCH
EOF

    log_success "Configuration saved: $profile"
}

# Load configuration from profile
# Args: $1 - profile name (default: "default")
# Returns: 0 on success, 1 if profile not found
load_config() {
    local profile="${1:-default}"
    local config_file="${CONFIG_FILE%.conf}-${profile}.conf"

    if [[ ! -f "$config_file" ]]; then
        log_warning "Configuration file not found: $config_file"
        return 1
    fi

    log_verbose "Loading configuration from $config_file"

    # Source the configuration file
    source "$config_file"

    log_success "Configuration loaded: $profile"
}

# List available configuration profiles
# Displays all saved configuration profiles with modification dates
list_config_profiles() {
    local config_dir=$(dirname "$CONFIG_FILE")
    local base_name=$(basename "${CONFIG_FILE%.conf}")

    echo -e "${COLOR_BOLD}${COLOR_YELLOW}Available Configuration Profiles:${COLOR_RESET}"
    echo ""

    local count=0
    for config in "$config_dir"/${base_name}-*.conf; do
        if [[ -f "$config" ]]; then
            ((count++))
            local profile=$(basename "$config")
            profile=${profile#${base_name}-}
            profile=${profile%.conf}

            local mod_date=$(date -r "$config" "+%Y-%m-%d %H:%M" 2>/dev/null || stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$config" 2>/dev/null)

            echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} ${COLOR_WHITE}$profile${COLOR_RESET}"
            echo -e "    ${COLOR_CYAN}Modified:${COLOR_RESET} $mod_date"
            echo -e "    ${COLOR_CYAN}File:${COLOR_RESET}     $config"
            echo ""
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "  ${COLOR_YELLOW}No saved profiles found${COLOR_RESET}"
        echo ""
    fi
}

# Delete configuration profile
# Args: $1 - profile name
# Returns: 0 on success, 1 if profile not found
delete_config_profile() {
    local profile="$1"
    local config_file="${CONFIG_FILE%.conf}-${profile}.conf"

    if [[ ! -f "$config_file" ]]; then
        log_error "Profile not found: $profile"
        return 1
    fi

    rm -f "$config_file"
    log_success "Profile deleted: $profile"
}

# Module loaded successfully
return 0
