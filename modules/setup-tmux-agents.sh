#!/usr/bin/env bash
set -Eeuo pipefail

SESSION_NAME="${HERMES_TMUX_SESSION:-hermes-agents}"
WORKTREE_ROOT="${HERMES_WORKTREE_ROOT:-/srv/hermes/worktrees}"

command -v tmux >/dev/null 2>&1 || {
  echo "tmux is required. Install it and rerun this module." >&2
  exit 1
}

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "tmux session '$SESSION_NAME' already exists."
  echo "Attach with: tmux attach -t $SESSION_NAME"
  exit 0
fi

require_agent_worktree() {
  local name="$1"
  local path="$WORKTREE_ROOT/$name"
  local expected_branch="agent/$name"
  local actual_branch=""

  if [[ ! -d "$path" ]]; then
    echo "Missing isolated worktree for '$name': $path" >&2
    echo "Run the worktree setup before starting the agent deck." >&2
    exit 1
  fi

  if ! git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Agent directory is not a Git worktree: $path" >&2
    exit 1
  fi

  actual_branch="$(git -C "$path" branch --show-current)"
  if [[ "$actual_branch" != "$expected_branch" ]]; then
    echo "Agent '$name' is on '$actual_branch', expected '$expected_branch': $path" >&2
    exit 1
  fi

  printf '%s\n' "$path"
}

ARCHITECT_DIR="$(require_agent_worktree architect)"
IMPLEMENTER_DIR="$(require_agent_worktree implementer)"
REVIEWER_DIR="$(require_agent_worktree reviewer)"
RESEARCH_DIR="$(require_agent_worktree research)"

# One tmux window, four tiled panes. Every pane is pinned to a distinct Git
# worktree. There is intentionally no shared-workspace fallback.
tmux new-session -d -s "$SESSION_NAME" -n agents -c "$ARCHITECT_DIR"
tmux split-window -h -t "$SESSION_NAME:agents.0" -c "$IMPLEMENTER_DIR"
tmux split-window -v -t "$SESSION_NAME:agents.0" -c "$REVIEWER_DIR"
tmux split-window -v -t "$SESSION_NAME:agents.1" -c "$RESEARCH_DIR"
tmux select-layout -t "$SESSION_NAME:agents" tiled

mapfile -t PANES < <(tmux list-panes -t "$SESSION_NAME:agents" -F '#{pane_id}')
ROLES=(architect implementer reviewer research)
DIRS=("$ARCHITECT_DIR" "$IMPLEMENTER_DIR" "$REVIEWER_DIR" "$RESEARCH_DIR")

for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  pane="${PANES[$i]}"
  dir="${DIRS[$i]}"
  tmux select-pane -t "$pane" -T "$role"
  tmux send-keys -t "$pane" "printf '\nHermes agent: $role\nWorkspace: $dir\nBranch: agent/$role\nStart with: hermes chat\n\n'" C-m
done

tmux select-pane -t "$SESSION_NAME:agents.0"

echo "Created isolated four-pane tmux agent session: $SESSION_NAME"
echo "Worktree root: $WORKTREE_ROOT"
echo "Attach with: tmux attach -t $SESSION_NAME"
echo "Move between panes with: Ctrl+b, then an arrow key"
