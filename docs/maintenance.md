# Repository Maintenance

Technical guidelines for extending and maintaining the dotfiles environment.

## Adding Dotfiles

To manage a new configuration file:

1. Place the source file under the [home/](../home/) directory.
2. Edit the `dotfiles` array in [dots.sh](../dots.sh) to include the mapping `"relative_source:relative_target"`.
3. Add the mapping to the `cleanup_symlinks` function in [dots.sh](../dots.sh).
4. Run `./dots.sh install` to generate the symlink.

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

