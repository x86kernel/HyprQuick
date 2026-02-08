import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    property int percent: 0
    property string state: "unknown"
    property bool available: true
    property bool acOnline: false

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function updateFromOutput(text) {
        var lines = text.split(/\r?\n/)
        var pct = 0
        var st = "unknown"
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.indexOf("percentage:") === 0) {
                pct = Number(line.replace(/[^0-9]/g, ""))
            } else if (line.indexOf("state:") === 0) {
                st = line.split(":")[1].trim()
            } else if (line.indexOf("online:") === 0) {
                acOnline = line.split(":")[1].trim() === "yes"
            } else if (line === "NO_BATTERY") {
                available = false
            }
        }
        if (!available) {
            percent = 0
            state = "unknown"
            return
        }
        percent = pct
        state = st
    }

    Process {
        id: battProc
        command: ["sh", "-c", "b=$(upower -e | grep -m1 BAT); a=$(upower -e | grep -m1 line_power); if [ -z \"$b\" ]; then echo NO_BATTERY; else upower -i \"$b\" | grep -E 'state:|percentage:'; if [ -n \"$a\" ]; then upower -i \"$a\" | grep -E 'online:'; fi; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateFromOutput(this.text)
        }
    }

    Timer {
        interval: Theme.batteryPollInterval
        running: true
        repeat: true
        onTriggered: battProc.running = true
    }

    function iconForState() {
        if (acOnline && state === "charging") return Theme.batteryIconCharging
        if (acOnline && state === "fully-charged") return Theme.batteryIconFull
        if (acOnline) return Theme.batteryIconCharging
        if (state === "fully-charged") return Theme.batteryIconFull
        if (percent >= 80) return Theme.batteryIconDischargingHigh
        if (percent >= 50) return Theme.batteryIconDischargingMid
        return Theme.batteryIconDischargingLow
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
                text: iconForState()
                color: Theme.batteryText
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize
                font.weight: Theme.fontWeight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: valueLabel
                text: available ? (percent + "%") : Theme.batteryUnavailableText
                color: Theme.batteryText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
