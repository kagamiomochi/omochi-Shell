#!/bin/bash

set -e

cleanup() {
    sudo rm -f /etc/sudoers.d/post-setup-tmp
    hyprctl notify 3 8000 0 "Error"
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
hyprctl notify 5 8000 0 "The initial setup has been completed"
