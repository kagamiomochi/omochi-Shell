#!/bin/bash

set -e

PACKAGES_FILE="packages.txt"

# Check for the existence of package list
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

# Load packages from package list and install them
echo "Install packages from $PACKAGES_FILE..."
grep -Ev '^\s*($|#)' "$PACKAGES_FILE" | xargs -r paru -S --needed --noconfirm

echo "Linking dotfiles..."
 
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$DOTFILES_DIR/home"
 
link() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
}
 
# .config
link "$HOME_DIR/.config/hypr"               "$HOME/.config/hypr"
link "$HOME_DIR/.config/kitty"              "$HOME/.config/kitty"
link "$HOME_DIR/.config/fcitx5"             "$HOME/.config/fcitx5"
link "$HOME_DIR/.config/quickshell"         "$HOME/.config/quickshell"
link "$HOME_DIR/.config/Thunar"             "$HOME/.config/Thunar"
link "$HOME_DIR/.config/mozc"               "$HOME/.config/mozc"
link "$HOME_DIR/.config/gpu-screen-recorder" "$HOME/.config/gpu-screen-recorder"
link "$HOME_DIR/.config/yt-dlp"             "$HOME/.config/yt-dlp"
 
# .local
link "$HOME_DIR/.local/share/applications"  "$HOME/.local/share/applications"
 
# system
sudo ln -sfn "$DOTFILES_DIR/system/etc/keyd/default.conf" /etc/keyd/default.conf

echo "Register a Startup..."

# startup
sudo systemctl enable --now bluetooth
sudo systemctl enable --now keyd

echo "Installation complete!"

for ((i=5; i>=1; i--))
do
    printf "\rRestarting in %d..." "$i"
    sleep 1
done

echo
sudo reboot
