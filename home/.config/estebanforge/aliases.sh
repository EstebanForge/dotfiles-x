# shellcheck shell=bash
# Cross-shell aliases (bash + zsh), sourced from the
# ~/.config/estebanforge/*.sh loop in .zshrc and .bashrc.
# Keep entries identical on both shells; shell-specific syntax goes behind
# a ZSH_VERSION branch.

# --- ls family ---
# GNU ls flags everywhere: gls (Homebrew coreutils) on macOS, native on
# Linux. Gate on gls so a fresh macOS without coreutils keeps a working ls.
if [[ "$(uname)" == "Darwin" ]] && command -v gls >/dev/null 2>&1; then
    alias ls='gls -GFh --color -h --group-directories-first'
    alias ll='gls --color -alF --group-directories-first'
    alias la='gls --color -A'
    alias l='gls --color -CF'
else
    alias ls='ls -GFh --color -h --group-directories-first'
    alias ll='ls --color -alF --group-directories-first'
    alias la='ls --color -A'
    alias l='ls --color -CF'
fi

alias cat='bat'
alias artisan='php artisan'

# --- Dot navigation ---
# zsh: global aliases so they also expand mid-command (e.g. `cp f .../sib/`);
# `..` needs no alias there, it is a real fs entry picked up by auto_cd.
# bash: plain cd aliases, `..` included.
if [[ -n "${ZSH_VERSION:-}" ]]; then
    alias -g ...='../..'
    alias -g ....='../../..'
    alias -g .....='../../../..'
    alias -g ......='../../../../..'
else
    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
    alias .....='cd ../../../..'
    alias ......='cd ../../../../..'
fi
