#!/bin/bash

HYPRBARS_PATH="/var/cache/hyprpm/${USER}/hyprland-plugins/hyprbars.so"

if hyprctl plugin list | grep -q "hyprbars"; then
    hyprctl plugin unload "$HYPRBARS_PATH"

    hyprctl eval 'for _, w in pairs(hl.get_windows()) do hl.dispatch(hl.dsp.window.float({ action = "unset", window = "address:" .. w.address })) end'

    hyprctl eval 'hl.window_rule({ match = { class = ".*" }, float = false })'
    hyprctl eval 'hl.config({ general = { resize_on_border = false } })'
else
    hyprctl plugin load "$HYPRBARS_PATH"

    hyprctl eval 'for _, w in pairs(hl.get_windows()) do hl.dispatch(hl.dsp.window.float({ action = "set", window = "address:" .. w.address })) end'

    hyprctl eval 'hl.window_rule({ match = { class = ".*" }, float = true })'
    hyprctl eval 'hl.config({ general = { resize_on_border = true } })'
fi