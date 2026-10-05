#!/usr/bin/env bash
set -euo pipefail

# Prune macOS AppleDouble junk that lands in $HOME via scp/rsync from a Mac
# (scp/SFTP have no server-side name filter, so cleanup happens after arrival).
# Names mirror the AppleDouble set in ~/.config/git/ignore; git never sees them.
# Files only, never dirs, never -rf. Safe to run from cron/systemd timers.
# Install as a systemd --user unit via `dots install` +
# `systemctl --user enable --now prune-macjunk.timer` (every 2 hours,
# Persistent=true).

if (( EUID == 0 )); then
    echo "refusing: run as user, not root" >&2
    exit 1
fi

names=(
    '._*'
    '.DS_Store'
    '.AppleDouble'
    '.AppleDesktop'
    '.AppleDB'
    '.DocumentRevisions-V100'
    '.fseventsd'
    '.Spotlight-V100'
    '.Trashes'
    '.TemporaryItems'
    '.VolumeIcon.icns'
    '.apdisk'
    '.localized'
    '__MACOSX'
)

pred=( -name "${names[0]}" )
for name in "${names[@]:1}"; do
    pred+=( -o -name "$name" )
done

# find exits non-zero on unreadable dirs (root-owned podman overlay
# layers under ~/.local/share/containers). That is permanent and harmless:
# keep the run green, keep the count, surface the coverage gap in the journal.
status=0
count=$(find "$HOME" \( "${pred[@]}" \) -type f -print -delete 2>/dev/null | wc -l) || status=1
printf 'prune-macjunk: removed %s files\n' "$count"
if (( status )); then
    echo 'prune-macjunk: warning: some paths were unreadable (podman overlay) and were skipped' >&2
fi
