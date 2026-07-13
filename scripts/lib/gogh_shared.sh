#!/usr/bin/env bash

# Shared Gogh terminal color-scheme installation (macOS + Linux).
# Installs terminal profiles via the Gogh project for supported terminals
# (GNOME Terminal, Tilix, Kitty, iTerm2, XFCE4 Terminal, etc.).
#
# Sourced by install_macos.sh, install_rpm.sh, and install_deb.sh;
# call install_gogh_themes().
#
# Requires dconf-cli (Deb) / dconf (RPM) + uuid-runtime / uuidgen; these are
# declared in the platform install scripts. macOS targets iTerm2 if installed.
#
# Project: https://github.com/Gogh-Co/Gogh  Themes: https://gogh-co.github.io/Gogh/

# Gogh themes to install (non-interactive). Each name must be passed as a single
# quoted positional arg; the matcher normalizes spaces to dashes, so
# "Catppuccin Mocha" resolves to the catppuccin-mocha theme file.
GOGH_THEMES=(
    "Catppuccin Mocha"
)

install_gogh_themes() {
    # Canonical raw URL (the git.io shortlink is deprecated by GitHub since 2022
    # and points at the project's stale pre-org path).
    local gogh_url="https://raw.githubusercontent.com/Gogh-Co/Gogh/master/gogh.sh"
    local script_text

    echo "Installing Gogh terminal color schemes (${GOGH_THEMES[*]})..."

    if command -v wget >/dev/null 2>&1; then
        script_text="$(wget -qO- "$gogh_url" 2>/dev/null)"
    elif command -v curl >/dev/null 2>&1; then
        script_text="$(curl -fsSL "$gogh_url" 2>/dev/null)"
    else
        echo "  WARNING: neither wget nor curl available; skipping Gogh themes." >&2
        return 0
    fi

    if [[ -z "$script_text" ]]; then
        echo "  WARNING: failed to download Gogh installer; skipping." >&2
        return 0
    fi

    # Passing positional theme names skips Gogh's interactive menu entirely
    # (each array element is one quoted arg; bash preserves the space in names
    # like "Catppuccin Mocha"). $0 is set to "gogh" for the inner script.
    # Fault-tolerant: a failed apply (e.g. no supported terminal on this host)
    # must not abort the install under `set -e`.
    bash -c "$script_text" gogh "${GOGH_THEMES[@]}" \
        || echo "  WARNING: Gogh could not apply themes on this host; skipping." >&2
}
