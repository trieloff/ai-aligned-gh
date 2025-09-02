# 🤖 AI-Aligned-GH: The Transparent GitHub CLI Wrapper for AI Attribution

A transparent wrapper for the GitHub CLI (`gh`) that automatically detects when it's being invoked by an AI tool and ensures all actions are properly attributed to a bot acting on behalf of the user, rather than appearing to come directly from the user.

## 🎯 The Problem

When AI coding assistants (Claude, Cursor, Gemini, etc.) use the GitHub CLI to perform actions like creating PRs, issues, or comments, those actions appear to come directly from you. This creates:

- **Attribution confusion**: Was this action taken by you or your AI assistant?
- **Audit trail issues**: No clear record of AI involvement in repository changes
- **Trust concerns**: Other developers can't distinguish between human and AI actions

## 💡 The Solution

AI-Aligned-GH is a transparent wrapper that:

1. **Intercepts all `gh` calls** without requiring any changes to how AI tools work
2. **Detects AI usage** through process tree analysis and environment variables
3. **Exchanges tokens** via the [as-a-bot](https://github.com/trieloff/as-a-bot) service
4. **Ensures proper attribution** so AI actions show as "as-a-bot[bot] on behalf of @username"

## 🚀 Quick Install

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/yourusername/ai-aligned-gh/main/install.sh | sh

# Add to PATH (if needed)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 🔧 How It Works

### The Wrapper Pattern

Unlike a GitHub CLI extension (which would require AI tools to consciously call `gh ai` instead of `gh`), this is a **transparent wrapper** that intercepts all `gh` calls:

```
AI Tool → gh (wrapper) → Detection → Token Exchange → gh (real) → GitHub API
                ↓                           ↓
           Our wrapper              as-a-bot service
```

### Installation Location

The wrapper installs itself as `gh` in `~/.local/bin`, which must come **before** the real `gh` in your PATH:

```bash
$ which -a gh
/home/user/.local/bin/gh    # Our wrapper (first in PATH)
/usr/bin/gh                  # Real gh CLI
```

### AI Detection

The wrapper detects AI tools through:

1. **Environment variables**: `CLAUDE_CODE`, `CURSOR_AI`, `GEMINI_CLI`, etc.
2. **Process tree analysis**: Walks up parent processes looking for AI tool signatures
3. **Process name matching**: Identifies `claude`, `cursor`, `gemini`, etc. in process names

### Token Exchange Flow

When an AI is detected and performing a write operation:

1. Wrapper gets the current repository from `git config`
2. Checks if the as-a-bot GitHub App is installed
3. Exchanges user token for bot token via the as-a-bot service
4. Executes `gh` with the bot token

Read-only operations (like `gh pr list`) skip token exchange for performance.

## 📋 Prerequisites

1. **GitHub CLI**: Install from [cli.github.com](https://cli.github.com/)
2. **GitHub App**: Install [as-a-bot-app](https://github.com/apps/as-a-bot-app) on your repositories
3. **Authentication**: Be authenticated with `gh auth login`
4. **jq** (recommended): For JSON parsing during token exchange

## 🎮 Usage

Once installed, the wrapper works **completely transparently**. AI tools continue to call `gh` normally:

```bash
# AI tools just use gh as usual
gh pr create --title "Add new feature" --body "..."
gh issue comment 123 --body "Fixed in latest commit"

# The wrapper automatically handles attribution when AI is detected
```

### Debug Mode

See what's happening under the hood:

```bash
GH_AI_DEBUG=true gh pr list
```

Output:
```
[DEBUG] Starting AI detection from PID 12345
[DEBUG] Detected Claude in process tree
[INFO] AI detected: claude - checking for bot token exchange...
[DEBUG] Found origin URL: https://github.com/user/repo.git
[DEBUG] Parsed owner: user, repo: repo
[INFO] Successfully exchanged token - actions will be attributed to bot
```

### Testing AI Detection

Force AI detection for testing:

```bash
# Simulate different AI environments
CLAUDE_CODE=1 gh issue list
CURSOR_AI=1 gh pr view 123
GEMINI_CLI=1 gh repo clone user/repo
```

## 🤖 Supported AI Tools

The wrapper automatically detects:

| AI Tool | Detection Method | Environment Variable |
|---------|------------------|---------------------|
| Claude (Anthropic) | Process name + env | `CLAUDE_CODE`, `ANTHROPIC_SHELL` |
| Cursor | Process name + env | `CURSOR_AI` |
| Gemini (Google) | Process name + env | `GEMINI_CLI` |
| Qwen Code (Alibaba) | Process name + env | `QWEN_CODE` |
| Zed AI | Process name + env | `ZED_AI` |
| OpenCode | Process name + env | `OPENCODE_AI` |

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GH_AI_DEBUG` | Enable debug output | `false` |
| `AS_A_BOT_URL` | as-a-bot service URL | `https://as-bot-worker.minivelos.workers.dev` |
| `GH_TOKEN` | GitHub token override | (uses `gh auth token`) |

### PATH Configuration

The wrapper **must** be found before the real `gh` in your PATH:

```bash
# Check PATH order
echo $PATH | tr ':' '\n'

# Verify wrapper is first
which -a gh
```

## 🔒 Security

- **No token storage**: Tokens are exchanged on-demand, never stored
- **Preserves permissions**: Bot tokens have the same permissions as user tokens
- **Transparent operation**: All actions are logged and auditable
- **Fails safely**: If token exchange fails, falls back to normal operation

## 📝 Example Scenarios

### Scenario 1: AI Creates a Pull Request

Without AI-Aligned-GH:
```
trieloff opened pull request #123
```

With AI-Aligned-GH:
```
as-a-bot[bot] opened pull request #123 on behalf of @trieloff
```

### Scenario 2: AI Comments on an Issue

Without AI-Aligned-GH:
```
@trieloff commented: "This has been fixed in the latest commit"
```

With AI-Aligned-GH:
```
as-a-bot[bot] commented on behalf of @trieloff: "This has been fixed in the latest commit"
```

## 🚧 Troubleshooting

### Wrapper Not Being Called

```bash
# Check if wrapper is installed
ls -la ~/.local/bin/gh

# Check PATH order
which -a gh

# Ensure ~/.local/bin is first in PATH
export PATH="$HOME/.local/bin:$PATH"
```

### App Not Installed

If you see warnings about the app not being installed:

1. Visit https://github.com/apps/as-a-bot-app
2. Click "Install" or "Configure"
3. Select the repositories where you want AI attribution
4. Save the configuration

### Token Exchange Fails

```bash
# Check authentication
gh auth status

# Test token exchange manually
GH_AI_DEBUG=true CLAUDE_CODE=1 gh pr list
```

### AI Not Detected

```bash
# Check process tree
ps -ef | grep -E "claude|cursor|gemini"

# Force detection with environment variable
CLAUDE_CODE=1 gh issue list
```

## 🤝 Contributing

To add support for a new AI tool:

1. Add detection logic to the `detect_ai_tool` function in `executable_gh`
2. Add environment variable check (e.g., `NEW_AI_TOOL`)
3. Add process name pattern matching
4. Test with `GH_AI_DEBUG=true`
5. Submit a pull request

## 📜 License

Apache 2.0 - See LICENSE file for details

## 🔗 Related Projects

- [ai-aligned-git](https://github.com/trieloff/ai-aligned-git) - The inspiration for this project, a git wrapper with the same philosophy
- [as-a-bot](https://github.com/trieloff/as-a-bot) - The GitHub App token broker service that makes this possible
- [GitHub CLI](https://cli.github.com/) - The official GitHub command-line tool

## 🙏 Acknowledgments

This project is inspired by and follows the design philosophy of [ai-aligned-git](https://github.com/trieloff/ai-aligned-git) by @trieloff. The transparent wrapper pattern ensures AI tools don't need to be modified or trained to use special commands - they just work.

---

*"The best interface is no interface. The wrapper is transparent, the AI doesn't know it exists, and yet every action is properly attributed."*