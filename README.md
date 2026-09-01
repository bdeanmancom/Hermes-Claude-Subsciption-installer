# Hermes + Claude + OpenAI Setup Installer

A repeatable Linux/WSL setup script for installing and validating:

- Claude Code
- Hermes Agent
- Anthropic provider configuration in Hermes
- OpenAI direct API support in Hermes
- A local clone of `kristianvast/hermes-claude-auth` for inspection

> Note: this repository does **not** automatically execute third-party authentication-bypass patches. It installs the supported Hermes and Claude components, configures providers, runs diagnostics, and leaves the optional patch repository cloned locally for review.

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

## Anthropic models

The installer uses the following Claude stack:

```text
Primary:      claude-opus-5
Fallback #1: claude-opus-4-8
Fallback #2: claude-sonnet-5
```

Override them for one run with environment variables:

```bash
CLAUDE_MODEL=claude-opus-5 \
CLAUDE_MODEL_FALLBACK_1=claude-opus-4-8 \
CLAUDE_MODEL_FALLBACK_2=claude-sonnet-5 \
./setup-hermes-claude.sh
```

## OpenAI models

Hermes direct OpenAI API support uses provider `openai-api` and detects `OPENAI_API_KEY` from your shell or `~/.hermes/.env`.

The configured OpenAI stack is:

```text
Primary:      gpt-5.6-sol
Fallback #1: gpt-5.6-terra
Fallback #2: gpt-5.6-luna
```

To enable OpenAI, add your key to:

```text
~/.hermes/.env
```

For example:

```bash
OPENAI_API_KEY=your-key-here
```

Do not commit real API keys to this repository.

You can override the OpenAI model stack for one run:

```bash
OPENAI_MODEL=gpt-5.6-sol \
OPENAI_MODEL_FALLBACK_1=gpt-5.6-terra \
OPENAI_MODEL_FALLBACK_2=gpt-5.6-luna \
./setup-hermes-claude.sh
```

## What the script does

1. Verifies base dependencies such as `git` and `curl`.
2. Installs Claude Code with Anthropic's native installer if needed.
3. Runs `claude doctor` and checks for Claude credentials.
4. Installs Hermes using the official Hermes installer if needed.
5. Configures Hermes to use Anthropic with `claude-opus-5` as the default model.
6. Detects `OPENAI_API_KEY` and enables OpenAI direct API smoke testing when available.
7. Runs `hermes doctor` and `hermes auth list`.
8. Clones or safely updates `~/hermes-claude-auth` without overwriting local changes.
9. Smoke-tests Anthropic using Opus 5, then Opus 4.8, then Sonnet 5 if needed.
10. Smoke-tests OpenAI using GPT-5.6 Sol, Terra, then Luna if needed.

## Useful commands

```bash
hermes doctor
hermes auth list
hermes model

hermes chat --provider anthropic --model claude-opus-5
hermes chat --provider anthropic --model claude-opus-4-8
hermes chat --provider anthropic --model claude-sonnet-5

hermes chat --provider openai-api --model gpt-5.6-sol
hermes chat --provider openai-api --model gpt-5.6-terra
hermes chat --provider openai-api --model gpt-5.6-luna

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
