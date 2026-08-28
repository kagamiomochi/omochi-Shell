#!/usr/bin/env bash

dbus-update-activation-environment --systemd --all
gnome-keyring-daemon --start --components=secrets

hyprlock

systemctl --user enable --now hypridle.service
quickshell &
hyprpm reload
awww-daemon &
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &
hyprctl setcursor BreezeX-Dark 24
easyeffects --gapplication-service &
fcitx5 -d &
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