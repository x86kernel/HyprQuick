import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    property var bar
    property int level: 0
    property bool available: true
    property bool open: false
    property real anim: open ? 1 : 0

    implicitWidth: Theme.brightnessPopupWidth
    implicitHeight: Math.max(1, brightnessBox.implicitHeight)
    visible: open || anim > 0.01
    color: "transparent"
    anchor.window: bar

    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }

    function reveal(brightnessPercent, isAvailable) {
        level = Math.max(0, Math.min(100, Math.round(Number(brightnessPercent) || 0)))
        available = !!isAvailable
        open = true
        if (bar && bar.updateBrightnessPopupAnchor) {
            bar.updateBrightnessPopupAnchor()
        }
        hideTimer.restart()
    }

    Rectangle {
        id: brightnessBox
        anchors.fill: parent
        radius: Theme.brightnessPopupRadius
        color: Theme.brightnessPopupBg
        border.width: 1
        border.color: Theme.brightnessPopupBorder
        implicitHeight: content.implicitHeight + Theme.brightnessPopupPadding * 2
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.brightnessPopupPadding
            spacing: 8

            Text {
                text: I18n.t("brightness.title")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                font.weight: Theme.fontWeight
            }

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: Theme.brightnessIcon
                    color: Theme.brightnessText
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize
                    font.weight: Theme.fontWeight
                    height: valueText.implicitHeight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: valueText
                    text: !root.available
                        ? Theme.brightnessUnavailableText
                        : (root.level + "%")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.controllerFontSizeSmall
                    font.weight: Theme.fontWeight
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                width: parent.width
                height: Theme.brightnessPopupProgressHeight
                radius: Theme.brightnessPopupProgressHeight / 2
                color: Theme.brightnessPopupProgressBg

                Rectangle {
                    width: parent.width * (root.available ? (root.level / 100) : 0)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.brightnessPopupProgressFill
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.brightnessPopupDuration
        repeat: false
        onTriggered: root.open = false
    }
}
