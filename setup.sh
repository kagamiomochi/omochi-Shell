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
    reset_screen 2>/dev/null || true
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
SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
LOG_LAST_LINE=0
SCREEN_INITIALIZED=false

# Construct a bar string (argument: percent)
render_bar() {
    local percent="$1"
    local filled=$(( percent * BAR_WIDTH / 100 ))
    local empty=$(( BAR_WIDTH - filled ))
    printf '%s%s' "$(printf '#%.0s' $(seq 1 "$filled") 2>/dev/null)" "$(printf -- '-%.0s' $(seq 1 "$empty") 2>/dev/null)"
}

# Set up the terminal: reserve the bottom lines for a fixed box,
# and make everything above it a scrolling region.
init_screen() {
    TERM_LINES=$(tput lines 2>/dev/null || echo 24)
    BOX_HEIGHT=3                                  # top border / content / bottom border
    REGION_BOTTOM=$((TERM_LINES - BOX_HEIGHT - 1))  # -1 leaves a blank separator line
    BOX_TOP=$((REGION_BOTTOM + 2))

    clear
    printf '\033[1;%dr' "$REGION_BOTTOM"   # set scroll region to rows 1..REGION_BOTTOM
    tput cup 0 0
    SCREEN_INITIALIZED=true
}

# Restore normal terminal behavior (full-screen scrolling again).
reset_screen() {
    $SCREEN_INITIALIZED || return 0
    printf '\033[r'   # reset scroll region to the whole screen
    tput cup $((TERM_LINES - 1)) 0
    echo ""
    SCREEN_INITIALIZED=false
}

# Append one line to the scrolling history area (log + completed steps).
# Printing a newline while the cursor sits on the region's bottom row
# scrolls only that region, leaving the fixed box untouched.
append_history() {
    tput cup $((REGION_BOTTOM - 1)) 0
    printf '%s\033[K\n' "$1"
}

# Read any new lines appended to LOG_FILE since the last check and
# push them into the scrolling history area.
flush_new_log_lines() {
    local total_lines
    total_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$total_lines" -gt "$LOG_LAST_LINE" ]; then
        while IFS= read -r line; do
            append_history "$line"
        done < <(sed -n "$((LOG_LAST_LINE + 1)),${total_lines}p" "$LOG_FILE")
        LOG_LAST_LINE=$total_lines
    fi
}

# Redraw the fixed box at the bottom of the screen (outside the scroll region).
draw_box() {
    local msg="$1" spin_char="$2" percent="$3" bar="$4"
    local box_text=" [$CURRENT_STEP/$TOTAL_STEPS] [$bar] ${percent}% $spin_char $msg "
    local box_len=${#box_text}
    local border
    border=$(printf '─%.0s' $(seq 1 "$box_len"))

    tput cup $((BOX_TOP - 1)) 0; printf '┌%s┐\033[K' "$border"
    tput cup $((BOX_TOP))     0; printf '│%s│\033[K' "$box_text"
    tput cup $((BOX_TOP + 1)) 0; printf '└%s┘\033[K' "$border"
}

# Execute one step, keep the fixed box updated, and stream log output
# into the scrolling area above it.
# Usage: run_step "Display Message" command...
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

    ( "$@" >> "$LOG_FILE" 2>&1 ) &
    local pid=$!
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % ${#SPIN} ))
        flush_new_log_lines
        draw_box "$msg" "${SPIN:$i:1}" "$percent" "$bar"
        sleep 0.1
    done

    wait "$pid"
    local status=$?
    flush_new_log_lines

    if [ $status -eq 0 ]; then
        append_history "✔ [$CURRENT_STEP/$TOTAL_STEPS] $msg"
        draw_box "$msg" "✔" "$percent" "$bar"
    else
        append_history "✘ [$CURRENT_STEP/$TOTAL_STEPS] $msg"
        draw_box "$msg" "✘" "$percent" "$bar"
        reset_screen
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

step_install_packages() {
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
    sed "s|\$DOTFILES_DIR|$DOTFILES_DIR|g" "$DOTFILES_DIR/home/.config/YouTube Music/config.json.template" > "$HOME/.config/YouTube Music/config.json"
    
    touch ~/.config/hypr/private.lua
}

step_system_symlinks() {
    local DOTFILES_DIR="$1"
    sudo ln -sfn "$DOTFILES_DIR/system/etc/keyd/default.conf"                 /etc/keyd/default.conf
    sudo ln -sfn "$DOTFILES_DIR/system/etc/pam.d/hyprlock"                    /etc/pam.d/hyprlock
    sudo ln -sfn "$DOTFILES_DIR/system/etc/polkit-1/rules.d/10-udisks2.rules" /etc/polkit-1/rules.d/10-udisks2.rules
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

init_screen

run_step "Updating the system"                   step_system_update
run_step "Installing paru"                       step_install_paru
run_step "Installing packages"                   step_install_packages
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

reset_screen

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
