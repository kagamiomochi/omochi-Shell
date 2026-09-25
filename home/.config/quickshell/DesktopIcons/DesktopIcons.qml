import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// xfdesktop的なデスクトップアイコン表示。
// shell.qml から `DesktopIcons {}` として読み込むこと。
//
// 仕組み:
//  1. scripts/list-desktop-icons.sh が ~/Desktop を走査してJSONを吐く
//  2. Process + StdioCollector でその出力を受け取り ListModel に詰める
//  3. 各アイコンの位置は positionsFile (JSON) に保存/復元する
//  4. Bottom レイヤーの全画面 PanelWindow 上にアイコンを並べる
//     (通常ウィンドウの下、壁紙の上に表示される)
Scope {
    id: root

    // ~/Desktop に相当するディレクトリ
    property string desktopPath: Quickshell.env("HOME") + "/Desktop"

    // list-desktop-icons.sh の場所。
    // このファイルと同じ quickshell 設定内に置いてある想定。
    // Quickshell.shellDir が使えない古いバージョンでは
    // 下の行を Quickshell.shellRoot に読み替えるか、絶対パスに変更すること。
    property string scriptPath: Quickshell.shellDir + "/DesktopIcons/scripts/list-desktop-icons.sh"

    // アイコン位置の保存先
    property string positionsFile: Quickshell.env("HOME") + "/.local/state/quickshell/desktop-icons.json"

    // アイコンを表示する画面。既定では全画面に表示する。
    // プライマリモニターだけに出したい場合は [Quickshell.screens[0]] などに変更する。
    property var targetScreens: Quickshell.screens

    property int cellWidth: 90
    property int cellHeight: 100
    property int columns: 6
    property int marginTop: 40
    property int marginLeft: 20
    property int iconWidth: 88
    property int iconHeight: 96

    // true: ドラッグ後に cellWidth/cellHeight のグリッドへスナップする
    // false: 自由配置(ドロップした場所そのまま)
    property bool snapToGrid: true

    // 表示ON/OFF。IpcHandler経由でコマンドから切り替えられる
    property bool enabled: false

    // inotifywait (inotify-tools) が使えない場合だけ使うポーリング間隔(ミリ秒)。
    // 0以下でポーリング自体を無効化(その場合、inotifywaitが無いと変化が反映されない)。
    property int fallbackPollIntervalMs: 5000

    // inotifywait がまともに起動できなかったときに true になる
    property bool _watchUnavailable: false
    property double _watchStartedAt: 0

    ListModel { id: iconModel }

    FileView {
        id: positionsView
        path: root.positionsFile
        watchChanges: false

        JsonAdapter {
            id: positionsData
            property var icons: ({})
        }
    }

    function savePositions() {
        positionsView.writeAdapter()
    }

    // model上のindexとfile名から、そのアイコンが今いる(べき)グリッドセルを返す
    function cellOf(file, idx) {
        const saved = positionsData.icons[file]
        if (saved) {
            return {
                col: Math.round((saved.x - root.marginLeft) / root.cellWidth),
                row: Math.round((saved.y - root.marginTop) / root.cellHeight)
            }
        }
        return { col: idx % root.columns, row: Math.floor(idx / root.columns) }
    }

    // 指定セルを excludeFile 以外の誰かが占有していないか
    function isCellTaken(col, row, excludeFile) {
        for (let i = 0; i < iconModel.count; i++) {
            const file = iconModel.get(i).file
            if (file === excludeFile) continue
            const c = root.cellOf(file, i)
            if (c.col === col && c.row === row) return true
        }
        return false
    }

    // candidateCol/candidateRow から一番近い空きセルを螺旋状に探して返す
    function findFreeCell(candidateCol, candidateRow, excludeFile) {
        const col0 = Math.max(0, candidateCol)
        const row0 = Math.max(0, candidateRow)
        if (!root.isCellTaken(col0, row0, excludeFile)) return { col: col0, row: row0 }

        for (let radius = 1; radius <= 64; radius++) {
            for (let dy = -radius; dy <= radius; dy++) {
                for (let dx = -radius; dx <= radius; dx++) {
                    if (Math.max(Math.abs(dx), Math.abs(dy)) !== radius) continue
                    const col = col0 + dx
                    const row = row0 + dy
                    if (col < 0 || row < 0) continue
                    if (!root.isCellTaken(col, row, excludeFile)) return { col: col, row: row }
                }
            }
        }
        return { col: col0, row: row0 } // 空きが見つからなければ諦めて重ねる
    }

    // 選択中のアイコン(fileをキーにしたセット)。矩形選択・クリック選択で更新する
    property var selectedFiles: ({})

    function selectOnly(file) {
        var sel = {}
        sel[file] = true
        root.selectedFiles = sel
    }

    function toggleSelect(file) {
        var sel = {}
        for (var key in root.selectedFiles) sel[key] = true
        if (sel[file]) delete sel[file]
        else sel[file] = true
        root.selectedFiles = sel
    }

    function clearSelection() {
        root.selectedFiles = {}
    }

    // model上のindexとfile名から、そのアイコンの現在の画面上矩形(x,y,幅,高さ)を返す
    function iconRect(file, idx) {
        const saved = positionsData.icons[file]
        let px, py
        if (saved) {
            px = saved.x
            py = saved.y
        } else {
            const col = idx % root.columns
            const row = Math.floor(idx / root.columns)
            px = root.marginLeft + col * root.cellWidth
            py = root.marginTop + row * root.cellHeight
        }
        return { x: px, y: py, width: root.iconWidth, height: root.iconHeight }
    }

    function _rectsIntersect(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by
    }

    // 矩形選択の範囲(親アイテム基準の座標)に入っているアイコンを選択状態にする
    function updateMarqueeSelection(rx, ry, rw, rh) {
        const sel = {}
        for (let i = 0; i < iconModel.count; i++) {
            const file = iconModel.get(i).file
            const r = root.iconRect(file, i)
            if (root._rectsIntersect(rx, ry, rw, rh, r.x, r.y, r.width, r.height)) {
                sel[file] = true
            }
        }
        root.selectedFiles = sel
    }

    function refresh() {
        scanProcess.running = false
        scanProcess.running = true
    }

    Process {
        id: scanProcess
        command: ["bash", root.scriptPath, root.desktopPath]

        stdout: StdioCollector {
            id: scanOutput
            onStreamFinished: {
                let parsed
                try {
                    parsed = JSON.parse(scanOutput.text)
                } catch (e) {
                    console.warn("DesktopIcons: failed to parse scan output:", e)
                    return
                }

                iconModel.clear()
                for (let i = 0; i < parsed.length; i++) {
                    iconModel.append(parsed[i])
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0) {
                    console.warn("DesktopIcons scan stderr:", this.text)
                }
            }
        }
    }

    Component.onCompleted: refresh()

    // ~/Desktop をinotifyで直接監視して、変化があったら即座に再スキャンする。
    // inotify-tools パッケージの inotifywait コマンドが必要
    // (未インストールなら `sudo pacman -S inotify-tools`)。
    Process {
        id: watchProcess
        command: [
            "inotifywait", "-m", "-q",
            "-e", "create,delete,moved_to,moved_from,close_write",
            "--format", "%f",
            root.desktopPath
        ]
        running: true

        onRunningChanged: {
            if (running) root._watchStartedAt = Date.now()
        }

        stdout: SplitParser {
            // イベントが連発しても1回にまとめて反映する
            onRead: (line) => watchDebounce.restart()
        }

        onExited: (exitCode, exitStatus) => {
            const ranMs = Date.now() - root._watchStartedAt
            if (ranMs < 1000) {
                // 起動直後に終了 = inotifywait が無い等、致命的な失敗とみなす
                if (!root._watchUnavailable) {
                    console.warn(
                        "DesktopIcons: inotifywait を起動できませんでした。" +
                        "inotify-tools パッケージ (sudo pacman -S inotify-tools) を" +
                        "入れると即時反映されます。当面はポーリングで代用します。"
                    )
                }
                root._watchUnavailable = true
                return
            }
            // ディレクトリが一時的に消えた等、通常でない終了なら少し待って再起動
            watchRestartTimer.restart()
        }
    }

    Timer {
        id: watchDebounce
        interval: 300
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: watchRestartTimer
        interval: 2000
        repeat: false
        onTriggered: {
            watchProcess.running = false
            watchProcess.running = true
        }
    }

    // inotifywait が使えないときだけ動くフォールバック(ポーリング)
    Timer {
        interval: root.fallbackPollIntervalMs
        running: root._watchUnavailable && root.fallbackPollIntervalMs > 0
        repeat: true
        onTriggered: root.refresh()
    }

    // `qs ipc call desktopicons show|hide|toggle` で表示を切り替えられる。
    // (shell.qml の launcher の IpcHandler と同じやり方)
    IpcHandler {
        target: "desktopicons"

        function open(): void { root.enabled = true }
        function hide(): void { root.enabled = false }
        function toggle(): void { root.enabled = !root.enabled }
    }

    Variants {
        model: root.targetScreens

        PanelWindow {
            id: bgWindow
            required property var modelData
            screen: modelData

            visible: root.enabled

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-desktop-icons"
            focusable: false

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            Item {
                id: iconArea
                anchors.fill: parent

                // 矩形選択(マーキー)用の背景。アイコンより下に配置し、
                // アイコン以外の余白をドラッグすると選択矩形が出る。
                MouseArea {
                    id: marqueeArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true

                    property real startX: 0
                    property real startY: 0
                    property bool dragActive: false

                    onPressed: (mouse) => {
                        marqueeArea.startX = mouse.x
                        marqueeArea.startY = mouse.y
                        marqueeArea.dragActive = false
                        marqueeRect.x = mouse.x
                        marqueeRect.y = mouse.y
                        marqueeRect.width = 0
                        marqueeRect.height = 0
                    }

                    onPositionChanged: (mouse) => {
                        const dx = mouse.x - marqueeArea.startX
                        const dy = mouse.y - marqueeArea.startY

                        if (!marqueeArea.dragActive) {
                            // 少し動くまではただのクリックとして扱う(誤反応防止)
                            if (Math.abs(dx) < 4 && Math.abs(dy) < 4) return
                            marqueeArea.dragActive = true
                            marqueeRect.visible = true
                        }

                        marqueeRect.x = Math.min(mouse.x, marqueeArea.startX)
                        marqueeRect.y = Math.min(mouse.y, marqueeArea.startY)
                        marqueeRect.width = Math.abs(dx)
                        marqueeRect.height = Math.abs(dy)

                        root.updateMarqueeSelection(
                            marqueeRect.x, marqueeRect.y,
                            marqueeRect.width, marqueeRect.height
                        )
                    }

                    onReleased: () => {
                        if (!marqueeArea.dragActive) {
                            // ドラッグせず余白をクリックしただけ → 選択解除
                            root.clearSelection()
                        }
                        marqueeArea.dragActive = false
                        marqueeRect.visible = false
                    }
                }

                Rectangle {
                    id: marqueeRect
                    visible: false
                    color: Qt.rgba(0.478, 0.635, 0.969, 0.18)
                    border.color: "#7aa2f7"
                    border.width: 1
                }

                Repeater {
                    model: iconModel

                    DesktopIconItem {
                        id: iconDelegate
                        entryName: model.name
                        iconSource: Quickshell.iconPath(model.icon, "text-x-generic")
                        execCommand: model.exec
                        filePath: root.desktopPath + "/" + model.file
                        isDesktopEntry: model.isDesktop

                        width: root.iconWidth
                        height: root.iconHeight

                        selected: !!root.selectedFiles[model.file]

                        gridX: {
                            const saved = positionsData.icons[model.file]
                            if (saved) return saved.x
                            const col = index % root.columns
                            return root.marginLeft + col * root.cellWidth
                        }
                        gridY: {
                            const saved = positionsData.icons[model.file]
                            if (saved) return saved.y
                            const row = Math.floor(index / root.columns)
                            return root.marginTop + row * root.cellHeight
                        }

                        onPositionChanged: (px, py) => {
                            let finalX = px
                            let finalY = py

                            if (root.snapToGrid) {
                                // ドロップ位置に一番近いグリッドセルへ、
                                // 既に埋まっていれば周囲の空きセルへずらす
                                const rawCol = Math.round((px - root.marginLeft) / root.cellWidth)
                                const rawRow = Math.round((py - root.marginTop) / root.cellHeight)
                                const free = root.findFreeCell(rawCol, rawRow, model.file)
                                finalX = root.marginLeft + free.col * root.cellWidth
                                finalY = root.marginTop + free.row * root.cellHeight
                                iconDelegate.x = finalX
                                iconDelegate.y = finalY
                            }

                            const icons = positionsData.icons
                            icons[model.file] = { x: finalX, y: finalY }
                            positionsData.icons = icons
                            root.savePositions()
                        }

                        onSelectRequested: (additive) => {
                            if (additive) root.toggleSelect(model.file)
                            else root.selectOnly(model.file)
                        }

                        onLaunchRequested: {
                            if (isDesktopEntry && execCommand.length > 0) {
                                Quickshell.execDetached(["sh", "-c", execCommand])
                            } else {
                                Quickshell.execDetached(["xdg-open", filePath])
                            }
                        }
                    }
                }
            }
        }
    }
}
