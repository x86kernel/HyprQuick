import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components"

PopupWindow {
    id: root
    property var bar
    property var clipboardIndicator
    property var i18nStrings: I18n.activeStrings
    function tr(key, fallbackText) {
        var _unused = root.i18nStrings
        var v = I18n.t(key)
        return v === key ? fallbackText : v
    }

    implicitWidth: Theme.clipboardPopupWidth
    implicitHeight: Math.max(1, clipboardBox.implicitHeight)
    property bool open: false
    property real anim: open ? 1 : 0
    visible: open || anim > 0.01
    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    color: "transparent"
    anchor.window: bar

    Rectangle {
        id: clipboardBox
        anchors.fill: parent
        radius: Theme.clipboardPopupRadius
        color: Theme.clipboardPopupBg
        border.width: 1
        border.color: Theme.clipboardPopupBorder
        implicitHeight: contentColumn.implicitHeight + Theme.clipboardPopupPadding * 2
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.clipboardPopupPadding
            spacing: 8

            Item {
                width: parent.width
                height: Theme.clipboardPopupListHeight
                visible: !clipboardIndicator || clipboardIndicator.items.length === 0

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
                        text: root.tr("clipboard.empty", "No clipboard items")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Flickable {
                id: listView
                width: parent.width
                height: Theme.clipboardPopupListHeight
                contentWidth: width
                contentHeight: listColumn.implicitHeight
                clip: true
                visible: clipboardIndicator && clipboardIndicator.items.length > 0

                Column {
                    id: listColumn
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: clipboardIndicator ? clipboardIndicator.items : []

                        delegate: Rectangle {
                            width: parent.width
                            height: Theme.clipboardPopupItemHeight
                            radius: 6
                            color: Theme.blockBg
                            border.width: 1
                            border.color: Theme.blockBorder

                            Text {
                                anchors.fill: parent
                                anchors.margins: 10
                                text: modelData.label
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                                font.weight: Theme.fontWeight
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (clipboardIndicator) {
                                        clipboardIndicator.copyItem(modelData.itemId)
                                    }
                                    root.open = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    onOpenChanged: {
        if (open) {
            if (bar) {
                bar.updateClipboardPopupAnchor()
            }
            if (clipboardIndicator) {
                clipboardIndicator.refreshItems()
            }
        }
    }
}
