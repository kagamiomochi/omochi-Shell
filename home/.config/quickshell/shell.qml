//@ pragma UseQApplication
// shell.qml - メインエントリポイント
// UseQApplication: QsMenuAnchor (システムトレイの右クリックメニュー) に必要
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelBar {
            required property var modelData
            screen: modelData
        }
    }
}
