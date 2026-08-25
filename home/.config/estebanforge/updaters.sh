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
        dots health
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
    dots health
}
