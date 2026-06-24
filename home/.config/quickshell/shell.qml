// shell.qml - メインエントリポイント
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelBar {
            // required property var modelData はPanelBar側で宣言
            // Variantsが自動でmodelDataをインジェクトする
            required property var modelData
            screen: modelData
        }
    }
}
