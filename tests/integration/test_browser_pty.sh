#!/usr/bin/env bash
# Integration tests for the interactive directory browser (lib/browser.sh).
# Drives browse_directory inside a real pseudo-terminal with scripted keys.
# Skipped when python3 (for the pty module) is not available.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"

_PTY_DRIVER=""

_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    mkdir -p "$TEST_TMPDIR/root/alpha/inner" "$TEST_TMPDIR/root/beta"
    _PTY_DRIVER="$TEST_TMPDIR/drive.py"
    cat > "$_PTY_DRIVER" <<'PY'
import os, pty, re, select, sys, time

lib, start, keys = sys.argv[1], sys.argv[2], sys.argv[3]
keys = keys.encode().decode('unicode_escape').encode('latin1')
script = (
    'export LOG_FILE=/dev/null LOG_DIR=/dev/null UNDO_LOG_DIR=/dev/null; '
    f'for f in {lib}/core.sh {lib}/platform.sh {lib}/utils.sh {lib}/theme.sh {lib}/browser.sh; do source "$f" >/dev/null 2>&1; done; '
    'BROWSER_RECENT_FILE=/dev/null; '
    f'browse_directory "{start}"; echo "RESULT rc=$? T=$TARGET_FOLDER"'
)
pid, fd = pty.fork()
if pid == 0:
    os.environ['TERM'] = 'xterm'
    os.execvp('bash', ['bash', '-c', script])

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
    return out

drain(1.0)
for k in re.findall(rb'\x1b\[[A-D]|\x1b.|.', keys, re.S):
    os.write(fd, k)
    time.sleep(0.12)
m = re.search(r'RESULT rc=(\d+) T=(.*)', drain(1.0).decode(errors='replace'))
print(f'{m.group(1)}|{m.group(2).strip()}' if m else 'NORESULT')
PY
}
_teardown() { [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"; }

# _drive START KEYS  ->  "rc|chosen-folder"
_drive() { python3 "$_PTY_DRIVER" "$LIB_DIR" "$1" "$2" 2>/dev/null; }

if ! command -v python3 >/dev/null 2>&1; then
    test_browser_pty_skipped() { assert_equals "1" "1" "browser pty tests skipped (no python3)"; }
    return 0 2>/dev/null || exit 0
fi

test_pty_enter_chooses_highlighted() {
    _setup
    assert_equals "0|$TEST_TMPDIR/root/alpha" "$(_drive "$TEST_TMPDIR/root" '\r')" \
        "browser: Enter chooses the highlighted folder"
    _teardown
}

test_pty_down_then_enter() {
    _setup
    assert_equals "0|$TEST_TMPDIR/root/beta" "$(_drive "$TEST_TMPDIR/root" '\x1b[B\r')" \
        "browser: Down then Enter chooses the second folder"
    _teardown
}

test_pty_right_opens_then_s_chooses_location() {
    _setup
    assert_equals "0|$TEST_TMPDIR/root/alpha" "$(_drive "$TEST_TMPDIR/root" '\x1b[Cs')" \
        "browser: Right opens the folder, S chooses it as the Location"
    _teardown
}

test_pty_backspace_goes_up() {
    _setup
    assert_equals "0|$TEST_TMPDIR/root" "$(_drive "$TEST_TMPDIR/root" '\x1b[C\x7fs')" \
        "browser: Backspace goes up one level"
    _teardown
}

test_pty_number_keys_do_not_navigate() {
    _setup
    assert_equals "0|$TEST_TMPDIR/root" "$(_drive "$TEST_TMPDIR/root" '2s')" \
        "browser: number keys no longer open folders"
    _teardown
}

test_pty_double_slash_normalized() {
    _setup
    assert_equals "0|/" "$(_drive "//" 's')" \
        "browser: a leading // is collapsed to /"
    _teardown
}

test_pty_cancel() {
    _setup
    assert_equals "1|" "$(_drive "$TEST_TMPDIR/root" 'q')" \
        "browser: Q cancels with a non-zero status"
    _teardown
}
