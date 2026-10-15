#!/usr/bin/env bash

# Passwordless fwupd for unattended topgrade runs. The "Firmware upgrades"
# step prompts for a password because polkit gates fwupd's metadata refresh
# and firmware installs; that gate is independent of NOPASSWD sudo, so a
# sudoers file cannot lift it. This installs a polkit rule that allows both
# actions for wheel users.
# One-time system setup; run manually, requires sudo.

# Re-exec under Bash when invoked from another shell (e.g. zsh fwupd_polkit.sh).
source "$(dirname "$0")/lib/bash_compat.sh"

set -euo pipefail

RULE_DIR="/etc/polkit-1/rules.d"
RULE_FILE="$RULE_DIR/49-fwupd-passwordless.rules"

RULE='polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel") &&
        (action.id == "org.freedesktop.fwupd.refresh-remote" ||
         action.id == "org.freedesktop.fwupd.update-internal")) {
        return polkit.Result.YES;
    }
});'

if ! command -v fwupdmgr >/dev/null 2>&1; then
    echo "fwupdmgr not found; no fwupd on this host, nothing to do."
    exit 0
fi

current="$(sudo cat "$RULE_FILE" 2>/dev/null || true)"
if [[ "$current" == "$RULE" ]]; then
    echo "Already installed: $RULE_FILE"
    exit 0
fi

if [[ -n "$current" ]]; then
    stamp="$(date +%Y%m%d_%H%M%S)"
    sudo cp -a "$RULE_FILE" "$RULE_FILE.backup.$stamp"
    echo "Backed up existing rule: $RULE_FILE.backup.$stamp"
fi

sudo mkdir -p "$RULE_DIR"
printf '%s\n' "$RULE" | sudo tee "$RULE_FILE" >/dev/null
sudo chmod 0644 "$RULE_FILE"

# The 49- prefix keeps this rule ahead of distro 50-* files; polkitd watches
# rules.d and reloads on change, so no service restart is needed.
echo "Installed: $RULE_FILE"
echo "Verify with: fwupdmgr refresh   # should run with no password prompt"
