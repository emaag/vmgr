#!/bin/bash

################################################################################
#
# VIDEO MANAGER ULTIMATE - REDDIT MODULE
#
# Downloads images and videos from a subreddit using the Reddit API.
#
# Reddit blocks unauthenticated requests to the public .json endpoints (HTTP
# 403), so this module authenticates via OAuth2 "app-only" (client
# credentials) auth when credentials are available in ~/.vmgr-reddit.conf.
# Without credentials it falls back to the public RSS feed, which still works
# but is heavily rate limited (roughly one request per minute); HTTP 429
# responses are waited out using the Retry-After / X-Ratelimit-Reset headers.
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

# How many times to wait out an HTTP 429 per request, and the longest single
# wait (seconds). Set in ~/.vmgr-reddit.conf to override.
REDDIT_MAX_RETRIES="${REDDIT_MAX_RETRIES:-3}"
REDDIT_MAX_WAIT="${REDDIT_MAX_WAIT:-120}"

# Set by _reddit_request / _reddit_fetch_listing (not usable from subshells)
REDDIT_RESPONSE=""
REDDIT_HTTP_STATUS=""

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

# Work out how long to wait after a 429 from the response headers file $1.
# Prints whole seconds, clamped to [5, REDDIT_MAX_WAIT]; 30 if no usable header.
_reddit_retry_wait() {
    local hdr_file="$1" secs
    secs=$(grep -iE '^(retry-after|x-ratelimit-reset):' "$hdr_file" 2>/dev/null | head -1 | cut -d: -f2 | tr -dc '0-9.')
    secs="${secs%%.*}"
    if [[ -z "$secs" ]]; then
        secs=30
    else
        secs=$(( secs + 2 ))
    fi
    (( secs < 5 )) && secs=5
    (( secs > REDDIT_MAX_WAIT )) && secs=$REDDIT_MAX_WAIT
    echo "$secs"
}

# Explain an HTTP status from Reddit in plain language.
# Args: $1 - status code, $2 - subreddit
_reddit_explain_status() {
    case "$1" in
        000) echo "network error (could not reach Reddit)" ;;
        401) echo "Reddit rejected the API credentials — check ~/.vmgr-reddit.conf" ;;
        403) echo "Reddit refused the request — r/$2 may be private or banned, or the request was blocked (add API credentials to ~/.vmgr-reddit.conf)" ;;
        404) echo "r/$2 was not found" ;;
        429) echo "Reddit is rate limiting requests — try again in a few minutes (API credentials raise the limit)" ;;
        5??) echo "Reddit is having problems (server error)" ;;
        *)   echo "unexpected response" ;;
    esac
}

# GET $1 (optionally with bearer token $2), waiting out HTTP 429 responses.
# Sets REDDIT_RESPONSE (body) and REDDIT_HTTP_STATUS. Returns 0 only for 200.
# Must be called directly, not inside $(...), so the variables survive.
_reddit_request() {
    local url="$1" token="$2"
    local hdr_file body_file code wait_secs attempt=0
    local -a auth=()
    [[ -n "$token" ]] && auth=(-H "Authorization: bearer $token")

    hdr_file=$(mktemp) || return 1
    body_file=$(mktemp) || { rm -f "$hdr_file"; return 1; }

    while true; do
        code=$(curl -s -D "$hdr_file" -o "$body_file" -w '%{http_code}' \
            -A "$REDDIT_USER_AGENT" "${auth[@]}" --max-time 30 "$url" 2>/dev/null)
        [[ "$code" =~ ^[0-9]{3}$ ]] || code=000

        if [[ "$code" == "429" && $attempt -lt $REDDIT_MAX_RETRIES ]]; then
            wait_secs=$(_reddit_retry_wait "$hdr_file")
            log_warning "Rate limited by Reddit (HTTP 429) — waiting ${wait_secs}s before retrying"
            sleep "$wait_secs"
            attempt=$(( attempt + 1 ))
            continue
        fi
        break
    done

    REDDIT_HTTP_STATUS="$code"
    REDDIT_RESPONSE=$(cat "$body_file")
    rm -f "$hdr_file" "$body_file"
    [[ "$code" == "200" ]]
}

