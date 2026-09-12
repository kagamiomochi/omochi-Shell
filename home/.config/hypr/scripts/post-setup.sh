#!/bin/bash

touch ~/.config/hypr/private.lua

cleanup() {
    sudo rm -f /etc/sudoers.d/hyprpm-tmp
}
trap cleanup EXIT

# Install Hyprland plugins
hyprpm update
yes | hyprpm add https://github.com/hyprwm/hyprland-plugins
yes | hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors
