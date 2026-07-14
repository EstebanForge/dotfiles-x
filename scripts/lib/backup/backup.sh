#!/usr/bin/env bash

# Backup runner: discovers and executes all backup scripts in this directory.
# Designed to be invoked by cron on both macOS and Linux — one cron entry
# runs every backup, instead of one entry per backup.
#
# Each sibling script (agentmemory.sh, etc.) is a self-contained backup that:
#   * Sources ../bash_compat.sh for Bash re-exec
#   * Runs standalone (invoke directly for testing: ./agentmemory.sh)
#   * Exits 0 on success, non-zero on failure
#
# The runner isolates failures: one backup crashing does NOT abort the others.
# A summary line reports how many succeeded vs failed, and the runner exits
# non-zero if any failed so cron/mail surfaces it.

source "$(dirname "$0")/../bash_compat.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$(basename "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status()  { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

run_all() {
    local scripts=() script succeeded=0 failed=0

    # Discover sibling .sh scripts, excluding this runner. -maxdepth 1 so a
    # nested subdir (e.g. a future lib helper) isn't picked up.
    while IFS= read -r -d '' script; do
        [[ "$(basename "$script")" == "$RUNNER" ]] && continue
        scripts+=("$script")
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)

    if (( ${#scripts[@]} == 0 )); then
        print_warning "No backup scripts found in $SCRIPT_DIR"
        return 0
    fi

    print_status "Running ${#scripts[@]} backup script(s)..."
    echo ""
    for script in "${scripts[@]}"; do
        print_status "→ $(basename "$script")"
        if bash "$script"; then
            echo ""
            ((succeeded++)) || true
        else
            status=$?
            print_error "✗ $(basename "$script") failed (exit $status)"
            echo ""
            ((failed++)) || true
        fi
    done

    print_status "Backup complete: $succeeded succeeded, $failed failed"
    # Non-zero exit if any failed, so cron/mail surfaces it.
    (( failed == 0 ))
}

list_backups() {
    local script
    print_status "Available backup scripts:"
    while IFS= read -r -d '' script; do
        [[ "$(basename "$script")" == "$RUNNER" ]] && continue
        echo "  $(basename "$script")"
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
}

case "${1:-run}" in
    run) run_all ;;
    list) list_backups ;;
    help|-h|--help)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  run    Run all backup scripts (default)"
        echo "  list   List available backup scripts"
        echo "  help   Show this help message"
        echo ""
        echo "Add new backups by dropping a *.sh file next to this runner."
        ;;
    *)
        print_error "Unknown command: $1"
        print_error "Use '$0 help' for usage information"
        exit 1
        ;;
esac
