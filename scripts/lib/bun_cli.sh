#!/usr/bin/env bash

# Bun (JavaScript runtime) installer.
# Uses the official installer, which works on macOS and Linux.
# Idempotent.

install_bun_cli() {
    if command -v bun >/dev/null 2>&1; then
        echo "Bun already installed, skipping."
    else
        echo "Installing Bun..."
        curl -fsSL https://bun.com/install | bash
    fi
}
