# AGENTS.md

Global guardrails for any AI agent working on Esteban's personal machines (macOS and Linux). Safety rules are universal. OS-specific facts branch per section. A project-local AGENTS.md may add rules but MUST NOT weaken these.

## 0. Prime Directive

Assist the user. Do no harm to the system. When unsure, STOP and ask. Order of preference: safe > fast, reversible > irreversible, ask > guess, local > remote.

## 1. Identity & Scope

- User: Esteban. Home: `$HOME` (`~`).
- Linux machines only: manually installed apps live in `~/Apps` (one folder per app, e.g. `~/Apps/steel-browser`, `~/Apps/xtool`). Always put manually installed apps there.
- Role: system configuration, maintenance, troubleshooting, development.
- Machines: macOS workstation `ATTD-ZenX`, Linux workstation `ATTD-Zenless` (Fedora, runs the Docker stacks), secondary Linux laptop, and other client devices.

## 2. Detect Your Environment

macOS (`ATTD-ZenX`): zsh, launchd, brew. Linux (`ATTD-Zenless`, Linux laptops): bash, systemd, dnf/flatpak/apt. Detect OS with `uname -s` or distro detection, and specific machine with `hostname`. MUST NOT hardcode paths like `/Users/esteban` or `~/Library`; use `$HOME` and branch on the detected OS.

## 3. Execution & Privilege

- MUST NOT run `sudo`, `doas`, `su`, or `pkexec`. Ever. If an operation needs root, print the exact command for Esteban to run himself.
- MUST NOT perform unattended irreversible operations. Confirm each, case by case.
- MUST ask before: `find -exec`, `find -delete`, cron, service units, bulk renames, or anything that touches `$HOME` broadly. Managed dotfiles (see §4) are exempt.
- MUST confirm first: `rm -rf`, `rm` with globs, `git reset --hard`, `git push --force*`, `git clean -fd`, `chmod -R`, `chown -R`, `firewall-cmd`/`ufw` changes, `launchctl bootout`, `systemctl stop`/`disable`.
- MUST prefer non-destructive. Move to `$TMPDIR` or a `.backup.<timestamp>` over `rm`. MUST NOT delete the `.backup.*` files that `dots.sh` creates.

## 4. Filesystem: Fail Closed on Secrets, Open on Managed Config

MUST NOT read, write, or exfiltrate these without explicit per-action direction (credentials and secrets):

- `~/.ssh`, `~/.aws`, `~/.gnupg`
- `~/.secrets`, `~/.netrc`
- `~/.config/gh/hosts.yml` (OAuth token), `~/.docker/config.json`
- Keyrings: `~/Library/Keychains` (macOS), `~/.local/share/keyrings` (Linux)
- Browser profiles: `~/Library/Application Support/Google/Chrome`, `~/.config/google-chrome`, `~/.mozilla`

System directories (need root; you cannot write them anyway). Propose edits; MUST NOT apply: `/etc`, `/usr`, `/bin`, `/sbin`, `/boot`, `/efi`, `/var`, `/sys`, `/proc`, and on macOS `/System`, `/Library`, `/Applications`.

macOS extra-sensitive: `~/Library` (Preferences, LaunchAgents you did not create, Application Support). MUST ask first.

Managed dotfiles are fair game. They are symlinks into the dotfiles repo, so editing them is editing the repo: `~/.gitconfig`, `~/.config/git`, `~/.config/ghostty`, `~/.config/zed`, `~/.zshrc`, `~/.bashrc`, `~/.config/mcp-cli-ent`, `~/.config/gh/config.yml`, `~/.config/topgrade`, `~/.config/environment.d`, `~/.config/systemd/user`, and the rest of the `dots.sh` managed set.

Scratch: `mktemp -d` or `$TMPDIR` only. MUST NOT create tmp or scratch dirs anywhere in `$HOME`. `~/Downloads` (read only if asked; MUST NOT write).

## 5. Package Managers: Info Yes, Mutations No

Read-only, no confirmation needed: `brew search | info | list | outdated`, `dnf list | info | search`, `apt list | show | search`, `flatpak list | search`, `pip show`, `npm ls`.

Mutations need confirmation: `install | uninstall | reinstall | upgrade | remove | purge | autoremove`, `brew tap | untap`, `flatpak install`, `snap install`, `pip install`, `npm i -g`.

MUST NOT run `topgrade`, `sysup`, or any `upgrade-all` without confirmation.

## 6. Services

- macOS: `launchd`. `launchctl bootstrap | bootout | kickstart`, plists in `~/Library/LaunchAgents`. `launchctl load` is deprecated.
- Linux: `systemd`. Try `systemctl --user` first (`start | stop | enable | status`). System services need root: print the command for Esteban.
- MUST NOT stop or disable a service you did not start.

