#!/usr/bin/env bash
set -Eeuo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_ENV="$HERMES_HOME/.env"
PATCH_REPO="$HOME/hermes-claude-auth"

CLAUDE_MODEL="${CLAUDE_MODEL:-claude-opus-5}"
OPENAI_MODEL="${OPENAI_MODEL:-gpt-5.6-sol}"

LOG_DIR="$HERMES_HOME/logs"
LOG_FILE="$LOG_DIR/post-update-guard.log"
mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

printf '\n[%s] Hermes post-update guard starting\n' "$(date -Is)"

if ! command -v hermes >/dev/null 2>&1; then
    echo "[WARN] hermes command not found in PATH"
    exit 0
fi

# Reapply supported model/provider defaults after any Hermes update.
hermes config set model.provider anthropic || true
hermes config set model.default "$CLAUDE_MODEL" || true

# Reload Hermes environment so OpenAI survives independently of the repo/venv.
if [[ -f "$HERMES_ENV" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$HERMES_ENV"
    set +a
fi

# Run Hermes' own health checks.
if hermes doctor; then
    echo "[OK] hermes doctor passed"
else
    echo "[WARN] hermes doctor reported an issue"
fi

hermes auth list || echo "[WARN] unable to read Hermes auth status"

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    echo "[OK] OPENAI_API_KEY is available"
    hermes chat \
        --provider openai-api \
        --model "$OPENAI_MODEL" \
        -q "Reply with exactly: UPDATE GUARD OK" \
        -Q || echo "[WARN] OpenAI smoke test failed"
else
    echo "[INFO] OPENAI_API_KEY not configured; OpenAI smoke test skipped"
fi

# Check the optional Claude integration without modifying or reinstalling it.
if [[ -x "$PATCH_REPO/install.sh" ]]; then
    if "$PATCH_REPO/install.sh" --check; then
        echo "[OK] hermes-claude-auth health check passed"
    else
        echo "[WARN] hermes-claude-auth is missing or drifted after the Hermes update"
    fi
else
    echo "[INFO] hermes-claude-auth installer not found at $PATCH_REPO/install.sh"
fi

# Anthropic smoke test catches provider/model breakage immediately.
hermes chat \
    --provider anthropic \
    --model "$CLAUDE_MODEL" \
    -q "Reply with exactly: UPDATE GUARD OK" \
    -Q || echo "[WARN] Anthropic smoke test failed"

printf '[%s] Hermes post-update guard finished\n' "$(date -Is)"
