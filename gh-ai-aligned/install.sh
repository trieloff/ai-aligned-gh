#!/bin/bash

# gh-ai-aligned Installation Script
# Installs the gh-ai-aligned extension for GitHub CLI

set -e

# Colors for output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Function to print colored output
print_color() {
    printf "%s%s%s\n" "$1" "$2" "$NC"
}

# Installation directory for gh extensions
GH_EXT_DIR="${HOME}/.local/share/gh/extensions"

# Extension name (directory name determines command: "gh ai")
EXT_NAME="gh-ai"
EXT_DIR="${GH_EXT_DIR}/${EXT_NAME}"

print_color "$BLUE" "Installing gh-ai-aligned extension..."
echo ""

# Check if gh CLI is installed
if ! command -v gh > /dev/null 2>&1; then
    print_color "$RED" "Error: GitHub CLI (gh) is not installed."
    echo "Please install GitHub CLI first:"
    echo "  https://cli.github.com/"
    exit 1
fi

# Create extensions directory if it doesn't exist
mkdir -p "$GH_EXT_DIR"

# Check if extension already exists
if [ -d "$EXT_DIR" ]; then
    print_color "$YELLOW" "Extension already exists. Upgrading..."
    rm -rf "$EXT_DIR"
fi

# Create extension directory
mkdir -p "$EXT_DIR"

# Copy the extension script
if [ -f "gh-ai" ]; then
    # Local installation
    cp gh-ai "$EXT_DIR/gh-ai"
    chmod +x "$EXT_DIR/gh-ai"
    print_color "$GREEN" "✓ Extension script copied"
else
    # Remote installation via curl
    print_color "$BLUE" "Downloading extension from GitHub..."
    curl -fsSL "https://raw.githubusercontent.com/trieloff/gh-ai-aligned/main/gh-ai" -o "$EXT_DIR/gh-ai"
    chmod +x "$EXT_DIR/gh-ai"
    print_color "$GREEN" "✓ Extension script downloaded"
fi

# Extension is ready (gh-ai script in place)

# Verify installation
if gh extension list 2>/dev/null | grep -q "$EXT_NAME"; then
    print_color "$GREEN" "✓ Extension registered with gh CLI"
else
    # Manually register the extension if needed
    gh extension install "$EXT_DIR" 2>/dev/null || true
fi

echo ""
print_color "$GREEN" "🎉 Installation complete!"
echo ""
echo "The gh-ai-aligned extension has been installed."
echo ""
echo "Usage:"
echo "  gh ai <command>     - Use gh with AI attribution when AI is detected"
echo "  gh ai --help        - Show help for the extension"
echo ""
echo "To enable automatic AI detection and attribution, you can:"
echo "1. Use 'gh ai' instead of 'gh' for all commands"
echo "2. Set up an alias: alias gh='gh ai'"
echo "3. Create a wrapper script in your PATH"
echo ""
echo "For the as-a-bot service to work, ensure the GitHub App is installed:"
echo "  https://github.com/apps/as-a-bot-app"
echo ""
print_color "$BLUE" "To test if AI detection is working:"
echo "  GH_AI_DEBUG=true gh ai auth status"
echo ""