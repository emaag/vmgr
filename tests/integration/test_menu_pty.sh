#!/usr/bin/env bash
# Integration tests for the interactive menus: single-keypress input (no Enter),
# Esc to go back, and plain mode. Drives the real script in a pseudo-terminal.
# Skipped when python3 (for the pty module) is not available.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    cat > "$TEST_TMPDIR/drive.py" <<'PY'
import os, pty, re, select, sys, time

script, keys = sys.argv[1], sys.argv[2]
keys = keys.encode().decode('unicode_escape').encode('latin1')
pid, fd = pty.fork()
if pid == 0:
    os.environ['TERM'] = 'xterm-256color'
    os.environ['COLUMNS'] = '100'
    if os.environ.get('DRV_PATH'):
        os.environ['PATH'] = os.environ['DRV_PATH'] + ':' + os.environ['PATH']
    os.execvp('bash', ['bash', script, '-i'])

def drain(timeout):
    out = b''
    while select.select([fd], [], [], timeout)[0]:
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
    return out.decode(errors='replace')

log = drain(2.0)
# Arrow sequences and short keys go one at a time; long typed text in one write
for k in re.findall(rb'\x1b\[[A-D]|[^\x1b\r]{8,}|.', keys, re.S):
    os.write(fd, k)
    time.sleep(0.4)
    log += drain(0.3)
log += drain(0.8)
text = re.sub(r'\x1b\[[0-9;?]*[A-Za-z]', '', log)
done, _ = os.waitpid(pid, os.WNOHANG)
if os.environ.get('DRV_FIND'):
    print('|'.join(str(text.count(t)) for t in os.environ['DRV_FIND'].split(',')))
    sys.exit(0)
print('|'.join(str(text.count(t)) for t in ('FILE OPERATIONS', 'UTILITIES', 'MAIN MENU', 'Goodbye', 'Press any key')) + f'|{int(done != 0)}')
PY
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

# _drive KEYS -> "fileops|utilities|mainmenu|goodbye|anykey|exited"
_drive() { HOME="$TEST_TMPDIR" python3 "$TEST_TMPDIR/drive.py" "$VMGR_ROOT/video-manager-ultimate.sh" "$1" 2>/dev/null; }

if ! command -v python3 >/dev/null 2>&1; then
    test_menu_pty_skipped() { assert_equals "1" "1" "menu pty tests skipped (no python3)"; }
    return 0 2>/dev/null || exit 0
fi

test_pty_menu_needs_no_enter() {
    _setup
    assert_equals "1|0|1|0|0|0" "$(_drive '1')" "menu: one keypress opens File Operations"
    _teardown
}

test_pty_menu_esc_goes_back() {
    _setup
    assert_equals "1|0|2|0|0|0" "$(_drive '1\x1b')" "menu: Esc returns to the main menu"
    _teardown
}

test_pty_menu_arrows_ignored() {
    _setup
    assert_equals "0|0|1|0|0|0" "$(_drive '\x1b[A\x1b[B')" "menu: arrow keys are ignored"
    _teardown
}

test_pty_menu_quit() {
    _setup
    assert_equals "0|0|1|1|0|1" "$(_drive 'q')" "menu: Q quits immediately"
    _teardown
}

test_pty_info_screen_waits_for_a_key() {
    _setup
    # Utilities > System Information shows the screen and waits instead of flashing past
    assert_equals "0|1|1|0|1|0" "$(_drive '57')" "menu: an info screen pauses for a key"
    _teardown
}

test_pty_pause_then_back_to_menu() {
    _setup
    assert_equals "0|2|1|0|1|0" "$(_drive '57x')" "menu: any key after the pause returns to the menu"
    _teardown
}

test_pty_batch_reachable_from_file_operations() {
    _setup
    # File Operations > Batch Processing > Batch Rename opens the folder queue
    assert_equals "1|1|1" "$(DRV_FIND='BATCH PROCESSING,BATCH RENAME MULTIPLE FOLDERS,Folders to process (0)' _drive '171')" \
        "menu: Batch Processing is reachable and opens an empty queue"
    _teardown
}

test_pty_batch_queue_cancels_back_to_menu() {
    _setup
    assert_equals "2" "$(DRV_FIND='BATCH PROCESSING' _drive '171q')" \
        "menu: Q on the queue returns to the Batch menu"
    _teardown
}

test_pty_batch_decline_changes_nothing() {
    _setup
    mkdir "$TEST_TMPDIR/vids"; touch "$TEST_TMPDIR/vids/studio one.mp4"
    local seen
    seen="$(DRV_FIND='BATCH PROCESSING' _drive "171t$TEST_TMPDIR/vids\\r\\rn")"
    assert_equals "2" "$seen" "batch: declining the confirm returns to the Batch menu"
    assert_file_exists "$TEST_TMPDIR/vids/studio one.mp4" "batch: declining leaves the files alone"
    _teardown
}

