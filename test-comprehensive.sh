#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║          COMPREHENSIVE SYSTEM TEST - Video Manager Ultimate            ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

# Change to the work directory
cd /home/emaag/Work

PASS_COUNT=0
FAIL_COUNT=0
TEST_COUNT=0

pass() {
    echo "  ✅ PASS: $1"
    ((PASS_COUNT++))
    ((TEST_COUNT++))
}

fail() {
    echo "  ❌ FAIL: $1"
    ((FAIL_COUNT++))
    ((TEST_COUNT++))
}

test_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# SECTION 1: MODULE LOADING TESTS
# ============================================================================
test_section "1. MODULE LOADING & INITIALIZATION"

echo "Testing module loading..."
if ./test-modules.sh 2>&1 | grep -q "12/12 modules complete"; then
    pass "All 12 modules load successfully"
else
    fail "Module loading failed"
fi

echo "Testing version command..."
version_output=$(./video-manager-ultimate.sh --version 2>&1)
if echo "$version_output" | grep -q "v1.3.0"; then
    pass "Version command works (v1.3.0)"
else
    fail "Version command failed"
fi

echo "Testing help command..."
if ./video-manager-ultimate.sh --help 2>&1 | grep -q "USAGE:"; then
    pass "Help command displays correctly"
else
    fail "Help command failed"
fi

# ============================================================================
# SECTION 2: TAB COMPLETION TESTS
# ============================================================================
test_section "2. TAB COMPLETION - COMPREHENSIVE TESTING"

# Load completion
source ~/.bash_completion.d/vmgr 2>/dev/null || source vmgr-completion.bash

