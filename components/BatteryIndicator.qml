import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    property int percent: 0
    property string state: "unknown"
    property bool available: true
    property bool acOnline: false
    property int brightnessPercent: 0
    property bool brightnessAvailable: true
    property bool pendingBrightnessOsdSync: false

    signal brightnessOsdRequested(int brightnessPercent, bool available)

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function updateFromOutput(text) {
        var lines = text.split(/\r?\n/)
        var pct = 0
        var st = "unknown"
        available = true
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

    function updateBrightnessFromOutput(text) {
        var out = (text || "").trim()
        if (out.length === 0 || out.indexOf("__QSERR__") !== -1) {
            brightnessAvailable = false
            brightnessPercent = 0
            return
        }

        brightnessAvailable = true
        var match = out.match(/([0-9]{1,3})(?:\.[0-9]+)?%?/)
        if (match && match[1]) {
            brightnessPercent = clampPercent(match[1])
            return
        }
        brightnessPercent = 0
    }

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(Number(value) || 0)))
    }

    function requestBrightnessOsd(percentHint) {
        var pct = percentHint
        if (pct === undefined || pct === null || isNaN(Number(pct))) {
            pct = brightnessPercent
        }
        brightnessOsdRequested(clampPercent(pct), brightnessAvailable)
    }

    function adjustBrightness(isUp) {
        var step = Math.max(1, Theme.brightnessStepPercent)
        var predicted = clampPercent(brightnessPercent + (isUp ? step : -step))
        pendingBrightnessOsdSync = true
        requestBrightnessOsd(predicted)

        setBrightnessProc.command = ["sh", "-c",
            "if command -v brightnessctl >/dev/null 2>&1; then " +
            "brightnessctl set " + step + "%" + (isUp ? "+" : "-") + "; " +
            "elif command -v light >/dev/null 2>&1; then " +
            (isUp ? ("light -A " + step) : ("light -U " + step)) + "; " +
            "else printf '__QSERR__ missing:brightnessctl-or-light\\n'; fi"]
        setBrightnessProc.running = true
    }

    Process {
        id: battProc
        command: ["sh", "-c", "b=$(upower -e | grep -m1 BAT); a=$(upower -e | grep -m1 line_power); if [ -z \"$b\" ]; then echo NO_BATTERY; else upower -i \"$b\" | grep -E 'state:|percentage:'; if [ -n \"$a\" ]; then upower -i \"$a\" | grep -E 'online:'; fi; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateFromOutput(this.text)
        }
    }

    Process {
        id: brightnessProc
        command: ["sh", "-c", "if command -v brightnessctl >/dev/null 2>&1; then brightnessctl -m | awk -F, 'NR==1{print $4}'; elif command -v light >/dev/null 2>&1; then light -G | awk '{printf \"%d%%\\n\", $1}'; else printf '__QSERR__ missing:brightnessctl-or-light\\n'; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.updateBrightnessFromOutput(this.text)
                if (root.pendingBrightnessOsdSync) {
                    root.pendingBrightnessOsdSync = false
                    root.requestBrightnessOsd(root.brightnessPercent)
                }
            }
        }
    }

    Process {
        id: setBrightnessProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: brightnessProc.running = true
        }
    }

    Timer {
        interval: Theme.batteryPollInterval
        running: true
        repeat: true
        onTriggered: battProc.running = true
    }

    Timer {
        interval: Theme.brightnessPollInterval
        running: true
        repeat: true
        onTriggered: brightnessProc.running = true
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

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            onWheel: function(wheel) {
                if (!wheel || wheel.angleDelta.y === 0) {
                    return
                }
                root.adjustBrightness(wheel.angleDelta.y > 0)
                wheel.accepted = true
            }
        }
    }
}
