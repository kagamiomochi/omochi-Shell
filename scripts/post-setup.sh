#!/bin/bash

set -e

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

sudo rm -f /etc/sudoers.d/post-setup-tmp
suod mkdir -p "$HOME/.local/state/omochi-shell/"
sudo touch "$HOME/.local/state/omochi-shell/.setup_done"
