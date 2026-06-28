// BatteryWidget.qml - バッテリーウィジェット (UPower経由)
// バッテリーがない環境 (デスクトップ) では自動的に非表示
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Item {
    id: root

    // バッテリーデバイスを検索
    property var battery: {
        var devs = UPower.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === UPowerDeviceType.Battery)
                return devs[i]
        }
        return null
    }

    property bool hasBattery: battery !== null
    visible: hasBattery
    implicitWidth: hasBattery ? row.implicitWidth + 8 : 0
    implicitHeight: 36

    // バッテリー残量 0–100
    property int pct: hasBattery ? Math.round(battery.percentage) : 0
    property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

    // アイコン
    property string batIcon: charging ? "⚡"
                           : pct >= 90 ? "🔋"
                           : pct >= 50 ? "🔋"
                           : pct >= 20 ? "🪫"
                           : "🪫"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.batIcon
            font { pixelSize: 14 }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.pct + "%"
            color: root.pct <= 20 ? "#f7768e"
                 : root.pct <= 50 ? "#e0af68"
                 : "#9ece6a"
            font { pixelSize: 12 }
            width: 34
        }
    }
}
