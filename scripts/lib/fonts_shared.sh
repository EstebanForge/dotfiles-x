#!/usr/bin/env bash

# Shared font installation for Linux (rpm + deb).
# Installs Iosevka core families + Iosevka Nerd Font from GitHub releases.
#
# Sourced by install_rpm.sh and install_deb.sh; call install_iosevka_fonts().

# Core Iosevka monospace families (Super TTC bundles each family + spacing variants).
# Iosevka SuperTTC top-level bundles. Each bundles all spacing variants:
#   - Iosevka:         default + Term + Fixed (sans, ligatures)
#   - IosevkaSlab:     default + Term + Fixed (slab-serif, ligatures)
# There are no separate SuperTTC-IosevkaTerm/Fixed/etc. assets; the -SGr-
# single-group packages use a different URL pattern and aren't needed here.
_IOSEVKA_FAMILIES=(
    "Iosevka"
    "IosevkaSlab"
)

# Nerd Font patched packages.
_IOSEVKA_NERD_PACKAGES=(
    "Iosevka"
    "IosevkaTerm"
)

_iosevka_latest_tag() {
    # Extract the version string (without leading 'v') from GitHub's latest release.
    curl -fsSL https://api.github.com/repos/be5invis/Iosevka/releases/latest 2>/dev/null \
        | grep '"tag_name"' | head -1 \
        | sed -E 's/.*"v?([^"]+)".*/\1/'
}

_nerd_fonts_latest_tag() {
    curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest 2>/dev/null \
        | grep '"tag_name"' | head -1 \
        | sed -E 's/.*"v?([^"]+)".*/\1/'
}

install_iosevka_fonts() {
    local font_dir="$HOME/.local/share/fonts/iosevka"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local io_ver nf_ver

    echo "Installing Iosevka fonts..."

    io_ver="$(_iosevka_latest_tag)"
    nf_ver="$(_nerd_fonts_latest_tag)"

    if [[ -z "$io_ver" || -z "$nf_ver" ]]; then
        echo "WARNING: could not resolve Iosevka/Nerd Font version (offline?); skipping fonts." >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    echo "  Latest Iosevka: ${io_ver}  |  Nerd Fonts: ${nf_ver}"

    mkdir -p "$font_dir"

    # --- Iosevka core families (Super TTC) ---
    local family url out_zip marker
    for family in "${_IOSEVKA_FAMILIES[@]}"; do
        marker="$font_dir/.${family}-${io_ver}"
        if [[ -f "$marker" ]]; then
            echo "  ${family}: already installed at ${io_ver}, skipping."
            continue
        fi
        url="https://github.com/be5invis/Iosevka/releases/download/v${io_ver}/SuperTTC-${family}-${io_ver}.zip"
        out_zip="$tmp_dir/${family}.zip"
        echo "  Downloading ${family}..."
        if curl -fsSL -o "$out_zip" "$url" 2>/dev/null; then
            unzip -oq "$out_zip" -d "$font_dir" 2>/dev/null && touch "$marker"
        else
            echo "  WARNING: failed to download ${family}; skipping." >&2
        fi
    done

    # --- Iosevka Nerd Font ---
    for family in "${_IOSEVKA_NERD_PACKAGES[@]}"; do
        marker="$font_dir/.${family}-nerd-${nf_ver}"
        if [[ -f "$marker" ]]; then
            echo "  ${family} Nerd: already installed at ${nf_ver}, skipping."
            continue
        fi
        url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${nf_ver}/${family}.zip"
        out_zip="$tmp_dir/${family}-nerd.zip"
        echo "  Downloading ${family} Nerd Font..."
        if curl -fsSL -o "$out_zip" "$url" 2>/dev/null; then
            unzip -oq "$out_zip" -d "$font_dir" 2>/dev/null && touch "$marker"
        else
            echo "  WARNING: failed to download ${family} Nerd Font; skipping." >&2
        fi
    done

    # Refresh font cache so the new fonts are picked up immediately
    if command -v fc-cache >/dev/null 2>&1; then
        echo "  Refreshing font cache..."
        fc-cache -f "$font_dir" >/dev/null 2>&1 || true
    fi

    rm -rf "$tmp_dir"
    echo "Iosevka fonts installed."
}

# San Francisco Pro fonts (Apple's system font, packaged by sahibjotsaggu).
# Repo root contains all .otf/.ttf files; downloaded as a zip and unpacked.
install_sf_pro_fonts() {
    local font_dir="$HOME/.local/share/fonts/sf-pro"
    local marker="$font_dir/.installed"
    local tmp_dir extract_dir
    tmp_dir="$(mktemp -d)"
    local zip_url="https://codeload.github.com/sahibjotsaggu/San-Francisco-Pro-Fonts/zip/refs/heads/master"

    echo "Installing San Francisco Pro fonts..."

    if [[ -f "$marker" ]]; then
        echo "  SF Pro fonts already installed, skipping."
        rm -rf "$tmp_dir"
        return 0
    fi

    mkdir -p "$font_dir"

    echo "  Downloading SF Pro fonts archive..."
    if ! curl -fsSL -o "$tmp_dir/sf-pro.zip" "$zip_url" 2>/dev/null; then
        echo "  WARNING: failed to download SF Pro fonts; skipping." >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    # Archive extracts to San-Francisco-Pro-Fonts-master/ with .otf/.ttf at root.
    if ! unzip -oq "$tmp_dir/sf-pro.zip" -d "$tmp_dir" 2>/dev/null; then
        echo "  WARNING: failed to extract SF Pro fonts; skipping." >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    extract_dir="$tmp_dir/San-Francisco-Pro-Fonts-master"
    if [[ -d "$extract_dir" ]]; then
        # Copy only font files (ignore README, license, etc.).
        cp "$extract_dir"/*.otf "$extract_dir"/*.ttf "$font_dir"/ 2>/dev/null || true
        touch "$marker"
    else
        echo "  WARNING: unexpected archive layout; skipping." >&2
    fi

    if command -v fc-cache >/dev/null 2>&1; then
        echo "  Refreshing font cache..."
        fc-cache -f "$font_dir" >/dev/null 2>&1 || true
    fi

    rm -rf "$tmp_dir"
    echo "SF Pro fonts installed."
}

# Entry point: install all shared fonts.
install_shared_fonts() {
    install_iosevka_fonts
    install_sf_pro_fonts
}
