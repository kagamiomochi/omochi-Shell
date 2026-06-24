// BarIconButton.qml - バー用の小型ボタン
import QtQuick

Item {
    id: root
    required property string icon
    signal clicked()

    implicitWidth: 20
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: mouseArea.containsPress ? "#3b4261"
             : mouseArea.containsMouse ? "#2a2b3d"
             : "transparent"
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font { pixelSize: 11 }
        color: "#a9b1d6"
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
