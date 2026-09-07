#!/usr/bin/env bash
# One-time: Insync's apt key used to land in the globally-trusted
# /etc/apt/trusted.gpg.d and the repo used a plain-http baseurl. Rewrite the
# repo line to the scoped keyring + https, then drop the global key.
# Debian/Ubuntu hosts only; every step skips gracefully when absent.
set -euo pipefail

# Not a deb host (macOS, rpm): nothing to migrate.
[[ -d /etc/apt ]] || exit 0

LIST=/etc/apt/sources.list.d/insync.list
KEY_OLD=/etc/apt/trusted.gpg.d/insynchq.gpg
KEY_NEW=/etc/apt/keyrings/insynchq.gpg

if [[ -f "$LIST" ]]; then
    sudo sed -i \
        -e 's#signed-by=/etc/apt/trusted\.gpg\.d/insynchq\.gpg#signed-by=/etc/apt/keyrings/insynchq.gpg#' \
        -e 's#http://apt\.insync\.io#https://apt.insync.io#' \
        "$LIST"
fi

if [[ -f "$KEY_OLD" ]]; then
    sudo install -d -m 0755 /etc/apt/keyrings
    sudo cp -a "$KEY_OLD" "$KEY_NEW"
    sudo rm -f "$KEY_OLD"
fi

exit 0
