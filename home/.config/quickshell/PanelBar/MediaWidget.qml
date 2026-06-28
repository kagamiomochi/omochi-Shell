// MediaWidget.qml - MPRIS メディアプレイヤーウィジェット
// 再生中のプレイヤーがある場合のみ表示
import Quickshell.Services.Mpris
import QtQuick

Item {
    id: root

    // 最初の再生中プレイヤーを取得、なければ最初のプレイヤー
    property var activePlayer: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    property bool hasPlayer: activePlayer !== null

    visible: hasPlayer
    implicitWidth: hasPlayer ? mediaRow.implicitWidth : 0
    implicitHeight: 36

    Row {
        id: mediaRow
        anchors.centerIn: parent
        spacing: 4

        // 再生状態アイコン
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? "▶" : "⏸"
            color: "#9ece6a"
            font { pixelSize: 10 }
        }

        // 曲名 + アーティスト
        Text {
            anchors.verticalCenter: parent.verticalCenter
            property string title: root.activePlayer?.trackTitle ?? ""
            property string artist: root.activePlayer?.trackArtists?.join(", ") ?? ""
            text: {
                var full = artist.length > 0 ? artist + " - " + title : title
                return full.length > 30 ? full.substring(0, 28) + "…" : full
            }
            color: "#7dcfff"
            font { pixelSize: 12 }
        }

        // 前の曲ボタン
        BarIconButton {
            icon: "⏮"
            onClicked: root.activePlayer?.previous()
        }

        // 再生/一時停止ボタン
        BarIconButton {
            icon: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"
            onClicked: root.activePlayer?.playPause()
        }

        // 次の曲ボタン
        BarIconButton {
            icon: "⏭"
            onClicked: root.activePlayer?.next()
        }
    }
}
