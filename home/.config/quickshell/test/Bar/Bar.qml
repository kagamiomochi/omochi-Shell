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
            startX: 0; startY: shape.height

            PathLine { x: 0; y: shape.height * 0.7 }
            PathLine { x: shape.width * 0.3; y: shape.height * 0.7 }
            PathLine { x: shape.width * 0.3; y: shape.height }
            PathLine { x: 0; y: shape.height }

            PathMove { x: shape.width * 0.16; y: shape.height * 0.7 }
            PathLine { x: shape.width * 0.16; y: 0 }
            PathLine { x: 0; y: 0 }
            PathLine { x: 0; y: shape.height * 0.7 }
        }
    }
}