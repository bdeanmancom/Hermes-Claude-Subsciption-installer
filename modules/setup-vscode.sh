#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="${HERMES_WORKSPACE_ROOT:-$HOME/hermes-workspace}"
mkdir -p "$TARGET_DIR/.vscode"

cat > "$TARGET_DIR/hermes-agents.code-workspace" <<'EOF'
{
  "folders": [
    { "path": "." }
  ],
  "settings": {
    "terminal.integrated.persistentSessionReviveProcess": "onExitAndWindowClose",
    "remote.SSH.useLocalServer": true
  }
}
EOF

cat > "$TARGET_DIR/.vscode/tasks.json" <<'EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Hermes: Start agent deck",
      "type": "shell",
      "command": "tmux new-session -A -s hermes-agents",
      "problemMatcher": []
    },
    {
      "label": "Hermes: Doctor",
      "type": "shell",
      "command": "hermes doctor",
      "problemMatcher": []
    },
    {
      "label": "Hermes: Auth status",
      "type": "shell",
      "command": "hermes auth list",
      "problemMatcher": []
    }
  ]
}
EOF

echo "VS Code workspace created at: $TARGET_DIR/hermes-agents.code-workspace"
echo "Open it from an SSH-connected VS Code window."
