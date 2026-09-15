#!/bin/bash

set -euo pipefail

sudo -v
(while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done) &
SUDO_KEEPALIVE_PID=$!

BUILD_DIR=""
LOG_FILE="/tmp/omochi-Shell-setup_$(date +%s).log"
: > "$LOG_FILE"

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

# ============================================================
# Progress Indicator
# ============================================================
TOTAL_STEPS=14
CURRENT_STEP=0
BAR_WIDTH=20
TAIL_LINES=3          # Number of output lines to display below the progress bar
LINE_MAX_CHARS=100    # Maximum number of characters displayed per line
SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

# Construct a bar string (argument: percent)
render_bar() {
    local percent="$1"
    local filled=$(( percent * BAR_WIDTH / 100 ))
    local empty=$(( BAR_WIDTH - filled ))
    printf '%s%s' "$(printf '#%.0s' $(seq 1 "$filled") 2>/dev/null)" "$(printf -- '-%.0s' $(seq 1 "$empty") 2>/dev/null)"
}

# Remove ANSI escape sequences and carriage returns to format the text for display
sanitize_line() {
    printf '%s' "$1" | tr '\r' '\n' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tail -n 1
}

# Draw the progress line and the TAIL_LINES lines at the end of the output
# Arguments: symbol (spinner text or ✔/✘) tmpfile
draw_block() {
    local symbol="$1"
    local tmpfile="$2"

    printf "\r\033[K[%d/%d] [%s] %3d%% %s %s\n" \
        "$CURRENT_STEP" "$TOTAL_STEPS" "$bar" "$percent" "$symbol" "$msg"

    local lines=()
    if [ -s "$tmpfile" ]; then
        mapfile -t lines < <(tail -n "$TAIL_LINES" "$tmpfile" 2>/dev/null)
    fi

    local shown=0
    local raw
    for raw in "${lines[@]}"; do
        local clean
        clean=$(sanitize_line "$raw")
        printf "\033[K  %s\n" "${clean:0:LINE_MAX_CHARS}"
        shown=$((shown + 1))
    done
    while [ "$shown" -lt "$TAIL_LINES" ]; do
        printf "\033[K\n"
        shown=$((shown + 1))
    done
}

