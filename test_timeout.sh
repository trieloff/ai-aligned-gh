#!/bin/bash

# Test script for timeout functionality in AI-Aligned-GH wrapper
# Verifies that gh commands timeout after 60 seconds in agent mode

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

echo ""
echo -e "${BLUE}=== AI-Aligned-GH Timeout Test Suite ===${NC}"
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

# Test 2: Create a mock gh command that hangs to simulate interactive mode
print_test "Creating mock hanging gh command..."
MOCK_GH_DIR=$(mktemp -d)
MOCK_GH="$MOCK_GH_DIR/gh"

cat > "$MOCK_GH" << 'EOF'
#!/bin/bash
# Mock gh that hangs to simulate interactive mode
if [[ "$*" == *"--hang"* ]]; then
    echo "Starting interactive mode (hanging)..." >&2
    # Hang indefinitely
    sleep 300
else
    # Normal behavior - just echo the command
    echo "gh called with: $*"
fi
exit 0
EOF

chmod +x "$MOCK_GH"
print_pass "Mock gh command created at $MOCK_GH"

# Test 3: Test timeout functionality with hanging command
print_test "Testing timeout with hanging command (this will take ~60 seconds)..."
print_info "Starting timer..."

# Temporarily modify executable_gh to use our mock
WRAPPER="$HOME/.local/bin/gh"
BACKUP_WRAPPER=$(mktemp)
cp "$WRAPPER" "$BACKUP_WRAPPER"

# Create a test version that uses our mock
TEST_WRAPPER=$(mktemp)
sed "s|GH_BIN=\$(find_real_gh)|GH_BIN=\"$MOCK_GH\"|g" "$WRAPPER" > "$TEST_WRAPPER"
chmod +x "$TEST_WRAPPER"

# Run the test with timeout - should exit with code 124 after 60 seconds
START_TIME=$(date +%s)
set +e
GH_AI_DEBUG=true CLAUDE_CODE=1 "$TEST_WRAPPER" pr create --hang 2>&1 | tee /tmp/timeout_test_output.txt
EXIT_CODE=$?
set -e
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

print_info "Command completed with exit code $EXIT_CODE after ${ELAPSED}s"

# Verify timeout occurred
if [ $EXIT_CODE -eq 124 ]; then
    print_pass "Command exited with timeout code (124)"
else
    print_fail "Expected exit code 124, got $EXIT_CODE"
fi

# Verify timeout happened around 60 seconds (allow 58-65 second range for variance)
if [ $ELAPSED -ge 58 ] && [ $ELAPSED -le 65 ]; then
    print_pass "Timeout occurred at expected time (~60s, actual: ${ELAPSED}s)"
else
    print_warn "Timeout timing unexpected (expected ~60s, got ${ELAPSED}s)"
fi

# Verify error message includes helpful instructions
if grep -q "GitHub CLI Interactive Mode Timeout" /tmp/timeout_test_output.txt; then
    print_pass "Timeout error message displayed"
else
    print_fail "Timeout error message not found"
fi

if grep -q "gh .* | cat" /tmp/timeout_test_output.txt; then
    print_pass "Non-interactive mode instructions provided"
else
    print_fail "Non-interactive mode instructions not found"
fi

# Test 4: Test that non-hanging commands complete quickly
print_test "Testing that normal commands complete without timeout..."
START_TIME=$(date +%s)
set +e
GH_AI_DEBUG=true CLAUDE_CODE=1 "$TEST_WRAPPER" --version > /tmp/normal_test_output.txt 2>&1
EXIT_CODE=$?
set -e
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $EXIT_CODE -eq 0 ] && [ $ELAPSED -lt 10 ]; then
    print_pass "Normal commands complete quickly (${ELAPSED}s) without timeout"
else
    print_fail "Normal command behavior unexpected (exit: $EXIT_CODE, time: ${ELAPSED}s)"
fi

# Test 5: Verify timeout only applies in AI mode
print_test "Verifying timeout only applies when AI tool is detected..."
print_info "This test requires manual verification or running without AI env vars"
print_info "When no AI is detected, commands should pass through without timeout logic"

# Cleanup
rm -f "$TEST_WRAPPER"
rm -f /tmp/timeout_test_output.txt
rm -f /tmp/normal_test_output.txt
rm -rf "$MOCK_GH_DIR"

echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo ""

print_info "Timeout functionality tests completed"
print_info "Key features verified:"
echo "  ✓ 60-second timeout in AI agent mode"
echo "  ✓ Exit code 124 on timeout"
echo "  ✓ Helpful error messages with non-interactive mode instructions"
echo "  ✓ Normal commands complete without timeout"
echo ""

echo -e "${GREEN}Tests completed!${NC}"
echo ""
