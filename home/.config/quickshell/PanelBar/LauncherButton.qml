// LauncherButton.qml - アプリランチャー起動ボタン
import Quickshell.Io
import QtQuick

Item {
    id: root

    implicitWidth: 28
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouseArea.containsPress ? "#3b4261"
             : mouseArea.containsMouse ? "#2a2b3d"
             : "transparent"
    }

    Text {
        anchors.centerIn: parent
        text: "\uF001"  // Nerd Font アイコン、無ければ好きな文字に変更
        font { pixelSize: 15 }
        color: "#7aa2f7"
    }

    Process {
        id: toggleProc
        command: ["qs", "ipc", "call", "launcher", "toggle"]
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleProc.running = true
    }
}
