#!/usr/bin/env bash

# Zenless NFS mountpoint self-heal for macOS.
#
# GitHub Desktop only lists real volumes under /Volumes, so the autofs map
# (/etc/auto_nfs) mounts the zenless NFS export at /Volumes/Zenless.
# macOS prunes non-volume directories under /Volumes, and automountd refuses
# to create mountpoints there, so after some reboots every access fails with
# ENOENT before NFS is even attempted. The autofs map itself is fine; only
# the mountpoint vanishes.
#
# Fix: a root LaunchDaemon recreates the mountpoint and refreshes automount
# at boot (plus a 15-minute safety net, since prune timing is not documented).
# The NFS mount itself stays lazy via autofs: it mounts on first path access,
# so a sleeping zenless never blocks boot. Do not force-mount here.
#
# Usage:
#   zenless_mount.sh install   Install/refresh the LaunchDaemon (sudo)
#   zenless_mount.sh plist     Print the embedded plist (no changes)
#   zenless_mount.sh status    Show daemon + mountpoint + mount state

# Re-exec under Bash when invoked from another shell (e.g. zsh zenless_mount.sh).
source "$(dirname "$0")/lib/bash_compat.sh"

set -euo pipefail

LABEL="com.user.zenless-mount"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"
MOUNT_POINT="/Volumes/Zenless"
SERVER="192.168.10.100"
AUTO_NFS="/etc/auto_nfs"

print_plist() {
    # && is XML-escaped; launchd hands the string to /bin/bash verbatim.
    cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.zenless-mount</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>[[ -d /Volumes/Zenless ]] || { mkdir /Volumes/Zenless &amp;&amp; /usr/sbin/automount -vc; }</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>900</integer>
</dict>
</plist>
EOF
}

repair_now() {
    # Same job the daemon does, run once so the fix lands without a reboot.
    if [[ -d "$MOUNT_POINT" ]]; then
        echo "Mountpoint already present: $MOUNT_POINT"
    else
        echo "Recreating mountpoint $MOUNT_POINT..."
        sudo mkdir "$MOUNT_POINT"
        sudo automount -vc
    fi

    # autofs mounts on first access. Trigger it only when the server answers,
    # otherwise `ls` blocks until the NFS timeout.
    if ping -c 1 -t 2 "$SERVER" >/dev/null 2>&1; then
        echo "Triggering lazy mount (server $SERVER reachable)..."
        ls "$MOUNT_POINT" >/dev/null
        echo "Mounted: $(mount | grep -F "$MOUNT_POINT" || echo 'will appear on next access')"
    else
        echo "Server $SERVER unreachable; mount will appear on first access once it is up."
    fi
}

do_install() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo "ERROR: macOS-only script (this machine: $(uname -s))." >&2
        exit 1
    fi

    if [[ ! -f "$AUTO_NFS" ]] || ! grep -q "^$MOUNT_POINT " "$AUTO_NFS"; then
        echo "ERROR: $AUTO_NFS has no entry for $MOUNT_POINT." >&2
        echo "The autofs map is machine-local; set it up before installing the daemon." >&2
        exit 1
    fi

    local tmp
    tmp="$(mktemp)"
    print_plist >"$tmp"

    if ! plutil -lint "$tmp" >/dev/null; then
        echo "ERROR: generated plist failed plutil lint." >&2
        rm -f "$tmp"
        exit 1
    fi

    echo "Installing $PLIST (sudo required)..."
    sudo cp "$tmp" "$PLIST"
    rm -f "$tmp"
    sudo chown root:wheel "$PLIST"
    sudo chmod 644 "$PLIST"

    # Idempotent reload: bootout ignores "not loaded", bootstrap re-registers.
    sudo launchctl bootout "system/$LABEL" 2>/dev/null || true
    sudo launchctl bootstrap system "$PLIST"

    repair_now

    echo ""
    echo "Done. The daemon recreates the mountpoint at every boot and every 15 minutes."
    echo "Verify later with: sudo launchctl print system/$LABEL"
}

do_status() {
    echo "== Daemon =="
    sudo launchctl print "system/$LABEL" 2>/dev/null | grep -E 'state|program' | head -4 \
        || echo "not loaded ($PLIST missing or never bootstrapped)"
    echo "== Mountpoint =="
    ls -ld "$MOUNT_POINT" 2>/dev/null || echo "MISSING (daemon should recreate it within 5 min)"
    echo "== Mount =="
    mount | grep -F "$MOUNT_POINT" || echo "not mounted (autofs is lazy; access the path to mount)"
}

case "${1:-install}" in
    install) do_install ;;
    plist)   print_plist ;;
    status)  do_status ;;
    *)
        echo "Usage: $0 {install|plist|status}" >&2
        exit 1
        ;;
esac
