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
SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

# Construct a bar string (argument: percent)
render_bar() {
    local percent="$1"
    local filled=$(( percent * BAR_WIDTH / 100 ))
    local empty=$(( BAR_WIDTH - filled ))
    printf '%s%s' "$(printf '#%.0s' $(seq 1 "$filled") 2>/dev/null)" "$(printf -- '-%.0s' $(seq 1 "$empty") 2>/dev/null)"
}

# Execute one step and display a progress bar with a spinner until completion
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
        printf "\r\033[K[%d/%d] [%s] %3d%% %s %s" \
            "$CURRENT_STEP" "$TOTAL_STEPS" "$bar" "$percent" "${SPIN:$i:1}" "$msg"
        sleep 0.1
    done

    wait "$pid"
    local status=$?

    if [ $status -eq 0 ]; then
        printf "\r\033[K[%d/%d] [%s] %3d%% %s %s\n" \
            "$CURRENT_STEP" "$TOTAL_STEPS" "$bar" "$percent" "✔" "$msg"
    else
        printf "\r\033[K[%d/%d] [%s] %3d%% %s %s\n" \
            "$CURRENT_STEP" "$TOTAL_STEPS" "$bar" "$percent" "✘" "$msg"
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

step_install_hyprland() {
    sudo pacman -S hyprland --needed --noconfirm
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
}

step_pear_desktop() {
    local DOTFILES_DIR="$1"
    mkdir -p "$HOME/.config/YouTube Music"
    sed "s|\$HOME|$HOME|g" "$DOTFILES_DIR/home/.config/YouTube Music/config.json.template" > "$HOME/.config/YouTube Music/config.json"
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

    touch ~/.config/hypr/private.lua

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
# Execute
# ============================================================

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

run_step "システムを更新中"                 step_system_update
run_step "paruをインストール中"             step_install_paru
run_step "Hyprlandをインストール中"         step_install_hyprland
run_step "パッケージを一括インストール中"   step_install_packages
run_step "dotfilesをリンク中"               step_link_dotfiles "$DOTFILES_DIR"
run_step "Pear Desktopを設定中"             step_pear_desktop "$DOTFILES_DIR"
run_step "システム設定ファイルをリンク中"   step_system_symlinks "$DOTFILES_DIR"
run_step "greetdの自動ログインを設定中"     step_greetd_config "$DOTFILES_DIR"
run_step "sudoのフィードバック表示を設定中" step_sudo_feedback
run_step "gitのスキップ設定を適用中"        step_git_skip_worktree "$DOTFILES_DIR"
run_step "各種サービスを有効化中"           step_enable_services
run_step "初期セットアップ準備を実行中"     step_post_setup_nopasswd
run_step "テーマとユーザーグループを設定中" step_theme_and_groups
run_step "環境変数を設定中"                 step_env_var "$DOTFILES_DIR"

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
