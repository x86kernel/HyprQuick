import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    property real usage: 0
    property real lastTotal: 0
    property real lastIdle: 0
    property var parentWindow: null
    property bool hovered: false
    property string tooltipText: ""

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function updateFromStat(text) {
        var line = text.trim()
        if (line.length === 0)
            return
        var parts = line.split(/\s+/)
        if (parts.length < 5 || parts[0] !== "cpu")
            return
        var total = 0
        for (var i = 1; i < parts.length; i += 1) {
            total += Number(parts[i])
        }
        var idle = Number(parts[4]) + (parts.length > 5 ? Number(parts[5]) : 0)
        if (lastTotal > 0) {
            var deltaTotal = total - lastTotal
            var deltaIdle = idle - lastIdle
            if (deltaTotal > 0) {
                var pct = (deltaTotal - deltaIdle) / deltaTotal * 100
                usage = Math.max(0, Math.min(100, pct))
            }
        }
        lastTotal = total
        lastIdle = idle
    }

    Process {
        id: cpuProc
        command: ["sh", "-c", "grep '^cpu ' /proc/stat"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateFromStat(this.text)
        }
    }

    Timer {
        interval: Theme.cpuPollInterval
        running: true
        repeat: true
        onTriggered: cpuProc.running = true
    }

    function parseSensors(text) {
        var lines = text.split(/\r?\n/)
        var temps = []
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i]
            if (line.indexOf("°C") === -1) {
                continue
            }
            var trimmed = line.trim()
            if (trimmed.length > 0) {
                temps.push(trimmed)
            }
        }
        if (temps.length === 0) {
            return "Temp: n/a"
        }
        var maxLines = Theme.cpuTooltipMaxLines > 0 ? Theme.cpuTooltipMaxLines : 3
        var out = temps.slice(0, maxLines).join("\n")
        return out
    }

    function refreshSensors() {
        sensorsProc.running = true
    }

    Process {
        id: sensorsProc
        command: ["sh", "-c", "sensors"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.tooltipText = "CPU " + Math.round(root.usage) + "%\n" + root.parseSensors(this.text)
                root.updateTooltipPosition()
            }
        }
    }

    Timer {
        interval: Theme.cpuTooltipPollInterval
        running: root.hovered
        repeat: true
        onTriggered: root.refreshSensors()
        triggeredOnStart: true
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
                text: Theme.cpuIcon
                color: Theme.cpuText
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize
                font.weight: Theme.fontWeight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: valueLabel
                text: Math.round(root.usage) + "%"
                color: Theme.cpuText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onEntered: {
                root.hovered = true
                root.refreshSensors()
            }
            onExited: root.hovered = false
        }
    }
}
