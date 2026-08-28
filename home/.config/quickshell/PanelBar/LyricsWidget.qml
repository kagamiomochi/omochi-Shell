// LyricsWidget.qml - LRCLIB 歌詞ウィジェット (v0.3.0)
//
// 同期精度の改善:
//   - タイマーは positionChanged() emit 専用、行の判定も同じタイミングで即実行
//   - フェードアニメーションを廃止し、即時テキスト切り替えにすることで遅延をゼロに
//   - フェード中の currentLine="" による消え問題を解消
//
// 消え問題の修正:
//   - lrcLines が空でも displayLine を "" にしない
//   - フェッチ完了まで前の曲の最後の行を保持する

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Item {
    id: root
    implicitHeight: 36
    implicitWidth: lyricsText.implicitWidth + 16

    visible: lyricsText.text.length > 0

    // ===== 状態 =====
    property string currentTrackKey: ""
    property var lrcLines: []
    property string fetchBuf: ""

    // ===== プレイヤー =====
    property var player: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    property string watchedTitle:  player?.trackTitle  ?? ""
    property string watchedArtist: player?.trackArtist ?? ""

    onWatchedTitleChanged:  Qt.callLater(checkAndFetch)
    onWatchedArtistChanged: Qt.callLater(checkAndFetch)

    function checkAndFetch() {
        var key = watchedTitle + "::" + watchedArtist
        if (key === "::" || key === currentTrackKey) return
        currentTrackKey = key
        root.lrcLines = []
        // 消え防止: displayLine は fetchが完了してから更新する
        if (watchedTitle !== "") fetchLyrics()
    }

    // ===== 歌詞フェッチ =====
    function fetchLyrics() {
        var duration = player?.length ? Math.round(player.length) : 0

        var args = [
            "curl", "-s", "-m", "10",
            "-H", "User-Agent: omochi-Shell/1.0 (https://github.com/kagamiomochi/omochi-Shell)",
            "--get",
            "--data-urlencode", "track_name=" + watchedTitle,
            "--data-urlencode", "artist_name=" + watchedArtist
        ]
        if (duration > 0) {
            args.push("--data-urlencode")
            args.push("duration=" + duration)
        }
        args.push("https://lrclib.net/api/get")

        fetchProc.command = args
        fetchProc.running = true
    }

    Process {
        id: fetchProc
        command: []
        stdout: SplitParser {
            onRead: data => root.fetchBuf += data
        }
        onExited: (code, signal) => {
            var raw = root.fetchBuf
            root.fetchBuf = ""
            if (code !== 0 || raw.trim() === "") return
            try {
                var obj = JSON.parse(raw)
                if (obj.syncedLyrics) {
                    root.lrcLines = parseLrc(obj.syncedLyrics)
                    // フェッチ完了時に即座に現在位置の行を表示
                    updateLine()
                } else if (obj.plainLyrics) {
                    root.lrcLines = []
                    lyricsText.text = obj.plainLyrics.split("\n")[0] ?? ""
                } else {
                    root.lrcLines = []
                    lyricsText.text = ""
                }
            } catch(e) {
                root.lrcLines = []
            }
        }
    }

    // ===== LRC パーサー =====
    function parseLrc(lrc) {
        var lines = lrc.split("\n")
        var result = []
        var re = /^\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)$/
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(re)
            if (!m) continue
            var ms = m[3].length === 2 ? parseInt(m[3]) * 10 : parseInt(m[3])
            result.push({
                time: parseInt(m[1]) * 60 + parseInt(m[2]) + ms / 1000,
                text: m[4].trim()
            })
        }
        result.sort(function(a, b) { return a.time - b.time })
        return result
    }

    // ===== 行の更新 (タイマーから呼ぶ) =====
    function updateLine() {
        if (!player || root.lrcLines.length === 0) return
        // positionChanged() emit 直後に読むと最新値が返る (ドキュメント通り)
        var posSec = player.position
        var line = ""
        for (var i = 0; i < root.lrcLines.length; i++) {
            if (root.lrcLines[i].time <= posSec) {
                line = root.lrcLines[i].text
            } else {
                break
            }
        }
        // テキストを即時更新 (アニメーションなし → 遅延ゼロ)
        if (lyricsText.text !== line) lyricsText.text = line
    }

    // ===== position ポーリング =====
    // ドキュメント推奨: Timer で positionChanged() を emit → 即 position を読む
    Timer {
        id: posTimer
        interval: 300
        running: root.lrcLines.length > 0
                 && root.player !== null
                 && root.player.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: {
            if (!root.player) return
            root.player.positionChanged()  // position をリフレッシュ
            root.updateLine()
        }
    }

    // ===== 表示 =====
    Text {
        id: lyricsText
        anchors.centerIn: parent
        text: ""
        color: "#c0caf5"
        font { pixelSize: 13 }
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 500)
    }

    Component.onCompleted: Qt.callLater(checkAndFetch)
}
