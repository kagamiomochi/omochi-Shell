-- https://wiki.hypr.land/Plugins/Using-Plugins/

local M = {}

function M.setup_hyprbars()
    if hl.plugin.hyprbars ~= nil then
        
        hl.config({
            plugin = {
                hyprbars = {
                    bar_height = 32,
                    bar_blur = true,
                    bar_button_padding = 15,
                    bar_part_of_window = true,
                    bar_precedence_over_border = true,
                    on_double_click = "hyprctl dispatch fullscreen 1",
                },
            },
        })

        hl.plugin.hyprbars.add_button({
            bg_color = "rgba(00000000)",
            fg_color = "rgb(ffffff)",
            size = 18,
            icon = "✕",
            action = "hyprctl dispatch killactive",
        })

        hl.plugin.hyprbars.add_button({
            bg_color = "rgba(00000000)",
            fg_color = "rgb(ffffff)",
            size = 18,
            icon = "❏",
            action = "hyprctl dispatch fullscreen 1",
        })

    end
end

M.setup_hyprbars()
