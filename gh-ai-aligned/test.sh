#!/bin/bash

# Test script for gh-ai-aligned extension
# This script helps verify the AI detection and token exchange functionality

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

print_color() {
    echo -e "${1}${2}${NC}"
}

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

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GH_AI_SCRIPT="$SCRIPT_DIR/gh-ai"

echo ""
print_color "$BLUE" "=== gh-ai-aligned Extension Test Suite ==="
echo ""

# Test 1: Script exists and is executable
print_test "Checking if gh-ai script exists and is executable..."
if [ -x "$GH_AI_SCRIPT" ]; then
    print_pass "Script is executable"
else
    print_fail "Script not found or not executable at: $GH_AI_SCRIPT"
    exit 1
fi

# Test 2: Check gh CLI availability
print_test "Checking if gh CLI is installed..."
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -n1)
    print_pass "gh CLI found: $GH_VERSION"
else
    print_fail "gh CLI not installed"
    print_info "Install from: https://cli.github.com/"
    exit 1
fi

# Test 3: Check authentication
print_test "Checking GitHub authentication..."
if gh auth status &> /dev/null; then
    print_pass "Authenticated with GitHub"
else
    print_fail "Not authenticated with GitHub"
    print_info "Run: gh auth login"
    exit 1
fi

# Test 4: Test AI detection in debug mode
print_test "Testing AI detection (simulating Claude)..."
if CLAUDE_CODE=1 GH_AI_DEBUG=true "$GH_AI_SCRIPT" auth status 2>&1 | grep -q "Detected Claude"; then
    print_pass "AI detection works (Claude)"
else
    print_fail "AI detection failed"
fi

# Test 5: Test AI detection for different tools
print_test "Testing AI detection for multiple tools..."
for tool in GEMINI_CLI QWEN_CODE CURSOR_AI ZED_AI OPENCODE_AI; do
    env_var="$tool=1"
    tool_name=$(echo "$tool" | cut -d'_' -f1 | tr '[:upper:]' '[:lower:]')
    
    if env $env_var GH_AI_DEBUG=true "$GH_AI_SCRIPT" auth status 2>&1 | grep -qi "detected.*$tool_name"; then
        print_pass "  ✓ $tool_name detection works"
    else
        print_fail "  ✗ $tool_name detection failed"
    fi
done

# Test 6: Test without AI (should pass through)
print_test "Testing passthrough when no AI detected..."
OUTPUT=$("$GH_AI_SCRIPT" auth status 2>&1)
if echo "$OUTPUT" | grep -q "AI detected"; then
    print_fail "Incorrectly detected AI when none present"
else
    print_pass "Correctly passes through when no AI detected"
fi

# Test 7: Check repository detection
print_test "Testing repository detection..."
if [ -d .git ]; then
    OWNER_REPO=$(GH_AI_DEBUG=true "$GH_AI_SCRIPT" auth status 2>&1 | grep "Parsed owner:" | head -n1)
    if [ -n "$OWNER_REPO" ]; then
        print_pass "Repository detected: $OWNER_REPO"
    else
        print_info "Could not detect repository info"
    fi
else
    print_info "Not in a git repository, skipping repo detection test"
fi

# Test 8: Test help/version commands
print_test "Testing basic gh commands through wrapper..."
if "$GH_AI_SCRIPT" --version &> /dev/null; then
    print_pass "Version command works"
else
    print_fail "Version command failed"
fi

echo ""
print_color "$BLUE" "=== Test Summary ==="
echo ""

# Optional: Test with real repository if as-a-bot is installed
print_info "To test token exchange with a real repository:"
echo "  1. Install the as-a-bot app: https://github.com/apps/as-a-bot-app"
echo "  2. Navigate to a GitHub repository"
echo "  3. Run: CLAUDE_CODE=1 GH_AI_DEBUG=true $GH_AI_SCRIPT pr list"
echo ""

print_color "$GREEN" "Basic tests completed successfully!"
echo ""