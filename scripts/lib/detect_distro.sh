#!/usr/bin/env bash

# Distro detection helper for dotfiles-x.
# Usage: source this file, then call `detect_distro`.
# Returns one of: macos, rpm, deb, unknown

detect_distro() {
    local os_name
    os_name="$(uname -s)"

    if [[ "$os_name" == "Darwin" ]]; then
        echo "macos"
        return 0
    fi

    if [[ "$os_name" != "Linux" ]]; then
        echo "unknown"
        return 0
    fi

    # Linux: inspect /etc/os-release
    if [[ -f /etc/os-release ]]; then
        local id like
        id="$(grep ^ID= /etc/os-release | head -1 | cut -d'=' -f2 | tr -d '"')"
        like="$(grep ^ID_LIKE= /etc/os-release | head -1 | cut -d'=' -f2 | tr -d '"')"

        # Direct matches
        case "$id" in
            fedora)       echo "rpm"; return 0 ;;
            ubuntu)       echo "deb"; return 0 ;;
            zorin*)       echo "deb"; return 0 ;;
            debian)       echo "deb"; return 0 ;;
            linuxmint)    echo "deb"; return 0 ;;
            pop)          echo "deb"; return 0 ;;
            elementary*)  echo "deb"; return 0 ;;
        esac

        # Fallback: check ID_LIKE
        case "$like" in
            *fedora*|*rhel*)  echo "rpm"; return 0 ;;
            *debian*)         echo "deb"; return 0 ;;
        esac
    fi

    # Last resort: check for dnf or apt
    if command -v dnf >/dev/null 2>&1; then
        echo "rpm"
    elif command -v apt >/dev/null 2>&1; then
        echo "deb"
    else
        echo "unknown"
    fi
}
