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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"

distro="$(detect_distro)"
if [[ "$distro" != "deb" ]]; then
    echo "This script is for Deb-based distros. Detected: $distro" >&2
    exit 1
fi

echo "Configuring GNOME desktop environment..."

# GNOME Shell Extensions
echo "Enabling GNOME Shell extensions..."
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com 2>/dev/null || true

# Desktop settings
echo "Configuring desktop settings..."
gsettings set org.gnome.desktop.interface show-battery-percentage true
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Set Flat Remix Dark as the GNOME Shell theme (requires user-theme extension, enabled above)
gsettings set org.gnome.shell.extensions.user-theme name 'Flat-Remix-Dark'

# Clock settings
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.desktop.interface clock-show-weekday true

# Workspace settings
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 2
gsettings set org.gnome.mutter workspaces-only-on-primary false

# Touchpad settings
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
# macOS-like drag lock: tap, drag, lift finger, reposition; tap again to release
gsettings set org.gnome.desktop.peripherals.touchpad tap-and-drag true
gsettings set org.gnome.desktop.peripherals.touchpad tap-and-drag-lock true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true

# Mouse settings
gsettings set org.gnome.desktop.peripherals.mouse natural-scroll false

# Keyboard settings
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:ctrl_modifier']"

# Privacy settings
echo "Configuring privacy settings..."
gsettings set org.gnome.system.location enabled false
gsettings set org.gnome.privacy report-technical-problems false
gsettings set org.gnome.desktop.screensaver lock-enabled true
gsettings set org.gnome.desktop.screensaver lock-delay 'uint32 300'

# Nautilus settings
echo "Configuring Nautilus..."

# Install backspace-to-go-up navigation extension (EstebanForge/nautilus-backspace-nav)
curl -fsSL https://raw.githubusercontent.com/EstebanForge/nautilus-backspace-nav/main/install.sh | bash 2>/dev/null || true

gsettings set org.gtk.Settings.FileChooser show-hidden true
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gsettings set org.gnome.nautilus.preferences show-delete-permanently true

# Terminal settings
echo "Configuring GNOME Terminal..."
gsettings set org.gnome.Terminal.Legacy.Settings default-show-menubar false
gsettings set org.gnome.Terminal.Legacy.Settings theme-variant 'dark'

# Set Iosevka Nerd Font Mono as the terminal font on the default profile (best-effort)
_default_profile="$(gsettings get org.gnome.Terminal.Legacy.Settings default 2>/dev/null)"
_default_profile="${_default_profile//\'/}"
if [[ -n "$_default_profile" ]]; then
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:"$_default_profile"/ use-system-font false 2>/dev/null || true
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:"$_default_profile"/ font 'Iosevka Nerd Font Mono 11' 2>/dev/null || true
fi
unset _default_profile

# Power settings
echo "Configuring power settings..."
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'suspend'
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false

# Network settings
echo "Configuring network settings..."
gsettings set org.gnome.nm-applet disable-wifi-create false

# Sound settings
echo "Configuring sound settings..."
gsettings set org.gnome.desktop.sound event-sounds true

# Application defaults
echo "Configuring application defaults..."
if command -v firefox &> /dev/null; then
    xdg-settings set default-web-browser firefox.desktop
fi

# GNOME Shell preferences
echo "Configuring GNOME Shell..."
gsettings set org.gnome.desktop.interface enable-hot-corners false

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
gsettings set org.gnome.shell favorite-apps "[${local_apps[*]}]"

# Font settings
echo "Configuring font settings..."
gsettings set org.gnome.desktop.interface text-scaling-factor 1.0
gsettings set org.gnome.desktop.interface document-font-name 'Sans 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Iosevka Nerd Font Mono 11'

# Window behavior
echo "Configuring window behavior..."
# Enable minimize, maximize, close window buttons
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
gsettings set org.gnome.desktop.wm.preferences focus-mode 'sloppy'
gsettings set org.gnome.desktop.wm.preferences action-middle-click-titlebar 'lower'
gsettings set org.gnome.desktop.wm.preferences action-right-click-titlebar 'menu'

# Regional settings
echo "Configuring regional settings..."
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.interface temperature-unit 'celsius'

# Settings apply on next session; prompt user to relogin
echo "Deb-based GNOME configuration complete!"
echo "Please log out and back in for all changes to take effect."
