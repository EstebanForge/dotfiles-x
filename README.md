# Cross-Platform Dotfiles with Chezmoi

This repository contains a unified dotfiles setup using [chezmoi](https://www.chezmoi.io/) that works across Unix and Unix-like systems including macOS and Linux distributions (primarily Fedora).

## Quick Start

### On a new machine:

```bash
# Initialize and apply dotfiles in one command
chezmoi init --apply estebanforge/dotfiles-x

# Set up secrets (required for API keys)
chezmoi secret keyring set --service=anthropic --user=$USER
```

### On existing machine:

```bash
# Initialize from repository
chezmoi init estebanforge/dotfiles-x
cd ~/.local/share/chezmoi

# Initialize chezmoi
chezmoi init

# Copy templates to chezmoi source directory
cp home/dot_* ~/.local/share/chezmoi/
cp .chezmoi.toml.tmpl ~/.local/share/chezmoi/

# Apply dotfiles
chezmoi apply

# Set up secrets
chezmoi secret keyring set --service=anthropic --user=$USER
```

## Repository Structure

```
dotfiles-x/
├── home/                           # Your dotfiles templates
│   ├── dot_zshrc.tmpl             # Zsh configuration with OS detection
│   ├── dot_gitconfig.tmpl         # Git configuration with variables
│   └── dot_gitignore_global       # Global gitignore
├── scripts/                       # Optional setup scripts
│   ├── install_macos.sh           # macOS package installation
│   ├── install_fedora.sh          # Fedora package installation
│   ├── configure_macos.sh         # macOS system settings
│   └── configure_fedora.sh        # Fedora GNOME settings
├── .chezmoi.toml.tmpl             # Configuration template
├── .chezmoiignore                 # Files to ignore
└── README.md                      # This file
```

## Features

- **Cross-platform**: Works on Unix and Unix-like systems (macOS, Linux)
- **Template-based**: OS-specific configurations with shared settings
- **Secure**: API keys stored in system keyring, not in version control
- **Auto-sync**: Automatic commits and pushes to your repo
- **Single command setup**: Works on new machines with one command

## Configuration

### Personal Information

When you first run `chezmoi init`, you'll be prompted for:
- Full name
- Email address  
- Computer name

These are stored in `~/.config/chezmoi/chezmoi.toml` and used in templates.

### Security

API keys and secrets are stored securely using the system keyring:

```bash
# Set API key (do this once per machine)
chezmoi secret keyring set --service=anthropic --user=$USER

# The key is then available in templates as:
# {{ keyring "anthropic" .chezmoi.username }}
```

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
- Template system allows for OS-specific adaptations
- Package management scripts can be adapted for other distros

## Daily Usage

```bash
# Check status of managed files
chezmoi status

# See what would change
chezmoi diff

# Apply changes
chezmoi apply

# Edit a managed file
chezmoi edit ~/.zshrc

# Add a new file to management
chezmoi add ~/.newconfig

# Pull and apply latest changes from repo
chezmoi update
```

## Adding New Dotfiles

1. Edit the file in your home directory normally
2. Add it to chezmoi: `chezmoi add ~/.newfile`
3. If it needs OS-specific logic, rename to `.tmpl` and use template syntax
4. Commit changes: `chezmoi cd && git add . && git commit -m "Add newfile"`

## Template Syntax

Use templates for files that vary between machines:

```go
{{- if eq .chezmoi.os "darwin" }}
# macOS-specific settings
eval "$(/opt/homebrew/bin/brew shellenv)"
{{- else if eq .chezmoi.os "linux" }}
# Linux-specific settings
if command -v brew >/dev/null 2>&1; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
{{- end }}

# Use variables from config
[user]
    name = {{ .name | default "Your Name" }}
    email = {{ .email | default "your@email.com" }}

# Use secure secrets
export API_KEY="{{ keyring "service" .chezmoi.username }}"
```

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

## Migration from Old Systems

This setup replaces:
- Manual dotfile management
- `setup.sh` + `packages.sh` scripts
- `backup.sh` + `restore.sh` scripts

Benefits:
- Single command for both platforms
- Template-based configuration
- Secure secrets management
- Automatic version control
- Cross-platform compatibility

## Requirements

- **macOS**: macOS 10.15+ with optional Homebrew
- **Linux**: Tested on Fedora 40+, should work on other distributions
- **All**: Git, Zsh, curl
- **Optional**: Package managers (Homebrew for macOS, DNF/Flatpak for Fedora)

## License

MIT License - see [LICENSE](LICENSE) file for details.