## 7. Data & Privacy

- No exfiltration. MUST NOT send file contents, environment variables, secrets, or system information to any external API or service unless that is the explicit function of the current tool and Esteban asked.
- MUST NOT print: `env` output, `~/.secrets`, tokens, `~/.zsh_history`, `~/.bash_history`, keychain or keyring dumps.
- MUST redact credentials from logs. MUST NOT pipe secrets into commands that log their argv.

## 8. Output & Code Style

- Markdown with code blocks. Use `diff` format for config edits; show exact lines to add or modify.
- Code comments should explain the "why", not the "what". The "why" doesn't go out of date, even if the "what" does.
- Keep code comments short. Delete any claim from a comment that is derivable from the code; keep only the WHY.
- MUST check for existing configuration before suggesting new configuration.
- Shell scripts: quote variables, `[[ ]]` over `[ ]`, `set -euo pipefail`, portable Bash 5 / Zsh, pass ShellCheck. Shebang `#!/usr/bin/env bash`.
- Editors in use: VS Code, Zed. Terminal: Ghostty.

## 9. Backups & Recovery

- `dots.sh` auto-creates `.backup.<timestamp>` before symlinking. MUST NOT delete them.
- Before bulk edits, snapshot: `cp -a <path> <path>.bak.<timestamp>` (in place, same convention as `dots.sh`).
- Rollback options: `git` (repo), `dots restore <commit>`, Time Machine (macOS), restic/borg if installed.

## Appendix A. Known Fixes per OS

Machine-specific fixes. Components live on the machine; some are not part of this repo. Gate on the detection command in each entry before applying a fix.

### macOS: Superkey delayed auto-launch

Problem: Superkey.app must wait briefly after login to avoid key-mapping conflicts with VoiceInk.

Solution: a `launchd` LaunchAgent runs `sleep 1; open -gj -a "Superkey"` at load. Plist: `~/Library/LaunchAgents/com.user.superkey.plist` (the file on disk is the source of truth; read it there).

Management (run in Terminal):

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.superkey.plist   # activate
launchctl bootout   gui/$(id -u) ~/Library/LaunchAgents/com.user.superkey.plist   # disable
launchctl kickstart -p gui/$(id -u)/com.user.superkey                            # test (no logout)
rm ~/Library/LaunchAgents/com.user.superkey.plist                                # remove
```

Notes: `sleep 1` lets VoiceInk init first; raise to 3 or 5 if needed, then reload (bootout + bootstrap). `open -gj`: `-g` no foreground, `-j` hidden. Plist auto-loads on every login. Quit the app before kickstart: `osascript -e 'quit app "Superkey"'`.

### macOS: zenless localhost tunnel (pf redirect)

Problem: `https://localhost` on a client machine (e.g. `ATTD-ZenX` or another laptop) serves a site stack running on the Linux machine `ATTD-Zenless` (ssh host alias `tunneless`). Two halves must both live: an ssh local forward (user-owned) and a pf port redirect (root-owned). The pf half dies silently when something flushes pf mid-session (the NordVPN privileged helper is the prime suspect; it lives in `/Library/PrivilegedHelperTools/`). After that, `tunnel up` still said "up" because it only checked the ssh half. Fixed: the `tunnel` function now proves the full chain via port 443 and prints the repair command on split state.

Components (machine-local, not symlinked by dots):

- ssh half: `ssh -fN tunneless` binds `127.0.0.1:8080`, `127.0.0.1:8443`, and `127.0.0.1:8025` (Mailpit UI) on the client machine, forwarding to ports 80/443/8025 on `ATTD-Zenless`. Host stanza lives in the ssh config managed by `~/.config/estebanforge/ssh-hosts.sh`. `tunnel` also discovers extra site ports from the stack's listeners on zenless (`ss -tlnp`, web-server process names, loopback binds, Caddy admin 2019 excluded) and appends them as `-L` flags on the same connection; `tunnel refresh` rebuilds when site ports drift, and `tunnel status` reports drift without touching anything.
- pf half: `/etc/pf.anchors/tunneless` redirects `lo0` 80 -> 8080 and 443 -> 8443. Loaded by `rdr-anchor`/`load anchor` lines in `/etc/pf.conf`.
- Boot loader: `/Library/LaunchDaemons/com.user.pf.plist` runs `pfctl -f /etc/pf.conf && pfctl -e` at load. Log: `/var/log/com.user.pf.log` (no timestamps).

Gate: `nc -z 127.0.0.1 443 && echo full-chain-ok`. Port 8443 answering while 443 refuses = pf half dead.

Repair (run in Terminal):

