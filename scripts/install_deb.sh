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

# Keep Homebrew non-interactive and quiet during this install.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ASK=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/brew_shared.sh
source "$SCRIPT_DIR/lib/brew_shared.sh"
# shellcheck source=lib/flatpak_shared.sh
source "$SCRIPT_DIR/lib/flatpak_shared.sh"
# shellcheck source=lib/fonts_shared.sh
source "$SCRIPT_DIR/lib/fonts_shared.sh"
# shellcheck source=lib/themes_shared.sh
source "$SCRIPT_DIR/lib/themes_shared.sh"
# shellcheck source=lib/icons_reversal_shared.sh
source "$SCRIPT_DIR/lib/icons_reversal_shared.sh"
# shellcheck source=lib/antigravity_cli.sh
source "$SCRIPT_DIR/lib/antigravity_cli.sh"
# shellcheck source=lib/claude_code_cli.sh
source "$SCRIPT_DIR/lib/claude_code_cli.sh"
# shellcheck source=lib/phpvm_cli.sh
source "$SCRIPT_DIR/lib/phpvm_cli.sh"
# shellcheck source=lib/npm_globals.sh
source "$SCRIPT_DIR/lib/npm_globals.sh"
# shellcheck source=lib/bun_cli.sh
source "$SCRIPT_DIR/lib/bun_cli.sh"
# shellcheck source=lib/codex_cli.sh
source "$SCRIPT_DIR/lib/codex_cli.sh"
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"
# shellcheck source=lib/gogh_shared.sh
source "$SCRIPT_DIR/lib/gogh_shared.sh"

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

# Install build-essential (equivalent to Development Tools group, idempotent)
if dpkg -l build-essential >/dev/null 2>&1; then
    echo "build-essential already installed."
else
    echo "Installing build-essential..."
    sudo apt install -y build-essential
fi

# Install apt packages
echo "Installing apt packages..."
sudo apt install -y \
    xdotool \
    android-tools-adb \
    android-tools-fastboot \
    fd-find \
    ffmpeg \
    python3-nautilus \
    gnome-shell-extension-user-theme \
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
    dconf-cli \
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
    uuid-runtime \
    curl \
    wget \
    tree \
    tmux \
    jq \
    podman \
    podman-docker \
    podman-compose

# --- Code editors: VS Code, Sublime Text, Zed ------------------------------
# Each uses its own official repo/installer. Guarded so re-runs are no-ops.

# Visual Studio Code (Microsoft apt repo, deb822 sources format)
# https://code.visualstudio.com/docs/setup/linux
if ! dpkg -l code >/dev/null 2>&1; then
    echo "Installing Visual Studio Code..."
    if [[ ! -f /etc/apt/sources.list.d/vscode.sources ]]; then
        sudo apt install -y wget gpg
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
            | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
        echo -e 'Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\nArchitectures: amd64,arm64,armhf\nSigned-By: /usr/share/keyrings/microsoft.gpg' \
            | sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null
    fi
    sudo apt update
    sudo apt install -y code
else
    echo "Visual Studio Code already installed."
fi

# Sublime Text (Sublime HQ apt repo, deb822 sources format)
# https://www.sublimetext.com/docs/linux_repositories.html
if ! dpkg -l sublime-text >/dev/null 2>&1; then
    echo "Installing Sublime Text..."
    sudo install -d -m 0755 /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/sublimehq-pub.asc ]]; then
        wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg \
            | sudo tee /etc/apt/keyrings/sublimehq-pub.asc >/dev/null
    fi
    if [[ ! -f /etc/apt/sources.list.d/sublime-text.sources ]]; then
        echo -e 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc' \
            | sudo tee /etc/apt/sources.list.d/sublime-text.sources >/dev/null
    fi
    sudo apt update
    sudo apt install -y sublime-text
else
    echo "Sublime Text already installed."
fi

# Zed (official curl installer -> ~/.local, user-space, no repo)
# https://zed.dev/docs/linux
if command -v zed >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/zed" ]]; then
    echo "Zed already installed."
else
    echo "Installing Zed..."
    curl -f https://zed.dev/install.sh | sh
fi

# Brave Origin browser (official installer, distro-aware: adds repo + package)
# https://github.com/brave/install.sh
# FLAVOR=origin = privacy-first build (no crypto/rewards). Installs `brave-origin`.
if ! dpkg -l brave-origin >/dev/null 2>&1; then
    echo "Installing Brave Origin..."
    curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin sh
else
    echo "Brave Origin already installed."
fi

# Install tailscale via official script (not in standard apt repos)
if ! command -v tailscale >/dev/null 2>&1; then
    echo "Installing tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Install Ghostty terminal (mkasberg/ghostty-ubuntu)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"

# Insync (Google Drive sync, official apt repo)
# https://www.insynchq.com/downloads/linux
# Insync requires distro + codename (lowercase) in the repo line. We map our
# distro family to Insync's supported apt distribution; codename comes from
# os-release (preferring UBUNTU_CODENAME, which Ubuntu-derivatives export).
if ! dpkg -l insync >/dev/null 2>&1; then
    echo "Installing Insync..."
    . /etc/os-release
    _insync_codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    _insync_codename="${_insync_codename,,}"
    case "$ID" in
        linuxmint)                      _insync_dist="mint"   ;;
        debian)                         _insync_dist="debian" ;;
        ubuntu|pop|zorin*|elementary*)  _insync_dist="ubuntu" ;;
        *)                              _insync_dist="debian" ;;
    esac
    if [[ ! -f /etc/apt/trusted.gpg.d/insynchq.gpg ]]; then
        curl -fsSL https://apt.insync.io/insynchq.gpg \
            | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/insynchq.gpg
    fi
    if [[ ! -f /etc/apt/sources.list.d/insync.list ]]; then
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/insynchq.gpg] http://apt.insync.io/$_insync_dist $_insync_codename non-free contrib" \
            | sudo tee /etc/apt/sources.list.d/insync.list >/dev/null
    fi
    sudo apt update
    sudo apt install -y insync
    unset _insync_dist _insync_codename
else
    echo "Insync already installed."
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

# Install fonts (Iosevka + SF Pro) into ~/.local/share/fonts
echo "Installing user fonts..."
install_shared_fonts

# Install Flat Remix GNOME Shell themes into ~/.themes
echo "Installing GNOME themes..."
install_flat_remix_theme

# Install Gogh terminal color schemes (Catppuccin Mocha)
install_gogh_themes

# Install Reversal icon theme into ~/.local/share/icons
echo "Installing Reversal icon theme..."
install_reversal_icon_theme

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
if brew list --formula node >/dev/null 2>&1; then
    echo "Node.js already installed ($(brew list --versions node 2>/dev/null | awk '{print $2}'))."
else
    brew install node
fi

# Install Bun (official installer)
install_bun_cli

# Install global npm packages (Node is provided by Homebrew)
install_npm_globals

# Install phpvm (PHP version manager)
install_phpvm_cli

# Install Claude Code (official installer, maintained by Anthropic)
install_claude_code_cli

# Install Codex CLI (official installer)
install_codex_cli

# Install Antigravity CLI (Google's replacement for Gemini CLI)
install_antigravity_cli

echo "Deb-based package installation complete!"
