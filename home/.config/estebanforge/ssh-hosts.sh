# shellcheck shell=bash
# SSH host wrappers. Sourced by both .zshrc (macOS) and .bashrc (Linux);
# keep syntax compatible with bash 3.2+ and zsh (printf, [[ ]], no print/echo -n).

zenless() { command ssh zenless "$@"; }
attd-zenless() { command ssh attd-zenless "$@"; }
