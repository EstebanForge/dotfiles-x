# Repository Maintenance

Technical guidelines for extending and maintaining the dotfiles environment.

## Adding Dotfiles

To manage a new configuration file:

1. Place the source file under the [home/](../home/) directory.
2. Edit the `dotfiles` array in [dots.sh](../dots.sh) to include the mapping `"relative_source:relative_target"`.
3. Add the mapping to the `cleanup_symlinks` function in [dots.sh](../dots.sh).
4. Add the mapping to the platform branch of `show_status` in [dots.sh](../dots.sh) as well. `show_status` keeps its own copy of the list; skipping it leaves `dots status` and `dots health` blind to the file.
5. Run `./dots.sh install` to generate the symlink.

## Package Management

To modify installed packages:

* **Homebrew (macOS/Linux)**: Edit [scripts/lib/brew_shared.sh](../scripts/lib/brew_shared.sh).
* **Flatpak (Linux)**: Edit [scripts/lib/flatpak_shared.sh](../scripts/lib/flatpak_shared.sh).
* **System Packages**: Update the platform-specific scripts:
  * [scripts/install_macos.sh](../scripts/install_macos.sh)
  * [scripts/install_rpm.sh](../scripts/install_rpm.sh)
  * [scripts/install_deb.sh](../scripts/install_deb.sh)

## System Configuration & Crontab

* **Preferences**: Edit platform-specific configure scripts (e.g., [scripts/configure_macos.sh](../scripts/configure_macos.sh)).
* **Crontabs**: Edit [scripts/crontab.sh](../scripts/crontab.sh) (platform-specific behavior keyed off `detect_distro`).
* **Distro Detection**: Import [scripts/lib/detect_distro.sh](../scripts/lib/detect_distro.sh) and execute `detect_distro`. Do not duplicate lookup logic.

## Migrations

One-time transitions for machines carrying older state (removing retired
symlinks, converting a formerly-symlinked file to local ownership, cleaning up
a dropped package). They never belong inside idempotent install code: fresh
machines have no legacy state and should skip them entirely.

* Add a dated script under [migrations/](../migrations/) following the naming
  convention in [migrations/README.md](../migrations/README.md).
* `dots migrate` runs pending scripts once per host; `dots install` also
  applies them at the end. Applied names are recorded in
  `~/.local/state/dotfiles-x/migrations`.
* A failing migration stops the run unmarked; the next run retries it.

## Testing

[test/smoke.sh](../test/smoke.sh) verifies the core dots.sh lifecycle in a
sandbox `$HOME` (mktemp; the real home directory is never touched):

```bash
test/smoke.sh
```

Covers: install creates expected symlinks + `~/.secrets` (600) + the `dots`
command; a second install adds no `.backup.*` files (idempotence); `dots status`
passes when fully linked; migrations run exactly once and a failing migration
stops the run unapplied; cleanup removes symlinks but preserves local files;
reinstall after cleanup relinks without clobbering local content.

Also run `shellcheck` over changed shell scripts before committing (repo-wide
baseline already passes).

