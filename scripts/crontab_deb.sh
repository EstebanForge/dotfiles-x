#!/usr/bin/env bash

# Re-exec with Bash when invoked from another shell (for example: zsh script.sh).
if [[ -z "${BASH_VERSION:-}" ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "This script requires Bash to run." >&2
    exit 1
fi

# Crontab setup script for Debian-based systems
# Supports ZorinOS, Ubuntu, and other Debian-based distros.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/detect_distro.sh
source "$SCRIPT_DIR/lib/detect_distro.sh"

distro="$(detect_distro)"
if [[ "$distro" != "deb" ]]; then
    echo "This script is for Debian-based distros. Detected: $distro" >&2
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
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

    cat >>"$temp_crontab" <<'EOF'

# Run topgrade for system updates - Daily at 10 AM
0 10 * * * topgrade -y 2>/dev/null || true

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
    if ! systemctl is-active --quiet cron 2>/dev/null; then
        print_warning "Cron service is not running"
        print_status "Starting cron service..."
        sudo systemctl start cron
        sudo systemctl enable cron
        print_status "Cron service started and enabled"
    else
        print_status "Cron service is running"
    fi
}

check_dependencies() {
    local missing_deps=()
    command -v crontab >/dev/null 2>&1 || missing_deps+=("crontab")
    command -v systemctl >/dev/null 2>&1 || missing_deps+=("systemctl")

    if (( ${#missing_deps[@]} > 0 )); then
        print_error "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

main() {
    print_status "Debian-based Crontab Setup Script"
    print_status "==================================="

    check_dependencies
    check_cron_service

    case "${1:-install}" in
        "install")
            backup_crontab
            install_crontab
            show_crontab
            ;;
        "show"|"status")
            show_crontab
            ;;
        "remove"|"cleanup")
            remove_crontab
            ;;
        "backup")
            backup_crontab
            ;;
        "service")
            check_cron_service
            ;;
        "help"|"-h"|"--help")
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
