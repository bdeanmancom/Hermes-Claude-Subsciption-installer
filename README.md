# Hermes + Claude + OpenAI Setup Installer

A repeatable Linux/WSL setup script for installing and validating:

- Claude Code
- Hermes Agent
- Anthropic provider configuration in Hermes
- OpenAI direct API support in Hermes
- Automatic post-update health checks
- Optional VS Code Remote SSH workspace
- Optional Antigravity integration helpers
- Optional persistent tmux multi-agent deck
- Optional per-agent Git worktrees
- A local clone of `kristianvast/hermes-claude-auth` for inspection

> Note: this repository does **not** automatically execute third-party authentication-bypass patches. It installs supported Hermes/Claude components, configures providers, runs diagnostics, and leaves the optional patch repository cloned locally for review.

## Quick start

Core setup only:

```bash
chmod +x setup-hermes-claude.sh
./setup-hermes-claude.sh
```

Core setup plus VS Code and persistent multi-agent tmux sessions:

```bash
./setup-hermes-claude.sh --vscode --multi-agent
```

Everything:

```bash
./setup-hermes-claude.sh --all
```

If Claude authentication has not yet been completed, run `claude`, complete the Claude.ai login, exit Claude, and rerun the installer.

## Optional modules

```text
--vscode              Create VS Code Remote SSH workspace/tasks
--antigravity         Create Antigravity integration helpers/notes
--multi-agent         Create persistent tmux agent deck
--worktrees [PATH]    Create per-agent Git worktrees
--all                 Enable all optional modules
```

Examples:

```bash
./setup-hermes-claude.sh --antigravity
./setup-hermes-claude.sh --worktrees ~/src/my-project
./setup-hermes-claude.sh --vscode --antigravity --multi-agent
```

The default tmux deck creates four persistent windows:

```text
architect
implementer
reviewer
research
```

The worktree module creates matching branches/worktrees under `~/hermes-worktrees/` so concurrent coding agents do not edit the same checkout.

## Anthropic models

```text
Primary:      claude-opus-5
Fallback #1: claude-opus-4-8
Fallback #2: claude-sonnet-5
```

Override them with `CLAUDE_MODEL`, `CLAUDE_MODEL_FALLBACK_1`, and `CLAUDE_MODEL_FALLBACK_2`.

## OpenAI models

Hermes direct OpenAI API support uses provider `openai-api` and detects `OPENAI_API_KEY` from your shell or `~/.hermes/.env`.

```text
Primary:      gpt-5.6-sol
Fallback #1: gpt-5.6-terra
Fallback #2: gpt-5.6-luna
```

Do not commit API keys to this repository.

## Architecture

```text
VS Code Remote SSH / Antigravity / Telegram
                 |
                 v
        Linux / WSL Hermes host
                 |
      Hermes + tmux + Git worktrees
        |                    |
     Anthropic             OpenAI
```

Hermes remains the persistent service/agent layer. VS Code and Antigravity are optional front ends, while tmux keeps sessions alive through editor disconnects.

## Useful commands

```bash
hermes doctor
hermes auth list
hermes model

tmux attach -t hermes-agents

hermes chat --provider anthropic --model claude-opus-5
hermes chat --provider openai-api --model gpt-5.6-sol

hermes gateway setup
```

## Repository layout

```text
.
├── README.md
├── setup-hermes-claude.sh
├── install-update-guard.sh
├── hermes-safe-update.sh
├── modules/
│   ├── setup-vscode.sh
│   ├── setup-antigravity.sh
│   ├── setup-tmux-agents.sh
│   └── setup-worktrees.sh
└── .gitignore
```

## Update resilience

The installer enables the repository's post-update guard when supported. After Hermes changes, the guard reapplies provider/model settings, runs diagnostics, checks auth status, and verifies the local `hermes-claude-auth` checkout for drift.

For a guarded manual update:

```bash
./hermes-safe-update.sh
```

## Notes

The optional `hermes-claude-auth` project is cloned persistently to `~/hermes-claude-auth`. If that directory has local changes, the installer skips `git pull` so they are not overwritten.
