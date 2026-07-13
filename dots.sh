#!/usr/bin/env bash

# Re-exec with Bash when invoked from another shell (for example: zsh dots.sh).
if [[ -z "${BASH_VERSION:-}" ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "dots.sh requires Bash to run." >&2
    exit 1
fi

if [[ "$(uname)" == "Darwin" && "${DOTS_BASH_RESTARTED:-0}" != "1" ]]; then
    if (( BASH_VERSINFO[0] < 5 )); then
        for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
            if [[ -x "$candidate" ]]; then
                export DOTS_BASH_RESTARTED=1
                exec "$candidate" "$0" "$@"
            fi
        done

        brew_cmd="$(command -v brew || true)"
        if [[ -z "$brew_cmd" ]]; then
            echo "dots.sh requires Bash 5.x or later on macOS."
            echo "Homebrew is required to install a newer Bash."
            if [[ -t 0 ]]; then
                read -r -p "Install Homebrew now? [y/N]: " install_brew
                if [[ "$install_brew" =~ ^[Yy]$ ]]; then
                    echo "Installing Homebrew..."
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                        echo "Homebrew installation failed. Please install it manually and retry." >&2
                        exit 1
                    }
                    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
                        if [[ -x "$candidate" ]]; then
                            brew_cmd="$candidate"
                            break
                        fi
                    done
                else
                    echo "Install Homebrew with:" >&2
                    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
                    echo "Then run: brew install bash" >&2
                    exit 1
                fi
            else
                echo "Install Homebrew with:" >&2
                echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
                echo "Then run: brew install bash" >&2
                exit 1
            fi
        fi

        if [[ -z "$brew_cmd" ]]; then
            echo "Homebrew was not found after installation. Please ensure it is on your PATH, then run: brew install bash" >&2
            exit 1
        fi

        if ! "$brew_cmd" ls --versions bash >/dev/null 2>&1; then
            echo "Installing Bash 5 with Homebrew..."
            "$brew_cmd" install bash || {
                echo "Failed to install Bash via Homebrew. Install it manually and rerun dots.sh." >&2
                exit 1
            }
        fi

        brew_prefix="$("$brew_cmd" --prefix 2>/dev/null || true)"
        if [[ -n "$brew_prefix" ]]; then
            brew_bash="$brew_prefix/bin/bash"
            if [[ -x "$brew_bash" ]]; then
                export DOTS_BASH_RESTARTED=1
                exec "$brew_bash" "$0" "$@"
            fi
        fi

        echo "Bash 5.x was not found even after Homebrew checks." >&2
        echo "Ensure Homebrew's bash is installed and accessible, then rerun dots.sh." >&2
        exit 1
    fi
fi

set -euo pipefail

# Comprehensive dotfiles management script
# Usage: dots [COMMAND] [OPTIONS]

# Get the directory where this script is located (resolve symlinks so the
# globally-installed ~/.local/bin/dots alias finds the repo, not the bin dir).
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
HOME_DIR="$HOME"

# Source distro detection helper
# shellcheck source=scripts/lib/detect_distro.sh
source "$SCRIPT_DIR/scripts/lib/detect_distro.sh"
DISTRO="$(detect_distro)"

# Colors for output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color

# Version information
VERSION="1.0.0"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# Function to create backup of existing file
backup_file() {
    local file="$1"
    if [[ -f "$file" || -L "$file" ]]; then
        local backup
        backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "Backing up existing $file to $backup"
        mv "$file" "$backup"
    fi
}

# Function to create symlink
create_symlink() {
    local source="$1"
    local target="$2"

    # Idempotent: if the target is already a symlink pointing to the exact
    # source, it's correct - skip (no backup, no recreate). This prevents a
    # growing pile of .backup.<timestamp> files on every re-run.
    if [[ -L "$target" ]]; then
        local existing_target
        existing_target="$(readlink "$target")"
        if [[ "$existing_target" == "$source" ]]; then
            print_status "Symlink already correct: $target -> $source"
            return 0
        fi
    fi

    # Create parent directory if it doesn't exist
    local target_dir
    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"

    # Backup existing file/symlink if it exists
    backup_file "$target"

    # Create the symlink
    print_status "Creating symlink: $target -> $source"
    ln -s "$source" "$target"

    if [[ -L "$target" ]]; then
        print_success "Successfully created symlink: $target"
    else
        print_error "Failed to create symlink: $target"
        return 1
    fi
}

# Function to setup stable dots command
setup_dots_command() {
    local bin_dir="$HOME_DIR/.local/bin"
    local command_target="$bin_dir/dots"
    local command_source="$DOTFILES_DIR/dots.sh"

    mkdir -p "$bin_dir"
    create_symlink "$command_source" "$command_target"
}

# Function to setup dotfiles
setup_dotfiles() {
    print_header "Setting Up Dotfiles"
    print_status "Setting up dotfiles from $DOTFILES_DIR to $HOME_DIR"

    # List of dotfiles to symlink (relative to home/ directory)
    local dotfiles=(
        ".gitconfig:.gitconfig"
        ".config/git/ignore:.config/git/ignore"
        ".secrets.example:.secrets.example"
        ".editorconfig:.editorconfig"
        ".hushlogin:.hushlogin"
        ".config/topgrade/topgrade.toml:.config/topgrade/topgrade.toml"
        ".config/ghostty/config:.config/ghostty/config"
        ".config/zed/settings.json:.config/zed/settings.json"
        ".config/mcp-cli-ent/mcp_servers.json:.config/mcp-cli-ent/mcp_servers.json"
        ".config/gh/config.yml:.config/gh/config.yml"
        ".config/gh/hosts.yml:.config/gh/hosts.yml"
    )

    # Shell config: zsh on macOS, bash on Linux
    if [[ "$DISTRO" == "macos" ]]; then
        dotfiles+=(".zshrc:.zshrc")
        dotfiles+=(".zsh/prompt.zsh:.zsh/prompt.zsh")
    else
        dotfiles+=(".bashrc:.bashrc")
        dotfiles+=(".config/environment.d/gnome-wayland.conf:.config/environment.d/gnome-wayland.conf")
    fi

    for dotfile in "${dotfiles[@]}"; do
        local source_file="${dotfile%%:*}"
        local target_file="${dotfile##*:}"

        local source_path="$DOTFILES_DIR/home/$source_file"
        local target_path="$HOME_DIR/$target_file"

        if [[ -f "$source_path" ]]; then
            create_symlink "$source_path" "$target_path"
        else
            print_warning "Source file not found: $source_path"
        fi
    done

    # Setup secrets file
    setup_secrets

    # Setup dots command symlink
    setup_dots_command

    print_success "Dotfiles setup complete!"
    if [[ "$DISTRO" == "macos" ]]; then
        print_status "Run 'exec zsh' to reload shell configuration"
    else
        print_status "Run 'source ~/.bashrc' (or 'exec bash') to reload shell configuration"
    fi
}

# Function to setup secrets file
setup_secrets() {
    local secrets_file="$HOME_DIR/.secrets"
    local example_file="$HOME_DIR/.secrets.example"

    if [[ ! -f "$secrets_file" ]]; then
        if [[ -f "$example_file" ]]; then
            print_status "Creating secrets file from example"
            cp "$example_file" "$secrets_file"
            chmod 600 "$secrets_file"
            print_success "Created $secrets_file with example content"
            print_warning "Please edit $secrets_file with your actual secrets"
        else
            print_warning "Example secrets file not found: $example_file"
        fi
    else
        print_status "Secrets file already exists: $secrets_file"
    fi
}

# Function to cleanup symlinks
cleanup_symlinks() {
    print_header "Cleaning Up Symlinks"
    print_status "Cleaning up existing symlinks"

    # Remove both shell configs if symlinked (handles platform switches cleanly)
    local dotfiles=(
        ".zshrc"
        ".zsh/prompt.zsh"
        ".bashrc"
        ".config/environment.d/gnome-wayland.conf"
        ".gitconfig"
        ".config/git/ignore"
        ".secrets.example"
        ".editorconfig"
        ".hushlogin"
        ".config/topgrade/topgrade.toml"
        ".config/ghostty/config"
        ".config/zed/settings.json"
        ".config/mcp-cli-ent/mcp_servers.json"
        ".config/gh/config.yml"
        ".config/gh/hosts.yml"
        ".local/bin/dots"
    )

    for dotfile in "${dotfiles[@]}"; do
        local target_path="$HOME_DIR/$dotfile"

        if [[ -L "$target_path" ]]; then
            print_status "Removing symlink: $target_path"
            rm "$target_path"
            print_success "Removed symlink: $target_path"
        fi
    done
}

# Function to show status
show_status() {
    print_header "Dotfile Status"
    print_status "Checking dotfile status"

    local dotfiles=(
        ".gitconfig:.gitconfig"
        ".config/git/ignore:.config/git/ignore"
        ".secrets.example:.secrets.example"
        ".editorconfig:.editorconfig"
        ".hushlogin:.hushlogin"
        ".config/topgrade/topgrade.toml:.config/topgrade.toml"
        ".config/ghostty/config:.config/ghostty/config"
        ".config/zed/settings.json:.config/zed/settings.json"
        ".config/mcp-cli-ent/mcp_servers.json:.config/mcp-cli-ent/mcp_servers.json"
        ".config/gh/config.yml:.config/gh/config.yml"
        ".config/gh/hosts.yml:.config/gh/hosts.yml"
    )

    # Shell config: zsh on macOS, bash on Linux
    if [[ "$DISTRO" == "macos" ]]; then
        dotfiles+=(".zshrc:.zshrc")
        dotfiles+=(".zsh/prompt.zsh:.zsh/prompt.zsh")
    else
        dotfiles+=(".bashrc:.bashrc")
        dotfiles+=(".config/environment.d/gnome-wayland.conf:.config/environment.d/gnome-wayland.conf")
    fi

    local all_good=true
    for dotfile in "${dotfiles[@]}"; do
        local source_file="${dotfile%%:*}"
        local target_file="${dotfile##*:}"

        local source_path="$DOTFILES_DIR/home/$source_file"
        local target_path="$HOME_DIR/$target_file"

        if [[ -L "$target_path" ]]; then
            local link_target
            link_target="$(readlink "$target_path")"
            if [[ "$link_target" == "$source_path" ]]; then
                print_success "$target_file → $source_file ✓"
            else
                print_warning "$target_file → $link_target (different target)"
                all_good=false
            fi
        elif [[ -f "$target_path" ]]; then
            print_warning "$target_file exists but is not a symlink"
            all_good=false
        else
            print_error "$target_file does not exist"
            all_good=false
        fi
    done

    local dots_target="$HOME_DIR/.local/bin/dots"
    if [[ -L "$dots_target" ]]; then
        local dots_link_target
        dots_link_target="$(readlink "$dots_target")"
        if [[ "$dots_link_target" == "$DOTFILES_DIR/dots.sh" ]]; then
            print_success ".local/bin/dots → dots.sh ✓"
        else
            print_warning ".local/bin/dots → $dots_link_target (different target)"
            all_good=false
        fi
    elif [[ -f "$dots_target" ]]; then
        print_warning ".local/bin/dots exists but is not a symlink"
        all_good=false
    else
        print_error ".local/bin/dots does not exist"
        all_good=false
    fi

    # Git repository status
    echo ""
    print_status "Git repository status:"
    cd "$DOTFILES_DIR"
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        print_warning "Repository has uncommitted changes"
        git status --short
    else
        print_success "Repository is clean"
    fi

    # Remote status
    echo ""
    print_status "Remote sync status:"
    local local_commit remote_commit
    local_commit=$(git rev-parse HEAD 2>/dev/null || true)
    remote_commit=$(git rev-parse origin/main 2>/dev/null || true)
    if [[ -z "$remote_commit" ]]; then
        print_warning "Remote not available or not fetched"
    elif [[ "$local_commit" == "$remote_commit" ]]; then
        print_success "Synced with remote"
    else
        print_warning "Out of sync with remote (run 'dots sync')"
    fi

    [[ "$all_good" == true ]]
}

# Function to sync dotfiles
sync_dotfiles() {
    print_header "Syncing Dotfiles"

    cd "$DOTFILES_DIR"

    # Check for uncommitted changes
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        print_warning "Found local changes"
        print_status "Please review and commit manually:"
        echo "  cd \"$DOTFILES_DIR\""
        echo "  git status"
        echo "  git add <files>"
        echo "  git commit"
        print_warning "Skipping auto-commit for safety"
        return 1
    fi

    # Pull latest changes
    print_status "Pulling latest changes..."
    if git pull; then
        print_success "Pull completed successfully"
    else
        print_error "Pull failed - resolve conflicts manually"
        return 1
    fi

    # Push local changes
    if git log origin/main..HEAD --oneline 2>/dev/null | grep -q .; then
        print_status "Pushing local changes..."
        git push
        print_success "Push completed successfully"
    else
        print_status "No local changes to push"
    fi

    # Reinstall dotfiles
    print_status "Reinstalling dotfiles..."
    setup_dotfiles
}

# Function to restore from git
restore_from_git() {
    local commit_hash="HEAD"
    local force=false
    local arg

    for arg in "$@"; do
        case "$arg" in
            "--force")
                force=true
                ;;
            -*)
                print_error "Unknown option for restore: $arg"
                print_status "Usage: dots restore [commit] [--force]"
                return 1
                ;;
            *)
                commit_hash="$arg"
                ;;
        esac
    done

    print_header "Restoring from Git"

    cd "$DOTFILES_DIR"

    print_status "Restoring to commit: $commit_hash"

    if [[ "$force" != true ]]; then
        print_warning "This will run 'git reset --hard $commit_hash' and discard local changes."
        if [[ -t 0 ]]; then
            local confirmation
            read -r -p "Type 'yes' to continue: " confirmation
            if [[ "$confirmation" != "yes" ]]; then
                print_status "Restore cancelled."
                return 1
            fi
        else
            print_error "Non-interactive shell detected. Re-run with --force to continue."
            return 1
        fi
    fi

    if git reset --hard "$commit_hash"; then
        print_success "Repository restored to $commit_hash"

        print_status "Reinstalling dotfiles..."
        setup_dotfiles

        print_success "Restore complete!"
    else
        print_error "Failed to restore to commit: $commit_hash"
        return 1
    fi
}

