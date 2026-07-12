#!/usr/bin/env bash

# Re-exec with Bash when invoked from another shell (for example: zsh script.sh).
if [[ -z "${BASH_VERSION:-}" ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "This script requires Bash to run." >&2
    exit 1
fi

# Deb-based packages installation script
# Supports ZorinOS, Ubuntu, and other Deb-based distros

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/brew_shared.sh
source "$SCRIPT_DIR/lib/brew_shared.sh"
# shellcheck source=lib/flatpak_shared.sh
source "$SCRIPT_DIR/lib/flatpak_shared.sh"
# shellcheck source=lib/antigravity_cli.sh
source "$SCRIPT_DIR/lib/antigravity_cli.sh"
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"

# Verify we're on a deb-based distro
distro="$(detect_distro)"
if [[ "$distro" != "deb" ]]; then
    echo "This script is for Deb-based distros. Detected: $distro" >&2
    echo "Use install_rpm.sh or install_macos.sh instead." >&2
    exit 1
fi

# Nuke snap if detected (snap is crap)
if command -v snap >/dev/null 2>&1; then
    echo "Snap detected. Removing all snap packages and purging snapd..."
    echo "Dependency order: user-facing apps first, then content snaps, then bases."

    # Keep removing snaps in rounds until none remain.
    # Dependent snaps fail to remove until their dependencies are gone,
    # so repeated passes naturally resolve the correct order.
    _round=0
    while true; do
        _remaining=$(snap list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v '^snapd$' || true)
        [[ -z "$_remaining" ]] && break

        _round=$(( _round + 1 ))
        echo "  Round $_round: $(echo "$_remaining" | wc -l | tr -d ' ') snap(s) remaining"
        _removed=0

        while IFS= read -r _snap; do
            [[ -z "$_snap" ]] && continue
            if sudo snap remove --purge "$_snap" 2>/dev/null; then
                echo "    Removed: $_snap"
                _removed=$(( _removed + 1 ))
            fi
        done <<< "$_remaining"

        # Safety: abort if no progress (stuck snap)
        if [[ $_removed -eq 0 ]]; then
            echo "  WARNING: No snaps removed this round. Forcing remaining..."
            echo "$_remaining" | while IFS= read -r _snap; do
                sudo snap remove --purge "$_snap" 2>/dev/null || true
            done
            break
        fi
    done

    # Remove snapd snap itself
    sudo snap remove --purge snapd 2>/dev/null || true

    # Stop all snapd services
    sudo systemctl daemon-reload
    sudo systemctl stop snapd snapd.socket snapd.seeded.service 2>/dev/null || true
    sudo systemctl disable snapd snapd.socket snapd.seeded.service 2>/dev/null || true

    # Purge snapd via apt
    sudo apt purge -y snapd

    # Remove orphaned dependencies
    sudo apt autoremove --purge -y

    # Pin snapd to prevent reinstallation (layer 1: hold)
    sudo apt-mark hold snapd

    # Block snapd via APT preferences (layer 2: negative pin priority)
    sudo tee /etc/apt/preferences.d/nosnap.pref >/dev/null <<'PREF'
Package: snapd
Pin: release a=*
Pin-Priority: -1
PREF
    echo "  snapd blocked via hold + APT pin."

    # Remove leftover snap directories
    sudo rm -rf /snap /var/snap /var/cache/snapd /var/lib/snapd
    rm -rf ~/snap

    # Reload systemd to clear stale snap mount units
    sudo systemctl daemon-reload

    # Verify snap is gone
    if command -v snap >/dev/null 2>&1; then
        echo "  WARNING: snap command still found after purge."
    else
        echo "  Verified: snap is gone."
    fi

    echo "Snap fully removed and pinned."
    unset _snap _remaining _removed _round
else
    echo "Snap not detected. Good."
fi

# Install Flatpak
if ! command -v flatpak >/dev/null 2>&1; then
    echo "Installing Flatpak..."
    sudo apt install -y flatpak gnome-software-plugin-flatpak
fi

# Add Flathub repository
echo "Adding Flathub repository..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install build-essential (equivalent to Development Tools group)
echo "Installing build-essential..."
sudo apt install -y build-essential

# Install apt packages
echo "Installing apt packages..."
sudo apt install -y \
    xdotool \
    android-tools-adb \
    android-tools-fastboot \
    fd-find \
    ffmpeg \
    nautilus-python \
    wl-clipboard \
    xsel \
    xclip \
    bleachbit \
    btrfs-progs \
    filezilla \
    flameshot \
    gnome-tweaks \
    meld \
    meson \
    mpv \
    python3-pip \
    solaar \
    subversion \
    sshpass \
    yt-dlp \
    dconf-editor \
    git \
    hdparm \
    ninja-build \
    sqlite3 \
    libwebkit2gtk-4.1-dev \
    libgtk-3-dev \
    libicu-dev \
    libjpeg-turbo8-dev \
    libwebp-dev \
    libffi-dev \
    libnss3-dev \
    bubblewrap \
    unzip \
    curl \
    wget \
    tree \
    tmux \
    jq

# Install tailscale via official script (not in standard apt repos)
if ! command -v tailscale >/dev/null 2>&1; then
    echo "Installing tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Install additional GUI apps via apt
# (where available; some apps may need Flatpak or manual install)
echo "Installing GUI applications via apt..."
sudo apt install -y \
    calibre \
    transmission-gtk \
    vlc \
    gimp \
    remmina \
    chromium \
    || true

# Install Flatpak apps
echo "Installing Flatpak apps..."
install_shared_flatpak_apps

# Install Homebrew for Linux (if not already installed)
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew for Linux..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Ensure Homebrew is on PATH regardless of whether it was just installed
test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Install common development tools via Homebrew
echo "Installing Homebrew packages..."
install_shared_brew_packages

# deb-specific Homebrew packages
brew install node

# Install Bun
curl -fsSL https://bun.sh/install | bash

# Global npm packages (Node is provided by Homebrew)
if command -v npm >/dev/null 2>&1; then
    npm install -g postcss
    npm install -g postcss-cli
    npm install -g @github/copilot
else
    echo "WARNING: npm not found; skipping npm packages." >&2
fi

# Install phpvm (PHP version manager)
echo "Installing phpvm..."
curl -o- https://raw.githubusercontent.com/Thavarshan/phpvm/main/install.sh | bash

# Install Antigravity CLI (Google's replacement for Gemini CLI)
install_antigravity_cli

echo "Deb-based package installation complete!"
