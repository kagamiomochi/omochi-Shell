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
    // Samples one pixel ahead of the cursor with grim (requires the grim package)
    // and mixes it gently into the glow colors.
    property bool bgAdapt: true             // Enable sampling the pixels ahead of the cursor
    property real bgMix: 0.9               // Mix amount for the head of the glow tail (0..1)
    property real bgMixTail: 0.6            // Mix amount for the older end of the glow tail
    property real bgMixOrb: 0.5             // Mix amount for the orb halo
    property real bgMixCore: 0.2            // Mix amount for the white cores (orb center and thin trail core)
    property real bgSampleDist: 56          // Sample distance ahead of the cursor (px), outside the halo
    property int bgSampleInterval: 150      // Sampling interval while the cursor is moving (ms)
    property real bgMinLightness: 0.5       // Lightness floor so dark backgrounds do not dim the glow
    property color bgColor: glowColor       // Smoothed sampled color
    Behavior on bgColor { ColorAnimation { duration: 250 } }

    // Colors actually used for drawing
    readonly property color effGlow: bgAdapt ? mixColor(glowColor, bgColor, bgMix) : glowColor
    readonly property color effTail: bgAdapt ? mixColor(glowTailColor, bgColor, bgMixTail) : glowTailColor
    readonly property color effOrb: bgAdapt ? mixColor(glowColor, bgColor, bgMixOrb) : glowColor
    readonly property color effCore: bgAdapt ? mixColor(Qt.rgba(1, 1, 1, 1), bgColor, bgMixCore) : Qt.rgba(1, 1, 1, 1)

    // Cursor tracking state used to pick the sample point
    property real lastX: 0
    property real lastY: 0
    property real dirX: 1
    property real dirY: 1
    property bool moving: false

    signal moved(real x, real y)

    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1);
    }

    // Track the (smoothed) movement direction
    onMoved: (x, y) => {
        const dx = x - lastX, dy = y - lastY;
        if (Math.hypot(dx, dy) > 0.5) {
            dirX = dirX * 0.7 + dx * 0.3;
            dirY = dirY * 0.7 + dy * 0.3;
        }
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

    // Pick a sample point ahead of the cursor, clamped to the screen under it
    function samplePoint() {
        const len = Math.hypot(dirX, dirY) || 1;
        let x = lastX + dirX / len * bgSampleDist;
        let y = lastY + dirY / len * bgSampleDist;
        for (const s of Quickshell.screens) {
            if (lastX >= s.x && lastX < s.x + s.width && lastY >= s.y && lastY < s.y + s.height) {
                x = Math.min(Math.max(x, s.x), s.x + s.width - 1);
                y = Math.min(Math.max(y, s.y), s.y + s.height - 1);
                break;
            }
        }
        return { x: Math.round(x), y: Math.round(y) };
    }

    // Poll only while the cursor is moving and the feature is active
    Timer {
        interval: root.bgSampleInterval
        repeat: true
        running: root.enabled && root.mode === "glow" && root.bgAdapt && root.moving
        onTriggered: {
            if (sampler.running)
                return;
            const p = root.samplePoint();
            // The last 3 bytes of a P6 PPM stream are the single pixel (R, G, B)
            sampler.command = ["sh", "-c",
                "grim -g '" + p.x + "," + p.y + " 1x1' -t ppm - | tail -c 3 | od -An -tu1 -w3"];
            sampler.running = true;
        }
    }

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

            Connections {
                target: root
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
