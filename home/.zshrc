# OPENSPEC:START
# OpenSpec shell completions configuration
fpath=("$HOME/.oh-my-zsh/custom/completions" $fpath)
autoload -Uz compinit
compinit
# OPENSPEC:END

# Load secrets file if it exists
if [[ -f ~/.secrets ]]; then
    source ~/.secrets
fi

# Speed up shell startup
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
#DISABLE_COMPFIX="true"

# Path to your Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# OS-specific Homebrew setup
if [[ "$(uname)" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$(uname)" == "Linux" ]]; then
    if command -v brew >/dev/null 2>&1; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

ZSH_THEME="TCattd"

zstyle ':omz:update' frequency 30

plugins=(
    git
    git-prompt
    aliases
)

source $ZSH/oh-my-zsh.sh

# OS-specific plugin loading
if [[ "$(uname)" == "Darwin" ]]; then
    source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    #source $HOMEBREW_PREFIX/share/zsh-completions/zsh-completions.zsh
elif [[ "$(uname)" == "Linux" ]]; then
    if [[ -d $HOMEBREW_PREFIX/share/zsh-autosuggestions ]]; then
        source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    fi
    if [[ -d $HOMEBREW_PREFIX/share/zsh-syntax-highlighting ]]; then
        source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    fi
fi

ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"
ZSH_AUTOSUGGEST_USE_ASYNC=1

# https://github.com/ajeetdsouza/zoxide
eval "$(zoxide init zsh)"

######################
# User configuration #
######################

# Bitwarden SSH-Agent (macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
    launchctl setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK"
fi

# Preferred editor
export EDITOR='nano'

# Brewup updater
# Upgrades formulae and casks separately: a single OS-incompatible cask
# (e.g. one requiring a newer macOS) must not abort the whole run or skip cleanup.
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

# PHP version switcher. Default = 8.3 (set once via `brew link --force php@8.3`, persistent).
# Keeps 8.2/8.3/8.4/8.5 installed; all unpinned so brewup updates them.
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

# Topgrade Updater
sysup() {
    topgrade
}

# OS-specific ls aliases
if [[ "$(uname)" == "Darwin" ]]; then
    # gls (GNU ls) via Homebrew coreutils
    alias ls='gls -GFh --color -h --group-directories-first'
    alias ll='gls --color -alF --group-directories-first'
    alias la='gls --color -A'
    alias l='gls --color -CF'
    alias qs='open -a "QSpace Pro"'
elif [[ "$(uname)" == "Linux" ]]; then
    alias ls='ls -GFh --color -h --group-directories-first'
    alias ll='ls --color -alF --group-directories-first'
    alias la='ls --color -A'
    alias l='ls --color -CF'
fi

alias artisan='php artisan'
alias cat='bat'

# --- Sandbox Control (UTM, macOS only) ---
if [[ "$(uname)" == "Darwin" ]]; then
    alias sbdown='utmctl stop "Fedora Server"'
    alias sbssh='ssh sandbox'
    alias sbstatus='utmctl list | grep "Fedora Server"'

    sbup() {
        echo "🚀 Starting Sandbox..."
        utmctl start "Fedora Server"

        echo -n "⏳ Waiting for SSH..."
        while ! nc -z -G 1 192.168.64.10 22 > /dev/null 2>&1; do
            sleep 1
            echo -n "."
        done
        echo "\n✅ Sandbox is online!"
    }
fi

######################################
# PATH AND ENVIRONMENT CONFIGURATION #
######################################

# PHP & Composer
export PATH="$HOME/.config/composer/vendor/bin:$PATH"
export COMPOSER_PROCESS_TIMEOUT=1800

# User-specific binary paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# HOMEBREW
export HOMEBREW_NO_ENV_HINTS=1

# Bun (macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="$HOME/.bun/bin:$PATH"
fi

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

# Go (Golang)
export GOPATH="$HOME/.local/share/go"
export PATH="$GOPATH/bin:$PATH"

# LLVM & OpenJDK (macOS, via Homebrew)
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
    export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
fi

# Antigravity (macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
    export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"
fi

# Load custom plugins from ~/.zsh/plugins/
if [[ -n "$ZSH_VERSION" ]]; then
    setopt NULL_GLOB 2>/dev/null || true
    for plugin in ~/.zsh/plugins/*.plugin.sh; do
        [[ -r "$plugin" ]] && source "$plugin"
    done
    unsetopt NULL_GLOB 2>/dev/null || true
else
    for plugin in ~/.zsh/plugins/*.plugin.sh; do
        [[ -f "$plugin" && -r "$plugin" ]] && source "$plugin"
    done
fi

eval "$(atuin init zsh)"

# Wicket completions (macOS)
if [[ "$(uname)" == "Darwin" ]] && [[ -f "$HOME/.zshrc.wicket" ]]; then
    source "$HOME/.zshrc.wicket"
fi

# ZAI API wrapper (requires Z_API_KEY in ~/.secrets)
ns-cc-zai() {
    export ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY"
    export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
    export API_TIMEOUT_MS="3000000"

    export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5-turbo"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.1"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.1"

    claude "$@"
}

# Construct-cli agent aliases (requires construct-cli installed)
if command -v ct >/dev/null 2>&1; then
    alias agy='ct agy'
    alias claude='ct claude'
    alias amp='ct amp'
    alias qwen='ct qwen'
    alias copilot='ct copilot'
    alias opencode='ct opencode'
    alias cline='ct cline'
    alias crush='ct crush'
    alias codex='ct codex'
    alias droid='ct droid'
    alias goose='ct goose'
    alias kilocode='ct kilocode'
    alias pi='ct pi'
    alias cc-kimi='ct cc kimi'
    alias cc-mimo='ct cc mimo'
    alias cc-minimax='ct cc minimax'
    alias cc-qwen='ct cc qwen'
    alias cc-zai='ct cc zai'

    # Non-sandboxed aliases - run agents directly
    ns-agy() { command agy "$@"; }
    ns-claude() { command claude "$@"; }
    ns-qwen() { command qwen "$@"; }
    ns-copilot() { command copilot "$@"; }
    ns-opencode() { command opencode "$@"; }
    ns-cline() { command cline "$@"; }
    ns-codex() { command codex "$@"; }
    ns-droid() { command droid "$@"; }
    ns-kilocode() { command kilocode "$@"; }
    ns-pi() { command pi "$@"; }
fi

# Load Fuse Agents plugin
if [[ -f "$HOME/.zsh/plugins/fuse-agents/fuse-agents.plugin.sh" ]]; then
    source "$HOME/.zsh/plugins/fuse-agents/fuse-agents.plugin.sh"
fi

# Route puppeteer (mermaid-cli, etc.) to system Chrome; auto-skips bundled download.
# Setting PUPPETEER_EXECUTABLE_PATH flips puppeteer's skipDownload=true, so global
# npm installs (topgrade) stop fetching chrome-headless-shell and use this binary instead.
if [[ "$(uname)" == "Darwin" ]]; then
    export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
fi
