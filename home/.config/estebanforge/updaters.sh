# shellcheck shell=bash
# Cross-shell updaters (bash + zsh). sysup is one implementation for both
# shells: topgrade first, then dotfile health through the global `dots`
# command, so no hardcoded repo path (~/.dotfiles) survives here.

sysup() {
    echo "Starting system update with topgrade..."
    topgrade
    echo "System update complete!"
    echo ""
    echo "Checking dotfile health..."
    if command -v dots >/dev/null 2>&1; then
        dots doctor
    else
        echo "dots not found on PATH (expected ~/.local/bin/dots)"
    fi
}

sysup-full() {
    echo "Full system and dotfiles update..."
    echo ""
    echo "1. Updating system packages..."
    sysup
    echo ""
    echo "2. Updating dotfiles..."
    dots sync
    echo ""
    echo "Full update complete! Reload your shell (exec zsh / exec bash)."
}

dots-check() {
    dots doctor
}

sysclean() {
    echo "Starting system cleanup..."

    if command -v brew >/dev/null 2>&1; then
        echo "Cleaning Homebrew cache..."
        brew cleanup --prune=all
    fi

    if command -v podman >/dev/null 2>&1; then
        echo "Pruning Podman system..."
        podman system prune -f
    fi

    if command -v npm >/dev/null 2>&1; then
        echo "Cleaning npm cache..."
        npm cache clean --force
    fi

    if command -v go >/dev/null 2>&1; then
        echo "Cleaning Go caches..."
        go clean -cache
        go clean -modcache
    fi

    if command -v cargo-cache >/dev/null 2>&1; then
        echo "Cleaning Cargo cache..."
        cargo cache -a
    elif [ -d "${CARGO_HOME:-$HOME/.cargo}/registry/cache" ]; then
        echo "Cleaning Cargo registry cache..."
        rm -rf "${CARGO_HOME:-$HOME/.cargo}/registry/cache"/*
    fi

    if command -v journalctl >/dev/null 2>&1; then
        echo "Vacuuming user journal logs..."
        journalctl --user --vacuum-size=200M 2>/dev/null || true
    fi

    echo "System cleanup complete!"
}
