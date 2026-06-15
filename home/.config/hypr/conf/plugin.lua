-- https://wiki.hypr.land/Plugins/Using-Plugins/

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
    size =18,
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

plugin:dynamic-cursors {

    mode = rotate # tilt, rotate, stretch, none

    # minimum angle difference in degrees after which the shape is changed
    # smaller values are smoother, but more expensive for hw cursors
    threshold = 2

    # for mode = rotate
    rotate {

        # length in px of the simulated stick used to rotate the cursor
        # most realistic if this is your actual cursor size
        length = 20

        # clockwise offset applied to the angle in degrees
        # this will apply to ALL shapes
        offset = 0.0
    }

    # for mode = tilt
    tilt {

        # controls how powerful the tilt is, the lower, the more power
        # this value controls at which speed (px/s) the full tilt is reached
        limit = 5000

        # relationship between speed and tilt, supports these values:
        # linear             - a linear function is used
        # quadratic          - a quadratic function is used (most realistic to actual air drag)
        # negative_quadratic - negative version of the quadratic one, feels more aggressive
        # see `activation` in `src/mode/utils.cpp` for how exactly the calculation is done
        function = negative_quadratic

        # time window (ms) over which the speed is calculated
        # higher values will make slow motions smoother but more delayed
        window = 100

        # full tilt for each side (°)
        full_tilt = 60
    }

    # for mode = stretch
    stretch {

        # controls how much the cursor is stretched
        # this value controls at which speed (px/s) the full stretch is reached
        # the full stretch being twice the original length
        limit = 3000

        # relationship between speed and stretch amount, supports these values:
        # linear             - a linear function is used
        # quadratic          - a quadratic function is used
        # negative_quadratic - negative version of the quadratic one, feels more aggressive
        # see `activation` in `src/mode/utils.cpp` for how exactly the calculation is done
        function = quadratic

        # time window (ms) over which the speed is calculated
        # higher values will make slow motions smoother but more delayed
        window = 100
    }

    # configure shake to find
    # magnifies the cursor if its is being shaken
    shake {

        # enables shake to find
        enabled = true

        # use nearest-neighbour (pixelated) scaling when shaking
        # may look weird when effects are enabled
        nearest = true

        # controls how soon a shake is detected
        # lower values mean sooner
        threshold = 6.0

        # magnification level immediately after shake start
        base = 4.0
        # magnification increase per second when continuing to shake
        speed = 4.0
        # how much the speed is influenced by the current shake intensitiy
        influence = 0.0

        # maximal magnification the cursor can reach
        # values below 1 disable the limit (e.g. 0)
        limit = 0.0

        # time in millseconds the cursor will stay magnified after a shake has ended
        timeout = 2000

        # show cursor behaviour `tilt`, `rotate`, etc. while shaking
        effects = false

        # enable ipc events for shake
        # see the `ipc` section below
        ipc = false
    }

    # use hyprcursor to get a higher resolution texture when the cursor is magnified
    # see the `hyprcursor` section below
    hyprcursor {

        # use nearest-neighbour (pixelated) scaling when magnifing beyond texture size
        # this will also have effect without hyprcursor support being enabled
        # 0 / false - never use pixelated scaling
        # 1 / true  - use pixelated when no highres image
        # 2         - always use pixleated scaling
        nearest = true

        # enable dedicated hyprcursor support
        enabled = true

        # resolution in pixels to load the magnified shapes at
        # be warned that loading a very high-resolution image will take a long time and might impact memory consumption
        # -1 means we use [normal cursor size] * [shake:base option]
        resolution = -1

        # shape to use when clientside cursors are being magnified
        # see the shape-name property of shape rules for possible names
        # specifying clientside will use the actual shape, but will be pixelated
        fallback = clientside
    }
}
