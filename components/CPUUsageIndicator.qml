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
    property string tooltipText: ""
    signal clicked

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
        var packageLine = ""
        var coreLine = ""
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.length === 0) {
                continue
            }
            if (!/[+-]?[0-9.]+\s*°?C/.test(line)) {
                continue
            }
            temps.push(line)
            if (packageLine.length === 0 && line.indexOf("Package id 0:") === 0) {
                packageLine = line
            }
            if (coreLine.length === 0 && line.indexOf("Core 0:") === 0) {
                coreLine = line
            }
        }
        if (temps.length === 0) {
            return I18n.t("cpu.temp_na")
        }
        function extractTemp(line) {
            var m = line.match(/[+-]?[0-9.]+\s*°?C/)
            return m && m[0] ? m[0].replace(/\s+/g, "") : ""
        }
        if (packageLine.length > 0) {
            return extractTemp(packageLine)
        }
        if (coreLine.length > 0) {
            return extractTemp(coreLine)
        }
        return extractTemp(temps[0])
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
                root.tooltipText = root.parseSensors(this.text)
            }
        }
    }

    Timer {
        interval: Theme.cpuTooltipPollInterval
        running: true
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
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
