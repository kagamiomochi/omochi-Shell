pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root

    property alias agent: polkitAgent
    readonly property AuthFlow flow: polkitAgent.flow
    readonly property bool requestActive: polkitAgent.isActive
    readonly property bool registered: polkitAgent.isRegistered

    PolkitAgent {
        id: polkitAgent

        onAuthenticationRequestStarted: {
            console.log("PolkitService: 認証リクエストを受信")
        }
    }
}