import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// ============================================================
// 新着通知を画面右上にポップアップ表示するレイヤー
// 一定時間(緊急度により変動)で自動的に消える
// ============================================================
Item {
    id: root

    function createToast(notification) {
        toastModel.append({
            notifObj: notification,
            summary: notification.summary,
            body: notification.body,
            appName: notification.appName,
            appIcon: notification.appIcon,
            urgency: notification.urgency,
            image: notification.image,
            uid: Date.now() + Math.random()
        })
    }

    ListModel { id: toastModel }

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
        // マウス操作を透過させ、カード部分だけ受け取る
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

                    // 表示アニメーション
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Timer {
                        // 緊急度に応じた自動消去時間 (critical は自動で消さない)
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
