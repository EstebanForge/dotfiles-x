#!/usr/bin/env bash

# Global npm packages installed across all platforms.
# Node.js is provided by Homebrew (macOS + Linuxbrew) on all platforms.

install_npm_globals() {
    if command -v npm >/dev/null 2>&1; then
        echo "Installing global npm packages..."
        npm install -g postcss
        npm install -g postcss-cli
        npm install -g @github/copilot
        # Persistent memory engine for AI coding agents.
        # Auto-started in the background by the platform-specific service
        # (LaunchAgent on macOS, systemd user unit on Linux) — see
        # scripts/lib/agentmemory.sh.
        npm install -g @agentmemory/agentmemory
        corepack enable yarn
    else
        echo "WARNING: npm not found; skipping npm packages." >&2
    fi
}
