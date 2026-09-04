#!/usr/bin/env bash
set -euo pipefail

# Nightly mirror of ~/Dev to the NAS.
# Files live in dotfiles-x; installed as a systemd --user unit via
# `dots install` + one-time `systemctl --user enable --now dev-backup.timer`
# (03:00, Persistent=true; enable per machine that should back up).
# Endpoint values are machine-local, never committed. Set in ~/.secrets:
#   DEV_BACKUP_NAS   ssh alias of the NAS
#   DEV_BACKUP_SHARE share that receives the mirror
# Destination is a per-host folder on the NAS: <share>/$(hostname -s)/dev.
# Only deltas cross the wire; --delete makes the NAS match this machine.
# Excludes regenerable build outputs and caches (see EXCLUDES).

SRC="$HOME/Dev/"

# Fail closed: without the endpoint values there is nothing safe to sync.
# shellcheck source=/dev/null
if [[ -r "$HOME/.secrets" ]]; then
    source "$HOME/.secrets"
fi
NAS="${DEV_BACKUP_NAS:-}"
SHARE="${DEV_BACKUP_SHARE:-}"
if [[ -z "$NAS" || -z "$SHARE" ]]; then
    echo "dev-backup: set DEV_BACKUP_NAS and DEV_BACKUP_SHARE in ~/.secrets" >&2
    exit 1
fi

DEST="/mnt/user/$SHARE/$(hostname -s)/dev"

# Bail out early (last night's copy stays intact) if the NAS is unreachable.
ssh -o ConnectTimeout=10 -o BatchMode=yes "$NAS" true
# SC2029: DEST expansion client-side is intended (path built here, used there).
# shellcheck disable=SC2029
ssh "$NAS" "mkdir -p '$DEST'"

# Regenerable trees: rebuild via package manager, compiler, or tool index.
# Receiver-side files matching these are also protected from --delete.
EXCLUDES=(
  # version control + code indexes (clone again)
  .git/ .codegraph/

  # node / JS / TS
  node_modules/ .next/ .nuxt/ .svelte-kit/ .astro/ .turbo/
  .parcel-cache/ .yarn/cache/ .eslintcache coverage/ .nyc_output/

  # python
  __pycache__/ .venv/ venv/ .pytest_cache/ .mypy_cache/ .ruff_cache/
  .tox/ .nox/ *.egg-info/

  # rust / go / general build outputs
  target/ bin/ build/ dist/ out/ obj/ zig-cache/

  # php / terraform / misc caches
  vendor/ .terraform/ .cache/ .DS_Store *.swp
)

args=(--archive --delete --partial --info=stats2)
for pattern in "${EXCLUDES[@]}"; do
  args+=(--exclude="$pattern")
done

exec rsync "${args[@]}" "$SRC" "$NAS:$DEST/"
