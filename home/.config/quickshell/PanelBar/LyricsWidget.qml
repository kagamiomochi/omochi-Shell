// LyricsWidget.qml - LRCLIB 歌詞ウィジェット (v0.3.0)
//
// 取得戦略 (3段階フォールバック):
//   Step 1: /api/get?track_name&artist_name&album_name&duration  (完全一致)
//   Step 2: /api/get?track_name&artist_name                      (duration省略)
//   Step 3: /api/search?track_name&artist_name                   (FTS検索、先頭からsynced優先)
//   + タイトルの "(feat. ...)" "[Radio Edit]" 等をクリーニングして再試行
//
// 各ステップで syncedLyrics が取れたら採用、plainLyrics のみならそれを使用

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
    property int fetchStep: 0      // 0=idle, 1=full, 2=nodur, 3=search, 4=clean+full, 5=clean+search
    property string cleanTitle: "" // suffix除去済みタイトル

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
    property string watchedAlbum:  player?.trackAlbum  ?? ""

    onWatchedTitleChanged:  Qt.callLater(checkAndFetch)
    onWatchedArtistChanged: Qt.callLater(checkAndFetch)

    function checkAndFetch() {
        var key = watchedTitle + "::" + watchedArtist
        if (key === "::" || key === currentTrackKey) return
        currentTrackKey = key
        root.lrcLines = []
        root.fetchStep = 0
        // タイトルから "(feat. ...)" "[...]" "- Radio Edit" 等を除去したクリーン版を準備
        root.cleanTitle = watchedTitle
            .replace(/\s*[\(\[（【][^)\]）】]*[\)\]）】]/g, "") // (feat.) [Remix] 等
            .replace(/\s*-\s*(Radio Edit|Remaster(ed)?|Live|Acoustic|Instrumental|Short Ver\.?|TV Size)\s*$/i, "")
            .trim()
        if (watchedTitle !== "") startFetch()
    }

    // ===== フェッチ開始 (step管理) =====
    function startFetch() {
        fetchStep++
        root.fetchBuf = ""
        var title  = (fetchStep >= 4) ? root.cleanTitle : watchedTitle
        var artist = watchedArtist
        var album  = watchedAlbum
        var dur    = player?.length ? Math.round(player.length) : 0

        var args = [
            "curl", "-s", "-m", "10",
            "-H", "User-Agent: omochi-Shell/1.0 (https://github.com/kagamiomochi/omochi-Shell)",
            "--get"
        ]

        if (fetchStep === 1) {
            // Step 1: 完全一致 (title + artist + album + duration)
            args.push("--data-urlencode", "track_name=" + title)
            args.push("--data-urlencode", "artist_name=" + artist)
            if (album !== "") args.push("--data-urlencode", "album_name=" + album)
            if (dur > 0)      args.push("--data-urlencode", "duration=" + dur)
            args.push("https://lrclib.net/api/get")

        } else if (fetchStep === 2) {
            // Step 2: duration・album なし
            args.push("--data-urlencode", "track_name=" + title)
            args.push("--data-urlencode", "artist_name=" + artist)
            args.push("https://lrclib.net/api/get")

        } else if (fetchStep === 3) {
            // Step 3: FTS search
            args.push("--data-urlencode", "track_name=" + title)
            args.push("--data-urlencode", "artist_name=" + artist)
            args.push("https://lrclib.net/api/search")

        } else if (fetchStep === 4) {
            // Step 4: クリーニング済みタイトル + duration なし
            args.push("--data-urlencode", "track_name=" + title)
            args.push("--data-urlencode", "artist_name=" + artist)
            args.push("https://lrclib.net/api/get")

        } else if (fetchStep === 5) {
            // Step 5: クリーニング済みタイトル + FTS search
            args.push("--data-urlencode", "track_name=" + title)
            args.push("--data-urlencode", "artist_name=" + artist)
            args.push("https://lrclib.net/api/search")

        } else {
            // 全ステップ失敗
            lyricsText.text = ""
            return
        }

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

            if (code !== 0 || raw.trim() === "") {
                startFetch()  // 次のステップへ
                return
            }

            try {
                var parsed = JSON.parse(raw)

                // search エンドポイントは配列を返す
                var obj = null
                if (Array.isArray(parsed)) {
                    // synced優先で先頭から探す
                    for (var i = 0; i < parsed.length; i++) {
                        if (parsed[i].syncedLyrics) { obj = parsed[i]; break }
                    }
                    // syncedなければplainで
                    if (!obj) {
                        for (var j = 0; j < parsed.length; j++) {
                            if (parsed[j].plainLyrics) { obj = parsed[j]; break }
                        }
                    }
                } else {
                    obj = parsed
                }

                if (!obj || obj.statusCode === 404 || obj.error) {
                    startFetch()  // 次のステップへ
                    return
                }

                if (obj.instrumental === true) {
                    // インスト曲は歌詞なし扱い
                    lyricsText.text = ""
                    root.lrcLines = []
                    return
                }

                if (obj.syncedLyrics) {
                    root.lrcLines = parseLrc(obj.syncedLyrics)
                    updateLine()
                } else if (obj.plainLyrics) {
                    root.lrcLines = []
                    lyricsText.text = obj.plainLyrics.split("\n")[0] ?? ""
                } else {
                    startFetch()  // 次のステップへ
                }

            } catch(e) {
                startFetch()
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

    // ===== 行の更新 =====
    function updateLine() {
        if (!player || root.lrcLines.length === 0) return
        var posSec = player.position
        var line = ""
        for (var i = 0; i < root.lrcLines.length; i++) {
            if (root.lrcLines[i].time <= posSec) {
                line = root.lrcLines[i].text
            } else {
                break
            }
        }
        if (lyricsText.text !== line) lyricsText.text = line
    }

    // ===== position ポーリング =====
    Timer {
        id: posTimer
        interval: 300
        running: root.lrcLines.length > 0
                 && root.player !== null
                 && root.player.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: {
            if (!root.player) return
            root.player.positionChanged()
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
