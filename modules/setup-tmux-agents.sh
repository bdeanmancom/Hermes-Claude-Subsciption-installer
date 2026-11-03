#!/usr/bin/env bash
set -Eeuo pipefail

SESSION_NAME="${HERMES_TMUX_SESSION:-hermes-agents}"
# Must match the default in modules/setup-worktrees.sh.
WORKTREE_ROOT="${HERMES_WORKTREE_ROOT:-$HOME/hermes-worktrees}"

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
#
# Each pane ID is captured from the command that created it (-P -F
# '#{pane_id}'). Do not read the mapping back from `list-panes` order:
# `select-layout tiled` renumbers panes by screen position, so three of the
# four banners would claim a worktree the pane is not actually sitting in.
ARCHITECT_PANE="$(tmux new-session -d -s "$SESSION_NAME" -n agents \
  -c "$ARCHITECT_DIR" -P -F '#{pane_id}')"
IMPLEMENTER_PANE="$(tmux split-window -h -t "$ARCHITECT_PANE" \
  -c "$IMPLEMENTER_DIR" -P -F '#{pane_id}')"
REVIEWER_PANE="$(tmux split-window -v -t "$ARCHITECT_PANE" \
  -c "$REVIEWER_DIR" -P -F '#{pane_id}')"
RESEARCH_PANE="$(tmux split-window -v -t "$IMPLEMENTER_PANE" \
  -c "$RESEARCH_DIR" -P -F '#{pane_id}')"
tmux select-layout -t "$SESSION_NAME:agents" tiled

PANES=("$ARCHITECT_PANE" "$IMPLEMENTER_PANE" "$REVIEWER_PANE" "$RESEARCH_PANE")
ROLES=(architect implementer reviewer research)
DIRS=("$ARCHITECT_DIR" "$IMPLEMENTER_DIR" "$REVIEWER_DIR" "$RESEARCH_DIR")

for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  pane="${PANES[$i]}"
  dir="${DIRS[$i]}"
  tmux select-pane -t "$pane" -T "$role"
  tmux send-keys -t "$pane" "printf '\nHermes agent: $role\nWorkspace: $dir\nBranch: agent/$role\nStart with: hermes chat\n\n'" C-m
done

tmux select-pane -t "$ARCHITECT_PANE"

echo "Created isolated four-pane tmux agent session: $SESSION_NAME"
echo "Worktree root: $WORKTREE_ROOT"
echo "Attach with: tmux attach -t $SESSION_NAME"
echo "Move between panes with: Ctrl+b, then an arrow key"
