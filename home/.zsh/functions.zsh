# shellcheck shell=bash
# zsh file: shellcheck only speaks bash, so zsh-specific constructs are
# disabled file-wide (read -q prompt assignment, literal backticks in print,
# zsh parameter-expansion flags and array literals shellcheck cannot model:
# SC2190, SC2034, SC2206, SC2128, SC2086, SC2296).
# shellcheck disable=SC2162,SC2154,SC2016,SC2190,SC2034,SC2206,SC2128,SC2086,SC2296
# User shell functions. Sourced by .zshrc after the prompt.
# Keep this file small: functions only, no aliases, no exports.

# zenless tunnel: browse https://<site>.localhost on a different machine for sites
# served by the wicket stack (FrankenPHP/Caddy) on zenless. pf maps
# 127.0.0.1:80->8080 and :443->8443 (see /etc/pf.anchors/tunneless);
# `ssh -fN tunneless` binds the high ports and carries the config stanza
# forwards to zenless 80/443/8025. Caddy routes by hostname (SNI), so one
# chain carries every site and the tunnel never learns site names; site
# checks are TCP-only because Caddy refuses TLS for non-site SNI by design
# (an HTTP probe with the wrong hostname false-fails a healthy chain).
# Site ports beyond 80/443/8025 are discovered from the stack's listeners
# and appended as -L flags on the same connection; `refresh` rebuilds when
# they drift. pf rules are root-owned and die when something flushes pf
# (VPN helpers do this); `up` then offers the sudo repair (y/N prompt,
# password stays in the terminal) and prints the manual command on decline.
# macOS upgrades revert /etc/pf.conf to stock, so the repair re-adds the
# tunneless anchor lines before reloading. `status` only reports.
# Usage: tunnel [up|down|status|refresh]   (no argument = up)
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

