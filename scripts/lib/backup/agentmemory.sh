#!/usr/bin/env bash

# agentmemory backup: stop the daemon (flush to disk), copy the data store,
# restart the daemon, then encrypt the copy with 7z AES-256 into Google Drive.
#
# Why stop (not hot export): the /export REST endpoint serializes the full
# in-memory state into one JSON. With ~2000 sessions some have massive
# observation sets, and the endpoint hangs even at maxSessions=5. The on-disk
# .bin store is NOT written live — data only reaches disk on graceful stop
# (confirmed: files stay stale during runtime until the worker flushes). So
# stopping is mandatory for a complete, consistent backup.
#
# The #843 fix (present in the 0.9.27 publish) makes `agentmemory stop`
# flush correctly: worker SIGTERM (5s grace, flushes indexes) → engine
# SIGTERM (3s grace). Both service managers (launchd KeepAlive.SuccessfulExit
# =false, systemd Restart=on-failure) leave a clean-stop down — no restart
# race — so we control the full stop→copy→restart window.
#
# Downtime: ~1-2 min (stop ~8s + copy ~30-60s + restart ~5s). Encryption
# runs AFTER restart, so it adds no downtime.
#
# Requires:
#   * agentmemory daemon (stopped + restarted by this script)
#   * 7zz (brew: sevenzip) or 7z on PATH
#   * BACKUP_PASSWORD set in ~/.secrets
#   * ~/Google Drive/Backups/dotfiles-x/ (Google Drive desktop app synced)
#
# Standalone: ./scripts/lib/backup/agentmemory.sh
# Via runner: ./scripts/lib/backup/backup.sh  (or: dots backup)

source "$(dirname "$0")/../bash_compat.sh"

set -euo pipefail

SCRIPT_NAME="agentmemory"

# --- config ---
# cron has a minimal PATH; add brew locations so `agentmemory`, `7zz`,
# `launchctl`/`systemctl` resolve on both macOS and Linux.
export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
REST_URL="${AGENTMEMORY_URL:-http://localhost:3111}"
DATA_DIR="$HOME/.agentmemory/data"
BACKUP_ROOT="$HOME/Google Drive/Backups/dotfiles-x"
BACKUP_DIR="$BACKUP_ROOT/agentmemory"
RETENTION_DAYS=30
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RESTART_TIMEOUT=30   # seconds to wait for daemon to come back up
STOP_TIMEOUT=60      # seconds to wait for `agentmemory stop` before giving up
LOCK_DIR="$HOME/.agentmemory/backup.lock.d"

# --- colors / logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
print_status()  { echo -e "${GREEN}[INFO]${NC} [$SCRIPT_NAME] $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} [$SCRIPT_NAME] $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} [$SCRIPT_NAME] $1"; }

# --- detect platform ---
OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="macos" ;;
    Linux)  PLATFORM="linux" ;;
    *)      print_error "Unsupported OS: $OS"; exit 1 ;;
esac

# --- resolve 7z binary (brew installs 7zz; some apt installs 7z) ---
if command -v 7zz >/dev/null 2>&1; then
    _7Z=7zz
elif command -v 7z >/dev/null 2>&1; then
    _7Z=7z
else
    print_error "7z not found. Install with: brew install sevenzip"
    exit 1
fi

# --- resolve agentmemory binary ---
if ! command -v agentmemory >/dev/null 2>&1; then
    print_error "agentmemory not on PATH. Install with: npm install -g @agentmemory/agentmemory"
    exit 1
fi

# --- load secrets (cron doesn't source the shell rc) ---
SECRETS_FILE="$HOME/.secrets"
if [[ ! -f "$SECRETS_FILE" ]]; then
    print_error "$SECRETS_FILE not found. Add BACKUP_PASSWORD to it (see .secrets.example)."
    exit 1
fi
# Source with -u temporarily disabled: the file may reference env vars that
# aren't set under cron's minimal environment. We only need BACKUP_PASSWORD.
# shellcheck source=/dev/null
set +u
source "$SECRETS_FILE"
set -u

