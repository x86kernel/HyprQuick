import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "."

Item {
    id: root
    property var monitor: null
    property int stepDurationMs: 80
    property real highlightX: 0
    property real highlightY: 0
    property real highlightW: 0
    property real highlightH: 0
    property bool highlightVisible: false
    property string highlightLabel: ""
    property bool highlightUrgent: false
    property int edgePadLeft: 0
    property int edgePadRight: 0
    property var currentKey: null
    property var targetKey: null
    property var focusedKey: null
    property var previousFocusedKey: null
    property real uniformWidth: 0
    property int urgentRevision: 0
    property int urgentPollIntervalMs: 1200

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    Timer {
        id: stepTimer
        interval: root.stepDurationMs
        repeat: true
        onTriggered: root.applyNextStep()
    }

    function requestWorkspaceRefresh() {
        // Avoid forcing Hyprland refresh on every workspace change.
        // Model updates already come through Hyprland.workspaces signals.
        root.syncFocusedKeys()
        root.updateUniformWidth()
        Qt.callLater(function() { root.applyNextStep() })
    }

    Component.onCompleted: root.requestWorkspaceRefresh()

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.syncFocusedKeys()
            root.requestWorkspaceRefresh()
        }
    }

    Instantiator {
        id: workspaceModelWatcher
        model: Hyprland.workspaces
        delegate: QtObject {}
        onObjectAdded: function() { root.requestWorkspaceRefresh() }
        onObjectRemoved: function() { root.requestWorkspaceRefresh() }
    }

    Instantiator {
        id: toplevelUrgencyWatcher
        model: Hyprland.toplevels
        delegate: Item {
            visible: false
            width: 0
            height: 0
            property var topObj: modelData
            Connections {
                target: topObj
                ignoreUnknownSignals: true
                function onLastIpcObjectChanged() { root.requestUrgentRefresh() }
                function onActivatedChanged() { root.requestUrgentRefresh() }
                function onUrgentChanged() { root.requestUrgentRefresh() }
                function onAttentionChanged() { root.requestUrgentRefresh() }
                function onTitleChanged() { root.requestUrgentRefresh() }
            }
        }
        onObjectAdded: function() { root.requestUrgentRefresh() }
        onObjectRemoved: function() { root.requestUrgentRefresh() }
    }

    Timer {
        id: urgentPoll
        interval: root.urgentPollIntervalMs
        repeat: true
        running: true
        onTriggered: root.requestUrgentRefresh()
    }

    function applyNextStep() {
        if (targetKey === null) {
            stepTimer.stop()
            return
        }
        var list = collectVisiblePills()
        if (list.length === 0) {
            stepTimer.stop()
            return
        }
        var toIndex = indexOfKey(list, targetKey)
        if (toIndex === -1) {
            stepTimer.stop()
            return
        }
        if (currentKey === null) {
            currentKey = targetKey
        }
        var fromIndex = indexOfKey(list, currentKey)
        if (fromIndex === -1) {
            currentKey = targetKey
            fromIndex = toIndex
        }
        var nextIndex = fromIndex
        if (fromIndex < toIndex) {
            nextIndex = fromIndex + 1
        } else if (fromIndex > toIndex) {
            nextIndex = fromIndex - 1
        }
        var t = list[nextIndex]
        highlightX = t.x
        highlightY = t.y
        highlightW = t.w
        highlightH = t.h
        highlightVisible = true
        currentKey = t.key
        if (currentKey === targetKey) {
            stepTimer.stop()
        }
    }

    function collectVisiblePills() {
        var list = []
        for (var i = 0; i < row.children.length; i += 1) {
            var child = row.children[i]
            if (!child || child.objectName !== "workspacePill" || !child.visible) {
                continue
            }
            list.push({
                pill: child,
                x: child.x,
                y: child.y,
                w: child.width,
                h: child.height,
                key: child.workspace ? child.workspace.id : i
            })
        }
        list.sort(function(a, b) { return a.x - b.x })
        return list
    }

    function indexOfKey(list, key) {
        for (var i = 0; i < list.length; i += 1) {
            if (list[i].key === key) {
                return i
            }
        }
        return -1
    }

    function updateEdgePadding() {}

    function requestUrgentRefresh() {
        urgentRevision += 1
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

    function toplevelIsUrgent(toplevel) {
        if (!toplevel || !toplevel.lastIpcObject) {
            return false
        }
        var ipc = toplevel.lastIpcObject
        return !!(
            ipc.urgent
            || ipc.attention
            || ipc.demandsAttention
            || ipc.demands_attention
            || toplevel.urgent
            || toplevel.attention
            || toplevel.demandsAttention
            || toplevel.demands_attention
        )
    }

    function workspaceHasUrgent(workspace, revisionToken) {
        var _unused = revisionToken
        if (!workspace) {
            return false
        }
        var wsId = normalizeWorkspaceId(workspace.id)
        if (wsId === null) {
            return false
        }
        var count = modelCount(Hyprland.toplevels)
        for (var i = 0; i < count; i += 1) {
            var top = modelGet(Hyprland.toplevels, i)
            if (!top || !top.lastIpcObject || !toplevelIsUrgent(top)) {
                continue
            }
            if (workspaceIdEquals(top.lastIpcObject.workspace, wsId)) {
                return true
            }
        }
        return false
    }

    function updateUniformWidth() {
        var maxWidth = 0
        for (var i = 0; i < row.children.length; i += 1) {
            var child = row.children[i]
            if (!child || child.objectName !== "workspacePill" || !child.visible) {
                continue
            }
            if (child.baseWidth > maxWidth) {
                maxWidth = child.baseWidth
            }
        }
        uniformWidth = maxWidth
    }

    function focusedWorkspaceId() {
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id !== undefined) {
            return Hyprland.focusedWorkspace.id
        }
        for (var i = 0; i < row.children.length; i += 1) {
            var child = row.children[i]
            if (!child || child.objectName !== "workspacePill" || !child.workspace) {
                continue
            }
            if (child.workspace.focused) {
                return child.workspace.id
            }
        }
        return null
    }

    function syncFocusedKeys() {
        var next = focusedWorkspaceId()
        if (next === null || next === undefined) {
            return
        }
        if (focusedKey === null || focusedKey === undefined) {
            focusedKey = next
            previousFocusedKey = next
            return
        }
        if (focusedKey !== next) {
            previousFocusedKey = focusedKey
            focusedKey = next
        }
    }

    function canUseAsStepStart(list, key) {
        if (key === null || key === undefined) {
            return false
        }
        return indexOfKey(list, key) !== -1
    }


    function startStepTo(pill) {
        if (!pill || !pill.workspace) {
            return
        }
        targetKey = pill.workspace.id
        highlightLabel = pill.workspace.name && pill.workspace.name.length > 0
            ? pill.workspace.name
            : pill.workspace.id
        highlightUrgent = pill.isUrgent
        var list = collectVisiblePills()
        if (pill.workspace.focused && canUseAsStepStart(list, previousFocusedKey) && previousFocusedKey !== targetKey) {
            currentKey = previousFocusedKey
        }
        if (currentKey === null) {
            var pos = pill.mapToItem(row, 0, 0)
            highlightX = pos.x
            highlightY = pos.y
            highlightW = pill.width
            highlightH = pill.height
            highlightVisible = true
            currentKey = targetKey
            return
        }
        applyNextStep()
        if (currentKey !== targetKey) {
            stepTimer.start()
        }
    }

    Rectangle {
        id: container
        property int paddingLeft: root.edgePadLeft
        property int paddingRight: root.edgePadRight
        property int paddingY: 0

        implicitHeight: Theme.blockHeight
        implicitWidth: row.implicitWidth + paddingLeft + paddingRight
        radius: Theme.blockRadius
        color: Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Row {
            id: row
            spacing: Theme.workspaceGap
            anchors.left: parent.left
            anchors.leftMargin: container.paddingLeft
            anchors.verticalCenter: parent.verticalCenter
            z: 1

            Repeater {
                model: Hyprland.workspaces

                delegate: Rectangle {
                    id: pill
                    objectName: "workspacePill"
                    property var workspace: modelData
                    property bool displayFocused: root.currentKey === workspace.id
                    property bool hasWindows: workspace.lastIpcObject
                        ? workspace.lastIpcObject.windows > 0
                        : false
                    property bool isUrgent: root.workspaceHasUrgent(workspace, root.urgentRevision)
                    property real baseWidth: Math.max(30, label.implicitWidth + 16)

                    visible: workspace.active || hasWindows
                    implicitHeight: Theme.blockHeight
                    implicitWidth: root.uniformWidth > 0 ? root.uniformWidth : baseWidth
                    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    radius: Theme.blockRadius
                    color: displayFocused
                        ? "transparent"
                        : (isUrgent ? Theme.workspaceUrgentBg : Theme.blockBg)
                    border.width: displayFocused ? 0 : 1
                    border.color: displayFocused
                        ? Theme.accent
                        : (isUrgent ? Theme.workspaceUrgentBorder : Theme.blockBorder)

                    function updateHighlight() {
                        if (!workspace.focused) {
                            return
                        }
                        root.startStepTo(pill)
                    }

                    Connections {
                        target: workspace
                        function onFocusedChanged() { pill.updateHighlight() }
                    }

                    onXChanged: updateHighlight()
                    onYChanged: updateHighlight()
                    onWidthChanged: updateHighlight()
                    onHeightChanged: updateHighlight()
                    onVisibleChanged: {
                        updateHighlight()
                        root.updateUniformWidth()
                    }
                    Component.onCompleted: {
                        updateHighlight()
                        root.updateUniformWidth()
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (workspace && !workspace.focused) {
                                workspace.activate()
                            }
                        }
                    }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        z: 3
                        text: workspace.name && workspace.name.length > 0 ? workspace.name : workspace.id
                        color: isUrgent ? Theme.workspaceUrgentText : Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Theme.fontWeight
                        onImplicitWidthChanged: root.updateUniformWidth()
                    }
                }
            }
        }

        Item {
            id: highlightLayer
            width: row.width
            height: row.height
            anchors.centerIn: row
            z: 2

            Rectangle {
                id: movingHighlight
                x: root.highlightX
                y: root.highlightY
                width: root.highlightW
                height: root.highlightH
                radius: Theme.blockRadius
                color: root.highlightUrgent ? Theme.workspaceUrgentBg : Theme.accent
                opacity: root.highlightVisible ? 0.85 : 0
                Behavior on x { NumberAnimation { duration: root.stepDurationMs; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: root.stepDurationMs; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: root.stepDurationMs; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: root.stepDurationMs; easing.type: Easing.OutCubic } }
            }

            Text {
                anchors.centerIn: movingHighlight
                text: root.highlightLabel
                color: Theme.textOnAccent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
            }
        }
    }
}
