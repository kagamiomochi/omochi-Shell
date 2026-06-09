-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.workspace_rule( workspace = "s[true]", gaps_in = 5, gaps_out = 30 )
hl.window_rule({ match = { fullscreen = true }, immediate = true })
hl.window_rule({ match = { class = "fcitx5" }, no_initial_focus = true, no_focus = true })

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
  name = "YTMusic",
  match = {
    class = "chrome-music.youtube.com__-Default"
  },
  workspace = "special",
  opacity = "0.7"
})
-----------------

windowrule {
    name = float-btop
    match:class = btop
    float = yes
}

windowrule {
    name = Virtual-Box
    match:class = VirtualBox Machine
    fullscreen = yes
}

windowrule {
    name = GPU Screen Recorder Notify
    match:title  = gsr notify
    rounding = 0
    no_focus = true
}

windowrule {
    name = Vesktop
    match:class = vesktop
    workspace = special
    opacity = 0.9
}

windowrule {
  name = UnrealEditor
  match:class = UnrealEditor
  border_size = 0
  decorate = no
  no_blur = yes
  no_dim = yes
  no_shadow = yes
}
