#!/usr/bin/env bash
# Run any aidemo command with the right PATH (ttyd, google-chrome symlinks)
# and the nvm node. Usage: ./run.sh <aidemo args...>
set -euo pipefail
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
export PATH="$HOME/bin:$PATH"
# Repo root is two levels up from this demo dir (demos/<name>/).
cd "$(cd "$(dirname "$0")/../.." && pwd)"
exec node bin/aidemo.mjs "$@"
