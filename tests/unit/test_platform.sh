#!/usr/bin/env bash
# Unit tests for lib/platform.sh:
#   format_bytes, calculate_file_hash, get_file_size_bytes, detect_os

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.sh"
load_vmgr_core

# ── detect_os ─────────────────────────────────────────────────────────────────

test_detect_os_sets_os_type() {
    detect_os
    assert_not_equals "" "$OS_TYPE" "detect_os: OS_TYPE is non-empty"
}

test_detect_os_valid_value() {
    detect_os
    local valid=false
    case "$OS_TYPE" in
        Linux|WSL|macOS|Windows|Unknown) valid=true ;;
    esac
    assert_equals "true" "$valid" "detect_os: OS_TYPE is a known value ($OS_TYPE)"
}

# ── format_bytes ──────────────────────────────────────────────────────────────

test_format_bytes_zero() {
    local result
    result=$(format_bytes 0)
    # Accepts "0B" or "0" depending on numfmt
    assert_contains "0" "$result" "format_bytes: 0 contains '0'"
}

test_format_bytes_small() {
    local result
    result=$(format_bytes 500)
    # Should be just bytes, no K/M/G
    assert_contains "B" "$result" "format_bytes: 500 bytes shown as B"
}

test_format_bytes_kilobytes() {
    local result
    result=$(format_bytes 2048)
    assert_contains "K" "$result" "format_bytes: 2048 → contains K"
}

test_format_bytes_megabytes() {
    local result
    result=$(format_bytes 2097152)
    assert_contains "M" "$result" "format_bytes: 2MiB → contains M"
}

test_format_bytes_gigabytes() {
    local result
    result=$(format_bytes 2147483648)
    assert_contains "G" "$result" "format_bytes: 2GiB → contains G"
}

test_format_bytes_empty_input() {
    local result
    result=$(format_bytes "")
    # Should return something (not crash), contains "0"
    assert_contains "0" "$result" "format_bytes: empty input → 0B"
}

test_format_bytes_non_numeric() {
    local result rc
    result=$(format_bytes "abc" 2>/dev/null)
    rc=$?
    # Should return non-zero and output something containing 0
    assert_not_equals "0" "$rc" "format_bytes: non-numeric → non-zero exit"
}

# ── calculate_file_hash ───────────────────────────────────────────────────────

test_hash_nonexistent_file_returns_nonzero() {
    assert_exits_nonzero "calculate_file_hash '/nonexistent/path/file.mp4'" \
        "calculate_file_hash: nonexistent file returns non-zero"
}

test_hash_empty_param_returns_nonzero() {
    assert_exits_nonzero "calculate_file_hash ''" \
        "calculate_file_hash: empty param returns non-zero"
}

test_hash_returns_64_char_hex() {
    local tmpfile
    tmpfile="$(mktemp)"
    echo "test content for hashing" > "$tmpfile"
    local result
    result=$(calculate_file_hash "$tmpfile")
    assert_matches "^[0-9a-f]{64}$" "$result" "calculate_file_hash: returns 64-char hex"
    rm -f "$tmpfile"
}

test_hash_same_content_same_hash() {
    local f1 f2
    f1="$(mktemp)"; f2="$(mktemp)"
    echo "identical content" > "$f1"
    echo "identical content" > "$f2"
    local h1 h2
    h1=$(calculate_file_hash "$f1")
    h2=$(calculate_file_hash "$f2")
    assert_equals "$h1" "$h2" "calculate_file_hash: identical content → same hash"
    rm -f "$f1" "$f2"
}

test_hash_different_content_different_hash() {
    local f1 f2
    f1="$(mktemp)"; f2="$(mktemp)"
    echo "content A" > "$f1"
    echo "content B" > "$f2"
    local h1 h2
    h1=$(calculate_file_hash "$f1")
    h2=$(calculate_file_hash "$f2")
    assert_not_equals "$h1" "$h2" "calculate_file_hash: different content → different hash"
    rm -f "$f1" "$f2"
}

test_hash_empty_file() {
    local tmpfile
    tmpfile="$(mktemp)"
    # Empty file should still produce a valid hash
    local result
    result=$(calculate_file_hash "$tmpfile")
    assert_matches "^[0-9a-f]{64}$" "$result" "calculate_file_hash: empty file → valid hash"
    rm -f "$tmpfile"
}

# ── get_file_size_bytes ───────────────────────────────────────────────────────

test_file_size_nonexistent() {
    local result
    result=$(get_file_size_bytes "/nonexistent/file")
    assert_equals "0" "$result" "get_file_size_bytes: nonexistent → 0"
}

test_file_size_known_content() {
    local tmpfile
    tmpfile="$(mktemp)"
    printf 'ABCDE' > "$tmpfile"   # exactly 5 bytes
    local result
    result=$(get_file_size_bytes "$tmpfile")
    assert_equals "5" "$result" "get_file_size_bytes: 5-byte file → 5"
    rm -f "$tmpfile"
}

test_file_size_empty_file() {
    local tmpfile
    tmpfile="$(mktemp)"
    # Empty file (0 bytes)
    local result
    result=$(get_file_size_bytes "$tmpfile")
    assert_equals "0" "$result" "get_file_size_bytes: empty file → 0"
    rm -f "$tmpfile"
}