```bash
sudo pfctl -f /etc/pf.conf && sudo pfctl -e   # reload rules, ensure enabled
```

Self-heal: `tunnel up` repairs a reverted or misplaced tunneless setup in `/etc/pf.conf` (missing or out-of-order `rdr-anchor "tunneless"` / `load anchor` lines, e.g. after the macOS 27.0 upgrade on 2026-09-18): it strips and reinserts the lines in valid category order (pf requires translation rules above filtering), backs up to `pf.conf.bak.<timestamp>`, syntax-checks with `pfctl -nf`, then reloads. The bare command above remains for simple flushes.

Notes: pf loads cleanly at boot per the daemon log, so recurring deaths are mid-session flushes. If it dies again, correlate with NordVPN connect/disconnect times before blaming the boot daemon. Verify end to end: `curl -skI https://<site>.localhost/` must return 200 for a site the stack serves. `https://localhost/` and `127.0.0.1` refuse TLS by design (Caddy routes by SNI hostname and has no site block for them), so a handshake failure there is not a tunnel fault.

### Linux: Baluard credential vault and SSH agent

Baluard (`~/.local/bin/baluard`) is the credential manager on this machine: a git-native password manager with a daemon that serves the OpenSSH agent. Bitwarden and the old `bw-ssh` bridge are retired here; do not reach for `bw` or `bw-ssh` commands. The agent socket is `/run/user/1000/baluard/baluard-agent.sock`, and `~/.ssh/agent.sock` symlinks to it, so `ssh` and `git` find the agent automatically.

Gate: `baluard ssh status`. Daemon running + agent listening + vaults unlocked means the agent is fine; stop there. `ssh-add -l` answering `agent refused operation` means the vault is LOCKED, not broken. An ssh push failing with `Permission denied (publickey)` right after working pushes is almost always this — check the vault state before re-trying git.

Unlock is interactive with the master password and belongs to the human. Hand the command to Esteban to run in his terminal; agents MUST NOT handle the password or any session token:

```bash
baluard unlock          # Esteban runs this; prompt takes the master password
baluard ssh status      # re-check: "1 unlocked" means go
baluard agents policy   # agent credential-request policy (enabled + auto_approve here)
```

Notes:

- The agent refuses every operation while the vault is locked. Nothing needs restarting after unlock; the next ssh/git call just works.
- `baluard agents pending|approve|deny` is the human approver surface for agent credential requests, and `baluard agents revoke` kills every agent grant for the vault.
- Keys serve from the vault through the daemon; there is no separate load step after a reboot, only the unlock.
- Stanzas with vault-only keys (`.pub` on disk, private key in the agent) carry `IdentityAgent ~/.ssh/agent.sock` next to `IdentityFile` and `IdentitiesOnly yes`. The `IdentityAgent` line reaches the agent in non-interactive shells, where `~/.bashrc` was skipped and `SSH_AUTH_SOCK` is stale. A stanza missing the line fails with `no such identity` then `Permission denied (publickey)`: add the line. `IdentitiesOnly yes` stays safe, ssh matches the `.pub` file against the agent. Verify the agent holds a key: the fingerprint from `ssh-keygen -lf ~/.ssh/<name>.pub` appears in `ssh-add -l`.
- `IdentityFile` is a cumulative option: a `Host github.com` stanza plus a command-line `-i` pub file offers BOTH keys, config entry first, so a second key can silently authenticate as the first account. Deterministic per-repo routing for agent-only keys: a repo-local ssh config (`ssh -F <config>`) holding only the wanted `IdentityFile` + `IdentitiesOnly yes` + `IdentityAgent`, wired via `core.sshCommand`.

### Linux: tailscale serve owns 443 on the tailnet IP

Problem: Rootless-podman stacks publish `0.0.0.0:443`. `tailscale serve` binds 443 on `tailscale0`. A wildcard publish fails to start when any specific address already holds the port. Symptom: `rootlessport listen tcp 0.0.0.0:443: bind: address already in use` during stack start.

Solution (applied 2026-10-13): couch-pi (a local service on `127.0.0.1:8090`) is served on 48443 instead of 443: `tailscale serve --https=48443 --bg http://127.0.0.1:8090` (migrated from 8443 on 2026-10-26; 48443 is unassigned, above 1023, and below the ephemeral range). Tailnet URL: `https://<machine>.<tailnet>.ts.net:48443`. Keep serve off 443, so the stacks can keep publishing `0.0.0.0:443`. Revert only if the stacks move to loopback publishes first.

Gate: `ss -tln '( sport = :443 )'`. A listener on `100.100.10.10` (tailscale0) is `tailscaled`, not a stack. Port 443 on `127.0.0.1` or `0.0.0.0` belongs to the running stack nginx.

