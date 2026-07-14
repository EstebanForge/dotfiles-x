#!/usr/bin/env bash

# Curl-pipe-to-shell CLI installers, unified.
#
# Each entry: binary name, install URL, curl flags, pipe target, and an
# optional rc-strip marker. The marker (when set) names the "# Added by
# <X> installer" comment block the installer appends to shell rc files;
# our dotfiles already put ~/.local/bin on PATH, so we strip that block
# to keep rc files clean.
#
# Idempotent: skips install when the binary is already on PATH (Antigravity
# also checks ~/.local/bin/agy directly, since its installer places the
# binary there before PATH is refreshed).

# strip_installer_rc_block <marker>
# Remove the 2-line "<marker>\nexport PATH=..." block installer leaves in rc files.
# marker is escaped for sed: any / \ & . * [ ] ^ $ in the marker are made literal.
strip_installer_rc_block() {
    local marker="$1" rc escaped
    escaped="${marker//\\\\/\\\\\\\\}"   # backslash first
    escaped="${escaped//\//\\/}"        # then slash (sed delimiter)
    escaped="${escaped//&/\\&}"        # then & (replacement meta, harmless in addr)
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        [[ -f "$rc" ]] || continue
        sed -i "/${escaped}/{N;d;}" "$rc" 2>/dev/null || true
    done
}

# install_curl_cli <name> <binary> <url> <curl_flags> <pipe_shell> [rc_marker]
install_curl_cli() {
    local name="$1" binary="$2" url="$3" curl_flags="$4" pipe_shell="$5" rc_marker="${6:-}"

    if command -v "$binary" >/dev/null 2>&1; then
        echo "$name already installed, skipping."
    else
        echo "Installing $name..."
        # shellcheck disable=SC2086 # curl_flags is intentionally word-split
        curl $curl_flags "$url" | $pipe_shell
    fi

    if [[ -n "$rc_marker" ]]; then
        strip_installer_rc_block "$rc_marker"
    fi
}

install_antigravity_cli() {
    # Antigravity's installer places the binary at ~/.local/bin/agy before
    # PATH is refreshed in the current shell, so check the path directly too.
    if [[ -x "$HOME/.local/bin/agy" ]] || command -v agy >/dev/null 2>&1; then
        echo "Antigravity CLI already installed, skipping."
    else
        echo "Installing Antigravity CLI..."
        curl -fsSL "https://antigravity.google/cli/install.sh" | bash
    fi
    strip_installer_rc_block "# Added by Antigravity CLI installer"
}

install_claude_code_cli() {
    install_curl_cli "Claude Code" claude "https://claude.ai/install.sh" "-fsSL" bash \
        "# Added by Claude Code installer"
}

install_codex_cli() {
    install_curl_cli "Codex" codex "https://chatgpt.com/codex/install.sh" "-fsSL" sh \
        "# Added by Codex CLI installer"
}

install_bun_cli() {
    install_curl_cli "Bun" bun "https://bun.com/install" "-fsSL" bash
}

install_phpvm_cli() {
    install_curl_cli "phpvm" phpvm "https://raw.githubusercontent.com/Thavarshan/phpvm/main/install.sh" "-o-" bash
}
