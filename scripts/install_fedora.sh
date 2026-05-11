#!/usr/bin/env bash

# Re-exec with Bash when invoked from another shell (for example: zsh script.sh).
if [[ -z "${BASH_VERSION:-}" ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "This script requires Bash to run." >&2
    exit 1
fi

# Fedora Linux packages installation script
# This script installs DNF packages, Flatpak apps, and sets up development environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/brew_shared.sh
source "$SCRIPT_DIR/lib/brew_shared.sh"
# shellcheck source=lib/flatpak_shared.sh
source "$SCRIPT_DIR/lib/flatpak_shared.sh"

# Update system
echo "Updating system packages..."
sudo dnf update -y

# Install RPM Fusion repositories (for proprietary codecs)
echo "Installing RPM Fusion repositories..."
sudo dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf install -y "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Install development tools group
echo "Installing development tools group..."
sudo dnf group install -y "Development Tools"

# Install DNF packages
echo "Installing DNF packages..."
sudo dnf install -y \
    xdotool \
    pulseaudio-utils \
    ibus-speech-to-text \
    gpaste \
    gpaste-ui \
    android-tools \
    evtest \
    libinput-devel \
    libudev-devel \
    fd-find \
    libxcrypt-compat \
    ffmpeg \
    nautilus-python \
    xsel \
    xclip \
    zsh \
    libavcodec-freeworld \
    bleachbit \
    btrfs-progs \
    chromium \
    filezilla \
    flameshot \
    gnome-commander \
    gnome-tweaks \
    meld \
    menulibre \
    meson \
    mpv \
    python3-pip \
    solaar \
    solaar-udev \
    subversion \
    sshpass \
    tailscale \
    ulauncher \
    yt-dlp \
    dconf-editor \
    fastfetch \
    git \
    hdparm \
    ninja-build \
    sqlite \
    wl-clipboard \
    webkit2gtk4.0 \
    gtk3 \
    libicu \
    libjpeg-turbo \
    libwebp \
    flite \
    pcre \
    libffi \
    nss \
    bubblewrap \
    unzip

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

# Fedora-specific Homebrew packages
brew install volta
brew install webpack

# Install Bun
curl -fsSL https://bun.sh/install | bash

# Install wakatime-cli
echo "Installing wakatime-cli..."
brew install wakatime-cli

export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
if volta install node; then
    npm install -g claude-code-wakatime
    npm install -g postcss
    npm install -g postcss-cli
    npm install -g @github/copilot
else
    echo "WARNING: volta failed to install node; skipping npm packages" >&2
fi

# Set zsh as default shell
echo "Setting zsh as default shell..."
ZSH_PATH="$(command -v zsh)"
if ! grep -qF "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
fi
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    sudo chsh -s "$ZSH_PATH" "$USER"
    echo "Default shell changed to zsh. Re-login to apply."
else
    echo "zsh is already the default shell."
fi

echo "Fedora package installation complete!"
