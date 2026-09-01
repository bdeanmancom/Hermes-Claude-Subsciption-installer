#!/usr/bin/env bash
set -Eeuo pipefail

REPO_PATH="${1:-$PWD}"
WORKTREE_ROOT="${HERMES_WORKTREE_ROOT:-$HOME/hermes-worktrees}"

if [[ ! -d "$REPO_PATH/.git" ]]; then
  echo "Usage: $0 /path/to/git/repository"
  exit 1
fi

mkdir -p "$WORKTREE_ROOT"

create_worktree() {
  local name="$1"
  local branch="agent/$name"
  local path="$WORKTREE_ROOT/$name"

  if [[ -d "$path" ]]; then
    echo "Worktree already exists: $path"
    return
  fi

  if git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$REPO_PATH" worktree add "$path" "$branch"
  else
    git -C "$REPO_PATH" worktree add -b "$branch" "$path"
  fi
}

create_worktree architect
create_worktree implementer
create_worktree reviewer
create_worktree research

echo "Agent worktrees created under: $WORKTREE_ROOT"
