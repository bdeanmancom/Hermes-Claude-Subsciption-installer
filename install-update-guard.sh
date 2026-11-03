#!/usr/bin/env bash
set -Eeuo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POST_SCRIPT="$REPO_DIR/post-hermes-update.sh"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER_DIR/hermes-post-update.service"
PATH_FILE="$SYSTEMD_USER_DIR/hermes-post-update.path"
HERMES_GIT_LOG="$HERMES_HOME/hermes-agent/.git/logs/HEAD"

if [[ ! -x "$POST_SCRIPT" ]]; then
    chmod +x "$POST_SCRIPT"
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "[WARN] systemd/systemctl is not available on this system."
    echo "Use ./hermes-safe-update.sh for guarded manual updates."
    exit 0
fi

if [[ ! -e "$HERMES_GIT_LOG" ]]; then
    echo "[ERROR] Hermes Git log not found at: $HERMES_GIT_LOG"
    echo "Install Hermes first, then rerun this script."
    exit 1
fi

mkdir -p "$SYSTEMD_USER_DIR"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Hermes post-update repair and validation
After=default.target

[Service]
Type=oneshot
Environment=HERMES_HOME=$HERMES_HOME
ExecStart=$POST_SCRIPT
EOF

cat > "$PATH_FILE" <<EOF
[Unit]
Description=Watch Hermes for updates

[Path]
PathChanged=$HERMES_GIT_LOG
Unit=hermes-post-update.service

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now hermes-post-update.path

echo "[OK] Hermes automatic post-update guard installed."
echo "[OK] Watching: $HERMES_GIT_LOG"
echo "[OK] Service:  hermes-post-update.service"
echo "[OK] Path unit: hermes-post-update.path"
echo "[OK] Log:      $HERMES_HOME/logs/post-update-guard.log"
echo
echo "Status:"
systemctl --user --no-pager status hermes-post-update.path || true
