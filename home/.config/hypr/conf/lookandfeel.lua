#####################
### LOOK AND FEEL ###
#####################

# Refer to https://wiki.hypr.land/Configuring/Variables/

# https://wiki.hypr.land/Configuring/Variables/#general
general {
    gaps_in = 3
    gaps_out = 10

    border_size = 1

    col.active_border = rgba(C56E6Eff) rgba(D69A6Bff) rgba(E6C35Cff) rgba(87A37Eff) rgba(6B8EADff) rgba(5E6C84ff) rgba(9B7E9Bff)
    col.inactive_border = rgba(ffffff80)

    # Set to true enable resizing windows by clicking and dragging on borders and gaps
    resize_on_border = false

    # Please see https://wiki.hypr.land/Configuring/Tearing/ before you turn this on
    allow_tearing = true

    layout = dwindle

    snap {
        enabled = true
        window_gap = 10
        monitor_gap = 10
    }

}

# https://wiki.hypr.land/Configuring/Variables/#decoration
decoration {
    rounding = 15
    rounding_power = 3

    # Change transparency of focused and unfocused windows
    active_opacity = 1.0
    inactive_opacity = 0.8

    shadow {
        enabled = false
    }

    # https://wiki.hypr.land/Configuring/Variables/#blur
    blur {
        enabled = true
        size = 8
        passes = 3

        special = true
        popups = true
        input_methods = true
    }
}

# https://wiki.hypr.land/Configuring/Variables/#animations
animations {
    enabled = yes, please :)

    # Default curves, see https://wiki.hypr.land/Configuring/Animations/#curves
    #        NAME,           X0,   Y0,   X1,   Y1
    bezier = easeOutQuint,   0.23, 1,    0.32, 1
    bezier = easeInOutCubic, 0.65, 0.05, 0.36, 1
    bezier = linear,         0,    0,    1,    1
    bezier = almostLinear,   0.5,  0.5,  0.75, 1
    bezier = quick,          0.15, 0,    0.1,  1
    bezier = softAccl,     0.26, 0.92, 0.41, 1

    # Default animations, see https://wiki.hypr.land/Configuring/Animations/
    #           NAME,          ONOFF, SPEED, CURVE,        [STYLE]
    animation = global,        1,     10,    default
    animation = border,        1,     5.39,  easeOutQuint
    animation = windows,       1,     4.79,  easeOutQuint
    animation = windowsIn,     1,     4.1,   easeOutQuint, popin 87%
    animation = windowsOut,    1,     1.49,  linear,       popin 87%
    animation = fadeIn,        1,     1.73,  almostLinear
    animation = fadeOut,       1,     1.46,  almostLinear
    animation = fade,          1,     3.03,  quick
    animation = layers,        1,     3.81,  easeOutQuint
    animation = layersIn,      1,     4,     easeOutQuint, fade
    animation = layersOut,     1,     1.5,   linear,       fade
    animation = fadeLayersIn,  1,     1.79,  almostLinear
    animation = fadeLayersOut, 1,     1.39,  almostLinear
    animation = workspacesIn,  1,     4,  softAccl, slidefade 20%
    animation = workspacesOut, 1,     4,  softAccl, slidefade 20%
    animation = specialWorkspace, 1, 4, softAccl, slidevert
    animation = zoomFactor,    1,     7,     quick
    animation = borderangle, 1, 50, linear, loop
}

# See https://wiki.hypr.land/Configuring/Dwindle-Layout/ for more
dwindle {
    pseudotile = true # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
    preserve_split = true # You probably want this
}

# See https://wiki.hypr.land/Configuring/Master-Layout/ for more
master {
    new_status = master
}

# https://wiki.hypr.land/Configuring/Variables/#misc
misc {
    force_default_wallpaper = -1 # Set to 0 or 1 to disable the anime mascot wallpapers
    disable_hyprland_logo = false # If true disables the random hyprland logo / anime girl background. :(
    animate_manual_resizes = true
    enable_swallow = true
    swallow_regex = ^(kitty)$
}