test_pty_batch_accept_renames() {
    _setup
    mkdir "$TEST_TMPDIR/vids"; touch "$TEST_TMPDIR/vids/studio one.mp4"
    DRV_FIND='Results' _drive "171t$TEST_TMPDIR/vids\\r\\ry" >/dev/null
    assert_file_exists "$TEST_TMPDIR/vids/[Studio] one.mp4" "batch: accepting the confirm renames the files"
    _teardown
}

# ── Reddit API setup ──────────────────────────────────────────────────────────

_setup_reddit_stub() {
    _setup
    mkdir -p "$TEST_TMPDIR/bin"
    cat > "$TEST_TMPDIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
out=""; want=false; cfg=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -w) want=true; shift 2 ;;
        -K) cfg="$(cat)"; shift 2 ;;
        *) shift ;;
    esac
done
code=401; body='{"error":401}'
case "$cfg" in *"goodClientId1234:goodSecretValue1234567890"*) code=200; body='{"access_token":"tok"}' ;; esac
[[ -n "$out" ]] && printf '%s' "$body" > "$out"
$want && printf '%s' "$code"
exit 0
STUB
    chmod +x "$TEST_TMPDIR/bin/curl"
    CONF="$TEST_TMPDIR/.vmgr-reddit.conf"
}

test_pty_reddit_menu_shows_the_api_status() {
    _setup_reddit_stub
    assert_equals "1" "$(DRV_FIND='Not set up: no galleries' DRV_PATH="$TEST_TMPDIR/bin" _drive '7')" "reddit menu: says the API is not set up"
    printf 'REDDIT_CLIENT_ID="x"\nREDDIT_CLIENT_SECRET="y"\n' > "$CONF"
    assert_equals "1" "$(DRV_FIND='API login saved' DRV_PATH="$TEST_TMPDIR/bin" _drive '7')" "reddit menu: says a login is saved"
    _teardown
}

test_pty_reddit_setup_saves_working_credentials() {
    _setup_reddit_stub
    local seen
    seen="$(DRV_FIND='Reddit login works' DRV_PATH="$TEST_TMPDIR/bin" _drive '72ngoodClientId1234\rgoodSecretValue1234567890\r')"
    assert_equals "1" "$seen" "reddit setup: reports the login works"
    assert_file_exists "$CONF" "reddit setup: the credentials file is written"
    assert_contains 'REDDIT_CLIENT_ID="goodClientId1234"' "$(cat "$CONF")" "reddit setup: the id is saved"
    assert_contains 'REDDIT_CLIENT_SECRET="goodSecretValue1234567890"' "$(cat "$CONF")" "reddit setup: the secret is saved"
    local mode; mode="$(stat -c '%a' "$CONF" 2>/dev/null || stat -f '%Lp' "$CONF")"
    assert_equals "600" "$mode" "reddit setup: the file is private"
    _teardown
}

test_pty_reddit_setup_does_not_echo_the_secret() {
    _setup_reddit_stub
    local shown
    shown="$(DRV_FIND='goodSecretValue1234567890' DRV_PATH="$TEST_TMPDIR/bin" _drive '72ngoodClientId1234\rgoodSecretValue1234567890\r')"
    assert_equals "0" "$shown" "reddit setup: the secret never appears on the screen"
    _teardown
}

test_pty_reddit_setup_rejected_credentials_are_not_saved() {
    _setup_reddit_stub
    local seen
    seen="$(DRV_FIND='Reddit rejected these credentials' DRV_PATH="$TEST_TMPDIR/bin" _drive '72nwrongClientId999\rwrongSecretValue0123456789\rn')"
    assert_equals "1" "$seen" "reddit setup: explains a rejected login"
    assert_file_not_exists "$CONF" "reddit setup: rejected credentials are not written"
    _teardown
}

test_pty_reddit_setup_can_test_and_delete_saved_credentials() {
    _setup_reddit_stub
    printf 'REDDIT_CLIENT_ID="goodClientId1234"\nREDDIT_CLIENT_SECRET="goodSecretValue1234567890"\n' > "$CONF"
    assert_equals "1" "$(DRV_FIND='The saved credentials work' DRV_PATH="$TEST_TMPDIR/bin" _drive '72t')" "reddit setup: tests the saved login"
    DRV_PATH="$TEST_TMPDIR/bin" _drive '72dy' >/dev/null
    assert_file_not_exists "$CONF" "reddit setup: delete removes the credentials"
    _teardown
}
