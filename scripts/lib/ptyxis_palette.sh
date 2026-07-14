#!/usr/bin/env bash

# Ptyxis terminal palette configuration (Linux: RPM + Deb).
# Sets the active color palette on the default Ptyxis profile via gsettings.
#
# Ptyxis (GNOME's default terminal on Fedora 41+ and Ubuntu 25.10+) stores
# per-profile settings in the org.gnome.Ptyxis.Profile gsettings schema.
# The active palette is the `palette` key (string) on each profile, valued
# by the palette's Name= field — NOT by filename. There is no CLI flag to
# set the active palette (--import-palette only installs the file); gsettings
# is the only programmatic path.
#
# The palette files themselves are symlinked into
# ~/.local/share/org.gnome.Ptyxis/palettes/ by `dots install` (see dots.sh).
# This function only flips the active-palette gsettings key, so it must run
# AFTER `dots install` has placed the .palette files — otherwise Ptyxis won't
# recognise the name and falls back to the default.
#
# Native install only. Flatpak ptyxis (app.devsuite.Ptyxis) uses a sandboxed
# gsettings copy and a different path; if the native schema is absent this is
# a no-op with a warning.
#
# Sourced by configure_rpm.sh and configure_deb.sh; call configure_ptyxis_palette.

# Palette to activate. Must match the Name= field in the vendored
# home/.local/share/org.gnome.Ptyxis/palettes/Catppuccin Mocha.palette.
PTYXIS_ACTIVE_PALETTE="Catppuccin Mocha"

configure_ptyxis_palette() {
    # Guard: gsettings binary present (GNOME desktop).
    if ! command -v gsettings >/dev/null 2>&1; then
        echo "  WARNING: gsettings not found; skipping Ptyxis palette config." >&2
        return 0
    fi

    # Guard: native ptyxis schema installed. Absent => ptyxis is Flatpak-only
    # or not installed on this host.
    if ! gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.Ptyxis'; then
        echo "  WARNING: org.gnome.Ptyxis schema not found (ptyxis not installed natively, or Flatpak-only); skipping palette config." >&2
        return 0
    fi

    # Guard: the palette file is installed. If dots install hasn't run, the
    # name won't resolve and ptyxis would silently fall back to 'gnome'.
    local palette_file="$HOME/.local/share/org.gnome.Ptyxis/palettes/${PTYXIS_ACTIVE_PALETTE}.palette"
    if [[ ! -e "$palette_file" ]]; then
        echo "  WARNING: palette file not found: $palette_file" >&2
        echo "           Run \`dots install\` first to symlink the Catppuccin palettes." >&2
        return 0
    fi

    # Resolve the default profile UUID. ptyxis creates this on first run;
    # if empty, ptyxis hasn't been launched yet and there's no profile to set.
    local uuid
    uuid="$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null | tr -d "'")"
    if [[ -z "$uuid" ]]; then
        echo "  WARNING: Ptyxis has no default profile yet (not launched?). Open Ptyxis once, then re-run configure." >&2
        return 0
    fi

    # Set the active palette on the default profile. Best-effort: a missing
    # key (older ptyxis) shouldn't abort the configure run.
    if gsettings set "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${uuid}/" palette "'${PTYXIS_ACTIVE_PALETTE}'" 2>/dev/null; then
        echo "  Ptyxis default profile palette set to: $PTYXIS_ACTIVE_PALETTE"
    else
        echo "  WARNING: failed to set Ptyxis palette (key may not exist in this ptyxis version)." >&2
    fi
}
