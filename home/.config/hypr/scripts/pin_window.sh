#!/bin/bash

info=$(hyprctl activewindow -j)

pinned=$(echo "$info" | jq -r '.pinned')
floating=$(echo "$info" | jq -r '.floating')

if [ "$pinned" = "true" ]; then
    # Pin解除
    hyprctl dispatch pin active

    # FloatならTileに戻す
    if [ "$floating" = "true" ]; then
        hyprctl dispatch togglefloating active
    fi
else
    # TileならFloat化
    if [ "$floating" != "true" ]; then
        hyprctl dispatch togglefloating active
    fi

    # Pin
    hyprctl dispatch pin active
fi
