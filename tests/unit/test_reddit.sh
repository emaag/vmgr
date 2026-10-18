#!/usr/bin/env bash
# Unit tests for lib/reddit.sh (offline):
#   RSS media extraction, pagination cursor, 429 handling, status messages

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core
load_module_under_test "utils.sh"
load_module_under_test "reddit.sh"

# Real feeds are HTML-escaped inside <content>, with the post id after the content.
_entry() { # id url
    printf '<entry><content type="html">&lt;span&gt;&lt;a href=&quot;%s&quot;&gt;[link]&lt;/a&gt;&lt;/span&gt; &lt;span&gt;&lt;a href=&quot;https://www.reddit.com/r/x/comments/%s/t/&quot;&gt;[comments]&lt;/a&gt;&lt;/span&gt;</content><id>t3_%s</id></entry>' "$2" "$1" "$1"
}

# Image, v.redd.it video, gallery (skipped), gifv, mp4 with query, webm
_feed() {
    printf '<?xml version="1.0"?><feed><id>/r/x/hot.rss</id>'
    _entry aaa111 "https://i.redd.it/pic.jpeg"
    _entry bbb222 "https://v.redd.it/vid999"
    _entry ccc333 "https://www.reddit.com/gallery/ccc333"
    _entry ddd444 "https://i.imgur.com/clip.gifv"
    _entry eee555 "https://example.com/a.mp4?x=1&amp;amp;y=2"
    _entry fff666 "https://example.com/b.webm"
    printf '</feed>'
}

test_rss_extract_kinds() {
    local result
    result=$(_feed | _reddit_extract_media_rss | jq -r '[.kind, .id] | join(":")' | tr '\n' ' ')
    assert_equals "image:aaa111 vreddit:bbb222 gallery:ccc333 gifv:ddd444 video:fff666 " "$result" "rss extract: kinds and ids (query-string link skipped)"
}

test_rss_extract_urls() {
    local result
    result=$(_feed | _reddit_extract_media_rss | jq -r 'select(.kind=="gifv" or .kind=="vreddit") | .url' | tr '\n' ' ')
    assert_equals "https://v.redd.it/vid999 https://i.imgur.com/clip.mp4 " "$result" "rss extract: gifv rewritten to mp4, v.redd.it kept bare"
}

test_rss_extract_empty_feed() {
    local result
    result=$(printf '<feed></feed>' | _reddit_extract_media_rss | wc -l | tr -d ' ')
    assert_equals "0" "$result" "rss extract: empty feed yields nothing"
}

test_rss_cursor_is_last_entry() {
    local result
    result=$(_feed | _reddit_next_cursor rss)
    assert_equals "t3_fff666" "$result" "rss cursor: id of the last entry"
}

test_rss_cursor_empty_feed() {
    local result
    result=$(printf '<feed></feed>' | _reddit_next_cursor rss)
    assert_equals "" "$result" "rss cursor: none for an empty feed"
}

test_json_cursor() {
    local result
    result=$(echo '{"data":{"after":"t3_zzz","children":[]}}' | _reddit_next_cursor json)
    assert_equals "t3_zzz" "$result" "json cursor: data.after"
}

test_json_extract_still_works() {
    local result
    result=$(echo '{"data":{"children":[{"data":{"id":"p1","url":"https://i.redd.it/a.png"}}]}}' | _reddit_extract_media | jq -r .kind)
    assert_equals "image" "$result" "json extract: image post"
}

# ── galleries ────────────────────────────────────────────────────────────────

_gallery_json() {
    cat <<'J'
{"data":{"children":[
 {"data":{"id":"g1","url":"https://www.reddit.com/gallery/g1","is_gallery":true,
  "gallery_data":{"items":[{"media_id":"aaa"},{"media_id":"bbb"},{"media_id":"ccc"},{"media_id":"ddd"}]},
  "media_metadata":{
    "aaa":{"status":"valid","m":"image/jpg"},
    "bbb":{"status":"valid","m":"image/png"},
    "ccc":{"status":"failed","m":"image/jpg"},
    "ddd":{"status":"valid","m":"image/gif"}}}},
 {"data":{"id":"x1","url":"https://www.reddit.com/gallery/x1","is_gallery":false}},
 {"data":{"id":"cp1","url":"https://www.reddit.com/gallery/orig","crosspost_parent_list":[
  {"is_gallery":true,"gallery_data":{"items":[{"media_id":"zzz"}]},"media_metadata":{"zzz":{"status":"valid","m":"image/webp"}}}]}}
]}}
J
}

