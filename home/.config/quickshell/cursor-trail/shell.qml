import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// カーソルトレイル
//   mode: "blur" = モーションブラー風の残像 / "glow" = 光の尾 / "both" = 両方
//   実行中の切り替え: qs -c cursor-trail ipc call trail set glow
ShellRoot {
    id: root

    property string mode: "glow"

    // ---- 調整用パラメータ ----
    property color glowColor: "#73bfff"   // 光の尾の先頭(カーソル側)の色
    property color glowTailColor: "#c77dff" // 光の尾の末端(古い側)の色。先頭と同じ色にすれば単色に戻る
    property real glowLifetime: 450       // 光の尾が消えるまで(ms)
    property real blurLifetime: 200       // 残像が消えるまで(ms)
    property real cursorScale: 1.0        // 残像サイズの追加倍率(画像が使えない時の矢印にも効く)
    property string cursorTheme: ""       // 空なら XCURSOR_THEME を使う
    property int cursorSize: 0            // 0 なら XCURSOR_SIZE を使う
    property var cursorInfo: null         // cursor-image.py の出力(画像パスとホットスポット)

    signal moved(real x, real y)

    // カーソル位置のストリーム
    Process {
        running: true
        command: ["python3", Quickshell.shellPath("cursor-stream.py")]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(" ");
                root.moved(parseFloat(p[0]), parseFloat(p[1]));
            }
        }
    }

    // 実際のカーソルテーマ画像を PNG 化して取得(失敗したら矢印にフォールバック)
    Process {
        running: true
        command: [
            "python3", Quickshell.shellPath("cursor-image.py"),
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
            root.mode = m;
        }
    }

    // 履歴を持って自分で描画するキャンバス
    component TrailCanvas: Canvas {
        id: c

        // "glow" = 太い色付きの帯 / "core" = 細い白い芯 / "ghost" = カーソル形の残像
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

        // 3点の二次ベジェ(a → b、制御点 c)を細かく分割して out に追加する
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

        // 離散的なサンプル点を、折れ線ではなく滑らかな曲線に直した細かい点列にする。
        // 隣り合う点の中点どうしを、間の点を制御点とする二次ベジェでつなぐ。
        // 行き過ぎ(オーバーシュート)が起きず、継ぎ目も滑らかになる
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
                // 経路上にカーソル形の残像を並べる。重なるほど濃くなり、ブレた見た目になる
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
                            // ホットスポットが経路上の点に来るように描く
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

            // glow / core: 古い区間ほど細く・薄くなる帯。
            // サンプル点をそのまま結ぶと高速移動で角ばるので、曲線化して細かく分割して描く
            let total = 0;
            for (let i = 1; i < pts.length; i++)
                total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
            // 分割の間隔。長い軌跡でも点列が増えすぎないよう上限を設ける
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
                    // 古い区間ほど末端色に寄せる。末端は薄くなるので、色の変化は早めに進める
                    const m = Math.min(1, (1 - k) * 1.5);
                    r = tint.r + (tailTint.r - tint.r) * m;
                    g = tint.g + (tailTint.g - tint.g) * m;
                    bl = tint.b + (tailTint.b - tint.b) * m;
                } else {
                    alpha = 0.95 * k;
                    width = 1 + 2.5 * k;
                    r = 1; g = 1; bl = 1;
                }
                // 丸い端が重なる分だけ濃くなるので、重なり回数で割って見た目の濃さを揃える
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
            mask: Region {}   // 空のRegionでクリックを完全に透過

            // 光の尾: ぼかした太い帯 + 細い芯
            TrailCanvas {
                id: glow
                kind: "glow"
                visible: root.mode !== "blur"
                lifetime: root.glowLifetime
                tint: root.glowColor
                tailTint: root.glowTailColor
                blurAmount: 0.7
                offX: win.modelData.x
                offY: win.modelData.y
            }
            TrailCanvas {
                id: core
                kind: "core"
                visible: root.mode !== "blur"
                lifetime: root.glowLifetime
                offX: win.modelData.x
                offY: win.modelData.y
            }

            // モーションブラー風: カーソル形の残像を軽くぼかす
            TrailCanvas {
                id: ghost
                kind: "ghost"
                visible: root.mode !== "glow"
                lifetime: root.blurLifetime
                scaleFactor: root.cursorScale
                cursorInfo: root.cursorInfo
                blurAmount: 0.15
                offX: win.modelData.x
                offY: win.modelData.y
            }

            Connections {
                target: root
                function onMoved(x, y) {
                    glow.add(x, y);
                    core.add(x, y);
                    ghost.add(x, y);
                }
            }
        }
    }
}
