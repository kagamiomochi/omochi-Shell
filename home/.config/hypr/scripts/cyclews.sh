#!/bin/bash

current=$(hyprctl activeworkspace -j | jq .id)

if [ "$1" = "next" ]; then
    target=$((current + 1))
    [ $target -gt 5 ] && target=1
else
    target=$((current - 1))
    [ $target -lt 1 ] && target=5
fi

hyprctl dispatch workspace "$target"
