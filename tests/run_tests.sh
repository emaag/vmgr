#!/usr/bin/env bash
#
# vmgr Test Runner
# Usage:
#   bash tests/run_tests.sh              # run all tests
#   bash tests/run_tests.sh unit         # run unit tests only
#   bash tests/run_tests.sh integration  # run integration tests only
#   bash tests/run_tests.sh tests/unit/test_file_ops.sh  # run one file
#
# Intentionally no set -e: test runner must survive individual failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# ── File selection ────────────────────────────────────────────────────────────
filter="${1:-all}"
declare -a FILES_TO_RUN

case "$filter" in
    unit)
        mapfile -t FILES_TO_RUN < <(find "$SCRIPT_DIR/unit" -name "test_*.sh" | sort)
        ;;
    integration)
        mapfile -t FILES_TO_RUN < <(find "$SCRIPT_DIR/integration" -name "test_*.sh" | sort)
        ;;
    all)
        mapfile -t FILES_TO_RUN < <(find "$SCRIPT_DIR/unit" "$SCRIPT_DIR/integration" -name "test_*.sh" 2>/dev/null | sort)
        ;;
    *.sh)
        # Specific file
        if [[ ! -f "$filter" ]]; then
            echo "Error: test file not found: $filter" >&2
            exit 1
        fi
        FILES_TO_RUN=("$filter")
        ;;
    *)
        echo "Usage: $0 [all|unit|integration|path/to/test_file.sh]" >&2
        exit 1
        ;;
esac

if [[ ${#FILES_TO_RUN[@]} -eq 0 ]]; then
    echo "No test files found." >&2
    exit 1
fi

echo ""
echo "${_BOLD}vmgr Test Suite${_RESET}"
echo "Running: $filter"

# ── Run each test file in a subshell to keep state isolated ──────────────────
# We accumulate pass/fail counts back from each subshell via temp files.
PASS_FILE="$(mktemp)"
FAIL_FILE="$(mktemp)"
echo 0 > "$PASS_FILE"
echo 0 > "$FAIL_FILE"

for test_file in "${FILES_TO_RUN[@]}"; do
    # Each test file runs in its own subshell so function definitions and
    # filesystem side-effects don't bleed into the next file.
    (
        source "$SCRIPT_DIR/helpers.sh"
        run_test_file "$test_file"
        echo "$TESTS_PASSED" >> "$PASS_FILE"
        echo "$TESTS_FAILED" >> "$FAIL_FILE"
    ) || true
done

# Sum counts from all subshells
TESTS_PASSED=0
TESTS_FAILED=0
while IFS= read -r n; do TESTS_PASSED=$(( TESTS_PASSED + n )); done < "$PASS_FILE"
while IFS= read -r n; do TESTS_FAILED=$(( TESTS_FAILED + n )); done < "$FAIL_FILE"
rm -f "$PASS_FILE" "$FAIL_FILE"

print_summary

[[ $TESTS_FAILED -eq 0 ]]
