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

# Worktree isolation separates the agents' FILES. It does not separate their
# MINDS: a bare `hermes chat` puts every pane on the default profile, so all
# four agents share one state.db and one memory store, read each other's
# sessions as their own history, and converge into a single identity.
#
# Each pane therefore runs `hermes -p <profile> chat`. Same contract as
# require_agent_worktree: a missing profile is a hard failure, never a silent
# fallback to shared state.
require_agent_profile() {
  local name="$1"
  local profile="$name"

  # The architect may live in the default profile (an established agent with
  # existing history); override with HERMES_PROFILE_ARCHITECT.
  if [[ "$name" == "architect" ]]; then
    profile="${HERMES_PROFILE_ARCHITECT:-default}"
  fi

  if [[ "$profile" != "default" && ! -d "$HOME/.hermes/profiles/$profile" ]]; then
    echo "Missing Hermes profile for agent '$name': $profile" >&2
    echo "Create it with: hermes profile create $profile --clone-from reviewer" >&2
    echo "Refusing to start: agents without their own profile share memory and identity." >&2
    exit 1
  fi

  printf '%s\n' "$profile"
}

ARCHITECT_DIR="$(require_agent_worktree architect)"
IMPLEMENTER_DIR="$(require_agent_worktree implementer)"
REVIEWER_DIR="$(require_agent_worktree reviewer)"
RESEARCH_DIR="$(require_agent_worktree research)"

ARCHITECT_PROFILE="$(require_agent_profile architect)"
IMPLEMENTER_PROFILE="$(require_agent_profile implementer)"
REVIEWER_PROFILE="$(require_agent_profile reviewer)"
RESEARCH_PROFILE="$(require_agent_profile research)"

# One tmux window, four tiled panes. Every pane is pinned to a distinct Git
# worktree. There is intentionally no shared-workspace fallback.
#
# Each pane's ID is captured from the split that CREATED it (-P -F '#{pane_id}').
# Do not derive the mapping from `list-panes` order instead: `select-layout
# tiled` renumbers panes by screen position, so pane index order and creation
# order diverge, and pairing PANES[i] with DIRS[i] silently mislabels three of
# the four panes -- an agent then reads a banner claiming a worktree it is not
# actually sitting in. Pane IDs (%0, %1, ...) are stable across relayout;
# indices are not.
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
PROFILES=("$ARCHITECT_PROFILE" "$IMPLEMENTER_PROFILE" "$REVIEWER_PROFILE" "$RESEARCH_PROFILE")

# Each agent's working name, shown in the pane border so an operator can tell
# the four apart at a glance. Names are part of the isolation story: an agent
# that cannot see its own name in front of it is one context-compaction away
# from answering to somebody else's.
NAMES=(
  "${HERMES_NAME_ARCHITECT:-Alfred}"
  "${HERMES_NAME_IMPLEMENTER:-Forge}"
  "${HERMES_NAME_REVIEWER:-DiffWhisper}"
  "${HERMES_NAME_RESEARCH:-AtlasScout}"
)

# One-line charter per role, in the third person for the pane border.
CHARTERS=(
  "decides what gets built"
  "builds it"
  "gates the merge"
  "gathers the evidence"
)

# Second-person form of the same charter, for the banner printed into the
# pane. Kept separate so neither reads like a grammatical accident.
CHARTERS_YOU=(
  "decide what gets built"
  "build it"
  "gate the merge"
  "gather the evidence"
)

# Human-readable role label; 'research' is the directory name, not a job title.
ROLE_LABELS=(architect implementer reviewer researcher)

# Show pane titles in the border, otherwise the -T name is invisible.
# Scoped to this window (-w), not the server (-g): a launcher should not
# restyle unrelated tmux sessions the user already has open.
tmux set-option -w -t "$SESSION_NAME:agents" pane-border-status top
tmux set-option -w -t "$SESSION_NAME:agents" pane-border-format " #{pane_title} "

for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  pane="${PANES[$i]}"
  dir="${DIRS[$i]}"
  profile="${PROFILES[$i]}"
  name="${NAMES[$i]}"
  charter="${CHARTERS[$i]}"
  charter_you="${CHARTERS_YOU[$i]}"
  label="${ROLE_LABELS[$i]}"

  tmux select-pane -t "$pane" -T "$name — $label — $charter"
  tmux send-keys -t "$pane" "printf '\nYou are $name, the $label — you $charter_you.\nWorkspace: $dir\nBranch: agent/$role\nProfile: $profile\nStart with: hermes -p $profile chat\n\n'" C-m
done

tmux select-pane -t "$SESSION_NAME:agents.0"

echo "Created isolated four-pane tmux agent session: $SESSION_NAME"
echo "Worktree root: $WORKTREE_ROOT"
echo "Attach with: tmux attach -t $SESSION_NAME"
echo "Move between panes with: Ctrl+b, then an arrow key"
