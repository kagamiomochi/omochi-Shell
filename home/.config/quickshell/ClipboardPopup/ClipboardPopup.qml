import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    visible: false

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        bottom: true
        left: true
    }
    margins {
        bottom: 20
        left: 20
    }

    implicitWidth: 360
    implicitHeight: content.implicitHeight + 24
    color: "transparent"

    property bool sensitive: false
    property string previewText: ""

    Timer {
        id: hideTimer
        interval: 3000
        onTriggered: root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#1e1e2e"
        border.color: "#585b70"
        border.width: 1

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            Text {
                text: root.sensitive ? "機密情報をコピーしました" : "クリップボードにコピー"
                color: "#a6adc8"
                font.pixelSize: 11
            }

            Text {
                Layout.fillWidth: true
                text: root.sensitive ? "•".repeat(Math.min(root.previewText.length, 24)) : root.previewText
                color: "#cdd6f4"
                font.pixelSize: 14
                elide: Text.ElideRight
                maximumLineCount: 3
                wrapMode: Text.Wrap
            }
        }
    }

    function show(text, isSensitive) {
        previewText = text
        sensitive = isSensitive
        visible = true
        hideTimer.restart()
    }
}