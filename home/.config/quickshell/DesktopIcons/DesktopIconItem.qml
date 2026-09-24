import QtQuick
import Quickshell.Widgets

// デスクトップアイコン1個分の見た目とドラッグ/起動の挙動。
// DesktopIcons.qml の Repeater から生成される。
Item {
    id: root

    property string entryName: ""
    property string iconSource: ""
    property string execCommand: ""
    property string filePath: ""
    property bool isDesktopEntry: false

    // グリッド上の初期(または保存済みの)位置
    property real gridX: 0
    property real gridY: 0

    signal positionChanged(real x, real y)
    signal launchRequested()

    width: 88
    height: 96
    x: gridX
    y: gridY

    property bool dragging: false
    property real _dragStartMouseX: 0
    property real _dragStartMouseY: 0
    property real _dragStartX: 0
    property real _dragStartY: 0

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouseArea.containsMouse || root.dragging
            ? Qt.rgba(1, 1, 1, 0.15)
            : "transparent"
        border.width: root.dragging ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.4)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitSize: 48
            source: root.iconSource
            asynchronous: true
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: root.entryName
            color: "white"
            font.pixelSize: 11
            style: Text.Outline
            styleColor: "black"
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onPressed: (mouse) => {
            root.dragging = true
            root._dragStartMouseX = mouse.x
            root._dragStartMouseY = mouse.y
            root._dragStartX = root.x
            root._dragStartY = root.y
        }

        onPositionChanged: (mouse) => {
            if (!root.dragging) return
            root.x = root._dragStartX + (mouse.x - root._dragStartMouseX)
            root.y = root._dragStartY + (mouse.y - root._dragStartMouseY)
        }

        onReleased: () => {
            if (!root.dragging) return
            root.dragging = false
            root.positionChanged(root.x, root.y)
        }

        onDoubleClicked: (mouse) => {
            root.launchRequested()
        }
    }
}
