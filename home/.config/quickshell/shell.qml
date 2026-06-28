//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "PanelBar"
import "Launcher"

ShellRoot {
    id: root

    // ====== ステータスバー ======
    Variants {
        model: Quickshell.screens

        PanelBar {
            required property var modelData
            screen: modelData
        }
    }

    // ====== アプリランチャー ======
    property bool launcherVisible: false

    IpcHandler {
        target: "launcher"

        function show():   void { root.launcherVisible = true  }
        function hide():   void { root.launcherVisible = false }
        function toggle(): void { root.launcherVisible = !root.launcherVisible }
    }

    AppLauncher {
        visible: root.launcherVisible
        onRequestClose: root.launcherVisible = false
    }
}