if [[ -z "${BACKUP_PASSWORD:-}" ]]; then
    print_error "BACKUP_PASSWORD not set in $SECRETS_FILE"
    exit 1
fi

# --- preflight: Google Drive target exists ---
if [[ ! -d "$BACKUP_ROOT" ]]; then
    print_warning "Google Drive backup root not found: $BACKUP_ROOT"
    print_warning "Is Google Drive desktop app installed and synced? Skipping."
    exit 0
fi
mkdir -p "$BACKUP_DIR"

# --- preflight: data dir exists ---
if [[ ! -d "$DATA_DIR" ]]; then
    print_error "agentmemory data dir not found: $DATA_DIR"
    exit 1
fi

# --- lock: prevent overlapping runs (manual + cron, or cron + cron) ---
# mkdir is atomic on every local filesystem (POSIX guarantee) — no flock
# (missing on macOS base install), no extra deps. Stale-lock recovery via
# PID liveness check: if the holder process is dead, reclaim the lock.
acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo $$ > "$LOCK_DIR/pid"
        return 0
    fi
    local holder_pid
    holder_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [[ -n "$holder_pid" ]] && kill -0 "$holder_pid" 2>/dev/null; then
        print_error "Another backup is already running (pid $holder_pid). Exiting."
        exit 1
    fi
    print_warning "Stale lock (pid ${holder_pid:-unknown} not running). Reclaiming."
    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR" || { print_error "Failed to acquire lock. Exiting."; exit 1; }
    echo $$ > "$LOCK_DIR/pid"
}
mkdir -p "$(dirname "$LOCK_DIR")"
acquire_lock
# EXIT trap defined here (early) with ${VAR:-} defaults so it's safe under
# set -u even if the script exits before WORK_DIR/RESTART_NEEDED are set.
# The trap body is re-evaluated at fire time, so it reads current values.
trap 'rm -rf "$LOCK_DIR" "${WORK_DIR:-}"; if [[ "${RESTART_NEEDED:-false}" == true ]]; then restart_daemon || true; fi' EXIT

# --- helper: is the daemon currently running? ---
daemon_running() {
    curl -sf --max-time 3 "$REST_URL/agentmemory/health" >/dev/null 2>&1
}

# --- helper: wait for daemon to come up (after restart) ---
wait_for_daemon() {
    local elapsed=0
    while (( elapsed < RESTART_TIMEOUT )); do
        if daemon_running; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 1
}

# --- helper: restart the daemon via the service manager ---
restart_daemon() {
    case "$PLATFORM" in
        macos)
            launchctl kickstart -k "gui/$(id -u)/com.agentmemory.server" 2>/dev/null || true
            ;;
        linux)
            export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
            systemctl --user start agentmemory.service 2>/dev/null || true
            ;;
    esac
    wait_for_daemon
}

# --- temp staging dir + EXIT trap ---
# The trap guarantees two things on ANY exit path (including set -e aborts):
#   1. Plaintext temp data is wiped (never lands in Google Drive).
#   2. If we stopped the daemon and haven't restarted it yet, restart it now.
#      This covers a cp/7z failure BEFORE the inline restart — without it,
#      a copy failure would leave the daemon down forever (the restart was
#      sequential code that never ran).
WORK_DIR="$(mktemp -d)"
COPY_DIR="$WORK_DIR/agentmemory-data"
RESTART_NEEDED=false
HAD_FAILURE=false
# EXIT trap already set right after lock acquisition — it re-reads
# WORK_DIR/RESTART_NEEDED at fire time, no need to redefine it here.

