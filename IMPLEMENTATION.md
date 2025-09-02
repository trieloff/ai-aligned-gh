# AI-Aligned-GH Implementation Notes

## Why a Wrapper, Not an Extension

After careful analysis of the problem and reviewing the ai-aligned-git implementation, we chose to implement AI-Aligned-GH as a **transparent wrapper** rather than a GitHub CLI extension. Here's why:

### The Extension Problem

A gh extension would require AI tools to consciously call `gh ai` instead of `gh`. This is problematic because:

1. **Training Data**: AI models are trained on millions of examples using `gh`, not `gh ai`
2. **Natural Behavior**: Developers and AIs naturally type `gh pr create`, not `gh ai pr create`
3. **Adoption Friction**: Requires every AI tool to be updated or configured differently
4. **User Burden**: Users would need to remember to use different commands when using AI

### The Wrapper Solution

A transparent wrapper that intercepts all `gh` calls solves these problems:

1. **Zero Configuration**: AI tools continue using `gh` normally
2. **Automatic Detection**: The wrapper detects AI usage transparently
3. **Universal Coverage**: Works with any AI tool, present or future
4. **Backward Compatible**: Non-AI usage continues to work exactly as before

## Implementation Details

### File Structure

```
ai-aligned-gh/
├── executable_gh     # The wrapper script that intercepts gh calls
├── install.sh        # Installation script that sets up PATH
├── test.sh          # Test suite for verification
├── README.md        # User documentation
└── IMPLEMENTATION.md # This file
```

### Key Components

#### 1. AI Detection (`detect_ai_tool` function)

Detects AI tools through multiple methods:
- Environment variables (fastest, most reliable)
- Process tree walking (catches nested invocations)
- Process name matching (works across platforms)

#### 2. Token Exchange

When AI is detected:
1. Get current repository from git config
2. Check if as-a-bot app is installed
3. Exchange user token for bot token
4. Execute gh with bot token

#### 3. Smart Operation Detection

The wrapper distinguishes between:
- **Read operations**: Skip token exchange for performance
- **Write operations**: Perform token exchange for attribution

#### 4. PATH Precedence

The wrapper installs to `~/.local/bin/gh` and must come before the real `gh` in PATH:
```
/home/user/.local/bin/gh (wrapper) → /usr/bin/gh (real)
```

## Comparison with gh Extension Approach

| Aspect | Extension (`gh ai`) | Wrapper (`gh` interceptor) |
|--------|---------------------|---------------------------|
| AI Adoption | Requires training/configuration | Works immediately |
| User Experience | Must remember special command | Transparent |
| Maintenance | Requires gh extension system | Standalone script |
| Installation | `gh ext install` | Simple PATH setup |
| Compatibility | Requires gh extension support | Works with any gh version |

## Security Considerations

1. **Token Handling**: Tokens are never stored, only exchanged on-demand
2. **Fallback Safety**: If exchange fails, falls back to normal operation
3. **Permission Preservation**: Bot tokens have same permissions as user
4. **Audit Trail**: All actions are logged and attributed

## Testing

The wrapper includes comprehensive tests for:
- AI detection for multiple tools
- PATH configuration
- Read vs write operation detection
- Repository detection
- Token exchange flow

## Future Improvements

1. **Caching**: Cache app installation status briefly to reduce API calls
2. **More AI Tools**: Add detection for new AI coding assistants
3. **Performance**: Optimize process tree walking for faster detection
4. **Configuration**: Add user config file for customization

## Credits

This implementation follows the excellent design pattern established by [ai-aligned-git](https://github.com/trieloff/ai-aligned-git), adapting it for the GitHub CLI with token exchange via the as-a-bot service.