# Fetch a subreddit listing page: JSON via OAuth when we have a token,
# otherwise the public RSS feed.
# Args: $1 - subreddit, $2 - "after" cursor (may be empty), $3 - sort
#       (hot/new/top/rising/controversial, default hot), $4 - time window
#       for top/controversial (hour/day/week/month/year/all, may be empty)
# Sets REDDIT_RESPONSE / REDDIT_HTTP_STATUS; returns 0 on HTTP 200.
_reddit_fetch_listing() {
    local subreddit="$1"
    local after="$2"
    local sort="${3:-hot}"
    local time_window="$4"
    local base_url query

    if [[ -n "$REDDIT_ACCESS_TOKEN" ]]; then
        base_url="https://oauth.reddit.com/r/${subreddit}/${sort}.json"
    else
        base_url="https://www.reddit.com/r/${subreddit}/${sort}.rss"
    fi

    query="?limit=100&raw_json=1"
    [[ -n "$after" ]] && query+="&after=$after"
    if [[ -n "$time_window" && ( "$sort" == "top" || "$sort" == "controversial" ) ]]; then
        query+="&t=$time_window"
    fi

    _reddit_request "${base_url}${query}" "$REDDIT_ACCESS_TOKEN"
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
        elif (($p.crosspost_parent_list[0]? // $p) | .is_gallery == true) then
            # Galleries (and crossposts of them): one item per valid image, taken
            # from the original i.redd.it file named by media_id + mime type
            ($p.crosspost_parent_list[0]? // $p) as $g |
            $g.gallery_data.items[]? |
            .media_id as $m |
            ($g.media_metadata[$m]? // null) as $md |
            select($md != null and ($md.status // "valid") == "valid") |
            (($md.m // "image/jpg") | sub("^image/"; "") | if . == "jpeg" then "jpg" else . end) as $ext |
            {kind: "image", id: $p.id, url: ("https://i.redd.it/" + $m + "." + $ext)}
        else empty end
    ' 2>/dev/null
}

# Shared jq filter: classify a post URL into a media item. Expects an object
# with .id and .url on its input; emits the item or nothing.
# shellcheck disable=SC2016
_REDDIT_CLASSIFY_JQ='
    if (.url | test("^https?://v\\.redd\\.it/[A-Za-z0-9]+/?$")) then
        {kind: "vreddit", id: .id, url: (.url | sub("/$"; ""))}
    elif (.url | test("\\.gifv$"; "i")) then
        {kind: "gifv", id: .id, url: (.url | sub("\\.gifv$"; ".mp4"; "i"))}
    elif (.url | test("\\.(mp4|webm)$"; "i")) then
        {kind: "video", id: .id, url: .url}
    elif (.url | test("\\.(jpg|jpeg|png|gif|webp)$"; "i")) then
        {kind: "image", id: .id, url: .url}
    elif (.url | test("^https?://(www\\.)?reddit\\.com/gallery/")) then
        {kind: "gallery", id: .id, url: .url}
    else empty end
'

# Extract downloadable media items from an RSS/Atom listing (stdin) as NDJSON,
# in the same shape as _reddit_extract_media. The feed carries each post's
# target link in a "[link]" anchor; v.redd.it posts come out as kind "vreddit"
# (resolved to a concrete stream later, in _reddit_download_item).
_reddit_extract_media_rss() {
    local tab=$'\t'
    sed 's#<entry>#\
<entry>#g' | \
        sed -nE "s#^<entry>.*&lt;span&gt;&lt;a href=&quot;([^ ]*)&quot;&gt;\\[link\\]&lt;.*<id>t3_([A-Za-z0-9]+)</id>.*#\\2${tab}\\1#p" | \
        sed 's/&amp;amp;/\&/g; s/&amp;/\&/g' | \
        jq -Rc "split(\"\\t\") | {id: .[0], url: .[1]} | ${_REDDIT_CLASSIFY_JQ}" 2>/dev/null
}

# Print the "after" cursor for the next page of a listing response (stdin).
# Args: $1 - "json" or "rss"
_reddit_next_cursor() {
    if [[ "$1" == "rss" ]]; then
        grep -oE '<id>t3_[A-Za-z0-9]+</id>' | tail -1 | sed -E 's#<id>(t3_[A-Za-z0-9]+)</id>#\1#'
    else
        jq -r '.data.after // empty' 2>/dev/null
    fi
}

# Look up the best video filename for a v.redd.it video from its DASH manifest
# (renditions are listed lowest to highest quality).
# Args: $1 - video base directory URL (e.g. https://v.redd.it/<id>)
# Prints the video filename (e.g. CMAF_720.mp4) if found, nothing otherwise
_reddit_find_video_filename() {
    local video_dir="$1"
    local mpd
    mpd=$(curl -sf -A "$REDDIT_USER_AGENT" "${video_dir}/DASHPlaylist.mpd" 2>/dev/null) || return 1

    echo "$mpd" | awk '/contentType="video"/{p=1} p{print} /<\/AdaptationSet>/{if(p) exit}' | \
        sed -n 's#.*<BaseURL>\([^<]*\)</BaseURL>.*#\1#p' | tail -1
}

# Download a single media item described by a JSON line from _reddit_extract_media
# Args: $1 - JSON item, $2 - output directory
# Returns: 0 on success, 1 on failure, 2 if skipped (already exists),
#          3 if unsupported without API credentials (gallery from the RSS feed)
_reddit_download_item() {
    local item="$1"
    local output_dir="$2"

    local kind id url
    kind=$(jq -r '.kind' <<< "$item")
    id=$(jq -r '.id' <<< "$item")
    url=$(jq -r '.url' <<< "$item")

    # The RSS feed does not list a gallery's images; they need the API
    [[ "$kind" == "gallery" ]] && return 3

    local filename dest
    if [[ "$kind" == "reddit_video" || "$kind" == "vreddit" ]]; then
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

    if [[ "$kind" == "vreddit" ]]; then
        # RSS gives only https://v.redd.it/<id>; pick the stream from the manifest
        local video_file
        video_file=$(_reddit_find_video_filename "$url")
        if [[ -n "$video_file" ]]; then
            _reddit_download_reddit_video "${url}/${video_file}" "$dest"
        else
            false
        fi
    elif [[ "$kind" == "reddit_video" ]]; then
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
        sed -n 's#.*<BaseURL>\([^<]*\)</BaseURL>.*#\1#p' | tail -1
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
    local feed_format=rss
    if _reddit_get_access_token; then
        feed_format=json
        log_verbose "Authenticated with Reddit API"
    elif [[ -f "$REDDIT_CONFIG_FILE" ]]; then
        log_warning "Reddit API authentication failed — using the public RSS feed instead (slower, rate limited). Check the credentials in $REDDIT_CONFIG_FILE"
    else
        log_warning "No Reddit API credentials ($REDDIT_CONFIG_FILE) — using the public RSS feed (slower, rate limited)"
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
    local galleries=0
    local after=""

    while [[ $downloaded -lt $max_images ]]; do
        if ! _reddit_fetch_listing "$subreddit" "$after" "$sort" "$time_window"; then
            log_error "Failed to fetch r/$subreddit (HTTP ${REDDIT_HTTP_STATUS}): $(_reddit_explain_status "$REDDIT_HTTP_STATUS" "$subreddit")"
            return 1
        fi
        local response="$REDDIT_RESPONSE"

        local items=()
        if [[ "$feed_format" == "rss" ]]; then
            mapfile -t items < <(echo "$response" | _reddit_extract_media_rss)
        else
            mapfile -t items < <(echo "$response" | _reddit_extract_media)
        fi

        # Pagination cursor (also tells us whether this was the last page)
        after=$(echo "$response" | _reddit_next_cursor "$feed_format")

        if [[ ${#items[@]} -eq 0 && -z "$after" ]]; then
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
                3)
                    ((galleries++))
                    continue
                    ;;
                *)
                    ((failed++))
                    ;;
            esac

            sleep "$REDDIT_RATE_LIMIT_DELAY"
        done

        [[ -z "$after" ]] && break
        sleep "$REDDIT_RATE_LIMIT_DELAY"
    done

    echo ""
    log_success "Downloaded $downloaded items from r/$subreddit"
    [[ $skipped -gt 0 ]] && log_info "Skipped $skipped (already existed)"
    [[ $galleries -gt 0 ]] && log_warning "Skipped $galleries gallery post(s) — galleries need Reddit API credentials ($REDDIT_CONFIG_FILE)"
    [[ $failed -gt 0 ]] && log_warning "$failed downloads failed"
}

return 0
