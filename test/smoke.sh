#!/usr/bin/env bash
# Smoke test for dots.sh: install, idempotence, status, migrate, cleanup.
# All writes land in a mktemp sandbox HOME; the real $HOME is never touched.
# Run: test/smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS="$SCRIPT_DIR/../dots.sh"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/dots-smoke.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
SB_HOME="$SANDBOX/home"
SB_MIGRATIONS="$SANDBOX/migrations"
mkdir -p "$SB_HOME" "$SB_MIGRATIONS"

run_dots() {
    HOME="$SB_HOME" DOTS_MIGRATIONS_DIR="$SB_MIGRATIONS" bash "$DOTS" "$@"
}

# 1. install creates the expected symlinks, secrets file, and dots command.
run_dots install > "$SANDBOX/install.log" 2>&1 || fail "install exited non-zero"
[[ -L "$SB_HOME/AGENTS.md" ]] || fail "AGENTS.md is not a symlink"
[[ "$(readlink "$SB_HOME/AGENTS.md")" == "$REPO_DIR/home/AGENTS.md" ]] || fail "AGENTS.md has the wrong target"
[[ -f "$SB_HOME/.secrets" ]] || fail ".secrets was not created"
perms="$(stat -f '%Lp' "$SB_HOME/.secrets" 2>/dev/null || stat -c '%a' "$SB_HOME/.secrets")"
[[ "$perms" == "600" ]] || fail ".secrets perms are $perms, expected 600"
[[ -L "$SB_HOME/.local/bin/dots" ]] || fail ".local/bin/dots is not a symlink"
if [[ "$(uname)" == "Darwin" ]]; then
    [[ -L "$SB_HOME/.zshrc" ]] || fail ".zshrc is not a symlink (macOS)"
else
    [[ -L "$SB_HOME/.bashrc" ]] || fail ".bashrc is not a symlink (Linux)"
fi
pass "install: symlinks, secrets (600), dots command"

# 2. Second install is idempotent: no new .backup.* files appear.
backups_before="$(find "$SB_HOME" -name '*.backup.*' | wc -l | tr -d ' ')"
run_dots install > "$SANDBOX/install2.log" 2>&1 || fail "second install exited non-zero"
backups_after="$(find "$SB_HOME" -name '*.backup.*' | wc -l | tr -d ' ')"
[[ "$backups_before" == "$backups_after" ]] || fail "second install created new .backup.* files (not idempotent)"
pass "install twice: idempotent, no new backups"

# 3. status passes in a fully-linked sandbox.
run_dots status > "$SANDBOX/status.log" 2>&1 || fail "status exited non-zero"
pass "status: all links correct"

# 4. Migrations run once each; the second run skips them.
# shellcheck disable=SC2016  # heredoc is unquoted on purpose: $SANDBOX must expand now
cat > "$SB_MIGRATIONS/202601010001_touch_marker.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'applied\n' >> "$SANDBOX/marker"
EOF
run_dots migrate > "$SANDBOX/migrate1.log" 2>&1 || fail "migrate exited non-zero"
[[ "$(cat "$SANDBOX/marker")" == "applied" ]] || fail "migration did not run"
state_file="$SB_HOME/.local/state/dotfiles-x/migrations"
grep -qxF "202601010001_touch_marker.sh" "$state_file" || fail "migration not recorded in state file"
run_dots migrate > "$SANDBOX/migrate2.log" 2>&1 || fail "second migrate exited non-zero"
[[ "$(wc -l < "$SANDBOX/marker" | tr -d ' ')" == "1" ]] || fail "migration ran twice"
pass "migrate: runs once per host, second run skips"

# 5. A failing migration stops the run and stays unapplied.
cat > "$SB_MIGRATIONS/202601010002_always_fails.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 3
EOF
if run_dots migrate > "$SANDBOX/migrate3.log" 2>&1; then
    fail "failing migration did not stop migrate"
fi
if grep -qxF "202601010002_always_fails.sh" "$state_file"; then
    fail "failed migration was marked applied"
fi
pass "migrate: failure stops run, script left unapplied"
rm "$SB_MIGRATIONS/202601010002_always_fails.sh"

# 6. cleanup removes symlinks but preserves local files (.secrets).
printf 'sentinel\n' > "$SB_HOME/.secrets"
run_dots cleanup > "$SANDBOX/cleanup.log" 2>&1 || fail "cleanup exited non-zero"
[[ ! -e "$SB_HOME/AGENTS.md" ]] || fail "cleanup left AGENTS.md in place"
[[ "$(cat "$SB_HOME/.secrets")" == "sentinel" ]] || fail "cleanup touched local .secrets"
pass "cleanup: symlinks removed, local files preserved"

# 7. Reinstall after cleanup relinks and still preserves local .secrets.
run_dots install > "$SANDBOX/install3.log" 2>&1 || fail "reinstall after cleanup exited non-zero"
[[ -L "$SB_HOME/AGENTS.md" ]] || fail "reinstall did not relink AGENTS.md"
[[ "$(cat "$SB_HOME/.secrets")" == "sentinel" ]] || fail "reinstall overwrote local .secrets"
pass "reinstall after cleanup: relinked, .secrets preserved"

echo ""
echo "All smoke tests passed."
