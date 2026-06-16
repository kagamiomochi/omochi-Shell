#!/bin/bash

set -e

PACKAGES_FILE="packages.txt"

# Check for the existence of packages.txt
if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: $PACKAGES_FILE not found."
    exit 1
fi

# Check if paru is installed.
if ! command -v paru &> /dev/null; then
    echo "paru not found. Starting installation..."
    
    sudo pacman -Syu --needed --noconfirm base-devel git
    BUILD_DIR=$(mktemp -d)
    trap 'rm -rf "$BUILD_DIR"' EXIT

    git clone https://aur.archlinux.org/paru.git "$BUILD_DIR/paru"
    (
        cd "$BUILD_DIR/paru"
        makepkg -si --noconfirm
    )
    
    echo "The installation of paru is complete."
else
    echo "Paru is already installed. Continue..."
fi

# Load packages from packages.txt and install them
echo "Install packages from packages.txt..."

grep -Ev '^\s*($|#)' "$PACKAGES_FILE" | xargs -r paru -S --needed --noconfirm

# Create symbolic links with stow
echo "Creating symbolic links with stow..."

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)

stow_with_overwrite() {
    local target="$1"
    local package="$2"
    local sudo_prefix="${3:-}"

    # Simulate and get the path of the conflicting file
    conflicts=$(stow --dir="$SCRIPT_DIR" --target="$target" --simulate "$package" 2>&1 \
        | grep "existing target is" \
        | sed "s|.*existing target is neither a link nor a directory: ||")

    # Delete conflicting files
    if [ -n "$conflicts" ]; then
        echo "$conflicts" | while read -r file; do
            echo "Removing: $target/$file"
            $sudo_prefix rm -f "$target/$file"
        done
    fi

    # Stow execution
    $sudo_prefix stow --dir="$SCRIPT_DIR" --target="$target" "$package"
}

stow_with_overwrite "$HOME" home
stow_with_overwrite "/" system sudo

echo "Installation complete!"
