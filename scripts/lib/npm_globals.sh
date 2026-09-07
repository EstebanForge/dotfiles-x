#!/usr/bin/env bash

# Global npm packages installed across all platforms.
# Node.js is provided by Homebrew (macOS + Linuxbrew) on all platforms.

# Install one npm package, fault-isolated: one registry hiccup must not abort
# the caller and silently skip the CLI installers that run after it.
npm_install_safe() {
    local pkg="$1"
    if npm install -g "$pkg"; then
        echo "  npm: installed $pkg"
    else
        echo "  WARNING: npm install failed: $pkg (continuing)" >&2
    fi
}

install_npm_globals() {
    if command -v npm >/dev/null 2>&1; then
        echo "Installing global npm packages..."
        npm_install_safe postcss
        npm_install_safe postcss-cli
        npm_install_safe @github/copilot
        # Code knowledge graph for AI coding agents (codegraph init/index/sync).
        npm_install_safe @colbymchenry/codegraph
        # Persistent memory engine for AI coding agents.
        # Auto-started in the background by the platform-specific service
        # (LaunchAgent on macOS, systemd user unit on Linux) — see
        # scripts/lib/agentmemory.sh.
        npm_install_safe @agentmemory/agentmemory
        # corepack ships its own shims; enable the Yarn/pnpm managers we use.
        # Homebrew's node does not bundle corepack (added above as its own
        # formula), so this is what wires yarn/pnpm onto PATH.
        if ! corepack enable yarn pnpm; then
            echo "  WARNING: corepack enable failed (continuing)" >&2
        fi
    else
        echo "WARNING: npm not found; skipping npm packages." >&2
    fi
}
