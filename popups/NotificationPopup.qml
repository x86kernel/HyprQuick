import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import "../components"

PopupWindow {
    id: root
    property var bar
    property var notificationServer
    property var notificationCountFn
    property var resolveNotificationIconFn
    property var iconImageComp
    property var imageComp

    implicitWidth: Theme.popupWidth
    property int maxHeight: bar.screen
        ? Math.max(200, bar.screen.height - (bar.height + Theme.popupOffset + Theme.barMarginTop + Theme.popupBottomMargin))
        : Theme.popupHeight
    implicitHeight: Math.min(
        maxHeight,
        Math.max(
            listColumn.implicitHeight,
            notificationCountFn() === 0 ? Theme.notificationEmptyMinHeight : 0
        ) + Theme.popupPadding * 2
    )
    property bool open: false
    property real anim: open ? 1 : 0
    visible: open || anim > 0.01
    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    color: "transparent"
    anchor.window: bar
    anchor.rect.x: bar.width - width - Theme.barMarginX
    anchor.rect.y: bar.height + Theme.popupOffset

    Rectangle {
        anchors.fill: parent
        radius: Theme.toastCardRadius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.popupBorder
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Flickable {
            id: notificationList
            anchors.fill: parent
            anchors.margins: Theme.popupPadding
            visible: notificationCountFn() > 0
            contentWidth: width
            contentHeight: listColumn.implicitHeight
            clip: true

            Column {
                id: listColumn
                spacing: Theme.toastGap
                width: parent.width

                Repeater {
                    model: notificationServer.trackedNotifications.values !== undefined
                        ? notificationServer.trackedNotifications.values
                        : notificationServer.trackedNotifications

                    delegate: Rectangle {
                        width: parent.width
                        radius: Theme.toastCardRadius
                        color: Theme.blockBg
                        border.width: 1
                        border.color: Theme.blockBorder
                        implicitHeight: contentColumn.implicitHeight + Theme.toastPadding * 2
                        property string displayTitle: {
                            var s = modelData.summary || ""
                            return s.length > Theme.toastTitleMaxChars ? (modelData.appName || s) : s
                        }
                        property string displayBody: {
                            var s = modelData.summary || ""
                            var b = modelData.body || ""
                            if (s.length > Theme.toastTitleMaxChars) {
                                if (b.length > 0)
                                    return s + "\n" + b
                                return s
                            }
                            return b
                        }

                        Column {
                            id: contentColumn
                            anchors.fill: parent
                            anchors.margins: Theme.toastPadding
                            spacing: 6

                            Row {
                                id: listTitleRow
                                spacing: Theme.toastTitleGap
                                width: parent.width
                                height: Math.max(listIconBox.height, listTitleText.implicitHeight)

                                Item {
                                    id: listIconBox
                                    width: Theme.toastIconCircleSize
                                    height: Theme.toastIconCircleSize
                                    property string iconRaw: (modelData && (modelData.image || modelData.appIcon || modelData.appIconName || modelData.icon || modelData.iconName)) || ""
                                    property string iconSource: resolveNotificationIconFn(iconRaw)
                                    property bool useIconImage: iconRaw.indexOf("image://icon/") === 0

                                    DropShadow {
                                        anchors.fill: listIconCircle
                                        source: listIconCircle
                                        radius: Theme.toastIconShadowRadius
                                        samples: Theme.toastIconShadowRadius * 2
                                        color: Theme.toastIconShadow
                                        verticalOffset: Theme.toastIconShadowOffsetY
                                        horizontalOffset: 0
                                        transparentBorder: true
                                    }

                                    Rectangle {
                                        id: listIconCircle
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: Theme.toastIconBg
                                        border.width: 0
                                        border.color: Theme.toastIconBorder
                                    }

                                    Loader {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        active: listIconBox.useIconImage ? listIconBox.iconRaw.length > 0 : listIconBox.iconSource.length > 0
                                        sourceComponent: listIconBox.useIconImage ? iconImageComp : imageComp
                                        property string iconRaw: listIconBox.iconRaw
                                        property string iconSource: listIconBox.iconSource
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.notificationFallbackIcon
                                        color: Theme.accent
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.toastIconSize
                                        font.weight: Theme.fontWeight
                                        visible: listIconBox.useIconImage ? listIconBox.iconRaw.length === 0 : listIconBox.iconSource.length === 0
                                    }
                                }

                                Text {
                                    id: listTitleText
                                    text: displayTitle
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.toastTitleSize
                                    font.weight: Theme.fontWeight
                                    textFormat: Text.PlainText
                                    width: parent.width - listIconBox.width - listTitleRow.spacing
                                    wrapMode: Text.Wrap
                                    height: listTitleRow.height
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Text {
                                text: displayBody
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.toastBodySize
                                textFormat: Text.PlainText
                                width: parent.width
                                wrapMode: Text.Wrap
                            }

                            Item {
                                width: parent.width
                                height: 8
                            }

                            Rectangle {
                                id: notificationConfirmButton
                                width: parent.width
                                height: 28
                                radius: 6
                                color: Theme.accent

                                Text {
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
                                    onClicked: {
                                        bar.markNotificationRead(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.popupPadding
            visible: notificationCountFn() === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                AnimatedImage {
                    Layout.alignment: Qt.AlignHCenter
                    source: Qt.resolvedUrl("../assets/bongocat.gif")
                    fillMode: Image.PreserveAspectFit
                    width: Theme.notificationEmptyGifSize
                    height: Theme.notificationEmptyGifSize
                    playing: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18n.t("notification.empty")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.controllerFontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
