import QtQuick
import "."

Item {
    id: root
    property int percent: SystemState.batteryPercent
    property string state: SystemState.batteryState
    property bool available: SystemState.batteryAvailable
    property bool acOnline: SystemState.acOnline
    property int brightnessPercent: SystemState.brightnessPercent
    property bool brightnessAvailable: SystemState.brightnessAvailable
    property bool pendingBrightnessOsdSync: false

    signal brightnessOsdRequested(int brightnessPercent, bool available)

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

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
        var steps = isUp ? 1 : -1
        var step = Math.max(1, Theme.brightnessStepPercent)
        var target = clampPercent(brightnessPercent + steps * step)
        pendingBrightnessOsdSync = true
        requestBrightnessOsd(target)
        SystemState.setBrightnessPercent(target)
    }

    Connections {
        target: SystemState
        function onBrightnessPercentChanged() {
            if (root.pendingBrightnessOsdSync) {
                root.pendingBrightnessOsdSync = false
                root.requestBrightnessOsd(SystemState.brightnessPercent)
            }
        }
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
