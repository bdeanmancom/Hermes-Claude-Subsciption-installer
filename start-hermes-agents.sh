#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_NAME="${HERMES_TMUX_SESSION:-hermes-agents}"
SETUP_SCRIPT="$ROOT_DIR/modules/setup-tmux-agents.sh"

usage() {
  cat <<EOF
Usage: ./start-hermes-agents.sh [--rebuild]

Starts and attaches to the Hermes four-pane tmux agent deck.

Options:
  --rebuild   Kill an existing session and recreate the four-pane layout.
  -h, --help  Show this help.

Environment overrides:
  HERMES_TMUX_SESSION
  HERMES_WORKSPACE_ROOT
  HERMES_WORKTREE_ROOT
EOF
}

REBUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild)
      REBUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

command -v tmux >/dev/null 2>&1 || {
  echo "tmux is required. Install it first." >&2
  exit 1
}

if [[ ! -x "$SETUP_SCRIPT" ]]; then
  chmod +x "$SETUP_SCRIPT"
fi

if (( REBUILD )) && tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Rebuilding tmux session '$SESSION_NAME'..."
  tmux kill-session -t "$SESSION_NAME"
fi

"$SETUP_SCRIPT"

if [[ -n "${TMUX:-}" ]]; then
  echo "Already inside tmux. Switch to '$SESSION_NAME' with: tmux switch-client -t $SESSION_NAME"
else
  exec tmux attach -t "$SESSION_NAME"
fi
