import QtQuick
import Quickshell.Io
import ".."

Item {
    id: root
    property bool hasClipboard: false
    property bool flashActive: false
    property string lastKey: ""

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function applyKey(key) {
        var trimmed = key.trim()
        hasClipboard = trimmed.length > 0
        if (trimmed.length > 0 && trimmed !== lastKey) {
            lastKey = trimmed
            flashActive = true
            flashTimer.restart()
        } else if (!hasClipboard) {
            flashActive = false
        }
    }

    Timer {
        id: flashTimer
        interval: Theme.clipboardFlashDuration
        repeat: false
        onTriggered: root.flashActive = false
    }

    Process {
        id: cliphistProc
        command: ["sh", "-c", "cliphist list | head -n 1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.applyKey(this.text)
        }
    }

    Timer {
        interval: Theme.clipboardPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cliphistProc.running = true
    }

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: iconLabel.implicitWidth + paddingX * 2
        radius: Theme.blockRadius
        color: root.flashActive ? Theme.clipboardFlashBg : Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Behavior on color {
            ColorAnimation { duration: Theme.clipboardFlashAnimMs }
        }

        Text {
            id: iconLabel
            anchors.centerIn: parent
            text: Theme.clipboardIcon
            color: root.flashActive ? Theme.clipboardActiveText : Theme.textPrimary
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize
            font.weight: Theme.fontWeight
        }
    }
}
