// VolumeWidget.qml - 音量ウィジェット (Pipewire経由)
// PwObjectTracker でノードを bind してから volume/muted を操作する
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root
    implicitWidth: volRow.implicitWidth + 8
    implicitHeight: 36

    property var sink: Pipewire.defaultAudioSink

    // PwObjectTracker でsinkをbindする
    // これをしないと volume/muted の読み書きができない
    PwObjectTracker {
        objects: [ root.sink ]
    }

    property bool ready: sink !== null && sink.audio !== null
    property real volume: ready ? sink.audio.volume : 0.0
    property bool muted:  ready ? sink.audio.muted  : false
    property int volPct:  Math.round(volume * 100)

    property string volIcon: muted || volPct === 0 ? "🔇"
                           : volPct < 40  ? "🔉"
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
                : root.muted  ? "MUTE"
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
            if (!root.ready) return
            var delta = event.angleDelta.y > 0 ? 0.05 : -0.05
            root.sink.audio.volume = Math.max(0.0, Math.min(1.5, root.volume + delta))
        }

        onClicked: {
            if (!root.ready) return
            root.sink.audio.muted = !root.sink.audio.muted
        }
    }
}
