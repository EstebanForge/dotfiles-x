#!/usr/bin/env bash

# agentmemory engine helpers.
# https://github.com/rohitg00/agentmemory
#
# The npm package itself is installed by scripts/lib/npm_globals.sh.
# This lib wires the engine into a host OS service so it auto-launches
# in the background on every login:
#
#   * macOS  -> LaunchAgent at ~/Library/LaunchAgents/com.agentmemory.server.plist
#   * Linux  -> systemd user unit at ~/.config/systemd/user/agentmemory.service
#
# Both functions are no-ops (with a warning) if the `agentmemory` binary
# is not on PATH, so it's safe to call them after a fresh checkout before
# `npm install -g @agentmemory/agentmemory` has been run.

# Render the LaunchAgent plist template into ~/Library/LaunchAgents and load
# it via launchctl. Idempotent: re-running after install re-applies the
# service with fresh content.
install_agentmemory_service_macos() {
    if ! command -v agentmemory >/dev/null 2>&1; then
        echo "WARNING: agentmemory binary not on PATH; skipping LaunchAgent install." >&2
        echo "         Run \`dots install --packages\` (or install_macos.sh) first." >&2
        return 0
    fi

    local script_dir launchagents_dir template target label uid
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    launchagents_dir="$HOME/Library/LaunchAgents"
    template="$script_dir/com.agentmemory.server.plist.template"
    target="$launchagents_dir/com.agentmemory.server.plist"
    label="com.agentmemory.server"
    uid="$(id -u)"

    if [[ ! -f "$template" ]]; then
        echo "WARNING: LaunchAgent template missing: $template" >&2
        return 0
    fi

    mkdir -p "$launchagents_dir" "$HOME/.agentmemory"

    # Render template (substitute __HOME__). Pipe-delimited sed avoids
    # conflicts with path slashes.
    sed "s|__HOME__|$HOME|g" "$template" > "$target"
    chmod 644 "$target"

    # Validate before loading — launchctl silently accepts broken plists.
    if ! plutil -lint "$target" >/dev/null; then
        echo "WARNING: rendered LaunchAgent failed plutil -lint: $target" >&2
        return 0
    fi

    # Bootout any existing copy so a re-run doesn't accumulate agents.
    launchctl bootout "gui/$uid/$label" 2>/dev/null || true
    launchctl bootstrap "gui/$uid" "$target" 2>/dev/null \
        || echo "WARNING: launchctl bootstrap failed for $label (may already be loaded)." >&2
    launchctl enable "gui/$uid/$label" 2>/dev/null || true
    # kickstart ensures the engine is actually running right now, not just
    # configured to start on next login.
    launchctl kickstart -k "gui/$uid/$label" 2>/dev/null || true

    echo "agentmemory LaunchAgent installed: $label"
}

# Enable the systemd user unit so it auto-starts on every login and run
# it now. Idempotent: re-running just refreshes the enable state.
install_agentmemory_service_linux() {
    if ! command -v agentmemory >/dev/null 2>&1; then
        echo "WARNING: agentmemory binary not on PATH; skipping systemd unit enable." >&2
        echo "         Run \`dots install --packages\` (or install_rpm.sh / install_deb.sh) first." >&2
        return 0
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        echo "WARNING: systemctl not found; cannot enable agentmemory systemd user unit." >&2
        return 0
    fi

    local unit_dir="$HOME/.config/systemd/user"
    local unit="$unit_dir/agentmemory.service"

    mkdir -p "$unit_dir"

    # The unit file is symlinked from the dotfiles repo by dots.sh. If the
    # symlink is missing (e.g. dotfiles not yet installed), bail with a hint
    # rather than copying the file silently — the symlink is the source of
    # truth and is what tracks upgrades.
    if [[ ! -e "$unit" ]]; then
        echo "WARNING: systemd unit not found at $unit" >&2
        echo "         Run \`dots install\` to symlink it from the dotfiles repo." >&2
        return 0
    fi

    # XDG_RUNTIME_DIR is the canonical systemd user bus socket location;
    # it's set by systemd --user itself once a user session starts. When
    # configure scripts run at first boot it may not exist yet, in which
    # case systemctl falls back to a private socket. Don't fail on it.
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

    systemctl --user daemon-reload 2>/dev/null || {
        echo "WARNING: systemctl --user daemon-reload failed (no user session yet?)." >&2
        return 0
    }
    systemctl --user enable --now agentmemory.service 2>/dev/null \
        || echo "WARNING: systemctl --user enable --now agentmemory.service failed." >&2

    echo "agentmemory systemd user unit enabled: agentmemory.service"
}
