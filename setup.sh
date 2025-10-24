#!/bin/bash

# Dotfiles setup script using symlinks
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
HOME_DIR="$HOME"

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

# Function to setup dotfiles
setup_dotfiles() {
    print_status "Setting up dotfiles from $DOTFILES_DIR to $HOME_DIR"
    
    # List of dotfiles to symlink (relative to home/ directory)
    local dotfiles=(
        "dot_zshrc:.zshrc"
        "dot_gitconfig:.gitconfig"
        "dot_gitignore_global:.gitignore_global"
        "dot_secrets.example:.secrets.example"
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
}

# Function to cleanup symlinks
cleanup_symlinks() {
    print_status "Cleaning up existing symlinks"
    
    local dotfiles=(
        ".zshrc"
        ".gitconfig"
        ".gitignore_global"
        ".secrets.example"
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
    print_status "Checking dotfile status"
    
    local dotfiles=(
        "dot_zshrc:.zshrc"
        "dot_gitconfig:.gitconfig"
        "dot_gitignore_global:.gitignore_global"
        "dot_secrets.example:.secrets.example"
    )
    
    for dotfile in "${dotfiles[@]}"; do
        local source_file="${dotfile%%:*}"
        local target_file="${dotfile##*:}"
        
        local source_path="$DOTFILES_DIR/home/$source_file"
        local target_path="$HOME_DIR/$target_file"
        
        if [[ -L "$target_path" ]]; then
            local link_target
            link_target="$(readlink "$target_path")"
            if [[ "$link_target" == "$source_path" ]]; then
                print_success "$target_file -> $source_file ✓"
            else
                print_warning "$target_file -> $link_target (different target)"
            fi
        elif [[ -f "$target_path" ]]; then
            print_warning "$target_file exists but is not a symlink"
        else
            print_error "$target_file does not exist"
        fi
    done
}

# Function to show help
show_help() {
    cat << EOF
Dotfiles Setup Script

USAGE:
    $0 [COMMAND]

COMMANDS:
    install     Install dotfiles (create symlinks)
    cleanup     Remove existing symlinks
    status      Show current status of dotfiles
    help        Show this help message

EXAMPLES:
    $0 install      # Install all dotfiles
    $0 status       # Check current status
    $0 cleanup      # Remove all symlinks

EOF
}

# Main script logic
main() {
    case "${1:-install}" in
        "install")
            setup_dotfiles
            print_success "Dotfiles setup complete!"
            print_status "Run '$0 status' to verify installation"
            ;;
        "cleanup")
            cleanup_symlinks
            print_success "Cleanup complete!"
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"