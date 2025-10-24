# Cross-Platform Dotfiles

This repository contains a unified dotfiles setup that works across Unix and Unix-like systems including macOS and Linux distributions (primarily Fedora).

## Quick Start

### On a new machine:

```bash
# Clone the repository
git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
cd ~/.dotfiles

# Run the setup script to create symlinks
./setup.sh install

# Reload shell configuration
source ~/.zshrc
```

### On existing machine:

```bash
# Clone the repository
git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
cd ~/.dotfiles

# Run the setup script (automatically backs up existing files)
./setup.sh install

# Reload shell configuration
source ~/.zshrc
```

### Setup Script Commands

The setup script provides several commands:

```bash
./setup.sh install    # Install dotfiles (create symlinks)
./setup.sh status     # Check current status of dotfiles
./setup.sh cleanup    # Remove existing symlinks
./setup.sh help       # Show help information
```

### Secrets Management

The dotfiles include a secrets management system:

1. **Template file**: `home/dot_secrets.example` - Contains example secrets and documentation
2. **Your secrets**: `~/.secrets` - Your actual secrets (never committed to git)
3. **Auto-loading**: Secrets are automatically loaded when shell starts

**Setup your secrets:**

```bash
# After running ./setup.sh install, edit your secrets:
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
│   ├── dot_zshrc                   # Zsh configuration with OS detection
│   ├── dot_gitconfig               # Git configuration
│   ├── dot_gitignore_global        # Global gitignore
│   └── dot_secrets.example         # Secrets template (copy to ~/.secrets)
├── scripts/                        # Optional setup scripts
│   ├── install_macos.sh            # macOS package installation
│   ├── install_fedora.sh           # Fedora package installation
│   ├── configure_macos.sh          # macOS system settings
│   └── configure_fedora.sh         # Fedora GNOME settings
├── setup.sh                        # Setup script for symlinks
└── README.md                       # This file
```

## Features

- **Cross-platform**: Works on Unix and Unix-like systems (macOS, Linux)
- **OS-specific configurations**: Shared settings with platform-specific adaptations
- **Symlink-based management**: Easy updates and version control of dotfiles
- **Secure secrets management**: Template-based secrets with git-safe storage
- **Package management scripts**: Automated installation for common tools
- **Single command setup**: Works on new machines with minimal effort
- **Automatic backups**: Existing files are backed up before being replaced

## Configuration

### Personal Information

Edit the dotfiles after copying to customize:
- `~/.gitconfig`: Update your name and email
- `~/.zshrc`: Customize shell settings and aliases

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

### Linux (Fedora-based)
- DNF package installation
- Flatpak application management
- GNOME desktop configuration
- Development environment setup

### Other Unix-like Systems
- Core dotfiles work on any Unix-like system
- OS-specific adaptations can be made manually
- Package management scripts can be adapted for other distros

## Optional Package Installation

After setting up dotfiles, you can optionally install packages:

```bash
# macOS
./scripts/install_macos.sh
./scripts/configure_macos.sh

# Fedora
./scripts/install_fedora.sh  
./scripts/configure_fedora.sh
```

## Adding New Dotfiles

1. Create the file in the `home/` directory with the `dot_` prefix
2. Add the new file to the `dotfiles` array in `setup.sh`
3. Update this README if needed
4. Run `./setup.sh install` to create the symlink
5. Commit changes: `git add . && git commit -m "Add new dotfile"`

### Example: Adding a new dotfile

```bash
# Create the new dotfile in home/ directory
echo "export MY_VAR=value" > home/dot_myconfig

# Edit setup.sh to add the new file to the dotfiles array:
# "dot_myconfig:.myconfig"

# Install the new dotfile
./setup.sh install
```

## Requirements

- **macOS**: macOS 10.15+ with optional Homebrew
- **Linux**: Tested on Fedora 40+, should work on other distributions
- **All**: Git, Zsh, curl
- **Optional**: Package managers (Homebrew for macOS, DNF/Flatpak for Fedora)

## License

MIT License - see [LICENSE](LICENSE) file for details.