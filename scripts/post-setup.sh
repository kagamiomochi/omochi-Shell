#!/bin/bash

set -e

cleanup() {
    sudo rm -f /etc/sudoers.d/post-setup-tmp
    hyprctl notify 3 2147483647 0 "Initial setup failed. Please run the following commands manually."
    hyprctl notify 3 2147483647 0 "$DOTFILES_DIR/scripts/post-setup.sh"
}
trap cleanup ERR

# Add a hyprpm repository; treat "already installed" as success
hyprpm_add() {
    local url="$1"
    local output

    if output=$(yes | hyprpm add "$url" 2>&1); then
        printf '%s\n' "$output"
    elif [[ "$output" == *"Repository already installed"* ]]; then
        echo "Repository already installed: $url"
    else
        printf '%s\n' "$output" >&2
        return 1
    fi
}

# Install Hyprland plugins
hyprpm update

hyprpm_add "https://github.com/hyprwm/hyprland-plugins"
hyprpm_add "https://github.com/virtcode/hypr-dynamic-cursors"

hyprpm enable dynamic-cursors

discord --start-minimized ; sleep 60 && vencordinstallercli -install -location ~/.config/discord

sudo mkdir -p "$HOME/.local/state/omochi-shell/"
sudo touch "$HOME/.local/state/omochi-shell/.setup_done"
sudo rm -f /etc/sudoers.d/post-setup-tmp
hyprctl notify 5 3000 0 "Initial setup is complete"
