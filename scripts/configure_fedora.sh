#!/bin/bash

# Fedora GNOME configuration script
# This script applies GNOME settings and desktop customizations

echo "Configuring GNOME desktop environment..."

# GNOME Shell Extensions
echo "Enabling GNOME Shell extensions..."
# Enable user themes extension
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com 2>/dev/null || true

# Desktop settings
echo "Configuring desktop settings..."
# Show battery percentage
gsettings set org.gnome.desktop.interface show-battery-percentage true

# Set dark theme (optional)
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'

# Clock settings
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.desktop.interface clock-show-weekday true

# Workspace settings
gsettings set org.gnome.mutter dynamic-workspaces true
gsettings set org.gnome.desktop.wm.preferences num-workspaces 4

# Touchpad settings
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false

# Mouse settings
gsettings set org.gnome.desktop.peripherals.mouse natural-scroll false

# Keyboard settings
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:ctrl_modifier']"

# Privacy settings
echo "Configuring privacy settings..."
# Disable location services
gsettings set org.gnome.system.location enabled false

# Disable crash reporting
gsettings set org.gnome.privacy report-technical-problems false

# Set screen lock settings
gsettings set org.gnome.desktop.screensaver lock-enabled true
gsettings set org.gnome.desktop.screensaver lock-delay 'uint32 300'

# File Manager (Nautilus) settings
echo "Configuring Nautilus..."
# Show hidden files
gsettings set org.gtk.Settings.FileChooser show-hidden true

# Set default view to list view
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'

# Show delete permanently option
gsettings set org.gnome.nautilus.preferences show-delete-permanently true

# Terminal settings
echo "Configuring GNOME Terminal..."
# Set default profile to use dark theme
gsettings set org.gnome.Terminal.Legacy.Settings default-show-menubar false
gsettings set org.gnome.Terminal.Legacy.Settings theme-variant 'dark'

# Power settings
echo "Configuring power settings..."
# Set power button action to suspend
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'suspend'

# Disable automatic screen brightness (if applicable)
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false

# Network settings
echo "Configuring network settings..."
# Enable auto-connect to known Wi-Fi networks
gsettings set org.gnome.nm-applet disable-wifi-create false

# Sound settings
echo "Configuring sound settings..."
# Enable event sounds
gsettings set org.gnome.desktop.sound event-sounds true

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
gsettings set org.gnome.desktop.interface enable-hot-corners true

# Set favorite apps in dock
gsettings set org.gnome.shell favorite-apps "['firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.gedit.desktop', 'org.gnome.Calendar.desktop']"

# Font settings
echo "Configuring font settings..."
# Set font scaling
gsettings set org.gnome.desktop.interface text-scaling-factor 1.0

# Set document font
gsettings set org.gnome.desktop.interface document-font-name 'Sans 11'

# Set monospace font
gsettings set org.gnome.desktop.interface monospace-font-name 'Monospace 11'

# Window behavior
echo "Configuring window behavior..."
# Enable focus follows mouse
gsettings set org.gnome.desktop.wm.preferences focus-mode 'sloppy'

# Set window titlebar actions
gsettings set org.gnome.desktop.wm.preferences action-middle-click-titlebar 'lower'
gsettings set org.gnome.desktop.wm.preferences action-right-click-titlebar 'menu'

# Accessibility settings
echo "Configuring accessibility..."
# Enable screen reader if needed (commented out by default)
# gsettings set org.gnome.desktop.a11y.applications screen-reader-enabled true

# Enable high contrast if needed (commented out by default)
# gsettings set org.gnome.desktop.interface gtk-theme 'HighContrast'

# Regional settings
echo "Configuring regional settings..."
# Set 24-hour clock
gsettings set org.gnome.desktop.interface clock-format '24h'

# Set temperature unit to Celsius
gsettings set org.gnome.desktop.interface temperature-unit 'celsius'

# Background settings (optional - set a custom wallpaper)
# gsettings set org.gnome.desktop.background picture-uri 'file:///path/to/your/wallpaper.jpg'

# Restart GNOME Shell to apply all changes
echo "Restarting GNOME Shell to apply changes..."
if command -v gnome-shell &> /dev/null; then
    # Only restart if we're in a GNOME session
    if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
        killall -SIGUSR2 gnome-shell 2>/dev/null || true
    fi
fi

echo "Fedora GNOME configuration complete!"
echo "Some settings may require a logout/restart to take full effect."