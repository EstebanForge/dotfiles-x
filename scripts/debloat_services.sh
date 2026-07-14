#!/usr/bin/env bash

# Safe systemd service debloat for Fedora.
# Disables a small set of unconditionally-safe-to-remove services and removes
# the deprecated ABRT crash-reporting stack. Deliberately conservative: many
# "debloat" lists online include services whose removal silently breaks things
# (auditd = kernel security logs, gssproxy = NFS/Kerberos, sssd-kcm = login
# credential cache, switcheroo-control = hybrid GPU, colord = color profiles).
# None of those are touched here.

# Reference: Fedora Project Leader Matthew Miller on this exact class of list:
# https://discussion.fedoraproject.org/t/disabling-unsafe-services-in-fedora/69395
# ("I would ignore this tool [Lynis/systemd-analyze security] entirely.")

# Re-exec under Bash when invoked from another shell (e.g. zsh debloat_services.sh).
source "$(dirname "$0")/lib/bash_compat.sh"

set -euo pipefail

echo "=== Fedora service debloat (safe wins only) ==="

# Services that are dead weight on a typical personal workstation without a
# modem, smart-card reader, or the need to receive inbound SSH. Each disable is
# guarded: a unit that doesn't exist on this spin must not abort the run.
DEBLOAT_SERVICES=(
    ModemManager.service      # mobile broadband management; no modem = unused
    atd.service               # legacy `at` scheduler; superseded by systemd timers
    pcscd.service             # smart card reader daemon; no reader = unused
    pcscd.socket              # pcscd activation socket (keeps it from respawning)
    sshd.service              # inbound SSH server; disable if you don't ssh INTO this box
)

for svc in "${DEBLOAT_SERVICES[@]}"; do
    # `systemctl cat` is the cheapest existence check; ignore failures so a
    # missing unit (e.g. pcscd not installed) is a no-op rather than fatal.
    if systemctl cat "$svc" >/dev/null 2>&1; then
        echo "Disabling $svc"
        sudo systemctl disable --now "$svc" 2>/dev/null || true
    else
        echo "Skipping $svc (not installed)"
    fi
done

# ABRT is deprecated: the GUI (gnome-abrt) was removed in Fedora 44 and the
# framework is slated for full removal in F45 (retrace server doesn't support
# F43/F44, no maintainers). Removing the packages is cleaner than disabling
# four services that are already half-removed upstream.
# See: https://discussion.fedoraproject.org/t/last-call-to-save-abrt/188901
if rpm -q abrt >/dev/null 2>&1; then
    echo "Removing deprecated ABRT crash-reporting stack..."
    sudo dnf remove -y abrt abrt-addon-* abrt-journal-core abrt-oops abrt-xorg abrt-retrace-client 2>/dev/null || true
else
    echo "ABRT already removed."
fi

echo "Debloat complete."
