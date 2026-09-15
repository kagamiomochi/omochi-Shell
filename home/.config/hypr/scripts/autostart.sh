#!/usr/bin/env bash

dbus-update-activation-environment --systemd --all
gnome-keyring-daemon --start --components=secrets,pkcs11,ssh
hyprctl setcursor "Bibata-Modern-Classic" 24
awww-daemon &
udiskie &

hyprlock

systemctl --user enable --now hypridle.service
quickshell &
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &
fcitx5 -d &
easyeffects --gapplication-service &
ollama serve &
python ~/.config/hypr/scripts/click_shrink.py &
~/.config/hypr/scripts/update-notify.sh &
~/.config/hypr/scripts/random_wall.sh &

gsr-ui &
kdeconnectd &
kdeconnect-indicator &
thunar --daemon &
sunshine &
vesktop --start-minimized &
steam -silent &
