// PanelBar.qml - バー本体
// 左: ワークスペース + アクティブウィンドウタイトル
// 中: 時計
// 右: メディア再生 + 音量 + ネットワーク + バッテリー + 輝度 + システムトレイ

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    // Wayland レイヤーシェル設定
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 36

    // バー背景色 (Tokyo Night ベース)
    color: "#1a1b26"

    // ウィンドウタイトル更新用: rawEvent を購読
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") {
                // event.data = "class,title"
                var parts = event.data.split(",")
                root.activeWindowTitle = parts.length >= 2 ? parts.slice(1).join(",") : ""
            }
            if (event.name === "closewindow") {
                root.activeWindowTitle = ""
            }
        }
    }

    property string activeWindowTitle: ""

    // ネットワーク情報をポーリング取得
    property string networkText: "..."
    property bool networkConnected: false
    property string brightnessBuf: ""
    property int brightnessValue: -1

    Timer {
        id: netTimer
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev | grep -E ':(wifi|ethernet):connected' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":")
                if (parts.length >= 4 && parts[2] === "connected") {
                    root.networkConnected = true
                    var conn = parts.slice(3).join(":")
                    root.networkText = conn.length > 16 ? conn.substring(0, 14) + "…" : conn
                } else {
                    root.networkConnected = false
                    root.networkText = "切断"
                }
            }
        }
    }

    // 輝度取得 (ラップトップのみ)
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
        command: ["sh", "-c", "brightnessctl get 2>/dev/null && echo '/' && brightnessctl max 2>/dev/null || echo '-1'"]
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

        // ===== 左ゾーン =====
        RowLayout {
            spacing: 4

            // ワークスペースボタン
            Repeater {
                model: 10
                delegate: WorkspaceButton {}
            }

            // セパレータ
            BarSeparator {}

            // アクティブウィンドウタイトル
            Text {
                text: root.activeWindowTitle.length > 0
                      ? (root.activeWindowTitle.length > 40
                         ? root.activeWindowTitle.substring(0, 38) + "…"
                         : root.activeWindowTitle)
                      : "デスクトップ"
                color: "#a9b1d6"
                font { pixelSize: 13 }
                elide: Text.ElideRight
                Layout.maximumWidth: 300
            }
        }

        // 中央スペーサー
        Item { Layout.fillWidth: true }

        // ===== 中央: 時計 =====
        ClockWidget {}

        // 中央スペーサー
        Item { Layout.fillWidth: true }

        // ===== 右ゾーン =====
        RowLayout {
            spacing: 2

            // MPRIS メディアプレイヤー (再生中の場合のみ表示)
            MediaWidget {}

            BarSeparator {}

            // 音量 (Pipewire)
            VolumeWidget {}

            BarSeparator {}

            // 輝度 (ラップトップのみ)
            BrightnessWidget {
                visible: root.brightnessValue >= 0
                value: root.brightnessValue
            }

            BarSeparator {
                visible: root.brightnessValue >= 0
            }

            // ネットワーク
            NetworkWidget {
                connected: root.networkConnected
                label: root.networkText
            }

            BarSeparator {}

            // バッテリー (UPower)
            BatteryWidget {}

            BarSeparator {}

            // システムトレイ (barWindow でメニューアンカーを渡す)
            TrayWidget {
                barWindow: root
            }
        }
    }
}
