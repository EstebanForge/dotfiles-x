#!/usr/bin/env bash

# agentmemory backup: hot-export the full memory database via the REST API,
# encrypt with 7z AES-256, and drop the archive into Google Drive.
#
# Why hot export (not a file copy of ~/.agentmemory/data): the /export
# endpoint reads through the RUNNING engine, reflecting the true in-memory
# state. Cold file copies can be stale if the worker hasn't flushed indexes
# to disk (historical bug #843, fixed in the 0.9.27 publish).
#
# Why 7z not zip: macOS `zip -e` uses ZipCrypto (broken via known-plaintext
# attack). .7z format uses AES-256 by default with -p. -mhe=on also encrypts
# the archive headers (filenames), so the contents are opaque without the
# password.
#
# Requires:
#   * agentmemory daemon running (localhost:3111)
#   * 7zz (brew: sevenzip) or 7z on PATH
#   * BACKUP_PASSWORD set in ~/.secrets (shared across all backup scripts)
#   * ~/Google Drive/Backups/dotfiles-x/ (Google Drive desktop app synced)
#
# Standalone: ./scripts/lib/backup/agentmemory.sh
# Via runner: ./scripts/lib/backup/backup.sh

source "$(dirname "$0")/../bash_compat.sh"

set -euo pipefail

SCRIPT_NAME="agentmemory"

# --- config ---
REST_URL="${AGENTMEMORY_URL:-http://localhost:3111}"
BACKUP_ROOT="$HOME/Google Drive/Backups/dotfiles-x"
BACKUP_DIR="$BACKUP_ROOT/agentmemory"
RETENTION_DAYS=30
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# --- colors / logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
print_status()  { echo -e "${GREEN}[INFO]${NC} [$SCRIPT_NAME] $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} [$SCRIPT_NAME] $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} [$SCRIPT_NAME] $1"; }

# --- resolve 7z binary (brew installs 7zz; some apt installs 7z) ---
if command -v 7zz >/dev/null 2>&1; then
    _7Z=7zz
elif command -v 7z >/dev/null 2>&1; then
    _7Z=7z
else
    print_error "7z not found. Install with: brew install sevenzip"
    exit 1
fi

# --- load secrets (cron doesn't source the shell rc) ---
SECRETS_FILE="$HOME/.secrets"
if [[ ! -f "$SECRETS_FILE" ]]; then
    print_error "$SECRETS_FILE not found. Add BACKUP_PASSWORD to it (see .secrets.example)."
    exit 1
fi
# Source the user's secrets file with -u temporarily disabled: the file may
# reference env vars that aren't set under cron's minimal environment, and
# those are the shell rc's concern, not ours. We only need BACKUP_PASSWORD.
# shellcheck source=/dev/null
set +u
source "$SECRETS_FILE"
set -u

# Load agentmemory's own .env so AGENTMEMORY_SECRET (if set) is picked up
# for bearer auth. The file uses KEY=value syntax (no export), harmless to
# source. Non-fatal if absent.
AM_ENV="$HOME/.agentmemory/.env"
# shellcheck source=/dev/null
set +u
[[ -f "$AM_ENV" ]] && source "$AM_ENV"
set -u

if [[ -z "${BACKUP_PASSWORD:-}" ]]; then
    print_error "BACKUP_PASSWORD not set in ~/.secrets"
    exit 1
fi

# --- preflight: daemon health ---
AUTH_HEADER=()
if [[ -n "${AGENTMEMORY_SECRET:-}" ]]; then
    AUTH_HEADER=(-H "Authorization: Bearer $AGENTMEMORY_SECRET")
fi

if ! curl -sf --max-time 5 "${AUTH_HEADER[@]}" "$REST_URL/agentmemory/health" >/dev/null 2>&1; then
    print_error "agentmemory daemon not reachable at $REST_URL"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        print_error "Start it: launchctl kickstart -k gui/$(id -u)/com.agentmemory.server"
    else
        print_error "Start it: systemctl --user start agentmemory.service"
    fi
    exit 1
fi

# --- ensure Google Drive target exists ---
if [[ ! -d "$BACKUP_ROOT" ]]; then
    print_warning "Google Drive backup root not found: $BACKUP_ROOT"
    print_warning "Is Google Drive desktop app installed and synced? Skipping."
    exit 0
fi
mkdir -p "$BACKUP_DIR"

# --- hot export to a TEMP dir outside Google Drive ---
# Critical: the plaintext JSON contains client source/paths/secrets. It must
# NEVER land inside the Drive folder, where Google Drive would sync it to the
# cloud unencrypted before we can delete it. Only the .7z touches Drive.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
EXPORT_FILE="$WORK_DIR/agentmemory-export-$TIMESTAMP.json"
ARCHIVE_FILE="$BACKUP_DIR/agentmemory-$TIMESTAMP.7z"

print_status "Exporting memory database from $REST_URL ..."
# Single-shot export. The API supports pagination (maxSessions+offset) for
# very large corpora; revisit with paged merge if this times out.
if ! curl -sf --max-time 600 "${AUTH_HEADER[@]}" "$REST_URL/agentmemory/export" -o "$EXPORT_FILE"; then
    print_error "Export failed. Check daemon logs: ~/.agentmemory/server-error.log"
    exit 1
fi

export_size=$(du -h "$EXPORT_FILE" | cut -f1)
print_status "Exported: $export_size"

# --- encrypt ---
print_status "Encrypting with 7z AES-256 (header encryption on)..."
# -p<PASSWORD>: password via argv (visible in `ps` for the command duration;
#   acceptable on a single-user box; the password lives in ~/.secrets, chmod
#   600, never committed). Do NOT log this command.
# -mhe=on: encrypt archive headers (filenames invisible without password).
# AES-256 is the default for .7z with -p; no -mem switch needed (and
# -mem=AES256 is invalid on modern 7zz, errors E_INVALIDARG).
"$_7Z" a -t7z -mhe=on -p"$BACKUP_PASSWORD" -mx=1 "$ARCHIVE_FILE" "$EXPORT_FILE" >/dev/null 2>&1

archive_size=$(du -h "$ARCHIVE_FILE" | cut -f1)
print_status "Encrypted archive: $archive_size"
print_status "Saved to: $ARCHIVE_FILE"

# Plaintext export is cleaned by the EXIT trap (rm -rf WORK_DIR).

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
