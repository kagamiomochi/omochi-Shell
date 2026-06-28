-- https://wiki.hypr.land/Configuring/Basics/Binds/

local mainMod  = "SUPER"
local fileManager = "thunar"
local browser = "zen-browser"

-- pin window
local function toggle_pin()
    local w = hl.get_active_window()
    if w == nil then return end

    if w.pinned then
        hl.dispatch(hl.dsp.window.pin({ action = "toggle" }))
        if w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
        end
    else
        if not w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "set" }))
        end
        hl.dispatch(hl.dsp.window.pin({ action = "toggle" }))
    end
end

-- toggle scratchpad
local function toggle_scratchpad()
    local w = hl.get_active_window()
    if w == nil then return end

    local ws = w.workspace.name or ""

    if ws:find("special") then
        hl.dispatch(hl.dsp.window.move({
            workspace = "previous"
        }))
    else
        hl.dispatch(hl.dsp.window.move({
            workspace = "special:special"
        }))
    end
end

-- General
hl.bind(mainMod .. " + T",
    hl.dsp.exec_cmd(
        "kitty --hold sh -c \"fastfetch | tte highlight"
        .. " --highlight-brightness 1.5"
        .. " --highlight-direction diagonal_top_left_to_bottom_right"
        .. " --highlight-width 5"
        .. " --final-gradient-stops 3B5DA0 A18FD9 D69FDA DABFC8 DAD5BE"
        .. " --final-gradient-steps 12"
        .. " --final-gradient-direction vertical\""
    )
)

hl.bind(mainMod .. " + C",  hl.dsp.window.close())
hl.bind(mainMod .. " + L",  hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + E",  hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W",  hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + P",  toggle_pin)

hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

-- Window Mode
hl.bind(mainMod .. " + SHIFT + Space",
    hl.dsp.exec_cmd("~/.config/hypr/scripts/window-mode.sh"))

-- App Launcher
hl.bind(mainMod .. " + SUPER_L",
    hl.dsp.exec_cmd("qs ipc call launcher toggle"),
    { release = true })

-- Clipboard history
hl.bind(mainMod .. " + V",
    hl.dsp.exec_cmd(
        "cliphist list | rofi -dmenu | cliphist decode | wl-copy && wtype -M ctrl v -m ctrl"
    ))

-- color picker
hl.bind(mainMod .. " + SHIFT + P",
    hl.dsp.exec_cmd("hyprpicker"))

-- btop
hl.bind("CONTROL + SHIFT + Escape",
    hl.dsp.exec_cmd("kitty --class btop -e btop"))

-- Reload Hyprland
hl.bind(mainMod .. " + SHIFT + R", function()
    hl.exec_cmd("hyprctl reload")
    hl.notification.create({ text = "Hyprland has been reloaded.", timeout = 3000, icon = "ok" })
end)

-- Move focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
-- Move Window
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))

-- Switch workspaces (0 moves to empty)
for i = 1, 9 do
    local key = i % 9 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i}))
end
hl.bind(mainMod .. " + 0 ", hl.dsp.focus({ workspace = "empty"}))

-- Move window to workspace (0 moves to empty)
for i = 1, 9 do
    hl.bind(mainMod .. " + SHIFT + " .. i,
        hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + SHIFT + 0",
    hl.dsp.window.move({ workspace = "empty" }))

-- Special workspace
hl.bind(mainMod .. " + S",
    hl.dsp.workspace.toggle_special("special"))
hl.bind(mainMod .. " + SHIFT + S", toggle_scratchpad)

-- Scrolling the workspace with the mouse
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "r+1" }))

--Move/resize windows
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume
hl.bind("XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { repeating = true })
hl.bind("XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { repeating = true })
hl.bind("XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { repeating = true })
hl.bind("XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { repeating = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
    { repeating = true })
hl.bind("XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
    { repeating = true })

-- Media playback (works even on the lock screen)
hl.bind("XF86AudioNext",
    hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause",
    hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",
    hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",
    hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
