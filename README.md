# Cross-Platform Dotfiles

Unified dotfiles and system configuration for macOS, Fedora, and Debian-based Linux.

## Features

* **Cross-Platform**: Tailored setups for macOS (zsh), Fedora, and Debian-based Linux (bash).
* **Symlink Management**: Automatic symbolic link creation with safe backups of existing configs.
* **Secrets Isolation**: Git-safe local secrets template (`~/.secrets`) sourced automatically by your shell.
* **Distro Detection & Provisioning**: Auto-detects platform to install native packages and configure system preferences.
* **Background Services**: The [agentmemory](https://github.com/rohitg00/agentmemory) memory engine is installed globally via npm and auto-launched in the background on login (LaunchAgent on macOS, systemd user unit on Linux).

## Quick Start

```bash
git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
cd ~/.dotfiles

# Run setup (creates symlinks, backs up existing files)
./dots.sh install

# Full setup: symlinks + packages + crontab + system config
# (--configure wires the agentmemory background service among other things)
./dots.sh install --packages --crontab --configure
```

Once installed, use the global `dots` command to manage symlinks, packages, backups, and crontabs. Run `dots help` for all commands.

## Secrets Management

Copy `home/.secrets.example` to `~/.secrets` to store API keys and machine-local variables (e.g., `SANDBOX_IP`). It is sourced by both `~/.bashrc` and `~/.zshrc` and is excluded from git.

```bash
cp home/.secrets.example ~/.secrets
chmod 600 ~/.secrets
nano ~/.secrets
```

## Structure

* **`home/`**: Files symlinked to `$HOME` (e.g., `.bashrc`, `.zshrc`, `.gitconfig`, `.config/`)
* **`scripts/`**: Distro-specific package installation (`install_*`) and system configurations (`configure_*`)
* **`dots.sh`**: The main symlink and utility management engine

## License

MIT - see [LICENSE](LICENSE)


