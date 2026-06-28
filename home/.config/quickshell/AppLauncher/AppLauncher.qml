import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// アプリランチャーパネル
// - 画面上部中央に表示
// - 検索バー付き
// - グリッドレイアウト
// - スクロール対応
PanelWindow {
    id: launcherWindow

    signal requestClose()

    // ====== レイアウト設定 ======
    // 上部アンカーのみ → 上端に貼り付け、左右は中央寄せ
    anchors.top: true
    exclusionMode: ExclusionMode.Ignore  // 他のウィンドウのスペースを奪わない

    // パネルサイズ
    implicitWidth:  700
    implicitHeight: visible ? panelContent.implicitHeight + 2 : 0

    // 中央寄せ (左右マージンで中央に)
    margins {
        left:  (Screen.width  - implicitWidth)  / 2
        right: (Screen.width  - implicitWidth)  / 2
        top:   12
    }

    color: "transparent"

    // キーボードフォーカスを排他的に取得
    WlrLayershell.keyboardFocus: KeyboardFocus.Exclusive
    WlrLayershell.layer: WlrLayer.Overlay

    // ====== カラーテーマ (Tokyo Night) ======
    readonly property color colorBg:          "#1a1b26"
    readonly property color colorBgHighlight: "#292e42"
    readonly property color colorBgPanel:     "#24283b"
    readonly property color colorFg:          "#a9b1d6"
    readonly property color colorFgDim:       "#565f89"
    readonly property color colorAccent:      "#7aa2f7"
    readonly property color colorAccentSoft:  "#3d59a1"
    readonly property color colorBorder:      "#3b4261"
    readonly property color colorSearchBg:    "#1f2335"
    readonly property color colorHover:       "#2d3f6c"
    readonly property int   cornerRadius:     12

    // ====== グリッド設定 ======
    readonly property int colCount:    5        // 列数
    readonly property int itemSize:    120      // アイテムの幅・高さ
    readonly property int itemSpacing: 8        // アイテム間の余白
    readonly property int maxRows:     4        // 最大表示行数 (超えたらスクロール)

    // ====== 状態 ======
    property string searchQuery: ""

    // ====== 表示時に検索バーにフォーカス ======
    onVisibleChanged: {
        if (visible) {
            searchQuery = ""
            searchInput.text = ""
            searchInput.forceActiveFocus()
        }
    }

    // ESCで閉じる (パネル自体でもキャッチ)
    Keys.onEscapePressed: launcherWindow.requestClose()

    // ====== フィルタリングされたアプリ一覧 ======
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

    // ====== メインコンテンツ ======
    Rectangle {
        id: panelContent
        anchors.fill: parent

        implicitHeight: searchRow.height + gridArea.implicitHeight + 32
        implicitWidth:  launcherWindow.implicitWidth

        color:        launcherWindow.colorBg
        radius:       launcherWindow.cornerRadius
        border.color: launcherWindow.colorBorder
        border.width: 1

        // ドロップシャドウ風の外枠
        layer.enabled: true

        // ========== 検索バー ==========
        Rectangle {
            id: searchRow
            anchors {
                top:   parent.top
                left:  parent.left
                right: parent.right
                margins: 12
            }
            height: 44
            radius: 8
            color:  launcherWindow.colorSearchBg
            border.color: searchInput.activeFocus
                          ? launcherWindow.colorAccent
                          : launcherWindow.colorBorder
            border.width: searchInput.activeFocus ? 2 : 1

            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            RowLayout {
                anchors {
                    fill:    parent
                    margins: 10
                }
                spacing: 8

                // 検索アイコン
                Text {
                    text:  "\uF002"        // Font Awesome magnifier (Nerd Font)
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
                    focus:            true
                    selectByMouse:    true

                    onTextChanged: {
                        launcherWindow.searchQuery = text
                    }

                    Keys.onEscapePressed: {
                        if (text !== "") {
                            text = ""
                        } else {
                            launcherWindow.requestClose()
                        }
                    }

                    // ← → でグリッドのフォーカス移動はしない (入力優先)
                    // Enter でグリッドの先頭アイテムを起動
                    Keys.onReturnPressed: {
                        if (filteredApps.values.length > 0) {
                            filteredApps.values[0].execute()
                            launcherWindow.requestClose()
                        }
                    }
                }

                // クリアボタン
                Text {
                    text:  "\uF057"        // Font Awesome circle-xmark (Nerd Font)
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

                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }
            }
        }

        // ========== アプリグリッド ==========
        Item {
            id: gridArea
            anchors {
                top:     searchRow.bottom
                left:    parent.left
                right:   parent.right
                bottom:  parent.bottom
                topMargin:    8
                bottomMargin: 12
                leftMargin:   12
                rightMargin:  12
            }

            // グリッド1行分の高さ
            readonly property int rowHeight: launcherWindow.itemSize + launcherWindow.itemSpacing + 24  // アイコン+ラベル
            readonly property int maxHeight: rowHeight * launcherWindow.maxRows

            // 実際に表示するアイテム数から行数を算出
            readonly property int actualRows: Math.ceil(filteredApps.values.length / launcherWindow.colCount)
            readonly property int gridHeight: Math.min(actualRows * rowHeight, maxHeight)

            implicitHeight: gridHeight + 4

            // スクロール可能なグリッド
            ScrollView {
                anchors.fill:  parent
                clip:          true
                contentHeight: appGrid.implicitHeight
                contentWidth:  width

                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy:   ScrollBar.AsNeeded

                // グリッド本体
                GridLayout {
                    id: appGrid
                    width:       parent.width
                    columns:     launcherWindow.colCount
                    columnSpacing: launcherWindow.itemSpacing
                    rowSpacing:    launcherWindow.itemSpacing

                    Repeater {
                        model: filteredApps.values

                        delegate: AppItem {
                            required property var  modelData
                            required property int  index

                            Layout.preferredWidth:  launcherWindow.itemSize
                            Layout.preferredHeight: launcherWindow.itemSize + 24
                            Layout.alignment:       Qt.AlignTop | Qt.AlignHCenter

                            appEntry:    modelData
                            colorBg:     launcherWindow.colorBg
                            colorHover:  launcherWindow.colorHover
                            colorFg:     launcherWindow.colorFg
                            colorFgDim:  launcherWindow.colorFgDim
                            colorAccent: launcherWindow.colorAccent
                            radius:      8

                            onLaunched: launcherWindow.requestClose()
                        }
                    }

                    // グリッドが疎な場合に残った列を埋めるスペーサー
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

            // 検索結果がゼロの場合のメッセージ
            Text {
                anchors.centerIn: parent
                visible:   filteredApps.values.length === 0
                text:      "アプリが見つかりません: \"" + launcherWindow.searchQuery + "\""
                color:     launcherWindow.colorFgDim
                font.pixelSize: 14
            }
        }
    }

    // 背景クリックで閉じる (パネルの外側エリア)
    // PanelWindow全体でクリックを検知し、パネル内はMouseAreaが消費する
    MouseArea {
        anchors.fill: parent
        onClicked: launcherWindow.requestClose()
        z: -1
    }
}
