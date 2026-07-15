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
# `--setup` writes a config (~/.config/wayland-wheeltani/config.toml, lowercase
# per the daemon's XDG dir) keyed by USB vendor/product IDs (stable across
# reboots/replugs). Subsequent runs skip setup and are fully non-interactive.

# Re-exec under Bash when invoked from another shell (e.g. zsh wheeltani_autoscroll.sh).
source "$(dirname "$0")/lib/bash_compat.sh"

set -euo pipefail

WT_BIN="$HOME/.cargo/bin/wayland-wheeltani"
WT_CONFIG="$HOME/.config/wayland-wheeltani/config.toml"

# USB mouse = an input device udev tags ID_INPUT_MOUSE=1 with a real vendor ID
# (ID_VENDOR_ID is populated by the usb/pci builtins; I2C/ACPI touchpads lack
# it, and Wheeltani can neither match them nor grant access to them).
usb_mouse_present() {
    local ev props vid
    for ev in /dev/input/event*; do
        props="$(udevadm info -q property "$ev" 2>/dev/null)" || continue
        grep -q '^ID_INPUT_MOUSE=1' <<<"$props" || continue
        vid="$(sed -n 's/^ID_VENDOR_ID=//p' <<<"$props")"
        [[ -n "$vid" ]] && return 0
    done
    return 1
}

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
    echo "Wheeltani config present, skipping setup."
elif [[ ! -t 0 ]]; then
    echo "NOTE: non-interactive shell, skipping mouse setup." >&2
    echo "Run later to pick your mouse:" >&2
    echo "  sudo \"$WT_BIN\" --setup --install-udev-rule" >&2
    echo "  sudo udevadm control --reload-rules" >&2
    echo "  \"$WT_BIN\" --install-service" >&2
elif ! usb_mouse_present; then
    echo "NOTE: no USB mouse detected; skipping Wheeltani setup." >&2
    echo "      Wheeltani needs a USB mouse. Laptop touchpads sit on I2C/ACPI and" >&2
    echo "      lack the vendor/product IDs it matches on. Plug a mouse in and" >&2
    echo "      re-run 'dots install', or invoke the picker yourself later:" >&2
    echo "        sudo \"$WT_BIN\" --setup --install-udev-rule" >&2
else
    echo "One-time setup: pick your mouse from the list."
    # --setup writes the config for SUDO_USER (this user); --install-udev-rule
    # writes /etc/udev/rules.d/ (needs root) so the user can read the device
    # and /dev/uinput without running the daemon as root.
    #
    # This can still fail if a non-USB device (e.g. a touchpad) gets picked or
    # the rule install hits missing udev IDs. Don't abort the whole dotfiles
    # install: roll back the partial config (so the next run re-prompts) and
    # let the user finish manually.
    if ! sudo "$WT_BIN" --setup --install-udev-rule; then
        echo "WARNING: Wheeltani setup / udev-rule install failed." >&2
        rm -f "$WT_CONFIG"
        echo "         Partial config removed. Pick a USB mouse, or install the" >&2
        echo "         rule manually; see:" >&2
        echo "         https://github.com/docloulou/Wayland-Wheeltani (contrib/)" >&2
    fi
    sudo udevadm control --reload-rules || true
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
