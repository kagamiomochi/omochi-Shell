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

    // 定期的に ~/Desktop を再スキャンする間隔(ミリ秒)。0以下で無効化。
    property int rescanIntervalMs: 5000

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

    Timer {
        interval: root.rescanIntervalMs
        running: root.rescanIntervalMs > 0
        repeat: true
        onTriggered: root.refresh()
    }

    Variants {
        model: root.targetScreens

        PanelWindow {
            id: bgWindow
            required property var modelData
            screen: modelData

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
