#!/usr/bin/env bash

# Re-exec with Bash when invoked from another shell (for example: zsh script.sh).
if [[ -z "${BASH_VERSION:-}" ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "This script requires Bash to run." >&2
    exit 1
fi

# Deb-based GNOME configuration script
# Applies GNOME settings for ZorinOS, Ubuntu, and other Deb-based distros.

# gsettings calls are best-effort; set -e is intentionally omitted
set -uo pipefail

# Best-effort gsettings setter: silently skips schemas/keys that don't exist
# on this GNOME version/distro (e.g. Ubuntu-only org.gnome.privacy on Fedora,
# or keys removed in GNOME 48 like temperature-unit). One guard > many.
gset() {
    gsettings set "$@" 2>/dev/null || true
}

# Enable a GNOME Shell extension by UUID, merging into enabled-extensions.
# More reliable than `gnome-extensions enable`, which needs the shell's D-Bus
# responsive and fails silently during scripted runs. Persists across reboots.
enable_gnome_extension() {
    local uuid="$1" current new
    # Master switch: allow user extensions to load at all.
    gset org.gnome.shell disable-user-extensions false
    # Merge UUID into enabled-extensions if not already present.
    if ! gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -qF -- "$uuid"; then
        current="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null)"
        current="${current#@as }"   # strip GVariant empty-array type annotation
        if [[ "$current" == "[]" ]]; then
            new="['$uuid']"
        else
            new="${current%]}, '$uuid']"
        fi
        gset org.gnome.shell enabled-extensions "$new"
    fi
    # Best-effort live activation (no-op if the shell isn't running).
    gnome-extensions enable "$uuid" 2>/dev/null || true
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"
# shellcheck source=lib/profile_picture.sh
source "$SCRIPT_DIR/lib/profile_picture.sh"

distro="$(detect_distro)"
if [[ "$distro" != "deb" ]]; then
    echo "This script is for Deb-based distros. Detected: $distro" >&2
    exit 1
fi

echo "Configuring GNOME desktop environment..."

# GNOME Shell Extensions
echo "Enabling GNOME Shell extensions..."
enable_gnome_extension "user-theme@gnome-shell-extensions.gcampax.github.com"

# Desktop settings
echo "Configuring desktop settings..."
gset org.gnome.desktop.interface show-battery-percentage true
gset org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gset org.gnome.desktop.interface icon-theme 'Reversal-blue-dark'
gset org.gnome.desktop.interface color-scheme 'prefer-dark'

# Set Flat Remix Dark fullPanel as the GNOME Shell theme (requires user-theme extension, enabled above)
gset org.gnome.shell.extensions.user-theme name 'Flat-Remix-Dark-fullPanel'

# Clock settings
gset org.gnome.desktop.interface clock-show-date true
gset org.gnome.desktop.interface clock-show-weekday true

# Workspace settings
gset org.gnome.mutter dynamic-workspaces false
gset org.gnome.desktop.wm.preferences num-workspaces 2
gset org.gnome.mutter workspaces-only-on-primary false

# Touchpad settings
gset org.gnome.desktop.peripherals.touchpad tap-to-click true
# macOS-like drag lock: tap, drag, lift finger, reposition; tap again to release
gset org.gnome.desktop.peripherals.touchpad tap-and-drag true
gset org.gnome.desktop.peripherals.touchpad tap-and-drag-lock true
gset org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gset org.gnome.desktop.peripherals.touchpad natural-scroll true

# Mouse settings
gset org.gnome.desktop.peripherals.mouse natural-scroll false

# Keyboard settings
gset org.gnome.desktop.input-sources xkb-options "['caps:ctrl_modifier']"

# Privacy settings
echo "Configuring privacy settings..."
gset org.gnome.system.location enabled false
gset org.gnome.privacy report-technical-problems false
gset org.gnome.desktop.screensaver lock-enabled true
gset org.gnome.desktop.screensaver lock-delay 'uint32 300'

# Nautilus settings
echo "Configuring Nautilus..."

# Install backspace-to-go-up navigation extension (EstebanForge/nautilus-backspace-nav)
curl -fsSL https://raw.githubusercontent.com/EstebanForge/nautilus-backspace-nav/main/install.sh | bash 2>/dev/null || true

gset org.gtk.Settings.FileChooser show-hidden true
gset org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gset org.gnome.nautilus.preferences show-delete-permanently true

# Terminal settings
echo "Configuring GNOME Terminal..."
gset org.gnome.Terminal.Legacy.Settings default-show-menubar false
gset org.gnome.Terminal.Legacy.Settings theme-variant 'dark'

# Set Iosevka Nerd Font Mono as the terminal font on the default profile (best-effort)
_default_profile="$(gsettings get org.gnome.Terminal.Legacy.Settings default 2>/dev/null)"
_default_profile="${_default_profile//\'/}"
if [[ -n "$_default_profile" ]]; then
    gset org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:"$_default_profile"/ use-system-font false
    gset org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:"$_default_profile"/ font 'Iosevka Nerd Font Mono 11'
fi
unset _default_profile

# Power settings
echo "Configuring power settings..."
gset org.gnome.settings-daemon.plugins.power power-button-action 'suspend'
gset org.gnome.settings-daemon.plugins.power ambient-enabled false

# Network settings
echo "Configuring network settings..."
gset org.gnome.nm-applet disable-wifi-create false

# Sound settings
echo "Configuring sound settings..."
gset org.gnome.desktop.sound event-sounds true

# Application defaults
echo "Configuring application defaults..."
if command -v firefox &> /dev/null; then
    xdg-settings set default-web-browser firefox.desktop
fi

# GNOME Shell preferences
echo "Configuring GNOME Shell..."
gset org.gnome.desktop.interface enable-hot-corners false

# Detect available apps for favorites
local_apps=()
for app in firefox.desktop google-chrome.desktop chromium-browser.desktop; do
    if [[ -f "/usr/share/applications/$app" ]]; then
        local_apps+=("'$app'")
        break
    fi
done
local_apps+=("'org.gnome.Nautilus.desktop'")
local_apps+=("'org.gnome.Terminal.desktop'")
gset org.gnome.shell favorite-apps "[${local_apps[*]}]"

# Font settings
echo "Configuring font settings..."
gset org.gnome.desktop.interface text-scaling-factor 1.0
gset org.gnome.desktop.interface font-name 'SF Pro Text 11'
gset org.gnome.desktop.interface document-font-name 'Sans 11'
gset org.gnome.desktop.interface monospace-font-name 'Iosevka Nerd Font Mono 11'

# Window behavior
echo "Configuring window behavior..."
# Enable minimize, maximize, close window buttons
gset org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
gset org.gnome.desktop.wm.preferences focus-mode 'sloppy'
gset org.gnome.desktop.wm.preferences action-middle-click-titlebar 'lower'
gset org.gnome.desktop.wm.preferences action-right-click-titlebar 'menu'

# Regional settings
echo "Configuring regional settings..."
gset org.gnome.desktop.interface clock-format '24h'
gset org.gnome.desktop.interface temperature-unit 'celsius'

# User profile picture (AccountsService + ~/.face)
echo "Setting user profile picture..."
set_profile_picture_linux "$SCRIPT_DIR/../assets/profile-picture.jpg"

# Settings apply on next session; prompt user to relogin
echo "Deb-based GNOME configuration complete!"
echo "Please log out and back in for all changes to take effect."
