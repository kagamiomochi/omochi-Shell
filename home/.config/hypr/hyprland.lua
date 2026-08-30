-- https://wiki.hypr.land/Configuring/Start/


----- If you want to add your own configuration without overriding the shell configuration, please write your code above this line. -----
hl.on("hyprland.start", function ()
  hl.exec_cmd("chmod +x ~/.config/hypr/scripts/post-unlock.sh; ~/.config/hypr/scripts/post-unlock.sh")
end)
require("conf/env")
require("conf/keybinds")
require("conf/windowrule")
require("conf/variables")
require("conf/plugin")
----- If you want to override the shell configuration, please write your code below this line. -----

require("private")
