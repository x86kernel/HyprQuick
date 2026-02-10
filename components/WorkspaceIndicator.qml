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
    property int edgePadLeft: 0
    property int edgePadRight: 0
    property var currentKey: null
    property var targetKey: null
    property real uniformWidth: 0

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
        root.updateUniformWidth()
        Qt.callLater(function() { root.applyNextStep() })
    }

    Component.onCompleted: root.requestWorkspaceRefresh()

    Connections {
        target: Hyprland
        function onActiveWorkspaceChanged() { root.requestWorkspaceRefresh() }
    }

    Instantiator {
        id: workspaceModelWatcher
        model: Hyprland.workspaces
        delegate: QtObject {}
        onObjectAdded: function() { root.requestWorkspaceRefresh() }
        onObjectRemoved: function() { root.requestWorkspaceRefresh() }
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


    function startStepTo(pill) {
        if (!pill || !pill.workspace) {
            return
        }
        targetKey = pill.workspace.id
        highlightLabel = pill.workspace.name && pill.workspace.name.length > 0
            ? pill.workspace.name
            : pill.workspace.id
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
                    property real baseWidth: Math.max(30, label.implicitWidth + 16)

                    visible: workspace.active || hasWindows
                    implicitHeight: Theme.blockHeight
                    implicitWidth: root.uniformWidth > 0 ? root.uniformWidth : baseWidth
                    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    radius: Theme.blockRadius
                    color: displayFocused
                        ? "transparent"
                        : Theme.blockBg
                    border.width: displayFocused ? 0 : 1
                    border.color: displayFocused
                        ? Theme.accent
                        : Theme.blockBorder

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
                        color: Theme.textPrimary
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
                color: Theme.accent
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
