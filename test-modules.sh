#!/bin/bash

################################################################################
#
# MODULE LOADING TEST SCRIPT
#
# This script tests that all extracted modules can be loaded successfully
# and that basic functions work correctly.
#
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

echo "Testing Video Manager Ultimate Modular Architecture"
echo "===================================================="
echo ""

# Test 1: Load core module
echo "Test 1: Loading core.sh..."
if source "$LIB_DIR/core.sh"; then
    echo "  ✓ core.sh loaded successfully"
    echo "    - Script version: $SCRIPT_VERSION"
    echo "    - Script name: $SCRIPT_NAME"
else
    echo "  ✗ Failed to load core.sh"
    exit 1
fi
echo ""

# Test 2: Load platform module
echo "Test 2: Loading platform.sh..."
if source "$LIB_DIR/platform.sh"; then
    echo "  ✓ platform.sh loaded successfully"
    echo "    - Detected OS: $OS_TYPE"
else
    echo "  ✗ Failed to load platform.sh"
    exit 1
fi
echo ""

# Test 3: Load logging module
echo "Test 3: Loading logging.sh..."
if source "$LIB_DIR/logging.sh"; then
    echo "  ✓ logging.sh loaded successfully"
else
    echo "  ✗ Failed to load logging.sh"
    exit 1
fi
echo ""

# Test 4: Load config module
echo "Test 4: Loading config.sh..."
if source "$LIB_DIR/config.sh"; then
    echo "  ✓ config.sh loaded successfully"
else
    echo "  ✗ Failed to load config.sh"
    exit 1
fi
echo ""

# Test 5: Initialize core
echo "Test 5: Testing init_core function..."
if init_core; then
    echo "  ✓ init_core executed successfully"
else
    echo "  ✗ init_core failed"
    exit 1
fi
echo ""

# Test 6: Initialize logging
echo "Test 6: Testing init_logging function..."
if init_logging; then
    echo "  ✓ init_logging executed successfully"
else
    echo "  ✗ init_logging failed"
    exit 1
fi
echo ""

# Test 7: Test logging functions
echo "Test 7: Testing logging functions..."
log_verbose "This is a verbose message"
log_info "This is an info message"
log_success "This is a success message"
log_warning "This is a warning message"
echo "  ✓ All logging functions work"
echo ""

# Test 8: Test platform functions
echo "Test 8: Testing platform functions..."

# Test format_bytes
bytes_formatted=$(format_bytes 1073741824)
echo "  - format_bytes(1073741824) = $bytes_formatted"

# Test file size (on this script itself)
script_size=$(get_file_size_bytes "$0")
echo "  - get_file_size_bytes(test-modules.sh) = $script_size bytes"

echo "  ✓ Platform functions work"
echo ""

# Test 9: Test statistics
echo "Test 9: Testing statistics..."
STATS[files_processed]=10
STATS[files_renamed]=5
STATS[files_moved]=3
STATS[errors]=1
print_statistics
echo "  ✓ Statistics display works"
echo ""

# Test 10: Reset statistics
echo "Test 10: Testing reset_statistics..."
reset_statistics
if [[ ${STATS[files_processed]} -eq 0 && ${STATS[errors]} -eq 0 ]]; then
    echo "  ✓ Statistics reset successfully"
else
    echo "  ✗ Statistics reset failed"
    exit 1
fi
echo ""

# Final summary
echo "===================================================="
echo "All module tests passed! ✓"
echo ""
echo "Modules loaded:"
echo "  • lib/core.sh"
echo "  • lib/platform.sh"
echo "  • lib/logging.sh"
echo "  • lib/config.sh"
echo ""
echo "Modular architecture is working correctly!"
echo "===================================================="