# Function to show history
show_history() {
    print_header "Dotfiles History"

    cd "$DOTFILES_DIR"

    print_status "Recent commits:"
    git log --oneline --graph --decorate -10

    echo ""
    print_status "Use 'dots restore <commit-hash>' to restore to a specific commit"
}

# Function to setup crontab
setup_crontab() {
    local action="${1:-install}"
    print_header "Crontab Setup"

    case "$DISTRO" in
        macos)
            if [[ -f "$DOTFILES_DIR/scripts/crontab_macos.sh" ]]; then
                print_status "Running macOS crontab $action..."
                "$DOTFILES_DIR/scripts/crontab_macos.sh" "$action"
            else
                print_error "macOS crontab script not found"
                return 1
            fi
            ;;
        rpm)
            if [[ -f "$DOTFILES_DIR/scripts/crontab_rpm.sh" ]]; then
                print_status "Running RPM crontab $action..."
                "$DOTFILES_DIR/scripts/crontab_rpm.sh" "$action"
            else
                print_error "RPM crontab script not found"
                return 1
            fi
            ;;
        deb)
            if [[ -f "$DOTFILES_DIR/scripts/crontab_deb.sh" ]]; then
                print_status "Running Deb-based crontab $action..."
                "$DOTFILES_DIR/scripts/crontab_deb.sh" "$action"
            else
                print_error "Deb-based crontab script not found"
                return 1
            fi
            ;;
        *)
            print_error "Unsupported operating system for crontab setup"
            return 1
            ;;
    esac
}

