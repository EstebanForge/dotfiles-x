#!/bin/bash

# Comprehensive dotfiles management script
# Usage: dots [COMMAND] [OPTIONS]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
HOME_DIR="$HOME"

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
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "Backing up existing $file to $backup"
        mv "$file" "$backup"
    fi
}

# Function to create symlink
create_symlink() {
    local source="$1"
    local target="$2"

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

# Function to setup SSH configuration
setup_ssh_config() {
    local ssh_source="$DOTFILES_DIR/home/.ssh/config"
    local ssh_target="$HOME_DIR/.ssh/config"

    if [[ -f "$ssh_source" ]]; then
        # Create SSH directory if it doesn't exist
        local ssh_dir="$(dirname "$ssh_target")"
        if [[ ! -d "$ssh_dir" ]]; then
            print_status "Creating SSH directory: $ssh_dir"
            mkdir -p "$ssh_dir"
            chmod 700 "$ssh_dir"
        fi

        # Backup existing SSH config
        backup_file "$ssh_target"

        # Create symlink
        create_symlink "$ssh_source" "$ssh_target"

        # Set proper permissions
        chmod 600 "$ssh_target"
        print_success "SSH config setup complete with proper permissions"
    else
        print_warning "SSH config template not found: $ssh_source"
    fi
}

# Function to setup dotfiles
setup_dotfiles() {
    print_header "Setting Up Dotfiles"
    print_status "Setting up dotfiles from $DOTFILES_DIR to $HOME_DIR"

    # Setup SSH config
    setup_ssh_config

    # List of dotfiles to symlink (relative to home/ directory)
    local dotfiles=(
        ".zshrc:.zshrc"
        ".gitconfig:.gitconfig"
        ".gitignore_global:.gitignore_global"
        ".secrets.example:.secrets.example"
        ".editorconfig:.editorconfig"
        ".config/topgrade/topgrade.toml:.config/topgrade/topgrade.toml"
    )

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

    print_success "Dotfiles setup complete!"
    print_status "Run 'exec zsh' to reload shell configuration"
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

    local dotfiles=(
        ".zshrc"
        ".gitconfig"
        ".gitignore_global"
        ".secrets.example"
        ".editorconfig"
        ".ssh/config"
        ".config/topgrade/topgrade.toml"
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
        ".zshrc:.zshrc"
        ".gitconfig:.gitconfig"
        ".gitignore_global:.gitignore_global"
        ".secrets.example:.secrets.example"
        ".editorconfig:.editorconfig"
        ".ssh/config:.ssh/config"
        ".config/topgrade/topgrade.toml:.config/topgrade/topgrade.toml"
    )

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
    local local_commit=$(git rev-parse HEAD 2>/dev/null)
    local remote_commit=$(git rev-parse origin/main 2>/dev/null)
    if [[ "$local_commit" == "$remote_commit" ]]; then
        print_success "Synced with remote"
    else
        print_warning "Out of sync with remote (run 'dots sync')"
    fi

    return $([[ "$all_good" == true ]] && echo 0 || echo 1)
}

# Function to sync dotfiles
sync_dotfiles() {
    print_header "Syncing Dotfiles"

    cd "$DOTFILES_DIR"

    # Check for uncommitted changes
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        print_status "Found local changes, committing..."
        git add -A
        git commit -m "Update dotfiles ($(date +'%Y-%m-%d %H:%M:%S'))"
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
    if git log origin/main..HEAD --oneline | grep -q .; then
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

# Function to setup new machine
setup_new_machine() {
    print_header "New Machine Setup"

    print_status "Starting new machine dotfiles setup..."

    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        print_error "Git is not installed. Please install git first."
        return 1
    fi

    # Check if we're in the dotfiles directory
    if [[ ! -f "$DOTFILES_DIR/dots.sh" ]]; then
        print_error "dots.sh not found in current directory"
        return 1
    fi

    # Setup dotfiles
    setup_dotfiles

    # Install system packages if requested
    if [[ "${1:-}" == "--with-packages" ]]; then
        print_status "Installing system packages..."
        if [[ "$(uname)" == "Darwin" ]]; then
            if [[ -f "$DOTFILES_DIR/scripts/install_macos.sh" ]]; then
                print_status "Running macOS package installation..."
                "$DOTFILES_DIR/scripts/install_macos.sh"
            fi
        elif [[ "$(uname)" == "Linux" ]]; then
            if [[ -f "$DOTFILES_DIR/scripts/install_fedora.sh" ]]; then
                print_status "Running Fedora package installation..."
                "$DOTFILES_DIR/scripts/install_fedora.sh"
            fi
        fi
    fi

    print_success "New machine setup complete!"
    print_status "Next steps:"
    print_status "  1. Edit ~/.secrets with your actual API keys"
    print_status "  2. Run 'exec zsh' to reload shell"
    print_status "  3. Run 'dots sync' to keep updated"
}

# Function to restore from git
restore_from_git() {
    local commit_hash="${1:-HEAD}"
    print_header "Restoring from Git"

    cd "$DOTFILES_DIR"

    print_status "Restoring to commit: $commit_hash"

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
            local remote_url=$(git remote get-url origin)
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
        local local_commit=$(git rev-parse HEAD 2>/dev/null)
        local remote_commit=$(git rev-parse origin/main 2>/dev/null)
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

    # Check if ZSH config is symlinked properly
    if [[ -L "$HOME/.zshrc" ]]; then
        local zsh_target="$(readlink "$HOME/.zshrc")"
        if [[ -f "$zsh_target" ]] && [[ "$zsh_target" == "$DOTFILES_DIR/home/.zshrc" ]]; then
            print_success "✅ ZSH configuration is properly symlinked"
        else
            print_error "❌ ZSH symlink is broken or incorrect"
            ((issues++))
        fi
    else
        print_warning "⚠️  ZSH configuration is not symlinked"
        ((warnings++))
    fi

    # Check if Oh My Zsh is installed
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        print_success "✅ Oh My Zsh is installed"

        # Check if Oh My Zsh is up to date
        cd "$HOME/.oh-my-zsh"
        if git status >/dev/null 2>&1; then
            local omz_local=$(git rev-parse HEAD 2>/dev/null)
            if git fetch --dry-run >/dev/null 2>&1; then
                local omz_remote=$(git rev-parse origin/master 2>/dev/null)
                if [[ "$omz_local" != "$omz_remote" ]]; then
                    print_warning "⚠️  Oh My Zsh updates available"
                    ((warnings++))
                else
                    print_success "✅ Oh My Zsh is up to date"
                fi
            fi
        fi
        cd "$DOTFILES_DIR"
    else
        print_error "❌ Oh My Zsh is not installed"
        ((issues++))
    fi

    # 4. Check package managers
    echo ""
    print_status "4. Checking package managers..."

    # Homebrew health check
    if command -v brew >/dev/null 2>&1; then
        print_success "✅ Homebrew is installed"

        # Check if Homebrew is healthy
        if brew doctor >/dev/null 2>&1; then
            print_success "✅ Homebrew configuration is healthy"
        else
            print_warning "⚠️  Homebrew configuration issues detected"
            ((warnings++))
        fi

        # Check for outdated packages
        local outdated_count=$(brew outdated | wc -l | tr -d ' ')
        if [[ $outdated_count -eq 0 ]]; then
            print_success "✅ All Homebrew packages are up to date"
        else
            print_warning "⚠️  $outdated_count Homebrew packages need updates"
            ((warnings++))
        fi
    else
        print_error "❌ Homebrew is not installed"
        ((issues++))
    fi

    # npm health check
    if command -v npm >/dev/null 2>&1; then
        print_success "✅ npm is installed"

        # Check if npm is configured correctly
        if npm config get prefix >/dev/null 2>&1; then
            local npm_prefix=$(npm config get prefix)
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
        local composer_version=$(composer --version 2>/dev/null | cut -d' ' -f2)
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
    local essential_tools=("zsh" "curl" "git" "brew")
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

    # SSH configuration
    if [[ -f "$HOME/.ssh/config" ]]; then
        print_success "✅ SSH configuration exists"

        # Check SSH permissions
        if [[ "$(stat -f %A "$HOME/.ssh")" == "drwx------" ]]; then
            print_success "✅ SSH directory has correct permissions (700)"
        else
            print_warning "⚠️  SSH directory permissions may be insecure"
            ((warnings++))
        fi

        if [[ -f "$HOME/.ssh/config" ]]; then
            if [[ "$(stat -f %A "$HOME/.ssh/config")" == "-rw-------" ]]; then
                print_success "✅ SSH config file has correct permissions (600)"
            else
                print_warning "⚠️  SSH config file permissions may be insecure"
                ((warnings++))
            fi
        fi
    else
        print_warning "⚠️  SSH configuration does not exist"
        ((warnings++))
    fi

    # Secrets file security
    if [[ -f "$HOME/.secrets" ]]; then
        if [[ "$(stat -f %A "$HOME/.secrets")" == "-rw-------" ]]; then
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
    local disk_usage=$(df "$HOME" | awk 'NR==2 {print $5}' | sed 's/%//')
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
        local memory_pressure=$(memory_pressure | head -1 | grep -o '[0-9]\+%')
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
    local os_name=$(uname -s)
    case "$os_name" in
        "Darwin")
            print_success "✅ Running on macOS (supported)"
            local macos_version=$(sw_vers -productVersion)
            print_status "ℹ️  macOS version: $macos_version"
            ;;
        "Linux")
            print_success "✅ Running on Linux (supported)"
            if [[ -f /etc/os-release ]]; then
                local linux_distro=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
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
Comprehensive Dotfiles Management Script v1.0.0

USAGE:
    dots [COMMAND] [OPTIONS]

COMMANDS:
    install           Install dotfiles (create symlinks)
    cleanup           Remove existing symlinks
    status            Check current status of dotfiles
    sync              Pull, push, and sync dotfiles
    setup-machine      Setup new machine
    restore <commit>   Restore to specific git commit
    history           Show recent git history
    health            Run comprehensive health check
    help, -h, --help Show this help message

NEW MACHINE SETUP:
    dots setup-machine           # Basic setup
    dots setup-machine --with-packages  # Setup + install packages

SYNC COMMANDS:
    dots sync                  # Full sync (pull, push, install)

RESTORE COMMANDS:
    dots restore               # Restore to latest commit
    dots restore abc123        # Restore to specific commit
    dots history               # Show commit history

STATUS COMMANDS:
    dots status               # Detailed status of all dotfiles
    dots health               # Overall system health check

EXAMPLES:
    dots install              # Install all dotfiles
    dots status               # Check if everything is working
    dots sync                 # Keep dotfiles updated
    dots setup-machine         # Setup new computer
    dots restore HEAD~1       # Restore to previous commit
    dots health               # Run health diagnostics

FILES MANAGED:
    • ~/.zshrc               - ZSH shell configuration
    • ~/.gitconfig            - Git configuration
    • ~/.ssh/config           - SSH client configuration
    • ~/.editorconfig         - Editor configuration
    • ~/.secrets.example      - Secrets template
    • ~/.gitignore_global     - Global git ignore
    • ~/.config/topgrade/topgrade.toml - Update configuration

For more information, see: https://github.com/estebanforge/dotfiles-x
EOF
}

# Main script logic
main() {
    local command="${1:-help}"
    local args=("${@:2}")

    case "$command" in
        "install"|"setup")
            setup_dotfiles
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
        "setup-machine"|"new")
            setup_new_machine "${args[@]}"
            ;;
        "restore"|"r")
            restore_from_git "${args[0]:-HEAD}"
            ;;
        "history"|"log")
            show_history
            ;;
        "health"|"check")
            health_check
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