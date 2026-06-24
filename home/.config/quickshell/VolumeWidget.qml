// VolumeWidget.qml - 音量ウィジェット (Pipewire経由)
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root
    implicitWidth: volRow.implicitWidth + 8
    implicitHeight: 36

    // defaultAudioSink は存在しても audio が null の場合がある (unbound状態)
    // audio が非null かつ ready な場合のみ操作する
    property var sink: Pipewire.defaultAudioSink
    property var audio: sink?.audio ?? null
    property real volume: audio?.volume ?? 0.0
    property bool muted: audio?.muted ?? false
    property bool ready: audio !== null

    property int volPct: Math.round(volume * 100)

    property string volIcon: muted || volPct === 0 ? "🔇"
                           : volPct < 30 ? "🔉"
                           : "🔊"

    Row {
        id: volRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.volIcon
            font { pixelSize: 14 }
            opacity: root.muted ? 0.4 : 1.0
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: !root.ready ? "---"
                : root.muted ? "MUTE"
                : root.volPct + "%"
            color: root.muted ? "#565f89" : "#c0caf5"
            font { pixelSize: 12 }
            width: 38
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onWheel: event => {
            // audio が null または unbound の間は無視
            if (!root.ready) return
            var delta = event.angleDelta.y > 0 ? 0.05 : -0.05
            root.audio.volume = Math.max(0.0, Math.min(1.5, root.volume + delta))
        }

        onClicked: {
            if (!root.ready) return
            root.audio.muted = !root.audio.muted
        }
    }
}
