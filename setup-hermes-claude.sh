#!/usr/bin/env bash
# ==============================================================================
# setup-hermes-claude.sh
# Repeatable setup for Claude Code + Hermes Agent on Linux / WSL2
# ==============================================================================

set -Eeuo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PATCH_REPO="$HOME/hermes-claude-auth"

# Current preferred Claude models, ordered strongest/default to fallback.
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-opus-5}"
CLAUDE_MODEL_FALLBACK_1="${CLAUDE_MODEL_FALLBACK_1:-claude-opus-4-8}"
CLAUDE_MODEL_FALLBACK_2="${CLAUDE_MODEL_FALLBACK_2:-claude-sonnet-5}"

HERMES_INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"
CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
PATCH_REPO_URL="https://github.com/kristianvast/hermes-claude-auth.git"

if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''
    BLUE=''
    YELLOW=''
    RED=''
    BOLD=''
    NC=''
fi

info()    { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

die() {
    error "$*"
    exit 1
}

on_error() {
    local exit_code=$?
    local line_no=$1
    error "Setup failed at line ${line_no}, exit code ${exit_code}."
    exit "$exit_code"
}

trap 'on_error $LINENO' ERR

banner() {
    printf "\n${GREEN}${BOLD}"
    printf '%s\n' "============================================================"
    printf '%s\n' "        Hermes Agent + Claude Code Setup"
    printf '%s\n' "============================================================"
    printf "${NC}\n"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_path() {
    export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
}

install_base_dependencies() {
    local missing=()

    for cmd in git curl; do
        command_exists "$cmd" || missing+=("$cmd")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        success "Base dependencies already installed."
        return
    fi

    warn "Missing dependencies: ${missing[*]}"

    if command_exists apt-get; then
        info "Installing dependencies with apt..."
        sudo apt-get update
        sudo apt-get install -y git curl ca-certificates xz-utils
    elif command_exists dnf; then
        info "Installing dependencies with dnf..."
        sudo dnf install -y git curl ca-certificates xz
    elif command_exists pacman; then
        info "Installing dependencies with pacman..."
        sudo pacman -Sy --needed --noconfirm git curl ca-certificates xz
    else
        die "Unsupported package manager. Install git, curl, ca-certificates, and xz manually."
    fi

    for cmd in git curl; do
        command_exists "$cmd" || die "$cmd is still unavailable after installation."
    done

    success "Base dependencies installed."
}

install_claude() {
    info "Checking Claude Code..."

    if command_exists claude; then
        success "Claude Code already installed: $(claude --version 2>/dev/null || printf 'version unknown')"
        return
    fi

    info "Installing Claude Code using Anthropic's native installer..."
    curl -fsSL "$CLAUDE_INSTALL_URL" | bash

    ensure_path
    hash -r

    command_exists claude || die \
        "Claude installer completed but 'claude' is not in PATH. Open a new shell and rerun this script."

    success "Claude Code installed: $(claude --version 2>/dev/null || printf 'installed')"
}

check_claude_auth() {
    info "Checking Claude Code installation/authentication..."

    if claude doctor >/dev/null 2>&1; then
        success "Claude Code diagnostic completed successfully."
    else
        warn "Claude Code diagnostic reported an issue."
    fi

    if [[ -f "$HOME/.claude/.credentials.json" ]]; then
        success "Claude credential file found."
        return 0
    fi

    warn "Claude Code authentication has not been confirmed."
    printf '\nRun:\n\n'
    printf '    claude\n\n'
    printf 'Complete the Claude.ai login if prompted, exit Claude, then rerun this script.\n\n'
    return 1
}

install_hermes() {
    info "Checking Hermes Agent..."
    ensure_path

    if command_exists hermes && [[ -d "$HERMES_HOME/hermes-agent" ]]; then
        success "Hermes Agent already installed."
        return
    fi

    info "Running official Hermes installer..."
    curl -fsSL "$HERMES_INSTALL_URL" | bash

    ensure_path
    hash -r

    command_exists hermes || die \
        "Hermes installation completed but 'hermes' is not available in PATH."

    success "Hermes Agent installed."
}

update_or_clone_patch_repo() {
    info "Preparing optional repository at: $PATCH_REPO"

    if [[ -d "$PATCH_REPO/.git" ]]; then
        if [[ -n "$(git -C "$PATCH_REPO" status --porcelain)" ]]; then
            warn "Repository contains local changes. Skipping git pull so nothing gets overwritten."
        else
            info "Updating repository..."
            git -C "$PATCH_REPO" pull --ff-only
        fi
    elif [[ -e "$PATCH_REPO" ]]; then
        die "$PATCH_REPO exists but is not a Git repository."
    else
        info "Cloning repository..."
        git clone "$PATCH_REPO_URL" "$PATCH_REPO"
    fi

    success "Repository available at $PATCH_REPO."
    info "Repository commit: $(git -C "$PATCH_REPO" rev-parse --short HEAD)"
    warn "The repository's OAuth bypass installer was NOT executed."
}

configure_hermes() {
    info "Configuring Hermes Anthropic provider..."

    hermes config set model.provider anthropic
    hermes config set model.default "$CLAUDE_MODEL"

    success "Hermes default provider: anthropic"
    success "Hermes default model: $CLAUDE_MODEL"
    info "Fallback models: $CLAUDE_MODEL_FALLBACK_1, $CLAUDE_MODEL_FALLBACK_2"
}

diagnose_hermes() {
    info "Running Hermes diagnostics..."

    if hermes doctor; then
        success "Hermes doctor passed."
    else
        warn "Hermes doctor reported one or more issues."
        return 1
    fi
}

show_auth_status() {
    info "Hermes authentication status:"
    hermes auth list || warn "'hermes auth list' did not complete successfully."
}

smoke_test_model() {
    local model="$1"

    info "Testing model: $model"
    if hermes chat \
        --provider anthropic \
        --model "$model" \
        -q "Reply with exactly: AUTH TEST OK" \
        -Q
    then
        success "Smoke test passed with $model."
        return 0
    fi

    warn "Smoke test failed with $model."
    return 1
}

smoke_test() {
    printf '%s\n' "------------------------------------------------------------"

    if smoke_test_model "$CLAUDE_MODEL"; then
        printf '%s\n' "------------------------------------------------------------"
        return 0
    fi

    warn "Primary model unavailable. Trying $CLAUDE_MODEL_FALLBACK_1..."
    if smoke_test_model "$CLAUDE_MODEL_FALLBACK_1"; then
        printf '%s\n' "------------------------------------------------------------"
        return 0
    fi

    warn "Second model unavailable. Trying $CLAUDE_MODEL_FALLBACK_2..."
    if smoke_test_model "$CLAUDE_MODEL_FALLBACK_2"; then
        printf '%s\n' "------------------------------------------------------------"
        return 0
    fi

    printf '%s\n' "------------------------------------------------------------"
    warn "Hermes could not complete an Anthropic smoke test with any configured model."
    return 1
}

summary() {
    printf '\n'
    printf "${GREEN}${BOLD}"
    printf '%s\n' "============================================================"
    printf '%s\n' "                    Setup Summary"
    printf '%s\n' "============================================================"
    printf "${NC}"

    printf 'Claude Code:   '
    command -v claude 2>/dev/null || printf 'NOT FOUND'
    printf '\n'

    printf 'Hermes:        '
    command -v hermes 2>/dev/null || printf 'NOT FOUND'
    printf '\n'

    printf 'Hermes home:   %s\n' "$HERMES_HOME"
    printf 'Default model: %s\n' "$CLAUDE_MODEL"
    printf 'Fallback #1:   %s\n' "$CLAUDE_MODEL_FALLBACK_1"
    printf 'Fallback #2:   %s\n' "$CLAUDE_MODEL_FALLBACK_2"
    printf 'Patch source:  %s\n' "$PATCH_REPO"

    printf '\nUseful commands:\n\n'
    printf '  hermes doctor\n'
    printf '  hermes auth list\n'
    printf '  hermes model\n'
    printf '  hermes chat --provider anthropic --model %s\n' "$CLAUDE_MODEL"
    printf '  hermes chat --provider anthropic --model %s\n' "$CLAUDE_MODEL_FALLBACK_1"
    printf '  hermes chat --provider anthropic --model %s\n' "$CLAUDE_MODEL_FALLBACK_2"
    printf '  hermes gateway setup\n'
    printf '\n'
}

main() {
    banner
    ensure_path
    install_base_dependencies
    install_claude

    local claude_auth_ok=1
    check_claude_auth || claude_auth_ok=0

    install_hermes
    update_or_clone_patch_repo
    configure_hermes
    diagnose_hermes || true
    show_auth_status || true

    if [[ "$claude_auth_ok" -eq 1 ]]; then
        smoke_test || true
    else
        warn "Skipping Anthropic smoke test until Claude authentication is complete."
    fi

    summary
}

main "$@"
