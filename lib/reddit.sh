#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - REDDIT MODULE
#
# Downloads images from a public subreddit using the Reddit JSON API.
#
# Dependencies: core.sh, logging.sh
# Module: reddit.sh
# Version: 1.0.0
#
################################################################################

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

    log_info "Downloading up to $max_images images from r/$subreddit"
    log_info "Output: $output_dir"
    echo ""

    local downloaded=0
    local skipped=0
    local failed=0
    local after=""

    while [[ $downloaded -lt $max_images ]]; do
        local url="https://www.reddit.com/r/${subreddit}/hot.json?limit=100&raw_json=1"
        [[ -n "$after" ]] && url+="&after=$after"

        local response
        response=$(curl -sf -A "vmgr/1.0" "$url" 2>/dev/null)
        if [[ $? -ne 0 || -z "$response" ]]; then
            log_error "Failed to fetch r/$subreddit — check subreddit name and network"
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

            if curl -sf -A "vmgr/1.0" -o "$dest" "$img_url" 2>/dev/null; then
                ((downloaded++))
                ((STATS[files_moved]++))
                show_progress "$downloaded" "$max_images" "Downloading"
                log_verbose "Downloaded: $filename"
            else
                ((failed++))
                log_warning "Failed: $img_url"
                rm -f "$dest"
            fi
        done

        # Pagination
        after=$(echo "$response" | jq -r '.data.after // empty' 2>/dev/null)
        [[ -z "$after" ]] && break
    done

    echo ""
    log_success "Downloaded $downloaded images from r/$subreddit"
    [[ $skipped -gt 0 ]] && log_info "Skipped $skipped (already existed)"
    [[ $failed -gt 0 ]] && log_warning "$failed downloads failed"
}

return 0
