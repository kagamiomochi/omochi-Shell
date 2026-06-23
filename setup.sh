#!/bin/bash

set -e

PACKAGES_FILE="packages.txt"

# Check for the existence of packages list
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

stow_app() {
    local app_dir="$1"
    local target="$2"
    local sudo_prefix="${3:-}"

    local app=$(basename "$app_dir")
    local parent=$(dirname "$app_dir")

    conflicts=$(stow --dir="$parent" --target="$target" --simulate "$app" 2>&1 \
        | grep "existing target is" \
        | sed "s|.*existing target is neither a link nor a directory: ||")

    if [ -n "$conflicts" ]; then
        echo "$conflicts" | while read -r file; do
            echo "Removing: $target/$file"
            $sudo_prefix rm -f "$target/$file"
        done
    fi

    $sudo_prefix stow --dir="$parent" --target="$target" "$app"
}

# home/.config/
if [ -d "$SCRIPT_DIR/home/.config" ]; then
    find "$SCRIPT_DIR/home/.config" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        echo "Stowing: $dir -> $HOME/.config"
        stow_app "$dir" "$HOME/.config"
    done
fi

# home/.local/
if [ -d "$SCRIPT_DIR/home/.local" ]; then
    find "$SCRIPT_DIR/home/.local" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        echo "Stowing: $dir -> $HOME/.local"
        stow_app "$dir" "$HOME/.local"
    done
fi

stow_with_overwrite() {
    local target="$1"
    local package="$2"
    local sudo_prefix="${3:-}"

    conflicts=$(stow --dir="$SCRIPT_DIR" --target="$target" --simulate "$package" 2>&1 \
        | grep "existing target is" \
        | sed "s|.*existing target is neither a link nor a directory: ||")

    if [ -n "$conflicts" ]; then
        echo "$conflicts" | while read -r file; do
            echo "Removing: $target/$file"
            $sudo_prefix rm -f "$target/$file"
        done
    fi

    $sudo_prefix stow --dir="$SCRIPT_DIR" --target="$target" "$package"
}

stow_with_overwrite "/" system sudo

sudo systemctl enable --now bluetooth
sudo systemctl enable --now keyd

echo "Installation complete!"
read -rp "Reboot now? [y/N] " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    sudo reboot
else
    echo "Please reboot your computer later."
fi
