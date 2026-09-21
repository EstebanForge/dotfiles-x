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
# terminal) and prints the manual command on decline. macOS upgrades revert
# /etc/pf.conf to stock, so the repair re-adds the tunneless anchor lines
# before reloading. `status` only reports.
# Usage: tunnel [up|down|status]   (no argument = up)
# Offer the pf repair for tunnel(). macOS upgrades revert /etc/pf.conf to
# stock and drop the tunneless lines; a plain reload then fixes nothing. The
# heal restores the anchor file if missing and reinserts the anchor lines in
# valid category order (pf: translation rules above filtering). Interactive
# y/N: yes heals + reloads with sudo (the password prompt stays in the
# terminal); no prints the manual path. Propagates the repair exit code.
_tunnel_pf_repair() {
    local pfconf=/etc/pf.conf anchor=/etc/pf.anchors/tunneless
    local ask='reload pf rules now? needs sudo [y/N] '
    if [[ -r "$pfconf" ]] && ! grep -q 'rdr-anchor "tunneless"' "$pfconf" 2>/dev/null; then
        ask='pf config damaged (OS upgrade revert?), heal + reload now? needs sudo [y/N] '
    fi
    read -q "reply?$ask"
    print ''
    if [[ "$reply" != y ]]; then
        print 'manual repair: run `tunnel up` and answer y'
        return 1
    fi
    if [[ ! -r "$anchor" ]]; then
        print "tunnel: recreating missing $anchor"
        printf '%s\n' \
            'rdr pass on lo0 inet proto tcp from any to 127.0.0.1 port 80 -> 127.0.0.1 port 8080' \
            'rdr pass on lo0 inet proto tcp from any to 127.0.0.1 port 443 -> 127.0.0.1 port 8443' \
            | sudo tee "$anchor" >/dev/null
    fi
    # pf demands category order: translation (rdr-anchor) must sit with the
    # other rdr anchors, above filtering. Strip + reinsert at canonical
    # spots; a correct file comes out byte-identical and skips reinstall.
    local healed
    healed=$(mktemp "${TMPDIR:-/tmp}/pf.conf.XXXXXX") || return 1
    /usr/bin/awk '
        /tunneless/ { next }
        { print }
        /^rdr-anchor "com.apple\/\*"$/ { print "rdr-anchor \"tunneless\"" }
        /^load anchor "com.apple" from "\/etc\/pf.anchors\/com.apple"$/ { print "load anchor \"tunneless\" from \"/etc/pf.anchors/tunneless\"" }
    ' "$pfconf" > "$healed" || { rm -f "$healed"; return 1; }
    if ! cmp -s "$pfconf" "$healed"; then
        print "tunnel: moving tunneless anchor lines into order in $pfconf"
        sudo cp -a "$pfconf" "$pfconf.bak.$(date +%Y%m%d%H%M%S)" || { rm -f "$healed"; return 1; }
        sudo install -m 644 -o root -g wheel "$healed" "$pfconf" || { rm -f "$healed"; return 1; }
    fi
    rm -f "$healed"
    # Fail closed: never load an unparseable ruleset.
    if ! sudo pfctl -nf "$pfconf"; then
        print "tunnel: $pfconf failed syntax check, refusing to load"
        return 1
    fi
    sudo pfctl -f "$pfconf" && sudo pfctl -e
}

# Any HTTP reply counts as a live site; the site owns the status code. nc
# can only prove pf + ssh exist, not that anything answers on zenless.
_tunnel_site_ok() {
    curl -sk -o /dev/null --max-time 3 https://127.0.0.1/
}

# pf takes a beat to answer on 443 right after pfctl -f, so the first probe
# after a reload can fail on an otherwise healthy redirect. Retry briefly.
_tunnel_443_ok() {
    local try
    for try in 1 2 3; do
        nc -z 127.0.0.1 443 2>/dev/null && return 0
        (( try < 3 )) && sleep 1
    done
    return 1
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
            if _tunnel_pf_repair && _tunnel_443_ok; then
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
                print 'repair: run `tunnel up` (heals pf.conf if reverted, then reloads) or: sudo pfctl -f /etc/pf.conf && sudo pfctl -e'
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
