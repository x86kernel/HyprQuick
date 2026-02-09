import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    property var bar
    property var cpuUsageIndicator

    implicitWidth: Theme.cpuPopupWidth
    implicitHeight: Math.max(1, cpuBox.implicitHeight)
    property bool open: false
    property real anim: open ? 1 : 0
    visible: open || anim > 0.01
    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    color: "transparent"
    anchor.window: bar

    Rectangle {
        id: cpuBox
        anchors.fill: parent
        radius: Theme.cpuPopupRadius
        color: Theme.cpuPopupBg
        border.width: 1
        border.color: Theme.cpuPopupBorder
        implicitHeight: cpuContent.implicitHeight + Theme.cpuPopupPadding * 2
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Column {
            id: cpuContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.cpuPopupPadding
            spacing: 10

            Text {
                text: "CPU"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSize
                font.weight: Theme.fontWeight
            }

            Text {
                text: "Usage"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                font.weight: Theme.fontWeight
            }

            Rectangle {
                width: parent.width
                height: 10
                radius: 5
                color: Theme.blockBg

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (cpuUsageIndicator ? cpuUsageIndicator.usage : 0) / 100))
                    height: parent.height
                    radius: 5
                    color: Theme.cpuText
                }
            }

            Text {
                text: Math.round(cpuUsageIndicator ? cpuUsageIndicator.usage : 0) + "%"
                color: Theme.cpuText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                font.weight: Theme.fontWeight
            }

            Text {
                text: "Temperature"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                font.weight: Theme.fontWeight
            }

            Text {
                text: cpuUsageIndicator ? cpuUsageIndicator.tooltipText : "Temp: n/a"
                color: Theme.cpuTooltipText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                font.weight: Theme.fontWeight
                width: parent.width
                wrapMode: Text.Wrap
            }
        }
    }

    onOpenChanged: {
        if (open) {
            bar.updateCpuPopupAnchor()
        }
    }
}
