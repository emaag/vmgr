#!/usr/bin/env bash
#
# vmgr Test Helpers
# Shared assert functions, module loader, and temp directory management.
#

# ── Project root ────────────────────────────────────────────────────────────
VMGR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$VMGR_ROOT/lib"

# ── Counters (shared across all test files in a run) ────────────────────────
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_SUITE=""

# ── Output helpers ───────────────────────────────────────────────────────────
_GREEN=$'\033[0;32m'
_RED=$'\033[0;31m'
_YELLOW=$'\033[0;33m'
_CYAN=$'\033[0;36m'
_RESET=$'\033[0m'
_BOLD=$'\033[1m'

_pass() {
    echo "${_GREEN}  PASS${_RESET}  $1"
    TESTS_PASSED=$(( TESTS_PASSED + 1 ))
}
_fail() {
    echo "${_RED}  FAIL${_RESET}  $1"
    if [[ -n "$2" ]]; then echo "         ${_YELLOW}expected:${_RESET} $2"; fi
    if [[ -n "$3" ]]; then echo "         ${_YELLOW}actual:  ${_RESET} $3"; fi
    TESTS_FAILED=$(( TESTS_FAILED + 1 ))
}

# ── Assert functions ─────────────────────────────────────────────────────────

# assert_equals EXPECTED ACTUAL NAME
assert_equals() {
    local expected="$1" actual="$2" name="$3"
    if [[ "$expected" == "$actual" ]]; then
        _pass "$name"
    else
        _fail "$name" "$expected" "$actual"
    fi
}

# assert_not_equals UNEXPECTED ACTUAL NAME
assert_not_equals() {
    local unexpected="$1" actual="$2" name="$3"
    if [[ "$unexpected" != "$actual" ]]; then
        _pass "$name"
    else
        _fail "$name" "(anything except '$unexpected')" "$actual"
    fi
}

# assert_exits_zero CMD NAME
assert_exits_zero() {
    local cmd="$1" name="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        _pass "$name"
    else
        _fail "$name" "exit 0" "exit $?"
    fi
}

# assert_exits_nonzero CMD NAME
assert_exits_nonzero() {
    local cmd="$1" name="$2"
    if ! eval "$cmd" >/dev/null 2>&1; then
        _pass "$name"
    else
        _fail "$name" "exit non-zero" "exit 0"
    fi
}

# assert_file_exists PATH NAME
assert_file_exists() {
    local path="$1" name="$2"
    if [[ -e "$path" ]]; then
        _pass "$name"
    else
        _fail "$name" "file exists: $path" "file not found"
    fi
}

# assert_file_not_exists PATH NAME
assert_file_not_exists() {
    local path="$1" name="$2"
    if [[ ! -e "$path" ]]; then
        _pass "$name"
    else
        _fail "$name" "file absent: $path" "file exists"
    fi
}

# assert_contains SUBSTRING STRING NAME
assert_contains() {
    local substr="$1" string="$2" name="$3"
    if [[ "$string" == *"$substr"* ]]; then
        _pass "$name"
    else
        _fail "$name" "contains '$substr'" "'$string'"
    fi
}

# assert_matches REGEX STRING NAME  (bash extended regex)
assert_matches() {
    local regex="$1" string="$2" name="$3"
    if [[ "$string" =~ $regex ]]; then
        _pass "$name"
    else
        _fail "$name" "matches /$regex/" "'$string'"
    fi
}

# ── Module loading ───────────────────────────────────────────────────────────

# Stub all log display functions to keep test output clean.
# Actual log_message writes are redirected to LOG_FILE=/dev/null.
stub_logging() {
    log_verbose()     { :; }
    log_success()     { :; }
    log_error()       { :; }
    log_warning()     { :; }
    log_info()        { :; }
    log_message()     { :; }
    start_operation() { :; }
    end_operation()   { :; }
    print_statistics(){ :; }
}

# Load the core vmgr environment (core + platform + logging) in test mode.
# Call this once at the top of each test file.
load_vmgr_core() {
    export LOG_FILE=/dev/null
    export LOG_DIR=/dev/null
    export UNDO_LOG_DIR=/dev/null
    source "$LIB_DIR/core.sh"
    source "$LIB_DIR/platform.sh"
    source "$LIB_DIR/logging.sh"
    stub_logging
    # Safe defaults for testing
    DRY_RUN=false
    VERBOSE=false
    INTERACTIVE=false
    ORGANIZE_SHOW_PROGRESS=false
    ORGANIZE_LOG_OPERATIONS=true
}

# Source an additional module after core is loaded.
load_module_under_test() {
    source "$LIB_DIR/$1"
}

# ── Temp directory management ────────────────────────────────────────────────
TEST_TMPDIR=""

setup_tmpdir() {
    TEST_TMPDIR="$(mktemp -d)"
    trap 'teardown_tmpdir' EXIT
}

teardown_tmpdir() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
        TEST_TMPDIR=""
    fi
}

# ── Test runner ──────────────────────────────────────────────────────────────

# Run all test_* functions defined in the current shell.
# Prints suite header, runs each test, returns number of failures.
run_test_file() {
    local file="$1"
    local suite_name
    suite_name="$(basename "$file" .sh)"

    echo ""
    echo "${_BOLD}${_CYAN}▶ ${suite_name}${_RESET}"

    local before_pass=$TESTS_PASSED
    local before_fail=$TESTS_FAILED

    # Source the file to get test functions defined
    # shellcheck source=/dev/null
    source "$file"

    # Collect and run all test_* functions
    local fn
    while IFS= read -r fn; do
        "$fn" || true
    done < <(declare -F | awk '{print $3}' | grep '^test_' | sort)

    local suite_pass=$(( TESTS_PASSED - before_pass ))
    local suite_fail=$(( TESTS_FAILED - before_fail ))
    echo "  ${_CYAN}↳ ${suite_pass} passed, ${suite_fail} failed${_RESET}"
}

# Print final summary line
print_summary() {
    local total=$(( TESTS_PASSED + TESTS_FAILED ))
    echo ""
    echo "${_BOLD}════════════════════════════════════${_RESET}"
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "${_GREEN}${_BOLD}  ALL TESTS PASSED  ${TESTS_PASSED}/${total}${_RESET}"
    else
        echo "${_RED}${_BOLD}  FAILURES: ${TESTS_FAILED}/${total}${_RESET}"
    fi
    echo "${_BOLD}════════════════════════════════════${_RESET}"
    echo ""
}
