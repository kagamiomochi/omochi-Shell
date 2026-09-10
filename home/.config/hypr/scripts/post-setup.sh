#!/bin/bash

touch ~/.config/hypr/private.lua

# Install Hyprland plugins
hyprpm update
yes | hyprpm add https://github.com/hyprwm/hyprland-plugins
yes | hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors
