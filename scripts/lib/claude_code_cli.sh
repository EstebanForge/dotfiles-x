#!/usr/bin/env bash

# Claude Code CLI installer (official, maintained by Anthropic).
# Uses curl pipe-to-bash so all platforms use the same installer and it
# stays current with Anthropic's setup changes. Idempotent.

CLAUDE_CODE_INSTALL_URL="https://claude.ai/install.sh"

install_claude_code_cli() {
    if command -v claude >/dev/null 2>&1; then
        echo "Claude Code already installed, skipping."
    else
        echo "Installing Claude Code CLI..."
        curl -fsSL "$CLAUDE_CODE_INSTALL_URL" | bash
    fi

    # The installer appends a redundant ~/.local/bin PATH line to shell rc
    # files; our dotfiles already put ~/.local/bin on PATH. Strip its
    # "# Added by Claude Code installer" block to keep rc files clean.
    local rc
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        [[ -f "$rc" ]] || continue
        sed -i '/# Added by Claude Code installer/{N;d;}' "$rc" 2>/dev/null || true
    done
}
