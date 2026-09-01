#!/usr/bin/env bash
set -Eeuo pipefail

SESSION_NAME="${HERMES_TMUX_SESSION:-hermes-agents}"
WORKSPACE_ROOT="${HERMES_WORKSPACE_ROOT:-$HOME/hermes-workspace}"
WORKTREE_ROOT="${HERMES_WORKTREE_ROOT:-$HOME/hermes-worktrees}"

command -v tmux >/dev/null 2>&1 || {
  echo "tmux is required. Install it and rerun this module."
  exit 1
}

mkdir -p "$WORKSPACE_ROOT"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "tmux session '$SESSION_NAME' already exists."
  exit 0
fi

agent_dir() {
  local name="$1"
  local worktree="$WORKTREE_ROOT/$name"

  if [[ -d "$worktree" ]] && git -C "$worktree" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '%s\n' "$worktree"
  else
    printf '%s\n' "$WORKSPACE_ROOT"
  fi
}

ARCHITECT_DIR="$(agent_dir architect)"
IMPLEMENTER_DIR="$(agent_dir implementer)"
REVIEWER_DIR="$(agent_dir reviewer)"
RESEARCH_DIR="$(agent_dir research)"

tmux new-session -d -s "$SESSION_NAME" -n architect -c "$ARCHITECT_DIR"
tmux new-window -t "$SESSION_NAME" -n implementer -c "$IMPLEMENTER_DIR"
tmux new-window -t "$SESSION_NAME" -n reviewer -c "$REVIEWER_DIR"
tmux new-window -t "$SESSION_NAME" -n research -c "$RESEARCH_DIR"

for window in architect implementer reviewer research; do
  tmux send-keys -t "$SESSION_NAME:$window" "printf '\nHermes agent pane: $window\nWorking directory: %s\nStart with: hermes chat\n\n' \"\$PWD\"" C-m
done

echo "Created tmux agent session: $SESSION_NAME"
echo "Attach with: tmux attach -t $SESSION_NAME"
