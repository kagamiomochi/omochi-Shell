#!/usr/bin/env bash
# Terminal intro: play the animation, but let any keypress skip it instantly.

fastfetch --disable-linewrap | tte --reuse-canvas --no-eol --random-effect &
anim_pid=$!

sleep 0.15
while read -t 0 -n 1 -s -r _discard; do :; done

# Poll in short bursts: keep checking for a keypress until either
# the user presses something or the animation finishes on its own.
while kill -0 "$anim_pid" 2>/dev/null; do
    if read -n 1 -s -r -t 0.05; then
        kill "$anim_pid" 2>/dev/null
        break
    fi
done

# Reap the animation process and wipe any half-drawn frame.
wait "$anim_pid" 2>/dev/null
clear
# Safety net: reset terminal modes in case the killed process didn't restore
# them (hidden cursor, echo off, etc.) before it died.
stty sane 2>/dev/null

# Show the plain fastfetch result as the final, static output before the shell starts.
fastfetch --disable-linewrap

exec "$SHELL"