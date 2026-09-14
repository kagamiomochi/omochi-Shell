import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Launcher

PanelWindow {
    id: launcherWindow

    signal requestClose()

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
    readonly property color colorRed:      "#f7768e"
    readonly property int   cornerRadius:  12

    // ====== グリッド設定 ======
    readonly property int colCount:    5
    readonly property int itemSize:    120
    readonly property int itemSpacing: 8
    readonly property int maxRows:     4

    // ====== 状態 ======
    property string searchQuery:   ""
    property bool   powerMenuOpen: false

    // ====== コマンド実行 ======
    Process {
        id: runner
        command: []
        running: false
    }

    function runCmd(args) {
        runner.command = args
        runner.running = true
    }

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

    onVisibleChanged: {
        if (visible) {
            launcherWindow.searchQuery   = ""
            launcherWindow.powerMenuOpen = false
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

    Item {
        id: rootItem
        anchors.fill: parent

        // 外側クリックで閉じる
        MouseArea {
            anchors.fill: parent
            z: 0
            onClicked: (mouse) => {
                if (launcherWindow.powerMenuOpen) {
                    launcherWindow.powerMenuOpen = false
                    return
                }
                const mapped = panelContent.mapFromItem(rootItem, mouse.x, mouse.y)
                if (mapped.x < 0 || mapped.y < 0 ||
                    mapped.x > panelContent.width ||
                    mapped.y > panelContent.height) {
                    launcherWindow.requestClose()
                }
            }
        }

        // パネル本体
        Rectangle {
            id: panelContent

            readonly property int panelWidth:  700
            readonly property int rowHeight:   launcherWindow.itemSize + launcherWindow.itemSpacing + 24
            readonly property int actualRows:  Math.ceil(filteredApps.values.length / launcherWindow.colCount)
            readonly property int gridHeight:  Math.min(actualRows * rowHeight, rowHeight * launcherWindow.maxRows)
            readonly property int panelHeight: 44 + 12 + 8 + gridHeight + 4 + 32

            width:  panelWidth
            height: panelHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top:              parent.top
            anchors.topMargin:        12

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

                    // 検索入力
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
                            if (launcherWindow.powerMenuOpen) {
                                launcherWindow.powerMenuOpen = false
                            } else if (text !== "") {
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

                    // セパレータ
                    Rectangle {
                        width:  1
                        height: 22
                        color:  launcherWindow.colorBorder
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // ====== 電源ボタン ======
                    Item {
                        Layout.preferredWidth:  32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: powerBtnArea.containsMouse
                                   ? Qt.rgba(247/255, 118/255, 142/255, 0.15)
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uF011"
                            font.family:    "JetBrainsMono Nerd Font"
                            font.pixelSize: 17
                            color: launcherWindow.powerMenuOpen || powerBtnArea.containsMouse
                                   ? launcherWindow.colorRed
                                   : launcherWindow.colorFgDim
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: powerBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: launcherWindow.powerMenuOpen = !launcherWindow.powerMenuOpen
                        }
                    }
                }
            }

            // ====== 電源メニュー ドロップダウン ======
            Rectangle {
                id: powerMenu
                visible: launcherWindow.powerMenuOpen

                anchors.top:       searchRow.bottom
                anchors.right:     searchRow.right
                anchors.topMargin: 4
                z: 10

                width:  180
                height: powerMenuCol.implicitHeight + 8
                radius: 8
                color:        launcherWindow.colorBg
                border.color: launcherWindow.colorBorder
                border.width: 1
                layer.enabled: true

                Column {
                    id: powerMenuCol
                    anchors {
                        top:   parent.top
                        left:  parent.left
                        right: parent.right
                        margins: 4
                    }
                    spacing: 2

                    Repeater {
                        model: [
                            { label: "画面ロック",     icon: "\uF023", cmd: ["hyprlock"]               },
                            { label: "スリープ",       icon: "\uF186", cmd: ["systemctl", "suspend"]    },
                            { label: "ハイバネート",   icon: "\uF7E2", cmd: ["systemctl", "hibernate"]  },
                            { label: "再起動",         icon: "\uF2F9", cmd: ["systemctl", "reboot"]     },
                            { label: "シャットダウン", icon: "\uF011", cmd: ["systemctl", "poweroff"]   },
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width:  parent.width
                            height: 38
                            radius: 6
                            color: menuItemArea.containsMouse
                                   ? launcherWindow.colorHover
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                spacing: 10

                                Text {
                                    text: modelData.icon
                                    font.family:    "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: launcherWindow.colorFgDim
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: modelData.label
                                    font.pixelSize: 13
                                    font.family:    "Sans"
                                    color: launcherWindow.colorFg
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: menuItemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    launcherWindow.powerMenuOpen = false
                                    launcherWindow.requestClose()
                                    launcherWindow.runCmd(modelData.cmd)
                                }
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
