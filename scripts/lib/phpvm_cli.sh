#!/usr/bin/env bash

# phpvm (PHP version manager) installer.
# Uses the official curl pipe-to-bash installer. Idempotent.

install_phpvm_cli() {
    if command -v phpvm >/dev/null 2>&1; then
        echo "phpvm already installed, skipping."
    else
        echo "Installing phpvm..."
        curl -o- https://raw.githubusercontent.com/Thavarshan/phpvm/main/install.sh | bash
    fi
}
