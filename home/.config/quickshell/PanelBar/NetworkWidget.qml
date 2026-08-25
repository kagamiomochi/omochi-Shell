// NetworkWidget.qml - ネットワークウィジェット (v0.3.0)
// Quickshell.Networking を使用。nmcli ポーリング不要。
// NetworkDevice.connected と networks から接続名を取得する。
// デバイスは Wifi 優先、なければ Wired を使用。
import Quickshell.Networking
import QtQuick

Item {
    id: root
    implicitHeight: 36
    implicitWidth: row.implicitWidth + 8

    // Wifi / Wired デバイスを優先度順に探す
    property var activeDevice: {
        var devs = Networking.devices.values
        var wifi = null, wired = null
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi && devs[i].connected) wifi = devs[i]
            if (devs[i].type === DeviceType.Wired && devs[i].connected) wired = devs[i]
        }
        return wifi ?? wired ?? null
    }

    property bool connected: activeDevice !== null
    property bool isWifi: activeDevice !== null && activeDevice.type === DeviceType.Wifi

    // 接続中ネットワーク名 (networks の先頭で connected なもの)
    property string netName: {
        if (!activeDevice) return "切断"
        var nets = activeDevice.networks.values
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].connected) {
                var n = nets[i].name
                return n.length > 16 ? n.substring(0, 14) + "..." : n
            }
        }
        return activeDevice.name  // fallback: デバイス名
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.isWifi ? "Wi-Fi" : root.connected ? "LAN" : "NET"
            color: root.connected ? "#9ece6a" : "#f7768e"
            font { pixelSize: 11; bold: root.connected }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.netName
            color: root.connected ? "#c0caf5" : "#565f89"
            font { pixelSize: 12 }
        }
    }
}
