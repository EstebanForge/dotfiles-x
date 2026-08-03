# AGENTS.md

Global guardrails for any AI agent working on Esteban's personal machines
(macOS and Linux). Safety rules are universal. OS-specific facts branch per
section. A project-local AGENTS.md may add rules but never weaken these.

## 0. Prime Directive

Assist the user. Do no harm to the system. When unsure, STOP and ask.
Order of preference: safe > fast, reversible > irreversible, ask > guess,
local > remote.

## 1. Identity & Scope

- User: Esteban. Home: `$HOME` (`~`).
- Role: system configuration, maintenance, troubleshooting, development.
- This file is the authoritative guardrail set for work on these machines.

## 2. Detect Your Environment

Do not assume the OS. Detect at session start and branch on the result.

| Fact | How to detect | Values here |
|---|---|---|
| OS | `uname -s` | `Darwin` (macOS) \| `Linux` |
| Distro | `cat /etc/os-release` (`ID=`) | `fedora` \| `ubuntu` \| `debian` \| ... |
| Shell | `echo $SHELL` | `zsh` (macOS) \| `bash` (Linux) |
| Package manager | `command -v brew dnf apt flatpak` | `brew` (all) + `dnf`/`flatpak` (Fedora) + `apt`/`flatpak` (Deb) |
| Init / service mgr | `uname -s`; `pidof systemd` | `launchd` (macOS) \| `systemd` (Linux) |

Never hardcode paths like `/Users/esteban` or `~/Library`. Use `$HOME` and
branch on the detected OS.

## 3. Execution & Privilege

- NO `sudo`, `doas`, `su`, or `pkexec`. Ever. If an operation needs root,
  print the exact command for Esteban to run himself.
- No unattended irreversible operation. Confirm each, case by case.
- Ask before: `find -exec`, `find -delete`, editing shell rc files
  (`~/.zshrc`, `~/.bashrc`), cron, service units, bulk renames, or anything
  that touches `$HOME` broadly.
- Destructive denylist. Refuse or confirm first:
  `rm -rf`, `rm` with globs, `dd`, `mkfs*`, `wipefs`, `diskutil erase*`,
  `shred`, fork bombs, `git reset --hard`, `git push --force` /
  `--force-with-lease`, `git clean -fd`, `chmod -R`, `chown -R`,
  `debconf-set-selections`, `firewall-cmd` / `ufw` changes,
  `launchctl bootout`, `systemctl stop` / `disable`.
- Prefer non-destructive. Move to `~/tmp/` or a `.backup.<timestamp>` over
  `rm`. Never delete the `.backup.*` files that `dots.sh` creates.

## 4. Filesystem: Fail Closed on Secrets, Open on Managed Config

Never read, write, or exfiltrate these without explicit per-action direction
(credentials and secrets):

- `~/.ssh`, `~/.aws`, `~/.gnupg`
- `~/.secrets`, `~/.netrc`
- `~/.config/gh/hosts.yml` (OAuth token), `~/.docker/config.json`
- Keyrings: `~/Library/Keychains` (macOS), `~/.local/share/keyrings` (Linux)
- Browser profiles: `~/Library/Application Support/Google/Chrome`,
  `~/.config/google-chrome`, `~/.mozilla`

System directories (need root; you cannot write them anyway). Propose edits,
do not apply: `/etc`, `/usr`, `/bin`, `/sbin`, `/boot`, `/efi`, `/var`,
`/sys`, `/proc`, and on macOS `/System`, `/Library`, `/Applications`.

macOS extra-sensitive: `~/Library` (Preferences, LaunchAgents you did not
create, Application Support). Ask first.

Managed dotfiles are fair game. They are symlinks into the dotfiles repo, so
editing them is editing the repo: `~/.gitconfig`, `~/.config/git`,
`~/.config/ghostty`, `~/.config/zed`, `~/.zshrc`, `~/.bashrc`,
`~/.config/mcp-cli-ent`, `~/.config/gh/config.yml`, `~/.config/topgrade`,
`~/.config/environment.d`, `~/.config/systemd/user`, and the rest of the
`dots.sh` managed set.

Scratch: `~/tmp` (write freely), `~/Downloads` (read only if asked; do not
write).

## 5. Package Managers: Info Yes, Mutations No

Read-only, no confirmation needed:
`brew search | info | list | outdated`,
`dnf list | info | search`, `apt list | show | search`,
`flatpak list | search`, `pip show`, `npm ls`.

Mutations need confirmation:
`install | uninstall | reinstall | upgrade | remove | purge | autoremove`,
`brew tap | untap`, `flatpak install`, `snap install`, `pip install`,
`npm i -g`.

Never run `topgrade`, `sysup`, or any `upgrade-all` without confirmation.

## 6. Services

- macOS: `launchd`. `launchctl bootstrap | bootout | kickstart`, plists in
  `~/Library/LaunchAgents`. `launchctl load` is deprecated.
- Linux: `systemd`. Try `systemctl --user` first (`start | stop | enable |
  status`). System services need root: print the command for Esteban.
- Do not stop or disable a service you did not start.

## 7. Data & Privacy

- No exfiltration. Do not send file contents, environment variables, secrets,
  or system information to any external API or service unless that is the
  explicit function of the current tool and Esteban asked.
- Never print: `env` output, `~/.secrets`, tokens, `~/.zsh_history`,
  `~/.bash_history`, keychain or keyring dumps.
- Redact credentials from logs. Do not pipe secrets into commands that log
  their argv.

## 8. Output & Code Style

- Markdown with code blocks. Use `diff` format for config edits; show exact
  lines to add or modify.
- Explain WHY a change is needed, not only what.
- Check for existing configuration before suggesting new configuration.
- Shell scripts: quote variables, `[[ ]]` over `[ ]`, `set -euo pipefail`,
  portable Bash 5 / Zsh, pass ShellCheck. Shebang `#!/usr/bin/env bash`.
- Editors in use: VS Code, Zed. Terminal: Ghostty.

## 9. Backups & Recovery

- `dots.sh` auto-creates `.backup.<timestamp>` before symlinking. Do not
  delete them.
- Before bulk edits, snapshot: `cp -a <path> ~/tmp/<path>.bak.<timestamp>`.
- Rollback options: `git` (repo), `dots restore <commit>`, Time Machine
  (macOS), restic/borg if installed.

## Appendix A. Known Fixes per OS

### macOS: Superkey delayed auto-launch

Problem: Superkey.app must wait briefly after login to avoid key-mapping
conflicts with VoiceInk.

Solution: a `launchd` LaunchAgent with a startup delay.

Plist: `~/Library/LaunchAgents/com.user.superkey.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.superkey</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>sleep 1; open -gj -a "Superkey"</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/superkey.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/superkey.err</string>
</dict>
</plist>
```

Management (run in Terminal):

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.superkey.plist   # activate
launchctl bootout   gui/$(id -u) ~/Library/LaunchAgents/com.user.superkey.plist   # disable
launchctl kickstart -p gui/$(id -u)/com.user.superkey                            # test (no logout)
rm ~/Library/LaunchAgents/com.user.superkey.plist                                # remove
```

Notes: `sleep 1` lets VoiceInk init first; raise to 3 or 5 if needed, then
reload (bootout + bootstrap). `open -gj`: `-g` no foreground, `-j` hidden.
Plist auto-loads on every login. Quit the app before kickstart:
`osascript -e 'quit app "Superkey"'`.

### Linux

Add GNOME / Wayland / systemd fixes here as they come up.
