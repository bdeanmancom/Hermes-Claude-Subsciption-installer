#!/usr/bin/env bash
set -Eeuo pipefail

SESSION_NAME="${HERMES_TMUX_SESSION:-hermes-agents}"
WORKSPACE_ROOT="${HERMES_WORKSPACE_ROOT:-$HOME/hermes-workspace}"

command -v tmux >/dev/null 2>&1 || {
  echo "tmux is required. Install it and rerun this module."
  exit 1
}

mkdir -p "$WORKSPACE_ROOT"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "tmux session '$SESSION_NAME' already exists."
  exit 0
fi

tmux new-session -d -s "$SESSION_NAME" -n architect -c "$WORKSPACE_ROOT"
tmux new-window -t "$SESSION_NAME" -n implementer -c "$WORKSPACE_ROOT"
tmux new-window -t "$SESSION_NAME" -n reviewer -c "$WORKSPACE_ROOT"
tmux new-window -t "$SESSION_NAME" -n research -c "$WORKSPACE_ROOT"

for window in architect implementer reviewer research; do
  tmux send-keys -t "$SESSION_NAME:$window" "printf '\nHermes agent pane: $window\nStart with: hermes chat\n\n'" C-m
done

echo "Created tmux agent session: $SESSION_NAME"
echo "Attach with: tmux attach -t $SESSION_NAME"
