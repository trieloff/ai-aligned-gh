#!/bin/bash

# Test script for `gh impersonate` subcommand
# Verifies add, list, remove, idempotent add, and format validation

set -e

# Colors for output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    BLUE=''
    CYAN=''
    NC=''
fi

print_test() {
    echo -e "${CYAN}[TEST]${NC} $*"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    FAILURES=$((FAILURES + 1))
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

FAILURES=0

echo ""
echo -e "${BLUE}=== gh impersonate Test Suite ===${NC}"
echo ""

# Use a temporary config dir so we don't modify the real one
HOME=$(mktemp -d)
export HOME
trap 'rm -rf "$HOME"' EXIT
IGNORE_FILE="$HOME/.config/ai-aligned-gh/ignorerepos"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# We invoke executable_gh directly with a fake GH_BIN so it doesn't need real gh
# But the impersonate subcommand doesn't need GH_BIN — it exits before using it.
GH_WRAPPER="$SCRIPT_DIR/executable_gh"

# Test 1: --list with empty list
print_test "List with no entries shows empty message"
output=$("$GH_WRAPPER" impersonate --list 2>&1)
if echo "$output" | grep -q "No repositories in impersonate list"; then
    print_pass "--list shows empty message"
else
    print_fail "--list did not show empty message. Got: $output"
fi

# Test 2: Add a repo
print_test "Add owner/repo to impersonate list"
output=$("$GH_WRAPPER" impersonate testowner/testrepo 2>&1)
if echo "$output" | grep -q "Added 'testowner/testrepo'"; then
    print_pass "Add prints confirmation"
else
    print_fail "Add did not print confirmation. Got: $output"
fi

# Verify file contents
if [ -f "$IGNORE_FILE" ] && grep -qxF "testowner/testrepo" "$IGNORE_FILE"; then
    print_pass "Entry written to ignorerepos file"
else
    print_fail "Entry not found in ignorerepos file"
fi

# Test 3: --list shows entries
print_test "List shows added entry"
output=$("$GH_WRAPPER" impersonate --list 2>&1)
if echo "$output" | grep -q "testowner/testrepo"; then
    print_pass "--list shows testowner/testrepo"
else
    print_fail "--list did not show entry. Got: $output"
fi

# Test 4: Duplicate add is idempotent
print_test "Duplicate add is idempotent"
output=$("$GH_WRAPPER" impersonate testowner/testrepo 2>&1)
if echo "$output" | grep -q "already in the impersonate list"; then
    print_pass "Duplicate add detected"
else
    print_fail "Duplicate add was not idempotent. Got: $output"
fi
# Verify no duplicate in file
count=$(grep -cxF "testowner/testrepo" "$IGNORE_FILE")
if [ "$count" -eq 1 ]; then
    print_pass "No duplicate line in file"
else
    print_fail "File has $count copies of the entry (expected 1)"
fi

# Test 5: Add an org wildcard
print_test "Add org wildcard"
output=$("$GH_WRAPPER" impersonate someorg/* 2>&1)
if echo "$output" | grep -q "Added 'someorg/\*'"; then
    print_pass "Org wildcard accepted"
else
    print_fail "Org wildcard not accepted. Got: $output"
fi

# Test 6: --remove removes entry
print_test "Remove entry from list"
output=$("$GH_WRAPPER" impersonate --remove testowner/testrepo 2>&1)
if echo "$output" | grep -q "Removed 'testowner/testrepo'"; then
    print_pass "Remove prints confirmation"
else
    print_fail "Remove did not print confirmation. Got: $output"
fi
# Verify entry is gone
if grep -qxF "testowner/testrepo" "$IGNORE_FILE" 2>/dev/null; then
    print_fail "Entry still in file after remove"
else
    print_pass "Entry removed from file"
fi
# Verify other entries survive
if grep -qxF "someorg/*" "$IGNORE_FILE" 2>/dev/null; then
    print_pass "Other entries preserved after remove"
else
    print_fail "Other entries lost after remove"
fi

# Test 7: Remove the last remaining entry
print_test "Remove last remaining entry leaves empty file"
output=$("$GH_WRAPPER" impersonate --remove "someorg/*" 2>&1)
if echo "$output" | grep -q "Removed 'someorg/\*'"; then
    print_pass "Last entry removal prints confirmation"
else
    print_fail "Last entry removal did not print confirmation. Got: $output"
fi
if [ ! -s "$IGNORE_FILE" ]; then
    print_pass "File is empty after removing last entry"
else
    print_fail "File still has content after removing last entry"
fi
# Verify list now shows empty
output=$("$GH_WRAPPER" impersonate --list 2>&1)
if echo "$output" | grep -q "No repositories in impersonate list"; then
    print_pass "--list shows empty after removing last entry"
else
    print_fail "--list did not show empty. Got: $output"
fi

# Re-add an entry for subsequent tests
"$GH_WRAPPER" impersonate someorg/* >/dev/null 2>&1

# Test 8: Remove non-existent entry fails
print_test "Remove non-existent entry fails"
output=$("$GH_WRAPPER" impersonate --remove nonexistent/repo 2>&1) && rc=$? || rc=$?
if [ "$rc" -ne 0 ] && echo "$output" | grep -q "is not in the impersonate list"; then
    print_pass "Remove of non-existent entry fails with message"
else
    print_fail "Expected failure for non-existent remove. rc=$rc, output: $output"
fi

# Test 8: Invalid format rejected
print_test "Invalid format rejected (no slash)"
output=$("$GH_WRAPPER" impersonate "badformat" 2>&1) && rc=$? || rc=$?
if [ "$rc" -ne 0 ] && echo "$output" | grep -q "Invalid format"; then
    print_pass "Format without slash rejected"
else
    print_fail "Expected rejection. rc=$rc, output: $output"
fi

print_test "Invalid format rejected (empty owner)"
output=$("$GH_WRAPPER" impersonate "/repo" 2>&1) && rc=$? || rc=$?
if [ "$rc" -ne 0 ] && echo "$output" | grep -q "Invalid format"; then
    print_pass "Empty owner rejected"
else
    print_fail "Expected rejection. rc=$rc, output: $output"
fi

print_test "Invalid format rejected (spaces)"
output=$("$GH_WRAPPER" impersonate "bad owner/repo" 2>&1) && rc=$? || rc=$?
if [ "$rc" -ne 0 ] && echo "$output" | grep -q "Invalid format"; then
    print_pass "Spaces rejected"
else
    print_fail "Expected rejection. rc=$rc, output: $output"
fi

# Test 9: No-args shows list (same as --list)
print_test "No args shows list"
output=$("$GH_WRAPPER" impersonate 2>&1)
if echo "$output" | grep -q "someorg/\*"; then
    print_pass "No args shows existing entries"
else
    print_fail "No args did not show entries. Got: $output"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAILURES test(s) failed!${NC}"
    exit 1
fi
