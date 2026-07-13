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
# shellcheck source=lib/gogh_shared.sh
source "$SCRIPT_DIR/lib/gogh_shared.sh"

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
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi

# 3. Add Homebrew to ~/.bashrc (the installer's "Next steps"), idempotently.
#    The dotfiles' own .bashrc also evals brew shellenv, but this guarantees
#    Homebrew is available even when this script runs standalone.
if ! grep -qF 'brew shellenv' "$HOME/.bashrc" 2>/dev/null; then
    echo "Adding Homebrew to ~/.bashrc..."
    {
        echo ""
        echo "# Homebrew"
        # single quotes intentional: eval/$() is written literally into .bashrc
        # and expanded at login, not here. SC2016 (no expansion in singles) expected.
        # shellcheck disable=SC2016
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    } >> "$HOME/.bashrc"
fi

# 4. Install Node.js via Homebrew
if brew list --formula node >/dev/null 2>&1; then
    echo "Node.js already installed ($(brew list --versions node 2>/dev/null | awk '{print $2}'))."
else
    echo "Installing Node.js via Homebrew..."
    brew install node
fi

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
# Idempotent: skip the sudo dnf install if the release packages are present.
if rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
    echo "RPM Fusion repositories already installed, skipping."
else
    echo "Installing RPM Fusion repositories..."
    sudo dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf install -y "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi

# Install development tools group (idempotent: skip if group already installed,
# avoiding an unnecessary sudo prompt on re-runs)
if dnf group list --installed 2>/dev/null | grep -qi "development tools"; then
    echo "Development tools group already installed."
else
    echo "Installing development tools group..."
    sudo dnf group install -y --skip-unavailable development-tools
fi

# Install DNF packages
# NOTE: git is listed for completeness; on Fedora 44+ it is preinstalled and
# this line is a harmless no-op.
# --allowerasing: Fedora ships ffmpeg-free/libavcodec-free; RPM Fusion's full
# ffmpeg + libavcodec-freeworld replace them (removes the -free variants).
echo "Installing DNF packages..."
sudo dnf install -y --skip-unavailable --allowerasing \
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
    gnome-shell-extension-user-theme \
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
    dconf \
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
    unzip \
    podman \
    podman-docker \
    podman-compose

# Install full-codec Mesa VA/VDPAU drivers from RPM Fusion freeworld
# (replace stripped mesa-va-drivers/mesa-vdpau-drivers for HW video decode)
sudo dnf install -y --skip-unavailable --allowerasing mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld

# --- Code editors: VS Code, Sublime Text, Zed ------------------------------
# Each uses its own official repo/installer. Guarded so re-runs are no-ops.

# Visual Studio Code (Microsoft yum repo)
# https://code.visualstudio.com/docs/setup/linux
if ! rpm -q code >/dev/null 2>&1; then
    echo "Installing Visual Studio Code..."
    if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
            | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
    fi
    sudo dnf install -y code
else
    echo "Visual Studio Code already installed."
fi

# Sublime Text (Sublime HQ dnf repo, x86_64 only)
# https://www.sublimetext.com/docs/linux_repositories.html
# dnf5 (Fedora 41+) uses `config-manager addrepo --from-repofile=`;
# dnf4 uses `config-manager --add-repo`. Detect by subcommand availability.
if ! rpm -q sublime-text >/dev/null 2>&1; then
    echo "Installing Sublime Text..."
    sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
    if sudo dnf config-manager addrepo --help >/dev/null 2>&1; then
        sudo dnf config-manager addrepo \
            --from-repofile=https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
    else
        sudo dnf config-manager \
            --add-repo https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
    fi
    sudo dnf install -y sublime-text
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
if ! rpm -q brave-origin >/dev/null 2>&1; then
    echo "Installing Brave Origin..."
    curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin sh
else
    echo "Brave Origin already installed."
fi

# Install Ghostty terminal from COPR (scottames/ghostty)
# Idempotent: skip `copr enable` (and its warning reprint) if repo already enabled.
if ! ls /etc/yum.repos.d/_copr*scottames*ghostty*.repo >/dev/null 2>&1; then
    sudo dnf copr enable -y scottames/ghostty
fi
sudo dnf install -y ghostty

# Install keyd (key remapping daemon) from COPR (fmonteghetti/keyd)
# Not in Fedora repos; fmonteghetti/keyd is the maintained Fedora build.
# Idempotent: skip `copr enable` (and its warning reprint) if repo already enabled.
if ! rpm -q keyd >/dev/null 2>&1; then
    if ! ls /etc/yum.repos.d/_copr*fmonteghetti*keyd*.repo >/dev/null 2>&1; then
        sudo dnf copr enable -y fmonteghetti/keyd
    fi
    sudo dnf install -y keyd
fi

# Insync (Google Drive sync, official yum repo)
# https://www.insynchq.com/downloads/linux
# Repo baseurl uses $releasever so it tracks the running Fedora release.
if ! rpm -q insync >/dev/null 2>&1; then
    echo "Installing Insync..."
    sudo rpm --import https://d2t3ff60b2tol4.cloudfront.net/repomd.xml.key
    if [[ ! -f /etc/yum.repos.d/insync.repo ]]; then
        sudo tee /etc/yum.repos.d/insync.repo >/dev/null <<'REPO'
[insync]
name=insync repo
baseurl=http://yum.insync.io/fedora/$releasever/
gpgcheck=1
gpgkey=https://d2t3ff60b2tol4.cloudfront.net/repomd.xml.key
enabled=1
metadata_expire=120m
REPO
    fi
    sudo dnf install -y insync
else
    echo "Insync already installed."
fi

# Install Flatpak apps (bulk)
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

# Install common development tools via Homebrew (bulk)
echo "Installing Homebrew packages..."
install_shared_brew_packages

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

echo "Fedora package installation complete!"
