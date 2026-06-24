// WorkspaceButton.qml - ワークスペース切り替えボタン
import Quickshell
import Quickshell.Io
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

    // Hyprland 0.55+ Lua モード対応
    // usingLua が true の場合は hyprctl 経由で dispatch する
    function switchWorkspace(id) {
        if (Hyprland.usingLua) {
            hyprctlProc.command = [
                "hyprctl", "dispatch",
                "hl.dsp.workspace.focus({ workspace = \"" + id + "\" })"
            ]
            hyprctlProc.running = true
        } else {
            Hyprland.dispatch("workspace " + id)
        }
    }

    function scrollWorkspace(next) {
        var arg = next ? "e+1" : "e-1"
        if (Hyprland.usingLua) {
            hyprctlProc.command = [
                "hyprctl", "dispatch",
                "hl.dsp.workspace.focus({ workspace = \"" + arg + "\" })"
            ]
            hyprctlProc.running = true
        } else {
            Hyprland.dispatch("workspace " + arg)
        }
    }

    Process {
        id: hyprctlProc
        command: []
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
            onClicked: root.switchWorkspace(root.wsId)
            onWheel: event => root.scrollWorkspace(event.angleDelta.y > 0)
        }
    }
}
