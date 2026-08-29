import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// ============================================================
// 通知センター本体
// shell.qml から `NotificationCenter { }` として読み込む想定
// ============================================================
Item {
    id: root

    // 外部から通知センターの表示/非表示を切り替えるためのプロパティ
    property bool panelVisible: false
    function toggle() { panelVisible = !panelVisible }
    function open() { panelVisible = true }
    function close() { panelVisible = false }

    // ------------------------------------------------------
    // 通知サーバー本体
    // ------------------------------------------------------
    NotificationServer {
        id: notifServer

        // 対応する機能を宣言 (対応していないと送信側がフォールバックする)
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true
            history.model.insert(0, {
                notifObj: notification,
                summary: notification.summary,
                body: notification.body,
                appName: notification.appName,
                appIcon: notification.appIcon,
                urgency: notification.urgency,
                image: notification.image,
                time: Date.now()
            })

            // ポップアップトーストを1件生成
            toastLayer.createToast(notification)
        }
    }

    // ------------------------------------------------------
    // 通知履歴の保持用モデル
    // ------------------------------------------------------
    QtObject {
        id: history
        property ListModel model: ListModel {}
    }

    function clearAll() {
        for (let i = 0; i < history.model.count; i++) {
            const item = history.model.get(i)
            if (item.notifObj && item.notifObj.tracked) {
                item.notifObj.dismiss()
            }
        }
        history.model.clear()
    }

    function removeAt(index) {
        const item = history.model.get(index)
        if (item.notifObj) item.notifObj.dismiss()
        history.model.remove(index)
    }

    // ------------------------------------------------------
    // 通知センターパネル本体 (右上等にドッキング)
    // ------------------------------------------------------
    LazyLoader {
        active: root.panelVisible

        PanelWindow {
            id: panel
            visible: root.panelVisible

            anchors {
                top: true
                right: true
            }
            margins {
                top: 8
                right: 8
            }

            implicitWidth: 380
            implicitHeight: Math.min(600, 80 + list.contentHeight)
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "notification-center"
            exclusiveZone: 0

            // パネル外クリックで閉じる (フル画面の透明キャッチャーを使う簡易実装)
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.close()
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 14
                color: "#e6202020"
                border.color: "#33ffffff"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "通知"
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "すべてクリア"
                            color: "#aaaaaa"
                            font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.clearAll()
                            }
                        }
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: history.model

                        delegate: NotificationCard {
                            width: list.width
                            summary: model.summary
                            body: model.body
                            appName: model.appName
                            appIcon: model.appIcon
                            urgency: model.urgency
                            image: model.image
                            notifObj: model.notifObj
                            onDismissRequested: root.removeAt(index)
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: list.count === 0
                            text: "通知はありません"
                            color: "#777777"
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------
    // ポップアップトースト表示レイヤー
    // ------------------------------------------------------
    ToastLayer {
        id: toastLayer
    }
}
