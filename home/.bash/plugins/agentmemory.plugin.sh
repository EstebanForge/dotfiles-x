#!/usr/bin/env bash
# agentmemory.plugin.sh - guard + helpers for the launchd-managed engine
#
# Engine auto-starts via systemd user unit (agentmemory.service); see
# scripts/lib/agentmemory.sh. The guard prevents accidental manual starts
# from a project dir, which would bind a different ./data store
# (cwd-relative path footgun). Only non-starting subcommands pass through.

agentmemory() {
    if [[ "$1" == "stop" || "$1" == "status" || "$1" == "doctor" || "$1" == "demo" ]]; then
        command agentmemory "$@"
    else
        echo "Engine managed by systemd. Use: systemctl --user restart agentmemory.service" >&2
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
