#!/bin/bash

if pgrep -x "steam" > /dev/null; then
    steam -shutdown
    while pgrep -x "steam" > /dev/null; do
        sleep 1
    done
fi

setsid -f gamescope -e -W 1920 -H 1080 -r 60 -f -- steam -bigpicture </dev/null >/dev/null 2>&1 &

until hyprctl clients -j | jq -e '
    any(.[]; .title | test("Steam Big Picture"; "i"))
' >/dev/null; do
    sleep 1
done

exit 0
