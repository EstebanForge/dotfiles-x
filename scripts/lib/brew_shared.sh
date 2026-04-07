#!/usr/bin/env bash

# Shared Homebrew taps and packages used by both macOS and Fedora installers.

SHARED_BREW_TAPS=(
    "EstebanForge/tap"
    "max-sixty/worktrunk"
    "shivammathur/tap"
)

SHARED_BREW_FORMULAE=(
    "ast-grep"
    "aws-nuke"
    "awscli"
    "bat"
    "cloudflared"
    "composer"
    "eza"
    "fastfetch"
    "fzf"
    "gemini-cli"
    "git"
    "git-delta"
    "go"
    "gulp-cli"
    "httpie"
    "just"
    "mkcert"
    "mise"
    "ripgrep"
    "shellcheck"
    "sshpass"
    "tailwindcss"
    "topgrade"
    "uv"
    "vite"
    "yamllint"
    "zoxide"
    "EstebanForge/tap/construct-cli"
    "EstebanForge/tap/mcp-cli-ent"
    "EstebanForge/tap/md-over-here"
    "max-sixty/worktrunk/wt"
    "shivammathur/tap/pcov@8.5"
)

brew_tap_list() {
    local tap
    for tap in "$@"; do
        brew tap "$tap"
    done
}

brew_install_list() {
    local package
    for package in "$@"; do
        brew install "$package"
    done
}

install_shared_brew_packages() {
    echo "Installing shared Homebrew taps..."
    brew_tap_list "${SHARED_BREW_TAPS[@]}"

    echo "Installing shared Homebrew formulae..."
    brew_install_list "${SHARED_BREW_FORMULAE[@]}"
}