### Linux: agentmemory server (local instance)

Problem: agentmemory runs on this machine as a systemd --user service (migrated from Unraid `whitebox` on 2026-10-26; the whitebox container is stopped and retired). The iii engine heap-loads the whole state store, so RAM tracks store size and grows without maintenance. Deletions never shrink the persisted bm25 index shards; only an index rebuild does.

Solution (applied 2026-10-26): pruned 50k stale observations (engine RSS 3.97G to 1.16G, store 3.1G to 240M). Solution (applied 2026-11-15): dropped the hand-rolled engine launcher for the stock CLI compose flow after a CLI/engine version-skew crash loop (see Notes).

Components:

- Service: `~/.config/systemd/user/agentmemory.service` (repo-symlinked): ExecStart runs `iii compose --namespace agentmemory-3111 --up --file ~/.local/share/agentmemory/compose/worker-compose.yaml` in the foreground, so one tracked process owns the whole stack. Carries `MALLOC_ARENA_MAX=2`, `MemoryHigh=4G` / `MemoryMax=6G`, `Restart=on-failure`.
- Stack: the CLI (0.9.33) generates and manages the compose project: engine iii 0.25.1 plus containers state 0.22.22 (same `state_store.db` path as before), http 0.22.8 (REST 3111, viewer 3113) and the agentmemory worker itself. Project files live under `~/.local/share/agentmemory/compose/` and `compose-state/`.
- Weekly maintenance: `agentmemory-maint.timer` (Sun 04:00 +15m jitter, Persistent) runs `~/.local/bin/agentmemory-maint` (repo-symlinked, registered in `dots.sh`): eviction pass, then bm25 index rebuild (stop unit, move `state_store.db/mem%3Aindex*` aside, start, wait livez, sanity smart-search, delete stale shards only on success; auto-restore on failure).
- Evict cost trap: the real evict pass recovers each stale session individually; with `AGENTMEMORY_AUTO_COMPRESS=true` plus a provider key that is one LLM summarize per session. The script dry-runs first and skips the real pass when staleSessions > 200. Bulk catch-ups must be supervised.
- Lean env (`~/.agentmemory/.env`, mode 600): `AGENTMEMORY_AUDIT_RETENTION_MONTHS=9`, `AGENTMEMORY_CAPTURE_OUTPUT_MAX=3000`, `CONSOLIDATION_INTERVAL_MS=43200000`, `AGENTMEMORY_III_VERSION=0.25.1` (must track the CLI's engine pin). Keep `EMBEDDING_PROVIDER` unset (BM25-only; enabling embeddings grows RAM).
- Last-resort backup: whitebox's stopped agentmemory container still holds the pristine pre-migration store (the pre-prune data tar on whitebox was deleted 2026-10-26 once the pruned local store proved stable).

Management:

```bash
systemctl --user restart agentmemory          # ready again in ~20-30s
journalctl --user -u agentmemory -f           # stack log (engine + workers)
~/.local/bin/agentmemory-maint                # manual maintenance run
cat ~/.local/state/agentmemory/maint.log      # maintenance history
agentmemory status                            # health, counts, heap
curl -H "Authorization: Bearer $(cat ~/.agentmemory/secret)" \
  http://localhost:3111/agentmemory/health    # must return 200
```

Notes:

- Version coupling: the CLI pins iii via `III_PINNED_VERSION` (0.9.33 -> 0.25.1) and probes `state::list_keys` at boot; a stale engine never registers it and the unit crash-loops (2026-11-15: 118 restarts over ~5h after the weekly maintenance restart loaded the new CLI). `AGENTMEMORY_III_VERSION` in `.env` overrides the pin; bump it with every CLI update or delete it.
- iii 0.25.1 rejects legacy config.yaml worker blocks (`UNSUPPORTED_CONFIG_WORKERS`). Never reintroduce the old `~/.config/agentmemory/iii.yaml` worker list or the deleted `agentmemory-local` launcher (removed 2026-11-15).
- Stop the stack through `systemctl --user stop agentmemory`; a bare `agentmemory stop` exits cleanly and leaves the unit inactive.
- REST bearer secret lives in `~/.agentmemory/secret`; pi sessions get URL + secret via `~/.config/environment.d/agentmemory.conf`.
- `~/.config/systemd/user` and `~/.local/bin/agentmemory-maint` are symlinks into the dotfiles repo; edit through either path, it is the same file.
- After pruning observations, run a rebuild (or wait for the weekly timer): deletion alone does not lower RSS.
- Eviction thresholds are store-config, not env: key `eviction` in the config store (defaults stale 30d, lowImportance 90d with importance < 3, 10k obs/project cap).
