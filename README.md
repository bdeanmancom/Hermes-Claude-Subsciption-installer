# Hermes Multi-Agent Workstation

Turn a Linux or WSL machine into a persistent, multi-provider AI workstation built around Hermes Agent.

This project sets up the core Hermes environment, connects supported Anthropic and OpenAI workflows, keeps long-running sessions alive, adds update-health protection, and optionally layers on VS Code Remote SSH, Antigravity, tmux-based agent panes, and isolated Git worktrees.

The goal is simple: **Hermes stays running on the box while your editor, terminal, Telegram, and other clients become interchangeable front ends.**

## What this gives you

- **Persistent Hermes host** for long-running agent sessions and gateway workloads
- **Multiple AI providers** through Hermes, including Anthropic and OpenAI-compatible workflows
- **Claude Code integration** with local credential detection and diagnostics
- **VS Code Remote SSH workspace** for using the box like a remote AI development workstation
- **Antigravity integration helpers** for Gemini-oriented interactive work alongside Hermes
- **Persistent multi-agent tmux deck** with separate Architect, Implementer, Reviewer, and Research panes
- **Per-agent Git worktrees** so concurrent coding agents do not edit the same checkout
- **Telegram-compatible Hermes gateway** for remote/mobile access
- **Post-update health guard** to re-check configuration and catch breakage after Hermes changes
- **Safe, rerunnable setup** designed to reuse existing installations instead of blindly replacing them

## Architecture

```text
                     YOUR DESKTOP / PHONE

          VS Code        Antigravity       Telegram
             \               |               /
              \              |              /
               +-------------+-------------+
                             |
                          SSH / API
                             |
                  +-----------------------+
                  |   Linux / WSL Host    |
                  |                       |
                  |      Hermes Agent     |
                  |      Hermes Gateway   |
                  |                       |
                  |   tmux agent deck     |
                  |   Git worktrees       |
                  |   update guard        |
                  +-----------+-----------+
                              |
                  +-----------+-----------+
                  |                       |
              Anthropic                OpenAI
```

Hermes is the persistent service layer. VS Code, Antigravity, Telegram, and ordinary SSH terminals are simply different ways to reach the same machine and the same underlying agent environment.

## Quick start

Clone the repository and run the installer:

```bash
git clone https://github.com/bdeanmancom/Hermes-Claude-Subsciption-installer.git
cd Hermes-Claude-Subsciption-installer
chmod +x setup-hermes-claude.sh
./setup-hermes-claude.sh
```

That performs the core Hermes + Claude setup without enabling the optional workspace modules.

### Build the full workstation

```bash
./setup-hermes-claude.sh --all
```

That enables VS Code helpers, Antigravity integration, the persistent tmux agent deck, and per-agent worktrees.

## Choose your front end

You do **not** have to pick one editor or client.

### VS Code

Use VS Code Remote SSH as the main desktop cockpit while Hermes, tmux, credentials, and agent state remain on the Linux host.

```bash
./setup-hermes-claude.sh --vscode --multi-agent
```

The generated workspace includes tasks for attaching to the Hermes agent deck and running health/auth checks.

### Antigravity

Use Antigravity as an additional interactive AI IDE while keeping Hermes as the persistent backend.

```bash
./setup-hermes-claude.sh --antigravity
```

### Telegram

Keep the Hermes gateway available for lightweight remote access, mobile requests, and checking on long-running work away from your desk.

### SSH / terminal

Nothing requires a GUI. SSH into the machine and attach directly to the persistent tmux session:

```bash
tmux attach -t hermes-agents
```

## Multi-agent mode

Enable the persistent four-role deck:

```bash
./setup-hermes-claude.sh --multi-agent
```

Default roles:

```text
architect
implementer
reviewer
research
```

Each role gets its own tmux window. If matching agent worktrees exist, each window opens directly inside its own checkout.

You can override the session name:

```bash
HERMES_TMUX_SESSION=my-agents ./setup-hermes-claude.sh --multi-agent
```

VS Code and Antigravity helpers honor the same configured session name.

## Isolated Git worktrees

For concurrent coding agents, give each role its own Git worktree:

```bash
./setup-hermes-claude.sh --worktrees ~/src/my-project
```

By default they are created under:

```text
~/hermes-worktrees/
├── architect/
├── implementer/
├── reviewer/
└── research/
```

with matching branches such as:

```text
agent/architect
agent/implementer
agent/reviewer
agent/research
```

The worktree setup understands linked Git worktrees and safely handles agent branches that are already checked out elsewhere.

## Provider configuration

The installer configures Hermes with Anthropic as the default provider and supports OpenAI direct API access when `OPENAI_API_KEY` is available.

Provider credentials should stay in supported credential stores or local configuration such as:

```text
~/.hermes/.env
```

Never commit API keys or local credentials to this repository.

Model choices can be overridden with environment variables rather than editing the scripts, for example:

```bash
CLAUDE_MODEL=your-claude-model \
OPENAI_MODEL=your-openai-model \
./setup-hermes-claude.sh
```

## Claude Code authentication

If Claude Code is not yet authenticated:

```bash
claude
```

Complete the Claude login, exit the CLI, then rerun the setup script.

The installer runs diagnostics and checks for local Claude credentials before attempting Anthropic smoke tests.

## Update resilience

AI tooling moves quickly, and a working setup should not become confetti after an update.

The repository includes an update guard that re-checks the Hermes installation after changes and verifies important pieces such as:

- Hermes configuration
- provider/model defaults
- `hermes doctor`
- authentication status
- OpenAI key availability
- local `hermes-claude-auth` checkout health/drift

For a guarded manual update:

```bash
./hermes-safe-update.sh
```

Guard logs are written under:

```text
~/.hermes/logs/
```

## Optional `hermes-claude-auth` checkout

The installer keeps a persistent clone of:

```text
https://github.com/kristianvast/hermes-claude-auth
```

at:

```text
~/hermes-claude-auth
```

If that checkout contains local changes, this project intentionally skips `git pull` instead of overwriting them.

This repository does **not** automatically execute third-party authentication-bypass patches. It can clone and health-check the optional project, while the core installer remains focused on supported Hermes, Claude Code, provider, workspace, and multi-agent setup.

## Installer options

```text
--vscode              Create VS Code Remote SSH workspace/tasks
--antigravity         Create Antigravity integration helpers/notes
--multi-agent         Create the persistent tmux agent deck
--worktrees [PATH]    Create per-agent Git worktrees
--all                 Enable all optional modules
-h, --help            Show installer help
```

Examples:

```bash
./setup-hermes-claude.sh --vscode
./setup-hermes-claude.sh --antigravity
./setup-hermes-claude.sh --vscode --multi-agent
./setup-hermes-claude.sh --worktrees ~/src/my-project
./setup-hermes-claude.sh --all
```

## Useful commands

```bash
hermes doctor
hermes auth list
hermes model
hermes gateway setup

tmux ls
tmux attach -t hermes-agents
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

## Design philosophy

This project deliberately keeps the pieces loosely coupled:

**Hermes owns persistence.** Editors come and go.

**tmux owns terminal continuity.** SSH disconnects should not kill your agents.

**Git worktrees own edit isolation.** Multiple coding agents should not fight over one checkout.

**Provider configuration stays portable.** The workstation should be able to use different model providers without rebuilding the whole environment.

**Front ends stay optional.** VS Code, Antigravity, Telegram, or plain SSH can all coexist around the same Hermes host.

That turns one Linux box into something closer to a small self-hosted AI operations console than a single-purpose chat client.
