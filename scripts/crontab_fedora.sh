#!/usr/bin/env bash

# Crontab setup script for Fedora Linux
# This script configures common cron jobs for Fedora Linux systems

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to backup existing crontab
backup_crontab() {
    if crontab -l >/dev/null 2>&1; then
        local backup_file="$HOME/.crontab.backup.$(date +%Y%m%d_%H%M%S)"
        crontab -l >"$backup_file"
        print_status "Existing crontab backed up to: $backup_file"
    fi
}

# Function to install crontab entries
install_crontab() {
    local temp_crontab=$(mktemp)
    
    # Get existing crontab if it exists
    if crontab -l >/dev/null 2>&1; then
        crontab -l >"$temp_crontab"
    fi
    
    # Add new cron entries
    cat >>"$temp_crontab" <<'EOF'

# Run topgrade for system updates - Daily at 10 AM
0 10 * * * topgrade -y 2>/dev/null || true

EOF
    
    # Install the new crontab
    crontab "$temp_crontab"
    rm "$temp_crontab"
    
    print_status "Crontab entries installed successfully"
}

# Function to show current crontab
show_crontab() {
    if crontab -l >/dev/null 2>&1; then
        print_status "Current crontab entries:"
        crontab -l
    else
        print_warning "No crontab entries found"
    fi
}

# Function to remove crontab entries
remove_crontab() {
    if crontab -l >/dev/null 2>&1; then
        backup_crontab
        crontab -r
        print_status "All crontab entries removed"
    else
        print_warning "No crontab entries to remove"
    fi
}

# Function to check if cron service is running
check_cron_service() {
    if ! systemctl is-active --quiet cron; then
        print_warning "Cron service is not running"
        print_status "Starting cron service..."
        sudo systemctl start cron
        sudo systemctl enable cron
        print_status "Cron service started and enabled"
    else
        print_status "Cron service is running"
    fi
}

# Function to check if required tools are available
check_dependencies() {
    local missing_deps=()
    
    if ! command -v crontab >/dev/null 2>&1; then
        missing_deps+=("crontab")
    fi
    
    if ! command -v systemctl >/dev/null 2>&1; then
        missing_deps+=("systemctl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Please install the missing dependencies and try again"
        exit 1
    fi
}

# Main script logic
main() {
    print_status "Fedora Linux Crontab Setup Script"
    print_status "================================="
    
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

# Run main function with all arguments
main "$@"