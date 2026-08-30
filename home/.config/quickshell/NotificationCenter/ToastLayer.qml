import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// ============================================================
// 新着通知を画面右上にポップアップ表示するレイヤー
// NotificationService.notified シグナルを購読して表示する
// ============================================================
Item {
    id: root

    ListModel { id: toastModel }

    Connections {
        target: NotificationService
        function onNotified(notification) {
            toastModel.append({
                notifObj: notification,
                summary: notification.summary,
                body: notification.body,
                appName: notification.appName,
                appIcon: notification.appIcon,
                urgency: notification.urgency,
                image: notification.image
            })
        }
    }

    PanelWindow {
        id: toastWindow
        visible: toastModel.count > 0

        anchors {
            top: true
            right: true
        }
        margins {
            top: 8
            right: 8
        }

        implicitWidth: 340
        implicitHeight: toastCol.implicitHeight
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notification-toast"
        exclusiveZone: 0
        mask: Region { item: toastCol }

        ColumnLayout {
            id: toastCol
            width: parent.width
            spacing: 6

            Repeater {
                model: toastModel
                delegate: NotificationCard {
                    width: toastCol.width
                    summary: model.summary
                    body: model.body
                    appName: model.appName
                    appIcon: model.appIcon
                    urgency: model.urgency
                    image: model.image
                    notifObj: model.notifObj

                    onDismissRequested: toastModel.remove(index)

                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Timer {
                        interval: urgency === NotificationUrgency.Critical
                            ? -1
                            : (urgency === NotificationUrgency.Low ? 3000 : 5000)
                        running: interval > 0
                        onTriggered: toastModel.remove(index)
                    }
                }
            }
        }
    }
}
