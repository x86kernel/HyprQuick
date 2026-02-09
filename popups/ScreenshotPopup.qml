import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    property var bar
    property var screenshotSaveProc
    property var screenshotCopyProc

    implicitWidth: Theme.screenshotPopupWidth
    implicitHeight: Theme.screenshotPopupHeight
    property bool open: false
    property real anim: open ? 1 : 0
    property string tempPath: ""
    property string errorText: ""
    visible: open || anim > 0.01
    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    color: "transparent"
    anchor.window: bar
    anchor.rect.x: (bar.width - width) / 2
    anchor.rect.y: bar.height + Theme.popupOffset

    Rectangle {
        anchors.fill: parent
        radius: Theme.screenshotPopupRadius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.popupBorder
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Column {
            anchors.fill: parent
            anchors.margins: Theme.screenshotPopupPadding
            spacing: Theme.screenshotPopupGap

            Text {
                id: screenshotTitleLabel
                text: Theme.screenshotTitle
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSize
                font.weight: Theme.fontWeight
            }

            Rectangle {
                width: parent.width
                height: Math.max(
                    90,
                    parent.height - screenshotTitleLabel.implicitHeight - actionsRow.height - (Theme.screenshotPopupGap * 2)
                )
                radius: Theme.blockRadius
                color: Theme.blockBg
                border.width: 1
                border.color: Theme.blockBorder
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    source: root.tempPath.length > 0 ? ("file://" + root.tempPath) : ""
                    visible: root.tempPath.length > 0
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    visible: root.tempPath.length === 0 && root.errorText.length > 0
                    text: root.errorText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.controllerFontSizeSmall
                }
            }

            Row {
                id: actionsRow
                width: parent.width
                spacing: Theme.screenshotPopupGap

                Rectangle {
                    width: (parent.width - Theme.screenshotPopupGap * 2) / 3
                    height: Theme.screenshotActionButtonHeight
                    radius: Theme.wifiConnectRadius
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: Theme.screenshotSaveText
                        color: Theme.textOnAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSizeSmall
                        font.weight: Theme.fontWeight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.tempPath.length === 0) {
                                bar.closeScreenshotPreview(false)
                                return
                            }
                            screenshotSaveProc.commandText = bar.commandWithFile(
                                Theme.screenshotSaveCommandTemplate + "; " + Theme.screenshotDiscardCommandTemplate,
                                root.tempPath
                            )
                            screenshotSaveProc.running = true
                            bar.closeScreenshotPreview(false)
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.screenshotPopupGap * 2) / 3
                    height: Theme.screenshotActionButtonHeight
                    radius: Theme.wifiConnectRadius
                    color: Theme.blockBg
                    border.width: 1
                    border.color: Theme.blockBorder

                    Text {
                        anchors.centerIn: parent
                        text: Theme.screenshotCopyText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSizeSmall
                        font.weight: Theme.fontWeight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.tempPath.length === 0) {
                                bar.closeScreenshotPreview(false)
                                return
                            }
                            screenshotCopyProc.commandText = bar.commandWithFile(
                                Theme.screenshotCopyCommandTemplate + "; " + Theme.screenshotDiscardCommandTemplate,
                                root.tempPath
                            )
                            screenshotCopyProc.running = true
                            bar.closeScreenshotPreview(false)
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.screenshotPopupGap * 2) / 3
                    height: Theme.screenshotActionButtonHeight
                    radius: Theme.wifiConnectRadius
                    color: Theme.blockBg
                    border.width: 1
                    border.color: Theme.blockBorder

                    Text {
                        anchors.centerIn: parent
                        text: Theme.screenshotCloseText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSizeSmall
                        font.weight: Theme.fontWeight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.closeScreenshotPreview(true)
                    }
                }
            }
        }
    }
}
