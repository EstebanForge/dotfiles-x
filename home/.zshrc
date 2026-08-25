# ============================================================
# ZSH configuration (lean, Oh-My-Zsh-free)
# Native completion, history, and keybindings replace OMZ libs.
# Prompt: EstebanForgePrompt (~/.zsh/prompt.zsh).
# ============================================================

# --- Secrets ---
if [[ -f ~/.secrets ]]; then
    source ~/.secrets
fi

# --- Homebrew ---
if [[ "$(uname)" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$(uname)" == "Linux" ]]; then
    if command -v brew >/dev/null 2>&1; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# --- History (ported from OMZ history.zsh) ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion before running
setopt share_history          # share command history data

# --- Directories (ported from OMZ directories.zsh) ---
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus

# Dot navigation aliases (... to ......): shared in
# ~/.config/estebanforge/aliases.sh (loaded below with the other shared files).

# --- Completion (ported from OMZ completion.zsh) ---
# OpenSpec completions + user completions live here now (was ~/.oh-my-zsh/custom/completions)
fpath=("$HOME/.zsh/completions" $fpath)

zmodload -i zsh/complist
WORDCHARS=''
unsetopt menu_complete flowcontrol
setopt auto_menu complete_in_word always_to_end
bindkey -M menuselect '^o' accept-and-infer-next-history
zstyle ':completion:*:*:*:*:*' menu select
# case-insensitive (all), partial-word and substring completion
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USERNAME -o pid,user,comm -w -w"
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$HOME/.cache/zsh"
mkdir -p "$HOME/.cache/zsh"

# --- OpenSpec completions (auto-managed block; relocated from OMZ) ---
# OPENSPEC:START
# OpenSpec shell completions configuration
autoload -Uz compinit
compinit
# OPENSPEC:END

autoload -U +X bashcompinit && bashcompinit

# --- Key bindings (ported from OMZ key-bindings.zsh, emacs mode) ---
bindkey -e
if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
    zle-line-init() { echoti smkx }
    zle-line-finish() { echoti rmkx }
    zle -N zle-line-init
    zle -N zle-line-finish
fi

# Up/Down — prefix history search
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" down-line-or-beginning-search

# Home/End/PageUp/PageDown/Shift-Tab
[[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n "${terminfo[kend]}" ]]  && bindkey "${terminfo[kend]}"  end-of-line
[[ -n "${terminfo[kpp]}" ]]   && bindkey "${terminfo[kpp]}"   up-line-or-history
[[ -n "${terminfo[knp]}" ]]   && bindkey "${terminfo[knp]}"   down-line-or-history
[[ -n "${terminfo[kcbt]}" ]]  && bindkey "${terminfo[kcbt]}"  reverse-menu-complete

# Delete/Backspace
bindkey '^?' backward-delete-char
[[ -n "${terminfo[kdch1]}" ]] && bindkey "${terminfo[kdch1]}" delete-char

# Ctrl-arrows / Ctrl-delete — word motion
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[3;5~' kill-word

# Misc emacs-style bindings
bindkey '\ew' kill-region                          # [Esc-w] kill to mark
bindkey '^r' history-incremental-search-backward   # [Ctrl-r]
bindkey ' ' magic-space                            # [Space] no history expansion
autoload -U edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line               # [Ctrl-x Ctrl-e] edit in $EDITOR
bindkey "^[m" copy-prev-shell-word                 # [Esc-m] copy prev word

# --- Prompt: EstebanForgePrompt ---
source "$HOME/.zsh/prompt.zsh"

# --- User functions (tunnel etc.) ---
[[ -f "$HOME/.zsh/functions.zsh" ]] && source "$HOME/.zsh/functions.zsh"

# --- Shared shell config (bash + zsh) ---
# Everything in ~/.config/estebanforge/*.sh is shared with .bashrc:
# aliases, environment, updaters, devtools, ssh host wrappers.
# Loaded in glob (alphabetical) order; keep the files order-independent.
setopt NULL_GLOB
for _ef in "$HOME/.config/estebanforge"/*.sh; do
    [[ -f "$_ef" ]] && source "$_ef"
done
unset _ef
unsetopt NULL_GLOB

######################
# User configuration #
######################

# OS-specific plugin loading (zsh-autosuggestions + zsh-syntax-highlighting)
if [[ "$(uname)" == "Darwin" ]]; then
    source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
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

# Bitwarden SSH-Agent (macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
    launchctl setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK"
fi

# EDITOR, brewup, phpv: shared in ~/.config/estebanforge/env.sh and
# ~/.config/estebanforge/devtools.sh.

# sysup / sysup-full / dots-check: shared in ~/.config/estebanforge/updaters.sh

# agentmemory: engine is launchd-managed (com.agentmemory.server) with the
# correct WorkingDirectory. Prevent accidental manual starts from a project
# dir, which would bind a different ./data store (cwd-relative path footgun).
# Allow only non-starting subcommands; everything else points at launchd.
agentmemory() {
    if [[ "$1" == "stop" || "$1" == "status" || "$1" == "doctor" || "$1" == "demo" ]]; then
        command agentmemory "$@"
    else
        echo "Engine managed by launchd. Use: launchctl kickstart -k gui/$(id -u)/com.agentmemory.server" >&2
    fi
}

# On-demand agentmemory consolidation. Runs the 4-tier pipeline (working ->
# episodic -> semantic -> procedural) with the configured decay window, then
# the auto-forget GC. Hit the local engine directly; no CLI start involved.
#   memconsolidate          run pipeline + GC for real
#   memconsolidate -p       pipeline only
#   memconsolidate -g       GC only
#   memconsolidate --dry    preview GC deletes without applying
memconsolidate() {
    local url="${AGENTMEMORY_URL:-http://localhost:3111}/agentmemory"
    local do_pipe=1 do_gc=1 dry=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p) do_gc=0 ;;
            -g) do_pipe=0 ;;
            --dry) dry=1; do_pipe=0 ;;
            *) echo "usage: memconsolidate [-p|-g|--dry]" >&2; return 2 ;;
        esac
        shift
    done
    if ! curl -sf -o /dev/null "$url/health"; then
        echo "agentmemory engine not reachable at ${url%/*}" >&2
        return 1
    fi
    if [[ "$do_pipe" == "1" ]]; then
        echo "== consolidate-pipeline =="
        curl -sS -X POST "$url/consolidate-pipeline" -H 'Content-Type: application/json' -d '{}' | jq .
    fi
    if [[ "$do_gc" == "1" ]]; then
        echo "== auto-forget =="
        if [[ "$dry" == "1" ]]; then
            curl -sS -X POST "$url/auto-forget" -H 'Content-Type: application/json' -d '{"dryRun":true}' \
                | jq '{ttlExpired:(.ttlExpired|length), contradictions:(.contradictions|length), lowValueObs:(.lowValueObs|length), dryRun}'
        else
            curl -sS -X POST "$url/auto-forget" -H 'Content-Type: application/json' -d '{}' \
                | jq '{ttlExpired:(.ttlExpired|length), contradictions:(.contradictions|length), lowValueObs:(.lowValueObs|length)}'
        fi
    fi
}

# ls/ll/la/l, cat, artisan: shared in ~/.config/estebanforge/aliases.sh
if [[ "$(uname)" == "Darwin" ]]; then
    alias qs='open -a "QSpace Pro"'
fi

# --- Sandbox Control (UTM, macOS only) ---
# Sandbox VM IP. Override in ~/.secrets. Must match ~/.ssh/config Host sandbox.
SANDBOX_IP="${SANDBOX_IP:-192.168.0.0}"
if [[ "$(uname)" == "Darwin" ]]; then
    alias sbdown='utmctl stop "Fedora Server"'
    alias sbssh='ssh sandbox'
    alias sbstatus='utmctl list | grep "Fedora Server"'

    sbup() {
        echo "🚀 Starting Sandbox..."
        utmctl start "Fedora Server"

        echo -n "⏳ Waiting for SSH..."
        while ! nc -z -G 1 "$SANDBOX_IP" 22 > /dev/null 2>&1; do
            sleep 1
            echo -n "."
        done
        echo "\n✅ Sandbox is online!"
    }
fi

######################################
# PATH AND ENVIRONMENT CONFIGURATION #
######################################

# Composer, ~/.local/bin, HOMEBREW_NO_ENV_HINTS, opencode, LM Studio, phpvm:
# shared in ~/.config/estebanforge/env.sh

export PATH="$HOME/.cargo/bin:$PATH"

# Bun (macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="$HOME/.bun/bin:$PATH"
fi

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
setopt NULL_GLOB 2>/dev/null || true
for plugin in ~/.zsh/plugins/*.plugin.sh; do
    [[ -r "$plugin" ]] && source "$plugin"
done
unsetopt NULL_GLOB 2>/dev/null || true

eval "$(atuin init zsh)"

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

# Construct-cli agent routing.
# Most agents now route through PATH shims (`construct sys shims --install`):
# ~/.local/bin/<slug> execs `ct <slug>` sandboxed, ns-<slug> execs the real
# # host binary. The aliases kept below exist because a real binary already
# occupies the shim filename in ~/.local/bin for those agents, so the shell
# alias is still the sandbox route and the ns- function the direct route.
if command -v ct >/dev/null 2>&1; then
    alias agy='ct agy'
    alias claude='ct claude'
    alias codex='ct codex'
    alias droid='ct droid'
    alias cc-kimi='ct cc kimi'
    alias cc-mimo='ct cc mimo'
    alias cc-minimax='ct cc minimax'
    alias cc-qwen='ct cc qwen'
    alias cc-zai='ct cc zai'

    # Non-sandboxed aliases - run agents directly
    ns-agy() { command agy "$@"; }
    ns-claude() { command claude "$@"; }
    ns-codex() { command codex "$@"; }
    ns-droid() { command droid "$@"; }
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

# --- pi token cost tracker (host-owned; reads host + construct ledgers) ---
# Docs: ~/Dev/pi-token-cost-tracking.md  |  Run: tokens
tokens() {
  local ct="$HOME/.pi/cost-tracker"
  local choice range month ep
  while true; do
    cat <<'MENU'

pi token cost tracker  (host-owned; reads host + construct ledgers)

  1) live spend — this month
  2) live spend — all history (by month)
  3) live spend — specific month/day
  4) squash month into archive (+ trend)
  5) show trend (history.csv)
  6) show archive detail for a month
  7) export last 12 months to CSV
  q) quit
MENU
    printf '\n> '; read -r choice || break
    case "$choice" in
      1) "$ct/api-equiv.sh" "$(date +%Y/%m)" ;;
      2) "$ct/api-equiv.sh" --by-month ;;
      3) printf 'range (YYYY/MM or YYYY/MM/DD): '; read -r range
         [ -n "$range" ] && "$ct/api-equiv.sh" "$range" ;;
      4) printf 'month (YYYY/MM) [enter=current]: '; read -r month
         "$ct/monthly-rollup.sh" "${month:-$(date +%Y/%m)}" ;;
      5) column -t -s, "$ct/monthly/history.csv" 2>/dev/null \
           || echo "no archive yet; use option 4 first" ;;
      6) printf 'month (YYYY/MM): '; read -r month
         if [ -n "$month" ] && [ -f "$ct/monthly/${month//\//-}.json" ]; then
           jq . "$ct/monthly/${month//\//-}.json"
         else
           echo "no archive for ${month:-<empty>}; squash it first (option 4)"
         fi ;;
      7) printf 'output path [enter = ./pi-cost-last12months-<today>.csv]: '; read -r ep
         if [ -z "$ep" ]; then "$ct/api-equiv.sh" --export-csv
         else "$ct/api-equiv.sh" --export-csv "$ep"; fi ;;
      q|Q) echo "bye"; break ;;
      *) echo "invalid: $choice" ;;
    esac
    printf '\n[enter to continue]'; read -r || break
  done
}

# Pi agent
export PI_CACHE_RETENTION="long"

# Agent-browser
export AGENT_BROWSER_IGNORE_HTTPS_ERRORS=true

# Android SDK (Baluard mobile)
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/27.2.12479018
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# druk
export PATH=/Users/esteban/.druk/bin:$PATH

# --- Route directory opens to QSpace Pro (macOS Tahoe) ---
# Tahoe locks the public.folder default handler to Finder, so plain
# `open <dir>` and `open .` land in Finder. This routes a SINGLE existing
# directory argument to QSpace instead; everything else (URLs, files, -R,
# -a, multiple args) passes through to the real open.
# Behavior matches the Hammerspoon redirect: running+window -> new tab;
# running, no window -> new window; not running -> launch QSpace on the folder.
# Bypass: command open <dir>   (or /usr/bin/open <dir>)
if [[ "$(uname)" == "Darwin" ]]; then
    __qspace_open_dir() {
        emulate -L zsh
        local dir="${1:A}"
        [[ -d "$dir" ]] || return 1
        local n
        n=$(osascript -e 'tell application "System Events" to count (processes whose name contains "QSpace")' 2>/dev/null)
        if [[ "$n" =~ [1-9] ]]; then
            osascript >/dev/null 2>&1 \
                -e 'tell application "QSpace Pro"' \
                -e 'if (count of windows) > 0 then' \
                -e "tell window 1 to open urlstr \"file://${dir}/\"" \
                -e 'else' \
                -e "open urlstr \"file://${dir}/\"" \
                -e 'end if' \
                -e 'end tell'
        else
            command open -a "QSpace Pro" "$dir"
        fi
    }

    open() {
        if (( $# == 1 )) && [[ -d "$1" ]]; then
            __qspace_open_dir "$1"
        else
            command open "$@"
        fi
    }
fi
eval "$(/Users/esteban/.local/bin/mise activate zsh)"
