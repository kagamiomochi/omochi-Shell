#!/bin/bash

touch ~/.config/hypr/private.lua

cleanup() {
    sudo rm -f /etc/sudoers.d/post-setup-tmp
}
trap cleanup EXIT

# Install Hyprland plugins
hyprpm update
yes | hyprpm add https://github.com/hyprwm/hyprland-plugins
yes | hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors

hyprpm reload

mkdir -p "$HOME/.local/state/omochi-shell/"
touch "$HOME/.local/state/omochi-shell/.setup_done"
