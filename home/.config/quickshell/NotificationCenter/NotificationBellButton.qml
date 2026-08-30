import QtQuick
import QtQuick.Layouts

// ============================================================
// ステータスバー用の通知ベルアイコン
// 既存のバー(clock, volume, network などと並ぶ想定)に
// `NotificationBellButton { }` として1行追加するだけで使える
// ============================================================
Item {
    id: root

    implicitWidth: 28
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouseArea.containsMouse ? "#33ffffff" : "transparent"

        Text {
            anchors.centerIn: parent
            // Nerd Font等のベルアイコンが使えるならグリフに差し替え可
            text: "\uf0f3"
            font.pixelSize: 15
            color: "white"
        }

        // 未読件数バッジ
        Rectangle {
            visible: NotificationService.unreadCount > 0
            width: 15
            height: 15
            radius: 8
            color: "#e05252"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2
            anchors.rightMargin: -2

            Text {
                anchors.centerIn: parent
                text: NotificationService.unreadCount > 9 ? "9+" : NotificationService.unreadCount
                color: "white"
                font.pixelSize: 9
                font.bold: true
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: NotificationService.toggle()
    }
}
