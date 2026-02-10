import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "."

Item {
    id: root
    property var monitor: null
    property var activeWorkspace: Hyprland.focusedWorkspace
    property bool desktopActive: false
    property var toplevel: null
    property var mappedEntry: null
    property bool syncPending: false
    property var workspaceItems: []
    property var monitorItems: []

    Instantiator {
        id: workspacesInst
        model: Hyprland.workspaces
        delegate: QtObject { property var ws: modelData }
        onObjectAdded: function(index, object) {
            workspaceItems.splice(index, 0, object.ws)
            root.requestStateRefresh()
        }
        onObjectRemoved: function(index) {
            workspaceItems.splice(index, 1)
            root.requestStateRefresh()
        }
    }

    Instantiator {
        id: monitorsInst
        model: Hyprland.monitors
        delegate: QtObject { property var mon: modelData }
        onObjectAdded: function(index, object) {
            monitorItems.splice(index, 0, object.mon)
            root.requestStateRefresh()
        }
        onObjectRemoved: function(index) {
            monitorItems.splice(index, 1)
            root.requestStateRefresh()
        }
    }

    Instantiator {
        id: toplevelsInst
        model: Hyprland.toplevels
        delegate: Item {
            visible: false
            width: 0
            height: 0
            property var topObj: modelData
            Connections {
                target: topObj
                ignoreUnknownSignals: true
                function onLastIpcObjectChanged() { root.requestStateRefresh() }
                function onTitleChanged() { root.requestStateRefresh() }
            }
        }
        onObjectAdded: function() { root.requestStateRefresh() }
        onObjectRemoved: function() { root.requestStateRefresh() }
    }

    function requestStateRefresh() {
        root.toplevel = root.resolvePreferredToplevel()
        root.desktopActive = !root.toplevel || !root.toplevel.lastIpcObject
        root.updateMappedEntry()
        if (root.desktopActive) {
            root.requestSyncRefresh()
        }
    }

    function requestSyncRefresh() {
        if (root.syncPending) {
            return
        }
        root.syncPending = true
        syncRefreshDebounce.restart()
    }

    Component.onCompleted: root.requestStateRefresh()

    function workspaceIdFrom(value) {
        if (value === null || value === undefined) {
            return null
        }
        return value.id !== undefined ? value.id : value
    }

    function normalizeWorkspaceId(value) {
        var wsId = workspaceIdFrom(value)
        if (wsId === null || wsId === undefined) {
            return null
        }
        var n = Number(wsId)
        if (!isNaN(n)) {
            return n
        }
        return String(wsId)
    }

    function workspaceIdEquals(a, b) {
        var na = normalizeWorkspaceId(a)
        var nb = normalizeWorkspaceId(b)
        return na !== null && nb !== null && na === nb
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

    function resolvePreferredToplevel() {
        var activeId = normalizeWorkspaceId(currentActiveWorkspaceId())
        if (activeId === null) {
            return null
        }
        var count = modelCount(Hyprland.toplevels)
        for (var i = 0; i < count; i += 1) {
            var top = modelGet(Hyprland.toplevels, i)
            if (!top || !top.lastIpcObject) {
                continue
            }
            var wsId = normalizeWorkspaceId(top.lastIpcObject.workspace)
            if (workspaceIdEquals(wsId, activeId)) {
                return top
            }
        }
        return null
    }

    Connections {
        target: root
        function onActiveWorkspaceChanged() { root.requestStateRefresh() }
        function onToplevelChanged() { root.requestStateRefresh() }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.requestStateRefresh()
        }
        function onActiveToplevelChanged() { root.requestStateRefresh() }
    }

    Timer {
        id: syncRefreshDebounce
        interval: 180
        repeat: false
        onTriggered: {
            root.syncPending = false
            if (Hyprland.refreshToplevels) {
                Hyprland.refreshToplevels()
            }
            if (Hyprland.refreshWorkspaces) {
                Hyprland.refreshWorkspaces()
            }
            root.toplevel = root.resolvePreferredToplevel()
            root.desktopActive = !root.toplevel || !root.toplevel.lastIpcObject
            root.updateMappedEntry()
        }
    }

    Connections {
        target: root.toplevel
        ignoreUnknownSignals: true
        function onLastIpcObjectChanged() { root.updateMappedEntry() }
        function onTitleChanged() { root.updateMappedEntry() }
    }

    Connections {
        target: Theme
        function onWindowIconMappingsChanged() { root.updateMappedEntry() }
    }

    function currentActiveWorkspaceId() {
        if (root.monitor && root.monitor.activeWorkspace) {
            var monitorWsId = normalizeWorkspaceId(root.monitor.activeWorkspace)
            if (monitorWsId !== null) {
                return monitorWsId
            }
        }
        var monCount = modelCount(Hyprland.monitors)
        for (var m = 0; m < monCount; m += 1) {
            var mon = modelGet(Hyprland.monitors, m)
            if (mon && mon.focused && mon.activeWorkspace) {
                var monId = normalizeWorkspaceId(mon.activeWorkspace)
                if (monId !== null) {
                    return monId
                }
            }
        }
        var wsCount = modelCount(Hyprland.workspaces)
        for (var w = 0; w < wsCount; w += 1) {
            var focusedWs = modelGet(Hyprland.workspaces, w)
            if (focusedWs && focusedWs.focused) {
                var focusedId = normalizeWorkspaceId(focusedWs.id)
                if (focusedId !== null) {
                    return focusedId
                }
            }
        }
        return null
    }

    Timer {
        id: desktopProbe
        interval: 200
        running: root.desktopActive
        repeat: true
        onTriggered: root.requestStateRefresh()
    }

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function isDesktopState(toplevel) {
        return !toplevel || !toplevel.lastIpcObject
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

    function computeMapping(toplevel) {
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

    function updateMappedEntry() {
        root.mappedEntry = computeMapping(root.toplevel)
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
                visible: root.mappedEntry === null
                source: Quickshell.iconPath(iconNameFor(root.toplevel), "application-x-executable")
            }

            Text {
                id: iconGlyph
                visible: root.mappedEntry !== null
                text: root.mappedEntry ? root.mappedEntry.icon : ""
                color: Theme.textPrimary
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
            }

            Text {
                id: titleLabel
                text: root.mappedEntry && root.mappedEntry.name
                    ? root.mappedEntry.name
                    : appNameFor(root.toplevel)
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
