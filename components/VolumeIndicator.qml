import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    property int volumePercent: 0
    property int volumePercentRaw: 0
    property int intendedVolumePercent: -1
    property int queuedVolumePercent: -1
    property real wheelDeltaRemainder: 0
    property bool muted: false
    property bool available: true
    property bool pendingOsdSync: false

    signal osdRequested(int volumePercent, bool muted, bool available)

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function updateFromOutput(text) {
        var out = (text || "").trim()
        if (out.length === 0 || out.indexOf("__QSERR__") !== -1) {
            available = false
            muted = false
            volumePercent = 0
            volumePercentRaw = 0
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
                volumePercentRaw = Math.max(0, Math.round(pct))
                volumePercent = clampPercent(volumePercentRaw)
                return
            }
        }

        var volMatch = out.match(/volume:\s*([0-9]+(?:\.[0-9]+)?)/i)
        if (volMatch && volMatch[1]) {
            var ratio = Number(volMatch[1])
            if (!isNaN(ratio)) {
                volumePercentRaw = Math.max(0, Math.round(ratio * 100))
                volumePercent = clampPercent(volumePercentRaw)
                return
            }
        }

        volumePercent = 0
        volumePercentRaw = 0
    }

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(Number(value) || 0)))
    }

    function requestOsd(percentHint) {
        var pct = percentHint
        if (pct === undefined || pct === null || isNaN(Number(pct))) {
            pct = volumePercent
        }
        osdRequested(clampPercent(pct), muted, available)
    }

    function queueVolumeBySteps(stepCount) {
        if (!stepCount || stepCount === 0) {
            return
        }
        var step = Math.max(1, Theme.volumeStepPercent)
        var base = intendedVolumePercent >= 0
            ? intendedVolumePercent
            : clampPercent(volumePercentRaw)
        var target = clampPercent(base + stepCount * step)

        intendedVolumePercent = target
        queuedVolumePercent = target
        pendingOsdSync = true
        requestOsd(target)
        applyVolumeTimer.restart()
    }

    function queueVolumeByWheelDelta(deltaY) {
        if (!deltaY || deltaY === 0) {
            return
        }
        wheelDeltaRemainder += deltaY
        var notch = 120
        var steps = 0

        while (Math.abs(wheelDeltaRemainder) >= notch) {
            var dir = wheelDeltaRemainder > 0 ? 1 : -1
            steps += dir
            wheelDeltaRemainder -= dir * notch
        }

        if (steps !== 0) {
            queueVolumeBySteps(steps)
        }
    }

    function applyQueuedVolume() {
        if (queuedVolumePercent < 0 || setVolumeProc.running) {
            return
        }
        var target = queuedVolumePercent
        queuedVolumePercent = -1

        setVolumeProc.command = ["sh", "-c",
            "if command -v wpctl >/dev/null 2>&1; then " +
            "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + String(target) + "%; " +
            "elif command -v pactl >/dev/null 2>&1; then " +
            "pactl set-sink-volume @DEFAULT_SINK@ " + String(target) + "%; fi"]
        setVolumeProc.running = true
    }

    Process {
        id: volumeProc
        command: ["sh", "-c", "if command -v wpctl >/dev/null 2>&1; then wpctl get-volume @DEFAULT_AUDIO_SINK@; elif command -v pactl >/dev/null 2>&1; then pactl get-sink-volume @DEFAULT_SINK@ | head -n1; pactl get-sink-mute @DEFAULT_SINK@; else printf '__QSERR__ missing:wpctl-or-pactl\\n'; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.updateFromOutput(this.text)
                root.intendedVolumePercent = root.clampPercent(root.volumePercentRaw)
                if (root.pendingOsdSync) {
                    root.pendingOsdSync = false
                    root.requestOsd(root.volumePercent)
                }
            }
        }
    }

    Process {
        id: setVolumeProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.queuedVolumePercent >= 0) {
                    root.applyQueuedVolume()
                } else {
                    volumeProc.running = true
                }
            }
        }
    }

    Timer {
        id: applyVolumeTimer
        interval: 40
        running: false
        repeat: false
        onTriggered: root.applyQueuedVolume()
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
                if (!wheel) {
                    return
                }
                var deltaY = wheel.angleDelta.y
                if (deltaY === 0 && wheel.pixelDelta && wheel.pixelDelta.y !== 0) {
                    deltaY = wheel.pixelDelta.y * 8
                }
                if (deltaY === 0) {
                    return
                }
                root.queueVolumeByWheelDelta(deltaY)
                wheel.accepted = true
            }
        }
    }
}