# Execute one step and display the spinner and the most recent output until completion.
# Usage: run_step “Display Message” command...
run_step() {
    local msg="$1"
    shift
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    local bar
    bar=$(render_bar "$percent")

    {
        echo ""
        echo "===== [$CURRENT_STEP/$TOTAL_STEPS] $msg ====="
    } >> "$LOG_FILE"

    local STEP_TMP
    STEP_TMP=$(mktemp)

    # Redirect standard output and standard error to both a log file and a temporary file
    ( "$@" ) > >(tee -a "$LOG_FILE" >> "$STEP_TMP") 2>&1 &
    local pid=$!
    local i=0
    local drawn=0

    while true; do
        if [ "$drawn" -gt 0 ]; then
            printf "\033[%dA" "$drawn"
        fi

        draw_block "${SPIN:$i:1}" "$STEP_TMP"
        drawn=$((TAIL_LINES + 1))

        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi

        i=$(( (i + 1) % ${#SPIN} ))
        sleep 0.1
    done

    wait "$pid"
    local status=$?

    printf "\033[%dA" "$drawn"
    if [ $status -eq 0 ]; then
        draw_block "✔" "$STEP_TMP"
    else
        draw_block "✘" "$STEP_TMP"
    fi

    rm -f "$STEP_TMP"

    if [ $status -ne 0 ]; then
        echo ""
        echo "An error has occurred. Please check the log below for details:"
        echo "  $LOG_FILE"
        echo ""
        echo "----- Recent Logs -----"
        tail -n 30 "$LOG_FILE"
        exit $status
    fi
}

# ============================================================
# Main Body of Each Step
# ============================================================

step_system_update() {
    sudo pacman -Syu --noconfirm
}

step_install_paru() {
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
}

step_install_required_packages() {
    sudo pacman -S hyprland --needed --noconfirm
}

step_install_other_packages() {
    grep -Ev '^\s*($|#)' "$PACKAGES_FILE" | xargs -r paru -S --needed --noconfirm
}

step_link_dotfiles() {
    local DOTFILES_DIR="$1"

    link() {
        local src="$1"
        local dst="$2"
        mkdir -p "$(dirname "$dst")"
        ln -sfn "$src" "$dst"
    }

    link "$DOTFILES_DIR/home/.zshrc"    "$HOME/.zshrc"
    link "$DOTFILES_DIR/home/.p10k.zsh" "$HOME/.p10k.zsh"

    shopt -s nullglob dotglob
    for item in "$DOTFILES_DIR/home"/.config/*; do
        name="$(basename "$item")"
        link "$DOTFILES_DIR/home/.config/$name" "$HOME/.config/$name"
    done
    shopt -u nullglob dotglob

    mkdir -p "$HOME/.config/YouTube Music"
    sed "s|\$HOME|$HOME|g" "$DOTFILES_DIR/home/.config/YouTube Music/config.json.template" > "$HOME/.config/YouTube Music/config.json"
    
    touch ~/.config/hypr/private.lua
}

step_system_symlinks() {
    local DOTFILES_DIR="$1"
    sudo ln -sfn "$DOTFILES_DIR/system/etc/keyd/default.conf" /etc/keyd/default.conf
    sudo ln -sfn "$DOTFILES_DIR/system/etc/pam.d/hyprlock" /etc/pam.d/hyprlock
}

step_greetd_config() {
    local DOTFILES_DIR="$1"
    sudo mkdir -p /etc/greetd
    sed "s/__USERNAME__/${USER}/g" "$DOTFILES_DIR/system/etc/greetd/config.toml.template" | sudo tee /etc/greetd/config.toml > /dev/null
}

step_sudo_feedback() {
    echo "Defaults pwfeedback" | sudo tee /etc/sudoers.d/pwfeedback
}

step_git_skip_worktree() {
    local DOTFILES_DIR="$1"
    git update-index --skip-worktree "$DOTFILES_DIR/home/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"
}

step_enable_services() {
    sudo systemctl enable --now bluetooth
    sudo systemctl enable --now keyd
    sudo systemctl enable greetd
}

step_post_setup_nopasswd() {
    local SUDOERS_FILE="/etc/sudoers.d/post-setup-tmp"
    sudo tee "$SUDOERS_FILE" > /dev/null <<EOF
$USER ALL=(ALL) NOPASSWD: ALL
EOF
    sudo chmod 0440 "$SUDOERS_FILE"
    sudo visudo -c -f "$SUDOERS_FILE"
}

step_firewall_setup() {
    sudo ufw allow 1714:1764/tcp
    sudo ufw allow 1714:1764/udp

    sudo ufw allow 27015:27050/tcp
    sudo ufw allow 27000:27250/udp
    sudo ufw allow 27031:27036/udp
    sudo ufw allow 27036/tcp
    sudo ufw allow 4380/udp
    sudo ufw allow 3478/udp
    sudo ufw allow 4379/udp

    sudo ufw allow 47984,47989,47990,48010/tcp
    sudo ufw allow 47998,47999,48000,48002,48010,5353/udp
}

step_theme_and_groups() {
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    sudo usermod -aG input "$USER"
}

step_env_var() {
    local DOTFILES_DIR="$1"
    sudo sed -i '/^DOTFILES_DIR=/d' /etc/environment
    echo "DOTFILES_DIR=$DOTFILES_DIR" | sudo tee -a /etc/environment > /dev/null
}

# ============================================================
# Run
# ============================================================

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

run_step "Updating the system"                   step_system_update
run_step "Installing paru"                       step_install_paru
run_step "Installing required packages"          step_install_required_packages
run_step "Installing other packages"             step_install_other_packages
run_step "Linking dotfiles"                      step_link_dotfiles "$DOTFILES_DIR"
run_step "Linking the system configuration file" step_system_symlinks "$DOTFILES_DIR"
run_step "Setting up automatic login for greetd" step_greetd_config "$DOTFILES_DIR"
run_step "Configuring sudo feedback display"     step_sudo_feedback
run_step "Applying Git skip settings"            step_git_skip_worktree "$DOTFILES_DIR"
run_step "Enabling various services"             step_enable_services
run_step "Initial setup is in progress"          step_post_setup_nopasswd
run_step "Setting up the firewall"               step_firewall_setup
run_step "Setting up the theme and user group"   step_theme_and_groups
run_step "Setting environment variables"         step_env_var "$DOTFILES_DIR"

echo "The log is stored in $LOG_FILE."
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