# Function to show health check
health_check() {
    print_header "Comprehensive Health Check"

    local issues=0
    local warnings=0

    # 1. Check dotfile symlinks
    echo ""
    print_status "1. Checking dotfile symlinks..."
    if ! show_status >/dev/null 2>&1; then
        print_warning "⚠️  Dotfile issues detected"
        ((warnings++))
    else
        print_success "✅ All dotfiles properly linked"
    fi

    # 2. Check git repository health
    echo ""
    print_status "2. Checking git repository health..."
    cd "$DOTFILES_DIR"
    if git rev-parse --git-dir >/dev/null 2>&1; then
        print_success "✅ Git repository is valid"

        # Check remote configuration
        if git remote get-url origin >/dev/null 2>&1; then
            local remote_url
            remote_url=$(git remote get-url origin)
            print_success "✅ Remote origin configured: $remote_url"

            # Check if remote is accessible
            if git ls-remote --exit-code origin >/dev/null 2>&1; then
                print_success "✅ Remote repository is accessible"
            else
                print_warning "⚠️  Cannot access remote repository"
                ((warnings++))
            fi
        else
            print_error "❌ No remote origin configured"
            ((issues++))
        fi

        # Check for uncommitted changes
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            print_warning "⚠️  Uncommitted changes detected"
            ((warnings++))
        else
            print_success "✅ Working directory is clean"
        fi

        # Check if synced with remote
        local local_commit remote_commit
        local_commit=$(git rev-parse HEAD 2>/dev/null)
        remote_commit=$(git rev-parse origin/main 2>/dev/null)
        if [[ "$local_commit" == "$remote_commit" ]] && [[ -n "$remote_commit" ]]; then
            print_success "✅ Synced with remote"
        else
            print_warning "⚠️  Out of sync with remote"
            ((warnings++))
        fi
    else
        print_error "❌ Not a git repository"
        ((issues++))
    fi

    # 3. Check shell configuration
    echo ""
    print_status "3. Checking shell configuration..."

    # Check shell configuration symlink (zsh on macOS, bash on Linux)
    local shell_rc shell_name shell_src
    if [[ "$DISTRO" == "macos" ]]; then
        shell_rc="$HOME/.zshrc"
        shell_name="ZSH"
        shell_src="$DOTFILES_DIR/home/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
        shell_name="Bash"
        shell_src="$DOTFILES_DIR/home/.bashrc"
    fi

    if [[ -L "$shell_rc" ]]; then
        local shell_target
        shell_target="$(readlink "$shell_rc")"
        if [[ -f "$shell_target" ]] && [[ "$shell_target" == "$shell_src" ]]; then
            print_success "✅ $shell_name configuration is properly symlinked"
        else
            print_error "❌ $shell_name symlink is broken or incorrect"
            ((issues++))
        fi
    else
        print_warning "⚠️  $shell_name configuration is not symlinked"
        ((warnings++))
    fi

    # Check EstebanForgePrompt is symlinked (macOS only)
    if [[ "$DISTRO" == "macos" ]]; then
        if [[ -L "$HOME/.zsh/prompt.zsh" ]] \
           && [[ "$(readlink "$HOME/.zsh/prompt.zsh")" == "$DOTFILES_DIR/home/.zsh/prompt.zsh" ]]; then
            print_success "✅ EstebanForgePrompt is properly symlinked"
        else
            print_warning "⚠️  ~/.zsh/prompt.zsh not symlinked (run: dots install)"
            ((warnings++))
        fi
    fi

    # 4. Check package managers
    echo ""
    print_status "4. Checking package managers..."

    # Homebrew health check (required on all platforms)
    if command -v brew >/dev/null 2>&1; then
        print_success "✅ Homebrew is installed"

        if brew doctor >/dev/null 2>&1; then
            print_success "✅ Homebrew configuration is healthy"
        else
            print_warning "⚠️  Homebrew configuration issues detected"
            ((warnings++))
        fi

        local outdated_count
        outdated_count=$(brew outdated | wc -l | tr -d ' ')
        if [[ $outdated_count -eq 0 ]]; then
            print_success "✅ All Homebrew packages are up to date"
        else
            print_warning "⚠️  $outdated_count Homebrew packages need updates"
            ((warnings++))
        fi
    else
        print_error "❌ Homebrew is not installed (run: dots install --packages)"
        ((issues++))
    fi

    # npm health check
    if command -v npm >/dev/null 2>&1; then
        print_success "✅ npm is installed"

        # Check if npm is configured correctly
        if npm config get prefix >/dev/null 2>&1; then
            local npm_prefix
            npm_prefix=$(npm config get prefix)
            if [[ -w "$npm_prefix" ]]; then
                print_success "✅ npm is properly configured"
            else
                print_warning "⚠️  npm prefix configuration issue"
                ((warnings++))
            fi
        fi
    else
        print_warning "⚠️  npm is not installed"
        ((warnings++))
    fi

    # Composer health check
    if command -v composer >/dev/null 2>&1; then
        print_success "✅ Composer is installed"

        # Check Composer version
        local composer_version
        composer_version=$(composer --version 2>/dev/null | cut -d' ' -f2)
        print_status "✅ Composer version: $composer_version"
    else
        print_warning "⚠️  Composer is not installed"
        ((warnings++))
    fi

    # 5. Check development tools
    echo ""
    print_status "5. Checking development tools..."

    # Git configuration
    if command -v git >/dev/null 2>&1; then
        print_success "✅ Git is installed"

        # Check git user configuration
        if git config user.name >/dev/null 2>&1 && git config user.email >/dev/null 2>&1; then
            print_success "✅ Git user is configured"
        else
            print_warning "⚠️  Git user is not configured"
            ((warnings++))
        fi
    else
        print_error "❌ Git is not installed"
        ((issues++))
    fi

    # Essential tools
    if [[ "$DISTRO" == "macos" ]]; then
        local essential_tools=("zsh" "curl" "git" "brew")
    else
        local essential_tools=("bash" "curl" "git" "brew")
    fi
    for tool in "${essential_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            print_success "✅ $tool is available"
        else
            print_error "❌ $tool is not available"
            ((issues++))
        fi
    done

    # 6. Check security configurations
    echo ""
    print_status "6. Checking security configurations..."

    # Secrets file security
    if [[ -f "$HOME/.secrets" ]]; then
        local secrets_perms
        secrets_perms="$(stat -f '%A' "$HOME/.secrets" 2>/dev/null || stat -c '%A' "$HOME/.secrets" 2>/dev/null)"
        if [[ "$secrets_perms" == "-rw-------" ]]; then
            print_success "✅ Secrets file has correct permissions (600)"
        else
            print_warning "⚠️  Secrets file permissions may be insecure"
            ((warnings++))
        fi
    else
        print_status "ℹ️  Secrets file does not exist (run 'dots install' to create)"
    fi

    # 7. Check system performance indicators
    echo ""
    print_status "7. Checking system performance indicators..."

    # Check available disk space
    local disk_usage
    disk_usage=$(df "$HOME" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 90 ]]; then
        print_success "✅ Home directory has sufficient disk space (${disk_usage}% used)"
    elif [[ $disk_usage -lt 95 ]]; then
        print_warning "⚠️  Home directory getting full (${disk_usage}% used)"
        ((warnings++))
    else
        print_error "❌ Home directory is almost full (${disk_usage}% used)"
        ((issues++))
    fi

    # Check memory usage (macOS)
    if [[ "$(uname)" == "Darwin" ]]; then
        local memory_pressure
        memory_pressure=$(memory_pressure | head -1 | grep -o '[0-9]\+%')
        if [[ -n "$memory_pressure" ]]; then
            if [[ ${memory_pressure%?} -lt 80 ]]; then
                print_success "✅ Memory pressure is normal"
            else
                print_warning "⚠️  High memory pressure detected"
                ((warnings++))
            fi
        else
            print_status "ℹ️  Memory pressure not available"
        fi
    fi

    # Check if running on supported OS
    local os_name
    os_name=$(uname -s)
    case "$os_name" in
        "Darwin")
            print_success "✅ Running on macOS (supported)"
            local macos_version
            macos_version=$(sw_vers -productVersion)
            print_status "ℹ️  macOS version: $macos_version"
            ;;
        "Linux")
            case "$DISTRO" in
                rpm)
                    print_success "✅ Running on RPM-based Linux (supported)"
                    ;;
                deb)
                    print_success "✅ Running on Deb-based Linux (supported)"
                    ;;
                *)
                    print_warning "⚠️  Running on unsupported Linux distro"
                    ((warnings++))
                    ;;
            esac
            if [[ -f /etc/os-release ]]; then
                local linux_distro
                linux_distro=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
                print_status "ℹ️  Linux distribution: $linux_distro"
            fi
            ;;
        *)
            print_warning "⚠️  Running on unsupported OS: $os_name"
            ((warnings++))
            ;;
    esac

    # 8. Final summary and recommendations
    echo ""
    print_header "Health Check Summary"

    if [[ $issues -eq 0 ]]; then
        if [[ $warnings -eq 0 ]]; then
            print_success "🎉 All systems are healthy and optimal!"
        else
            print_success "✅ All critical systems are healthy"
            print_warning "⚠️  $warnings warning(s) detected - review above"
        fi

        echo ""
        print_status "Recommendations:"
        if [[ $warnings -gt 0 ]]; then
            print_status "  • Run 'dots sync' to resolve sync issues"
            print_status "  • Run 'sysup' to update outdated packages"
            print_status "  • Check specific warnings above for detailed fixes"
        fi
        print_status "  • Run 'dots health' periodically to monitor system health"
        return 0
    else
        print_error "❌ $issues critical issue(s) found!"

        if [[ $warnings -gt 0 ]]; then
            print_warning "⚠️  Additionally, $warnings warning(s) detected"
        fi

        echo ""
        print_status "Immediate actions required:"
        print_status "  • Run 'dots status' for detailed diagnostics"
        print_status "  • Run 'dots install' to fix dotfile issues"
        print_status "  • Address critical issues above before proceeding"

        return 1
    fi
}

