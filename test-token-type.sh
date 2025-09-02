#!/bin/bash

# Test script to verify token type
# User-to-server tokens have 15000 rate limit
# OAuth tokens have 5000 rate limit

TOKEN_FILE="$HOME/.cache/ai-aligned-gh/token"

if [ ! -f "$TOKEN_FILE" ]; then
    echo "No cached token found at $TOKEN_FILE"
    exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")

echo "Testing token type..."
echo ""

# Check rate limit
RATE_LIMIT=$(curl -sS -H "Authorization: Bearer $TOKEN" \
    https://api.github.com/rate_limit | jq -r '.rate.limit')

echo "Rate limit: $RATE_LIMIT"

if [ "$RATE_LIMIT" = "15000" ]; then
    echo "✅ This is a user-to-server token (GitHub App user token)"
    echo "   Actions will show app badge attribution"
elif [ "$RATE_LIMIT" = "5000" ]; then
    echo "❌ This is a regular OAuth token"
    echo "   Actions will NOT show app badge attribution"
else
    echo "⚠️  Unexpected rate limit: $RATE_LIMIT"
fi

echo ""
echo "Checking OAuth scopes..."
SCOPES=$(curl -sS -I -H "Authorization: Bearer $TOKEN" \
    https://api.github.com/user 2>&1 | grep -i "x-oauth-scopes:" | cut -d: -f2- | xargs)

if [ -z "$SCOPES" ]; then
    echo "No OAuth scopes (likely a user-to-server token)"
else
    echo "OAuth scopes: $SCOPES"
fi