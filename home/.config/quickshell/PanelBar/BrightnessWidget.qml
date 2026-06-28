// BrightnessWidget.qml - 輝度ウィジェット (brightnessctl 依存)
// ラップトップ等、brightnessctl が使える環境でのみ visible=true にする
import Quickshell.Io
import QtQuick

Item {
    id: root
    required property int value  // 0–100
    implicitWidth: row.implicitWidth + 8
    implicitHeight: 36

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "☀"
            color: "#e0af68"
            font { pixelSize: 14 }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.value + "%"
            color: "#c0caf5"
            font { pixelSize: 12 }
            width: 34
        }
    }

    // ホイールで輝度変更
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onWheel: event => {
            var delta = event.angleDelta.y > 0 ? 5 : -5
            brightAdjProc.command = ["brightnessctl", "set", (delta > 0 ? "+" : "") + Math.abs(delta) + "%"]
            brightAdjProc.running = true
        }
    }

    Process {
        id: brightAdjProc
        command: []
    }
}
