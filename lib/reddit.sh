#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - REDDIT MODULE
#
# Downloads images and videos from a subreddit using the Reddit API.
#
# Reddit now blocks most unauthenticated requests to the public .json
# endpoints, so this module authenticates via OAuth2 "app-only" (client
# credentials) auth when credentials are available in ~/.vmgr-reddit.conf,
# and falls back to the unauthenticated endpoint otherwise.
#
# Handles direct image links, direct video links (mp4/webm), Imgur .gifv
# (rewritten to its .mp4 counterpart), and Reddit-hosted video (v.redd.it),
# which ships video and audio as separate DASH streams that get muxed
# together with ffmpeg when it's available.
#
# Dependencies: core.sh, logging.sh
# Module: reddit.sh
# Version: 3.0.0
#
################################################################################

REDDIT_CONFIG_FILE="$HOME/.vmgr-reddit.conf"
REDDIT_USER_AGENT="vmgr/3.0 (by /u/mosqua)"

# Seconds to wait between requests (downloads and listing pages).
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
# Args: $1 - subreddit, $2 - "after" cursor (may be empty), $3 - sort
#       (hot/new/top/rising/controversial, default hot), $4 - time window
#       for top/controversial (hour/day/week/month/year/all, may be empty)
# Prints the response body to stdout
_reddit_fetch_listing() {
    local subreddit="$1"
    local after="$2"
    local sort="${3:-hot}"
    local time_window="$4"
    local base_url query

    if [[ -n "$REDDIT_ACCESS_TOKEN" ]]; then
        base_url="https://oauth.reddit.com/r/${subreddit}/${sort}.json"
    else
        base_url="https://www.reddit.com/r/${subreddit}/${sort}.json"
    fi

    query="?limit=100&raw_json=1"
    [[ -n "$after" ]] && query+="&after=$after"
    if [[ -n "$time_window" && ( "$sort" == "top" || "$sort" == "controversial" ) ]]; then
        query+="&t=$time_window"
    fi

    if [[ -n "$REDDIT_ACCESS_TOKEN" ]]; then
        curl -sf -A "$REDDIT_USER_AGENT" -H "Authorization: bearer $REDDIT_ACCESS_TOKEN" "${base_url}${query}" 2>/dev/null
    else
        curl -sf -A "$REDDIT_USER_AGENT" "${base_url}${query}" 2>/dev/null
    fi
}

