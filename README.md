# Hermes + Claude Setup Installer

A repeatable Linux/WSL setup script for installing and validating:

- Claude Code
- Hermes Agent
- Anthropic provider configuration in Hermes
- A local clone of `kristianvast/hermes-claude-auth` for inspection

> Note: this repository does **not** automatically execute third-party authentication-bypass patches. It installs the supported Hermes and Claude components, configures them, runs diagnostics, and leaves the optional patch repository cloned locally for review.

## Quick start

```bash
chmod +x setup-hermes-claude.sh
./setup-hermes-claude.sh
```

If Claude authentication has not yet been completed, run:

```bash
claude
```

Complete the Claude.ai login, exit Claude, then rerun:

```bash
./setup-hermes-claude.sh
```

The script is designed to be rerunnable. Existing installations are detected and reused where possible.

## What the script does

1. Verifies base dependencies such as `git` and `curl`.
2. Installs Claude Code with Anthropic's native installer if needed.
3. Runs `claude doctor` and checks for Claude credentials.
4. Installs Hermes using the official Hermes installer if needed.
5. Configures Hermes to use Anthropic and `claude-sonnet-4-6` by default.
6. Runs `hermes doctor` and `hermes auth list`.
7. Clones or safely updates `~/hermes-claude-auth` without overwriting local changes.
8. Runs a simple Hermes/Anthropic smoke test when authentication is available.

## Default model

The default is:

```text
claude-sonnet-4-6
```

Override it for one run with:

```bash
CLAUDE_MODEL=your-model ./setup-hermes-claude.sh
```

## Useful commands

```bash
hermes doctor
hermes auth list
hermes model
hermes chat --provider anthropic --model claude-sonnet-4-6
hermes gateway setup
```

## Repository layout

```text
.
├── README.md
├── setup-hermes-claude.sh
└── .gitignore
```

## Notes

The optional `hermes-claude-auth` project is cloned to:

```text
~/hermes-claude-auth
```

If that directory already exists and contains local changes, the installer intentionally skips `git pull` so those changes are not overwritten.
