// NetworkWidget.qml - ネットワークウィジェット
import QtQuick

Item {
    id: root
    required property bool connected
    required property string label

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 36

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.connected ? "󰖩" : "󰖪"   // Nerd Font アイコン (なければ下記フォールバック)
            font { pixelSize: 14 }
            color: root.connected ? "#9ece6a" : "#f7768e"

            // Nerd Font が使えない環境向けフォールバック
            Component.onCompleted: {
                if (implicitWidth < 4) {
                    text = root.connected ? "NET" : "---"
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.connected ? "#c0caf5" : "#565f89"
            font { pixelSize: 12 }
        }
    }
}
