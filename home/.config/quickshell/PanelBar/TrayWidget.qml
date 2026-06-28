// TrayWidget.qml - システムトレイウィジェット
// SystemTray.items を Repeater で展開し、アイコン + 右クリックメニューを提供
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Item {
    id: root
    // バーウィンドウ (QsWindow) をメニューアンカー用に受け取る
    required property var barWindow

    implicitWidth: trayRow.implicitWidth + 4
    implicitHeight: 36

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: SystemTray.items

            delegate: TrayIcon {
                required property SystemTrayItem modelData
                item: modelData
                barWindow: root.barWindow
            }
        }
    }
}
