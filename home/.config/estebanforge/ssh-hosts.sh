# SSH host wrappers with Bitwarden agent pre-flight.
# Sourced by both .zshrc (macOS) and .bashrc (Linux); keep syntax compatible
# with bash 3.2+ and zsh (printf, [[ ]], no print/echo -n).
#
# Why: `ssh zenless` degrades to a password prompt when the Bitwarden
# SSH agent is down (Bitwarden.app not running): the pub-only IdentityFile
# then logs "invalid format" and no agent key gets offered. These wrappers
# check the agent first and fix the common causes. Plain `ssh` stays
# untouched: scripts, scp, and git keep calling the binary directly.

# Sanity checks for ssh hops that depend on the Bitwarden agent.
# $1 = public key file whose fingerprint must be present in the agent.
# Returns 0 when the connection attempt may proceed.
_bw_ssh_preflight() {
    local pub="$1" want answer _ out rc

    # Scripts and other non-interactive callers: do not interfere.
    if [[ ! -t 0 ]]; then
        return 0
    fi

    out=$(ssh-add -l 2>&1); rc=$?

    # Agent down (socket dead): recover per platform.
    if [[ $rc -ne 0 && "$out" != *"has no identities"* ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            printf 'ssh: bitwarden agent is not running.\n'
            printf 'start Bitwarden now? [Y/n] '
            read -r answer
            if [[ "$answer" == [nN]* ]]; then
                return 1
            fi
            open -a Bitwarden
            printf 'waiting for the agent'
            for _ in {1..30}; do
                out=$(ssh-add -l 2>&1); rc=$?
                if [[ $rc -eq 0 || "$out" == *"has no identities"* ]]; then
                    break
                fi
                printf '.'; sleep 1
            done
            printf '\n'
            if [[ $rc -ne 0 && "$out" != *"has no identities"* ]]; then
                printf 'ssh: agent did not come up in 30s; start Bitwarden manually and retry.\n' >&2
                return 1
            fi
        elif command -v bw-ssh >/dev/null 2>&1; then
            # Linux bridge host: bw-ssh load asks for the vault password
            # in this terminal; the shell function never sees it.
            printf 'ssh: bitwarden agent is not running.\n'
            printf 'run bw-ssh load now? [Y/n] '
            read -r answer
            if [[ "$answer" == [nN]* ]]; then
                return 1
            fi
            if ! bw-ssh load; then
                return 1
            fi
            out=$(ssh-add -l 2>&1); rc=$?
            if [[ $rc -ne 0 ]]; then
                printf 'ssh: agent still holds no keys; aborting.\n' >&2
                return 1
            fi
        else
            printf 'ssh: bitwarden agent is not running; start it, then retry.\n' >&2
            return 1
        fi
    fi

    # Agent up, vault locked or empty: no keys until the user acts.
    if [[ "$out" == *"has no identities"* ]]; then
        printf 'ssh: bitwarden vault is locked or empty. unlock it (or run bw-ssh load), then press Enter (Ctrl-C aborts): '
        read -r answer
        out=$(ssh-add -l 2>&1); rc=$?
        if [[ $rc -ne 0 ]]; then
            printf 'ssh: agent still holds no keys; aborting.\n' >&2
            return 1
        fi
    fi

    # IdentitiesOnly is set: the agent must hold this host's exact key.
    want=$(ssh-keygen -lf "$pub" 2>/dev/null | awk '{print $2}')
    if [[ -z "$want" ]] || ! grep -qF -- "$want" <<<"$out"; then
        printf 'ssh: agent has no key matching %s.\n' "$pub" >&2
        printf 'ssh: enable it in Bitwarden under Settings > SSH agent, then retry.\n' >&2
        return 1
    fi

    return 0
}

# Fool-proof ssh into the dev server: checks the Bitwarden agent, then
# connects. Extra args pass through: zenless -- htop
zenless() {
    _bw_ssh_preflight "$HOME/.ssh/attd-zenless" || return 1
    command ssh zenless "$@"
}
