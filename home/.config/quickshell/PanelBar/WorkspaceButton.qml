// WorkspaceButton.qml - ワークスペース切り替えボタン
// Hyprland 0.55+ Lua mode に対応
import Quickshell
import Quickshell.Hyprland
import QtQuick

Item {
    id: root
    required property int index
    readonly property int wsId: index + 1

    implicitWidth: 28
    implicitHeight: 28

    property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
    property bool isActive: Hyprland.focusedWorkspace?.id === wsId
    property bool hasWindows: ws !== null

    // Lua mode / hyprlang mode を自動判定して dispatch 文字列を生成
    function dispatchWorkspace(id) {
        if (Hyprland.usingLua) {
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })')
        } else {
            Hyprland.dispatch("workspace " + id)
        }
    }

    function dispatchRelative(delta) {
        var dir = delta > 0 ? "e-1" : "e+1"
        if (Hyprland.usingLua) {
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + dir + '" })')
        } else {
            Hyprland.dispatch("workspace " + dir)
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 24
        height: 22
        radius: 6
        color: root.isActive ? "#7aa2f7"
             : root.hasWindows ? "#3b4261"
             : "transparent"
        border.color: root.isActive ? "#7aa2f7"
                    : root.hasWindows ? "#565f89"
                    : "#2a2b3d"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: root.wsId
            color: root.isActive ? "#1a1b26"
                 : root.hasWindows ? "#c0caf5"
                 : "#565f89"
            font { pixelSize: 12; bold: root.isActive }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dispatchWorkspace(root.wsId)
            onWheel: event => root.dispatchRelative(event.angleDelta.y)
        }
    }
}