# Function to show help
show_help() {
    cat << 'EOF'
Dotfiles Management Script v1.0.0

USAGE:
    dots <command> [options]

COMMANDS:
    install                   Install dotfiles (create symlinks)
    install --packages        Also install system packages
    install --crontab         Also install crontab entries
    install --configure       Also apply desktop settings (GNOME/macOS)
    cleanup                   Remove existing symlinks
    status                    Check current status of dotfiles
    sync                      Pull, push, and reinstall dotfiles
    restore [commit]          Restore to a git commit (default: HEAD)
    restore [commit] --force  Skip confirmation prompt
    history                   Show recent git history
    health                    Run comprehensive health check
    crontab [action]          Manage crontab entries (install/show/remove/backup/service)
    version                   Show script version
    help                      Show this help message

EXAMPLES:
    dots install                        # Symlinks only
    dots install --packages             # Symlinks + system packages
    dots install --packages --crontab   # Full new machine setup
    dots install --configure             # Apply desktop settings
    dots status                         # Check everything is linked
    dots sync                           # Pull latest and reinstall
    dots restore HEAD~1                 # Roll back one commit
    dots health                         # Run health diagnostics
    dots crontab show                   # Show scheduled jobs

FILES MANAGED:
    ~/.zshrc                            ZSH configuration (macOS only)
    ~/.zsh/prompt.zsh                   EstebanForgePrompt theme (macOS only)
    ~/.bashrc                           Bash configuration (Linux only)
    ~/.gitconfig                        Git configuration
    ~/.editorconfig                     Editor configuration
    ~/.hushlogin                       Silence login banner (all platforms)
    ~/.secrets.example                  Secrets template
    ~/.config/git/ignore                Global git ignore
    ~/.config/topgrade/topgrade.toml    Update manager configuration
    ~/.config/ghostty/config            Ghostty terminal configuration
    ~/.config/zed/settings.json         Zed editor configuration
    ~/.config/mcp-cli-ent/mcp_servers.json  MCP server registry
    ~/.config/gh/config.yml             GitHub CLI configuration
    ~/.config/gh/hosts.yml              GitHub CLI hosts

SUPPORTED PLATFORMS:
    macOS (Homebrew) · Fedora Linux (DNF/Flatpak) · Deb-based (apt)

For more information, see: https://github.com/estebanforge/dotfiles-x
EOF
}

