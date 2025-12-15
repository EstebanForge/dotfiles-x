# Load .zshrc.local if it exists
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi

# Speed up shell startup
#DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
#DISABLE_COMPFIX="true"

# Initialize completion system
autoload -Uz compinit
compinit

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# OS-specific Homebrew setup
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    eval "$(/opt/homebrew/bin/brew shellenv)" # Correct path for Apple Silicon (M-series)
elif [[ "$(uname)" == "Linux" ]]; then
    # Linux
    if command -v brew >/dev/null 2>&1; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="TCattd"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 30

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

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
    if [[ -d /home/linuxbrew/.linuxbrew/share/zsh-autosuggestions ]]; then
        source /home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    fi
    if [[ -d /home/linuxbrew/.linuxbrew/share/zsh-syntax-highlighting ]]; then
        source /home/linuxbrew/.linuxbrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    fi
fi

ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"
ZSH_AUTOSUGGEST_USE_ASYNC=1

######################
# User configuration #
######################

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='nano'
  else
    export EDITOR='nano'
fi

# Updaters
if [[ "$(uname)" == "Darwin" ]]; then
    brewup() {
        echo "Updating and upgrading Homebrew packages..."
        brew update && brew upgrade && brew cleanup
        echo "Homebrew packages updated and cleaned up."
    }
fi

# Enhanced system update function with dotfile integration
sysup() {
    echo "🔄 Starting system update with topgrade..."
    topgrade
    echo "✅ System update complete!"
    echo ""
    echo "🔍 Checking dotfile status..."
    cd ~/.dotfiles
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        echo "⚠️  Dotfiles have changes. Run 'dots status' to check."
    else
        echo "✅ Dotfiles are up to date!"
    fi
}

# Full system and dotfile update
sysup-full() {
    echo "🚀 Full system and dotfiles update..."
    echo ""

    # 1. Update system packages
    echo "1️⃣ Updating system packages..."
    sysup

    echo ""
    # 2. Update dotfiles
    echo "2️⃣ Updating dotfiles..."
    dots sync

    echo ""
    # 3. Complete status
    echo "🎉 Full update complete!"
    echo "💡 Run 'exec zsh' to reload shell with latest changes"
}

# Quick dotfile check (now uses dots.sh)
dots-check() {
    echo "🔍 Quick dotfile health check..."
    cd ~/.dotfiles
    ./dots.sh health
}

# Use gls (GNU ls) for enhanced functionality, including coloring and directory grouping.
if [[ "$(uname)" == "Darwin" ]]; then
    # The 'g' prefix is required when using coreutils installed via Homebrew.
    alias ls='gls -GFh --color -h --group-directories-first'
    alias ll='gls --color -alF --group-directories-first'
    alias la='gls --color -A'
    alias l='gls --color -CF'
elif [[ "$(uname)" == "Linux" ]]; then
    alias ls='ls -GFh --color -h --group-directories-first'
    alias ll='ls --color -alF --group-directories-first'
    alias la='ls --color -A'
    alias l='ls --color -CF'
fi
alias artisan='php artisan'
alias cat='bat'
alias qs='open -a "QSpace Pro"'

######################################
# PATH AND ENVIRONMENT CONFIGURATION #
######################################

# Volta (JavaScript Tool Manager)
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# PHP (from Homebrew) & Composer
# Add brew-installed PHP to the PATH
# Add Composer's vendor binaries to the PATH
export PATH="$HOME/.config/composer/vendor/bin:$PATH"
export COMPOSER_PROCESS_TIMEOUT=600

# User-specific binary paths
# This includes ~/.local/bin, which is a common place for user-installed scripts.
export PATH="$HOME/.local/bin:$PATH"

# HOMEBREW
export HOMEBREW_NO_ENV_HINTS=1

# Load secrets file if it exists
if [[ -f ~/.secrets ]]; then
    source ~/.secrets
fi

zai() {
    (
        #export ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
        #export ANTHROPIC_AUTH_TOKEN=$Z_API_KEY
        claude "$@"
    )
}

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"
# End of LM Studio CLI section

# Added by Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

# Wicket Tools PATH
export PATH="$HOME/.local/bin:$PATH"

# Load custom plugins
if [[ -n "$ZSH_VERSION" ]]; then
  # Zsh: use null_glob to avoid errors
  setopt NULL_GLOB 2>/dev/null || true
  for plugin in ~/.zsh/plugins/*.plugin.sh; do
    [[ -r "$plugin" ]] && source "$plugin"
  done
  unsetopt NULL_GLOB 2>/dev/null || true
else
  # Bash: check if files exist before looping
  for plugin in ~/.zsh/plugins/*.plugin.sh; do
    [[ -f "$plugin" && -r "$plugin" ]] && source "$plugin"
  done
fi