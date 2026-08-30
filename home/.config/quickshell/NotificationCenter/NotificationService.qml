pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// ============================================================
// 通知の状態を一元管理するシングルトン
// ステータスバー・通知パネル・トーストレイヤーの全てがここを参照する
// 使い方: import "root" ではなく qmldir で Singleton 登録してから
//         各QMLで `NotificationService.xxx` として参照する
// ============================================================
Singleton {
    id: root

    property bool panelVisible: false
    property alias historyModel: history
    property alias server: notifServer

    // 新着通知が来た時に発火 (トースト表示用)
    signal notified(var notification)

    function toggle() { panelVisible = !panelVisible }
    function open() { panelVisible = true }
    function close() { panelVisible = false }

    function clearAll() {
        for (let i = 0; i < history.count; i++) {
            const item = history.get(i)
            if (item.notifObj && item.notifObj.tracked) {
                item.notifObj.dismiss()
            }
        }
        history.clear()
    }

    function removeAt(index) {
        const item = history.get(index)
        if (item.notifObj) item.notifObj.dismiss()
        history.remove(index)
    }

    readonly property int unreadCount: history.count

    ListModel {
        id: history
    }

    NotificationServer {
        id: notifServer

        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true
            history.insert(0, {
                notifObj: notification,
                summary: notification.summary,
                body: notification.body,
                appName: notification.appName,
                appIcon: notification.appIcon,
                urgency: notification.urgency,
                image: notification.image,
                time: Date.now()
            })

            root.notified(notification)
        }
    }
}
