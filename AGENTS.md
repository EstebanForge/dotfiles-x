## Project Overview

This repository contains a unified dotfiles setup using symlinks to automate the setup of a personalized development environment across Unix and Unix-like systems (macOS and Linux). The main goal is to provide a consistent configuration across multiple machines and platforms.

The project uses a symlink-based approach with automation scripts to achieve this:

*   **Symlink Management:** For managing dotfiles across multiple machines with simple symbolic links and backup capabilities.
*   **Homebrew (macOS):** For installing and managing software packages on macOS.
*   **DNF/Flatpak (Linux):** For installing and managing software packages on Fedora Linux.
*   **Zsh (Z Shell):** As the default shell, configured with plugins for improved productivity.
*   **Git:** For version control, with a global gitignore and user configuration.
*   **Cross-platform Support:** OS-specific configurations with automatic platform detection.

## Key Files

*   `home/`: This directory contains the dotfiles that will be symlinked to your home directory:
    *   `dot_zshrc`: Zsh configuration with OS-specific logic and secure API key management.
    *   `dot_gitconfig`: Git configuration with user details.
    *   `dot_gitignore_global`: Global gitignore rules for all projects.
    *   `dot_secrets.example`: Secrets management template for API keys and sensitive data.

*   `scripts/`: Optional setup scripts for package installation and system configuration:
    *   `install_macos.sh`: macOS package installation using Homebrew.
    *   `install_fedora.sh`: Fedora Linux package installation using DNF and Flatpak.
    *   `configure_macos.sh`: macOS system settings and preferences.
    *   `configure_fedora.sh`: Fedora GNOME desktop configuration.

*   `setup.sh`: Main setup script for managing symlinks, backups, and dotfile deployment.

## Building and Running

### Quick Setup (New Machine)

To set up a new machine using these dotfiles, run:

```bash
# Clone the repository
git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
cd ~/.dotfiles

# Install dotfiles (creates symlinks automatically)
./setup.sh install

# Reload shell configuration
source ~/.zshrc

# Set up your secrets file
cp ~/.secrets.example ~/.secrets
chmod 600 ~/.secrets
# Edit ~/.secrets with your actual API keys and secrets
```

### Manual Setup (Existing Machine)

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/estebanforge/dotfiles-x.git ~/.dotfiles
    cd ~/.dotfiles
    ```

2.  **Install dotfiles:**
    ```bash
    ./setup.sh install
    ```

3.  **Set up your secrets:**
    ```bash
    cp ~/.secrets.example ~/.secrets
    chmod 600 ~/.secrets
    # Edit the secrets file with your actual values
    ```

4.  **Optional: Install packages:**
    ```bash
    # macOS
    ./scripts/install_macos.sh
    ./scripts/configure_macos.sh

    # Fedora Linux
    ./scripts/install_fedora.sh
    ./scripts/configure_fedora.sh
    ```

### Setup Script Commands

The setup script provides several commands:

```bash
./setup.sh install    # Install dotfiles (create symlinks)
./setup.sh status     # Check current status of dotfiles
./setup.sh cleanup    # Remove existing symlinks
./setup.sh help       # Show help information
```

## Development Conventions

*   **Adding new packages:** To add a new application or tool, add a new `brew install` or `brew install --cask` line to the appropriate `install_*.sh` script for your platform.
*   **Adding new dotfiles:** If you want to manage a new configuration file, add it to the `home/` directory with the `dot_` prefix. Then update the `dotfiles` array in `setup.sh` to include the new file.
*   **Customizing macOS settings:** The `configure_macos.sh` script contains `defaults write` commands to change macOS settings. You can add, remove, or modify these commands to fit your preferences.
*   **Backup Management:** The setup script automatically creates timestamped backups of existing files before creating symlinks.
