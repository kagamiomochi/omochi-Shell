import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

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

    // Collect actions that should be shown as buttons (non-empty text, not "default")
    function buttonActions() {
        const out = []
        if (!notifObj || !notifObj.actions) return out
        for (let i = 0; i < notifObj.actions.length; i++) {
            const a = notifObj.actions[i]
            if (a.text !== "" && a.identifier !== "default") out.push(a)
        }
        return out
    }

    // Invoke the "default" action (click on the notification body)
    function invokeDefault() {
        if (!notifObj || !notifObj.actions) return
        for (let i = 0; i < notifObj.actions.length; i++) {
            if (notifObj.actions[i].identifier === "default") {
                notifObj.actions[i].invoke()
                card.dismissRequested()
                return
            }
        }
    }

    readonly property var shownActions: buttonActions()

    implicitHeight: contentCol.implicitHeight + 20
    radius: 10
    color: urgency === NotificationUrgency.Critical ? "#552a1a1a" : "#332f2f2f"
    border.color: urgency === NotificationUrgency.Critical ? "#ff5555" : "#44ffffff"
    border.width: 1

    // Background click area (declared first so buttons and the close mark stay above it)
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.invokeDefault()
    }

    RowLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

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

            RowLayout {
                visible: card.shownActions.length > 0
                spacing: 6
                Repeater {
                    model: card.shownActions
                    delegate: Rectangle {
                        required property var modelData
                        radius: 6
                        color: "#3a3a3a"
                        implicitHeight: 26
                        implicitWidth: actionLabel.implicitWidth + 16
                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: "white"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                parent.modelData.invoke()
                                card.dismissRequested()
                            }
                        }
                    }
                }
            }
        }
    }
}
