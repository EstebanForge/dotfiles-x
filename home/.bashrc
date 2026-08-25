######################################
# System integration                 #
######################################

# Source system-wide bashrc (Fedora/RHEL) if present
if [[ -f /etc/bashrc ]]; then
    source /etc/bashrc
fi

# Source drop-in snippets (Fedora's ~/.bashrc.d mechanism) if present
if [[ -d ~/.bashrc.d ]]; then
    for _rc in ~/.bashrc.d/*; do
        [[ -f "$_rc" ]] && source "$_rc"
    done
    unset _rc
fi

# Load .bashrc.local if it exists
if [[ -f ~/.bashrc.local ]]; then
    source ~/.bashrc.local
fi

# Terminal-env hygiene: Ghostty leaks TERM_PROGRAM=ghostty into the GNOME
# session's D-Bus activation environment on launch, and Ptyxis (GTK4, doesn't
# set TERM_PROGRAM itself) inherits it. TUI apps (Claude Code, Codex, ...) then
# assume a Ghostty terminal and enable the kitty keyboard protocol, which VTE
# does not support — every keystroke renders as a raw \xNN escape. Guard: when
# we're actually inside a VTE terminal (VTE_VERSION set), a TERM_PROGRAM=ghostty
# claim is always the leaked lie, so drop it. A real Ghostty session has no
# VTE_VERSION and is left untouched.
if [[ -n "${VTE_VERSION:-}" && "${TERM_PROGRAM:-}" == "ghostty" ]]; then
    unset TERM_PROGRAM
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

# Navigate by typing a directory name (zsh-like autocd)
shopt -s autocd

# Dot navigation aliases: shared in ~/.config/estebanforge/aliases.sh

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

# Check the binary exists (not PATH) so this works in a fresh shell
# where Homebrew isn't on PATH yet — `command -v brew` would fail there.
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi

######################################
# SSH Agent (Bitwarden Flatpak)      #
######################################

# Use the Bitwarden Flatpak SSH agent on Linux when its socket is present.
# Flatpak stores the socket under ~/.var/app/... (not ~/.bitwarden-ssh-agent.sock).
# Otherwise fall back to the systemd ssh-agent socket set up by the bw-ssh bridge.
# Gate on the socket: hosts without the bridge keep whatever SSH_AUTH_SOCK they
# already have (inherited agent, keyring), instead of pointing at a dead path.
if [[ "$(uname)" == "Linux" ]]; then
    _BW_SSH_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
    if [[ -S "$_BW_SSH_SOCK" ]]; then
        export SSH_AUTH_SOCK="$_BW_SSH_SOCK"
    elif [[ -S "$HOME/.ssh/agent.sock" ]]; then
        export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    fi
    unset _BW_SSH_SOCK
fi

######################################
# Shared shell functions (bash + zsh) #
######################################

# Everything in ~/.config/estebanforge/*.sh is shared with .zshrc:
# aliases, environment, updaters, devtools, ssh host wrappers.
# Loaded in glob (alphabetical) order; keep the files order-independent.
for _ef in "$HOME/.config/estebanforge"/*.sh; do
    [[ -f "$_ef" ]] && source "$_ef"
done
unset _ef

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

# Colored prompt (Linux)
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(__git_branch)\[\033[00m\]\$ '

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

# EDITOR: shared in ~/.config/estebanforge/env.sh
# sysup / sysup-full / dots-check: shared in ~/.config/estebanforge/updaters.sh

######################################
# Aliases                            #
######################################

# ls family, cat, artisan, dot navigation: shared in
# ~/.config/estebanforge/aliases.sh

######################################
# PATH AND ENVIRONMENT               #
######################################

# Composer, ~/.local/bin, HOMEBREW_NO_ENV_HINTS, opencode, LM Studio, phpvm:
# shared in ~/.config/estebanforge/env.sh

# PHP 8.3 first in PATH (Homebrew php@8.3 is keg-only)
export PATH="$HOMEBREW_PREFIX/opt/php@8.3/bin:$PATH"
export PATH="$HOMEBREW_PREFIX/opt/php@8.3/sbin:$PATH"

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

######################################
# Atuin shell history                #
######################################

# Per-host install: ~/.atuin/bin/env only exists where Atuin is installed.
if [[ -f "$HOME/.atuin/bin/env" ]]; then
    . "$HOME/.atuin/bin/env"
    eval "$(atuin init bash)"
fi

######################################
# zoxide (smarter cd)                #
######################################

# Installed via the shared Homebrew formulae (scripts/lib/brew_shared.sh).
# Guarded: brew_install_list skips failed formulae, and hosts without the
# binary must start clean instead of erroring on every shell.
# https://github.com/ajeetdsouza/zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
