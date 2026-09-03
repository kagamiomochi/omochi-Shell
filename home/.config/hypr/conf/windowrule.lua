-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.workspace_rule({ workspace = "s[true]", gaps_in = 5, gaps_out = 30 })
hl.window_rule({ match = { fullscreen = true }, immediate = true })
hl.window_rule({ match = { title = "^$" }, float = true })
hl.window_rule({ match = { class = "fcitx5" }, no_initial_focus = true, no_focus = true })
hl.window_rule({ match = { title = "ピクチャーインピクチャー" }, float = true, keep_aspect_ratio = true, })
hl.window_rule({ match = { pin = true }, border_color = "rgba(FFAA00aa) rgba(CC7700aa)", border_size = 7 })

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

local float_rules = {
    { name = "Thunar file operation progress",      class = "thunar", title = "ファイル操作の進捗" },
    { name = "Thunar confirm replace file",         class = "thunar", title = "置換するファイルの確認" },
    { name = "Thunar change filename",              class = "thunar", title = ".*の名前を変更.*" },
    { name = "Prism Launcher Quick Setup",          class = "org.prismlauncher.PrismLauncher", title = "Prism Launcher Quick Setup.*" },
    { name = "Prism Launcher Account",              class = "org.prismlauncher.PrismLauncher", title = "Microsoftアカウントを追加.*" },
    { name = "Prism Launcher Confirm activation",   class = "org.prismlauncher.PrismLauncher", title = "有効化の確認.*" },
    { name = "Bitwarden",                           class = "zen", title = "拡張機能: (Bitwarden パスワードマネージャー) - Bitwarden — Zen Browser"},
}

for _, rule in ipairs(float_rules) do
    hl.window_rule({
        name = rule.name,
        match = { class = rule.class, title = rule.title },
        float = true
    })
end


hl.window_rule({
    name = "Discord",
    match = {
        class = "^(discord|vesktop)$"
    },
    workspace = "special"
})

hl.window_rule({
    name = "Zen Browser",
    match = {
        class = "zen"
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
    name = "UnrealEditor",
    match = {
        class = "UnrealEditor"
    },
    border_size = 0,
    opacity = "1.0 override 1.0 override 1.0 override",
    decorate = false,
    no_blur = true,
    no_dim = true,
    no_shadow = true
})

hl.window_rule({
    name = "Autodesk Fusion",
    match = {
        class = "fusion360.exe"
    },
    float = true,
    border_size = 0,
    rounding = 0,
    rounding_power = 1,
    opacity = "1.0 override 1.0 override 1.0 override",
    decorate = false,
    no_anim = true,
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    render_unfocused = true
})

hl.window_rule({
    name = "AIRI",
    match = {
        class = "ai-moeru-airi"
    },
    float = true,
    pin = true,
    border_size = 0,
    opacity = "1.0 override 1.0 override 1.0 override",
    no_blur = true,
})