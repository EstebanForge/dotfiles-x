#!/usr/bin/env bash

# Re-exec under Bash when invoked from another shell (e.g. zsh crontab.sh).
source "$(dirname "$0")/lib/bash_compat.sh"

# Crontab setup script (all platforms: macOS, RPM, Deb).
# Installs a daily topgrade cron job, plus backup/show/remove/service helpers.
# Platform differences (cron service name, topgrade path, deps) are resolved
# from the detected distro so the CLI surface is identical everywhere.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"

DISTRO="$(detect_distro)"

# Per-platform config: cron service name (empty = launchd, no service check),
# topgrade invocation, and required deps.
case "$DISTRO" in
    macos)
        CRON_SERVICE=""
        TOPGRADE="/opt/homebrew/bin/topgrade"
        REQUIRED_DEPS=(crontab)
        LABEL="macOS"
        ;;
    rpm)
        CRON_SERVICE="crond"
        TOPGRADE="topgrade"
        REQUIRED_DEPS=(crontab systemctl)
        LABEL="Fedora Linux"
        ;;
    deb)
        CRON_SERVICE="cron"
        TOPGRADE="topgrade"
        REQUIRED_DEPS=(crontab systemctl)
        LABEL="Deb-based"
        ;;
    *)
        echo "Unsupported distro for crontab setup: $DISTRO" >&2
        exit 1
        ;;
esac

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status()  { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

backup_crontab() {
    if crontab -l >/dev/null 2>&1; then
        local backup_file
        backup_file="$HOME/.crontab.backup.$(date +%Y%m%d_%H%M%S)"
        crontab -l >"$backup_file"
        print_status "Existing crontab backed up to: $backup_file"
    fi
}

install_crontab() {
    local temp_crontab
    temp_crontab=$(mktemp)
    trap 'rm -f "$temp_crontab"' EXIT

    if crontab -l >/dev/null 2>&1; then
        crontab -l >"$temp_crontab"
    fi

    # Skip if entry already exists
    if grep -qF 'topgrade' "$temp_crontab" 2>/dev/null; then
        print_status "Crontab entries already installed"
        return 0
    fi

    cat >>"$temp_crontab" <<EOF

# Run topgrade for system updates - Daily at 10 AM
0 10 * * * $TOPGRADE -y 2>/dev/null || true

EOF

    crontab "$temp_crontab"
    print_status "Crontab entries installed successfully"
}

show_crontab() {
    if crontab -l >/dev/null 2>&1; then
        print_status "Current crontab entries:"
        crontab -l
    else
        print_warning "No crontab entries found"
    fi
}

remove_crontab() {
    if crontab -l >/dev/null 2>&1; then
        backup_crontab
        crontab -r
        print_status "All crontab entries removed"
    else
        print_warning "No crontab entries to remove"
    fi
}

check_cron_service() {
    [[ -n "$CRON_SERVICE" ]] || return 0
    if ! systemctl is-active --quiet "$CRON_SERVICE" 2>/dev/null; then
        print_warning "Cron service ($CRON_SERVICE) is not running"
        print_status "Starting cron service..."
        sudo systemctl start "$CRON_SERVICE"
        sudo systemctl enable "$CRON_SERVICE"
        print_status "Cron service started and enabled"
    else
        print_status "Cron service ($CRON_SERVICE) is running"
    fi
}

check_dependencies() {
    local missing_deps=() dep
    for dep in "${REQUIRED_DEPS[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || missing_deps+=("$dep")
    done
    if (( ${#missing_deps[@]} > 0 )); then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Please install the missing dependencies and try again"
        exit 1
    fi
}

main() {
    print_status "$LABEL Crontab Setup Script"
    print_status "==================================="

    # Deps and service checks run only for actions that need them, so help
    # and read-only commands don't abort on a missing crontab binary or
    # trigger a sudo'd systemctl start.
    case "${1:-install}" in
        install)
            check_dependencies
            check_cron_service
            backup_crontab
            install_crontab
            show_crontab
            ;;
        show|status)
            check_dependencies
            show_crontab
            ;;
        remove|cleanup)
            check_dependencies
            remove_crontab
            ;;
        backup)
            check_dependencies
            backup_crontab
            ;;
        service)
            check_dependencies
            check_cron_service
            ;;
        help|-h|--help)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  install   Install crontab entries (default)"
            echo "  show      Show current crontab entries"
            echo "  remove    Remove all crontab entries"
            echo "  backup    Backup existing crontab"
            echo "  service   Check and start cron service"
            echo "  help      Show this help message"
            ;;
        *)
            print_error "Unknown command: $1"
            print_error "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
