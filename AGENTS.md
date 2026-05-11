## Project Overview

This repository contains a unified dotfiles setup using symlinks to automate the setup of a personalized development environment across Unix and Unix-like systems (Fedora Linux, Deb-based Linux distros, macOS). The main goal is to provide a consistent configuration across multiple machines and platforms.

The project uses a symlink-based approach with automation scripts to achieve this:

*   **Symlink Management:** For managing dotfiles across multiple machines with simple symbolic links and backup capabilities.
*   **Homebrew (all platforms):** Primary package manager for dev tools on macOS and Linux. Required on all platforms.
*   **DNF/Flatpak (Fedora):** For system packages and GUI apps on Fedora Linux.
*   **apt (Debian-based):** For system packages and GUI apps on Debian-based distros.
*   **Zsh (Z Shell):** As the default shell, configured with plugins for improved productivity. Updated Bash also available.
*   **Git:** For version control, with a global gitignore and user configuration.
*   **Cross-platform Support:** OS-specific configurations with automatic platform detection via `scripts/lib/detect_distro.sh`.

## Key Files

*   `home/`: This directory mirrors the actual home folder structure. Files here are symlinked directly into `$HOME`:
    *   `.zshrc`: Zsh configuration with OS-specific logic and secure API key management.
    *   `.bashrc`: Bash configuration (symlinked on Linux distros; not macOS).
    *   `.gitconfig`: Git configuration with user details.
    *   `.gitignore_global`: Global gitignore rules for all projects.
    *   `.secrets.example`: Secrets management template for API keys and sensitive data.
    *   `.editorconfig`: Editor configuration for consistent coding style across tools.
    *   `.ssh/config`: SSH client configuration template with modern security practices.
    *   `.config/topgrade/topgrade.toml`: Topgrade update manager configuration.

*   `scripts/`: Setup scripts for package installation and system configuration:
    *   `install_macos.sh`: macOS package installation using Homebrew.
    *   `install_fedora.sh`: Fedora Linux package installation using DNF and Flatpak.
    *   `install_deb.sh`: Debian-based Linux package installation using apt.
    *   `configure_macos.sh`: macOS system settings and preferences.
    *   `configure_fedora.sh`: Fedora GNOME desktop configuration.
    *   `configure_deb.sh`: Debian-based desktop configuration.
    *   `crontab_macos.sh`: macOS crontab entry management.
    *   `crontab_fedora.sh`: Fedora crontab entry management.
    *   `crontab_deb.sh`: Debian-based crontab entry management.
    *   `lib/detect_distro.sh`: Distro detection helper (returns `macos`, `fedora`, or `deb`).
    *   `lib/brew_shared.sh`: Shared Homebrew install logic used across install scripts.

*   `dots.sh`: Main dotfile management script. After `install`, also symlinked to `~/.local/bin/dots` for global use as `dots <command>`.

*   `README.md`: End-user documentation and usage instructions.
*   `TODO.md`: Planned improvements and issue tracking.
*   `CLAUDE.md`: Claude Code agent instructions (mirrors this file with additional project context).
*   `GEMINI.md`: Gemini agent instructions.

## Building and Running

### Quick Setup (New Machine)

```bash
# Clone the repository
git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
cd ~/.dotfiles

# Symlinks only
./dots.sh install

# Full machine setup (symlinks + packages + crontab)
./dots.sh install --packages --crontab

# Reload shell configuration
exec zsh

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
    ./scripts/install_fedora.sh
    ./scripts/configure_fedora.sh

    # Debian-based
    ./scripts/install_deb.sh
    ./scripts/configure_deb.sh
    ```

### dots Command Reference

After `install`, `dots` is available globally via `~/.local/bin/dots`.

```bash
dots install                             # Install dotfiles (symlinks only)
dots install --packages                  # Also install system packages
dots install --crontab                   # Also install crontab entries
dots install --packages --crontab        # Full new machine setup
dots cleanup                             # Remove existing symlinks
dots status                              # Check current status of all dotfiles
dots sync                                # Pull + push + reinstall dotfiles
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

**Aliases:** `setup`=`install`, `clean`=`cleanup`, `st`=`status`, `s`=`sync`, `r`=`restore`, `log`=`history`, `check`=`health`

### Files Managed by dots

| Symlink in `$HOME`                  | Source in `home/`                        | Notes                      |
|-------------------------------------|------------------------------------------|----------------------------|
| `~/.zshrc`                          | `.zshrc`                                 | All platforms               |
| `~/.bashrc`                         | `.bashrc`                                | Linux only (not macOS)      |
| `~/.gitconfig`                      | `.gitconfig`                             | All platforms               |
| `~/.gitignore_global`               | `.gitignore_global`                      | All platforms               |
| `~/.secrets.example`                | `.secrets.example`                       | All platforms               |
| `~/.editorconfig`                   | `.editorconfig`                          | All platforms               |
| `~/.ssh/config`                     | `.ssh/config`                            | All platforms               |
| `~/.config/topgrade/topgrade.toml`  | `.config/topgrade/topgrade.toml`         | All platforms               |
| `~/.local/bin/dots`                 | `dots.sh`                                | Global `dots` command       |

`~/.secrets` is created automatically from `.secrets.example` on first install (not a symlink; stays local).

## Development Conventions

*   **Adding new dotfiles:** Add the file to `home/` using its final filename relative to `$HOME` (e.g., `.myconfig`). Then add a `"source:target"` entry to the `dotfiles` array in `dots.sh` and a matching entry to the `cleanup_symlinks` function.
*   **Adding new packages:** Add `brew install` / `brew install --cask` lines to `install_macos.sh`, or the equivalent `dnf install` / `apt install` lines to `install_fedora.sh` / `install_deb.sh`.
*   **Adding crontab entries:** Edit the relevant `crontab_<platform>.sh` script.
*   **Customizing settings:** `configure_macos.sh` uses `defaults write` commands; `configure_fedora.sh` and `configure_deb.sh` use `gsettings`/`dconf` commands.
*   **Distro detection:** Import `scripts/lib/detect_distro.sh` and call `detect_distro` to get `macos`, `fedora`, or `deb`. Do not replicate detection logic elsewhere.
*   **Shared Homebrew logic:** Shared install helpers live in `scripts/lib/brew_shared.sh`. Extend it instead of duplicating across platform scripts.
*   **Backup Management:** `dots.sh` automatically creates timestamped backups (`.backup.YYYYMMDD_HHMMSS`) of existing files before creating symlinks.
*   **Bash requirement:** `dots.sh` requires Bash 5.x. On macOS with the system Bash (3.x), it auto-detects and re-execs with Homebrew Bash, installing it if needed.
