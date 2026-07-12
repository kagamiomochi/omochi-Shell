import Quickshell
import QtQuick
import QtQuick.Shapes

PanelWindow {
    implicitWidth: 500
    implicitHeight: 500
    color: "transparent"
    anchors {
        top: false
        bottom: true
        left: true
        right: false
    }

    Shape {
        id: shape
        anchors.fill: parent

        ShapePath {
            strokeWidth: 4
            strokeColor: "red"

            startX: 0; startY: 0
            PathLine { x: shape.width; y: shape.height }
        }
    }
}