# Site ports listening on zenless, one per line. The wicket stack binds a
# loopback port per site, so the set is dynamic and stays unknown to the
# tunnel. Loopback/wildcard binds and named web processes only: keeps out
# adb, chrome devtools, agent ports and the tailscale interface. Root-owned
# listeners hide their process name from ss, which keeps non-stack services
# out by default. 2019 would be the Caddy admin endpoint, not a site.
_tunnel_discover() {
    local out line addr port proc
    local -a extras
    typeset -A seen
    seen=(80 1 443 1 8025 1)
    out=$(ssh -o ConnectTimeout=5 -o ClearAllForwardings=yes zenless 'ss -tlnp' 2>/dev/null) || {
        print -u2 'tunnel: site-port discovery failed (zenless unreachable), keeping base forwards'
        return 1
    }
    for line in ${(f)out}; do
        [[ $line == LISTEN\ * ]] || continue
        addr=${line[(w)4]}
        case $addr in
            127.0.0.1:*|[[]::1]:*|[[]::]:*|0.0.0.0:*|\*:*) ;;
            *) continue ;;
        esac
        port=${addr##*:}
        proc=${line#*\"}
        proc=${proc%%\"*}
        [[ $proc =~ ^(frankenphp|caddy|php.*|wicket|nginx|httpd|apache2|traefik)$ ]] || continue
        [[ $port == 2019 ]] && continue
        (( seen[$port]++ )) && continue
        extras+=($port)
    done
    (( ${#extras} )) && print -lr -- $extras
    return 0
}

# One ssh connection carries the stanza base plus discovered extras as -L
# flags (CLI -L does not suppress the stanza, and a second connection would
# double-bind 8080/8443). The kill/pgrep pattern must match every argv
# shape the tunnel has ever started (legacy had options after the host),
# else a stale ssh survives its own rebuild and rebinds all clash. Probing
# local ports first keeps one busy port from tripping ExitOnForwardFailure
# and killing the whole tunnel.
_tunnel_start() {
    local port extras
    local -a fwd
    if extras=$(_tunnel_discover); then
        for port in ${(f)extras}; do
            if nc -z 127.0.0.1 "$port" 2>/dev/null; then
                print "tunnel: local port $port busy, skipping zenless:$port"
            else
                fwd+=(-L "127.0.0.1:${port}:127.0.0.1:${port}")
            fi
        done
    fi
    if ! ssh -fN tunneless -o ExitOnForwardFailure=yes "${fwd[@]}"; then
        (( ${#fwd} )) || return 1
        print 'tunnel: extra forwards failed to bind, retrying base only'
        # Base retry keeps the pre-extras tolerance: a busy client-side base
        # port must degrade the chain, not kill the tunnel.
        ssh -fN tunneless
    fi
}

# pkill only signals; the dying ssh holds the port binds for a beat, and a
# new ssh started too early fails every bind. Wait for the release.
_tunnel_ssh_gone() {
    local try
    for try in {1..15}; do
        pgrep -f 'ssh -f.?N.*tunneless' >/dev/null || return 0
        sleep 0.2
    done
    return 1
}

# Ports the tunnel ssh itself binds locally, one per line. Scoped to the
# tunnel pid: any other ssh -L on the machine must not read as a tunnel
# forward. Empty output when the tunnel ssh is not running.
_tunnel_forwarded_ports() {
    local line addr port
    local -a pids ports
    typeset -A seen
    pids=(${(f)"$(pgrep -f 'ssh -f.?N.*tunneless')"})
    (( ${#pids} )) || return 0
    for line in ${(f)"$(lsof -a -nP -p ${(j:,:)pids} -iTCP -sTCP:LISTEN 2>/dev/null)"}; do
        addr=${line[(w)9]}
        [[ $addr == 127.0.0.1:* ]] || continue
        seen[${addr#127.0.0.1:}]=1
    done
    (( ${#seen} )) && print -lr -- ${(kon)seen}
    return 0
}

# Discovered site ports with no local forward yet (drift). Empty output with
# rc 0 = nothing to add; rc 1 = discovery failed (warned by _tunnel_discover).
# A port held by another local app can never be forwarded, so it is neither
# fresh nor carried; the stderr hint keeps that from being silent.
_tunnel_unforwarded() {
    local port extras
    local -a fresh
    typeset -A carried
    extras=$(_tunnel_discover) || return 1
    for port in $(_tunnel_forwarded_ports); do carried[$port]=1; done
    for port in ${(f)extras}; do
        (( ${+carried[$port]} )) && continue
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            print -u2 "tunnel: local port $port busy (not the tunnel), cannot forward zenless:$port"
        else
            fresh+=("$port")
        fi
    done
    (( ${#fresh} )) && print -lr -- $fresh
    return 0
}

# While the chain is up, pick up site ports that started after the tunnel:
# rebuild the one connection so they get forwards. A rebuild drops live
# browser connections for a beat, which is why status only hints.
_tunnel_adopt_extras() {
    local fresh
    fresh=$(_tunnel_unforwarded) || return 0
    [[ -n $fresh ]] || return 0
    print "tunnel: new site ports, rebuilding ssh: ${fresh//$'\n'/ }"
    # Preflight before the kill: a failed rebuild must not be the thing
    # that takes a working tunnel down.
    _bw_ssh_preflight "$HOME/.ssh/attd-zenless" || {
        print 'tunnel: ssh preflight failed, keeping the running tunnel'
        return 1
    }
    pkill -f 'ssh -f.?N.*tunneless'
    _tunnel_ssh_gone || { print 'tunnel: old ssh would not die; run `tunnel refresh`'; return 1; }
    _tunnel_start || { print 'tunnel: rebuild failed; run `tunnel refresh`'; return 1; }
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

# Chain-only report: the 443 proof is TCP level, so it says the chain
# carries traffic, not that a specific site answers. The browser (SNI) is
# the site test. Lists what the ssh connection actually binds locally.
_tunnel_report() {
    local forwarded
    local -a ports
    forwarded=$(_tunnel_forwarded_ports)
    ports=(${(f)forwarded})
    if ! nc -z 127.0.0.1 443 2>/dev/null; then
        print 'tunnel: chain down (pf redirect or ssh half); run `tunnel up`'
        return 1
    fi
    print 'tunnel: up (pf + ssh + zenless:443 reachable, TCP proof)'
    print "tunnel: forwarded local ports: ${(on)ports}"
    print 'tunnel: browse https://<site>.localhost (SNI rides the chain; browser is the site test)'
}

tunnel() {
    local cmd="${1:-up}"
    local fresh
    case "$cmd" in
        up)
            # 443 proves pf + ssh reach a zenless web port.
            if nc -z 127.0.0.1 443 2>/dev/null; then
                _tunnel_adopt_extras
                _tunnel_report
                return 0
            fi
            if ! nc -z 127.0.0.1 8443 2>/dev/null; then
                _bw_ssh_preflight "$HOME/.ssh/attd-zenless" || return 1
                _tunnel_start || return 1
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
            if pkill -f 'ssh -f.?N.*tunneless'; then
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
        refresh)
            pkill -f 'ssh -f.?N.*tunneless' && print 'tunnel: ssh stopped for rebuild'
            _tunnel_ssh_gone || { print 'tunnel: old ssh would not die; kill it manually'; return 1; }
            _bw_ssh_preflight "$HOME/.ssh/attd-zenless" || return 1
            _tunnel_start || return 1
            _tunnel_report
            ;;
        status)
            # Read-only on purpose: drift is reported, never healed here.
            if nc -z 127.0.0.1 443 2>/dev/null; then
                _tunnel_report
                if ! fresh=$(_tunnel_unforwarded); then
                    print 'tunnel: site drift check skipped (zenless unreachable)'
                elif [[ -n $fresh ]]; then
                    print "tunnel: unforwarded site ports: ${fresh//$'\n'/ }" '-> run `tunnel refresh`'
                fi
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
            print 'usage: tunnel [up|down|status|refresh]'
            return 1
            ;;
    esac
}

# SSH host wrappers (attd-zenless + Bitwarden agent pre-flight) live in
# ~/.config/estebanforge/ssh-hosts.sh, shared with .bashrc.
