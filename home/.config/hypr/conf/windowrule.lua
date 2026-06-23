-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.workspace_rule({ workspace = "s[true]", gaps_in = 5, gaps_out = 30 })
hl.window_rule({ match = { fullscreen = true }, immediate = true })
hl.window_rule({ match = { title = "^$" }, float = true })
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
  opacity = 0.7
})

hl.window_rule({
    name = "PiP",
    match = {
        title = "ピクチャーインピクチャー"
    },
    float = true,
    keep_aspect_ratio = true,
})

hl.window_rule({
    name = "btop",
    match = {
        class = "btop"
    },
    float = true
})

hl.window_rule({
    name = "VirtualBox",
    match = {
        class = "VirtualBox Machine"
    },
    fullscreen = true
})

hl.window_rule({
    name = "gsr notify",
    match = {
        class = "gsr notify"
    },
    rounding = 0,
    no_focus = true
})

hl.window_rule({
    name = "Vesktop",
    match = {
        class = "vesktop"
    },
    workspace = "special",
    opacity = 0.9
})

hl.window_rule({
    name = "UnrealEditor",
    match = {
        class = "UnrealEditor"
    },
    border_size = 0,
    decorate = false,
    no_blur = true,
    no_dim = true,
    no_shadow = true
})
