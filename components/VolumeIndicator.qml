import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    property int volumePercent: 0
    property bool muted: false
    property bool available: true

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function updateFromOutput(text) {
        var out = (text || "").trim()
        if (out.length === 0 || out.indexOf("__QSERR__") !== -1) {
            available = false
            muted = false
            volumePercent = 0
            return
        }

        available = true
        var lower = out.toLowerCase()
        muted = lower.indexOf("muted") !== -1 || /\byes\b/.test(lower)

        var matches = out.match(/([0-9]{1,3})%/g)
        if (matches && matches.length > 0) {
            var pctText = matches[matches.length - 1].replace("%", "")
            var pct = Number(pctText)
            if (!isNaN(pct)) {
                volumePercent = Math.max(0, Math.min(100, Math.round(pct)))
                return
            }
        }

        var volMatch = out.match(/volume:\s*([0-9]+(?:\.[0-9]+)?)/i)
        if (volMatch && volMatch[1]) {
            var ratio = Number(volMatch[1])
            if (!isNaN(ratio)) {
                volumePercent = Math.max(0, Math.min(100, Math.round(ratio * 100)))
                return
            }
        }

        volumePercent = 0
    }

    function adjustVolume(isUp) {
        var step = Math.max(1, Theme.volumeStepPercent)
        var delta = String(step) + "%" + (isUp ? "+" : "-")
        setVolumeProc.command = ["sh", "-c",
            "if command -v wpctl >/dev/null 2>&1; then " +
            "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + delta + "; " +
            "elif command -v pactl >/dev/null 2>&1; then " +
            "pactl set-sink-volume @DEFAULT_SINK@ " + delta + "; fi"]
        setVolumeProc.running = true
    }

    Process {
        id: volumeProc
        command: ["sh", "-c", "if command -v wpctl >/dev/null 2>&1; then wpctl get-volume @DEFAULT_AUDIO_SINK@; elif command -v pactl >/dev/null 2>&1; then pactl get-sink-volume @DEFAULT_SINK@ | head -n1; pactl get-sink-mute @DEFAULT_SINK@; else printf '__QSERR__ missing:wpctl-or-pactl\\n'; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateFromOutput(this.text)
        }
    }

    Process {
        id: setVolumeProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: volumeProc.running = true
        }
    }

    Timer {
        interval: Theme.volumePollInterval
        running: true
        repeat: true
        onTriggered: volumeProc.running = true
    }

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX

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
                text: !root.available
                    ? Theme.volumeUnknownIcon
                    : (root.muted ? Theme.volumeMutedIcon : Theme.volumeIcon)
                color: Theme.volumeText
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize
                font.weight: Theme.fontWeight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: valueLabel
                text: root.available
                    ? (root.volumePercent + "%")
                    : Theme.volumeUnavailableText
                color: Theme.volumeText
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
                root.adjustVolume(wheel.angleDelta.y > 0)
                wheel.accepted = true
            }
        }
    }
}
