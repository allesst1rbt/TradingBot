#!/bin/sh
# Seed Hermes credentials from Railway env vars before running the bot.
export HOME=${HOME:-/root}
export PATH="$HOME/.local/bin:$PATH"

if [ ! -d "$HOME/.hermes" ]; then
  mkdir -p "$HOME/.hermes"
fi

if [ -n "$OPENCODE_GO_API_KEY" ] && ! grep -q "^OPENCODE_GO_API_KEY=" "$HOME/.hermes/.env" 2>/dev/null; then
  echo "OPENCODE_GO_API_KEY=$OPENCODE_GO_API_KEY" >> "$HOME/.hermes/.env"
fi

exec "$@"
