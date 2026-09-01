#!/usr/bin/env python3
"""Verify every agent pane sits in the worktree its label claims.

This exists because a launcher can print a banner saying "Workspace: X"
into a pane whose real working directory is Y. Grepping that banner back
out proves nothing -- it only compares the launcher's output to itself.
The authority is tmux's own #{pane_current_path}.

Checks, per pane:
  1. pane_current_path basename == the role it is labelled with
  2. the git branch checked out there == agent/<role>
  3. the banner's "Workspace:" line agrees with pane_current_path
  4. every role appears exactly once

Exit 0 when all panes agree, 1 otherwise.

Usage:
  verify_panes.py [session_name]     (default: hermes-agents)
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

# Pane title -> role. Titles carry a display name and charter, so match on
# the role word rather than the whole string.
ROLES = ["architect", "implementer", "reviewer", "research"]
ROLE_ALIASES = {"researcher": "research"}


def tmux(*args: str) -> str:
    r = subprocess.run(["tmux", *args], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"tmux {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout.rstrip("\n")


def role_from_title(title: str) -> str | None:
    for word in re.split(r"[^a-zA-Z]+", title.lower()):
        canon = ROLE_ALIASES.get(word, word)
        if canon in ROLES:
            return canon
    return None


def main() -> None:
    session = sys.argv[1] if len(sys.argv) > 1 else "hermes-agents"
    target = f"{session}:agents"

    listing = tmux("list-panes", "-t", target, "-F",
                   "#{pane_id}\t#{pane_current_path}\t#{pane_title}")

    failures: list[str] = []
    seen: dict[str, str] = {}

    print(f"{'pane':<6} {'labelled':<12} {'actual cwd':<40} {'branch':<22} verdict")
    print("-" * 96)

    for line in listing.splitlines():
        pane_id, path, title = line.split("\t", 2)
        claimed = role_from_title(title)
        actual = Path(path).name

        branch = subprocess.run(["git", "-C", path, "branch", "--show-current"],
                                capture_output=True, text=True).stdout.strip() or "(not a repo)"

        problems = []
        if claimed is None:
            problems.append(f"title has no recognisable role: {title!r}")
        elif claimed != actual:
            problems.append(f"labelled '{claimed}' but sitting in '{actual}'")

        expected_branch = f"agent/{actual}"
        if branch != expected_branch:
            problems.append(f"branch is '{branch}', expected '{expected_branch}'")

        # The banner the launcher printed into the pane must not contradict
        # the pane's real cwd.
        captured = subprocess.run(["tmux", "capture-pane", "-p", "-t", pane_id],
                                  capture_output=True, text=True).stdout
        m = re.search(r"^Workspace:\s*(\S+)", captured, re.M)
        if m and m.group(1) != path:
            problems.append(f"banner claims workspace {m.group(1)}, cwd is {path}")

        if claimed:
            if claimed in seen:
                problems.append(f"role '{claimed}' also claimed by pane {seen[claimed]}")
            seen[claimed] = pane_id

        verdict = "OK" if not problems else "MISMATCH"
        print(f"{pane_id:<6} {str(claimed):<12} {path:<40} {branch:<22} {verdict}")
        for p in problems:
            print(f"       -> {p}")
            failures.append(f"{pane_id}: {p}")

    missing = [r for r in ROLES if r not in seen]
    if missing:
        failures.append(f"no pane labelled for role(s): {', '.join(missing)}")
        print(f"\nMissing roles: {', '.join(missing)}")

    print()
    if failures:
        print(f"FAIL: {len(failures)} problem(s)")
        sys.exit(1)
    print(f"PASS: all {len(seen)} panes sit in the worktree their label claims")


if __name__ == "__main__":
    main()
