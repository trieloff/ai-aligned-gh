#!/bin/bash

# Test script for AI-Aligned-GH wrapper
# Verifies installation and functionality

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
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

echo ""
echo -e "${BLUE}=== AI-Aligned-GH Test Suite ===${NC}"
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

# Test 2: Check if wrapper is in PATH
print_test "Checking if wrapper is in PATH..."
export PATH="$HOME/.local/bin:$PATH"
FIRST_GH=$(which gh 2>/dev/null)
if [ "$FIRST_GH" = "$HOME/.local/bin/gh" ]; then
    print_pass "Wrapper is first in PATH"
else
    print_fail "Wrapper is not first in PATH (found: $FIRST_GH)"
    print_info "Add ~/.local/bin to the beginning of your PATH"
fi

# Test 3: Check prerequisites
print_test "Checking prerequisites..."
if command -v jq >/dev/null 2>&1; then
    print_pass "jq is installed"
else
    print_fail "jq is not installed (recommended for token parsing)"
fi

if command -v git >/dev/null 2>&1; then
    print_pass "git is installed"
else
    print_fail "git is not installed (needed for repo detection)"
fi

# Test 4: Test AI detection
print_test "Testing AI detection..."
for tool in CLAUDE_CODE CURSOR_AI GEMINI_CLI QWEN_CODE ZED_AI OPENCODE_AI CODEX_CLI KIMI_CLI AUGMENT_API_TOKEN; do
    if [ "$tool" = "AUGMENT_API_TOKEN" ]; then
        tool_name="auggie"
    else
        tool_name=$(echo "$tool" | cut -d'_' -f1 | tr '[:upper:]' '[:lower:]')
    fi

    # Run with debug to check detection
    OUTPUT=$(env GH_AI_DEBUG=true "$tool=1" gh --version 2>&1)

    if echo "$OUTPUT" | grep -qi "detected.*$tool_name"; then
        print_pass "  ✓ $tool_name detection works"
    else
        print_fail "  ✗ $tool_name detection failed"
    fi
done

# Test 5: Test passthrough without AI
print_test "Testing passthrough when no AI detected..."
OUTPUT=$(GH_AI_DEBUG=true gh --version 2>&1)
if echo "$OUTPUT" | grep -q "No AI detected"; then
    print_pass "Correctly passes through when no AI detected"
else
    # We might actually be running under an AI
    if echo "$OUTPUT" | grep -q "AI detected"; then
        print_info "Currently running under AI, cannot test passthrough"
    else
        print_fail "Unexpected behavior"
    fi
fi

# Test 6: Test read-only operation detection
print_test "Testing read-only operation detection..."
OUTPUT=$(GH_AI_DEBUG=true CLAUDE_CODE=1 gh auth status 2>&1 || true)
if echo "$OUTPUT" | grep -q "Read-only operation, skipping token exchange"; then
    print_pass "Read-only operations correctly skip token exchange"
else
    print_info "Read-only detection may vary based on operation"
fi

# Test 7: Check repository detection (if in a git repo)
print_test "Testing repository detection..."
if [ -d .git ]; then
    OUTPUT=$(GH_AI_DEBUG=true gh auth status 2>&1 || true)
    if echo "$OUTPUT" | grep -q "Found origin URL"; then
        print_pass "Repository detection works"
    else
        print_info "No remote origin configured"
    fi
else
    print_info "Not in a git repository, skipping repo detection test"
fi

echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo ""

print_info "Basic functionality tests completed"
print_info "To test token exchange with a real repository:"
echo "  1. Install the as-a-bot app: https://github.com/apps/as-a-bot"
echo "  2. Navigate to a GitHub repository with the app installed"
echo "  3. Run: GH_AI_DEBUG=true CLAUDE_CODE=1 gh pr create --dry-run"
echo ""

echo -e "${GREEN}Tests completed!${NC}"
echo ""
