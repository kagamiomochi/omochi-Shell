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
if command -v paru &> /dev/null; then
    echo "paru is already installed."
elif pacman -Si paru &>/dev/null; then
    sudo pacman -S --needed --noconfirm paru
else
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

# Linking dotfiles 
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
 
link() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
}

# home
link "$DOTFILES_DIR/home/.zshrc"    "$HOME/.zshrc"
link "$DOTFILES_DIR/home/.p10k.zsh" "$HOME/.p10k.zsh"

shopt -s nullglob dotglob
for item in "$DOTFILES_DIR/home"/.config/*; do
    name="$(basename "$item")"
    link "$DOTFILES_DIR/home/.config/$name" "$HOME/.config/$name"
done
shopt -u nullglob dotglob

# Pear Desktop
mkdir -p "$HOME/.config/YouTube Music"
sed "s|\$HOME|$HOME|g" "$HOME/omochi-Shell/home/.config/YouTube Music/config.json.template" > "$HOME/.config/YouTube Music/config.json"
 
# system
sudo ln -sfn "$DOTFILES_DIR/system/etc/keyd/default.conf" /etc/keyd/default.conf
sudo ln -sfn "$DOTFILES_DIR/system/etc/pam.d/hyprlock" /etc/pam.d/hyprlock

# greetd autologin
sudo mkdir -p /etc/greetd
sed "s/__USERNAME__/${USER}/g" "$DOTFILES_DIR/system/etc/greetd/config.toml.template" | sudo tee /etc/greetd/config.toml > /dev/null

# sudo show asterisks
echo "Defaults pwfeedback" | sudo tee /etc/sudoers.d/pwfeedback

# git
git update-index --skip-worktree "$DOTFILES_DIR/home/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"

# startup
sudo systemctl enable --now bluetooth
sudo systemctl enable --now keyd
sudo systemctl enable greetd

# post-setup nopassword
POSTSETUP_PATH="$DOTFILES_DIR/post-setup.sh"
SUDOERS_FILE="/etc/sudoers.d/post-setup-tmp"

sudo tee "$SUDOERS_FILE" > /dev/null <<EOF
$USER ALL=(ALL) NOPASSWD: $POSTSETUP_PATH, /usr/bin/rm -f $SUDOERS_FILE
EOF
sudo chmod 0440 "$SUDOERS_FILE"
sudo visudo -c -f "$SUDOERS_FILE"

touch ~/.config/hypr/private.lua

# firewall
sudo ufw allow 1714:1764/tcp # KDE Connect
sudo ufw allow 1714:1764/udp

sudo ufw allow 27015:27050/tcp # Steam
sudo ufw allow 27000:27250/udp
sudo ufw allow 27031:27036/udp
sudo ufw allow 27036/tcp
sudo ufw allow 4380/udp
sudo ufw allow 3478/udp
sudo ufw allow 4379/udp

sudo ufw allow 47984,47989,47990,48010/tcp # Sunshine
sudo ufw allow 47998,47999,48000,48002,48010,5353/udp

# Theme setting
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

# User groups
sudo usermod -aG input "$USER"

clear
echo "Installation complete!"
printf "Welcome to \e[1;33momochi-Shell!\e[0m\n"
echo "The system will reboot in 10 seconds."
echo "Press Ctrl+C to cancel."

for ((i=10; i>=1; i--))
do
    printf "\rRebooting in %d seconds..." "$i"
    sleep 1
done

sudo reboot
