import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: watcher
    property var popup

    Process {
        id: watchProc
        command: ["wl-paste", "--watch", "echo", "changed"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                checkProc.running = true
            }
        }
    }

    Process {
        id: checkProc
        command: ["wl-paste", "--list-types"]
        property string buf: ""
        stdout: SplitParser {
            onRead: line => checkProc.buf += line + "\n"
        }
        onExited: (exitCode, exitStatus) => {
            const isSensitive = checkProc.buf.includes("x-kde-passwordManagerHint")
            checkProc.buf = ""
            if (isSensitive) {
                popup.show("", true)
            } else {
                contentProc.running = true
            }
        }
    }

    Process {
        id: contentProc
        command: ["wl-paste", "--no-newline"]
        property string buf: ""
        stdout: SplitParser {
            onRead: line => contentProc.buf += line
        }
        onExited: (exitCode, exitStatus) => {
            popup.show(contentProc.buf, false)
            contentProc.buf = ""
        }
    }
}