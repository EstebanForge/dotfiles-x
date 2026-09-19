#!/usr/bin/env bash

# Zenless symlink self-heal for macOS.
#
# The zenless NFS export is autofs-mounted at /System/Volumes/Data/mnt/Zenless
# (/etc/auto_nfs; the sealed root volume is read-only, so /mnt cannot exist).
# GUI apps only list real volumes under /Volumes, so /Volumes/Zenless is a
# symlink to the trigger. macOS prunes non-volume entries under /Volumes
# after reboots; the 2026-09 version of this daemon then recreated the path
# as a real directory, which broke the link instead of healing it.
#
# Fix: a root LaunchDaemon restores the symlink at boot (plus a 15-minute
# safety net, since prune timing is not documented). The installer also wires
# /etc/auto_nfs into /etc/auto_master as a direct map (/-) and refreshes
# automount, so the /mnt/Zenless trigger exists; an orphaned map file mounts
# nothing. The NFS mount stays lazy via autofs: it mounts on first path
# access, so a sleeping zenless never blocks boot. Do not force-mount here.
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
MOUNT_POINT="/Volumes/Zenless"   # symlink, recreated when the pruner eats it
# Real autofs trigger; must match /etc/auto_nfs. Lives under the Data volume:
# the root volume is sealed read-only, so /mnt cannot exist on modern macOS.
REAL_MOUNT="/System/Volumes/Data/mnt/Zenless"
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
        <string>[[ -L /Volumes/Zenless &amp;&amp; "$(readlink /Volumes/Zenless)" = "/System/Volumes/Data/mnt/Zenless" ]] || { rmdir /Volumes/Zenless 2>/dev/null; ln -sf /System/Volumes/Data/mnt/Zenless /Volumes/Zenless; }</string>
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
    # -e follows the link to a lazy autofs target that may not stat as
    # existing, so correctness is decided by -L + readlink, never -e alone.
    if [[ -L "$MOUNT_POINT" && "$(readlink "$MOUNT_POINT")" == "$REAL_MOUNT" ]]; then
        echo "Symlink already present: $MOUNT_POINT -> $REAL_MOUNT"
    else
        # Missing, wrong target, or wrong shape. rmdir only succeeds on an
        # empty real dir (a non-empty one fails visibly under set -e and is
        # left untouched); ln -sf replaces a symlink of any target.
        sudo rmdir "$MOUNT_POINT" 2>/dev/null || true
        echo "Creating symlink $MOUNT_POINT -> $REAL_MOUNT..."
        sudo ln -sf "$REAL_MOUNT" "$MOUNT_POINT"
    fi

    # autofs mounts on first access. Trigger it only when the server answers,
    # otherwise `ls` blocks until the NFS timeout.
    if ping -c 1 -t 2 "$SERVER" >/dev/null 2>&1; then
        echo "Triggering lazy mount (server $SERVER reachable)..."
        ls "$MOUNT_POINT" >/dev/null
        echo "Mounted: $(mount | grep -F "$REAL_MOUNT" || echo 'will appear on next access')"
    else
        echo "Server $SERVER unreachable; mount will appear on first access once it is up."
    fi
}

do_install() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo "ERROR: macOS-only script (this machine: $(uname -s))." >&2
        exit 1
    fi

    # Older iterations pointed the map at /mnt/Zenless, which cannot exist on
    # the sealed root volume. Repoint the key to REAL_MOUNT, keeping options
    # and the export target untouched.
    if [[ -f "$AUTO_NFS" ]] && ! grep -q "^$REAL_MOUNT " "$AUTO_NFS"; then
        echo "Repointing $AUTO_NFS key to $REAL_MOUNT..."
        sudo sed -i '' -E "1s|^[[:space:]]*[^[:space:]]+|$REAL_MOUNT|" "$AUTO_NFS"
    fi

    if [[ ! -f "$AUTO_NFS" ]] || ! grep -q "^$REAL_MOUNT " "$AUTO_NFS"; then
        echo "ERROR: $AUTO_NFS has no entry for $REAL_MOUNT." >&2
        echo "The autofs map is machine-local; set it up before installing the daemon." >&2
        exit 1
    fi

    # Wire the map into the master table (idempotent). Without this entry the
    # map file is orphaned: automountd never reads it, the lazy trigger never
    # exists, and the symlink dangles with no mount.
    # Literal backslash-t garbage (from a printf whose escapes did not
    # expand): ONE backslash before the t. Filter through a temp file
    # plus cp; never rewrite a file in place from its own pipeline.
    if grep -q '^/-\\t' /etc/auto_master; then
        echo "Repairing malformed auto_master entry..."
        tmp_master="$(mktemp)"
        grep -v '^/-\\t' /etc/auto_master >"$tmp_master"
        sudo cp "$tmp_master" /etc/auto_master
        sudo chown root:wheel /etc/auto_master
        sudo chmod 644 /etc/auto_master
        rm -f "$tmp_master"
    fi
    if ! grep -Eq '^/-[[:space:]]+auto_nfs([[:space:]]|$)' /etc/auto_master; then
        echo "Adding auto_nfs direct-map entry to /etc/auto_master..."
        printf '/-\t\t\tauto_nfs\t\t-nosuid\n' | sudo tee -a /etc/auto_master >/dev/null
    fi

    # Direct maps need the mountpoint present; automountd mounts over the stub.
    sudo mkdir -p "$REAL_MOUNT"
    sudo automount -vc

    # Fail loudly if no autofs trigger came up: a plain empty directory
    # at $REAL_MOUNT would pass every shape check while mounting nothing.
    if ! mount | grep -F "$REAL_MOUNT" >/dev/null; then
        echo "ERROR: no autofs trigger at $REAL_MOUNT after automount -vc." >&2
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

    # Heal BEFORE bootstrapping the daemon: RunAtLoad fires on bootstrap and
    # would race repair_now for the same ln -s (loser dies on "File exists").
    repair_now

    # Idempotent reload: bootout ignores "not loaded", bootstrap re-registers.
    sudo launchctl bootout "system/$LABEL" 2>/dev/null || true
    sudo launchctl bootstrap system "$PLIST"

    echo ""
    echo "Done. The daemon restores the symlink at every boot and every 15 minutes."
    echo "Verify later with: sudo launchctl print system/$LABEL"
}

do_status() {
    echo "== Daemon =="
    sudo launchctl print "system/$LABEL" 2>/dev/null | grep -E 'state|program' | head -4 \
        || echo "not loaded ($PLIST missing or never bootstrapped)"
    echo "== Mountpoint =="
    ls -ld "$MOUNT_POINT" 2>/dev/null || echo "MISSING (daemon restores it within 15 min)"
    echo "== Mount =="
    mount | grep -F "$REAL_MOUNT" || echo "not mounted (autofs is lazy; access the path to mount)"
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
