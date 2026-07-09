import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.Services

PanelWindow {
    id: root
    visible: PolkitService.requestActive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property AuthFlow flow: PolkitService.flow

    Connections {
    target: flow
    function onIsResponseRequiredChanged() {
        if (flow && flow.isResponseRequired) {
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
    }
    function onAuthenticationFailed() {
        errorLabel.text = qsTr("認証に失敗しました。もう一度お試しください。")
        passwordField.text = ""
    }
    function onAuthenticationSucceeded() {
        errorLabel.text = ""
    }
    function onAuthenticationRequestCancelled() {
        errorLabel.text = ""
        passwordField.text = ""
    }
}

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.5

        MouseArea {
            anchors.fill: parent
            onClicked: {} // 背景クリックでは閉じない
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 420
        height: content.implicitHeight + 48
        radius: 12
        color: "#1e1e2e"
        border.color: "#313244"
        border.width: 1

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            RowLayout {
                spacing: 12
                Image {
                    source: flow && flow.iconName ? "image://icon/" + flow.iconName : ""
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    visible: source !== ""
                }
                Label {
                    text: qsTr("認証が必要です")
                    font.pixelSize: 16
                    font.bold: true
                    color: "#cdd6f4"
                }
            }

            Label {
                text: flow ? flow.message : ""
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#bac2de"
            }

            Label {
                visible: flow && flow.supplementaryMessage !== ""
                text: flow ? flow.supplementaryMessage : ""
                color: flow && flow.supplementaryIsError ? "#f38ba8" : "#a6adc8"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                text: flow ? flow.inputPrompt : qsTr("パスワード")
                color: "#cdd6f4"
                visible: flow && flow.isResponseRequired
            }

            TextField {
                id: passwordField
                Layout.fillWidth: true
                echoMode: (flow && flow.responseVisible) ? TextInput.Normal : TextInput.Password
                enabled: flow && flow.isResponseRequired
                onAccepted: submitButton.clicked()
            }

            Label {
                id: errorLabel
                color: "#f38ba8"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Button {
                    text: qsTr("キャンセル")
                    onClicked: {
                        if (flow) flow.cancelAuthenticationRequest()
                    }
                }

                Button {
                    id: submitButton
                    text: qsTr("認証")
                    enabled: flow && flow.isResponseRequired
                    onClicked: {
                        if (flow) {
                            flow.submit(passwordField.text)
                            passwordField.text = ""
                        }
                    }
                }
            }
        }
    }
}