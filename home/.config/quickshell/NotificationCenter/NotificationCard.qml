import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

// ============================================================
// 通知1件分のカード。履歴パネル・トースト両方から使う共通部品
// ============================================================
Rectangle {
    id: card

    property string summary: ""
    property string body: ""
    property string appName: ""
    property string appIcon: ""
    property int urgency: NotificationUrgency.Normal
    property string image: ""
    property var notifObj: null

    signal dismissRequested()

    implicitHeight: contentCol.implicitHeight + 20
    radius: 10
    color: urgency === NotificationUrgency.Critical ? "#552a1a1a" : "#332f2f2f"
    border.color: urgency === NotificationUrgency.Critical ? "#ff5555" : "#44ffffff"
    border.width: 1

    RowLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // アイコン or 画像
        Image {
            visible: image !== "" || appIcon !== ""
            source: image !== "" ? image : ("image://icon/" + appIcon)
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            fillMode: Image.PreserveAspectFit
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: appName
                    color: "#999999"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }
                Text {
                    text: "×"
                    color: "#999999"
                    font.pixelSize: 14
                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.dismissRequested()
                    }
                }
            }

            Text {
                text: summary
                color: "white"
                font.pixelSize: 14
                font.bold: true
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Text {
                visible: body !== ""
                text: body
                color: "#cccccc"
                font.pixelSize: 12
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            // 通知アクションボタン (返信・確認など)
            RowLayout {
                visible: notifObj && notifObj.actions && notifObj.actions.length > 0
                spacing: 6
                Repeater {
                    model: notifObj ? notifObj.actions : []
                    delegate: Rectangle {
                        radius: 6
                        color: "#3a3a3a"
                        implicitHeight: 26
                        implicitWidth: actionLabel.implicitWidth + 16
                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            color: "white"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
