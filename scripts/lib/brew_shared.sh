#!/usr/bin/env bash

# Shared Homebrew taps and packages used by both macOS and Fedora installers.

SHARED_BREW_TAPS=(
    "EstebanForge/tap"
    "rtk-ai/tap"
)

SHARED_BREW_FORMULAE=(
    "ast-grep"
    "atuin"
    "aws-nuke"
    "awscli"
    "bat"
    "biome"
    "cloudflared"
    "composer"
    "deno"
    "eza"
    "fastfetch"
    "fzf"
    "git"
    "git-delta"
    "gh"
    "go"
    "golangci-lint"
    "gulp-cli"
    "httpie"
    "imagemagick"
    "just"
    "lazydocker"
    "lazygit"
    "lftp"
    "mise"
    "mkcert"
    "nmap"
    "opencode"
    "php"
    "php@8.2"
    "php@8.3"
    "php@8.4"
    "rclone"
    "ripgrep"
    "rtk-ai/tap/rtk"
    "rust"
    "shellcheck"
    "sshpass"
    "tailwindcss"
    "topgrade"
    "uv"
    "vite"
    "webpack"
    "yamllint"
    "zoxide"
    "EstebanForge/tap/construct-cli"
    "EstebanForge/tap/mcp-cli-ent"
    "EstebanForge/tap/md-over-here"
)

brew_tap_list() {
    local tap
    for tap in "$@"; do
        brew tap "$tap"
    done
}

brew_install_list() {
    local package short_name
    for package in "$@"; do
        # Idempotent: skip packages already installed. Tapped formulae
        # (e.g. "EstebanForge/tap/construct-cli") register under their short
        # name, so strip everything before the last "/" for the lookup.
        short_name="${package##*/}"
        if brew list --formula "$short_name" >/dev/null 2>&1; then
            continue
        fi
        brew install "$package"
    done
}

install_shared_brew_packages() {
    # Keep Homebrew non-interactive during scripted installs.
    export HOMEBREW_NO_AUTO_UPDATE=1

    echo "Installing shared Homebrew taps..."
    brew_tap_list "${SHARED_BREW_TAPS[@]}"

    # Trust the taps so their formulae install without an interactive
    # "Do you want to proceed with the installation?" prompt.
    local tap
    for tap in "${SHARED_BREW_TAPS[@]}"; do
        brew trust "$tap" 2>/dev/null || true
    done

    echo "Installing shared Homebrew formulae..."
    brew_install_list "${SHARED_BREW_FORMULAE[@]}"
}
