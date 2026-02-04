import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    property real usage: 0

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function updateFromMeminfo(text) {
        var lines = text.split(/\r?\n/)
        var total = 0
        var available = 0
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i]
            if (line.indexOf("MemTotal:") === 0) {
                total = Number(line.replace(/[^0-9]/g, ""))
            } else if (line.indexOf("MemAvailable:") === 0) {
                available = Number(line.replace(/[^0-9]/g, ""))
            }
        }
        if (total > 0) {
            var used = total - available
            var pct = used / total * 100
            usage = Math.max(0, Math.min(100, pct))
        }
    }

    Process {
        id: memProc
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateFromMeminfo(this.text)
        }
    }

    Timer {
        interval: Theme.memPollInterval
        running: true
        repeat: true
        onTriggered: memProc.running = true
    }

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: row.implicitWidth + paddingX * 2
        radius: Theme.blockRadius
        color: Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Row {
            id: row
            spacing: 8
            anchors.centerIn: parent
            height: Math.max(iconLabel.implicitHeight, valueLabel.implicitHeight)

            Text {
                id: iconLabel
                text: Theme.memIcon
                color: Theme.memText
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize
                font.weight: Theme.fontWeight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: valueLabel
                text: Math.round(root.usage) + "%"
                color: Theme.memText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
