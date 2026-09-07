## Project Overview

This repository contains a unified dotfiles setup using symlinks to automate the setup of a personalized development environment across Unix and Unix-like systems (Fedora Linux, Deb-based Linux distros, macOS). The main goal is to provide a consistent configuration across multiple machines and platforms.

The project uses a symlink-based approach with automation scripts to achieve this:

*   **Symlink Management:** For managing dotfiles across multiple machines with simple symbolic links and backup capabilities.
*   **Homebrew (all platforms):** Primary package manager for dev tools on macOS and Linux. Required on all platforms.
*   **DNF/Flatpak (RPM):** For system packages and GUI apps on RPM-based Linux (Fedora, etc.).
*   **apt (Deb-based):** For system packages and GUI apps on Deb-based distros.
*   **Shell:** Zsh is the default shell on macOS (with plugins); Bash is the default shell on Linux.
*   **Git:** For version control, with a global gitignore and user configuration.
*   **Cross-platform Support:** OS-specific configurations with automatic platform detection via `scripts/lib/detect_distro.sh`.

## Key Files

*   `home/`: This directory mirrors the actual home folder structure. Files here are symlinked directly into `$HOME`:
    *   `.zshrc`: Zsh configuration (symlinked on macOS only).
    *   `.bashrc`: Bash configuration (symlinked on Linux only).
    *   `.config/environment.d/gnome-wayland.conf`: Per-user session environment for GNOME/Wayland (animation speed, Electron ozone hint; symlinked on Linux only).
    *   `AGENTS.md`: Global agent protocol read by coding agents at `~/AGENTS.md` (all platforms).
    *   `.gitconfig`: Git configuration with user details.
    *   `.config/git/ignore`: Global gitignore rules for all projects (canonical XDG path).
    *   `.secrets.example`: Secrets management template for API keys and sensitive data.
    *   `.editorconfig`: Editor configuration for consistent coding style across tools.
    *   `.hushlogin`: Empty flag file that silences the "Last login" banner on terminal launch.
    *   `.tmux.conf`: tmux terminal multiplexer configuration.
    *   `.config/topgrade/topgrade.toml`: Topgrade update manager configuration.
    *   `.config/ghostty/config`: Ghostty terminal configuration.
    *   `.config/zed/settings.json`: Zed editor configuration (theme, fonts, agent servers).
    *   `.config/mcp-cli-ent/mcp_servers.json`: MCP server registry (secrets kept as `${ENV_VAR}` refs resolved from `~/.secrets`).
    *   `.config/gh/config.yml`: GitHub CLI configuration.

*   `scripts/`: Setup scripts for package installation and system configuration:
    *   `install_macos.sh`: macOS package installation using Homebrew.
    *   `install_rpm.sh`: RPM-based Linux package installation using DNF and Flatpak.
    *   `install_deb.sh`: Deb-based Linux package installation using apt.
    *   `configure_macos.sh`: macOS system settings and preferences.
    *   `configure_rpm.sh`: RPM-based GNOME desktop configuration.
    *   `configure_deb.sh`: Deb-based desktop configuration.
    *   `crontab.sh`: Crontab entry management (all platforms; detects distro for cron service + topgrade path).
    *   `lib/detect_distro.sh`: Distro detection helper (returns `macos`, `rpm`, or `deb`).
    *   `lib/brew_shared.sh`: Shared Homebrew taps and formulae used by all platform install scripts.
    *   `lib/flatpak_shared.sh`: Shared Flatpak app list installed on all Linux platforms (RPM and deb).
    *   `lib/profile_picture.sh`: Shared Linux helper that sets the user profile picture (AccountsService icon + `~/.face`). Sourced by `configure_rpm.sh` and `configure_deb.sh`.
    *   `lib/agentmemory.sh`: Installs + enables the agentmemory engine as a host service (LaunchAgent on macOS, systemd user unit on Linux). The npm package itself is installed by `lib/npm_globals.sh`. Sourced by `configure_macos.sh`, `configure_rpm.sh`, and `configure_deb.sh`.
    *   `lib/bash_compat.sh`: Re-exec-with-Bash guard sourced by every script so they work when invoked from another shell (e.g. `zsh install_rpm.sh`).
    *   `lib/cli_installers.sh`: Curl-pipe-to-shell CLI installers (Antigravity, Claude Code, Codex, Bun, phpvm) with shared rc-file cleanup. Sourced by the platform `install_*.sh` scripts.
    *   `lib/fonts_shared.sh`: Shared Iosevka + SF Pro font install for Linux. Sourced by `install_rpm.sh` and `install_deb.sh`.
    *   `lib/themes_shared.sh`: Shared Flat Remix GNOME theme install for Linux.
    *   `lib/icons_reversal_shared.sh`: Shared Reversal icon theme install for Linux (color variant via `REVERSAL_COLOR`).
    *   `lib/ptyxis_palette.sh`: Ptyxis terminal palette installer (Linux).
    *   `lib/npm_globals.sh`: Global npm packages, per-package fault-isolated. Sourced by `install_macos.sh`, `install_rpm.sh`, and `install_deb.sh`.
    *   `lib/backup/`: Backup helpers (`backup.sh` runner plus per-target scripts); exposed as `dots backup`.
    *   `luks_tpm_enroll.sh`: LUKS2 to TPM2 enrollment for passwordless disk unlock (Linux; status/enroll/remove).
    *   `zenless_mount.sh`: Zenless NFS mountpoint self-heal daemon installer (macOS; `dots zenless-mount`).
    *   `wheeltani_autoscroll.sh`: Wayland middle-mouse-hold autoscroll setup (Fedora/Wayland; `dots wheeltani`).
    *   `debloat_services.sh`: Disables dead-weight services and removes the deprecated ABRT stack (Fedora).
    *   `hyperkey_keyd.sh`: Capslock-to-hyper modifier via keyd (Fedora).

