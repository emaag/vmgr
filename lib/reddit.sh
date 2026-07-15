#!/usr/bin/env bash
#
# Video Manager Ultimate - Reddit Image Downloader Module
#
# Downloads images from public subreddits using the Reddit OAuth2 API.
# Requires a free Reddit "script" app — register at reddit.com/prefs/apps.
#
# Credentials (pick one):
#   1. Env vars:  REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET
#   2. Creds file: ~/.vmgr-reddit.conf  (key=value, same var names)
#
# Dependencies: core.sh, logging.sh, utils.sh
# Requires: curl, jq
#

################################################################################
# OAUTH2 TOKEN MANAGEMENT
################################################################################

# Session-scoped token cache (cleared when shell exits)
_REDDIT_TOKEN=""
_REDDIT_TOKEN_EXPIRY=0

# Load credentials from ~/.vmgr-reddit.conf if not already in environment.
_reddit_load_creds() {
    local creds_file="$HOME/.vmgr-reddit.conf"

    if [[ -z "$REDDIT_CLIENT_ID" || -z "$REDDIT_CLIENT_SECRET" ]] && [[ -f "$creds_file" ]]; then
        local owner
        owner=$(stat -c '%U' "$creds_file" 2>/dev/null || stat -f '%Su' "$creds_file" 2>/dev/null)
        if [[ "$owner" != "$USER" ]]; then
            log_error "~/.vmgr-reddit.conf is not owned by $USER — refusing to load" >&2
            return 1
        fi
        # shellcheck source=/dev/null
        source "$creds_file"
    fi

    if [[ -z "$REDDIT_CLIENT_ID" || -z "$REDDIT_CLIENT_SECRET" ]]; then
        log_error "Reddit credentials not found." >&2
        log_error "Register a free 'script' app at https://www.reddit.com/prefs/apps then:" >&2
        log_error "  echo 'REDDIT_CLIENT_ID=your_id'      >> ~/.vmgr-reddit.conf" >&2
        log_error "  echo 'REDDIT_CLIENT_SECRET=your_sec' >> ~/.vmgr-reddit.conf" >&2
        log_error "  chmod 600 ~/.vmgr-reddit.conf" >&2
        return 1
    fi
}

# Fetch (or return cached) OAuth2 bearer token using application-only flow.
_reddit_get_token() {
    local now
    now=$(date +%s)

    # Return cached token if still valid (with 60s buffer)
    if [[ -n "$_REDDIT_TOKEN" && "$now" -lt "$(( _REDDIT_TOKEN_EXPIRY - 60 ))" ]]; then
        echo "$_REDDIT_TOKEN"
        return 0
    fi

    _reddit_load_creds || return 1

    local response
    response=$(curl -sf \
        --max-time 15 \
        -u "${REDDIT_CLIENT_ID}:${REDDIT_CLIENT_SECRET}" \
        -A "vmgr-image-downloader/1.0 (by /u/vmgr_user)" \
        -d "grant_type=client_credentials" \
        "https://www.reddit.com/api/v1/access_token")

    if [[ -z "$response" ]]; then
        log_error "Failed to reach Reddit OAuth endpoint" >&2
        return 1
    fi

    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err
        err=$(echo "$response" | jq -r '.error // "unknown"')
        log_error "Reddit OAuth error: ${err}" >&2
        return 1
    fi

    _REDDIT_TOKEN=$(echo "$response" | jq -r '.access_token')
    local expires_in
    expires_in=$(echo "$response" | jq -r '.expires_in // 3600')
    _REDDIT_TOKEN_EXPIRY=$(( now + expires_in ))

    echo "$_REDDIT_TOKEN"
}

################################################################################
# REDDIT IMAGE DOWNLOAD
################################################################################

# Fetch one page of posts from a subreddit and print the JSON response.
# Usage: _reddit_fetch_page <token> <subreddit> <limit> [after_token]
_reddit_fetch_page() {
    local token="$1"
    local subreddit="$2"
    local limit="$3"
    local after="${4:-}"

    local url="https://oauth.reddit.com/r/${subreddit}/hot?limit=${limit}&raw_json=1"
    [[ -n "$after" ]] && url="${url}&after=${after}"

    curl -sf \
        -H "Authorization: Bearer ${token}" \
        -A "vmgr-image-downloader/1.0 (by /u/vmgr_user)" \
        --max-time 15 \
        "$url"
}

# Extract direct image URLs from a Reddit JSON response (stdin).
# Prints one URL per line.
_reddit_extract_image_urls() {
    jq -r '
        .data.children[].data |
        select(
            (.url | test("\\.(jpg|jpeg|png|gif|webp|gifv)$"; "i")) or
            (.url | test("^https?://i\\.redd\\.it/"; "i")) or
            (.url | test("^https?://i\\.imgur\\.com/"; "i"))
        ) |
        .url |
        gsub("\\.gifv$"; ".gif")
    '
}

