#!/usr/bin/env bash

# Shared profile-picture helper for GNOME/Linux.
# Sourced by configure_rpm.sh and configure_deb.sh.
#
# macOS uses a different mechanism (dsimport, to embed JPEGPhoto), so it is
# handled inline in configure_macos.sh rather than here.

# Set the user's profile picture in two places:
#   1. ~/.face               — read by GDM/LightDM and other login screens.
#   2. AccountsService icon  — what GNOME Settings and the login screen render.
# Arg 1: absolute path to a JPEG/PNG image (square, ~512px works best).
set_profile_picture_linux() {
    local src="$1"
    local user="${USER:-$(id -un)}"
    local icon_dir="/var/lib/AccountsService/icons"
    local users_file="/var/lib/AccountsService/users/${user}"
    local icon_file="${icon_dir}/${user}"

    if [[ -z "$src" || ! -f "$src" ]]; then
        echo "  warning: profile picture source not found ('$src'), skipping." >&2
        return 1
    fi

    # 1. Fallback image read by most display managers.
    cp -f "$src" "$HOME/.face" || echo "  warning: could not write ~/.face." >&2

    # 2. AccountsService (GNOME). Skip silently where absent (non-GNOME install).
    if [[ ! -d /var/lib/AccountsService ]]; then
        echo "  AccountsService not found; ~/.face set, GNOME icon skipped."
        return 0
    fi

    # Icon file is named after the user with NO extension (GNOME convention).
    sudo mkdir -p "$icon_dir" || return 1
    sudo cp -f "$src" "$icon_file" || return 1
    sudo chmod 644 "$icon_file"

    # Idempotently point Icon= at our file in the user record, preserving any
    # existing keys ([User] is an INI-style section managed by accounts-daemon).
    sudo touch "$users_file"
    if sudo grep -qE '^[[:space:]]*Icon[[:space:]]*=' "$users_file"; then
        sudo sed -i "s#^[[:space:]]*Icon[[:space:]]*=.*#Icon=${icon_file}#" "$users_file"
    elif sudo grep -qE '^[[:space:]]*\[User\]' "$users_file"; then
        sudo sed -i "/^[[:space:]]*\[User\]/a Icon=${icon_file}" "$users_file"
    else
        printf '\n[User]\nIcon=%s\n' "$icon_file" | sudo tee -a "$users_file" >/dev/null
    fi

    echo "  Profile picture set (AccountsService + ~/.face)."
}