test_json_gallery_expands_to_images() {
    local result
    result=$(_gallery_json | _reddit_extract_media | jq -r '[.kind, .id, .url] | join(" ")' | tr '\n' ',')
    assert_equals "image g1 https://i.redd.it/aaa.jpg,image g1 https://i.redd.it/bbb.png,image g1 https://i.redd.it/ddd.gif,image cp1 https://i.redd.it/zzz.webp," "$result" "json gallery: valid images only, mime to extension, crosspost handled"
}

test_json_gallery_without_metadata() {
    local result
    result=$(echo '{"data":{"children":[{"data":{"id":"g2","url":"https://www.reddit.com/gallery/g2","is_gallery":true}}]}}' | _reddit_extract_media | wc -l | tr -d ' ')
    assert_equals "0" "$result" "json gallery: no gallery_data yields nothing"
}

test_rss_gallery_kind() {
    local result
    result=$( { printf '<feed>'; _entry g3 "https://www.reddit.com/gallery/g3"; printf '</feed>'; } | _reddit_extract_media_rss | jq -r .kind)
    assert_equals "gallery" "$result" "rss gallery: classified as gallery"
}

test_download_item_gallery_unsupported() {
    local d; d="$(mktemp -d)"
    _reddit_download_item '{"kind":"gallery","id":"g3","url":"https://www.reddit.com/gallery/g3"}' "$d"
    local rc=$?
    local n; n=$(find "$d" -type f | wc -l | tr -d ' ')
    assert_equals "3:0" "$rc:$n" "download_item: gallery returns 3 and writes nothing"
    rm -rf "$d"
}

# ── retry wait ───────────────────────────────────────────────────────────────

test_retry_wait_uses_reset_header() {
    local h; h="$(mktemp)"
    printf 'HTTP/2 429\r\nx-ratelimit-reset: 38\r\n' > "$h"
    assert_equals "40" "$(_reddit_retry_wait "$h")" "retry wait: x-ratelimit-reset + 2s"
    rm -f "$h"
}

test_retry_wait_prefers_retry_after() {
    local h; h="$(mktemp)"
    printf 'HTTP/2 429\r\nRetry-After: 10\r\n' > "$h"
    assert_equals "12" "$(_reddit_retry_wait "$h")" "retry wait: Retry-After header"
    rm -f "$h"
}

test_retry_wait_default_and_clamp() {
    local h d c; h="$(mktemp)"
    printf 'HTTP/2 429\r\n' > "$h"
    d="$(_reddit_retry_wait "$h")"
    printf 'HTTP/2 429\r\nretry-after: 99999\r\n' > "$h"
    c="$(_reddit_retry_wait "$h")"
    assert_equals "30:$REDDIT_MAX_WAIT" "$d:$c" "retry wait: default 30s, capped at REDDIT_MAX_WAIT"
    rm -f "$h"
}

# ── _reddit_request (fake curl pops one status code per call) ────────────────
# The fake runs inside $(...), so its state lives in a file, not a variable.

_FAKE_CODES=""

sleep() { echo "$1" >> "$_FAKE_CODES.slept"; }

curl() {
    local hdr="" out="" a prev="" code
    for a in "$@"; do
        [[ "$prev" == "-D" ]] && hdr="$a"
        [[ "$prev" == "-o" ]] && out="$a"
        prev="$a"
    done
    code="$(head -1 "$_FAKE_CODES")"
    tail -n +2 "$_FAKE_CODES" > "$_FAKE_CODES.next"; mv "$_FAKE_CODES.next" "$_FAKE_CODES"
    [[ -n "$hdr" ]] && printf 'HTTP/2 %s\r\nx-ratelimit-reset: 3\r\n' "$code" > "$hdr"
    [[ -n "$out" ]] && echo "body-$code" > "$out"
    printf '%s' "$code"
}

_with_codes() {
    _FAKE_CODES="$(mktemp)"
    printf '%s\n' "$@" > "$_FAKE_CODES"
    rm -f "$_FAKE_CODES.slept"
}

_sleep_count() {
    if [[ -f "$_FAKE_CODES.slept" ]]; then wc -l < "$_FAKE_CODES.slept" | tr -d ' '; else echo 0; fi
}

test_request_ok() {
    _with_codes 200
    _reddit_request "https://example/x" ""
    local rc=$?
    assert_equals "0:200:body-200" "$rc:$REDDIT_HTTP_STATUS:$REDDIT_RESPONSE" "request: 200 succeeds and exposes body"
    rm -f "$_FAKE_CODES" "$_FAKE_CODES.slept"
}

