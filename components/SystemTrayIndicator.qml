import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "."

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

    function normalizeToken(value) {
        if (!value) {
            return ""
        }
        return String(value).toLowerCase().replace(/[^a-z0-9]+/g, "")
    }

    function pushToken(tokens, value) {
        var n = normalizeToken(value)
        if (n.length < 3) {
            return
        }
        if (tokens.indexOf(n) === -1) {
            tokens.push(n)
        }
    }

    function modelCount(model) {
        if (!model) return 0
        if (model.values !== undefined && model.values.length !== undefined) return model.values.length
        if (model.count !== undefined) return model.count
        if (model.length !== undefined) return model.length
        return 0
    }

    function modelGet(model, index) {
        if (!model) return null
        if (model.values !== undefined) return model.values[index]
        if (model.get !== undefined) return model.get(index)
        return model[index]
    }

    function collectTrayTokens(trayItem) {
        var out = []
        if (!trayItem) {
            return out
        }
        pushToken(out, trayItem.title)
        pushToken(out, trayItem.tooltipTitle)
        pushToken(out, trayItem.tooltip)
        pushToken(out, trayItem.id)
        pushToken(out, trayItem.status)
        var iconName = trayItem.icon || ""
        if (iconName.indexOf("image://icon/") === 0) {
            iconName = iconName.slice("image://icon/".length)
        }
        iconName = iconName.replace(/-symbolic$/i, "")
        pushToken(out, iconName)
        return out
    }

    function collectToplevelTokens(toplevel) {
        var out = []
        if (!toplevel || !toplevel.lastIpcObject) {
            return out
        }
        var ipc = toplevel.lastIpcObject
        pushToken(out, ipc.class)
        pushToken(out, ipc.initialClass)
        pushToken(out, ipc.app)
        pushToken(out, toplevel.title)
        return out
    }

    function tokenScore(trayTokens, toplevelTokens) {
        var score = 0
        for (var i = 0; i < trayTokens.length; i += 1) {
            var trayToken = trayTokens[i]
            for (var j = 0; j < toplevelTokens.length; j += 1) {
                var topToken = toplevelTokens[j]
                if (trayToken === topToken) {
                    score += 4
                } else if (trayToken.length >= 4 && topToken.indexOf(trayToken) !== -1) {
                    score += 2
                } else if (topToken.length >= 4 && trayToken.indexOf(topToken) !== -1) {
                    score += 1
                }
            }
        }
        return score
    }

    function findWorkspaceById(workspaceId) {
        var count = modelCount(Hyprland.workspaces)
        for (var i = 0; i < count; i += 1) {
            var ws = modelGet(Hyprland.workspaces, i)
            if (ws && ws.id === workspaceId) {
                return ws
            }
        }
        return null
    }

    function focusWorkspaceForTrayItem(trayItem) {
        if (Hyprland.refreshToplevels) {
            Hyprland.refreshToplevels()
        }
        var trayTokens = collectTrayTokens(trayItem)
        if (trayTokens.length === 0) {
            return false
        }

        var topCount = modelCount(Hyprland.toplevels)
        var bestScore = 0
        var bestWorkspaceId = null

        for (var i = 0; i < topCount; i += 1) {
            var top = modelGet(Hyprland.toplevels, i)
            if (!top || !top.lastIpcObject) {
                continue
            }
            var score = tokenScore(trayTokens, collectToplevelTokens(top))
            if (score <= bestScore) {
                continue
            }
            var ipc = top.lastIpcObject
            var wsValue = ipc.workspace
            var wsId = wsValue && wsValue.id !== undefined ? wsValue.id : wsValue
            if (wsId === undefined || wsId === null) {
                continue
            }
            bestScore = score
            bestWorkspaceId = wsId
        }

        if (bestWorkspaceId === null) {
            return false
        }

        var ws = findWorkspaceById(bestWorkspaceId)
        if (ws && ws.activate) {
            ws.activate()
            return true
        }
        return false
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
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                if (!root.focusWorkspaceForTrayItem(trayItem) && trayItem && trayItem.activate) {
                                    trayItem.activate()
                                }
                            } else if (mouse.button === Qt.RightButton && trayItem.hasMenu && root.parentWindow) {
                                var anchorItem = root.parentWindow.contentItem ? root.parentWindow.contentItem : root.parentWindow
                                var pos = traySlot.mapToItem(anchorItem, width / 2, height)
                                trayItem.display(root.parentWindow, pos.x, pos.y)
                            }
                        }
                        onDoubleClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                if (!root.focusWorkspaceForTrayItem(trayItem) && trayItem && trayItem.activate) {
                                    trayItem.activate()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
