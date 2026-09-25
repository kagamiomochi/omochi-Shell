import QtQuick
import Quickshell.Widgets

// デスクトップアイコン1個分の見た目とドラッグ/起動の挙動。
// DesktopIcons.qml の Repeater から生成される。
Item {
    id: root

    property string entryName: ""
    property string iconSource: ""
    property string execCommand: ""
    property string filePath: ""
    property bool isDesktopEntry: false
    property bool selected: false

    // グリッド上の初期(または保存済みの)位置
    property real gridX: 0
    property real gridY: 0

    signal positionChanged(real x, real y)
    signal launchRequested()
    signal selectRequested(bool additive)

    width: 88
    height: 96
    x: gridX
    y: gridY

    // ドラッグ中はアニメーションさせない(追従が遅れて見えるため)。
    // ドラッグを離した瞬間のスナップ移動だけふわっと動かす。
    Behavior on x { enabled: !mouseArea.drag.active; NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
    Behavior on y { enabled: !mouseArea.drag.active; NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    property bool dragging: mouseArea.drag.active

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.selected
            ? Qt.rgba(0.478, 0.635, 0.969, 0.28)
            : (mouseArea.containsMouse || root.dragging ? Qt.rgba(1, 1, 1, 0.15) : "transparent")
        border.width: (root.selected || root.dragging) ? 1 : 0
        border.color: root.selected ? "#7aa2f7" : Qt.rgba(1, 1, 1, 0.4)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitSize: 48
            source: root.iconSource
            asynchronous: true
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: root.entryName
            color: "white"
            font.pixelSize: 11
            style: Text.Outline
            styleColor: "black"
        }
    }

    // 動かしている本人(root)を drag.target に渡すのが QtQuick の作法。
    // mouse.x/mouse.y を自前で足し引きすると、アイテムが動くたびに
    // 基準座標までズレていくのでガクガク・カーソルとのズレが起きる。
    // drag.target 経由ならその計算をQt側がシーン座標で正しくやってくれる。
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        drag.target: root
        drag.axis: Drag.XAndYAxis
        // 画面外にはみ出さないように軽く制限(不要ならこの2行は削除可)
        drag.minimumX: 0
        drag.minimumY: 0

        onReleased: () => {
            // スナップ・衝突回避は親(DesktopIcons.qml)側でまとめて判断するので、
            // ここではドロップした生の座標をそのまま伝える。
            root.positionChanged(root.x, root.y)
        }

        onClicked: (mouse) => {
            root.selectRequested((mouse.modifiers & Qt.ControlModifier) !== 0)
        }

        onDoubleClicked: (mouse) => {
            root.launchRequested()
        }
    }
}
