#!/usr/bin/env bash

# Middle-mouse-hold autoscroll for Wayland via Wayland-Wheeltani.
#
# Hold the middle mouse button, move the pointer, and the daemon emits smooth
# scroll events through a virtual mouse. Release the button and scrolling stops.
# A short middle click still behaves as a normal middle click. Purpose-built for
# this exact workflow (unlike the deprecated libinput-config ld.so.preload hack,
# which was archived in Nov 2025 and only incidentally covered it).
#
# Fedora-only (Wayland + systemd --user). Replaces the old libinput-config flow:
#   git clone libinput-config && meson && ninja install + /etc/libinput.conf
# Project: https://github.com/docloulou/Wayland-Wheeltani
#
# One-time interactive step: the daemon must know which physical mouse to read.
# `--setup` writes a config (~/.config/Wayland-Wheeltani/config.toml) keyed by
# USB vendor/product IDs (stable across reboots/replugs). Subsequent runs skip
# setup and are fully non-interactive.

# Re-exec with Bash when invoked from another shell (for example: zsh script.sh).
if [[ -z "${BASH_VERSION:-}" ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "This script requires Bash to run." >&2
    exit 1
fi

set -euo pipefail

WT_BIN="$HOME/.cargo/bin/wayland-wheeltani"
WT_CONFIG="$HOME/.config/Wayland-Wheeltani/config.toml"

echo "=== Wayland-Wheeltani autoscroll setup ==="

# 1. Ensure the Rust toolchain is available (cargo). Not auto-installed here:
# rust is a heavy toolchain; if missing, point the user at it and stop cleanly.
if ! command -v cargo >/dev/null 2>&1; then
    echo "ERROR: cargo (Rust) is required to install wayland-wheeltani." >&2
    echo "Install Rust first, e.g. via Homebrew (rust is in the shared formulae):" >&2
    echo "  brew install rust" >&2
    echo "or via rustup: https://rustup.rs" >&2
    exit 1
fi

# 2. Install the binary (idempotent).
if [[ -x "$WT_BIN" ]]; then
    echo "wayland-wheeltani already installed."
else
    echo "Installing wayland-wheeltani via cargo..."
    cargo install wayland-wheeltani
fi

# 3. One-time interactive mouse selection + udev rule. Skipped if a config
#    already exists (idempotent) or if there is no interactive TTY (the daemon
#    --setup prompts you to pick a mouse from a list).
if [[ -f "$WT_CONFIG" ]]; then
    echo "Wayland-Wheeltani config present, skipping setup."
elif [[ ! -t 0 ]]; then
    echo "NOTE: non-interactive shell, skipping mouse setup." >&2
    echo "Run later to pick your mouse:" >&2
    echo "  sudo \"$WT_BIN\" --setup --install-udev-rule" >&2
    echo "  sudo udevadm control --reload-rules" >&2
    echo "  \"$WT_BIN\" --install-service" >&2
else
    echo "One-time setup: pick your mouse from the list."
    # --setup writes the config for SUDO_USER (this user); --install-udev-rule
    # writes /etc/udev/rules.d/ (needs root) so the user can read the device
    # and /dev/uinput without running the daemon as root.
    sudo "$WT_BIN" --setup --install-udev-rule
    sudo udevadm control --reload-rules
fi

# 4. Install + start the systemd --user service (NEVER with sudo: it manages
#    this user's session bus). Idempotent: --install-service enables + starts.
if [[ -f "$WT_CONFIG" ]]; then
    echo "Installing + starting systemd --user service..."
    "$WT_BIN" --install-service
fi

# 5. Verify (informational; not fatal under set -e).
if systemctl --user is-active --quiet wayland-wheeltani 2>/dev/null; then
    echo "wayland-wheeltani user service is running."
else
    echo "NOTE: service not active yet." >&2
    echo "If setup was skipped, complete it then: \"$WT_BIN\" --install-service" >&2
fi

echo "Wayland-Wheeltani setup complete."
echo "Tip: hold the middle mouse button and move to scroll; release to stop."
