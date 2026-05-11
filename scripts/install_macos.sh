#!/usr/bin/env bash

# Re-exec with Bash when invoked from another shell (for example: zsh script.sh).
if [[ -z "${BASH_VERSION:-}" ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "This script requires Bash to run." >&2
    exit 1
fi

# macOS Homebrew packages installation script
# This script installs all Homebrew packages and casks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/brew_shared.sh
source "$SCRIPT_DIR/lib/brew_shared.sh"

ensure_xcode_clt() {
    if xcode-select -p >/dev/null 2>&1 && [[ -d "/Library/Developer/CommandLineTools" ]]; then
        return
    fi

    echo "Xcode Command Line Tools are not installed. Triggering installation..."
    xcode-select --install || true
    echo "Complete Command Line Tools installation, then rerun this script."
    exit 0
}

ensure_homebrew_permissions() {
    local brew_prefix user_name
    local -a fix_paths=()

    brew_prefix="$(brew --prefix)"
    user_name="${SUDO_USER:-$USER}"

    local -a candidates=(
        "$HOME/Library/Caches/Homebrew"
        "$HOME/Library/Logs/Homebrew"
        "$brew_prefix"
        "$brew_prefix/Caskroom"
    )

    local path
    for path in "${candidates[@]}"; do
        [[ -e "$path" ]] || continue
        if [[ ! -w "$path" ]]; then
            fix_paths+=("$path")
        fi
    done

    if (( ${#fix_paths[@]} > 0 )); then
        echo "Fixing Homebrew permissions..."
        sudo chown -R "$user_name" "${fix_paths[@]}"
        sudo chmod -R u+rwX "${fix_paths[@]}"
    fi
}

# Install Homebrew first
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

ensure_xcode_clt
ensure_homebrew_permissions

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Install latest bash
echo "Installing latest bash..."
brew install bash

# Restart script with new bash if we just installed it
if [[ "${BASH_RESTART:-0}" != "1" ]]; then
    echo "Restarting script with updated bash..."
    for _new_bash in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$_new_bash" ]]; then
            BASH_RESTART=1 exec "$_new_bash" "$0" "$@"
        fi
    done
fi

# Install taps
echo "Installing taps..."
brew tap pakerwreah/calendr
brew tap oven-sh/bun
install_shared_brew_packages

# Install formulae (command-line tools)
echo "Installing formulae..."
brew install alienator88-sentinel
brew install codex
brew install cv
brew install ffmpeg
brew install subversion
brew install jq
brew install yq
brew install zola
brew install mas
brew install mkvtoolnix
brew install music-decoy
brew install mpv
brew install node
brew install openssl
brew install pearcleaner
brew install php
brew install php-cs-fixer
brew install qwen-code
brew install specify
brew install tailspin
brew install volta
brew install wp-cli
brew install yarn
brew install yt-dlp
brew install tlrc
brew install aliases
brew install coreutils
brew install gnu-sed
brew install procs
brew install python
brew install sass/sass/sass
brew install tailscale
brew install gh
brew install prettier
brew install fastmod
brew install tree
brew install git-cliff
brew install fd
brew install sd
brew install tmux
brew install nss
brew install oven-sh/bun/bun
brew install unzip

# Install QuickLook plugins
echo "Installing QuickLook plugins..."
brew install qlimagesize suspicious-package apparency quicklookase qlvideo
brew install --cask quickjson
brew install --cask keka

# Install casks (GUI applications)
echo "Installing casks..."
brew install --cask 1password
brew install --cask alfred
brew install --cask bettermouse
brew install --cask bettertouchtool
brew install --cask beyond-compare
brew install --cask bitwarden
brew install --cask brave-browser
brew install --cask bruno
brew install --cask balenaetcher
brew install --cask calendr
brew install --cask calibre
brew install --cask claude-code
brew install --cask command-tab-plus
brew install --cask coteditor
brew install --cask cryptomator
brew install --cask daisydisk
brew install --cask dbeaver-community
brew install --cask ferdium
brew install --cask filebot
brew install --cask firefox
brew install --cask font-iosevka-nerd-font
brew install --cask font-iosevka-term-nerd-font
brew install --cask font-open-sans
brew install --cask font-oswald
brew install --cask github
brew install --cask google-drive
brew install --cask iconchamp
brew install --cask iina
brew install --cask imageoptim
brew install --cask jump-desktop
brew install --cask jordanbaird-ice
brew install --cask kextviewr
brew install --cask knockknock
brew install --cask lm-studio
brew install --cask localsend
brew install --cask lulu
brew install --cask macwhisper
brew install --cask mediainfo
brew install --cask middleclick
brew install --cask nordvpn
brew install --cask obsidian
brew install --cask orbstack
brew install --cask path-finder
brew install --cask qspace-pro
brew install --cask rectangle-pro
brew install --cask shottr
brew install --cask signal
brew install --cask stay
brew install --cask sublime-merge
brew install --cask sublime-text
brew install --cask superkey
brew install --cask taskexplorer
brew install --cask handbrake-app
brew install --cask permute
brew install --cask session-manager-plugin

brew install --cask transmission
brew install --cask tuxera-ntfs
brew install --cask typora
brew install --cask uninstallpkg
brew install --cask utm
brew install --cask visual-studio-code
brew install --cask windsurf
brew install --cask zoom
brew install --cask elmedia-player
brew install --cask unite
brew install zsh-autosuggestions
brew install zsh-completions
brew install zsh-syntax-highlighting
brew install --cask ungoogled-chromium
brew install --cask font-inconsolata-nerd-font
brew install --cask font-arial
brew install --cask font-cantarell
brew install --cask font-roboto
brew install --cask font-iosevka
brew install --cask font-esteban
brew install --cask mission-control-plus
brew install --cask sensei
brew install --cask keepingyouawake
brew install --cask nextcloud
brew install --cask claude
brew install --cask antigravity

# Install npm packages
echo "Installing npm packages..."
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

# Install wakatime-cli
echo "Installing wakatime-cli..."
brew install wakatime-cli

echo "macOS package installation complete!"
