import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    property var bar
    property int level: 0
    property bool muted: false
    property bool available: true
    property bool open: false
    property real anim: open ? 1 : 0

    implicitWidth: Theme.volumePopupWidth
    implicitHeight: Math.max(1, volumeBox.implicitHeight)
    visible: open || anim > 0.01
    color: "transparent"
    anchor.window: bar

    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }

    function reveal(volumePercent, isMuted, isAvailable) {
        level = Math.max(0, Math.min(100, Math.round(Number(volumePercent) || 0)))
        muted = !!isMuted
        available = !!isAvailable
        open = true
        if (bar && bar.updateVolumePopupAnchor) {
            bar.updateVolumePopupAnchor()
        }
        hideTimer.restart()
    }

    Rectangle {
        id: volumeBox
        anchors.fill: parent
        radius: Theme.volumePopupRadius
        color: Theme.volumePopupBg
        border.width: 1
        border.color: Theme.volumePopupBorder
        implicitHeight: content.implicitHeight + Theme.volumePopupPadding * 2
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.volumePopupPadding
            spacing: 8

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: !root.available
                        ? Theme.volumeUnknownIcon
                        : (root.muted ? Theme.volumeMutedIcon : Theme.volumeIcon)
                    color: Theme.volumeText
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize
                    font.weight: Theme.fontWeight
                    height: valueText.implicitHeight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: valueText
                    text: !root.available
                        ? Theme.volumeUnavailableText
                        : (root.muted ? I18n.t("volume.muted") : (root.level + "%"))
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.controllerFontSizeSmall
                    font.weight: Theme.fontWeight
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                width: parent.width
                height: Theme.volumePopupProgressHeight
                radius: Theme.volumePopupProgressHeight / 2
                color: Theme.volumePopupProgressBg

                Rectangle {
                    width: parent.width * ((!root.available || root.muted) ? 0 : (root.level / 100))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.volumePopupProgressFill
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.volumePopupDuration
        repeat: false
        onTriggered: root.open = false
    }
}