# Extract downloadable media items from a listing response as NDJSON.
# Each line: {"kind": "...", "id": "...", "url": "..."}
# kind is one of: image, video, gifv, reddit_video
_reddit_extract_media() {
    jq -c '
        .data.children[].data |
        . as $p |
        ($p.media.reddit_video.fallback_url // $p.secure_media.reddit_video.fallback_url // null) as $rv |
        if ($p.is_video == true) and ($rv != null and $rv != "") then
            {kind: "reddit_video", id: $p.id, url: ($rv | sub("\\?.*$"; ""))}
        elif ($p.url? // "" | test("\\.gifv$"; "i")) then
            {kind: "gifv", id: $p.id, url: ($p.url | sub("\\.gifv$"; ".mp4"; "i"))}
        elif ($p.url? // "" | test("\\.(mp4|webm)$"; "i")) then
            {kind: "video", id: $p.id, url: $p.url}
        elif ($p.url? // "" | test("\\.(jpg|jpeg|png|gif|webp)$"; "i")) then
            {kind: "image", id: $p.id, url: $p.url}
        else empty end
    ' 2>/dev/null
}

# Download a single media item described by a JSON line from _reddit_extract_media
# Args: $1 - JSON item, $2 - output directory
# Returns: 0 on success, 1 on failure, 2 if skipped (already exists)
_reddit_download_item() {
    local item="$1"
    local output_dir="$2"

    local kind id url
    kind=$(jq -r '.kind' <<< "$item")
    id=$(jq -r '.id' <<< "$item")
    url=$(jq -r '.url' <<< "$item")

    local filename dest
    if [[ "$kind" == "reddit_video" ]]; then
        filename="${id}.mp4"
    else
        filename=$(basename "$url" | sed 's/[?#].*//')
    fi
    # Normalize .jpeg to .jpg for consistency with the rest of the library
    filename=$(sed -E 's/\.jpeg$/.jpg/I' <<< "$filename")
    dest="$output_dir/$filename"

    if [[ -f "$dest" ]]; then
        log_verbose "Skipped (exists): $filename"
        return 2
    fi

    if [[ "$kind" == "reddit_video" ]]; then
        _reddit_download_reddit_video "$url" "$dest"
    else
        curl -sf -A "$REDDIT_USER_AGENT" -o "$dest" "$url" 2>/dev/null
    fi

    if [[ $? -eq 0 && -s "$dest" ]]; then
        log_verbose "Downloaded: $filename"
        return 0
    else
        log_warning "Failed: $url"
        rm -f "$dest"
        return 1
    fi
}

# Look up the audio track filename for a v.redd.it video from its DASH
# manifest. Reddit has used different naming schemes over time (DASH_audio.mp4,
# CMAF_AUDIO_*.mp4), and posts with no audio track have no <AdaptationSet
# contentType="audio"> at all, so the manifest is the only reliable source.
# Args: $1 - video base directory URL (e.g. https://v.redd.it/<id>)
# Prints the audio filename (e.g. CMAF_AUDIO_128.mp4) if found, nothing otherwise
_reddit_find_audio_filename() {
    local video_dir="$1"
    local mpd
    mpd=$(curl -sf -A "$REDDIT_USER_AGENT" "${video_dir}/DASHPlaylist.mpd" 2>/dev/null) || return 1

    echo "$mpd" | awk '/contentType="audio"/{p=1} p{print} /<\/AdaptationSet>/{if(p) exit}' | \
        grep -oP '(?<=<BaseURL>)[^<]+' | tail -1
}

# Download and mux a Reddit-hosted video (separate video/audio DASH streams)
# Args: $1 - video (fallback) URL, $2 - destination path
# Returns: 0 on success, 1 on failure
_reddit_download_reddit_video() {
    local video_url="$1"
    local dest="$2"
    local video_dir="${video_url%/*}"
    local audio_filename
    audio_filename=$(_reddit_find_audio_filename "$video_dir")
    local audio_url="${video_dir}/${audio_filename}"

    local tmp_video="${dest}.video.tmp"
    curl -sf -A "$REDDIT_USER_AGENT" -o "$tmp_video" "$video_url" 2>/dev/null
    if [[ $? -ne 0 || ! -s "$tmp_video" ]]; then
        rm -f "$tmp_video"
        return 1
    fi

    if [[ -z "$audio_filename" ]]; then
        # No audio AdaptationSet in the manifest — silent video/gif
        mv "$tmp_video" "$dest"
        return $?
    fi

    if ! command -v ffmpeg &>/dev/null; then
        [[ "$REDDIT_WARNED_NO_FFMPEG" != true ]] && \
            log_warning "ffmpeg not installed — saving Reddit videos without audio (sudo apt install ffmpeg)"
        REDDIT_WARNED_NO_FFMPEG=true
        mv "$tmp_video" "$dest"
        return $?
    fi

    local tmp_audio="${dest}.audio.tmp"
    if curl -sf -A "$REDDIT_USER_AGENT" -o "$tmp_audio" "$audio_url" 2>/dev/null && [[ -s "$tmp_audio" ]]; then
        if ffmpeg -y -loglevel error -i "$tmp_video" -i "$tmp_audio" -c copy "$dest" </dev/null 2>/dev/null; then
            rm -f "$tmp_video" "$tmp_audio"
            return 0
        fi
        # Mux failed (e.g. mismatched codecs) — fall back to video-only
        rm -f "$tmp_audio" "$dest"
    fi

    # No audio track (silent video/gif) — keep the video stream as-is
    rm -f "$tmp_audio"
    mv "$tmp_video" "$dest"
}

# Download images and videos from a subreddit
# Args: $1 - subreddit name, $2 - output directory, $3 - max items (default 200),
#       $4 - sort (hot/new/top/rising/controversial, default hot),
#       $5 - time window for top/controversial (hour/day/week/month/year/all)
download_subreddit_images() {
    local subreddit="$1"
    local output_dir="$2"
    local max_images="${3:-200}"
    local sort="${4:-hot}"
    local time_window="$5"

    if [[ -z "$subreddit" || -z "$output_dir" ]]; then
        log_error "Usage: download_subreddit_images <subreddit> <output_dir> [max] [sort] [time]"
        return 1
    fi

    # Normalize common ways of specifying a subreddit ("r/foo", "/r/foo/",
    # a pasted reddit.com URL) into the bare name the Reddit API expects.
    subreddit=$(sed -E 's#^https?://(www\.)?reddit\.com/##; s#^/+##; s#^[Rr]/##; s#/.*##' <<< "$subreddit")
    if [[ -z "$subreddit" ]]; then
        log_error "Invalid subreddit name"
        return 1
    fi

    if [[ ! "$sort" =~ ^(hot|new|top|rising|controversial)$ ]]; then
        log_error "Invalid sort: $sort (must be hot, new, top, rising, controversial)"
        return 1
    fi

    if [[ -n "$time_window" ]]; then
        if [[ ! "$time_window" =~ ^(hour|day|week|month|year|all)$ ]]; then
            log_error "Invalid time window: $time_window (must be hour, day, week, month, year, all)"
            return 1
        fi
        if [[ "$sort" != "top" && "$sort" != "controversial" ]]; then
            log_warning "Time window ($time_window) ignored — only applies to top/controversial sort"
        fi
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
    REDDIT_WARNED_NO_FFMPEG=false
    if _reddit_get_access_token; then
        log_verbose "Authenticated with Reddit API"
    else
        log_warning "No valid Reddit API credentials — falling back to unauthenticated access (Reddit may block this)"
    fi

    if ! command -v ffmpeg &>/dev/null; then
        log_warning "ffmpeg not found — Reddit-hosted videos will be saved without audio"
    fi

    log_info "Downloading up to $max_images items from r/$subreddit (sort: $sort${time_window:+, t=$time_window})"
    log_info "Output: $output_dir"
    log_verbose "Rate limit delay: ${REDDIT_RATE_LIMIT_DELAY}s between requests"
    echo ""

    local downloaded=0
    local skipped=0
    local failed=0
    local after=""

    while [[ $downloaded -lt $max_images ]]; do
        local response
        response=$(_reddit_fetch_listing "$subreddit" "$after" "$sort" "$time_window")
        if [[ -z "$response" ]]; then
            log_error "Failed to fetch r/$subreddit — check subreddit name, network, and Reddit API credentials"
            return 1
        fi

        local items
        mapfile -t items < <(echo "$response" | _reddit_extract_media)

        if [[ ${#items[@]} -eq 0 ]]; then
            log_info "No more image/video posts found"
            break
        fi

        for item in "${items[@]}"; do
            [[ $downloaded -ge $max_images ]] && break

            _reddit_download_item "$item" "$output_dir"
            case $? in
                0)
                    ((downloaded++))
                    ((STATS[files_moved]++))
                    show_progress "$downloaded" "$max_images" "Downloading"
                    ;;
                2)
                    ((skipped++))
                    ((STATS[files_skipped]++))
                    ;;
                *)
                    ((failed++))
                    ;;
            esac

            sleep "$REDDIT_RATE_LIMIT_DELAY"
        done

        # Pagination
        after=$(echo "$response" | jq -r '.data.after // empty' 2>/dev/null)
        [[ -z "$after" ]] && break
        sleep "$REDDIT_RATE_LIMIT_DELAY"
    done

    echo ""
    log_success "Downloaded $downloaded items from r/$subreddit"
    [[ $skipped -gt 0 ]] && log_info "Skipped $skipped (already existed)"
    [[ $failed -gt 0 ]] && log_warning "$failed downloads failed"
}

return 0
