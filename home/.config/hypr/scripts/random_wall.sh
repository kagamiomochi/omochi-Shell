#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd)

WALLPAPER_DIR="${SCRIPT_DIR}/../wallpapers"
FALLBACK_DIR="/usr/share/wallpapers/cachyos-wallpapers"

if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon &
    sleep 0.5
fi

mapfile -t PICS < <(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.pbm" -o -name "*.pgm" -o -name "*.ppm" -o -name "*.tga" -o -name "*.tif" -o -name "*.tiff" -o -name "*.webp" -o -name "*.bmp" -o -name "*.ff" \) 2>/dev/null)

if [ ${#PICS[@]} -eq 0 ]; then
    if [ -f /etc/os-release ] && grep -qi '^ID=cachyos' /etc/os-release; then
        echo "No images found in $WALLPAPER_DIR, falling back to $FALLBACK_DIR"
        mapfile -t PICS < <(find "$FALLBACK_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.pbm" -o -name "*.pgm" -o -name "*.ppm" -o -name "*.tga" -o -name "*.tif" -o -name "*.tiff" -o -name "*.webp" -o -name "*.bmp" -o -name "*.ff" \) 2>/dev/null)
    fi
fi

if [ ${#PICS[@]} -eq 0 ]; then
    echo "No images found in $FALLBACK_DIR"
    exit 1
fi

RANDOM_PIC=${PICS[RANDOM % ${#PICS[@]}]}

CURSOR=$(hyprctl cursorpos | tr -d ' ')
X=$(echo "$CURSOR" | cut -d',' -f1)
Y=$(echo "$CURSOR" | cut -d',' -f2)

HEIGHT=$(hyprctl monitors -j | jq '.[] | select(.focused==true) | .height')

NEW_Y=$((HEIGHT - Y))

awww img "$RANDOM_PIC" --transition-fps 60 --transition-bezier 0.3,0.0,0.0,0.8 --transition-pos "${X},${NEW_Y}" --transition-type grow
