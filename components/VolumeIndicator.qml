import QtQuick
import "."

Item {
    id: root
    property int volumePercent: SystemState.volumePercent
    property int volumePercentRaw: SystemState.volumePercentRaw
    property int intendedVolumePercent: -1
    property int queuedVolumePercent: -1
    property real wheelDeltaRemainder: 0
    property bool muted: SystemState.volumeMuted
    property bool available: SystemState.volumeAvailable
    property bool pendingOsdSync: false

    signal osdRequested(int volumePercent, bool muted, bool available)

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

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
        if (queuedVolumePercent < 0) {
            return
        }
        var target = queuedVolumePercent
        queuedVolumePercent = -1
        SystemState.setVolumePercent(target)
    }

    Connections {
        target: SystemState
        function onVolumePercentChanged() {
            root.intendedVolumePercent = root.clampPercent(SystemState.volumePercentRaw)
            if (root.pendingOsdSync) {
                root.pendingOsdSync = false
                root.requestOsd(SystemState.volumePercent)
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
