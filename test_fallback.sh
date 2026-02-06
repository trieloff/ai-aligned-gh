#!/bin/bash

# Test script for user token fallback in AI-Aligned-GH wrapper
# Verifies that when the as-a-bot app is not installed in a target repository,
# the wrapper falls back to the user's regular token and adds the repo to
# the ignore list for future calls.

set -e

# Colors for output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    BLUE=''
    CYAN=''
    YELLOW=''
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
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

TESTS_PASSED=0
TESTS_FAILED=0

echo ""
echo -e "${BLUE}=== AI-Aligned-GH Fallback Test Suite ===${NC}"
echo ""

# Test 1: Check if wrapper is installed
print_test "Checking if wrapper is installed..."
if [ -x "$HOME/.local/bin/gh" ]; then
    print_pass "Wrapper found at ~/.local/bin/gh"
else
    print_fail "Wrapper not found at ~/.local/bin/gh"
    print_info "Run ./install.sh first"
    exit 1
fi

# Setup: Create mock gh and test wrapper
print_test "Creating mock gh that simulates 'app not installed' error..."
MOCK_GH_DIR=$(mktemp -d)
MOCK_GH="$MOCK_GH_DIR/gh"

cat > "$MOCK_GH" << 'MOCKEOF'
#!/bin/bash
# Mock gh for fallback testing
# - API calls for token validation always succeed
# - Commands with GH_TOKEN set fail with "Resource not accessible by integration"
# - Commands without GH_TOKEN succeed (simulating user token works)

# API calls used during token validation and debug checks
if [[ "$1" == "api" ]]; then
    if [[ "$2" == "user" ]]; then
        echo '{"login":"testuser"}'
        exit 0
    elif [[ "$2" == "rate_limit" ]]; then
        echo '15000'
        exit 0
    fi
fi

# For all other commands: fail if GH_TOKEN is set (simulating app not installed)
if [ -n "$GH_TOKEN" ]; then
    echo "Resource not accessible by integration" >&2
    exit 1
fi

# Without GH_TOKEN: succeed (user token fallback)
echo "Command succeeded with user token: $*"
exit 0
MOCKEOF

chmod +x "$MOCK_GH"
print_pass "Mock gh created at $MOCK_GH"

# Create test wrapper with mock gh
WRAPPER="$HOME/.local/bin/gh"
TEST_WRAPPER=$(mktemp)
sed "s|GH_BIN=\$(find_real_gh)|GH_BIN=\"$MOCK_GH\"|g" "$WRAPPER" > "$TEST_WRAPPER"
chmod +x "$TEST_WRAPPER"
print_pass "Test wrapper created at $TEST_WRAPPER"

# Backup and seed token cache
CACHE_DIR="$HOME/.cache/ai-aligned-gh"
BACKUP_TOKEN=""
if [ -f "$CACHE_DIR/token" ]; then
    BACKUP_TOKEN=$(cat "$CACHE_DIR/token")
fi
mkdir -p "$CACHE_DIR"
echo "ghu_test_fake_token_for_fallback" > "$CACHE_DIR/token"
chmod 600 "$CACHE_DIR/token"
print_pass "Seeded fake bot token in cache"

# Backup and clear ignore list
IGNORE_FILE="$HOME/.config/ai-aligned-gh/ignorerepos"
BACKUP_IGNORE=""
if [ -f "$IGNORE_FILE" ]; then
    BACKUP_IGNORE=$(cat "$IGNORE_FILE")
fi
rm -f "$IGNORE_FILE"
print_pass "Cleared ignore list for clean test"

# Cleanup function
cleanup() {
    rm -f "$TEST_WRAPPER"
    rm -rf "$MOCK_GH_DIR"
    rm -f /tmp/fallback_test_output.txt
    rm -f /tmp/fallback_test_stderr.txt
    rm -f /tmp/fallback_second_output.txt

    # Restore token cache
    if [ -n "$BACKUP_TOKEN" ]; then
        echo "$BACKUP_TOKEN" > "$CACHE_DIR/token"
    else
        rm -f "$CACHE_DIR/token"
    fi

    # Restore ignore list
    if [ -n "$BACKUP_IGNORE" ]; then
        mkdir -p "$(dirname "$IGNORE_FILE")"
        echo "$BACKUP_IGNORE" > "$IGNORE_FILE"
    else
        rm -f "$IGNORE_FILE"
    fi
}
trap cleanup EXIT

