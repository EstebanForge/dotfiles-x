#!/usr/bin/env bash

# Antigravity CLI (Google's replacement for Gemini CLI) installer.
# Uses curl pipe-to-bash (not available via Homebrew).

ANTIGRAVITY_CLI_INSTALL_URL="https://antigravity.google/cli/install.sh"

install_antigravity_cli() {
    # The CLI self-updates in the background during normal use, so a re-install
    # only spams a "already installed" notice. Skip if the binary is present.
    if [[ -x "$HOME/.local/bin/agy" ]] || command -v agy >/dev/null 2>&1; then
        echo "Antigravity CLI already installed, skipping."
    else
        echo "Installing Antigravity CLI..."
        curl -fsSL "$ANTIGRAVITY_CLI_INSTALL_URL" | bash
    fi

    # The installer appends a redundant ~/.local/bin PATH line to shell rc
    # files; our dotfiles already put ~/.local/bin on PATH. Strip its
    # "# Added by Antigravity CLI installer" block to keep rc files clean.
    local rc
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        [[ -f "$rc" ]] || continue
        sed -i '/# Added by Antigravity CLI installer/{N;d;}' "$rc" 2>/dev/null || true
    done
}
