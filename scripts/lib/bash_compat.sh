#!/usr/bin/env bash
# Re-exec helpers shared across all dotfiles scripts.
#
# Source this near the top of a script (after the shebang, before set -euo):
#
#   source "$(dirname "$0")/lib/bash_compat.sh"
#
# It re-execs the current script under Bash when invoked from another
# shell (e.g. `zsh install_rpm.sh`), then is a no-op on the re-invoked
# Bash process. Must run before set -euo pipefail so the bare variable
# refs don't trip -u.
#
if [[ -z "${BASH_VERSION:-}" ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "This script requires Bash to run." >&2
    exit 1
fi
