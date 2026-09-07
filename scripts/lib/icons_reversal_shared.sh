#!/usr/bin/env bash

# Shared Reversal icon theme installation for Linux (rpm + deb).
# Installs the Reversal icon theme from yeyushengfan258/Reversal-icon-theme.
#
# Sourced by install_rpm.sh and install_deb.sh; call install_reversal_icon_theme().

# Color variant(s) to install. 'all' = every folder color variant shipped by
# upstream (black/blue/brown/cyan/green/grey/lightblue/orange/pink/purple/red +
# the default). Each color comes with a -dark icon variant too (handled by
# install.sh's COLOR_VARIANTS). Override by exporting REVERSAL_COLOR before
# calling. See https://github.com/yeyushengfan258/Reversal-icon-theme
REVERSAL_COLOR="${REVERSAL_COLOR:-all}"

install_reversal_icon_theme() {
    local icons_dir="$HOME/.local/share/icons"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local zip_url="https://codeload.github.com/yeyushengfan258/Reversal-icon-theme/zip/refs/heads/master"

    echo "Installing Reversal icon theme..."

    # Idempotent: probe for a directory the current color selection produces.
    # 'all' installs every color incl. Reversal-red (red exists only in the
    # full set); a specific color 'X' installs Reversal-X.
    local probe
    if [[ "$REVERSAL_COLOR" == "all" ]]; then
        probe="$icons_dir/Reversal-red"
    else
        probe="$icons_dir/Reversal-${REVERSAL_COLOR%%,*}"
    fi
    if [[ -d "$probe" ]]; then
        echo "  Reversal icon theme already installed, skipping."
        rm -rf "$tmp_dir"
        return 0
    fi

    mkdir -p "$icons_dir"

    echo "  Downloading Reversal archive..."
    if ! curl -fsSL -o "$tmp_dir/reversal.zip" "$zip_url" 2>/dev/null; then
        echo "  WARNING: failed to download Reversal; skipping." >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    if ! unzip -oq "$tmp_dir/reversal.zip" -d "$tmp_dir" 2>/dev/null; then
        echo "  WARNING: failed to extract Reversal; skipping." >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    # Archive extracts to Reversal-icon-theme-master/.
    local src_dir="$tmp_dir/Reversal-icon-theme-master"
    if [[ ! -d "$src_dir" ]]; then
        echo "  WARNING: unexpected archive layout; skipping." >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    # Run upstream install.sh: installs user-space into ~/.local/share/icons.
    # --theme all installs every folder color variant; each gets a -dark icon
    # variant automatically.
    echo "  Running install.sh --theme ${REVERSAL_COLOR}..."
    (
        cd "$src_dir" || exit 1
        bash install.sh --theme "$REVERSAL_COLOR" >/dev/null 2>&1 \
            || echo "  WARNING: install.sh reported an error; theme may be incomplete." >&2
    )

    rm -rf "$tmp_dir"
    echo "Reversal icon theme installed."
}
