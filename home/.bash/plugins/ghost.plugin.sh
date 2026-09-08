#!/usr/bin/env bash
# ghost.plugin.sh - Fish-style ghost text suggestions for Bash 5.x
#
# Suggestions from history appear as gray text after the cursor.
#   Right / End        -> accept full suggestion (Tab stays completion)
#   Alt-F / Ctrl-F     -> accept next word
#   Up / Down arrow    -> browse history (ghost text cleared)
#
# MIT License - part of dotfiles-x
# Inspired by https://github.com/h-jangra/Ghost.sh (no license, unmaintained).
# Rewritten to fix: Tab binding (Ghost.sh README claimed it, code lacked it),
# clean license header, apostrophe-key crash, Ctrl-U data loss, and ANSI
# control-sequence replay from history.
# Later fixes: newline-eating tr in the history snapshot (suggestions never
# matched), Up/Down macros whose bodies contained unbound bytes (readline
# aborted and swallowed the keypress: arrows went dead on terminals sending
# normal-mode \e[A codes), app-mode arrow variants, Ctrl-E end-of-line, and
# PROMPT_COMMAND array clobbering (dropped systemd's OSC hook on Fedora).

[[ $- != *i* ]] && return
[[ -n "${_GHOST_LOADED:-}" ]] && return
_GHOST_LOADED=1

# --- State -----------------------------------------------------------------

_ghost_history=""
_ghost_suggestion=""
_ghost_prompt_len=0
_ghost_color=$'\e[38;5;244m' # gray

# --- History ---------------------------------------------------------------

# Build history snapshot: newest first, deduped, leading whitespace stripped,
# C0 control chars (\x00-\x08, \x0b-\x1f) and \x7f removed; newline (\x0a)
# is PRESERVED as the record separator. The original range \000-\037 deleted
# newlines too, collapsing the whole history into one mega-line so no
# suggestion ever matched.
#   - C0 stripping closes the door on replaying arbitrary escape sequences
#     from history (a previously pasted/typed colored command could otherwise
#     inject OSC/CSI bytes into the renderer on every keystroke that matches).
#   - Capped at 2000 entries for snappy render.
_ghost_init_history() {
    _ghost_history=$(
        fc -ln -2000 2>/dev/null \
            | sed 's/^[[:space:]]*//' \
            | tr -d '\000-\011\013-\037\177' \
            | awk '!seen[$0]++' \
            | tac
    )
}

