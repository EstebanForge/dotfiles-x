# GEMINI.md

## Project Overview

This repository contains a set of dotfiles and scripts to automate the setup of a personalized development environment on macOS. The main goal is to provide a consistent configuration across multiple machines.

The project uses a combination of shell scripts and configuration files to achieve this:

*   **Homebrew:** For installing and managing software packages, both command-line tools and GUI applications.
*   **Zsh (Z Shell):** As the default shell, configured with plugins for improved productivity.
*   **Git:** For version control, with a global gitignore and user configuration.
*   **macOS Defaults:** A script to customize various macOS settings for a better user experience.

## Key Files

*   `setup.sh`: This is the main entry point for the setup process. It performs the following actions:
    *   Sets the computer name.
    *   Configures various macOS settings (Finder, Dock, keyboard, etc.).
    *   Installs Homebrew if it's not already present.
    *   Calls `packages.sh` to install all the specified packages.
    *   Creates symbolic links for the dotfiles in the `home/` directory to the user's home directory.

*   `packages.sh`: This script contains a list of Homebrew formulas and casks to be installed. It's used to install everything from command-line tools like `git` and `node` to GUI applications like `Visual Studio Code` and `Alfred`.

*   `home/`: This directory contains the personal configuration files (dotfiles) that will be used in the user's home directory.
    *   `.zshrc`: Configuration for the Zsh shell, including plugins, aliases, and path settings.
    *   `.zprofile`: Zsh profile configuration, primarily used to initialize Homebrew.
    *   `.gitconfig`: Git configuration with user details and a global excludes file.
    *   `.gitignore_global`: A global set of rules for files and directories that should be ignored by Git in all projects.

## Building and Running

To set up a new macOS machine using these dotfiles, follow these steps:

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/dotfiles-macos.git
    cd dotfiles-macos
    ```

2.  **Make the scripts executable:**
    ```bash
    chmod +x setup.sh packages.sh
    ```

3.  **Run the setup script:**
    ```bash
    ./setup.sh
    ```
    The script will ask for your password to be able to change system settings and install software.

## Development Conventions

*   **Adding new packages:** To add a new application or tool, simply add a new `brew install` or `brew install --cask` line to the `packages.sh` file.
*   **Adding new dotfiles:** If you want to manage a new configuration file, add it to the `home/` directory. The `setup.sh` script will automatically create a symbolic link for it in your home directory.
*   **Customizing macOS settings:** The `setup.sh` script contains a large number of `defaults write` commands to change macOS settings. You can add, remove, or modify these commands to fit your preferences.
