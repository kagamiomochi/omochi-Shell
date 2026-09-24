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

    // 表示ON/OFF。IpcHandler経由でコマンドから切り替えられる
    property bool enabled: true

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

        function show(): void { root.enabled = true }
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

            Repeater {
                model: iconModel

                DesktopIconItem {
                    entryName: model.name
                    iconSource: Quickshell.iconPath(model.icon, "text-x-generic")
                    execCommand: model.exec
                    filePath: root.desktopPath + "/" + model.file
                    isDesktopEntry: model.isDesktop

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
                        const icons = positionsData.icons
                        icons[model.file] = { x: px, y: py }
                        positionsData.icons = icons
                        root.savePositions()
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
