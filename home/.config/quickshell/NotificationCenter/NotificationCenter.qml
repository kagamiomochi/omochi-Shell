import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// ============================================================
// 通知履歴パネル本体
// 状態は全て NotificationService (シングルトン) を参照する
// shell.qml に `NotificationCenter { }` を1つ置くだけでよい
// ============================================================
Item {
    id: root

    LazyLoader {
        active: NotificationService.panelVisible

        PanelWindow {
            id: panel
            visible: NotificationService.panelVisible

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

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: NotificationService.close()
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
                                onClicked: NotificationService.clearAll()
                            }
                        }
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: NotificationService.historyModel

                        delegate: NotificationCard {
                            width: list.width
                            summary: model.summary
                            body: model.body
                            appName: model.appName
                            appIcon: model.appIcon
                            urgency: model.urgency
                            image: model.image
                            notifObj: model.notifObj
                            onDismissRequested: NotificationService.removeAt(index)
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
}
