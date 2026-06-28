import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Launcher

// アプリランチャー
// 画面全体を覆う1枚のPanelWindowで構成:
//   - 外側 (透明) をクリック → 閉じる
//   - 内側 (パネルUI) のクリックはここで止める
//   - ESCキーは子のItemで受け取る
PanelWindow {
    id: launcherWindow

    signal requestClose()

    // 画面全体を覆う
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.layer: WlrLayer.Overlay

    // ====== カラーテーマ (Tokyo Night) ======
    readonly property color colorBg:       "#1a1b26"
    readonly property color colorFg:       "#a9b1d6"
    readonly property color colorFgDim:    "#565f89"
    readonly property color colorAccent:   "#7aa2f7"
    readonly property color colorBorder:   "#3b4261"
    readonly property color colorSearchBg: "#1f2335"
    readonly property color colorHover:    "#2d3f6c"
    readonly property int   cornerRadius:  12

    // ====== グリッド設定 ======
    readonly property int colCount:    5
    readonly property int itemSize:    120
    readonly property int itemSpacing: 8
    readonly property int maxRows:     4

    // ====== 状態 ======
    property string searchQuery: ""

    // フィルタリングされたアプリ一覧
    ScriptModel {
        id: filteredApps
        values: {
            const all = [...DesktopEntries.applications.values]
                .filter(d => d.name && !d.noDisplay)
                .sort((a, b) => a.name.localeCompare(b.name, "ja"))

            const q = launcherWindow.searchQuery.trim().toLowerCase()
            if (q === "") return all

            return all.filter(d => {
                const name     = (d.name     || "").toLowerCase()
                const comment  = (d.comment  || "").toLowerCase()
                const keywords = (d.keywords || []).join(" ").toLowerCase()
                const cats     = (d.categories || []).join(" ").toLowerCase()
                return name.includes(q) || comment.includes(q)
                    || keywords.includes(q) || cats.includes(q)
            })
        }
    }

    // ====== 表示時に検索バーをリセット ======
    // Timerで少し遅延させてウィンドウがコンポジターに接続されてからフォーカスを渡す
    onVisibleChanged: {
        if (visible) {
            launcherWindow.searchQuery = ""
            searchInput.text = ""
            focusTimer.start()
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    // ======================================================
    // 全画面のルートItem (Keysはここに付ける)
    // ======================================================
    Item {
        id: rootItem
        anchors.fill: parent
        // focusはTextInputに任せる。rootItemにfocus:trueを置くと
        // TextInputへの入力が競合してブロックされる。
        // ESCキーはTextInputのKeysハンドラで処理する。

        // --------------------------------------------------
        // 外側クリックで閉じる (パネル領域外のクリックのみ反応)
        // --------------------------------------------------
        MouseArea {
            anchors.fill: parent
            z: 0
            onClicked: (mouse) => {
                // クリック座標がパネル内なら無視
                const mapped = panelContent.mapFromItem(rootItem, mouse.x, mouse.y)
                if (mapped.x < 0 || mapped.y < 0 ||
                    mapped.x > panelContent.width ||
                    mapped.y > panelContent.height) {
                    launcherWindow.requestClose()
                }
            }
        }

        // --------------------------------------------------
        // パネル本体 (上部中央に配置)
        // --------------------------------------------------
        Rectangle {
            id: panelContent

            readonly property int panelWidth: 700
            readonly property int rowHeight: launcherWindow.itemSize + launcherWindow.itemSpacing + 24
            readonly property int actualRows: Math.ceil(filteredApps.values.length / launcherWindow.colCount)
            readonly property int gridHeight: Math.min(actualRows * rowHeight, rowHeight * launcherWindow.maxRows)
            readonly property int panelHeight: 44 + 12 + 8 + gridHeight + 4 + 32

            width:  panelWidth
            height: panelHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 12

            color:        launcherWindow.colorBg
            radius:       launcherWindow.cornerRadius
            border.color: launcherWindow.colorBorder
            border.width: 1
            layer.enabled: true

            // ========== 検索バー ==========
            Rectangle {
                id: searchRow
                anchors {
                    top:     parent.top
                    left:    parent.left
                    right:   parent.right
                    margins: 12
                }
                height: 44
                radius: 8
                color:  launcherWindow.colorSearchBg
                border.color: searchInput.activeFocus
                              ? launcherWindow.colorAccent
                              : launcherWindow.colorBorder
                border.width: searchInput.activeFocus ? 2 : 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 8

                    // 検索アイコン
                    Text {
                        text: "\uF002"
                        font.family:    "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: launcherWindow.colorFgDim
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // 検索入力フィールド
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.pixelSize:   16
                        font.family:      "Sans"
                        color:            launcherWindow.colorFg
                        clip:             true
                        selectByMouse:    true

                        onTextChanged: launcherWindow.searchQuery = text

                        Keys.onEscapePressed: {
                            if (text !== "") {
                                text = ""
                            } else {
                                launcherWindow.requestClose()
                            }
                        }

                        Keys.onReturnPressed: {
                            if (filteredApps.values.length > 0) {
                                filteredApps.values[0].execute()
                                launcherWindow.requestClose()
                            }
                        }
                    }

                    // クリアボタン
                    Text {
                        text: "\uF057"
                        font.family:    "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: launcherWindow.colorFgDim
                        visible: searchInput.text !== ""
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                searchInput.text = ""
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // ========== アプリグリッド ==========
            Item {
                id: gridArea
                anchors {
                    top:          searchRow.bottom
                    left:         parent.left
                    right:        parent.right
                    bottom:       parent.bottom
                    topMargin:    8
                    bottomMargin: 12
                    leftMargin:   12
                    rightMargin:  12
                }
                ScrollView {
                    anchors.fill:  parent
                    clip:          true
                    contentHeight: appGrid.implicitHeight
                    contentWidth:  width
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy:   ScrollBar.AsNeeded

                    GridLayout {
                        id: appGrid
                        width:         parent.width
                        columns:       launcherWindow.colCount
                        columnSpacing: launcherWindow.itemSpacing
                        rowSpacing:    launcherWindow.itemSpacing

                        Repeater {
                            model: filteredApps.values
                            delegate: AppItem {
                                required property var modelData
                                required property int index

                                Layout.preferredWidth:  launcherWindow.itemSize
                                Layout.preferredHeight: launcherWindow.itemSize + 24
                                Layout.alignment:       Qt.AlignTop | Qt.AlignHCenter

                                appEntry:    modelData
                                colorHover:  launcherWindow.colorHover
                                colorFg:     launcherWindow.colorFg
                                colorFgDim:  launcherWindow.colorFgDim
                                colorAccent: launcherWindow.colorAccent
                                radius:      8

                                onLaunched: launcherWindow.requestClose()
                            }
                        }

                        // 末尾の空きセルを埋めるスペーサー
                        Repeater {
                            model: {
                                const rem = filteredApps.values.length % launcherWindow.colCount
                                return rem === 0 ? 0 : launcherWindow.colCount - rem
                            }
                            Item {
                                Layout.preferredWidth:  launcherWindow.itemSize
                                Layout.preferredHeight: launcherWindow.itemSize + 24
                            }
                        }
                    }
                }

                // 検索結果ゼロ時のメッセージ
                Text {
                    anchors.centerIn: parent
                    visible:   filteredApps.values.length === 0
                    text:      "アプリが見つかりません: \"" + launcherWindow.searchQuery + "\""
                    color:     launcherWindow.colorFgDim
                    font.pixelSize: 14
                }
            }
        }
    }
}
