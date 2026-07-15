#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - REDDIT MODULE
#
# Downloads images from a subreddit using the Reddit API.
#
# Reddit now blocks most unauthenticated requests to the public .json
# endpoints, so this module authenticates via OAuth2 "app-only" (client
# credentials) auth when credentials are available in ~/.vmgr-reddit.conf,
# and falls back to the unauthenticated endpoint otherwise.
#
# Dependencies: core.sh, logging.sh
# Module: reddit.sh
# Version: 2.0.0
#
################################################################################

REDDIT_CONFIG_FILE="$HOME/.vmgr-reddit.conf"
REDDIT_USER_AGENT="vmgr/2.0 (by /u/mosqua)"

# Seconds to wait between requests (image downloads and listing pages).
# Override by setting REDDIT_RATE_LIMIT_DELAY in ~/.vmgr-reddit.conf.
REDDIT_RATE_LIMIT_DELAY="${REDDIT_RATE_LIMIT_DELAY:-1}"

# Load Reddit API credentials from ~/.vmgr-reddit.conf, if present
# Sets REDDIT_CLIENT_ID / REDDIT_CLIENT_SECRET
# Returns: 0 if credentials were loaded, 1 otherwise
_reddit_load_credentials() {
    [[ -f "$REDDIT_CONFIG_FILE" ]] || return 1

    local file_owner
    file_owner=$(stat -c '%U' "$REDDIT_CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$REDDIT_CONFIG_FILE" 2>/dev/null)
    if [[ "$file_owner" != "$USER" ]]; then
        log_warning "Reddit config not owned by current user ($file_owner) — refusing to load: $REDDIT_CONFIG_FILE"
        return 1
    fi

    source "$REDDIT_CONFIG_FILE"
    [[ -n "$REDDIT_CLIENT_ID" && -n "$REDDIT_CLIENT_SECRET" ]]
}

# Obtain an OAuth2 app-only access token
# Sets REDDIT_ACCESS_TOKEN on success
# Returns: 0 on success, 1 on failure
_reddit_get_access_token() {
    _reddit_load_credentials || return 1

    local response
    response=$(curl -sf -A "$REDDIT_USER_AGENT" \
        -u "${REDDIT_CLIENT_ID}:${REDDIT_CLIENT_SECRET}" \
        -d "grant_type=client_credentials" \
        https://www.reddit.com/api/v1/access_token 2>/dev/null)
    [[ -z "$response" ]] && return 1

    REDDIT_ACCESS_TOKEN=$(echo "$response" | jq -r '.access_token // empty' 2>/dev/null)
    [[ -n "$REDDIT_ACCESS_TOKEN" ]]
}

# Fetch a subreddit listing page (JSON), authenticated if possible
# Args: $1 - subreddit, $2 - "after" cursor (may be empty)
# Prints the response body to stdout
_reddit_fetch_listing() {
    local subreddit="$1"
    local after="$2"
    local base_url query

    if [[ -n "$REDDIT_ACCESS_TOKEN" ]]; then
        base_url="https://oauth.reddit.com/r/${subreddit}/hot.json"
    else
        base_url="https://www.reddit.com/r/${subreddit}/hot.json"
    fi

    query="?limit=100&raw_json=1"
    [[ -n "$after" ]] && query+="&after=$after"

    if [[ -n "$REDDIT_ACCESS_TOKEN" ]]; then
        curl -sf -A "$REDDIT_USER_AGENT" -H "Authorization: bearer $REDDIT_ACCESS_TOKEN" "${base_url}${query}" 2>/dev/null
    else
        curl -sf -A "$REDDIT_USER_AGENT" "${base_url}${query}" 2>/dev/null
    fi
}

# Download images from a subreddit
# Args: $1 - subreddit name, $2 - output directory, $3 - max images (default 200)
download_subreddit_images() {
    local subreddit="$1"
    local output_dir="$2"
    local max_images="${3:-200}"

    if [[ -z "$subreddit" || -z "$output_dir" ]]; then
        log_error "Usage: download_subreddit_images <subreddit> <output_dir> [max]"
        return 1
    fi

    if ! command -v curl &>/dev/null; then
        log_error "curl is required but not installed"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq is required but not installed (sudo apt install jq)"
        return 1
    fi

    mkdir -p "$output_dir" || { log_error "Cannot create output directory: $output_dir"; return 1; }

    REDDIT_ACCESS_TOKEN=""
    if _reddit_get_access_token; then
        log_verbose "Authenticated with Reddit API"
    else
        log_warning "No valid Reddit API credentials — falling back to unauthenticated access (Reddit may block this)"
    fi

    log_info "Downloading up to $max_images images from r/$subreddit"
    log_info "Output: $output_dir"
    log_verbose "Rate limit delay: ${REDDIT_RATE_LIMIT_DELAY}s between requests"
    echo ""

    local downloaded=0
    local skipped=0
    local failed=0
    local after=""

    while [[ $downloaded -lt $max_images ]]; do
        local response
        response=$(_reddit_fetch_listing "$subreddit" "$after")
        if [[ -z "$response" ]]; then
            log_error "Failed to fetch r/$subreddit — check subreddit name, network, and Reddit API credentials"
            return 1
        fi

        # Extract image URLs from posts
        local urls
        mapfile -t urls < <(echo "$response" | jq -r '
            .data.children[].data |
            if .url? then
                select(.url | test("\\.(jpg|jpeg|png|gif|webp)$"; "i")) |
                .url
            else empty end
        ' 2>/dev/null)

        if [[ ${#urls[@]} -eq 0 ]]; then
            log_info "No more image posts found"
            break
        fi

        for img_url in "${urls[@]}"; do
            [[ $downloaded -ge $max_images ]] && break

            local filename
            filename=$(basename "$img_url" | sed 's/[?#].*//')
            local dest="$output_dir/$filename"

            if [[ -f "$dest" ]]; then
                ((skipped++))
                ((STATS[files_skipped]++))
                log_verbose "Skipped (exists): $filename"
                continue
            fi

            if curl -sf -A "$REDDIT_USER_AGENT" -o "$dest" "$img_url" 2>/dev/null; then
                ((downloaded++))
                ((STATS[files_moved]++))
                show_progress "$downloaded" "$max_images" "Downloading"
                log_verbose "Downloaded: $filename"
            else
                ((failed++))
                log_warning "Failed: $img_url"
                rm -f "$dest"
            fi

            sleep "$REDDIT_RATE_LIMIT_DELAY"
        done

        # Pagination
        after=$(echo "$response" | jq -r '.data.after // empty' 2>/dev/null)
        [[ -z "$after" ]] && break
        sleep "$REDDIT_RATE_LIMIT_DELAY"
    done

    echo ""
    log_success "Downloaded $downloaded images from r/$subreddit"
    [[ $skipped -gt 0 ]] && log_info "Skipped $skipped (already existed)"
    [[ $failed -gt 0 ]] && log_warning "$failed downloads failed"
}

return 0
