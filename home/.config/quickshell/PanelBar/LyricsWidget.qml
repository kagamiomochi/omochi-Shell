// LyricsWidget.qml - LRCLIB 歌詞ウィジェット (v0.3.0)
// MPRISから再生中の曲情報を取得し、lrclib.net APIで歌詞を検索。
// syncedLyrics (LRC形式) を再生位置に合わせてリアルタイム表示。

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Item {
    id: root
    implicitHeight: 36
    implicitWidth: lyricsText.width + 16

    visible: displayLine.length > 0

    // ===== 状態 =====
    property string displayLine: ""   // 実際に表示する行
    property string currentLine: ""   // 計算上の現在行
    property string currentTrackKey: ""
    property var lrcLines: []
    property string fetchBuf: ""

    // displayLine は currentLine 変化時にフェードで更新
    onCurrentLineChanged: fadeOut.start()

    // ===== プレイヤー =====
    property var player: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    property string watchedTitle:  player?.trackTitle ?? ""
    property string watchedArtist: player?.trackArtist ?? ""

    onWatchedTitleChanged:  Qt.callLater(checkAndFetch)
    onWatchedArtistChanged: Qt.callLater(checkAndFetch)

    function checkAndFetch() {
        var key = watchedTitle + "::" + watchedArtist
        if (key === "::" || key === currentTrackKey) return
        currentTrackKey = key
        root.lrcLines = []
        root.currentLine = ""
        root.displayLine = ""
        if (watchedTitle !== "") fetchLyrics()
    }

    // ===== 歌詞フェッチ =====
    // curl の --get / --data-urlencode でシェル側にURLエンコードを任せる
    function fetchLyrics() {
        var duration = player?.trackDuration
            ? Math.round(player.trackDuration / 1000) : 0

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
                } else if (obj.plainLyrics) {
                    root.currentLine  = obj.plainLyrics.split("\n")[0] ?? ""
                    root.displayLine  = root.currentLine
                    root.lrcLines = []
                } else {
                    root.lrcLines = []
                    root.currentLine = ""
                    root.displayLine = ""
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

    // ===== 再生位置に合わせて行を更新 =====
    Timer {
        id: posTimer
        interval: 350
        running: root.lrcLines.length > 0 && root.player !== null
        repeat: true
        onTriggered: {
            if (!root.player || root.lrcLines.length === 0) return
            var posSec = (root.player.position ?? 0) / 1000.0
            var line = ""
            for (var i = 0; i < root.lrcLines.length; i++) {
                if (root.lrcLines[i].time <= posSec) {
                    line = root.lrcLines[i].text
                } else {
                    break
                }
            }
            if (line !== root.currentLine) root.currentLine = line
        }
    }

    // ===== 表示 + フェードアニメーション =====
    Text {
        id: lyricsText
        anchors.centerIn: parent
        text: root.displayLine
        color: "#c0caf5"
        font { pixelSize: 13 }
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 480)
    }

    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: lyricsText; property: "opacity"; to: 0; duration: 100 }
        ScriptAction    { script: { root.displayLine = root.currentLine } }
        NumberAnimation { target: lyricsText; property: "opacity"; to: 1; duration: 180 }
    }

    Component.onCompleted: Qt.callLater(checkAndFetch)
}
