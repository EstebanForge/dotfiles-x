#!/usr/bin/env bash

# Shared GNOME theme installation for Linux (rpm + deb).
# Installs Flat Remix GNOME Shell themes from the daniruiz/flat-remix-gnome repo.
#
# Sourced by install_rpm.sh and install_deb.sh; call install_flat_remix_theme().

# Flat Remix variants to install (each includes its -fullPanel counterpart).
_FLAT_REMIX_VARIANTS=(
    "Flat-Remix-Dark"
    "Flat-Remix-Darkest"
    "Flat-Remix-Miami-Dark"
)

install_flat_remix_theme() {
    local themes_dir="$HOME/.themes"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local zip_url="https://codeload.github.com/daniruiz/flat-remix-gnome/zip/refs/heads/master"

    echo "Installing Flat Remix GNOME themes..."

    mkdir -p "$themes_dir"

    echo "  Downloading Flat Remix archive..."
    if ! curl -fsSL -o "$tmp_dir/flat-remix.zip" "$zip_url" 2>/dev/null; then
        echo "  WARNING: failed to download Flat Remix; skipping." >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    if ! unzip -oq "$tmp_dir/flat-remix.zip" -d "$tmp_dir" 2>/dev/null; then
        echo "  WARNING: failed to extract Flat Remix; skipping." >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    # Archive extracts to flat-remix-gnome-master/themes/<Variant>/.
    local src_dir="$tmp_dir/flat-remix-gnome-master/themes"
    if [[ ! -d "$src_dir" ]]; then
        echo "  WARNING: unexpected archive layout; skipping." >&2
        rm -rf "$tmp_dir"
        return 0
    fi

    local variant
    for variant in "${_FLAT_REMIX_VARIANTS[@]}"; do
        # Install both the base variant and its -fullPanel counterpart.
        local name
        for name in "$variant" "${variant}-fullPanel"; do
            if [[ -d "$src_dir/$name" ]]; then
                rm -rf "${themes_dir:?}/$name"
                cp -r "$src_dir/$name" "$themes_dir/" 2>/dev/null && echo "  Installed: $name"
            else
                echo "  WARNING: $name not found in archive; skipping." >&2
            fi
        done
    done

    rm -rf "$tmp_dir"
    echo "Flat Remix themes installed."
}
