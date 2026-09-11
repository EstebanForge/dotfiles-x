# shellcheck shell=bash
# zsh file: shellcheck only speaks bash, so zsh-specific constructs are
# disabled file-wide (read -q prompt assignment, literal backticks in print).
# shellcheck disable=SC2162,SC2154,SC2016
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

# Any HTTP reply counts as a live site; the site owns the status code. nc
# can only prove pf + ssh exist, not that anything answers on zenless.
_tunnel_site_ok() {
    curl -sk -o /dev/null --max-time 3 https://127.0.0.1/
}

# Call only after 443 passes nc: pf + ssh are alive, ask about the site.
_tunnel_report() {
    if _tunnel_site_ok; then
        print 'tunnel: up (https://localhost)'
    else
        print 'tunnel: chain up, no site answers on zenless:443'
        print 'tunnel: put a site up on zenless (compose up / podman run -p 443:443)'
    fi
}

tunnel() {
    local cmd="${1:-up}"
    case "$cmd" in
        up)
            # 443 proves pf + ssh; the HTTP probe adds the remote site.
            if nc -z 127.0.0.1 443 2>/dev/null; then
                _tunnel_report
                return 0
            fi
            if ! nc -z 127.0.0.1 8443 2>/dev/null; then
                _bw_ssh_preflight "$HOME/.ssh/attd-zenless" || return 1
                ssh -fN tunneless || return 1
            fi
            if nc -z 127.0.0.1 443 2>/dev/null; then
                _tunnel_report
                return 0
            fi
            # pf disabled by a previous `tunnel down`: rules are still loaded,
            # just re-enable. Interactive reload below stays for broken rules.
            if sudo pfctl -e >/dev/null 2>&1 && nc -z 127.0.0.1 443 2>/dev/null; then
                _tunnel_report
                return 0
            fi
            print 'tunnel: ssh half up, pf redirect down'
            if _tunnel_pf_repair && nc -z 127.0.0.1 443 2>/dev/null; then
                _tunnel_report
            else
                print 'tunnel: pf redirect still down'
                return 1
            fi
            ;;
        down)
            if pkill -f 'ssh -f?N tunneless'; then
                print 'tunnel: ssh down'
            else
                print 'tunnel: ssh not running'
            fi
            # pf keeps redirecting lo0 80/443 into the now-dead 8080/8443, so
            # localhost is not truly free until pf is disabled.
            if sudo pfctl -d >/dev/null 2>&1; then
                print 'tunnel: pf disabled (localhost 80/443 free)'
            else
                print 'tunnel: pf still enabled (sudo declined or failed)'
                print 'tunnel: localhost 80/443 still redirected. manual: sudo pfctl -d'
                return 1
            fi
            ;;
        status)
            # 443 proves pf + ssh; the HTTP probe adds the remote site.
            if nc -z 127.0.0.1 443 2>/dev/null; then
                _tunnel_report
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

# SSH host wrappers (attd-zenless + Bitwarden agent pre-flight) live in
# ~/.config/estebanforge/ssh-hosts.sh, shared with .bashrc.
