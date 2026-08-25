// PanelBar.qml - バー本体 (v0.3.0)
// ネットワーク・Bluetooth はネイティブモジュールに移管したため、
// ポーリング処理を削除。輝度 (brightnessctl) のみ Process で取得。

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 36

    color: "#1a1b26"

    // アクティブウィンドウタイトル
    property string activeWindowTitle: ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") {
                var parts = event.data.split(",")
                root.activeWindowTitle = parts.length >= 2 ? parts.slice(1).join(",") : ""
            }
            if (event.name === "closewindow") {
                root.activeWindowTitle = ""
            }
        }
    }

    // 輝度 (brightnessctl) - ラップトップのみ
    property int brightnessValue: -1
    property string brightnessBuf: ""

    Timer {
        id: brightTimer
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: brightProc.running = true
    }

    Process {
        id: brightProc
        command: ["sh", "-c",
            "brightnessctl get 2>/dev/null && echo '/' && brightnessctl max 2>/dev/null || echo '-1'"
        ]
        stdout: SplitParser {
            onRead: data => root.brightnessBuf += data
        }
        onExited: (code, signal) => {
            var out = root.brightnessBuf.trim()
            root.brightnessBuf = ""
            if (code !== 0 || out === "-1") {
                root.brightnessValue = -1
                return
            }
            var parts = out.split("/")
            if (parts.length >= 2) {
                var cur = parseInt(parts[0].trim())
                var max = parseInt(parts[1].trim())
                root.brightnessValue = max > 0 ? Math.round(cur * 100 / max) : -1
            }
        }
    }

    // ======= レイアウト =======
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 0

        // ===== 左: ワークスペース + ウィンドウタイトル (縮小) =====
        RowLayout {
            spacing: 4
            Layout.maximumWidth: 420

            Repeater {
                model: 10
                delegate: WorkspaceButton {}
            }

            BarSeparator {}

            Text {
                text: root.activeWindowTitle.length > 0
                      ? (root.activeWindowTitle.length > 20
                         ? root.activeWindowTitle.substring(0, 18) + "..."
                         : root.activeWindowTitle)
                      : "Desktop"
                color: "#565f89"
                font { pixelSize: 12 }
                elide: Text.ElideRight
                Layout.maximumWidth: 140
            }
        }

        Item { Layout.fillWidth: true }

        // ===== 中央: 歌詞 (再生中のみ) + 時計 =====
        RowLayout {
            spacing: 8

            LyricsWidget {}

            ClockWidget {}
        }

        Item { Layout.fillWidth: true }

        // ===== 右: 各ウィジェット =====
        RowLayout {
            spacing: 2

            MediaWidget {}

            BarSeparator {}

            VolumeWidget {}

            BarSeparator {}

            BrightnessWidget {
                visible: root.brightnessValue >= 0
                value: root.brightnessValue
            }

            BarSeparator {
                visible: root.brightnessValue >= 0
            }

            NetworkWidget {}

            BarSeparator {}

            BluetoothWidget {}

            BarSeparator {}

            BatteryWidget {}

            BarSeparator {}

            TrayWidget {
                barWindow: root
            }
        }
    }
}
