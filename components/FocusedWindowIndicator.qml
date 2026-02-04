import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."

Item {
    id: root
    property var activeWorkspace: Hyprland.activeWorkspace
    property bool desktopActive: false
    property bool desktopAssume: false
    property var toplevel: desktopActive ? null : Hyprland.activeToplevel
    property var workspaceItems: []
    property var monitorItems: []

    Instantiator {
        id: workspacesInst
        model: Hyprland.workspaces
        delegate: QtObject { property var ws: modelData }
        onObjectAdded: workspaceItems.splice(index, 0, object.ws)
        onObjectRemoved: workspaceItems.splice(index, 1)
    }

    Instantiator {
        id: monitorsInst
        model: Hyprland.monitors
        delegate: QtObject { property var mon: modelData }
        onObjectAdded: monitorItems.splice(index, 0, object.mon)
        onObjectRemoved: monitorItems.splice(index, 1)
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
            root.desktopActive = root.computeDesktopActive()
        }
    }


    Timer {
        id: workspaceRefresh
        interval: 100
        repeat: false
        onTriggered: {
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
            root.desktopActive = root.computeDesktopActive()
        }
    }

    Connections {
        target: Hyprland
        function onActiveWorkspaceChanged() {
            desktopAssume = true
            workspaceRefresh.start()
        }
        function onActiveToplevelChanged() {
            if (!root.activeWorkspace || !Hyprland.activeToplevel || !Hyprland.activeToplevel.lastIpcObject) {
                return
            }
            if (Hyprland.activeToplevel.lastIpcObject.workspace === root.activeWorkspace.id) {
                desktopAssume = false
            }
        }
    }

    function currentActiveWorkspaceId() {
        for (var m = 0; m < root.monitorItems.length; m += 1) {
            var mon = root.monitorItems[m]
            if (mon && mon.focused && mon.activeWorkspace) {
                return mon.activeWorkspace.id
            }
        }
        var fallbackId = null
        for (var i = 0; i < root.workspaceItems.length; i += 1) {
            var ws = root.workspaceItems[i]
            if (!ws) {
                continue
            }
            if (ws.focused) {
                return ws.id
            }
            if (fallbackId === null && ws.active) {
                fallbackId = ws.id
            }
        }
        return fallbackId
    }

    function computeDesktopActive() {
        var activeId = currentActiveWorkspaceId()
        if (activeId === null) {
            return true
        }
        for (var i = 0; i < root.workspaceItems.length; i += 1) {
            var ws = root.workspaceItems[i]
            if (ws && ws.id === activeId && ws.lastIpcObject) {
                return ws.lastIpcObject.windows === 0
            }
        }
        return false
    }

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function isDesktopState(toplevel) {
        if (root.desktopActive || root.desktopAssume) {
            return true
        }
        if (!toplevel || !toplevel.lastIpcObject) {
            return true
        }
        var activeId = currentActiveWorkspaceId()
        if (activeId !== null && toplevel.lastIpcObject.workspace !== undefined) {
            return toplevel.lastIpcObject.workspace.id
                ? toplevel.lastIpcObject.workspace.id !== activeId
                : toplevel.lastIpcObject.workspace !== activeId
        }
        return false
    }

    function iconNameFor(toplevel) {
        if (isDesktopState(toplevel)) {
            return "user-desktop"
        }
        return toplevel.lastIpcObject.class
            || toplevel.lastIpcObject.initialClass
            || toplevel.lastIpcObject.app
            || "application-x-executable"
    }

    function appNameFor(toplevel) {
        if (isDesktopState(toplevel)) {
            return "Desktop"
        }
        return toplevel.lastIpcObject.class
            || toplevel.lastIpcObject.initialClass
            || toplevel.lastIpcObject.app
            || "Desktop"
    }

    function resolveMapping(toplevel) {
        if (isDesktopState(toplevel)) {
            return { icon: "󰇄", name: "Desktop" }
        }
        if (!Theme.windowIconMappings) {
            return null
        }
        var cls = toplevel.lastIpcObject.class || ""
        var title = toplevel.title || ""
        var app = toplevel.lastIpcObject.app || ""
        for (var i = 0; i < Theme.windowIconMappings.length; i += 1) {
            var item = Theme.windowIconMappings[i]
            var source = ""
            if (item.match === "title") {
                source = title
            } else if (item.match === "app") {
                source = app
            } else {
                source = cls
            }
            try {
                var re = new RegExp(item.pattern)
                if (re.test(source)) {
                    return item
                }
            } catch (e) {
                if (source === item.pattern) {
                    return item
                }
            }
        }
        return null
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

            IconImage {
                id: windowIcon
                width: Theme.trayIconSize
                height: Theme.trayIconSize
                visible: !iconGlyph.visible
                source: Quickshell.iconPath(iconNameFor(root.toplevel), "application-x-executable")
            }

            Text {
                id: iconGlyph
                visible: resolveMapping(root.toplevel) !== null
                text: {
                    var m = resolveMapping(root.toplevel)
                    return m ? m.icon : ""
                }
                color: Theme.textPrimary
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
            }

            Text {
                id: titleLabel
                text: {
                    var m = resolveMapping(root.toplevel)
                    return m && m.name ? m.name : appNameFor(root.toplevel)
                }
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
                elide: Text.ElideRight
                maximumLineCount: 1
            }

        }
    }
}
