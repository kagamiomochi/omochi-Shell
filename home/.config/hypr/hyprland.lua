-- https://wiki.hypr.land/Configuring/Start/


----- If you want to add your own configuration without overriding the shell configuration, please write your code above this line. -----
hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprpm reload")
    hl.exec_cmd("chmod +x ~/.config/hypr/scripts/autostart.sh; ~/.config/hypr/scripts/autostart.sh")
    hl.exec_cmd([[
        if [ ! -f "$HOME/.local/state/omochi-shell/.setup_done" ]; then
            "$DOTFILES_DIR/scripts/post-setup.sh"
        fi
    ]])
end)
require("conf/env")
require("conf/keybinds")
require("conf/windowrule")
require("conf/variables")
require("conf/plugin")
require("private")
----- If you want to override the shell configuration, please write your code below this line. -----