# Compute visible width of the last line of the current PS1.
# Strips OSC sequences (\e]...\a or \e]...\e\\) FIRST -- their payload can
# contain '[' which would corrupt the CSI strip -- then CSI escapes
# (\e[...letter), then the readline \x01/\x02 wrapper marks.
_ghost_update_prompt_len() {
    local plain last
    plain=$(printf '%s' "${PS1@P}" \
        | sed -E $'s/\x1b\][^\x07\x1b]*(\x07|\x1b\\\\)//g; s/\x1b\\[[0-9;?]*[a-zA-Z]//g; s/\x01|\x02//g')
    last="${plain##*$'\n'}"
    _ghost_prompt_len=${#last}
}

# Refresh both history and prompt width. Runs in PROMPT_COMMAND before each prompt.
# NOTE: this re-expands ${PS1@P}, which re-runs any command substitution inside
# PS1 (e.g., __git_branch in .bashrc shells out to git). Acceptable: once per
# prompt, not once per keystroke.
_ghost_refresh() {
    history -a
    _ghost_init_history
    _ghost_update_prompt_len
}

# --- Suggestion lookup -----------------------------------------------------

# Find the first history line whose prefix matches $1 (and isn't $1 itself).
_ghost_get_suggestion() {
    _ghost_suggestion=""
    [[ -z "$1" ]] && return
    local line
    while IFS= read -r line; do
        if [[ "$line" == "$1"* && "$line" != "$1" ]]; then
            _ghost_suggestion="${line#"$1"}"
            return
        fi
    done <<< "$_ghost_history"
}

# --- Rendering ------------------------------------------------------------

# Render (or clear) the ghost text at the current cursor position.
# Uses DEC save/restore cursor (\e7 / \e8) so the user's real input is untouched.
# Note: ANSI.SYS \e[s and \e[u are not supported by mosh's terminal emulator.
# Limitation: \e[%dG (CHA) clamps to the current row; lines wider than the
# terminal width render or clear at the wrong column. Suggestion text itself
# is stripped of C0 controls above, but ANSI SGR (\e[...m) in a history entry
# would still be replayed verbatim.
_ghost_render() {
    if [[ $READLINE_POINT -eq ${#READLINE_LINE} ]]; then
        _ghost_get_suggestion "$READLINE_LINE"
    else
        _ghost_suggestion=""
    fi

    local col=$(( _ghost_prompt_len + ${#READLINE_LINE} + 1 ))
    if [[ -n "$_ghost_suggestion" ]]; then
        printf '\e7\e[%dG%s%s\e[0m\e8' \
            "$col" "$_ghost_color" "$_ghost_suggestion" >&2
    else
        printf '\e7\e[%dG\e[K\e8' "$col" >&2
    fi
}

# --- Line-edit handlers ---------------------------------------------------

# Insert one printable char at the cursor, then re-render.
_ghost_insert() {
    READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$1${READLINE_LINE:$READLINE_POINT}"
    READLINE_POINT=$((READLINE_POINT + ${#1}))
    _ghost_render
}

# Accept the suggestion: if cursor is mid-line, advance one char (standard
# right-arrow behavior); otherwise append the whole ghost text.
_ghost_accept() {
    if [[ $READLINE_POINT -lt ${#READLINE_LINE} ]]; then
        READLINE_POINT=$(( READLINE_POINT + 1 ))
    elif [[ -n "$_ghost_suggestion" ]]; then
        READLINE_LINE+="$_ghost_suggestion"
        READLINE_POINT=${#READLINE_LINE}
        _ghost_suggestion=""
    fi
    _ghost_render
}

# End of line: accept the ghost suggestion when at the tail, then move to
# end-of-line (restores stock Ctrl-E semantics instead of a 1-char step).
_ghost_end() {
    if [[ -n "$_ghost_suggestion" && $READLINE_POINT -eq ${#READLINE_LINE} ]]; then
        READLINE_LINE+="$_ghost_suggestion"
        _ghost_suggestion=""
    fi
    READLINE_POINT=${#READLINE_LINE}
    _ghost_render
}

# Accept only the next whitespace-delimited word of the suggestion.
_ghost_accept_word() {
    [[ -n "$_ghost_suggestion" ]] || return
    local word="${_ghost_suggestion%% *}"
    [[ "$_ghost_suggestion" == *' '* ]] && word+=' '
    READLINE_LINE+="$word"
    READLINE_POINT=${#READLINE_LINE}
    _ghost_suggestion="${_ghost_suggestion#"$word"}"
    _ghost_render
}

# Backspace: delete char before cursor.
_ghost_backspace() {
    if [[ $READLINE_POINT -gt 0 ]]; then
        READLINE_LINE="${READLINE_LINE:0:$((READLINE_POINT - 1))}${READLINE_LINE:$READLINE_POINT}"
        READLINE_POINT=$((READLINE_POINT - 1))
    fi
    _ghost_render
}

# Left arrow: move cursor back one char (with ghost re-render in case we
# moved off the tail).
_ghost_left() {
    [[ $READLINE_POINT -gt 0 ]] && READLINE_POINT=$((READLINE_POINT - 1))
    _ghost_render
}

# Ctrl-U: kill from cursor to start of line (unix-line-discard semantics),
# leaving text after the cursor intact. Matches stock readline behavior.
_ghost_kill_line() {
    READLINE_LINE="${READLINE_LINE:$READLINE_POINT}"
    READLINE_POINT=0
    _ghost_render
}

_ghost_clear() { printf '\e[H\e[2J' >&2; _ghost_render; }
_ghost_home()  { READLINE_POINT=0; _ghost_render; }

# --- Init + bindings -------------------------------------------------------

_ghost_refresh

# Bind every printable byte (32..255) to a custom insert handler. Standard
# bash technique for in-line ghost text: each keystroke must re-render, so we
# can't rely on readline's default self-insert.
#
# Why 32..255 instead of just 32..126: accented Latin chars (e.g. Spanish é,
# ñ) and other UTF-8 sequences arrive as 2-byte combos where both bytes fall
# in 128..255. Without bindings in that range, readline's default self-insert
# would fire for those bytes and skip _ghost_render, leaving stale ghost text
# on screen until the next ASCII keystroke.
#
# Quoting: use printf %q for the FUNCTION ARG (bash quoting dialect) and
# numeric check for the KEY SPEC (readline's quoting dialect, which is
# different and requires backslash-escaping " and \ when wrapped in double
# quotes). 34 = ", 92 = \.
for ((_ghost_i = 32; _ghost_i <= 255; _ghost_i++)); do
    # Build the byte as a real char. printf '%b' interprets backslash escapes;
    # octal \ooo covers all bytes 0-255 uniformly. (Do NOT split $'\xNN' across
    # two quoted segments like $'\x'"$hex" -- on bash 5.3 that yields the
    # literal 4-char string "\xNN" and binds every key to echo \xNN.)
    printf -v _ghost_oct '\\%03o' "$_ghost_i"
    printf -v _ghost_char '%b' "$_ghost_oct"
    printf -v _ghost_argq '%q' "$_ghost_char"

    if (( _ghost_i == 34 || _ghost_i == 92 )); then
        _ghost_keyspec="\\$_ghost_char"
    else
        _ghost_keyspec="$_ghost_char"
    fi

    bind -x "\"$_ghost_keyspec\": _ghost_insert $_ghost_argq"
done
unset _ghost_i _ghost_oct _ghost_char _ghost_argq _ghost_keyspec

# Accept full suggestion. Tab is NOT rebound: filename completion is worth
# more than a second accept key (Right / End / Ctrl-E all accept).
bind -x '"\e[C":  _ghost_accept' # Right arrow (normal mode)
bind -x '"\eOC":  _ghost_accept' # Right arrow (application mode)
bind -x '"\C-e":  _ghost_end'    # End (accepts ghost text when at line tail)

# Accept next word
bind -x '"\ef":  _ghost_accept_word' # Alt-F
bind -x '"\C-f": _ghost_accept_word' # Ctrl-F (overrides Bash default forward-char)

# Line-edit ops that need ghost re-render (both cursor-key modes)
bind -x '"\e[D": _ghost_left'        # Left arrow (normal mode)
bind -x '"\eOD": _ghost_left'        # Left arrow (application mode)
bind -x '"\C-?": _ghost_backspace'   # Backspace (some terminals)
bind -x '"\C-h": _ghost_backspace'   # Ctrl-H / Backspace
bind -x '"\C-u": _ghost_kill_line'   # Kill from cursor to start of line
bind -x '"\C-l": _ghost_clear'       # Clear screen
bind -x '"\C-a": _ghost_home'        # Home

# Up/Down arrows are left at their STOCK readline bindings (previous-history /
# next-history in both \eA and \eOA modes). An earlier version chained a
# redraw-current-line helper chord inside macros to clear ghost text on
# arrow navigation; combined with the per-byte bind -x loop above, that made
# readline's parser print "no key sequence terminator" notices at shell
# startup (readline writes them straight to the tty; they cannot be
# redirected). Stale ghost text after arrow navigation self-corrects on the
# next keystroke (every printable byte re-renders) and at the next prompt
# (_ghost_refresh), so stock arrows are the simpler, silent choice.

# Refresh on each prompt draw. PROMPT_COMMAND may be an ARRAY (bash 5.1+;
# Fedora's 80-systemd-osc-context.sh appends to it as one). String-appending
# would flatten the array and silently drop every other hook, so branch on
# the actual type.
if [[ ${PROMPT_COMMAND@a} == *a* ]]; then
    PROMPT_COMMAND+=(_ghost_refresh)
else
    # Intentional runtime type branch: array on bash 5.1+, string on older bash.
    # shellcheck disable=SC2178,SC2128
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }_ghost_refresh"
fi