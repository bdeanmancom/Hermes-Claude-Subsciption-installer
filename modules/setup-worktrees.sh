#!/usr/bin/env bash
set -Eeuo pipefail

REPO_PATH="${1:-$PWD}"
WORKTREE_ROOT="${HERMES_WORKTREE_ROOT:-$HOME/hermes-worktrees}"

if ! git -C "$REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Usage: $0 /path/to/git/repository"
  echo "Not a valid Git work tree: $REPO_PATH"
  exit 1
fi

REPO_PATH="$(git -C "$REPO_PATH" rev-parse --show-toplevel)"
mkdir -p "$WORKTREE_ROOT"

worktree_for_branch() {
  local branch="$1"
  git -C "$REPO_PATH" worktree list --porcelain | awk -v target="refs/heads/$branch" '
    $1 == "worktree" { path=$2 }
    $1 == "branch" && $2 == target { print path; exit }
  '
}

create_worktree() {
  local name="$1"
  local branch="agent/$name"
  local path="$WORKTREE_ROOT/$name"
  local existing_path=""

  if [[ -d "$path" ]]; then
    if git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Worktree already exists: $path"
      return 0
    fi

    echo "Destination exists but is not a Git worktree: $path"
    return 1
  fi

  existing_path="$(worktree_for_branch "$branch")"
  if [[ -n "$existing_path" ]]; then
    echo "Branch $branch is already checked out at: $existing_path"
    echo "Skipping $name instead of aborting the remaining agent worktrees."
    return 0
  fi

  if git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$branch"; then
    if ! git -C "$REPO_PATH" worktree add "$path" "$branch"; then
      echo "Could not add existing branch $branch at $path; continuing."
      return 0
    fi
  else
    if ! git -C "$REPO_PATH" worktree add -b "$branch" "$path"; then
      echo "Could not create worktree for $branch at $path; continuing."
      return 0
    fi
  fi

  echo "Created worktree: $path ($branch)"
}

for name in architect implementer reviewer research; do
  create_worktree "$name"
done

echo "Agent worktrees are under: $WORKTREE_ROOT"