test_request_retries_429_then_succeeds() {
    _with_codes 429 429 200
    _reddit_request "https://example/x" ""
    local rc=$?
    assert_equals "0:200:2" "$rc:$REDDIT_HTTP_STATUS:$(_sleep_count)" "request: waits out two 429s then succeeds"
    rm -f "$_FAKE_CODES" "$_FAKE_CODES.slept"
}

test_request_gives_up_after_max_retries() {
    _with_codes 429 429 429 429 429
    REDDIT_MAX_RETRIES=2
    _reddit_request "https://example/x" ""
    local rc=$?
    REDDIT_MAX_RETRIES=3
    assert_equals "1:429:2" "$rc:$REDDIT_HTTP_STATUS:$(_sleep_count)" "request: returns 429 after exhausting retries"
    rm -f "$_FAKE_CODES" "$_FAKE_CODES.slept"
}

test_request_reports_403_without_retry() {
    _with_codes 403
    _reddit_request "https://example/x" ""
    local rc=$?
    assert_equals "1:403:0" "$rc:$REDDIT_HTTP_STATUS:$(_sleep_count)" "request: 403 reported immediately, no retry"
    rm -f "$_FAKE_CODES" "$_FAKE_CODES.slept"
}

# ── status explanations ──────────────────────────────────────────────────────

test_explain_status() {
    assert_contains "credentials" "$(_reddit_explain_status 403 pics)" "explain: 403 mentions credentials"
    assert_contains "nosuch" "$(_reddit_explain_status 404 nosuch)" "explain: 404 names the subreddit"
    assert_contains "rate limiting" "$(_reddit_explain_status 429 pics)" "explain: 429 mentions rate limiting"
    assert_contains "network" "$(_reddit_explain_status 000 pics)" "explain: 000 is a network error"
}

# ── Empty folders and bad names ───────────────────────────────────────────────

