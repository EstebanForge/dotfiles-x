#!/bin/bash

# macOS Homebrew packages installation script
# This script installs all Homebrew packages and casks

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Install taps
echo "Installing taps..."
brew tap pakerwreah/calendr

# Install formulae (command-line tools)
echo "Installing formulae..."
brew install alienator88-sentinel
brew install bash
brew install bat
brew install codex
brew install composer
brew install cv
brew install fastfetch
brew install ffmpeg
brew install gemini-cli
brew install git
brew install gulp-cli
brew install handbrake
brew install markedit
brew install mas
brew install mkvtoolnix
brew install mpv
brew install node
brew install openssl
brew install pearcleaner
brew install php
brew install php-cs-fixer
brew install qwen-code
brew install specify
brew install tailspin
brew install tailwindcss
brew install volta
brew install wp-cli
brew install yarn
brew install yt-dlp
brew install aliases
brew install coreutils
brew install python
brew install sass/sass/sass
brew install tailscale
brew install github-copilot-cli
brew install gh
brew install prettier
brew install fastmod
brew install topgrade

# Install QuickLook plugins
echo "Installing QuickLook plugins..."
brew install --cask qlmarkdown
brew install --cask quickjson
brew install --cask suspicious-package
brew install --cask apparency
brew install --cask quicklookase

# Install casks (GUI applications)
echo "Installing casks..."
brew install --cask 1password
brew install --cask affinity-designer
brew install --cask affinity-photo
brew install --cask alfred
brew install --cask bettermouse
brew install --cask beyond-compare
brew install --cask bitwarden
brew install --cask brave-browser
brew install --cask bruno
brew install --cask balenaetcher
brew install --cask calendr
brew install --cask calibre
brew install --cask claude-code
brew install --cask command-tab-plus
brew install --cask commander-one
brew install --cask coteditor
brew install --cask cryptomator
brew install --cask daisydisk
brew install --cask dbeaver-community
brew install --cask displaylink
brew install --cask ferdium
brew install --cask filebot
brew install --cask firefox
brew install --cask font-iosevka-nerd-font
brew install --cask font-iosevka-term-nerd-font
brew install --cask ghostty
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
brew install --cask opencode
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
brew install --cask the-unarchiver
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
brew install --cask zsh-autosuggestions
brew install --cask zsh-completions
brew install --cask zsh-syntax-highlighting
brew install --cask ungoogled-chromium
brew install --cask font-inconsolata-nerd-font
brew install --cask font-arial
brew install --cask font-cantarell
brew install --cask font-roboto
brew install --cask font-iosevka
brew install --cask font-esteban
brew install --cask gas-mask
brew install --cask mission-control-plus
brew install --cask sensei
brew install --cask keepingyouawake

# Install npm packages
echo "Installing npm packages..."
npm install -g claude-code-wakatime
npm install -g postcss
npm install -g postcss-cli
npm install -g @github/copilot

echo "macOS package installation complete!"