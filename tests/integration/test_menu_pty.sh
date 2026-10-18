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
for k in re.findall(rb'\x1b\[[A-D]|.', keys, re.S):
    os.write(fd, k)
    time.sleep(0.4)
    log += drain(0.3)
log += drain(0.8)
text = re.sub(r'\x1b\[[0-9;?]*[A-Za-z]', '', log)
done, _ = os.waitpid(pid, os.WNOHANG)
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
