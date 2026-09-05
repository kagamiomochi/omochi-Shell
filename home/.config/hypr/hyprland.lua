-- https://wiki.hypr.land/Configuring/Start/


----- If you want to add your own configuration without overriding the shell configuration, please write your code above this line. -----
hl.exec_cmd("hyprpm update")
hl.on("hyprland.start", function ()
  hl.exec_cmd("chmod +x ~/.config/hypr/scripts/autostart.sh; ~/.config/hypr/scripts/autostart.sh")
  hl.exec_cmd([[
        FLAG="$HOME/.local/state/omochi-shell/.setup_done"
        if [ ! -f "$FLAG" ]; then
            mkdir -p "$(dirname "$FLAG")"
            ~/.config/hypr/scripts/post-setup.sh
            touch "$FLAG"
        fi
    ]])
end)
require("conf/env")
require("conf/keybinds")
require("conf/windowrule")
require("conf/variables")
require("conf/plugin")
----- If you want to override the shell configuration, please write your code below this line. -----

require("private")