# Interactive menu shown when dots is run with no arguments.
# Falls back to help text on non-interactive stdin (piped/automated runs).
show_menu() {
    if [[ ! -t 0 ]]; then
        show_help
        return 0
    fi

    while true; do
        echo ""
        print_header "Dotfiles Management"
        echo ""
        printf '  %s1)%s   Install everything (symlinks + packages + crontab + configure)\n' "$CYAN" "$NC"
        printf '  %s2)%s   Install dotfiles only (symlinks)\n' "$CYAN" "$NC"
        printf '  %s3)%s   Install apps/packages\n' "$CYAN" "$NC"
        printf '  %s4)%s   Configure desktop settings\n' "$CYAN" "$NC"
        printf '  %s5)%s   Install crontab entries\n' "$CYAN" "$NC"
        printf '  %s6)%s   Check status\n' "$CYAN" "$NC"
        printf '  %s7)%s   Run health check\n' "$CYAN" "$NC"
        printf '  %s8)%s   Sync (pull + push + reinstall)\n' "$CYAN" "$NC"
        printf '  %s9)%s   Cleanup symlinks\n' "$CYAN" "$NC"
        printf '  %s10)%s  Show help\n' "$CYAN" "$NC"
        printf '  %s0)%s   Exit\n' "$CYAN" "$NC"
        echo ""
        read -r -p "Select an option [0-10]: " choice

        case "$choice" in
            1)  main install --packages --crontab --configure; return 0 ;;
            2)  main install; return 0 ;;
            3)  main install --packages; return 0 ;;
            4)  main install --configure; return 0 ;;
            5)  main install --crontab; return 0 ;;
            6)  main status; return 0 ;;
            7)  main health; return 0 ;;
            8)  main sync; return 0 ;;
            9)  main cleanup; return 0 ;;
            10) main help; return 0 ;;
            0|"q"|"quit"|"exit") echo "Bye."; return 0 ;;
            "")  echo "Bye."; return 0 ;;
            *) print_error "Invalid option: $choice" ;;
        esac
    done
}

