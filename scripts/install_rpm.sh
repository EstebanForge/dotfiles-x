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
# The foundational toolchain (Phase 1) is installed FIRST and in order, since
# the rest of the setup depends on it. Bulk packages (Phase 2) come after.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/brew_shared.sh
source "$SCRIPT_DIR/lib/brew_shared.sh"
# shellcheck source=lib/flatpak_shared.sh
source "$SCRIPT_DIR/lib/flatpak_shared.sh"
# shellcheck source=lib/antigravity_cli.sh
source "$SCRIPT_DIR/lib/antigravity_cli.sh"

# ===========================================================================
# PHASE 1: Foundational setup (run FIRST, in this exact order)
# Prerequisite: update the system once before running this script:
#   sudo dnf update -y
# Then this phase installs the foundational toolchain (idempotent):
#   1. Bitwarden Flatpak            (its own step, before the bulk Flatpaks)
#   2. Homebrew
#   3. Homebrew -> ~/.bashrc        (the installer's "Next steps")
#   4. Node.js via Homebrew
#   5. pi.dev agent                 (requires Node)
# These are prerequisites for everything that follows.
# ===========================================================================

# 1. Bitwarden Flatpak (installed on its own, not as part of the bulk Flatpak run)
echo "Ensuring Flathub remote is available..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
if flatpak list --columns=application 2>/dev/null | grep -qx com.bitwarden.desktop; then
    echo "Bitwarden Flatpak already installed."
else
    echo "Installing Bitwarden Flatpak..."
    flatpak install -y flathub com.bitwarden.desktop
fi

# 2. Install Homebrew for Linux (if not already installed)
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew for Linux..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put Homebrew on PATH for the rest of this script
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -d "$HOME/.linuxbrew" ]]; then
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi

# 3. Add Homebrew to ~/.bashrc (the installer's "Next steps"), idempotently.
#    The dotfiles' own .bashrc also evals brew shellenv, but this guarantees
#    Homebrew is available even when this script runs standalone.
if ! grep -qF 'brew shellenv' "$HOME/.bashrc" 2>/dev/null; then
    echo "Adding Homebrew to ~/.bashrc..."
    {
        echo ""
        echo "# Homebrew"
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    } >> "$HOME/.bashrc"
fi

# 4. Install Node.js via Homebrew
echo "Installing Node.js via Homebrew..."
brew install node

# 5. Install the pi.dev agent (requires Node/npm)
echo "Installing pi.dev agent..."
if command -v pi >/dev/null 2>&1; then
    echo "pi.dev agent already installed ($(pi --version 2>/dev/null || echo "unknown version"))."
else
    curl -fsSL https://pi.dev/install.sh | sh
fi

# ===========================================================================
# PHASE 2: System packages and configuration (the rest)
# ===========================================================================

# Install RPM Fusion repositories (for proprietary codecs)
echo "Installing RPM Fusion repositories..."
sudo dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf install -y "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Install development tools group
echo "Installing development tools group..."
sudo dnf group install -y --skip-unavailable development-tools

# Install DNF packages
# NOTE: git is listed for completeness; on Fedora 44+ it is preinstalled and
# this line is a harmless no-op.
echo "Installing DNF packages..."
sudo dnf install -y --skip-unavailable \
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

# Install Flatpak apps (bulk)
echo "Installing Flatpak apps..."
install_shared_flatpak_apps

# Install common development tools via Homebrew (bulk)
echo "Installing Homebrew packages..."
install_shared_brew_packages

# Install Bun
curl -fsSL https://bun.sh/install | bash

# Global npm packages (Node is provided by Homebrew in Phase 1)
if command -v npm >/dev/null 2>&1; then
    echo "Installing global npm packages..."
    npm install -g postcss
    npm install -g postcss-cli
    npm install -g @github/copilot
else
    echo "WARNING: npm not found; skipping global npm packages." >&2
fi

# Install Antigravity CLI (Google's replacement for Gemini CLI)
install_antigravity_cli

echo "Fedora package installation complete!"
