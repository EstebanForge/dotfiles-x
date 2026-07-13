#!/usr/bin/env bash

# Codex CLI (OpenAI) installer.
# Uses the official installer, which works on macOS and Linux.
# Idempotent.

install_codex_cli() {
    if command -v codex >/dev/null 2>&1; then
        echo "Codex CLI already installed, skipping."
    else
        echo "Installing Codex CLI..."
        curl -fsSL https://chatgpt.com/codex/install.sh | sh
    fi

    # The installer appends a redundant ~/.local/bin PATH line to shell rc
    # files; our dotfiles already put ~/.local/bin on PATH. Strip its
    # "# Added by Codex CLI installer" block to keep rc files clean.
    local rc
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        [[ -f "$rc" ]] || continue
        sed -i '/# Added by Codex CLI installer/{N;d;}' "$rc" 2>/dev/null || true
    done
}