test_completion() {
    local cmdline="$1"
    local expected="$2"
    local description="$3"

    # Split into words
    read -ra COMP_WORDS <<< "$cmdline"
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))

    # Call completion
    _vmgr_completion 2>/dev/null

    # Check results
    if [[ ${#COMPREPLY[@]} -gt 0 ]]; then
        # Check if expected is in results
        local found=false
        for reply in "${COMPREPLY[@]}"; do
            if [[ "$reply" == "$expected" ]] || [[ "$expected" == "*" ]]; then
                found=true
                break
            fi
        done

        if $found; then
            pass "$description"
        else
            fail "$description (got: ${COMPREPLY[@]}, expected: $expected)"
        fi
    else
        if [[ "$expected" == "none" ]]; then
            pass "$description (correctly no completion)"
        else
            fail "$description (no completions)"
        fi
    fi
}

echo "Testing basic command completion..."
test_completion "vmgr ren" "rename" "Command completion: 'ren' → 'rename'"
test_completion "vmgr flat" "flatten" "Command completion: 'flat' → 'flatten'"
test_completion "vmgr clean" "cleanup" "Command completion: 'clean' → 'cleanup'"
test_completion "vmgr dup" "duplicates" "Command completion: 'dup' → 'duplicates'"
test_completion "vmgr sub" "subtitles" "Command completion: 'sub' → 'subtitles'"

echo "Testing option completion..."
test_completion "vmgr --d" "--dry-run" "Option completion: '--d' → '--dry-run'"
test_completion "vmgr --q" "--quiet" "Option completion: '--q' → '--quiet'"
test_completion "vmgr --i" "--interactive" "Option completion: '--i' → '--interactive'"
test_completion "vmgr --g" "--gpu" "Option completion: '--g' → '--gpu'"

echo "Testing value completion..."
test_completion "vmgr --model b" "base" "Model completion: 'b' → 'base'"
test_completion "vmgr --model s" "small" "Model completion: 's' → 'small'"
test_completion "vmgr --model m" "medium" "Model completion: 'm' → 'medium'"
test_completion "vmgr --format s" "srt" "Format completion: 's' → 'srt'"
test_completion "vmgr --format v" "vtt" "Format completion: 'v' → 'vtt'"

echo "Testing organize command completion..."
test_completion "vmgr --org" "*" "Organize options appear"
test_completion "vmgr --organize-t" "--organize-target" "Organize target completion"
test_completion "vmgr --organize-s" "--organize-search" "Organize search completion"
test_completion "vmgr --undo" "--undo-organize" "Undo organize completion"
test_completion "vmgr --list-u" "--list-undo" "List undo completion"

echo "Testing language completion..."
test_completion "vmgr --language e" "*" "Language 'e' shows options"
test_completion "vmgr --language a" "auto" "Language 'a' → 'auto'"

echo "Testing parallel value completion..."
test_completion "vmgr --parallel 4" "4" "Parallel value '4' completion"

echo "Testing directory completion after commands..."
test_completion "vmgr rename /tm" "/tmp" "Directory completion after rename"

# ============================================================================
# SECTION 3: KEYBOARD NAVIGATION - MENU STRUCTURE
# ============================================================================
test_section "3. KEYBOARD NAVIGATION - MENU STRUCTURE"

echo "Testing menu function existence..."
menu_funcs=(
    "show_main_menu"
    "show_single_operations_menu"
    "show_batch_menu"
    "show_workflow_menu"
    "show_duplicate_menu"
    "show_subtitle_menu"
    "show_catalog_menu"
    "show_utilities_menu"
    "show_settings_menu"
    "show_organize_settings_menu"
    "show_granular_controls_menu"
)

for func in "${menu_funcs[@]}"; do
    if grep -q "^${func}()" lib/ui.sh; then
        pass "Menu function exists: $func"
    else
        fail "Menu function missing: $func"
    fi
done

echo "Testing handler function existence..."
handler_funcs=(
    "handle_single_operations"
    "handle_batch_processing"
    "handle_workflows"
    "handle_duplicates"
    "handle_subtitles"
    "handle_catalog"
    "handle_utilities"
    "handle_organize_settings"
    "handle_settings"
    "handle_granular_controls"
)

for func in "${handler_funcs[@]}"; do
    if grep -q "^${func}()" lib/ui.sh; then
        pass "Handler function exists: $func"
    else
        fail "Handler function missing: $func"
    fi
done

echo "Testing interactive_menu function..."
if grep -q "^interactive_menu()" lib/ui.sh; then
    pass "interactive_menu function exists"
else
    fail "interactive_menu function missing"
fi

# ============================================================================
# SECTION 4: KEYBOARD INPUT HANDLING
# ============================================================================
test_section "4. KEYBOARD INPUT HANDLING"

echo "Testing read command availability..."
if bash -c "echo 'test' | read -r input && echo \$input" >/dev/null 2>&1; then
    pass "Bash 'read' command works"
else
    fail "Bash 'read' command failed"
fi

echo "Testing menu display with simulated input..."
# Test that menu can be invoked and exited
if echo "Q" | timeout 2 ./video-manager-ultimate.sh -i 2>&1 | grep -q "MAIN MENU\|Main Menu"; then
    pass "Interactive menu launches and accepts 'Q' to quit"
else
    fail "Interactive menu launch failed"
fi

echo "Testing numeric input handling..."
# Menu should accept numbers 1-6
menu_output=$(echo "" | timeout 1 ./video-manager-ultimate.sh -i 2>&1)
if echo "$menu_output" | grep -qE "\[1\]|\[2\]|\[3\]|\[4\]|\[5\]|\[6\]"; then
    pass "Menu displays numbered options (1-6)"
else
    fail "Menu numbered options not displayed"
fi

echo "Testing quit option..."
if echo "$menu_output" | grep -qE "\[Q\].*Quit|\[q\].*Quit"; then
    pass "Menu displays Quit option"
else
    fail "Menu Quit option not displayed"
fi

# ============================================================================
# SECTION 5: COLOR CODE TESTS
# ============================================================================
test_section "5. COLOR CODES & DISPLAY"

echo "Testing color code definitions..."
color_codes=(
    "COLOR_RESET"
    "COLOR_BOLD"
    "COLOR_RED"
    "COLOR_GREEN"
    "COLOR_YELLOW"
    "COLOR_BLUE"
    "COLOR_CYAN"
)

for color in "${color_codes[@]}"; do
    if grep -q "readonly ${color}=" lib/core.sh; then
        pass "Color code defined: $color"
    else
        fail "Color code missing: $color"
    fi
done

echo "Testing symbol definitions..."
symbols=(
    "SYMBOL_CHECK"
    "SYMBOL_CROSS"
    "SYMBOL_ARROW"
    "SYMBOL_INFO"
    "SYMBOL_WARN"
    "SYMBOL_STAR"
)

for symbol in "${symbols[@]}"; do
    if grep -q "readonly ${symbol}=" lib/core.sh; then
        pass "Symbol defined: $symbol"
    else
        fail "Symbol missing: $symbol"
    fi
done

# ============================================================================
# SECTION 6: CLI ARGUMENT TESTS
# ============================================================================
test_section "6. COMMAND LINE ARGUMENTS"

echo "Testing --dry-run flag..."
mkdir -p /tmp/vmgr-test
touch "/tmp/vmgr-test/test.mp4"
if ./video-manager-ultimate.sh --dry-run rename /tmp/vmgr-test 2>&1 | grep -q "Dry run\|dry run"; then
    pass "--dry-run flag works"
else
    fail "--dry-run flag failed"
fi
rm -rf /tmp/vmgr-test

echo "Testing --quiet flag..."
if ./video-manager-ultimate.sh --quiet --version 2>&1 | grep -q "v1.3.0"; then
    pass "--quiet flag accepted"
else
    fail "--quiet flag failed"
fi

echo "Testing --interactive flag..."
if echo "Q" | timeout 2 ./video-manager-ultimate.sh --interactive 2>&1 | grep -q "MAIN MENU\|Main Menu"; then
    pass "--interactive flag works"
else
    fail "--interactive flag failed"
fi

echo "Testing subtitle options..."
test_opts=(
    "--model tiny"
    "--format srt"
    "--language en"
    "--gpu"
    "--parallel 2"
)

for opt in "${test_opts[@]}"; do
    if ./video-manager-ultimate.sh $opt --help 2>&1 | grep -q "USAGE:"; then
        pass "Option accepted: $opt"
    else
        fail "Option failed: $opt"
    fi
done

# ============================================================================
# SECTION 7: FILE OPERATIONS SIMULATION
# ============================================================================
test_section "7. FILE OPERATIONS (DRY RUN)"

echo "Setting up test environment..."
TEST_DIR="/tmp/vmgr-comprehensive-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
touch "$TEST_DIR/test video file.mp4"
touch "$TEST_DIR/another-test.mkv"

echo "Testing rename operation (dry run)..."
if ./video-manager-ultimate.sh --dry-run rename "$TEST_DIR" 2>&1 | grep -q "Dry run\|test video file"; then
    pass "Rename operation dry run works"
else
    fail "Rename operation dry run failed"
fi

echo "Testing flatten operation (dry run)..."
mkdir -p "$TEST_DIR/subdir"
touch "$TEST_DIR/subdir/nested.mp4"
if ./video-manager-ultimate.sh --dry-run flatten "$TEST_DIR" 2>&1 | grep -q "Dry run\|nested"; then
    pass "Flatten operation dry run works"
else
    fail "Flatten operation dry run failed"
fi

echo "Cleaning up test environment..."
rm -rf "$TEST_DIR"
pass "Test cleanup successful"

# ============================================================================
# SECTION 8: ERROR HANDLING
# ============================================================================
test_section "8. ERROR HANDLING"

echo "Testing invalid command..."
if ./video-manager-ultimate.sh invalid-command 2>&1 | grep -qE "Unknown|Error|error"; then
    pass "Invalid command shows error"
else
    fail "Invalid command error handling failed"
fi

echo "Testing missing directory argument..."
if ./video-manager-ultimate.sh rename 2>&1 | grep -qE "No directory|Error|directory"; then
    pass "Missing directory shows error"
else
    fail "Missing directory error handling failed"
fi

echo "Testing invalid option..."
if ./video-manager-ultimate.sh --invalid-option 2>&1 | grep -qE "Unknown|error"; then
    pass "Invalid option shows error"
else
    fail "Invalid option error handling failed"
fi

# ============================================================================
# RESULTS SUMMARY
# ============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                          TEST RESULTS SUMMARY                          ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Total Tests:  $TEST_COUNT"
echo "Passed:       $PASS_COUNT ✅"
echo "Failed:       $FAIL_COUNT ❌"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "🎉 SUCCESS: All tests passed! 🎉"
    echo ""
    SUCCESS_RATE="100%"
else
    SUCCESS_RATE=$(echo "scale=1; $PASS_COUNT * 100 / $TEST_COUNT" | bc)
    echo "⚠️  Some tests failed. Success rate: ${SUCCESS_RATE}%"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Exit with appropriate code
if [[ $FAIL_COUNT -eq 0 ]]; then
    exit 0
else
    exit 1
fi
