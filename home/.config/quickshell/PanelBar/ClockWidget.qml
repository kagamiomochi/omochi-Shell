// ClockWidget.qml - 時計ウィジェット
// SystemClock.date を Qt.formatDateTime() でフォーマットする
// (Qt.formatTime / Qt.formatDate は別のオブジェクト型を期待するため使わない)
import Quickshell
import QtQuick

Item {
    implicitWidth: clockRow.implicitWidth + 8
    implicitHeight: 36

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "M/d(ddd)")
            color: "#565f89"
            font { pixelSize: 12 }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            color: "#c0caf5"
            font { pixelSize: 14; bold: true; family: "monospace" }
        }
    }
}
