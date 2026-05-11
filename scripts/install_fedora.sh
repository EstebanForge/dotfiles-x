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
flatpak install -y flathub app.drey.Dialect
flatpak install -y flathub app.drey.KeyRack
flatpak install -y flathub com.calibre_ebook.calibre
flatpak install -y flathub com.dec05eba.gpu_screen_recorder
flatpak install -y flathub com.github.gijsgoudzwaard.image-optimizer
flatpak install -y flathub com.github.huluti.Coulr
flatpak install -y flathub com.github.jeromerobert.pdfarranger
flatpak install -y flathub com.github.maoschanz.drawing
flatpak install -y flathub com.github.marktext.marktext
flatpak install -y flathub com.github.muriloventuroso.pdftricks
flatpak install -y flathub com.github.sdv43.whaler
flatpak install -y flathub com.github.tchx84.Flatseal
flatpak install -y flathub com.github.xournalpp.xournalpp
flatpak install -y flathub com.jgraph.drawio.desktop
flatpak install -y flathub com.transmissionbt.Transmission
flatpak install -y flathub dev.bragefuglseth.Keypunch
flatpak install -y flathub dev.deedles.Trayscale
flatpak install -y flathub dev.geopjr.Collision
flatpak install -y flathub fr.handbrake.ghb
flatpak install -y flathub io.github.cboxdoerfer.FSearch
flatpak install -y flathub com.felixnkate.Permute
flatpak install -y flathub com.amazonaws.SessionManagerPlugin
flatpak install -y flathub io.github.flattool.Warehouse
flatpak install -y flathub io.github.giantpinkrobots.flatsweep
flatpak install -y flathub io.github.peazip.PeaZip
flatpak install -y flathub io.github.plrigaux.sysd-manager
flatpak install -y flathub io.github.realmazharhussain.GdmSettings
flatpak install -y flathub io.github.thetumultuousunicornofdarkness.cpu-x
flatpak install -y flathub io.github.vikdevelop.SaveDesktop
flatpak install -y flathub io.gitlab.adhami3310.Converter
flatpak install -y flathub it.mijorus.gearlever
flatpak install -y flathub me.iepure.devtoolbox
flatpak install -y flathub net.filebot.FileBot
flatpak install -y flathub net.mediaarea.MediaInfo
flatpak install -y flathub net.nokyan.Resources
flatpak install -y flathub org.bunkus.mkvtoolnix-gui
flatpak install -y flathub org.gimp.GIMP
flatpak install -y flathub org.gnome.Extensions
flatpak install -y flathub org.gnome.gitlab.YaLTeR.VideoTrimmer
flatpak install -y flathub org.gnome.NetworkDisplays
flatpak install -y flathub org.gnome.seahorse.Application
flatpak install -y flathub org.gnome.World.PikaBackup
flatpak install -y flathub org.kde.kdenlive
flatpak install -y flathub org.kde.krita
flatpak install -y flathub org.mozilla.firefox
flatpak install -y flathub org.nickvision.tubeconverter
flatpak install -y flathub org.openshot.OpenShot
flatpak install -y flathub org.pitivi.Pitivi
flatpak install -y flathub org.raspberrypi.rpi-imager
flatpak install -y flathub org.remmina.Remmina
flatpak install -y flathub org.shotcut.Shotcut
flatpak install -y flathub org.signal.Signal
flatpak install -y flathub org.sqlitebrowser.sqlitebrowser
flatpak install -y flathub org.videolan.VLC
flatpak install -y flathub tv.plex.PlexDesktop
flatpak install -y flathub us.zoom.Zoom
flatpak install -y flathub org.nextcloud.Nextcloud

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

echo "Fedora package installation complete!"
