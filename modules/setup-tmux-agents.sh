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
  echo "Attach with: tmux attach -t $SESSION_NAME"
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

# One tmux window, four tiled panes. This makes the full agent team visible
# at once while preserving a separate working directory for every role.
tmux new-session -d -s "$SESSION_NAME" -n agents -c "$ARCHITECT_DIR"
tmux split-window -h -t "$SESSION_NAME:agents.0" -c "$IMPLEMENTER_DIR"
tmux split-window -v -t "$SESSION_NAME:agents.0" -c "$REVIEWER_DIR"
tmux split-window -v -t "$SESSION_NAME:agents.1" -c "$RESEARCH_DIR"
tmux select-layout -t "$SESSION_NAME:agents" tiled

# Capture pane ids after the final tiled layout and label each role explicitly.
mapfile -t PANES < <(tmux list-panes -t "$SESSION_NAME:agents" -F '#{pane_id}')
ROLES=(architect implementer reviewer research)

for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  pane="${PANES[$i]}"
  tmux select-pane -t "$pane" -T "$role"
  tmux send-keys -t "$pane" "printf '\nHermes agent: $role\nWorking directory: %s\nStart with: hermes chat\n\n' \"\$PWD\"" C-m
done

tmux select-pane -t "$SESSION_NAME:agents.0"

echo "Created four-pane tmux agent session: $SESSION_NAME"
echo "Attach with: tmux attach -t $SESSION_NAME"
echo "Move between panes with: Ctrl+b, then an arrow key"