_dl_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    # the file-level fake sleep() appends to "$_FAKE_CODES.slept": keep that inside the temp dir
    _FAKE_CODES="$TEST_TMPDIR/fake_codes"
    OUT="$TEST_TMPDIR/pics/sub"
    REDDIT_RATE_LIMIT_DELAY=0
    _reddit_get_access_token() { return 1; }
    log_error() { echo "ERROR: $*"; }
    log_warning() { echo "WARN: $*"; }
    log_info() { echo "INFO: $*"; }
    log_success() { echo "OK: $*"; }
    show_progress() { :; }
}
_dl_teardown() {
    [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"
    _FAKE_CODES=""
    # Put back the real functions the test replaced (tests share one shell)
    source "$LIB_DIR/reddit.sh"
    source "$LIB_DIR/logging.sh"
    stub_logging
}

test_normalize_name_accepts_the_usual_forms() {
    assert_equals "EarthPorn" "$(_reddit_normalize_name 'EarthPorn')" "normalize: bare name"
    assert_equals "EarthPorn" "$(_reddit_normalize_name 'r/EarthPorn')" "normalize: r/name"
    assert_equals "EarthPorn" "$(_reddit_normalize_name '/r/EarthPorn/')" "normalize: /r/name/"
    assert_equals "EarthPorn" "$(_reddit_normalize_name 'https://www.reddit.com/r/EarthPorn/top/?t=week')" "normalize: pasted URL"
    assert_equals "EarthPorn" "$(_reddit_normalize_name '  EarthPorn  ')" "normalize: surrounding spaces"
}

test_valid_name_rules() {
    _reddit_valid_name "EarthPorn" && _reddit_valid_name "a_b2"
    assert_equals "0" "$?" "valid: letters, digits, underscores"
    local bad
    for bad in 'earthC:\Users\x.mp4' 'has space' 'a' 'toolongtoolongtoolongtoolong' 'bad!name' ''; do
        _reddit_valid_name "$bad"
        assert_not_equals "0" "$?" "valid: '$bad' is refused"
    done
}

test_a_pasted_file_path_is_refused_before_any_folder_is_made() {
    _dl_setup
    local out rc=0
    out="$(download_subreddit_images 'earthC:\Users\emaag\Videos\prom\clip.mp4' "$OUT" 5 2>&1)" || rc=$?
    assert_equals "1" "$rc" "bad name: the download fails"
    assert_contains "is not a valid subreddit name" "$out" "bad name: says why"
    assert_file_not_exists "$OUT" "bad name: no folder is created"
    _dl_teardown
}

test_a_failed_request_leaves_no_empty_folder() {
    _dl_setup
    _reddit_fetch_listing() { REDDIT_HTTP_STATUS=404; REDDIT_RESPONSE=""; return 1; }
    local out rc=0
    out="$(download_subreddit_images "nosuchsub" "$OUT" 5 2>&1)" || rc=$?
    assert_equals "1" "$rc" "404: the download fails"
    assert_contains "was not found" "$out" "404: explains it"
    assert_contains "banned, private and quarantined" "$out" "404: mentions the other reasons Reddit answers 404"
    assert_file_not_exists "$OUT" "404: no empty folder is left"
    _dl_teardown
}

test_only_galleries_is_reported_and_leaves_no_empty_folder() {
    _dl_setup
    _reddit_fetch_listing() { REDDIT_HTTP_STATUS=200; REDDIT_RESPONSE="$(_entry ccc333 'https://www.reddit.com/gallery/ccc333'; printf '</feed>')"; return 0; }
    # one gallery post, then the feed ends
    _reddit_next_cursor() { echo ""; }
    local out rc=0
    out="$(download_subreddit_images "galleryonly" "$OUT" 5 2>&1)" || rc=$?
    assert_equals "1" "$rc" "galleries only: reported as a failure, not a success"
    assert_contains "Nothing was downloaded" "$out" "galleries only: says nothing was downloaded"
    assert_contains "gallery post(s) were skipped" "$out" "galleries only: says why"
    assert_file_not_exists "$OUT" "galleries only: no empty folder"
    _dl_teardown
}

test_a_successful_download_creates_the_folder_and_returns_zero() {
    _dl_setup
    _reddit_fetch_listing() { REDDIT_HTTP_STATUS=200; REDDIT_RESPONSE="$(_entry aaa111 'https://i.redd.it/pic.jpeg'; printf '</feed>')"; return 0; }
    _reddit_next_cursor() { echo ""; }
    _reddit_download_item() { echo data > "$2/pic.jpg"; return 0; }
    local rc=0
    download_subreddit_images "goodsub" "$OUT" 5 >/dev/null 2>&1 || rc=$?
    assert_equals "0" "$rc" "success: returns 0"
    assert_file_exists "$OUT/pic.jpg" "success: the file is saved in the new folder"
    _dl_teardown
}

test_a_folder_we_did_not_create_is_never_removed() {
    _dl_setup
    mkdir -p "$OUT"
    _reddit_fetch_listing() { REDDIT_HTTP_STATUS=200; REDDIT_RESPONSE="$(_entry ccc333 'https://www.reddit.com/gallery/ccc333'; printf '</feed>')"; return 0; }
    _reddit_next_cursor() { echo ""; }
    download_subreddit_images "galleryonly" "$OUT" 5 >/dev/null 2>&1
    assert_file_exists "$OUT" "existing folder: left alone even when nothing was downloaded"
    _dl_teardown
}

test_an_uncreatable_output_folder_is_reported_up_front() {
    _dl_setup
    if [[ "$(id -u)" == 0 ]]; then _dl_teardown; return; fi
    mkdir -p "$TEST_TMPDIR/ro"; chmod a-w "$TEST_TMPDIR/ro"
    local out rc=0 requested=0
    _reddit_fetch_listing() { requested=1; return 1; }
    out="$(download_subreddit_images "goodsub" "$TEST_TMPDIR/ro/deeper/out" 5 2>&1)" || rc=$?
    chmod u+w "$TEST_TMPDIR/ro"
    assert_equals "1" "$rc" "unwritable: fails"
    assert_contains "Cannot create the output directory" "$out" "unwritable: says so before contacting Reddit"
    _dl_teardown
}

test_a_redirect_means_the_subreddit_does_not_exist() {
    local msg; msg="$(_reddit_explain_status 302 nosuchsub)"
    assert_contains "was not found" "$msg" "explain 302: not found"
    assert_contains "redirected to its search page" "$msg" "explain 302: says what Reddit did"
}

# ── API setup (offline: a fake curl plays Reddit's token endpoint) ────────────

GOOD_ID="goodClientId1234"; GOOD_SECRET="goodSecretValue1234567890"

# Records its arguments and the stdin config, then answers by credentials.
_fake_token_curl() {
    unset -f curl
    curl() {
        local out="" want_code=false stdin_cfg
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -o) out="$2"; shift 2 ;;
                -w) want_code=true; shift 2 ;;
                -K) stdin_cfg="$(cat)"; shift 2 ;;
                *) echo "$1" >> "$TEST_TMPDIR/curl_args"; shift ;;
            esac
        done
        echo "$stdin_cfg" > "$TEST_TMPDIR/curl_stdin"
        local code=401 body='{"error":401}'
        case "$stdin_cfg" in
            *"$GOOD_ID:$GOOD_SECRET"*) code=200; body='{"access_token":"tok123"}' ;;
            *neterr*) code=000; body='' ;;
            *server500*) code=500; body='' ;;
        esac
        [[ -n "$out" ]] && printf '%s' "$body" > "$out"
        if $want_code; then printf '%s' "$code"; else [[ "$code" == 200 ]] && printf '%s' "$body"; fi
        [[ "$code" == 200 || -n "$out" ]]
    }
}
_cfg_setup() {
    _SAVED_CURL="$(declare -f curl 2>/dev/null)"   # other tests in this file define their own fake curl
    TEST_TMPDIR="$(mktemp -d)"
    REDDIT_CONFIG_FILE="$TEST_TMPDIR/.vmgr-reddit.conf"
    USER="${USER:-$(id -un)}"
}
_cfg_teardown() {
    unset -f curl
    [[ -n "${_SAVED_CURL:-}" ]] && eval "$_SAVED_CURL"
    _SAVED_CURL=""
    [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"
    source "$LIB_DIR/reddit.sh"
    source "$LIB_DIR/logging.sh"
    stub_logging
}

test_client_id_and_secret_shapes() {
    _reddit_valid_client_id "abcDEF123_-xyz" && _reddit_valid_client_secret "abcDEF123_-xyz0123456789"
    assert_equals "0" "$?" "shape: plausible id and secret are accepted"
    local bad
    for bad in 'short' 'has space1234' 'semi;colon1234' 'quo"te1234567' '$(rm)12345678' ''; do
        _reddit_valid_client_id "$bad"
        assert_not_equals "0" "$?" "shape: id '$bad' is refused"
    done
    _reddit_valid_client_secret "tooshort"
    assert_not_equals "0" "$?" "shape: a short secret is refused"
}

test_api_configured_looks_at_the_file() {
    _cfg_setup
    reddit_api_configured; assert_not_equals "0" "$?" "configured: no file"
    echo 'REDDIT_CLIENT_ID="x"' > "$REDDIT_CONFIG_FILE"
    reddit_api_configured; assert_not_equals "0" "$?" "configured: only an id is not enough"
    printf 'REDDIT_CLIENT_ID="x"\nREDDIT_CLIENT_SECRET="y"\n' > "$REDDIT_CONFIG_FILE"
    reddit_api_configured; assert_equals "0" "$?" "configured: id and secret present"
    _cfg_teardown
}

test_credentials_test_reports_each_outcome() {
    _cfg_setup; _fake_token_curl
    assert_equals "ok" "$(_reddit_test_credentials "$GOOD_ID" "$GOOD_SECRET")" "test: good credentials"
    assert_equals "rejected" "$(_reddit_test_credentials "wrongClientId999" "wrongSecret0123456789")" "test: wrong credentials"
    assert_equals "network" "$(_reddit_test_credentials "neterr" "neterrneterrneterr")" "test: no connection"
    assert_equals "error:500" "$(_reddit_test_credentials "server500" "server500server500")" "test: unexpected status"
    _cfg_teardown
}

test_the_secret_never_appears_on_the_curl_command_line() {
    _cfg_setup; _fake_token_curl
    : > "$TEST_TMPDIR/curl_args"
    _reddit_test_credentials "$GOOD_ID" "$GOOD_SECRET" >/dev/null
    local args; args="$(cat "$TEST_TMPDIR/curl_args")"
    [[ "$args" != *"$GOOD_SECRET"* && "$args" != *"$GOOD_ID"* ]]
    assert_equals "0" "$?" "test: neither id nor secret is a curl argument"
    assert_contains "user = " "$(cat "$TEST_TMPDIR/curl_stdin")" "test: the credentials travel on stdin"
    # the real token request used by downloads is covered the same way
    printf 'REDDIT_CLIENT_ID="%s"\nREDDIT_CLIENT_SECRET="%s"\n' "$GOOD_ID" "$GOOD_SECRET" > "$REDDIT_CONFIG_FILE"
    : > "$TEST_TMPDIR/curl_args"; REDDIT_ACCESS_TOKEN=""
    _reddit_get_access_token
    assert_equals "tok123" "$REDDIT_ACCESS_TOKEN" "token: still obtained with credentials on stdin"
    args="$(cat "$TEST_TMPDIR/curl_args")"
    [[ "$args" != *"$GOOD_SECRET"* ]]
    assert_equals "0" "$?" "token: the secret is not a curl argument"
    _cfg_teardown
}

test_write_credentials_creates_a_private_file() {
    _cfg_setup
    _reddit_write_credentials "$GOOD_ID" "$GOOD_SECRET"
    assert_equals "0" "$?" "write: succeeds"
    assert_contains "REDDIT_CLIENT_ID=\"$GOOD_ID\"" "$(cat "$REDDIT_CONFIG_FILE")" "write: the id is saved"
    assert_contains "REDDIT_CLIENT_SECRET=\"$GOOD_SECRET\"" "$(cat "$REDDIT_CONFIG_FILE")" "write: the secret is saved"
    local mode; mode="$(stat -c '%a' "$REDDIT_CONFIG_FILE" 2>/dev/null || stat -f '%Lp' "$REDDIT_CONFIG_FILE")"
    assert_equals "600" "$mode" "write: readable only by the owner"
    assert_equals "0" "$(ls "$TEST_TMPDIR" | grep -c 'conf\.')" "write: no temp file is left behind"
    _cfg_teardown
}

test_write_credentials_keeps_other_settings_and_replaces_old_credentials() {
    _cfg_setup
    printf 'REDDIT_CLIENT_ID="old"\nREDDIT_CLIENT_SECRET="old"\nREDDIT_RATE_LIMIT_DELAY=3\n' > "$REDDIT_CONFIG_FILE"
    _reddit_write_credentials "$GOOD_ID" "$GOOD_SECRET"
    local text; text="$(cat "$REDDIT_CONFIG_FILE")"
    assert_contains "REDDIT_RATE_LIMIT_DELAY=3" "$text" "write: other settings are kept"
    assert_equals "1" "$(grep -c '^REDDIT_CLIENT_ID=' "$REDDIT_CONFIG_FILE")" "write: one id line, the old one is replaced"
    assert_equals "1" "$(grep -c "$GOOD_ID" "$REDDIT_CONFIG_FILE")" "write: it is the new id"
    _cfg_teardown
}

test_write_credentials_refuses_anything_that_could_be_shell_code() {
    _cfg_setup
    local rc=0
    _reddit_write_credentials 'abc"; touch /tmp/pwned; "' "$GOOD_SECRET" || rc=$?
    assert_not_equals "0" "$rc" "write: an id with shell syntax is refused"
    assert_file_not_exists "$REDDIT_CONFIG_FILE" "write: nothing is written for a refused value"
    _cfg_teardown
}

test_remove_credentials() {
    _cfg_setup
    printf 'REDDIT_CLIENT_ID="a"\nREDDIT_CLIENT_SECRET="b"\nREDDIT_RATE_LIMIT_DELAY=3\n' > "$REDDIT_CONFIG_FILE"
    _reddit_remove_credentials
    assert_file_exists "$REDDIT_CONFIG_FILE" "remove: the file stays while it has other settings"
    assert_equals "0" "$(grep -c 'CLIENT' "$REDDIT_CONFIG_FILE")" "remove: the credentials are gone"
    assert_contains "REDDIT_RATE_LIMIT_DELAY=3" "$(cat "$REDDIT_CONFIG_FILE")" "remove: the other setting survives"
    printf 'REDDIT_CLIENT_ID="a"\nREDDIT_CLIENT_SECRET="b"\n# note\n' > "$REDDIT_CONFIG_FILE"
    _reddit_remove_credentials
    assert_file_not_exists "$REDDIT_CONFIG_FILE" "remove: an otherwise empty file is deleted"
    _cfg_teardown
}

test_explain_test_messages() {
    assert_contains "client ID is the short text" "$(_reddit_explain_test rejected)" "explain: rejected tells you where to look"
    assert_contains "Could not reach Reddit" "$(_reddit_explain_test network)" "explain: network"
    assert_contains "500" "$(_reddit_explain_test error:500)" "explain: other status"
}

test_setup_needs_a_terminal() {
    _cfg_setup
    log_error() { echo "ERROR: $*"; }
    local out rc=0
    out="$(reddit_setup_interactive 2>&1 < /dev/null)" || rc=$?
    assert_equals "1" "$rc" "setup: refuses to run without a terminal"
    assert_contains "needs a terminal" "$out" "setup: says why and how to do it by hand"
    _cfg_teardown
}
