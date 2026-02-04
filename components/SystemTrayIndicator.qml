import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."

Item {
    id: root
    property var parentWindow: null
    function resolveIconSource(iconValue) {
        if (!iconValue || iconValue.length === 0) {
            return ""
        }
        if (iconValue.indexOf("image://icon/") === 0) {
            return iconValue
        }
        if (iconValue.indexOf("image://") === 0 || iconValue.indexOf("file://") === 0 || iconValue.indexOf("/") === 0) {
            return iconValue
        }
        var resolved = Quickshell.iconPath(iconValue, "")
        if (resolved && resolved.length > 0) {
            return resolved
        }
        var stripped = iconValue.replace(/-symbolic$/, "")
        if (stripped !== iconValue) {
            resolved = Quickshell.iconPath(stripped, "")
            if (resolved && resolved.length > 0) {
                return resolved
            }
        }
        resolved = Quickshell.iconPath("input-keyboard", "")
        if (resolved && resolved.length > 0) {
            return resolved
        }
        return Quickshell.iconPath("keyboard", "")
    }

    function trayCount() {
        if (!SystemTray.items) return 0
        if (SystemTray.items.values !== undefined && SystemTray.items.values.length !== undefined) {
            return SystemTray.items.values.length
        }
        if (SystemTray.items.count !== undefined) return SystemTray.items.count
        if (SystemTray.items.length !== undefined) return SystemTray.items.length
        return 0
    }

    function trayGet(index) {
        if (!SystemTray.items) return null
        if (SystemTray.items.values !== undefined) return SystemTray.items.values[index]
        if (SystemTray.items.get !== undefined) return SystemTray.items.get(index)
        return SystemTray.items[index]
    }

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: Math.max(row.implicitWidth + paddingX * 2, Theme.trayMinWidth)
        radius: Theme.blockRadius
        color: Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Row {
            id: row
            spacing: Theme.trayItemGap
            anchors.centerIn: parent

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    id: traySlot
                    width: Theme.trayIconSize
                    height: Theme.trayIconSize
                    property var trayItem: modelData
                    property bool iconNeedsFallback: trayItem.icon
                        && trayItem.icon.indexOf("image://icon/") === 0
                        && trayItem.icon.indexOf("input-keyboard") !== -1

                    Image {
                        id: trayIcon
                        anchors.centerIn: parent
                        width: Theme.trayIconSize
                        height: Theme.trayIconSize
                        visible: !traySlot.iconNeedsFallback
                        source: root.resolveIconSource(trayItem.icon)
                        sourceSize.width: Theme.trayIconSize
                        sourceSize.height: Theme.trayIconSize
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }

                    Text {
                        id: trayGlyph
                        anchors.centerIn: parent
                        visible: traySlot.iconNeedsFallback
                        text: "󰌌"
                        color: Theme.textPrimary
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fontSize + 3
                        font.weight: Theme.fontWeight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: {
                            if (mouse.button === Qt.LeftButton) {
                                trayItem.activate()
                            } else if (mouse.button === Qt.RightButton && trayItem.hasMenu && root.parentWindow) {
                                var anchorItem = root.parentWindow.contentItem ? root.parentWindow.contentItem : root.parentWindow
                                var pos = traySlot.mapToItem(anchorItem, width / 2, height)
                                trayItem.display(root.parentWindow, pos.x, pos.y)
                            }
                        }
                    }
                }
            }
        }
    }
}
