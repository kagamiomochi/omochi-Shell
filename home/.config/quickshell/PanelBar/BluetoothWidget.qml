// BluetoothWidget.qml - Bluetoothウィジェット (v0.3.0)
// Quickshell.Bluetooth を使用。bluetoothctl ポーリング不要。
// Bluetooth.defaultAdapter で電源状態、Bluetooth.devices で接続デバイスを取得。
import Quickshell.Bluetooth
import QtQuick

Item {
    id: root
    implicitHeight: 36

    property var adapter: Bluetooth.defaultAdapter

    // アダプターが存在し、かつ powered on のときのみ表示
    property bool powered: adapter !== null && (adapter.powered ?? false)
    visible: powered
    implicitWidth: powered ? row.implicitWidth + 8 : 0

    // 接続中デバイス一覧 (全アダプター合算)
    property var connectedDevices: {
        var result = []
        var devs = Bluetooth.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].connected) result.push(devs[i])
        }
        return result
    }

    property bool hasConnected: connectedDevices.length > 0
    property string firstDeviceName: {
        if (!hasConnected) return ""
        var n = connectedDevices[0].name
        return n.length > 14 ? n.substring(0, 12) + "..." : n
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "BT"
            color: root.hasConnected ? "#7aa2f7" : "#565f89"
            font { pixelSize: 11; bold: root.hasConnected }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasConnected
            text: root.firstDeviceName
            color: "#a9b1d6"
            font { pixelSize: 12 }
        }
    }

    // クリックでアダプターのオン/オフ切り替え
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.adapter) root.adapter.powered = !root.adapter.powered
        }
    }
}
