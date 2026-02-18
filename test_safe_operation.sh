#!/bin/bash

# Test is_safe_operation() from executable_gh

# Extract the functions we need
eval "$(sed -n '/^debug_log()/,/^}/p' executable_gh)"
eval "$(sed -n '/^is_safe_operation()/,/^}/p' executable_gh)"

PASS=0
FAIL=0

assert_safe() {
    local description="$1"
    shift
    if is_safe_operation "$@"; then
        echo "PASS: $description (safe)"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $description — expected safe (0), got unsafe (1)"
        FAIL=$((FAIL + 1))
    fi
}

assert_unsafe() {
    local description="$1"
    shift
    if is_safe_operation "$@"; then
        echo "FAIL: $description — expected unsafe (1), got safe (0)"
        FAIL=$((FAIL + 1))
    else
        echo "PASS: $description (unsafe)"
        PASS=$((PASS + 1))
    fi
}

echo "=== is_safe_operation() tests ==="

# --- Existing safe commands (sanity checks) ---
echo ""
echo "--- Safe commands ---"
assert_safe  "help"                help
assert_safe  "repo view"           repo view
assert_safe  "pr list"             pr list
assert_safe  "issue view"          issue view
assert_safe  "search prs"          search prs
assert_safe  "status"              status
assert_safe  "extension list"      extension list

# --- Existing unsafe commands (sanity checks) ---
echo ""
echo "--- Unsafe commands ---"
assert_unsafe "pr create"          pr create
assert_unsafe "issue create"       issue create
assert_unsafe "repo delete"        repo delete

# --- API method detection (core of PR #47) ---
echo ""
echo "--- API: default GET is safe ---"
assert_safe  "api repos/owner/repo"                          api repos/owner/repo
assert_safe  "api --method GET repos/owner/repo"              api --method GET repos/owner/repo

echo ""
echo "--- API: explicit non-GET methods are unsafe ---"
assert_unsafe "api --method POST repos/owner/repo"            api --method POST repos/owner/repo
assert_unsafe "api --method=POST repos/owner/repo"            api --method=POST repos/owner/repo
assert_unsafe "api --method=post repos/owner/repo"            api --method=post repos/owner/repo
assert_unsafe "api -X POST repos/owner/repo"                  api -X POST repos/owner/repo
assert_unsafe "api -X=POST repos/owner/repo"                  api -X=POST repos/owner/repo
assert_unsafe "api -X PUT repos/owner/repo"                   api -X PUT repos/owner/repo
assert_unsafe "api -X PATCH repos/owner/repo"                 api -X PATCH repos/owner/repo
assert_unsafe "api -X DELETE repos/owner/repo"                api -X DELETE repos/owner/repo

echo ""
echo "--- API: graphql endpoint defaults to POST ---"
assert_unsafe "api graphql"                                   api graphql

echo ""
echo "--- API: body flags imply POST ---"
assert_unsafe "api -f key=val repos/owner/repo"               api -f key=val repos/owner/repo
assert_unsafe "api -F key=val repos/owner/repo"               api -F key=val repos/owner/repo
assert_unsafe "api --field key=val repos/owner/repo"           api --field key=val repos/owner/repo
assert_unsafe "api --raw-field key=val repos/owner/repo"       api --raw-field key=val repos/owner/repo
assert_unsafe "api --input file.json repos/owner/repo"         api --input file.json repos/owner/repo

echo ""
echo "--- API: explicit GET overrides body flags ---"
assert_safe  "api --method GET -f key=val repos/owner/repo"   api --method GET -f key=val repos/owner/repo

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0

