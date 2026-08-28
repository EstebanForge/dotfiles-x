# Cross-shell environment (bash + zsh): exports and PATH entries shared by
# .zshrc and .bashrc. Platform-specific PATH additions (bun, Android SDK,
# php@8.3 keg paths, windsurf, LLVM, ...) stay in the per-shell rc files.

# Preferred editor
export EDITOR='nano'

# PHP & Composer
export PATH="$HOME/.config/composer/vendor/bin:$PATH"
# Unified: .bashrc used to export 600; 1800 matches .zshrc and survives
# slow composer installs (large WP/Wicket projects).
export COMPOSER_PROCESS_TIMEOUT=1800

# User-specific binary paths
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# HOMEBREW
export HOMEBREW_NO_ENV_HINTS=1

# FFF (disable $HOME scan; was duplicated in .zshrc and .bashrc)
export FFF_ENABLE_HOME_SCAN=0

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

# phpvm (PHP version manager)
export PHPVM_DIR="$HOME/.phpvm"
export PATH="$PHPVM_DIR/bin:$PATH"
[[ -s "$PHPVM_DIR/phpvm.sh" ]] && source "$PHPVM_DIR/phpvm.sh"

# macOS: stop BSD tar/cp/mv from writing AppleDouble ._ companion files
# (extended attributes) when the target cannot store them: tarballs, exFAT,
# NFS, anything non-APFS. The LaunchAgent com.user.copyfile-disable.plist
# (symlinked by dots.sh) sets the same variable for GUI-launched processes.
# Finder is not affected by this variable. No-op on Linux.
if [[ "$(uname)" == "Darwin" ]]; then
    export COPYFILE_DISABLE=1
fi
