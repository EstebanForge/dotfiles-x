# Cross-shell dev tooling (bash + zsh). Both helpers are Homebrew-based and
# work on every platform these dotfiles support (brew is the shared package
# manager). Previously zsh-only; .bashrc gains them through this file.

# Brewup updater
# Upgrades formulae and casks separately: a single OS-incompatible cask
# (e.g. one requiring a newer macOS) must not abort the whole run or skip
# cleanup.
brewup() {
    echo "Updating Homebrew packages..."
    brew update
    brew upgrade --formula
    for cask in $(brew outdated --cask --greedy -q); do
        brew upgrade --cask "$cask" || echo "  -> skipped: $cask"
    done
    brew cleanup
    echo "Homebrew packages updated and cleaned up."
}

# PHP version switcher. Default = 8.3 (set once via `brew link --force
# php@8.3`, persistent). Keeps 8.2/8.3/8.4/8.5 installed; all unpinned so
# brewup updates them.
phpv() {
    local target
    case "$1" in
        8.5) target="php" ;;
        8.2|8.3|8.4) target="php@$1" ;;
        "") echo "usage: phpv <8.2|8.3|8.4|8.5>"; return 2 ;;
        *) echo "phpv: unsupported version '$1'"; return 1 ;;
    esac
    brew list --formula "$target" >/dev/null 2>&1 || { echo "phpv: $target not installed"; return 1; }
    brew unlink php php@8.2 php@8.3 php@8.4 2>/dev/null
    brew link --force --overwrite "$target"
    php --version | head -1
}
