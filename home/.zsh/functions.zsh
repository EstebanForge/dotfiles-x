# User shell functions. Sourced by .zshrc after the prompt.
# Keep this file small: functions only, no aliases, no exports.

# zenless tunnel: serve https://localhost from the podman stack on
# zenless. pf maps 127.0.0.1:80->8080 and :443->8443 (see
# /etc/pf.anchors/tunneless); `ssh -fN tunneless` binds the high ports.
# pf rules are root-owned and die when something flushes pf (VPN helpers do
# this); `up` then offers the sudo repair (y/N prompt, password stays in the
# terminal) and prints the manual command on decline. `status` only reports.
# Usage: tunnel [up|down|status]   (no argument = up)
# Offer the pf repair for tunnel(). Interactive y/N: yes runs the reload
# with sudo (the password prompt stays in the terminal); no prints the
# command for a manual run. Propagates the repair exit code.
_tunnel_pf_repair() {
    read -q "reply?reload pf rules now? needs sudo [y/N] "
    print ''
    if [[ "$reply" == y ]]; then
        sudo pfctl -f /etc/pf.conf && sudo pfctl -e
    else
        print 'manual repair: sudo pfctl -f /etc/pf.conf && sudo pfctl -e'
        return 1
    fi
}

tunnel() {
    local cmd="${1:-up}"
    case "$cmd" in
        up)
            # 443 proves the full chain: pf + ssh + remote. 8443 only proves ssh.
            if nc -z 127.0.0.1 443 2>/dev/null; then
                print 'tunnel: up (https://localhost)'
                return 0
            fi
            if ! nc -z 127.0.0.1 8443 2>/dev/null; then
                _bw_ssh_preflight "$HOME/.ssh/attd-zenless" || return 1
                ssh -fN tunneless || return 1
            fi
            if nc -z 127.0.0.1 443 2>/dev/null; then
                print 'tunnel: up (https://localhost)'
                return 0
            fi
            print 'tunnel: ssh half up, pf redirect down'
            if _tunnel_pf_repair && nc -z 127.0.0.1 443 2>/dev/null; then
                print 'tunnel: up (https://localhost)'
            else
                print 'tunnel: pf redirect still down'
                return 1
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
            elif nc -z 127.0.0.1 8443 2>/dev/null; then
                print 'tunnel: ssh half up, pf half down'
                print 'repair: run `tunnel up` (offers the sudo reload) or: sudo pfctl -f /etc/pf.conf && sudo pfctl -e'
                return 1
            else
                print 'tunnel: down'
                return 1
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
