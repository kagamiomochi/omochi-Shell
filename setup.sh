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

sudo pacman -Syu --noconfirm

# Check if Paru is installed.
if ! command -v paru &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git rust
    BUILD_DIR=$(mktemp -d)

    git clone https://aur.archlinux.org/paru.git "$BUILD_DIR/paru"
    (
        cd "$BUILD_DIR/paru"
        makepkg -si --noconfirm
    )
fi

# Install prerequisite packages
sudo pacman -S \
hyprland \
--needed --noconfirm

# Load packages from package list and install them
grep -Ev '^\s*($|#)' "$PACKAGES_FILE" | xargs -r paru -S --needed --noconfirm

# Install Hyprland plugins
#hyprpm update
#yes | hyprpm add https://github.com/hyprwm/hyprland-plugins
#yes | hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
#hyprpm enable dynamic-cursors

# Linking dotfiles 
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
link "$HOME_DIR/.tmux.conf"                     "$HOME/.tmux.conf"

# .config
link "$HOME_DIR/.config/hypr"                   "$HOME/.config/hypr"
link "$HOME_DIR/.config/quickshell"             "$HOME/.config/quickshell"
link "$HOME_DIR/.config/kitty"                  "$HOME/.config/kitty"
link "$HOME_DIR/.config/fcitx5"                 "$HOME/.config/fcitx5"
link "$HOME_DIR/.config/hazkey"                 "$HOME/.config/hazkey"
link "$HOME_DIR/.config/Thunar"                 "$HOME/.config/Thunar"
link "$HOME_DIR/.config/xfce4"                  "$HOME/.config/xfce4"
link "$HOME_DIR/.config/gtk-3.0"                "$HOME/.config/gtk-3.0"
link "$HOME_DIR/.config/gtk-4.0"                "$HOME/.config/gtk-4.0"
link "$HOME_DIR/.config/gpu-screen-recorder"    "$HOME/.config/gpu-screen-recorder"
link "$HOME_DIR/.config/yt-dlp"                 "$HOME/.config/yt-dlp"
link "$HOME_DIR/.config/vesktop"                "$HOME/.config/vesktop"
link "$HOME_DIR/.config/sunshine"               "$HOME/.config/sunshine"
link "$HOME_DIR/.config/environment.d"          "$HOME/.config/environment.d"
link "$HOME_DIR/.config/mimeapps.list"          "$HOME/.config/mimeapps.list"
 
# system
sudo ln -sfn "$DOTFILES_DIR/system/etc/keyd/default.conf" /etc/keyd/default.conf

# greetd autologin
sudo mkdir -p /etc/greetd
sed "s/__USERNAME__/${USER}/g" "$DOTFILES_DIR/system/etc/greetd/config.toml.template" | sudo tee /etc/greetd/config.toml > /dev/null

# sudo show asterisks
echo "Defaults pwfeedback" | sudo tee /etc/sudoers.d/pwfeedback

# startup
sudo systemctl enable --now bluetooth
sudo systemctl enable --now keyd
sudo systemctl enable greetd

# firewall
sudo ufw allow 1714:1764/tcp # KDE Connect
sudo ufw allow 1714:1764/udp

sudo ufw allow 80/tcp # Steam
sudo ufw allow 443/tcp
sudo ufw allow 27015:27050/tcp
sudo ufw allow 27000:27250/udp
sudo ufw allow 27031:27036/udp
sudo ufw allow 27036/tcp
sudo ufw allow 4380/udp
sudo ufw allow 3478/udp
sudo ufw allow 4379/udp

# Theme setting
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

# User groups
sudo usermod -aG input "$USER"

clear
printf "\e[1;36mWelcome to omochi-Shell!\e[0m\n"
echo "Installation complete!"
echo "The system will reboot in 10 seconds."
echo "Press Ctrl+C to cancel."

for ((i=10; i>=1; i--))
do
    printf "\rRebooting in %d seconds..." "$i"
    sleep 1
done

sudo reboot