# --- stop the daemon so the worker flushes the in-memory state to disk ---
if daemon_running; then
    RESTART_NEEDED=true
    print_status "Stopping agentmemory daemon (flushing state to disk)..."
    # timeout guards against `agentmemory stop` hanging indefinitely.
    if ! timeout "$STOP_TIMEOUT" agentmemory stop >/dev/null 2>&1; then
        print_error "\`agentmemory stop\` failed or timed out after ${STOP_TIMEOUT}s."
        print_error "Aborting. Daemon state is uncertain — investigate before retrying."
        exit 1
    fi

    # `agentmemory stop` awaits the worker's SIGTERM flush (5s) + engine (3s),
    # but give the filesystem a moment to settle before copying.
    sleep 2

    # Verify it's actually down. If still up, abort — a live copy would
    # miss the entire current session (the store is not written live).
    if daemon_running; then
        print_error "Daemon still running after \`agentmemory stop\`. Aborting to avoid a stale backup."
        print_error "Investigate: agentmemory stop (verbose) or check ~/.agentmemory/server-error.log"
        exit 1
    fi
    print_status "Daemon stopped. On-disk store is now consistent."
else
    print_warning "Daemon not running. Copying last-flushed on-disk state (may miss current session)."
fi

# --- copy the data store to a TEMP dir outside Google Drive ---
# Critical: plaintext memory data must NEVER land inside the Drive folder,
# where Google Drive would sync it to the cloud unencrypted. Only the .7z
# touches Drive.
print_status "Copying data store to temp staging area..."
cp -a "$DATA_DIR" "$COPY_DIR"
copy_size=$(du -sh "$COPY_DIR" | cut -f1)
print_status "Copied: $copy_size"

# --- restart the daemon ASAP to minimize downtime ---
# Encryption runs AFTER restart, so it adds no downtime. Clear
# RESTART_NEEDED so the EXIT trap won't double-restart.
if [[ "$RESTART_NEEDED" == true ]]; then
    print_status "Restarting agentmemory daemon..."
    if restart_daemon; then
        print_status "Daemon is back up."
    else
        print_error "Daemon did not come back up within ${RESTART_TIMEOUT}s!"
        print_error "Restart manually: \
macOS: launchctl kickstart -k gui/$(id -u)/com.agentmemory.server | \
Linux: systemctl --user start agentmemory.service"
        HAD_FAILURE=true
    fi
    RESTART_NEEDED=false
fi

# --- encrypt the staged copy into Google Drive ---
# Write to a .tmp file first, then atomically mv into place. A partial .7z
# in the Drive folder would sync to the cloud — the rename ensures only a
# complete archive ever appears there.
ARCHIVE_FILE="$BACKUP_DIR/agentmemory-$TIMESTAMP.7z"
ARCHIVE_TMP="$ARCHIVE_FILE.tmp"
print_status "Encrypting with 7z AES-256 (header encryption on)..."
# -p<PASSWORD>: password (visible in `ps` briefly; acceptable on single-user
#   box; password lives in ~/.secrets, chmod 600, never committed).
# -mhe=on: encrypt archive headers (filenames invisible without password).
# AES-256 is the default for .7z with -p; -mem=AES256 is invalid on modern
# 7zz (errors E_INVALIDARG). -mx=1 = fast (data is mostly incompressible).
"$_7Z" a -t7z -mhe=on -p"$BACKUP_PASSWORD" -mx=1 "$ARCHIVE_TMP" "$COPY_DIR" >/dev/null 2>&1
mv "$ARCHIVE_TMP" "$ARCHIVE_FILE"

archive_size=$(du -h "$ARCHIVE_FILE" | cut -f1)
print_status "Encrypted archive: $archive_size"
print_status "Saved to: $ARCHIVE_FILE"

# Staged plaintext is cleaned by the EXIT trap (rm -rf WORK_DIR).

# --- retention: delete archives older than RETENTION_DAYS ---
deleted=0
while IFS= read -r -d '' old; do
    rm -f "$old"
    ((deleted++)) || true
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'agentmemory-*.7z' -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)
if (( deleted > 0 )); then
    print_status "Retention: removed $deleted archive(s) older than $RETENTION_DAYS days"
fi

print_status "Done."

# Honest exit: a restart failure means the daemon may be down even though
# the backup archive itself is valid. Surface it so the runner/cron log
# reflects the problem (Claude review critical #1).
if [[ "$HAD_FAILURE" == true ]]; then
    exit 1
fi