# Extract the pagination token from a Reddit JSON response (stdin).
_reddit_next_token() {
    jq -r '.data.after // empty'
}

# Download all images from a subreddit.
# Usage: download_subreddit_images <subreddit> <output_dir> [max_images]
download_subreddit_images() {
    local subreddit="$1"
    local output_dir="$2"
    local max_images="${3:-200}"

    # ── Validation ──────────────────────────────────────────────────────────
    if [[ -z "$subreddit" || -z "$output_dir" ]]; then
        log_error "Usage: download_subreddit_images <subreddit> <output_dir> [max_images]" >&2
        return 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required. Install with: sudo apt-get install curl" >&2
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required. Install with: sudo apt-get install jq" >&2
        return 1
    fi

    # Strip leading r/ if user typed it
    subreddit="${subreddit#r/}"
    subreddit="${subreddit#/r/}"

    # ── Auth ─────────────────────────────────────────────────────────────────
    local token
    token=$(_reddit_get_token) || return 1

    # ── Setup ────────────────────────────────────────────────────────────────
    mkdir -p "$output_dir" || {
        log_error "Cannot create output directory: $output_dir" >&2
        return 1
    }

    log_info "Downloading images from r/${subreddit} → ${output_dir}"
    log_info "Max images: ${max_images}"

    local after=""
    local downloaded=0
    local skipped=0
    local failed=0
    local page=1
    local per_page=100

    # ── Pagination loop ──────────────────────────────────────────────────────
    while true; do
        [[ "$downloaded" -ge "$max_images" ]] && break

        log_info "Fetching page ${page} (after=${after:-start})…" >&2

        local response
        response=$(_reddit_fetch_page "$token" "$subreddit" "$per_page" "$after")

        if [[ -z "$response" ]]; then
            log_error "Failed to fetch page ${page} — subreddit may be private or non-existent" >&2
            break
        fi

        # Check for Reddit error objects
        if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
            local err_msg
            err_msg=$(echo "$response" | jq -r '.message // "unknown error"')
            log_error "Reddit API error: ${err_msg}" >&2
            break
        fi

        local urls
        mapfile -t urls < <(echo "$response" | _reddit_extract_image_urls)

        if [[ "${#urls[@]}" -eq 0 ]]; then
            log_verbose "No image posts on page ${page} — continuing to next page" >&2
        fi

        # ── Download each image ──────────────────────────────────────────────
        for url in "${urls[@]}"; do
            [[ "$downloaded" -ge "$max_images" ]] && break

            local fname
            fname=$(basename "${url%%\?*}")
            local dest="${output_dir}/${fname}"

            if [[ -f "$dest" ]]; then
                log_verbose "Skipping (exists): ${fname}" >&2
                (( skipped++ )) || true
                continue
            fi

            if [[ "$DRY_RUN" == "true" ]]; then
                echo "[DRY RUN] Would download: ${url} → ${dest}"
                (( downloaded++ )) || true
                continue
            fi

            if curl -sf -L \
                    -A "vmgr-image-downloader/1.0 (by /u/vmgr_user)" \
                    --max-time 30 \
                    -o "$dest" \
                    "$url" 2>/dev/null; then
                log_success "Downloaded: ${fname}" >&2
                (( downloaded++ )) || true
            else
                log_warning "Failed:     ${url}" >&2
                rm -f "$dest"
                (( failed++ )) || true
            fi
        done

        # ── Advance pagination ───────────────────────────────────────────────
        local next
        next=$(echo "$response" | _reddit_next_token)

        if [[ -z "$next" ]]; then
            log_info "Reached end of subreddit listing." >&2
            break
        fi

        after="$next"
        (( page++ )) || true

        # Brief pause to be polite to the API
        sleep 1
    done

    # ── Summary ──────────────────────────────────────────────────────────────
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_WHITE}Download complete for r/${subreddit}${COLOR_RESET}"
    echo -e "  ${COLOR_BRIGHT_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Downloaded : ${COLOR_WHITE}${downloaded}${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Skipped    : ${COLOR_WHITE}${skipped}${COLOR_RESET} (already existed)"
    [[ "$failed" -gt 0 ]] && \
    echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} Failed     : ${COLOR_WHITE}${failed}${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}${SYMBOL_BULLET}${COLOR_RESET} Saved to   : ${COLOR_WHITE}${output_dir}${COLOR_RESET}"
    echo ""

    STATS[files_processed]=$(( ${STATS[files_processed]:-0} + downloaded ))
    return 0
}

################################################################################
# MODULE INITIALIZATION
################################################################################

return 0
