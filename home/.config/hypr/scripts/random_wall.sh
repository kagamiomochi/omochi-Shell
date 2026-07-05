#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd)

WALLPAPER_DIR="${SCRIPT_DIR}/../wallpapers"
FALLBACK_DIR="/usr/share/wallpapers/cachyos-wallpapers"

if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon &
    sleep 0.5
fi

mapfile -t PICS < <(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) 2>/dev/null)

if [ ${#PICS[@]} -eq 0 ]; then
    if [ -f /etc/os-release ] && grep -qi '^ID=cachyos' /etc/os-release; then
        echo "No images found in $WALLPAPER_DIR, falling back to $FALLBACK_DIR"
        mapfile -t PICS < <(find "$FALLBACK_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) 2>/dev/null)
    fi
fi

if [ ${#PICS[@]} -eq 0 ]; then
    echo "No images found in $FALLBACK_DIR"
    exit 1
fi

RANDOM_PIC=${PICS[RANDOM % ${#PICS[@]}]}

awww img "$RANDOM_PIC" --transition-type grow --transition-duration 2
