# Load .bashrc.local if it exists
if [[ -f ~/.bashrc.local ]]; then
    source ~/.bashrc.local
fi

######################
# Shell options      #
######################

# History
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

# If not running interactively, stop here
case $- in
    *i*) ;;
      *) return;;
esac

######################################
# OS / Distro detection              #
######################################

_distroname() {
    if [[ -f /etc/os-release ]]; then
        grep ^ID= /etc/os-release | head -1 | cut -d'=' -f2 | tr -d '"'
    fi
}

######################################
# Homebrew setup                     #
######################################

if [[ "$(uname)" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$(uname)" == "Linux" ]]; then
    if command -v brew >/dev/null 2>&1; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

######################################
# Prompt                             #
######################################

# Git branch in prompt
__git_branch() {
    local branch
    branch="$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null)"
    if [[ -n "$branch" ]]; then
        echo " ($branch)"
    fi
}

# Colored prompt
if [[ "$(uname)" == "Darwin" ]]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(__git_branch)\[\033[00m\]\$ '
else
    # Linux: show distro name
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(__git_branch)\[\033[00m\]\$ '
fi

######################################
# Completions                        #
######################################

# Enable programmable completion
if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    fi
fi

# Homebrew completions
if command -v brew >/dev/null 2>&1; then
    _brew_completion="$(brew --prefix)/etc/bash_completion"
    if [[ -f "$_brew_completion" ]]; then
        . "$_brew_completion"
    fi

    # Load individual Homebrew completions
    if [[ -d "$(brew --prefix)/etc/bash_completion.d" ]]; then
        for _bcfile in "$(brew --prefix)"/etc/bash_completion.d/*; do
            [[ -r "$_bcfile" ]] && . "$_bcfile"
        done
        unset _bcfile
    fi
    unset _brew_completion
fi

######################################
# User configuration                 #
######################################

export EDITOR='nano'

######################################
# Updaters                           #
######################################

if [[ "$(uname)" == "Darwin" ]]; then
    brewup() {
        echo "Updating and upgrading Homebrew packages..."
        brew update && brew upgrade && brew cleanup
        echo "Homebrew packages updated and cleaned up."
    }
fi

sysup() {
    echo "Starting system update with topgrade..."
    topgrade
    echo "System update complete!"
    echo ""
    echo "Checking dotfile status..."
    if [[ -d ~/.dotfiles ]]; then
        cd ~/.dotfiles || return 1
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            echo "Dotfiles have changes. Run 'dots status' to check."
        else
            echo "Dotfiles are up to date!"
        fi
    else
        echo "$HOME/.dotfiles directory not found"
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
    echo "Full update complete! Run 'exec bash' to reload shell"
}

dots-check() {
    echo "Quick dotfile health check..."
    cd ~/.dotfiles || return 1
    ./dots.sh health
}

######################################
# Aliases                            #
######################################

# ls aliases
if [[ "$(uname)" == "Darwin" ]]; then
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

alias cat='bat'
alias artisan='php artisan'

######################################
# PATH AND ENVIRONMENT               #
######################################

# PHP & Composer
export PATH="$HOME/.config/composer/vendor/bin:$PATH"
export COMPOSER_PROCESS_TIMEOUT=600

# User-specific binary paths
export PATH="$HOME/.local/bin:$PATH"

# HOMEBREW
export HOMEBREW_NO_ENV_HINTS=1

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

# Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

######################################
# Secrets                            #
######################################

if [[ -f ~/.secrets ]]; then
    source ~/.secrets
fi

######################################
# Custom plugins                     #
######################################

for plugin in ~/.bash/plugins/*.plugin.sh; do
    [[ -f "$plugin" && -r "$plugin" ]] && source "$plugin"
done
