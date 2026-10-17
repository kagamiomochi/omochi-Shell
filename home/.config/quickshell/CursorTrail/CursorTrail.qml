import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// Cursor trail overlay
//   mode: "blur" = motion-blur-like afterimage / "glow" = light tail + glowing orb
//   Switch at runtime: qs ipc call trail set glow
//   Cursor visibility (glow mode): qs ipc call trail hideCursor|showCursor|toggleCursor
//   Background color adaptation (glow mode): qs ipc call trail bgOn|bgOff|bgToggle
//   Click particles (glow mode): qs ipc call trail particlesOn|particlesOff|particlesToggle
Scope {
    id: root

    // Master switch. When false, the position stream stops and the overlay is hidden.
    property bool enabled: true
    property string mode: "glow"

    // In glow mode, hide the real cursor and draw an orb instead.
    // Switchable at runtime via IPC.
    property bool hideCursor: true
    // True only while the real cursor is actually hidden (and the orb is drawn)
    readonly property bool cursorHidden: enabled && mode === "glow" && hideCursor

    // ---- Tunable parameters ----
    property color glowColor: "#73bfff"     // Color at the head of the glow tail (cursor side)
    property color glowTailColor: "#c77dff" // Color at the end of the glow tail (older side). Same as glowColor = single color
    property real glowLifetime: 450         // Time until the glow tail fades out (ms)
    property real blurLifetime: 200         // Time until the afterimage fades out (ms)
    property real orbRadius: 7             // Radius of the glow orb that replaces the cursor (px)
    property real cursorScale: 1.0          // Extra scale for the afterimage (also applies to the fallback arrow)
    property string cursorTheme: ""         // Empty = use XCURSOR_THEME
    property int cursorSize: 0              // 0 = use XCURSOR_SIZE
    property var cursorInfo: null           // Output of cursor-image.py (image path and hotspot)

    // ---- Background color adaptation ----
    // Samples the pixel directly under the cursor with grim (requires the grim package)
    // and mixes it gently into the glow colors.
    // To keep the overlay itself out of the captured pixel, a 1px hole is punched
    // into the overlay at the sample point just before grim runs.
    property bool bgAdapt: true             // Enable sampling the pixel under the cursor
    property real bgMix: 0.9               // Mix amount for the head of the glow tail (0..1)
    property real bgMixTail: 0.6            // Mix amount for the older end of the glow tail
    property real bgMixOrb: 0.5             // Mix amount for the orb halo
    property real bgMixCore: 0.2            // Mix amount for the white cores (orb center and thin trail core)
    property int bgSampleInterval: 150      // Sampling interval while the cursor is moving (ms)
    property int bgHoleSettleMs: 50         // Wait after opening the hole so the compositor shows it (ms)
    property real bgMinLightness: 0.5       // Lightness floor so dark backgrounds do not dim the glow
    property color bgColor: glowColor       // Smoothed sampled color
    Behavior on bgColor { ColorAnimation { duration: 250 } }

    // Hole state: while holeActive is true, the overlay has a 1x1 transparent hole
    // at global logical coordinates (holeX, holeY).
    property bool holeActive: false
    property int holeX: 0
    property int holeY: 0

    // Colors actually used for drawing
    readonly property color effGlow: bgAdapt ? mixColor(glowColor, bgColor, bgMix) : glowColor
    readonly property color effTail: bgAdapt ? mixColor(glowTailColor, bgColor, bgMixTail) : glowTailColor
    readonly property color effOrb: bgAdapt ? mixColor(glowColor, bgColor, bgMixOrb) : glowColor
    readonly property color effCore: bgAdapt ? mixColor(Qt.rgba(1, 1, 1, 1), bgColor, bgMixCore) : Qt.rgba(1, 1, 1, 1)

    // ---- Click particles (glow mode) ----
    // Needs click-stream.py (evdev), so the user must be in the `input` group.
    property bool clickParticles: true      // Emit particles when a mouse button is pressed
    property int particleCount: 16          // Particles per click
    property real particleSpeed: 220        // Max initial speed (px/s)
    property real particleLifetime: 650     // Max particle lifetime (ms)
    property real particleSize: 3.0         // Max particle radius (px)

    // Latest cursor position (global logical coordinates)
    property real lastX: 0
    property real lastY: 0
    property bool moving: false

    signal moved(real x, real y)
    signal clicked(real x, real y)

    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1);
    }

    onMoved: (x, y) => {
        lastX = x;
        lastY = y;
        moving = true;
        idleTimer.restart();
    }

    Timer {
        id: idleTimer
        interval: 500
        onTriggered: root.moving = false
    }

    // Pick the sample point: the pixel directly under the cursor, clamped to its screen
    function samplePoint() {
        let x = Math.floor(lastX);
        let y = Math.floor(lastY);
        for (const s of Quickshell.screens) {
            if (lastX >= s.x && lastX < s.x + s.width && lastY >= s.y && lastY < s.y + s.height) {
                x = Math.min(Math.max(x, s.x), s.x + s.width - 1);
                y = Math.min(Math.max(y, s.y), s.y + s.height - 1);
                break;
            }
        }
        return { x: x, y: y };
    }

    // Step 1: open the hole at the cursor and wait for it to be shown.
    // Poll only while the cursor is moving and the feature is active.
    Timer {
        interval: root.bgSampleInterval
        repeat: true
        running: root.enabled && root.mode === "glow" && root.bgAdapt && root.moving
        onTriggered: {
            if (sampler.running || root.holeActive)
                return;
            const p = root.samplePoint();
            root.holeX = p.x;
            root.holeY = p.y;
            root.holeActive = true;
            settleTimer.restart();
        }
    }

    // Step 2: after the hole is visible, capture exactly that pixel.
    Timer {
        id: settleTimer
        interval: root.bgHoleSettleMs
        onTriggered: {
            // The last 3 bytes of a P6 PPM stream are the single pixel (R, G, B)
            sampler.command = ["sh", "-c",
                "grim -g '" + root.holeX + "," + root.holeY + " 1x1' -t ppm - | tail -c 3 | od -An -tu1 -w3"];
            sampler.running = true;
        }
    }

    // Step 3: close the hole once grim has finished (also on failure).
    Process {
        id: sampler
        command: []
        stdout: SplitParser {
            onRead: line => {
                const v = line.trim().split(/\s+/).map(Number);
                if (v.length !== 3 || v.some(isNaN))
                    return;
                const c = Qt.rgba(v[0] / 255, v[1] / 255, v[2] / 255, 1);
                // Raise lightness to the floor, keep hue and saturation
                const l = Math.max(c.hslLightness, root.bgMinLightness);
                root.bgColor = Qt.hsla(Math.max(c.hslHue, 0), c.hslSaturation, l, 1);
            }
        }
        onExited: (exitCode, exitStatus) => root.holeActive = false
    }

    // Toggle Hyprland's real cursor visibility
    function applyCursor() {
        Quickshell.execDetached([
            "hyprctl", "eval",
            "hl.config({ cursor = { invisible = " + (root.cursorHidden ? "true" : "false") + " } })"
        ]);
    }

    onCursorHiddenChanged: applyCursor()

    // Sync on startup, and always restore the cursor when the shell goes away
    Component.onCompleted: applyCursor()
    Component.onDestruction: {
        Quickshell.execDetached([
            "hyprctl", "eval",
            "hl.config({ cursor = { invisible = false } })"
        ]);
    }

    // Cursor position stream
    Process {
        running: root.enabled
        command: ["python3", Quickshell.shellPath("CursorTrail/cursor-stream.py")]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(" ");
                root.moved(parseFloat(p[0]), parseFloat(p[1]));
            }
        }
    }

    // Mouse button press stream. Runs only while particles can actually be shown.
    Process {
        running: root.enabled && root.mode === "glow" && root.clickParticles
        command: ["python3", Quickshell.shellPath("CursorTrail/click-stream.py")]
        stdout: SplitParser {
            onRead: line => root.clicked(root.lastX, root.lastY)
        }
    }

    // Convert the real cursor theme image to PNG (falls back to an arrow on failure)
    Process {
        running: true
        command: [
            "python3", Quickshell.shellPath("CursorTrail/cursor-image.py"),
            root.cursorTheme,
            root.cursorSize > 0 ? String(root.cursorSize) : ""
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.cursorInfo = JSON.parse(line);
                } catch (e) {}
            }
        }
    }

    IpcHandler {
        target: "trail"
        function set(m: string): void {
            if (m === "glow" || m === "blur")
                root.mode = m;
        }
        function on(): void { root.enabled = true }
        function off(): void { root.enabled = false }
        function toggle(): void { root.enabled = !root.enabled }

        function hideCursor(): void { root.hideCursor = true }
        function showCursor(): void { root.hideCursor = false }
        function toggleCursor(): void { root.hideCursor = !root.hideCursor }

        function bgOn(): void { root.bgAdapt = true }
        function bgOff(): void { root.bgAdapt = false }
        function bgToggle(): void { root.bgAdapt = !root.bgAdapt }

        function particlesOn(): void { root.clickParticles = true }
        function particlesOff(): void { root.clickParticles = false }
        function particlesToggle(): void { root.clickParticles = !root.clickParticles }
    }

    // Canvas that keeps its own history and draws it
    component TrailCanvas: Canvas {
        id: c

        // "glow" = thick colored band / "core" = thin white core / "ghost" = cursor-shaped afterimage
        property string kind: "glow"
        property real lifetime: 450
        property real offX: 0
        property real offY: 0
        property real blurAmount: 0
        property color tint: "#73bfff"
        property color tailTint: "#73bfff"
        property real scaleFactor: 1.0
        property var cursorInfo: null
        property string imgUrl: cursorInfo ? "file://" + cursorInfo.path : ""
        property var pts: []

        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        onImgUrlChanged: {
            if (imgUrl !== "")
                loadImage(imgUrl);
        }
        onImageLoaded: requestPaint()

        layer.enabled: blurAmount > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: c.blurAmount
            blurMax: 48
        }

        function add(x, y) {
            if (!visible) {
                pts = [];
                return;
            }
            pts.push({ x: x - offX, y: y - offY, t: Date.now() });
            tick.running = true;
            requestPaint();
        }

        function arrow(ctx, x, y, s) {
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(x, y + 16 * s);
            ctx.lineTo(x + 4 * s, y + 12.5 * s);
            ctx.lineTo(x + 7 * s, y + 19 * s);
            ctx.lineTo(x + 9.5 * s, y + 18 * s);
            ctx.lineTo(x + 6.5 * s, y + 11.5 * s);
            ctx.lineTo(x + 11 * s, y + 11.5 * s);
            ctx.closePath();
            ctx.fill();
        }

        // Subdivide a quadratic Bezier (a -> b, control point c) and append the points to out
        function addQuad(out, a, c, b, step) {
            const len = Math.hypot(c.x - a.x, c.y - a.y) + Math.hypot(b.x - c.x, b.y - c.y);
            const n = Math.max(1, Math.min(64, Math.ceil(len / step)));
            for (let s = 1; s <= n; s++) {
                const u = s / n, v = 1 - u;
                out.push({
                    x: v * v * a.x + 2 * v * u * c.x + u * u * b.x,
                    y: v * v * a.y + 2 * v * u * c.y + u * u * b.y,
                    t: a.t + (b.t - a.t) * u
                });
            }
        }

        // Turn the discrete sample points into a dense point list along a smooth curve
        // instead of a polyline. Midpoints of adjacent samples are connected by quadratic
        // Beziers whose control point is the sample in between. This avoids overshoot
        // and keeps the joins smooth.
        function smooth(step) {
            const n = pts.length;
            const mid = (a, b) => ({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, t: (a.t + b.t) / 2 });
            const out = [pts[0]];
            if (n < 2)
                return out;
            let cur = pts[0];
            for (let i = 1; i < n - 1; i++) {
                const end = mid(pts[i], pts[i + 1]);
                addQuad(out, cur, pts[i], end, step);
                cur = end;
            }
            const last = pts[n - 1];
            addQuad(out, cur, mid(cur, last), last, step);
            return out;
        }

        Timer {
            id: tick
            interval: 16
            repeat: true
            onTriggered: c.requestPaint()
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const now = Date.now();
            while (pts.length > 0 && now - pts[0].t > lifetime)
                pts.shift();
            if (pts.length === 0) {
                tick.running = false;
                return;
            }
            if (pts.length < 2)
                return;

            if (kind === "ghost") {
                // Place cursor-shaped afterimages along the path. Overlaps get denser,
                // which gives a blurred look.
                ctx.fillStyle = "white";
                for (let i = 1; i < pts.length; i++) {
                    const a = pts[i - 1], b = pts[i];
                    const d = Math.hypot(b.x - a.x, b.y - a.y);
                    const n = Math.min(24, Math.max(1, Math.floor(d / 4)));
                    for (let j = 1; j <= n; j++) {
                        const f = j / n;
                        const t = a.t + (b.t - a.t) * f;
                        const k = 1 - (now - t) / lifetime;
                        if (k <= 0)
                            continue;
                        ctx.globalAlpha = 0.16 * k * k;
                        const gx = a.x + (b.x - a.x) * f;
                        const gy = a.y + (b.y - a.y) * f;
                        if (cursorInfo && isImageLoaded(imgUrl)) {
                            // Draw so that the hotspot lands on the path point
                            const s = cursorInfo.scale * scaleFactor;
                            ctx.drawImage(imgUrl,
                                          gx - cursorInfo.xhot * s,
                                          gy - cursorInfo.yhot * s,
                                          cursorInfo.w * s,
                                          cursorInfo.h * s);
                        } else {
                            arrow(ctx, gx, gy, scaleFactor);
                        }
                    }
                }
                ctx.globalAlpha = 1;
                return;
            }

            // glow / core: a band that gets thinner and fainter toward older segments.
            // Connecting raw samples looks angular at high speed, so draw a densified curve.
            let total = 0;
            for (let i = 1; i < pts.length; i++)
                total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
            // Subdivision step, capped so long trails do not produce too many points
            const step = Math.max(kind === "glow" ? 3 : 2, total / 400);
            const dense = smooth(step);

            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            for (let i = 1; i < dense.length; i++) {
                const a = dense[i - 1], b = dense[i];
                const segLen = Math.hypot(b.x - a.x, b.y - a.y);
                if (segLen < 0.01)
                    continue;
                const k = 1 - (now - b.t) / lifetime;
                if (k <= 0)
                    continue;

                let alpha, width, r, g, bl;
                if (kind === "glow") {
                    alpha = 0.85 * k * k;
                    width = 3 + 14 * k;
                    // Older segments shift toward the tail color. The tail gets faint,
                    // so progress the color change early.
                    const m = Math.min(1, (1 - k) * 1.5);
                    r = tint.r + (tailTint.r - tint.r) * m;
                    g = tint.g + (tailTint.g - tint.g) * m;
                    bl = tint.b + (tailTint.b - tint.b) * m;
                } else {
                    alpha = 0.95 * k;
                    width = 1 + 2.5 * k;
                    r = tint.r; g = tint.g; bl = tint.b;
                }
                // Round caps get denser where they overlap, so divide by the overlap
                // count to keep the apparent opacity uniform
                const a1 = 1 - Math.pow(1 - alpha, Math.min(1, segLen / width));

                ctx.strokeStyle = Qt.rgba(r, g, bl, a1);
                ctx.lineWidth = width;
                ctx.beginPath();
                ctx.moveTo(a.x, a.y);
                ctx.lineTo(b.x, b.y);
                ctx.stroke();
            }
        }
    }

    // Canvas that draws click particles: soft glowing dots that burst outward and fade
    component ParticleCanvas: Canvas {
        id: pc

        property color tint: "#73bfff"
        property color tailTint: "#c77dff"
        property color coreTint: "white"
        property real offX: 0
        property real offY: 0
        property var parts: []
        property real lastTime: 0

        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        // x, y: global cursor position
        function burst(x, y) {
            if (!visible)
                return;
            const now = Date.now();
            if (!ptick.running)
                lastTime = now;
            for (let i = 0; i < root.particleCount; i++) {
                const ang = Math.random() * Math.PI * 2;
                const sp = root.particleSpeed * (0.3 + 0.7 * Math.random());
                parts.push({
                    x: x - offX,
                    y: y - offY,
                    vx: Math.cos(ang) * sp,
                    vy: Math.sin(ang) * sp,
                    t0: now,
                    life: root.particleLifetime * (0.5 + 0.5 * Math.random()),
                    size: root.particleSize * (0.4 + 0.6 * Math.random()),
                    mix: Math.random()   // 0 = head color, 1 = tail color
                });
            }
            ptick.running = true;
            requestPaint();
        }

        Timer {
            id: ptick
            interval: 16
            repeat: true
            onTriggered: pc.requestPaint()
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const now = Date.now();
            const dt = Math.min(0.05, (now - lastTime) / 1000);
            lastTime = now;

            parts = parts.filter(p => now - p.t0 < p.life);
            if (parts.length === 0) {
                ptick.running = false;
                return;
            }

            // Strong friction: the speed drops to about 4% per second
            const drag = Math.pow(0.04, dt);
            // Overlapping particles add up, which makes them look like light
            ctx.globalCompositeOperation = "lighter";

            for (const p of parts) {
                p.x += p.vx * dt;
                p.y += p.vy * dt;
                p.vx *= drag;
                p.vy *= drag;

                const k = 1 - (now - p.t0) / p.life;
                const r = p.size * (0.4 + 0.6 * k);
                const cr = tint.r + (tailTint.r - tint.r) * p.mix;
                const cg = tint.g + (tailTint.g - tint.g) * p.mix;
                const cb = tint.b + (tailTint.b - tint.b) * p.mix;
                const a = k * k;

                const grad = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r * 3);
                grad.addColorStop(0, Qt.rgba(coreTint.r, coreTint.g, coreTint.b, 0.95 * a));
                grad.addColorStop(0.35, Qt.rgba(cr, cg, cb, 0.8 * a));
                grad.addColorStop(1, Qt.rgba(cr, cg, cb, 0));
                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.arc(p.x, p.y, r * 3, 0, Math.PI * 2);
                ctx.fill();
            }
            ctx.globalCompositeOperation = "source-over";
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            visible: root.enabled
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "cursor-trail"
            mask: Region {}   // Empty Region makes the window fully click-through

            // Hole position in this window's local coordinates.
            // When no hole is active it is moved above the window (y = -10), so the
            // mask below covers the whole window and nothing is cut out.
            readonly property real holeLX: root.holeActive ? root.holeX - modelData.x : -10
            readonly property real holeLY: root.holeActive ? root.holeY - modelData.y : -10

            // Mask source: opaque everywhere except a 1x1 hole at (holeLX, holeLY).
            // Built from four rectangles around the hole.
            Item {
                id: holeMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                // Above the hole
                Rectangle {
                    x: 0
                    y: 0
                    width: holeMask.width
                    height: Math.max(0, win.holeLY)
                    color: "white"
                }
                // Below the hole
                Rectangle {
                    x: 0
                    y: win.holeLY + 1
                    width: holeMask.width
                    height: Math.max(0, holeMask.height - (win.holeLY + 1))
                    color: "white"
                }
                // Left of the hole (same row)
                Rectangle {
                    x: 0
                    y: win.holeLY
                    width: Math.max(0, win.holeLX)
                    height: 1
                    color: "white"
                }
                // Right of the hole (same row)
                Rectangle {
                    x: win.holeLX + 1
                    y: win.holeLY
                    width: Math.max(0, holeMask.width - (win.holeLX + 1))
                    height: 1
                    color: "white"
                }
            }

            // All drawn content lives here so the hole cuts through everything.
            // The layer (and the mask effect) is enabled only while a hole is open,
            // so the full-screen offscreen pass costs nothing the rest of the time.
            Item {
                id: content
                anchors.fill: parent

                layer.enabled: root.holeActive
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: holeMask
                }

                // Glow tail: blurred thick band + thin core
                TrailCanvas {
                    id: glow
                    kind: "glow"
                    visible: root.mode === "glow"
                    lifetime: root.glowLifetime
                    tint: root.effGlow
                    tailTint: root.effTail
                    blurAmount: 0.7
                    offX: win.modelData.x
                    offY: win.modelData.y
                }
                TrailCanvas {
                    id: core
                    kind: "core"
                    visible: root.mode === "glow"
                    lifetime: root.glowLifetime
                    tint: root.effCore
                    offX: win.modelData.x
                    offY: win.modelData.y
                }

                // Motion-blur style: lightly blurred cursor-shaped afterimages
                TrailCanvas {
                    id: ghost
                    kind: "ghost"
                    visible: root.mode === "blur"
                    lifetime: root.blurLifetime
                    scaleFactor: root.cursorScale
                    cursorInfo: root.cursorInfo
                    blurAmount: 0.15
                    offX: win.modelData.x
                    offY: win.modelData.y
                }

                // Glowing orb that replaces the real cursor while it is hidden
                Item {
                    id: orb
                    visible: root.cursorHidden
                    property real cx: -100
                    property real cy: -100

                    // Blurred halo
                    Item {
                        width: 96
                        height: 96
                        x: orb.cx - width / 2
                        y: orb.cy - height / 2
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 32
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: root.orbRadius * 2
                            height: width
                            radius: width / 2
                            color: root.effOrb
                            opacity: 0.9
                        }
                    }

                    // Bright core
                    Rectangle {
                        width: root.orbRadius * 0.7
                        height: width
                        radius: width / 2
                        x: orb.cx - width / 2
                        y: orb.cy - height / 2
                        color: root.effCore
                    }
                }

                // Click particles (drawn above the orb)
                ParticleCanvas {
                    id: particles
                    visible: root.mode === "glow"
                    tint: root.effGlow
                    tailTint: root.effTail
                    coreTint: root.effCore
                    offX: win.modelData.x
                    offY: win.modelData.y
                }
            }

            Connections {
                target: root
                function onClicked(x, y) {
                    // Only the screen under the cursor spawns particles
                    const sx = win.modelData.x, sy = win.modelData.y;
                    if (x >= sx && x < sx + win.modelData.width && y >= sy && y < sy + win.modelData.height)
                        particles.burst(x, y);
                }
                function onMoved(x, y) {
                    glow.add(x, y);
                    core.add(x, y);
                    ghost.add(x, y);
                    orb.cx = x - win.modelData.x;
                    orb.cy = y - win.modelData.y;
                }
            }
        }
    }
}
