# Cross-Platform Dotfiles

This repository contains a unified dotfiles setup that works across Unix and Unix-like systems including macOS and Linux distributions (Fedora, Deb-based).

## Quick Start

### On a new machine:

```bash
# Clone the repository
git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
cd ~/.dotfiles

# Run the setup script to create symlinks
./dots.sh install

# Reload shell configuration (macOS: zsh, Linux: bash)
source ~/.zshrc    # macOS
source ~/.bashrc   # Linux
```

### On existing machine:

```bash
# Clone the repository
git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
cd ~/.dotfiles

# Run the setup script (automatically backs up existing files)
./dots.sh install

# Reload shell configuration (macOS: zsh, Linux: bash)
source ~/.zshrc    # macOS
source ~/.bashrc   # Linux
```

### Setup Script Commands

The setup script provides several commands:

```bash
./dots.sh install    # Install dotfiles (create symlinks)
./dots.sh status     # Check current status of dotfiles
./dots.sh cleanup    # Remove existing symlinks
./dots.sh help       # Show help information
```

### Secrets Management

The dotfiles include a secrets management system:

1. **Template file**: `home/.secrets.example` - Contains example secrets and documentation
2. **Your secrets**: `~/.secrets` - Your actual secrets (never committed to git)
3. **Auto-loading**: Secrets are automatically loaded when shell starts

For non-secret machine-specific values (paths, IPs like `SANDBOX_IP`), use `home/.zshrc.local.example` instead. Copy it to `~/.zshrc.local` and override per machine. It is sourced by `~/.zshrc` after `~/.secrets`.

**Setup your secrets:**

```bash
# After running ./dots.sh install, edit your secrets:
nano ~/.secrets

# Set secure permissions:
chmod 600 ~/.secrets
```

**Using secrets in scripts:**

```bash
#!/bin/bash
# Source secrets to access environment variables
source ~/.secrets

# Use your API keys
curl -H "Authorization: Bearer $ANTHROPIC_API_KEY" https://api.anthropic.com/v1/messages
```

## Repository Structure

```
dotfiles-x/
├── home/                           # Your dotfiles
│   ├── .zshrc                   # Zsh configuration (macOS)
│   ├── .zsh/prompt.zsh          # EstebanForgePrompt theme (macOS)
│   ├── .bashrc                  # Bash configuration (Linux)
│   ├── .gitconfig               # Git configuration
│   ├── .gitignore_global        # Global gitignore
│   ├── .secrets.example         # Secrets template (copy to ~/.secrets)
│   └── .zshrc.local.example     # Machine-local config template (copy to ~/.zshrc.local)
├── scripts/                        # Optional setup scripts
│   ├── install_macos.sh            # macOS package installation
│   ├── install_rpm.sh              # Fedora package installation
│   ├── install_deb.sh              # Deb-based package installation
│   ├── configure_macos.sh          # macOS system settings
│   ├── configure_rpm.sh            # Fedora GNOME settings
│   ├── configure_deb.sh            # Deb-based GNOME settings
│   ├── crontab_macos.sh            # macOS crontab management
│   ├── crontab_rpm.sh              # Fedora crontab management
│   ├── crontab_deb.sh              # Deb-based crontab management
│   └── lib/                        # Shared libraries
│       ├── brew_shared.sh          # Shared Homebrew packages
│       └── detect_distro.sh        # Distro detection helper
├── dots.sh                        # Setup script for symlinks
└── README.md                       # This file
```

## Features

- **Cross-platform**: Works on macOS, Fedora, and Deb-based distros
- **OS-specific configurations**: Shared settings with platform-specific adaptations
- **Auto-distro detection**: Automatically detects your distro and routes to correct scripts
- **Symlink-based management**: Easy updates and version control of dotfiles
- **Secure secrets management**: Template-based secrets with git-safe storage
- **Package management scripts**: Automated installation for common tools (Homebrew, DNF, apt)
- **Single command setup**: Works on new machines with minimal effort
- **Automatic backups**: Existing files are backed up before being replaced

## Configuration

### Personal Information

Edit the dotfiles after copying to customize:
- `~/.gitconfig`: Update your name and email
- `~/.zshrc` (macOS) / `~/.bashrc` (Linux): Customize shell settings and aliases

### Security

API keys and secrets should be stored securely using your preferred method:
- Environment variables
- System keyring tools
- Secret management tools

## Supported Platforms

### macOS
- Homebrew package installation
- System defaults and preferences
- Finder, Dock, and desktop settings
- Native app configurations
- Zsh as the default shell

### Linux (Fedora-based)
- DNF package installation
- Flatpak application management
- GNOME desktop configuration
- Development environment setup
- Bash as the default shell

### Linux (Deb-based)
- apt package installation
- GNOME desktop configuration
- Bash as the default shell (.bashrc auto-linked)
- Development environment setup via Homebrew + apt

## Optional Package Installation

After setting up dotfiles, you can optionally install packages:

```bash
# macOS
./scripts/install_macos.sh
./scripts/configure_macos.sh

# Fedora
./scripts/install_rpm.sh  
./scripts/configure_rpm.sh
```

## Adding New Dotfiles

1. Create the file in the `home/` directory using the final filename (for example: `.myconfig`)
2. Add the new file to the `dotfiles` array in `dots.sh`
3. Update this README if needed
4. Run `./dots.sh install` to create the symlink
5. Commit changes: `git add . && git commit -m "Add new dotfile"`

### Example: Adding a new dotfile

```bash
# Create the new dotfile in home/ directory
echo "export MY_VAR=value" > home/.myconfig

# Edit dots.sh to add the new file to the dotfiles array:
# ".myconfig:.myconfig"

# Install the new dotfile
./dots.sh install
```

## Requirements

- **macOS**: macOS 10.15+ with optional Homebrew
- **Linux**: Tested on Fedora 40+, should work on other distributions
- **All**: Git, curl
- **macOS**: Zsh (default shell)
- **Linux**: Bash (default shell)
- **Optional**: Package managers (Homebrew for macOS, DNF/Flatpak for Fedora)

## License

MIT License - see [LICENSE](LICENSE) file for details.
