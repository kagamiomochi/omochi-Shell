#!/bin/bash

set -e

cleanup() {
    sudo rm -f /etc/sudoers.d/post-setup-tmp
    hyprctl notify 3 2147483647 0 "Initial setup failed. Please run the following commands manually."
    hyprctl notify 3 2147483647 0 "$DOTFILES_DIR/scripts/post-setup.sh"
}
trap cleanup ERR

# Install Hyprland plugins
hyprpm update
yes | hyprpm add https://github.com/hyprwm/hyprland-plugins
yes | hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors

vencordinstallercli -install -location ~/.config/discord

sudo rm -f /etc/sudoers.d/post-setup-tmp
mkdir -p "$HOME/.local/state/omochi-shell/"
touch "$HOME/.local/state/omochi-shell/.setup_done"
hyprctl notify 5 3000 0 "Initial setup is complete"
