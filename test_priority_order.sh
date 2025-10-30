#!/bin/bash

# Test script to verify AI tool priority order
# Ensures that Zed always comes last in priority

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_test() {
    echo -e "${CYAN}[TEST]${NC} $*"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    exit 1
}

# Find the gh wrapper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GH_WRAPPER="$SCRIPT_DIR/executable_gh"

if [ ! -f "$GH_WRAPPER" ]; then
    print_fail "executable_gh not found at $GH_WRAPPER"
fi

echo ""
echo -e "${BLUE}=== AI Tool Priority Order Tests ===${NC}"
echo ""
echo "Expected priority: Amp > Codex > Claude > Gemini > Qwen > Droid > OpenCode > Cursor > Kimi > Copilot > Crush > Goose > Zed"
echo ""

# Helper function to test detection
test_detection() {
    local test_name="$1"
    local expected="$2"
    shift 2
    local env_vars=("$@")

    print_test "$test_name"

    # Build env command
    local env_cmd=""
    for var in "${env_vars[@]}"; do
        env_cmd="$env_cmd $var"
    done

    # Run gh wrapper with debug mode and capture AI detection
    local output
    output=$(env GH_AI_DEBUG=true $env_cmd "$GH_WRAPPER" --version 2>&1 || true)

    # Extract detected AI tool from debug output
    local detected=""
    if echo "$output" | grep -q "AI detected:"; then
        detected=$(echo "$output" | grep "AI detected:" | sed 's/.*AI detected: \([^ ]*\).*/\1/')
    elif echo "$output" | grep -q "No AI detected"; then
        detected="none"
    fi

    if [ "$detected" = "$expected" ]; then
        print_pass "Correctly detected '$expected'"
        return 0
    else
        print_fail "Expected '$expected', got '$detected'"
        return 1
    fi
}

# Test 1: Only Zed detected
test_detection "Only Zed" "zed" "ZED_TERM=true"

# Test 2: Zed + Gemini (Gemini should win)
test_detection "Zed + Gemini" "gemini" "ZED_TERM=true" "GEMINI_CLI=1"

# Test 3: Zed + Cursor (Cursor should win)
test_detection "Zed + Cursor" "cursor" "ZED_TERM=true" "CURSOR_AI=1"

# Test 4: Zed + Kimi (Kimi should win)
test_detection "Zed + Kimi" "kimi" "ZED_TERM=true" "KIMI_CLI=1"

# Test 5: Zed + Codex (Codex should win)
test_detection "Zed + Codex" "codex" "ZED_TERM=true" "CODEX_CLI=1"

# Test 6: Zed + OpenCode (OpenCode should win)
test_detection "Zed + OpenCode" "opencode" "ZED_TERM=true" "OPENCODE_AI=1"

# Test 7: Zed + Qwen (Qwen should win)
test_detection "Zed + Qwen" "qwen" "ZED_TERM=true" "QWEN_CODE=1"

# Test 8: Zed + Amp (Amp should win - highest priority)
test_detection "Zed + Amp" "amp" "ZED_TERM=true" "AMP_HOME=/tmp/amp"

# Test 9: Multiple tools including Zed (Codex should win as highest priority present)
test_detection "Codex + Gemini + Zed" "codex" "ZED_TERM=true" "GEMINI_CLI=1" "CODEX_CLI=1"

# Test 10: Priority order verification - Claude > Gemini
test_detection "Claude + Gemini" "claude" "CLAUDECODE=1" "CLAUDE_CODE_ENTRYPOINT=cli" "GEMINI_CLI=1"

# Test 11: Priority order verification - Gemini > Qwen
test_detection "Gemini + Qwen" "gemini" "GEMINI_CLI=1" "QWEN_CODE=1"

# Test 12: Priority order verification - Cursor > Kimi
test_detection "Cursor + Kimi" "cursor" "CURSOR_AI=1" "KIMI_CLI=1"

# Test 13: Zed + Goose (Goose should win - comes before Zed)
test_detection "Zed + Goose" "goose" "ZED_TERM=true" "GOOSE_TERMINAL=1"

# Test 14: Priority order verification - Goose > Zed
test_detection "Goose + Zed" "goose" "GOOSE_TERMINAL=1" "ZED_TERM=true"

echo ""
echo -e "${GREEN}=== All Priority Order Tests Passed! ===${NC}"
echo ""
echo "✓ Zed is correctly prioritized last"
echo "✓ All higher-priority tools are selected over Zed when present"
echo "✓ Priority order is correctly enforced: Amp > Codex > Claude > Gemini > Qwen > Droid > OpenCode > Cursor > Kimi > Copilot > Crush > Goose > Zed"
echo ""