# Main script logic
main() {
    # No arguments + interactive TTY -> show menu. Non-interactive or any arg -> normal flow.
    if [[ $# -eq 0 && -t 0 ]]; then
        show_menu
        return $?
    fi

    local command="${1:-help}"
    local args=("${@:2}")

    case "$command" in
        "install"|"setup")
            local do_packages=false
            local do_crontab=false
            local do_configure=false
            for _arg in "${args[@]+"${args[@]}"}"; do
                case "$_arg" in
                    --packages)  do_packages=true ;;
                    --crontab)   do_crontab=true ;;
                    --configure) do_configure=true ;;
                    *) print_error "Unknown option: $_arg"; echo ""; show_help; exit 1 ;;
                esac
            done

            setup_dotfiles

            if [[ "$do_packages" == true ]]; then
                print_status "Installing system packages..."
                case "$DISTRO" in
                    macos)  [[ -f "$DOTFILES_DIR/scripts/install_macos.sh" ]]  && "$DOTFILES_DIR/scripts/install_macos.sh" ;;
                    rpm)    [[ -f "$DOTFILES_DIR/scripts/install_rpm.sh" ]] && "$DOTFILES_DIR/scripts/install_rpm.sh" ;;
                    deb)    [[ -f "$DOTFILES_DIR/scripts/install_deb.sh" ]]    && "$DOTFILES_DIR/scripts/install_deb.sh" ;;
                esac
            fi

            if [[ "$do_crontab" == true ]]; then
                print_status "Setting up crontab entries..."
                case "$DISTRO" in
                    macos)  [[ -f "$DOTFILES_DIR/scripts/crontab_macos.sh" ]] && "$DOTFILES_DIR/scripts/crontab_macos.sh" install ;;
                    rpm)    [[ -f "$DOTFILES_DIR/scripts/crontab_rpm.sh" ]]   && "$DOTFILES_DIR/scripts/crontab_rpm.sh" install ;;
                    deb)    [[ -f "$DOTFILES_DIR/scripts/crontab_deb.sh" ]]   && "$DOTFILES_DIR/scripts/crontab_deb.sh" install ;;
                esac
            fi

            if [[ "$do_configure" == true ]]; then
                print_status "Applying desktop configuration..."
                case "$DISTRO" in
                    macos)  [[ -f "$DOTFILES_DIR/scripts/configure_macos.sh" ]] && "$DOTFILES_DIR/scripts/configure_macos.sh" ;;
                    rpm)    [[ -f "$DOTFILES_DIR/scripts/configure_rpm.sh" ]]   && "$DOTFILES_DIR/scripts/configure_rpm.sh" ;;
                    deb)    [[ -f "$DOTFILES_DIR/scripts/configure_deb.sh" ]]   && "$DOTFILES_DIR/scripts/configure_deb.sh" ;;
                esac
            fi
            ;;
        "cleanup"|"clean")
            cleanup_symlinks
            ;;
        "status"|"st")
            show_status
            ;;
        "sync"|"s")
            sync_dotfiles
            ;;
        "restore"|"r")
            restore_from_git "${args[@]}"
            ;;
        "history"|"log")
            show_history
            ;;
        "health"|"check")
            health_check
            ;;
        "crontab")
            setup_crontab "${args[0]:-install}"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "version"|"-v"|"--version")
            echo "dots.sh v$VERSION"
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
