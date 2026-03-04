#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

CLAUDE_BIN="$(which claude 2>/dev/null || echo '/opt/node22/bin/claude')"
GLOBAL_SETTINGS="$HOME/.claude/settings.json"

# Check if oh-my-claudecode is already installed via settings.json
if [ -f "$GLOBAL_SETTINGS" ] && grep -q '"oh-my-claudecode' "$GLOBAL_SETTINGS"; then
  echo "oh-my-claudecode already installed, skipping."
  exit 0
fi

echo "Installing oh-my-claudecode..."
"$CLAUDE_BIN" plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode.git
"$CLAUDE_BIN" plugin install oh-my-claudecode
echo "oh-my-claudecode installed successfully."
