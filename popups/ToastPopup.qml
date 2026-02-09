import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "../components"

PanelWindow {
    id: root
    property var bar
    property var toastModel
    property var iconImageComp
    property var imageComp

    implicitWidth: Theme.toastWidth
    implicitHeight: bar && bar.screen ? bar.screen.height : 1080
    visible: toastModel && toastModel.count > 0 && bar && bar.hyprMonitor && bar.hyprMonitor.focused
    color: "transparent"
    screen: bar ? bar.screen : null
    anchors.top: true
    anchors.right: true
    margins.top: Theme.barMarginTop + (bar ? bar.height : 0) + Theme.popupOffset
    margins.right: Theme.barMarginX
    exclusionMode: ExclusionMode.Ignore

    Component.onCompleted: {
        if (root.WlrLayershell) {
            root.WlrLayershell.layer = WlrLayer.Overlay
        }
    }

    Item {
        id: toastStack
        anchors.left: parent.left
        anchors.right: parent.right
        height: implicitHeight
        implicitHeight: {
            var h = -Theme.toastGap
            for (var i = 0; i < toastRepeater.count; i += 1) {
                var item = toastRepeater.itemAt(i)
                if (item && item.layoutVisible)
                    h += item.implicitHeight + Theme.toastGap
            }
            return Math.max(0, h)
        }

        Repeater {
            id: toastRepeater
            model: toastModel

            delegate: Item {
                id: toastItem
                width: Theme.toastWidth
                height: implicitHeight
                implicitHeight: toastContent.implicitHeight
                property int toastId: model.toastId
                property bool appeared: false
                property bool closing: false
                property bool layoutVisible: true
                property string displayTitle: {
                    var s = model.summary || ""
                    return s.length > Theme.toastTitleMaxChars ? (model.appName || s) : s
                }
                property string displayBody: {
                    var s = model.summary || ""
                    var b = model.body || ""
                    if (s.length > Theme.toastTitleMaxChars) {
                        if (b.length > 0)
                            return s + "\n" + b
                        return s
                    }
                    return b
                }
                property real slideOffset: closing
                    ? -(toastItem.width + Theme.toastSlideOffset)
                    : (appeared ? 0 : (toastItem.width + Theme.toastSlideOffset))

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: {
                    var y = 0
                    for (var i = 0; i < index; i += 1) {
                        var item = toastRepeater.itemAt(i)
                        if (item && item.layoutVisible)
                            y += item.implicitHeight + Theme.toastGap
                    }
                    return y
                }

                opacity: appeared ? 1 : 0
                scale: 1
                Component.onCompleted: appeared = true
                onClosingChanged: {
                    if (closing) {
                        lifeTimer.stop()
                        removeTimer.restart()
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.toastAnimDuration
                        easing.type: Easing.InOutSine
                    }
                }

                Timer {
                    id: lifeTimer
                    interval: Theme.toastDuration
                    running: true
                    repeat: false
                    onTriggered: toastItem.closing = true
                }

                Timer {
                    id: removeTimer
                    interval: Theme.toastAnimDuration
                    repeat: false
                    onTriggered: bar.removeToastById(toastItem.toastId)
                }

                Item {
                    id: toastClip
                    anchors.fill: parent
                    clip: true

                    Item {
                        id: toastSlide
                        width: parent.width
                        height: parent.height
                        x: toastItem.slideOffset

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.toastAnimDuration
                                easing.type: Easing.InOutSine
                            }
                        }

                        Rectangle {
                            id: toastContent
                            width: parent.width
                            implicitHeight: toastTextColumn.implicitHeight + Theme.toastPadding * 2
                            radius: Theme.toastCardRadius
                            color: Theme.toastCardBg
                            border.width: 1
                            border.color: Theme.toastCardBorder

                            Column {
                                id: toastTextColumn
                                anchors.fill: parent
                                anchors.margins: Theme.toastPadding
                                spacing: 6

                                Row {
                                    id: toastTitleRow
                                    spacing: Theme.toastTitleGap
                                    width: parent.width
                                    height: Math.max(toastIconBox.height, titleText.implicitHeight)

                                    Item {
                                        id: toastIconBox
                                        width: Theme.toastIconCircleSize
                                        height: Theme.toastIconCircleSize
                                        property string iconRaw: model.iconRaw || ""
                                        property string iconSource: model.iconSource || ""
                                        property bool useIconImage: iconRaw.indexOf("image://icon/") === 0

                                        DropShadow {
                                            anchors.fill: toastIconCircle
                                            source: toastIconCircle
                                            radius: Theme.toastIconShadowRadius
                                            samples: Theme.toastIconShadowRadius * 2
                                            color: Theme.toastIconShadow
                                            verticalOffset: Theme.toastIconShadowOffsetY
                                            horizontalOffset: 0
                                            transparentBorder: true
                                        }

                                        Rectangle {
                                            id: toastIconCircle
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: Theme.toastIconBg
                                            border.width: 0
                                            border.color: Theme.toastIconBorder
                                        }

                                        Loader {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            active: toastIconBox.useIconImage ? toastIconBox.iconRaw.length > 0 : toastIconBox.iconSource.length > 0
                                            sourceComponent: toastIconBox.useIconImage ? iconImageComp : imageComp
                                            property string iconRaw: toastIconBox.iconRaw
                                            property string iconSource: toastIconBox.iconSource
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.notificationFallbackIcon
                                            color: Theme.accent
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.toastIconSize
                                            font.weight: Theme.fontWeight
                                            visible: toastIconBox.useIconImage ? toastIconBox.iconRaw.length === 0 : toastIconBox.iconSource.length === 0
                                        }
                                    }

                                    Text {
                                        id: titleText
                                        text: toastItem.displayTitle
                                        color: Theme.toastTitleText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.toastTitleSize
                                        font.weight: Theme.fontWeight
                                        width: parent.width - toastIconBox.width - toastTitleRow.spacing
                                        wrapMode: Text.Wrap
                                        height: toastTitleRow.height
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: Theme.toastBodyTopMargin
                                }

                                Text {
                                    text: toastItem.displayBody
                                    color: Theme.toastBodyText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.toastBodySize
                                    font.weight: Theme.fontWeight
                                    textFormat: Text.PlainText
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                }

                                Item {
                                    width: parent.width
                                    height: 8
                                }

                                Rectangle {
                                    id: toastConfirmButton
                                    width: parent.width
                                    height: 32
                                    radius: 6
                                    color: Theme.accent

                                    Text {
                                        id: confirmText
                                        anchors.centerIn: parent
                                        text: I18n.t("common.confirm")
                                        color: Theme.textOnAccent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.controllerFontSizeSmall
                                        font.weight: Theme.fontWeight
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: toastItem.closing = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