*   `assets/`: Static binary assets committed to the repo. Currently holds `profile-picture.jpg` (Esteban's GitHub avatar), applied as the login/user picture by the configure scripts.

*   `dots.sh`: Main dotfile management script. After `install`, also symlinked to `~/.local/bin/dots` for global use as `dots <command>`.

*   `README.md`: End-user documentation and usage instructions.
*   `TODO.md`: Planned improvements and issue tracking.
*   `CLAUDE.md`: Symlink to this file (`AGENTS.md`). Claude Code reads it as its project instructions; not a separate document.
*   `GEMINI.md`: Symlink to this file (`AGENTS.md`). Antigravity CLI (Google's replacement for Gemini CLI) reads it the same way.
*   `docs/`: Additional repository documentation:
    *   `maintenance.md`: Technical guidelines for adding dotfiles, modifying packages, and custom preferences.
*   `migrations/`: Dated one-time cleanup scripts for machines carrying older state, run once per host by `dots migrate` (naming and rules in `migrations/README.md`).
*   `test/smoke.sh`: Sandbox smoke test for the `dots.sh` install/status/migrate/cleanup lifecycle (uses a mktemp `$HOME`; the real home directory is never touched).

## Building and Running

### Quick Setup (New Machine)

```bash
# Clone the repository
git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
cd ~/.dotfiles

# Symlinks only
./dots.sh install

# Full machine setup (symlinks + packages + crontab + system config)
./dots.sh install --packages --crontab --configure

# Reload shell configuration (macOS: zsh, Linux: bash)
exec zsh        # macOS
exec bash       # Linux

# Edit secrets with your actual API keys
vim ~/.secrets
```

### Manual Setup (Existing Machine)

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
    cd ~/.dotfiles
    ```

2.  **Install dotfiles:**
    ```bash
    ./dots.sh install
    ```

3.  **Set up your secrets:**
    ```bash
    # Automatically created by install; edit with actual values
    vim ~/.secrets
    ```

4.  **Optional: Install packages:**
    ```bash
    # macOS
    ./scripts/install_macos.sh
    ./scripts/configure_macos.sh

    # Fedora Linux
    ./scripts/install_rpm.sh
    ./scripts/configure_rpm.sh

    # Deb-based
    ./scripts/install_deb.sh
    ./scripts/configure_deb.sh
    ```

### dots Command Reference

After `install`, `dots` is available globally via `~/.local/bin/dots`.

```bash
dots install                             # Install dotfiles (symlinks only)
dots install --packages                  # Also install system packages
dots install --crontab                   # Also install crontab entries
dots install --configure                 # Also apply desktop + service config
# Full new machine setup (symlinks + packages + crontab + system config):
dots install --packages --crontab --configure
dots cleanup                             # Remove existing symlinks
dots migrate                             # Run pending one-time migrations (once per host)
dots status                              # Check current status of all dotfiles
dots sync                                # Pull + push + reinstall dotfiles
dots push                                # Commit local tracked changes and push to remote
dots backup [run|list]                   # Run backup scripts (agentmemory, etc.)
dots wheeltani                           # Wayland-Wheeltani autoscroll setup (Fedora/Wayland)
dots zenless-mount [action]              # NFS mountpoint self-heal daemon (macOS)
dots restore                             # Restore to latest commit
dots restore <commit>                    # Restore to specific commit
dots restore <commit> --force            # Skip confirmation prompt
dots history                             # Show recent git history (last 10 commits)
dots health                              # Comprehensive health check
dots crontab install                     # Install crontab entries
dots crontab show                        # Show current crontab entries
dots crontab remove                      # Remove all crontab entries
dots crontab backup                      # Backup existing crontab
dots crontab service                     # Check/start cron service (Linux only)
dots version                             # Show script version
dots help                                # Show help message
```

**Aliases:** `setup`=`install`, `clean`=`cleanup`, `st`=`status`, `s`=`sync`, `p`=`push`, `r`=`restore`, `log`=`history`, `check`=`health`

### Files Managed by dots

| Symlink in `$HOME`                  | Source in `home/`                        | Notes                      |
|-------------------------------------|------------------------------------------|----------------------------|
| `~/.zshrc`                          | `.zshrc`                                 | macOS only                  |
| `~/.zsh/prompt.zsh`                 | `.zsh/prompt.zsh`                        | macOS only (EstebanForgePrompt) |
| `~/.zsh/functions.zsh`              | `.zsh/functions.zsh`                     | macOS only (zsh helper functions) |
| `~/Library/LaunchAgents/com.user.copyfile-disable.plist` | `Library/LaunchAgents/com.user.copyfile-disable.plist` | macOS only (COPYFILE_DISABLE env for GUI-launched apps) |
| `~/.config/linearmouse/linearmouse.json` | `.config/linearmouse/linearmouse.json` | macOS only (mouse autoscroll) |
| `~/.bashrc`                         | `.bashrc`                                | Linux only                  |
| `~/.config/environment.d/gnome-wayland.conf` | `.config/environment.d/gnome-wayland.conf` | Linux only (GNOME/Wayland session env) |
| `~/.config/environment.d/freetype.conf` | `.config/environment.d/freetype.conf` | Linux only (FreeType stem darkening) |
| `~/.bash/plugins/ghost.plugin.sh` | `.bash/plugins/ghost.plugin.sh` | Linux only (Fish-style ghost text for Bash 5.x; loaded by `.bashrc` plugin loader) |
| `~/.bash/plugins/agentmemory.plugin.sh` | `.bash/plugins/agentmemory.plugin.sh` | Linux only (agentmemory CLI guard + `memconsolidate`; loaded by `.bashrc` plugin loader) |
| `~/.config/fontconfig/fonts.conf`      | `.config/fontconfig/fonts.conf`           | Linux only (fontconfig for non-GNOME apps) |
| `~/.config/systemd/user/agentmemory.service` | `.config/systemd/user/agentmemory.service` | Linux only (agentmemory engine user service; auto-launched on login) |
| `~/.local/bin/dev-backup.sh` | `.local/bin/dev-backup.sh` | Linux only (dev backup helper) |
| `~/.config/systemd/user/dev-backup.service` | `.config/systemd/user/dev-backup.service` | Linux only (dev backup user service) |
| `~/.config/systemd/user/dev-backup.timer` | `.config/systemd/user/dev-backup.timer` | Linux only (dev backup timer) |
| `~/.local/share/org.gnome.Ptyxis/palettes/*.palette` | `.local/share/org.gnome.Ptyxis/palettes/` | Linux only (4 Catppuccin Ptyxis palettes: Latte, Frappe, Macchiato, Mocha) |
| `~/AGENTS.md`                       | `AGENTS.md`                              | All platforms (agent protocol) |
| `~/.gitconfig`                      | `.gitconfig`                             | All platforms               |
| `~/.config/git/ignore`              | `.config/git/ignore`                     | All platforms               |
| `~/.secrets.example`                | `.secrets.example`                       | All platforms               |
| `~/.editorconfig`                   | `.editorconfig`                          | All platforms               |
| `~/.hushlogin`                      | `.hushlogin`                             | All platforms (silences login banner) |
| `~/.tmux.conf`                      | `.tmux.conf`                             | All platforms (tmux mouse scroll + extended-keys) |
| `~/.config/topgrade/topgrade.toml`  | `.config/topgrade/topgrade.toml`         | All platforms               |
| `~/.config/ghostty/config`          | `.config/ghostty/config`                 | All platforms               |
| `~/.config/zed/settings.json`       | `.config/zed/settings.json`              | All platforms               |
| `~/.config/mcp-cli-ent/mcp_servers.json` | `.config/mcp-cli-ent/mcp_servers.json` | All platforms          |
| `~/.config/gh/config.yml`           | `.config/gh/config.yml`                  | All platforms               |
| `~/.config/estebanforge/ssh-hosts.sh` | `.config/estebanforge/ssh-hosts.sh`  | All platforms (SSH host wrappers with Bitwarden agent pre-flight; sourced by `.zshrc` and `.bashrc`) |
| `~/.config/estebanforge/aliases.sh` | `.config/estebanforge/aliases.sh`    | All platforms (cross-shell aliases: ls family, cat, artisan, dot navigation) |
| `~/.config/estebanforge/env.sh` | `.config/estebanforge/env.sh`          | All platforms (cross-shell exports and PATH: EDITOR, composer, `~/.local/bin`, opencode, LM Studio, phpvm) |
| `~/.config/estebanforge/updaters.sh` | `.config/estebanforge/updaters.sh`  | All platforms (`sysup`, `sysup-full`, `dots-check` via the global `dots` command) |
| `~/.config/estebanforge/devtools.sh` | `.config/estebanforge/devtools.sh`  | All platforms (brew-based helpers: `brewup`, `phpv`) |
| `~/.local/bin/dots`                 | `dots.sh`                                | Global `dots` command       |

`~/.secrets` is created automatically from `.secrets.example` on first install (not a symlink; stays local). It holds both secrets and machine-local values (e.g. `SANDBOX_IP`).

`~/.config/gh/hosts.yml` is intentionally NOT symlinked or tracked. `gh auth login` rewrites it with an OAuth token at runtime, so it must stay a local file owned by gh (same rationale as `~/.secrets`). On install, `dots.sh` converts any pre-existing symlink to a real local file, preserving the current token when possible.

## Development Conventions

*   **Adding new dotfiles:** Add the file to `home/` using its final filename relative to `$HOME` (e.g., `.myconfig`). Then register it in THREE places in `dots.sh`: the `dotfiles` array in `setup_dotfiles`, the `cleanup_symlinks` function, and the platform branch of `show_status`. Skipping `show_status` makes `dots status` and `dots health` blind to the file.
*   **Adding new packages:** Add `brew install` / `brew install --cask` lines to `install_macos.sh`, or the equivalent `dnf install` / `apt install` lines to `install_rpm.sh` / `install_deb.sh`.
*   **Adding crontab entries:** Edit `scripts/crontab.sh` (platform-specific behavior is keyed off `detect_distro` at the top of the script).
*   **Customizing settings:** `configure_macos.sh` uses `defaults write` commands; `configure_rpm.sh` and `configure_deb.sh` use `gsettings`/`dconf` commands.
*   **Distro detection:** Import `scripts/lib/detect_distro.sh` and call `detect_distro` to get `macos`, `rpm`, or `deb`. Do not replicate detection logic elsewhere.
*   **Shared Homebrew logic:** Shared taps and formulae live in `scripts/lib/brew_shared.sh`. Extend it instead of duplicating across platform scripts.
*   **Shared Flatpak apps:** The full Linux Flatpak app list lives in `scripts/lib/flatpak_shared.sh`. Both `install_rpm.sh` and `install_deb.sh` source it. Add new Flatpak apps there, not in the individual install scripts.
*   **Profile picture:** `scripts/lib/profile_picture.sh` (`set_profile_picture_linux`) handles Linux (GNOME AccountsService + `~/.face`); `configure_macos.sh` embeds the image via `dsimport` (the only reliable macOS method). Both read `assets/profile-picture.jpg`. Replace that file to change the picture; keep it square JPEG for best results.
*   **agentmemory engine:** Installed as an npm global by `scripts/lib/npm_globals.sh`, then auto-launched in the background by `scripts/lib/agentmemory.sh` (LaunchAgent `com.agentmemory.server` on macOS, systemd user unit `agentmemory.service` on Linux). The macOS plist is rendered from `scripts/lib/com.agentmemory.server.plist.template` (the `__HOME__` placeholder is substituted at install time because launchd does not expand `~` or `$HOME`). On Linux the unit file is symlinked from `home/.config/systemd/user/agentmemory.service` (uses `%h`). Both shell rc files guard `agentmemory` so accidental manual starts from a project dir are redirected to the service manager.
*   **Backup Management:** `dots.sh` automatically creates timestamped backups (`.backup.YYYYMMDD_HHMMSS`) of existing files before creating symlinks.
*   **One-time cleanups:** Machines carrying older state get dated scripts in `migrations/` (`YYYYMMDDNNNN_verb_what.sh`), run once per host by `dots migrate`. Never bury one-time cleanup inside idempotent install code; see `migrations/README.md`.
*   **Testing:** `test/smoke.sh` exercises install, idempotence, status, migrate, cleanup, and reinstall in a sandbox `$HOME`. Run it plus `shellcheck` before committing shell changes.
*   **Bash requirement:** `dots.sh` requires Bash 5.x. On macOS with the system Bash (3.x), it auto-detects and re-execs with Homebrew Bash, installing it if needed.
