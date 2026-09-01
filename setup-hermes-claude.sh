#!/usr/bin/env bash
# ==============================================================================
# setup-hermes-claude.sh
# Repeatable setup for Claude Code + Hermes Agent on Linux / WSL2
# Supports Anthropic + OpenAI direct API
# ============================================================================== 

set -Eeuo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_ENV="$HERMES_HOME/.env"
PATCH_REPO="$HOME/hermes-claude-auth"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLAUDE_MODEL="${CLAUDE_MODEL:-claude-opus-5}"
CLAUDE_MODEL_FALLBACK_1="${CLAUDE_MODEL_FALLBACK_1:-claude-opus-4-8}"
CLAUDE_MODEL_FALLBACK_2="${CLAUDE_MODEL_FALLBACK_2:-claude-sonnet-5}"

OPENAI_MODEL="${OPENAI_MODEL:-gpt-5.6-sol}"
OPENAI_MODEL_FALLBACK_1="${OPENAI_MODEL_FALLBACK_1:-gpt-5.6-terra}"
OPENAI_MODEL_FALLBACK_2="${OPENAI_MODEL_FALLBACK_2:-gpt-5.6-luna}"

HERMES_INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"
CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
PATCH_REPO_URL="https://github.com/kristianvast/hermes-claude-auth.git"

if [[ -t 1 ]]; then
    GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
else
    GREEN=''; BLUE=''; YELLOW=''; RED=''; BOLD=''; NC=''
fi

