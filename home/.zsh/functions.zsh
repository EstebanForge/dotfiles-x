# User shell functions. Sourced by .zshrc after the prompt.
# Keep this file small: functions only, no aliases, no exports.

# zenless tunnel: serve https://localhost from the podman stack on
# zenless. pf maps 127.0.0.1:80->8080 and :443->8443 (see
# /etc/pf.anchors/tunneless); `ssh -fN tunneless` binds the high ports.
# Usage: tunnel [up|down|status]   (no argument = up)
tunnel() {
    local cmd="${1:-up}"
    case "$cmd" in
        up)
            if nc -z 127.0.0.1 8443 2>/dev/null; then
                print 'tunnel: already up (https://localhost)'
            else
                _bw_ssh_preflight "$HOME/.ssh/zenless" || return 1
                ssh -fN tunneless && print 'tunnel: up (https://localhost)'
            fi
            ;;
        down)
            if pkill -f 'ssh -f?N tunneless'; then
                print 'tunnel: down'
            else
                print 'tunnel: not running'
            fi
            ;;
        status)
            # 443 proves the full chain: pf + ssh + remote. 8443 only proves ssh.
            if nc -z 127.0.0.1 443 2>/dev/null; then
                print 'tunnel: up (https://localhost)'
            else
                print 'tunnel: down'
            fi
            ;;
        *)
            print 'usage: tunnel [up|down|status]'
            return 1
            ;;
    esac
}

# SSH host wrappers (zenless + Bitwarden agent pre-flight) live in
# ~/.config/estebanforge/ssh-hosts.sh, shared with .bashrc.
