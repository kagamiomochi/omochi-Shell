import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// グリッドの1アイテム (アプリアイコン + アプリ名)
Item {
    id: root

    // ====== プロパティ ======
    required property var   appEntry
    property color colorBg:     "#1a1b26"
    property color colorHover:  "#2d3f6c"
    property color colorFg:     "#a9b1d6"
    property color colorFgDim:  "#565f89"
    property color colorAccent: "#7aa2f7"
    property int   radius:      8

    signal launched()

    // ====== 状態 ======
    property bool hovered:  hoverArea.containsMouse
    property bool pressed:  hoverArea.pressed

    // ====== 背景 ======
    Rectangle {
        id: bg
        anchors.fill:    parent
        radius:          root.radius
        color:           root.pressed  ? Qt.darker(root.colorHover, 1.15)
                       : root.hovered  ? root.colorHover
                       :                 "transparent"
        border.color:    root.hovered  ? root.colorAccent : "transparent"
        border.width:    1

        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        scale: root.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
    }

    // ====== レイアウト ======
    ColumnLayout {
        anchors {
            fill:    parent
            margins: 8
        }
        spacing: 4

        // アイコン
        IconImage {
            id: appIcon
            Layout.alignment:        Qt.AlignHCenter
            Layout.preferredWidth:   52
            Layout.preferredHeight:  52

            source: root.appEntry.icon
                    ? "image://icon/" + root.appEntry.icon
                    : "image://icon/application-x-executable"

            // アイコンが読み込めない場合のフォールバック
            onStatusChanged: {
                if (status === Image.Error) {
                    source = "image://icon/application-x-executable"
                }
            }
        }

        // アプリ名
        Text {
            id: appName
            Layout.fillWidth:    true
            Layout.alignment:    Qt.AlignHCenter

            text:            root.appEntry.name || ""
            color:           root.hovered ? root.colorFg : Qt.darker(root.colorFg, 1.1)
            font.pixelSize:  11
            font.family:     "Sans"
            horizontalAlignment: Text.AlignHCenter
            wrapMode:        Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: 2
            elide:           Text.ElideRight
            lineHeight:      1.2

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // ====== インタラクション ======
    MouseArea {
        id: hoverArea
        anchors.fill:       parent
        hoverEnabled:       true
        acceptedButtons:    Qt.LeftButton

        onClicked: {
            root.appEntry.execute()
            root.launched()
        }
    }

    // ====== ツールチップ (アプリの説明) ======
    ToolTip {
        id: tooltip
        visible:  root.hovered && (root.appEntry.comment || "").trim() !== ""
        text:     root.appEntry.comment || ""
        delay:    600
        timeout:  4000
    }
}
