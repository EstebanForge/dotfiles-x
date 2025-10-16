# macOS Dotfiles

Personalized macOS dotfiles for setting up a development environment on macOS. Includes system configurations, Homebrew package installations, and productivity tools.

## Features

- **System Configuration**: Customizes macOS defaults for Finder, Dock, Safari, Terminal, and more.
- **Package Management**: Installs Homebrew and a curated list of formulas and casks via `packages.sh`.
- **Zsh Setup**: Includes Zsh with a custom theme, autosuggestions, completions, and syntax highlighting.
- **Quiet Login**: Suppresses the "Last login" message for a cleaner and faster terminal startup.
- **Consistent Git Handling**: Configures a global `.gitattributes` and `.gitignore` to ensure consistent behavior across all your repositories.
- **Security Tweaks**: Disables captive portal and other privacy-focused settings.

## Prerequisites

- macOS 12+ (tested on Sequoia 15)
- Internet connection for downloading packages
- Administrator privileges (sudo access)

## Installation

1. **Clone or Download** this repository to your local machine.

2. **Run the Setup Script**:
   ```bash
   cd dotfiles-macos
   chmod +x setup.sh packages.sh
   ./setup.sh
   ```

   This will:
   - Prompt for sudo password
   - Set computer name to "ATTD-Zen4" (edit `setup.sh` to change)
   - Configure macOS system preferences
   - Install Homebrew
   - Install packages from `packages.sh`
   - Restart affected applications

3. **Post-Setup**:
   - Log out and log back in for all changes to take effect.
   - Some settings (e.g., Dock) may require a restart.

## What's Included

- `setup.sh`: Main configuration script for macOS defaults and Homebrew.
- `packages.sh`: Installs Homebrew packages (see `brew_packages.md` for list).
- `brew_packages.md`: Documentation of installed packages.

## Customization

- **Computer Name**: Edit the `COMPUTER_NAME` variable in `setup.sh` (currently "ATTD-Zen4").
- **Packages**: Modify `packages.sh` to add/remove packages.
- **Settings**: Uncomment or edit defaults in `setup.sh` for personal preferences.

## Troubleshooting

- If Homebrew fails, ensure Xcode Command Line Tools are installed: `xcode-select --install`
- For permission issues, run with `sudo` where needed.
- Check system logs if apps don't restart properly.

## Notes

- Back up your system before running, as this modifies macOS defaults.
- Some settings are macOS version-specific; tested on Sequoia.
- Contributions welcome—fork and submit PRs.

## License

MIT License. Use at your own risk.
