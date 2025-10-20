# Load .zshrc.local if it exists
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi

# Speed up shell startup
#DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
#DISABLE_COMPFIX="true"

# This block initializes the completion system with intelligent caching
if [[ -z "$__comp_init_p" ]]; then
  autoload -Uz compinit
  __comp_init_p=1 # Mark as initialized

  # Check if a .zcompdump file exists and was modified in the last day
  if [[ -n "${ZDOTDIR:-$HOME}/.zcompdump"(#qN.md-1) ]]; then
    compinit -C # Load from cache, NO security bypass
  else
    compinit -d "${ZDOTDIR:-$HOME}/.zcompdump" # Rebuild, NO security bypass
  fi
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# 1. Homebrew (macOS)
eval "$(/opt/homebrew/bin/brew shellenv)" # Correct path for Apple Silicon (M-series)

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

source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh

source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#source $HOMEBREW_PREFIX/share/zsh-completions/zsh-completions.zsh

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
brewup() {
    echo "Updating and upgrading Homebrew packages..."
    brew update && brew upgrade && brew cleanup
    echo "Homebrew packages updated and cleaned up."
}

sysup() {
    topgrade
}

# Use gls (GNU ls) for enhanced functionality, including coloring and directory grouping.
# The 'g' prefix is required when using coreutils installed via Homebrew.
alias ls='gls -GFh --color -h --group-directories-first'
alias ll='gls --color -alF --group-directories-first'
alias la='gls --color -A'
alias l='gls --color -CF'
alias artisan='php artisan'
alias cat='bat'

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

# Claude code with Z's GLM
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
export PATH="/Users/esteban/.codeium/windsurf/bin:$PATH"

# Wicket Tools PATH
export PATH="/Users/esteban/.local/bin:$PATH"
