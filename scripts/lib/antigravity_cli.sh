#!/usr/bin/env bash

# Antigravity CLI (Google's replacement for Gemini CLI) installer.
# Uses curl pipe-to-bash (not available via Homebrew).

ANTIGRAVITY_CLI_INSTALL_URL="https://antigravity.google/cli/install.sh"

install_antigravity_cli() {
    echo "Installing Antigravity CLI..."
    if command -v antigravity &>/dev/null; then
        echo "Antigravity CLI already installed ($(antigravity --version 2>/dev/null || echo "unknown version")). Updating..."
        curl -fsSL "$ANTIGRAVITY_CLI_INSTALL_URL" | bash
    else
        curl -fsSL "$ANTIGRAVITY_CLI_INSTALL_URL" | bash
    fi
}
