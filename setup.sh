#!/bin/bash

set -e

sudo -v
(while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done) &
SUDO_KEEPALIVE_PID=$!

BUILD_DIR=""

cleanup() {
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    [ -n "$BUILD_DIR" ] && rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

PACKAGES_FILE="packages.txt"

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: $PACKAGES_FILE not found."
    exit 1
fi

# Check if Paru is installed.
if ! command -v paru &> /dev/null; then
    echo "paru not found. Starting installation..."
    
    sudo pacman -Syu --needed --noconfirm base-devel git
    BUILD_DIR=$(mktemp -d)

    git clone https://aur.archlinux.org/paru.git "$BUILD_DIR/paru"
    (
        cd "$BUILD_DIR/paru"
        makepkg -si --noconfirm
    )

    echo "The installation of paru is complete."
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

# home
link "$HOME_DIR/.zshrc"                         "$HOME/.zshrc"
link "$HOME_DIR/.p10k.zsh"                      "$HOME/.p10k.zsh"

# .config
link "$HOME_DIR/.config/hypr"                   "$HOME/.config/hypr"
link "$HOME_DIR/.config/quickshell"             "$HOME/.config/quickshell"
link "$HOME_DIR/.config/kitty"                  "$HOME/.config/kitty"
link "$HOME_DIR/.config/fcitx5"                 "$HOME/.config/fcitx5"
link "$HOME_DIR/.config/mozc"                   "$HOME/.config/mozc"
link "$HOME_DIR/.config/Thunar"                 "$HOME/.config/Thunar"
link "$HOME_DIR/.config/xfce4"                  "$HOME/.config/xfce4"
link "$HOME_DIR/.config/gpu-screen-recorder"    "$HOME/.config/gpu-screen-recorder"
link "$HOME_DIR/.config/yt-dlp"                 "$HOME/.config/yt-dlp"
link "$HOME_DIR/.config/vesktop"                "$HOME/.config/vesktop"
 
# .local
link "$HOME_DIR/.local/share/applications"  "$HOME/.local/share/applications"
 
# system
sudo ln -sfn "$DOTFILES_DIR/system/etc/keyd/default.conf" /etc/keyd/default.conf

echo "Register a Startup..."

# startup
sudo systemctl enable --now bluetooth
sudo systemctl enable --now keyd

sudo ufw allow 1714:1764/tcp
sudo ufw allow 1714:1764/udp

clear
figlet -c -t -f slant "Welcome to omochi-Shell ! "
echo
echo
echo "Installation complete!"
echo "The system will reboot in 10 seconds."
echo "Press Ctrl+C to cancel."

for ((i=10; i>=1; i--))
do
    printf "\rRebooting in %d seconds..." "$i"
    sleep 1
done

sudo reboot
