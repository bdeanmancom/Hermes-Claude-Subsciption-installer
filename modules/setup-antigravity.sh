#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="${HERMES_WORKSPACE_ROOT:-$HOME/hermes-workspace}"
mkdir -p "$TARGET_DIR"

cat > "$TARGET_DIR/ANTIGRAVITY.md" <<'EOF'
# Antigravity + Hermes

Use this machine as the persistent Hermes host and connect to the same project over SSH.

Recommended split:
- Hermes owns long-running sessions, Telegram, provider credentials, and tmux persistence.
- Antigravity is an optional interactive IDE/client for Gemini-backed work.
- Keep each coding agent on its own Git worktree when agents may edit concurrently.

Useful remote commands:

```bash
hermes doctor
hermes auth list
tmux attach -t hermes-agents
```

Do not store API keys in project files. Keep provider secrets in `~/.hermes/.env` or the provider's supported credential store.
EOF

echo "Antigravity integration notes created at: $TARGET_DIR/ANTIGRAVITY.md"
