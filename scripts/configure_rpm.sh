#!/usr/bin/env bash

# Re-exec with Bash when invoked from another shell (for example: zsh script.sh).
if [[ -z "${BASH_VERSION:-}" ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "This script requires Bash to run." >&2
    exit 1
fi

# Fedora GNOME configuration script
# This script applies GNOME settings and desktop customizations
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

echo "Configuring GNOME desktop environment..."

# GNOME Shell Extensions
echo "Enabling GNOME Shell extensions..."
# Enable user themes extension (must succeed before applying a shell theme)
enable_gnome_extension "user-theme@gnome-shell-extensions.gcampax.github.com"

# Desktop settings
echo "Configuring desktop settings..."
# Show battery percentage
gset org.gnome.desktop.interface show-battery-percentage true

# Set dark theme (optional)
gset org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gset org.gnome.desktop.interface icon-theme 'Adwaita'
gset org.gnome.desktop.interface color-scheme 'prefer-dark'

# Set Flat Remix Dark as the GNOME Shell theme (requires user-theme extension, enabled above)
gset org.gnome.shell.extensions.user-theme name 'Flat-Remix-Dark'

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
# Disable location services
gset org.gnome.system.location enabled false

# Disable crash reporting
gset org.gnome.privacy report-technical-problems false

# Set screen lock settings
gset org.gnome.desktop.screensaver lock-enabled true
gset org.gnome.desktop.screensaver lock-delay 'uint32 300'

# File Manager (Nautilus) settings
echo "Configuring Nautilus..."

# Install backspace-to-go-up navigation extension (EstebanForge/nautilus-backspace-nav)
curl -fsSL https://raw.githubusercontent.com/EstebanForge/nautilus-backspace-nav/main/install.sh | bash 2>/dev/null || true

# Show hidden files
gset org.gtk.Settings.FileChooser show-hidden true

# Set default view to list view
gset org.gnome.nautilus.preferences default-folder-viewer 'list-view'

# Show delete permanently option
gset org.gnome.nautilus.preferences show-delete-permanently true

# Terminal settings
echo "Configuring GNOME Terminal..."
# Set default profile to use dark theme
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
# Set power button action to suspend
gset org.gnome.settings-daemon.plugins.power power-button-action 'suspend'

# Disable automatic screen brightness (if applicable)
gset org.gnome.settings-daemon.plugins.power ambient-enabled false

# Network settings
echo "Configuring network settings..."
# Enable auto-connect to known Wi-Fi networks
gset org.gnome.nm-applet disable-wifi-create false

# Sound settings
echo "Configuring sound settings..."
# Enable event sounds
gset org.gnome.desktop.sound event-sounds true

# Application settings
echo "Configuring application defaults..."
# Set default browser to Firefox
if command -v firefox &> /dev/null; then
    xdg-settings set default-web-browser firefox.desktop
fi

# Set default text editor to Gedit
if command -v gedit &> /dev/null; then
    xdg-mime default gedit.desktop text/plain
fi

# GNOME Shell preferences
echo "Configuring GNOME Shell..."
# Enable hot corners (top-left to show overview)
gset org.gnome.desktop.interface enable-hot-corners false

# Set favorite apps in dock
gset org.gnome.shell favorite-apps "['firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.gedit.desktop', 'org.gnome.Calendar.desktop']"

# Font settings
echo "Configuring font settings..."
# Set font scaling
gset org.gnome.desktop.interface text-scaling-factor 1.0

# Set interface text font to SF Pro Text (installed by fonts_shared.sh)
gset org.gnome.desktop.interface font-name 'SF Pro Text 11'

# Set document font
gset org.gnome.desktop.interface document-font-name 'Sans 11'

# Set monospace font
gset org.gnome.desktop.interface monospace-font-name 'Iosevka Nerd Font Mono 11'

# Window behavior
echo "Configuring window behavior..."
# Enable minimize, maximize, close window buttons
gset org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

# Enable focus follows mouse
gset org.gnome.desktop.wm.preferences focus-mode 'sloppy'

# Set window titlebar actions
gset org.gnome.desktop.wm.preferences action-middle-click-titlebar 'lower'
gset org.gnome.desktop.wm.preferences action-right-click-titlebar 'menu'

# Accessibility settings
echo "Configuring accessibility..."
# Enable screen reader if needed (commented out by default)
# gset org.gnome.desktop.a11y.applications screen-reader-enabled true

# Enable high contrast if needed (commented out by default)
# gset org.gnome.desktop.interface gtk-theme 'HighContrast'

# Regional settings
echo "Configuring regional settings..."
# Set 24-hour clock
gset org.gnome.desktop.interface clock-format '24h'

# Set temperature unit to Celsius
gset org.gnome.desktop.interface temperature-unit 'celsius'

# Background settings (optional - set a custom wallpaper)
# gset org.gnome.desktop.background picture-uri 'file:///path/to/your/wallpaper.jpg'

# Settings apply on next session; prompt user to relogin
echo "Fedora GNOME configuration complete!"
echo "Please log out and back in for all changes to take effect."
