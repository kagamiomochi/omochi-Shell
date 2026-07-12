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
        layer.enabled: true
        layer.samples: 4

///////////////////////////////////////////////////////////
        ShapePath {
            fillColor: "transparent"
            strokeColor: "blue"
            strokeWidth: 4

            startX: 0; startY: 0
            PathLine { x: shape.width; y: 0 }
            PathLine { x: shape.width; y: shape.height }
        }

        Rectangle {
            width: shape.width * 0.35
            height: shape.height * 0.35
            color: "transparent"
            border.color: "red"
            border.width: 4
            anchors.left: parent.left
            anchors.bottom: parent.bottom
        }
///////////////////////////////////////////////////////////

        ShapePath {
            fillColor: "#303030"
            strokeWidth: 0
            
            startX: 0; startY: 0
            PathLine { x: shape.width * 0.11; y: shape.height * 0.05 }
            PathLine { x: shape.width * 0.15; y: shape.height * 0.65 }
            PathLine { x: 0; y: shape.height * 0.65 }
        }

        ShapePath {
            fillColor: '#555555'
            strokeWidth: 0

            startX: 0; startY: 0
            PathMove { x: shape.width * 0.11; y: shape.height * 0.05 }
            PathLine { x: shape.width * 0.15; y: shape.height * 0.65 }
            PathLine { x: shape.width * 0.13; y: shape.height * 0.65 }
        }
    }
}