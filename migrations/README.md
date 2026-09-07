# Migrations

One-time transitions for machines carrying older state. Never add a one-time
cleanup inside `dots.sh` install code just because it is idempotent: fresh
machines have no legacy state, so they should skip it entirely. A migration
runs once per host and is then never executed again.

## Convention

- File name: `YYYYMMDDNNNN_verb_what.sh` (UTC date, zero-padded sequence,
  e.g. `202609100001_remove_retired_launchd_plist.sh`). Names sort
  chronologically; the sequence disambiguates same-day migrations.
- Each script: `#!/usr/bin/env bash`, `set -euo pipefail`, and a one-line
  comment stating what legacy state it removes and why.
- `dots migrate` (also run automatically at the end of `dots install`)
  executes pending scripts once per host. Applied names are recorded in
  `~/.local/state/dotfiles-x/migrations`. A failure stops the run and leaves
  the script unapplied, so the next run retries it.
