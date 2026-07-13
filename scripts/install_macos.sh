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

# Keep Homebrew non-interactive and quiet during this install.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ASK=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/brew_shared.sh
source "$SCRIPT_DIR/lib/brew_shared.sh"
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

# Update Homebrew + install latest bash, but only on the first pass.
# The script re-execs itself with Homebrew bash (BASH_RESTART=1) below; skip
# the update and bash install on that second pass to avoid duplicate work.
if [[ "${BASH_RESTART:-0}" != "1" ]]; then
    echo "Updating Homebrew..."
    brew update

    echo "Installing latest bash..."
    brew install bash

    # Restart script with new bash if we just installed it
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
install_shared_brew_packages

# Install formulae (command-line tools)
echo "Installing formulae..."
brew_install_list \
    progress \
    ffmpeg \
    subversion \
    jq \
    yq \
    mas \
    mkvtoolnix \
    mpv \
    node \
    openssl \
    php \
    qwen-code \
    specify \
    tailspin \
    tlrc \
    coreutils \
    gnu-sed \
    procs \
    python \
    sass/sass/sass \
    tailscale \
    mole \
    prettier \
    fastmod \
    tree \
    git-cliff \
    fd \
    sd \
    tmux \
    nss \
    unzip

# Install QuickLook plugins
echo "Installing QuickLook plugins..."
brew_ql_plugins=(
    quicklookase
    quickjson
)
# qlvideo requires macOS 26 (Tahoe) or newer; skip silently on older systems.
if [[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 26 ]]; then
    brew_ql_plugins+=(qlvideo)
fi
brew_install_cask_list "${brew_ql_plugins[@]}"

# Install casks (GUI applications)
echo "Installing casks..."
brew_install_cask_list \
    1password \
    alfred \
    alienator88-sentinel \
    apparency \
    bettermouse \
    bettertouchtool \
    beyond-compare \
    bitwarden \
    brave-origin \
    bruno \
    balenaetcher \
    calendr \
    calibre \
    cameracontroller \
    command-tab-plus \
    coteditor \
    cryptomator \
    daisydisk \
    ferdium \
    filebot \
    find-any-file \
    firefox \
    font-hack-nerd-font \
    font-iosevka-nerd-font \
    font-iosevka-term-nerd-font \
    font-meslo-lg-nerd-font \
    font-open-sans \
    font-oswald \
    ghostty \
    github \
    google-chrome \
    google-drive \
    iconchamp \
    iina \
    imageoptim \
    jump-desktop \
    jordanbaird-ice \
    keka \
    kextviewr \
    knockknock \
    lm-studio \
    mediainfo \
    middleclick \
    nordvpn \
    obsidian \
    orbstack \
    path-finder \
    pearcleaner \
    pictogram \
    qspace-pro \
    rectangle-pro \
    shotcut \
    shottr \
    signal \
    stay \
    sublime-merge \
    sublime-text \
    superkey \
    suspicious-package \
    taskexplorer \
    handbrake-app \
    permute \
    transmission \
    tuxera-ntfs \
    typora \
    uninstallpkg \
    utm \
    visual-studio-code \
    zed \
    zoom \
    elmedia-player \
    ente-auth

# zsh plugins (formulae, not casks)
brew_install_list \
    zsh-autosuggestions \
    zsh-completions \
    zsh-syntax-highlighting

# Fonts and remaining casks
brew_install_cask_list \
    font-inconsolata-nerd-font \
    font-arial \
    font-cantarell \
    font-roboto \
    font-iosevka \
    font-esteban \
    mission-control-plus \
    music-decoy \
    keepingyouawake \
    antigravity

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

# Install Gogh terminal color schemes (Catppuccin Mocha)
install_gogh_themes

echo "macOS package installation complete!"
