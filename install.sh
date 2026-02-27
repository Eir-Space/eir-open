#!/bin/bash
# Eir Open installer bootstrap
# Delegates to the Node.js CLI for Warp / modern-terminal compatibility.
set -euo pipefail

if ! command -v node &>/dev/null; then
  echo "Node.js 18+ is required.  Install:  brew install node"
  exit 1
fi

major=$(node -v | sed 's/^v//' | cut -d. -f1)
if [ "$major" -lt 18 ] 2>/dev/null; then
  echo "Node.js 18+ is required (found v$major).  Upgrade:  brew install node"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CLI="$SCRIPT_DIR/cli/index.js"

if [ -f "$LOCAL_CLI" ]; then
  cd "$SCRIPT_DIR/cli"
  [ -d node_modules ] || npm install --silent
  exec node "$LOCAL_CLI" "$@"
fi

exec npx --yes eir-open@latest "$@"
