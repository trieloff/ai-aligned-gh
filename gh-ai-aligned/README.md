# gh-ai-aligned: AI-Aware GitHub CLI Extension

A GitHub CLI (`gh`) extension that automatically detects when it's being invoked by an AI tool and ensures all actions are properly attributed to a bot acting on behalf of the user, rather than the user directly.

## 🎯 Purpose

When AI coding assistants (like Claude, Cursor, Gemini, etc.) use the GitHub CLI to perform actions, those actions appear to come directly from the user. This extension:

1. **Detects AI Usage**: Automatically identifies when `gh` is being called by an AI tool
2. **Exchanges Tokens**: Uses the [as-a-bot](https://github.com/trieloff/as-a-bot) service to exchange user tokens for bot tokens
3. **Ensures Attribution**: All AI-performed actions are properly attributed to a bot acting on behalf of the user

## 🚀 Quick Start

### One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/gh-ai-aligned/main/install.sh | sh
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/gh-ai-aligned.git
cd gh-ai-aligned

# Run the installer
./install.sh
```

## 📋 Prerequisites

1. **GitHub CLI**: Install `gh` from [cli.github.com](https://cli.github.com/)
2. **GitHub App**: Install the [as-a-bot-app](https://github.com/apps/as-a-bot-app) on your repositories
3. **Authentication**: Be authenticated with `gh auth login`

## 🔧 How It Works

### Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│   AI Tool   │────▶│ gh-ai-aligned│────▶│   gh CLI     │
│  (Claude,   │     │   Extension  │     │              │
│  Cursor,    │     │              │     └──────────────┘
│  etc.)      │     │   Detects AI │              │
└─────────────┘     │   & Exchanges│              ▼
                    │    Tokens    │     ┌──────────────┐
                    └──────────────┘     │  GitHub API  │
                            │            └──────────────┘
                            ▼
                    ┌──────────────┐
                    │  as-a-bot    │
                    │   Service    │
                    └──────────────┘
```

### Process Flow

1. **AI Detection**: The extension checks process trees and environment variables to detect AI tools
2. **Repository Context**: Determines the current GitHub repository from git config
3. **App Verification**: Checks if the as-a-bot GitHub App is installed on the repository
4. **Token Exchange**: Exchanges the user's token for a bot token via the as-a-bot service
5. **Execute Command**: Runs the original `gh` command with the bot token

## 🎮 Usage

### As a Direct Replacement

```bash
# Instead of:
gh pr create --title "Fix bug" --body "Fixed the issue"

# Use:
gh ai pr create --title "Fix bug" --body "Fixed the issue"
```

### With an Alias

Add to your shell configuration:

```bash
alias gh='gh ai'
```

### Debug Mode

See what's happening under the hood:

```bash
GH_AI_DEBUG=true gh ai auth status
```

## 🤖 Supported AI Tools

The extension automatically detects:

- **Claude** (Anthropic) - via process name or `CLAUDE_CODE`/`ANTHROPIC_SHELL` env vars
- **Cursor** - via process name or `CURSOR_AI` env var
- **Gemini** (Google) - via process name or `GEMINI_CLI` env var
- **Qwen Code** (Alibaba) - via process name or `QWEN_CODE` env var
- **Zed AI** - via process name or `ZED_AI` env var
- **OpenCode** - via process name or `OPENCODE_AI` env var

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GH_AI_DEBUG` | Enable debug logging | `false` |
| `AS_A_BOT_URL` | as-a-bot service URL | `https://as-bot-worker.minivelos.workers.dev` |
| `GH_TOKEN` | GitHub token (fallback to `GITHUB_TOKEN` or `gh auth token`) | - |

### Force AI Detection

For unsupported AI tools, set an environment variable:

```bash
export CLAUDE_CODE=1  # Force Claude detection
export CURSOR_AI=1    # Force Cursor detection
# etc.
```

## 🔒 Security

- **No Token Storage**: Tokens are exchanged on-demand and never stored
- **Privilege Preservation**: Bot tokens have the same permissions as the user
- **Audit Trail**: All actions are properly attributed in GitHub's audit logs
- **Open Source**: Both this extension and the as-a-bot service are open source

## 📝 Examples

### Example: AI Creating a Pull Request

When Claude uses `gh` to create a PR:

```bash
# Without gh-ai-aligned:
# PR appears to be created directly by the user

# With gh-ai-aligned:
# PR is created by "as-a-bot[bot]" on behalf of the user
```

### Example: Checking Installation Status

```bash
# Enable debug mode to see the detection process
GH_AI_DEBUG=true gh ai repo view

# Output will show:
# [INFO] AI detected: claude - checking for bot token exchange...
# [INFO] Successfully exchanged token - actions will be attributed to bot on behalf of user
```

## 🚧 Troubleshooting

### Extension Not Found

```bash
# Verify installation
gh extension list | grep gh-ai-aligned

# Reinstall if needed
curl -fsSL https://raw.githubusercontent.com/yourusername/gh-ai-aligned/main/install.sh | sh
```

### App Not Installed

If you see a warning about the GitHub App not being installed:

1. Visit [https://github.com/apps/as-a-bot-app](https://github.com/apps/as-a-bot-app)
2. Click "Install" or "Configure"
3. Select the repositories you want to use
4. Save the configuration

### Token Exchange Fails

```bash
# Check your authentication
gh auth status

# Re-authenticate if needed
gh auth login
```

### AI Not Detected

```bash
# Force detection with environment variable
export CLAUDE_CODE=1
gh ai pr list
```

## 🤝 Contributing

Contributions are welcome! To add support for a new AI tool:

1. Add detection logic in the `detect_ai_tool` function
2. Add any specific environment variable checks
3. Test the detection with `GH_AI_DEBUG=true`
4. Submit a pull request

## 📜 License

Apache 2.0 - See [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [ai-aligned-git](https://github.com/trieloff/ai-aligned-git) - Git wrapper for AI attribution
- [as-a-bot](https://github.com/trieloff/as-a-bot) - GitHub App token broker service
- [gh CLI](https://cli.github.com/) - GitHub's official command line tool

## 🙏 Acknowledgments

This project builds upon:
- The satirical genius of [ai-aligned-git](https://github.com/trieloff/ai-aligned-git) by @trieloff
- The practical token broker [as-a-bot](https://github.com/trieloff/as-a-bot) service by @trieloff
- The GitHub CLI team for making `gh` extensible

---

*"Because when AIs take over GitHub, at least we'll know which commits were theirs."* 🤖