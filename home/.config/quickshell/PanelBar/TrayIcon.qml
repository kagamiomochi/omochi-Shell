// TrayIcon.qml - 個別トレイアイコン + 右クリックメニュー
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property SystemTrayItem item
    required property var barWindow

    implicitWidth: 22
    implicitHeight: 22

    // アイコン表示 (icon は Image の source として使える string)
    Image {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: root.item.icon
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // ホバー時のツールチップ
    ToolTip {
        id: tooltip
        delay: 500
        timeout: 3000
        // v0.1.0 API: tooltipTitle プロパティ
        text: (root.item.tooltipTitle !== "" ? root.item.tooltipTitle : root.item.title) || root.item.id
        visible: mouseArea.containsMouse && text.length > 0
        y: -height - 4
        x: (parent.width - width) / 2
    }

    // QsMenuAnchor: バーウィンドウにメニューをアンカー
    QsMenuAnchor {
        id: menuAnchor
        // anchor.window には QsWindow (PanelWindow) を渡す
        anchor.window: root.barWindow
        menu: root.item.menu
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                // onlyMenu が true でない場合はアクティベート
                // v0.1.0 では display() 関数は存在しないため
                // 左クリックでもメニューを開く
                if (root.item.hasMenu) {
                    menuAnchor.open()
                }
            } else if (event.button === Qt.RightButton) {
                if (root.item.hasMenu) {
                    menuAnchor.open()
                }
            }
        }
    }
}