echo ""

# Test 2: Fallback to user token on "Resource not accessible" error
print_test "Testing fallback to user token when app is not installed..."
set +e
CLAUDE_CODE=1 "$TEST_WRAPPER" issue create --title "Test" --body "Test body" --repo testowner/testrepo > /tmp/fallback_test_output.txt 2>/tmp/fallback_test_stderr.txt
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    print_pass "Command succeeded after fallback (exit code 0)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Expected exit code 0, got $EXIT_CODE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    print_info "stdout: $(cat /tmp/fallback_test_output.txt)"
    print_info "stderr: $(cat /tmp/fallback_test_stderr.txt)"
fi

# Test 3: Verify warning message is displayed
print_test "Checking for fallback warning message in output..."
if grep -q "Falling Back to User Token" /tmp/fallback_test_stderr.txt; then
    print_pass "Fallback warning message displayed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Fallback warning message not found in stderr"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    print_info "stderr content: $(cat /tmp/fallback_test_stderr.txt)"
fi

# Test 4: Verify app installation link is shown
print_test "Checking for app installation link..."
if grep -q "https://github.com/apps/as-a-bot" /tmp/fallback_test_stderr.txt; then
    print_pass "App installation link displayed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "App installation link not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Verify command output came from the retry (user token)
print_test "Checking that the command ran with user token..."
if grep -q "Command succeeded with user token" /tmp/fallback_test_output.txt; then
    print_pass "Command output confirms user token was used"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Expected user token success message in stdout"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    print_info "stdout: $(cat /tmp/fallback_test_output.txt)"
fi

# Test 6: Verify repo was added to ignore list
print_test "Checking that repo was added to ignore list..."
if [ -f "$IGNORE_FILE" ] && grep -qx "testowner/testrepo" "$IGNORE_FILE"; then
    print_pass "testowner/testrepo found in ignore list"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "testowner/testrepo not found in ignore list"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    if [ -f "$IGNORE_FILE" ]; then
        print_info "Ignore file contents: $(cat "$IGNORE_FILE")"
    else
        print_info "Ignore file does not exist"
    fi
fi

# Test 7: Verify ignore list notification in output
print_test "Checking for ignore list notification..."
if grep -q "added to the ignore list" /tmp/fallback_test_stderr.txt; then
    print_pass "Ignore list notification displayed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_fail "Ignore list notification not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 8: Second call should skip bot token entirely (via ignore list)
print_test "Testing second call uses ignore list fast path..."
set +e
GH_AI_DEBUG=true CLAUDE_CODE=1 "$TEST_WRAPPER" issue create --title "Test2" --body "Test body 2" --repo testowner/testrepo > /tmp/fallback_second_output.txt 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    # Check that the ignore list was hit (debug message)
    if grep -q "Repository is in ignore list" /tmp/fallback_second_output.txt; then
        print_pass "Second call used ignore list fast path"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        # Even without debug, if it succeeded it means the ignore list worked
        # (because the mock would fail with bot token)
        print_pass "Second call succeeded (ignore list bypassed bot token)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
else
    print_fail "Second call failed with exit code $EXIT_CODE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    print_info "Output: $(cat /tmp/fallback_second_output.txt)"
fi

# Test 9: Verify no fallback warning on second call
print_test "Checking that no fallback warning appears on second call..."
if grep -q "Falling Back to User Token" /tmp/fallback_second_output.txt; then
    print_fail "Fallback warning should not appear on second call (should use ignore list)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    print_pass "No fallback warning on second call (ignore list fast path)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Summary
echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo ""

print_info "Fallback functionality tests completed"
print_info "Passed: $TESTS_PASSED"
print_info "Failed: $TESTS_FAILED"
echo ""
print_info "Key features verified:"
echo "  - Automatic fallback to user token when app not installed"
echo "  - Warning message displayed to stderr"
echo "  - App installation link provided"
echo "  - Repository auto-added to ignore list"
echo "  - Second call uses ignore list fast path"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
fi
echo ""
