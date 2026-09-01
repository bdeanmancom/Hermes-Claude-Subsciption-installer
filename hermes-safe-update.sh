#!/usr/bin/env bash
set -Eeuo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PATCH_REPO="$HOME/hermes-claude-auth"
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-opus-5}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
err()  { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

command -v hermes >/dev/null 2>&1 || {
  err "Hermes is not installed or not in PATH."
  exit 1
}

printf '\nUpdating Hermes...\n\n'
hermes update

printf '\nReapplying supported Hermes configuration...\n'
hermes config set model.provider anthropic || warn "Could not restore provider setting."
hermes config set model.default "$CLAUDE_MODEL" || warn "Could not restore default model setting."

printf '\nRunning Hermes diagnostics...\n'
if hermes doctor; then
  ok "Hermes doctor passed after update."
else
  warn "Hermes doctor reported issues after update."
fi

printf '\nChecking configured authentication...\n'
hermes auth list || warn "Could not read Hermes auth status."

if [[ -f "$HERMES_HOME/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$HERMES_HOME/.env"
  set +a
fi

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  ok "OPENAI_API_KEY is still available."
else
  warn "OPENAI_API_KEY was not detected in the environment or $HERMES_HOME/.env."
fi

printf '\nChecking optional hermes-claude-auth installation health...\n'
if [[ -x "$PATCH_REPO/install.sh" ]]; then
  if "$PATCH_REPO/install.sh" --check; then
    ok "hermes-claude-auth reports healthy."
  else
    warn "hermes-claude-auth reports missing or drifted files after the Hermes update."
    warn "The upstream project must be repaired separately before relying on that integration."
  fi
else
  warn "No persistent hermes-claude-auth installer found at $PATCH_REPO/install.sh."
fi

printf '\nPost-update smoke check...\n'
if hermes chat --provider anthropic --model "$CLAUDE_MODEL" -q "Reply with exactly: UPDATE TEST OK" -Q; then
  ok "Anthropic smoke test passed."
else
  warn "Anthropic smoke test failed after update."
fi

printf '\nDone. Hermes update and post-update health checks completed.\n'
