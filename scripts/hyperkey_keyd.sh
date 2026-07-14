#!/usr/bin/env bash

# Hyperkey setup for Linux via keyd: Capslock becomes a "hyper" modifier
# (Ctrl+Shift+Alt+Super simultaneously) when held, Escape when tapped, with
# hjkl as arrow keys in the held layer. A personal macOS-Superkey-equivalent.
#
# Fedora-only: keyd has no Debian package (Fedora COPR + Arch AUR only).
# Uses the fmonteghetti/keyd COPR (maintained Fedora builds).
#
# Owns ALL keyd setup: COPR enable, package install, config, service. Sourced
# nothing; runs standalone. Called by install_rpm.sh.
#
# Config reference: https://github.com/rvaiya/keyd/blob/master/docs/keyd.scdoc

# Re-exec under Bash when invoked from another shell (e.g. zsh hyperkey_keyd.sh).
source "$(dirname "$0")/lib/bash_compat.sh"

set -euo pipefail

KEYD_CONF_DIR="/etc/keyd"
KEYD_CONF_FILE="$KEYD_CONF_DIR/default.conf"
KEYD_COPR="fmonteghetti/keyd"

echo "=== Hyperkey (keyd) setup ==="

# 1. Install keyd from COPR (idempotent)
if ! rpm -q keyd >/dev/null 2>&1; then
    echo "Installing keyd from COPR ($KEYD_COPR)..."
    # keyd is not in Fedora repos; fmonteghetti/keyd is the maintained build.
    # Skip `copr enable` if the repo is already enabled (avoids warning reprint).
    if ! ls /etc/yum.repos.d/_copr*fmonteghetti*keyd*.repo >/dev/null 2>&1; then
        sudo dnf copr enable -y "$KEYD_COPR"
    fi
    sudo dnf install -y keyd
else
    echo "keyd already installed."
fi

# 2. Write the hyperkey config (idempotent: rewrite every run so config drift
#    is corrected; the file is small and authoritative here).
echo "Writing keyd config ($KEYD_CONF_FILE)..."
sudo mkdir -p "$KEYD_CONF_DIR"
sudo tee "$KEYD_CONF_FILE" >/dev/null <<'EOF'
# Hyperkey config: Capslock = overload layer + esc on tap.
# Layer modifier set C-S-A-M = Ctrl+Shift+Alt+Super (true "hyper" modifier).
# hjkl produce arrow keys while Capslock is held.
# Ref: https://github.com/rvaiya/keyd/blob/master/docs/keyd.scdoc

[ids]
*

[main]
capslock = overload(capslock_layer, esc)

[capslock_layer:C-S-A-M]
h = left
j = down
k = up
l = right
EOF

# 3. Enable + (re)start keyd so the new config is loaded immediately.
echo "Enabling + restarting keyd service..."
sudo systemctl enable --now keyd
sudo systemctl restart keyd

# 4. Verify (informational; not fatal under set -e)
if systemctl is-active --quiet keyd; then
    echo "keyd is running."
else
    echo "WARNING: keyd did not report active. Check: sudo journalctl -eu keyd" >&2
fi

echo "Hyperkey setup complete."
echo "Tip: 'sudo keyd reload' picks up config edits without a full restart."
