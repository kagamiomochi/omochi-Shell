###################
### KEYBINDINGS ###
###################

# See https://wiki.hypr.land/Configuring/Keywords/

$mainMod = SUPER
$terminal = kitty
$fileManager = thunar
$browser = google-chrome-stable

bind = $mainMod, T, exec, kitty --hold sh -c "fastfetch | tte highlight --highlight-brightness 1.5 --highlight-direction diagonal_top_left_to_bottom_right --highlight-width 5 --final-gradient-stops 3B5DA0 A18FD9 D69FDA DABFC8 DAD5BE --final-gradient-steps 12 --final-gradient-direction vertical"
#bind = $mainMod, T, exec, $terminal
bind = $mainMod, C, killactive
bind = $mainMod, L, exec, ~/.config/hypr/scripts/lockscreen.sh
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, W, exec, $browser
bind = $mainMod, P, exec, ~/.config/hypr/scripts/pin_window.sh
bind = $mainMod, Space, togglefloating
bind = $mainMod SHIFT, Space, exec, ~/.config/hypr/scripts/window-mode.sh
bind = $mainMod, F, fullscreen,
bindr = $mainMod, SUPER_L, exec, pkill rofi || rofi -show drun
bind = $mainMod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy && wtype -M ctrl v -m ctrl
bind = $mainMod SHIFT, T, exec, quickshell -c QuickSnip -n
bind = $mainMod SHIFT, P, exec, hyprpicker
bind = CONTROL SHIFT, Escape, exec, $terminal --class btop -e btop
bind = $mainMod SHIFT, R, exec, hyprctl reload | notify-send "Hyprland" "Hyprland has been reloaded."
bind = $mainMod, L, exec, hyprlock

# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Move window
bind = $mainMod SHIFT, left, movewindow, l
bind = $mainMod SHIFT, down, movewindow, d
bind = $mainMod SHIFT, up, movewindow, u
bind = $mainMod SHIFT, right, movewindow, r

# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, empty

# Move active window to a workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, empty

# special workspace
bind = $mainMod, S, togglespecialworkspace, special
bind = $mainMod SHIFT, S, exec, ~/.config/hypr/scripts/toggle_scratchpad.sh

# Scroll through existing workspaces
bind = $mainMod, mouse_down, exec, ~/.config/hypr/scripts/cyclews.sh prev
bind = $mainMod, mouse_up, exec, ~/.config/hypr/scripts/cyclews.sh next

# Move/resize windows
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Laptop multimedia keys for volume and LCD brightness
bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindel = ,XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+
bindel = ,XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPause, exec, playerctl play-pause
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioPrev, exec, playerctl previous
