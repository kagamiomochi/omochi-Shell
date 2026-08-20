#!/bin/bash
if pgrep -x "steam" > /dev/null; then
    steam -shutdown
    while pgrep -x "steam" > /dev/null; do
        sleep 1
    done
fi

setsid gamescope -e -W 1920 -H 1080 -r 60 -f -- steam -bigpicture