info()    { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
die()     { error "$*"; exit 1; }

on_error() {
    local exit_code=$?
    local line_no=$1
    error "Setup failed at line ${line_no}, exit code ${exit_code}."
    exit "$exit_code"
}
trap 'on_error $LINENO' ERR

command_exists() { command -v "$1" >/dev/null 2>&1; }
ensure_path() { export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"; }

banner() {
    printf "\n${GREEN}${BOLD}"
    printf '%s\n' "============================================================"
    printf '%s\n' "      Hermes Agent + Claude Code + OpenAI Setup"
    printf '%s\n' "============================================================"
    printf "${NC}\n"
}

install_base_dependencies() {
    local missing=()
    for cmd in git curl; do command_exists "$cmd" || missing+=("$cmd"); done
    [[ ${#missing[@]} -eq 0 ]] && { success "Base dependencies already installed."; return; }

    warn "Missing dependencies: ${missing[*]}"
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y git curl ca-certificates xz-utils
    elif command_exists dnf; then
        sudo dnf install -y git curl ca-certificates xz
    elif command_exists pacman; then
        sudo pacman -Sy --needed --noconfirm git curl ca-certificates xz
    else
        die "Unsupported package manager. Install git, curl, ca-certificates, and xz manually."
    fi
}

install_claude() {
    info "Checking Claude Code..."
    if command_exists claude; then
        success "Claude Code already installed: $(claude --version 2>/dev/null || printf 'version unknown')"
        return
    fi
    curl -fsSL "$CLAUDE_INSTALL_URL" | bash
    ensure_path
    hash -r
    command_exists claude || die "Claude installer completed but claude is not in PATH."
    success "Claude Code installed."
}

check_claude_auth() {
    claude doctor >/dev/null 2>&1 || warn "Claude Code diagnostic reported an issue."
    if [[ -f "$HOME/.claude/.credentials.json" ]]; then
        success "Claude credential file found."
        return 0
    fi
    warn "Claude authentication not confirmed. Run 'claude', log in, then rerun setup."
    return 1
}

install_hermes() {
    ensure_path
    if command_exists hermes && [[ -d "$HERMES_HOME/hermes-agent" ]]; then
        success "Hermes Agent already installed."
        return
    fi
    info "Running official Hermes installer..."
    curl -fsSL "$HERMES_INSTALL_URL" | bash
    ensure_path
    hash -r
    command_exists hermes || die "Hermes installation completed but hermes is not in PATH."
    success "Hermes Agent installed."
}

update_or_clone_patch_repo() {
    info "Preparing optional repository at $PATCH_REPO"
    if [[ -d "$PATCH_REPO/.git" ]]; then
        if [[ -n "$(git -C "$PATCH_REPO" status --porcelain)" ]]; then
            warn "hermes-claude-auth has local changes; skipping pull."
        else
            git -C "$PATCH_REPO" pull --ff-only
        fi
    elif [[ -e "$PATCH_REPO" ]]; then
        die "$PATCH_REPO exists but is not a Git repository."
    else
        git clone "$PATCH_REPO_URL" "$PATCH_REPO"
    fi
    success "Optional repository available at $PATCH_REPO."
    warn "Its authentication-bypass installer is not executed by this script."
}

configure_hermes() {
    hermes config set model.provider anthropic
    hermes config set model.default "$CLAUDE_MODEL"
    success "Hermes default provider/model configured: anthropic / $CLAUDE_MODEL"
}

install_update_guard() {
    local installer="$SCRIPT_DIR/install-update-guard.sh"
    if [[ -f "$installer" ]]; then
        chmod +x "$installer"
        if "$installer"; then
            success "Automatic Hermes post-update guard enabled."
        else
            warn "Automatic update guard could not be enabled; use hermes-safe-update.sh when updating."
        fi
    else
        warn "install-update-guard.sh not found; automatic post-update guard not installed."
    fi
}

load_hermes_env() {
    if [[ -f "$HERMES_ENV" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "$HERMES_ENV"
        set +a
    fi
}

check_openai_auth() {
    load_hermes_env
    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        success "OPENAI_API_KEY detected."
        return 0
    fi
    warn "OPENAI_API_KEY not detected. Add it to $HERMES_ENV to enable OpenAI smoke tests."
    return 1
}

smoke_test_model() {
    local provider="$1" model="$2"
    hermes chat --provider "$provider" --model "$model" -q "Reply with exactly: AUTH TEST OK" -Q
}

smoke_test_anthropic() {
    smoke_test_model anthropic "$CLAUDE_MODEL" || \
    smoke_test_model anthropic "$CLAUDE_MODEL_FALLBACK_1" || \
    smoke_test_model anthropic "$CLAUDE_MODEL_FALLBACK_2"
}

smoke_test_openai() {
    smoke_test_model openai-api "$OPENAI_MODEL" || \
    smoke_test_model openai-api "$OPENAI_MODEL_FALLBACK_1" || \
    smoke_test_model openai-api "$OPENAI_MODEL_FALLBACK_2"
}

summary() {
    printf '\n${GREEN}${BOLD}Setup complete.${NC}\n'
    printf 'Hermes home:       %s\n' "$HERMES_HOME"
    printf 'Claude default:    %s\n' "$CLAUDE_MODEL"
    printf 'Claude fallbacks:  %s, %s\n' "$CLAUDE_MODEL_FALLBACK_1" "$CLAUDE_MODEL_FALLBACK_2"
    printf 'OpenAI primary:    %s\n' "$OPENAI_MODEL"
    printf 'OpenAI fallbacks:  %s, %s\n' "$OPENAI_MODEL_FALLBACK_1" "$OPENAI_MODEL_FALLBACK_2"
    printf 'Update guard log:  %s/logs/post-update-guard.log\n' "$HERMES_HOME"
    printf '\nFor a guarded manual update: ./hermes-safe-update.sh\n'
}

main() {
    banner
    ensure_path
    install_base_dependencies
    install_claude

    local claude_auth_ok=1 openai_auth_ok=1
    check_claude_auth || claude_auth_ok=0

    install_hermes
    update_or_clone_patch_repo
    configure_hermes
    install_update_guard

    hermes doctor || warn "Hermes doctor reported one or more issues."
    hermes auth list || warn "Could not read Hermes auth status."
    check_openai_auth || openai_auth_ok=0

    [[ "$claude_auth_ok" -eq 1 ]] && smoke_test_anthropic || true
    [[ "$openai_auth_ok" -eq 1 ]] && smoke_test_openai || true

    summary
}

main "$@"
