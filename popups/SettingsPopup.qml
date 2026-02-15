import QtQuick
import Quickshell
import "../components"

PanelWindow {
    id: root
    property var bar
    property bool open: false
    property real anim: open ? 1 : 0
    property bool resetConfirmOpen: false
    property bool saveNoticeOpen: false
    property var draftSettings: ({})

    property var zoneDefinitions: ({
        left: [
            { key: "workspace", label: "Workspace" },
            { key: "focusedWindow", label: "Focused Window" },
            { key: "media", label: "Media" }
        ],
        center: [
            { key: "vpn", label: "VPN" },
            { key: "clock", label: "Clock" },
            { key: "screenCapture", label: "Capture/Record" }
        ],
        right: [
            { key: "systemTray", label: "System Tray" },
            { key: "volume", label: "Volume" },
            { key: "clipboard", label: "Clipboard" },
            { key: "cpu", label: "CPU" },
            { key: "memory", label: "Memory" },
            { key: "bluetooth", label: "Bluetooth" },
            { key: "wifi", label: "WiFi" },
            { key: "battery", label: "Battery" },
            { key: "notifications", label: "Notifications" }
        ]
    })

    property var targetScreen: bar ? bar.screen : null

    visible: open || anim > 0.01
    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    color: "transparent"
    screen: targetScreen
    focusable: true
    implicitWidth: Math.max(450, Math.floor((bar ? bar.width : 900) * 0.40))
    width: implicitWidth
    property int contentHeight: Math.min(860, (bar ? Math.max(640, bar.screen.height - 42) : 780))
    implicitHeight: contentHeight
    height: implicitHeight

    anchors.left: true
    anchors.top: true
    margins.left: Math.max(0, Math.round(((targetScreen ? targetScreen.width : width) - width) / 2))
    margins.top: Math.max(0, Math.round(((targetScreen ? targetScreen.height : height) - height) / 2))
    exclusiveZone: 0

    ListModel { id: leftUsedModel }
    ListModel { id: centerUsedModel }
    ListModel { id: rightUsedModel }
    ListModel { id: leftUnusedModel }
    ListModel { id: centerUnusedModel }
    ListModel { id: rightUnusedModel }

    function deepCopy(value) {
        try {
            return JSON.parse(JSON.stringify(value))
        } catch (e) {
            return {}
        }
    }

    function labelFor(zone, key) {
        var defs = zoneDefinitions[zone] || []
        for (var i = 0; i < defs.length; i += 1) {
            if (defs[i].key === key) {
                return defs[i].label
            }
        }
        return key
    }

    function zoneUsedModel(zone) {
        if (zone === "left") return leftUsedModel
        if (zone === "center") return centerUsedModel
        return rightUsedModel
    }

    function zoneUnusedModel(zone) {
        if (zone === "left") return leftUnusedModel
        if (zone === "center") return centerUnusedModel
        return rightUnusedModel
    }

    function modelHasKey(model, key) {
        for (var i = 0; i < model.count; i += 1) {
            if (model.get(i).key === key) {
                return true
            }
        }
        return false
    }

    function refillModel(model, keys) {
        model.clear()
        for (var i = 0; i < keys.length; i += 1) {
            model.append({ key: keys[i] })
        }
    }

    function rebuildUnusedForZone(zone) {
        var defs = zoneDefinitions[zone] || []
        var used = zoneUsedModel(zone)
        var unused = zoneUnusedModel(zone)
        unused.clear()
        for (var i = 0; i < defs.length; i += 1) {
            var key = defs[i].key
            if (!modelHasKey(used, key)) {
                unused.append({ key: key })
            }
        }
    }

    function rebuildAllUnused() {
        rebuildUnusedForZone("left")
        rebuildUnusedForZone("center")
        rebuildUnusedForZone("right")
    }

    function syncZoneModelsFromDraft() {
        var layout = (draftSettings && draftSettings.bar && draftSettings.bar.layout) ? draftSettings.bar.layout : {}
        refillModel(leftUsedModel, layout.left || [])
        refillModel(centerUsedModel, layout.center || [])
        refillModel(rightUsedModel, layout.right || [])
        rebuildAllUnused()
    }

    function syncDraftFromUsedModels() {
        var next = deepCopy(draftSettings)
        if (!next.bar) next.bar = {}
        if (!next.bar.layout) next.bar.layout = {}

        function keys(model) {
            var out = []
            for (var i = 0; i < model.count; i += 1) {
                out.push(model.get(i).key)
            }
            return out
        }

        next.bar.layout.left = keys(leftUsedModel)
        next.bar.layout.center = keys(centerUsedModel)
        next.bar.layout.right = keys(rightUsedModel)
        draftSettings = bar.normalizedSettings(next)
        rebuildAllUnused()
    }

    function toggleZoneBlock(zone, key) {
        var used = zoneUsedModel(zone)
        for (var i = 0; i < used.count; i += 1) {
            if (used.get(i).key === key) {
                used.remove(i)
                syncDraftFromUsedModels()
                return
            }
        }
        used.append({ key: key })
        syncDraftFromUsedModels()
    }

    function moveUsedZoneBlock(zone, from, to) {
        var used = zoneUsedModel(zone)
        if (from < 0 || to < 0 || from >= used.count || to >= used.count || from === to) {
            return
        }
        used.move(from, to, 1)
        syncDraftFromUsedModels()
    }

    function ensureDraft() {
        if (!bar) {
            draftSettings = ({})
            return
        }
        var base = bar.normalizedSettings(bar.appSettings || bar.defaultSettings())
        draftSettings = deepCopy(base)
        syncZoneModelsFromDraft()
    }

    function requestReset() {
        resetConfirmOpen = true
    }

    function confirmReset() {
        ensureDraft()
        resetConfirmOpen = false
    }

    function saveSettings() {
        if (!bar) {
            return
        }
        bar.replaceSettings(draftSettings)
        saveNoticeOpen = true
        saveNoticeTimer.restart()
    }

    onOpenChanged: {
        if (open) {
            ensureDraft()
        } else {
            resetConfirmOpen = false
            saveNoticeOpen = false
        }
    }

    Timer {
        id: saveNoticeTimer
        interval: 1600
        running: false
        repeat: false
        onTriggered: root.saveNoticeOpen = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.popupRadius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.popupBorder
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Text {
            id: titleText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 12
            text: "Block Layout Settings"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.controllerFontSize
            font.weight: Theme.fontWeight
        }

        Row {
            id: actionRow
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 14
            anchors.bottomMargin: 12
            spacing: 8

            Rectangle {
                width: 88
                height: 34
                radius: 8
                color: Theme.accentAlt
                Text {
                    anchors.centerIn: parent
                    text: "Reset"
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Theme.fontWeight
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestReset()
                }
            }

            Rectangle {
                width: 88
                height: 34
                radius: 8
                color: Theme.blockBg
                border.width: 1
                border.color: Theme.blockBorder
                Text {
                    anchors.centerIn: parent
                    text: "Close"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Theme.fontWeight
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open = false
                }
            }

            Rectangle {
                width: 100
                height: 34
                radius: 8
                color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Theme.fontWeight
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveSettings()
                }
            }
        }

        Flickable {
            id: scroll
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleText.bottom
            anchors.bottom: actionRow.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight

            Column {
                id: contentColumn
                width: scroll.width
                spacing: 12

                Repeater {
                    model: ["left", "center", "right"]
                    delegate: Rectangle {
                        property string zone: modelData
                        property var usedModel: root.zoneUsedModel(zone)
                        property var unusedModel: root.zoneUnusedModel(zone)
                        width: contentColumn.width
                        radius: Theme.blockRadius
                        color: Theme.blockBg
                        border.width: 1
                        border.color: Theme.blockBorder
                        implicitHeight: zoneColumn.implicitHeight + 14

                        Column {
                            id: zoneColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 7
                            spacing: 8

                            Text {
                                text: zone.toUpperCase() + " Blocks"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Theme.fontWeight
                            }

                            Text {
                                text: "사용함 (클릭: 사용안함, 드래그: 순서변경)"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                            }

                            ListView {
                                id: usedList
                                width: zoneColumn.width
                                height: rowHeight
                                clip: true
                                interactive: false
                                orientation: ListView.Horizontal
                                spacing: 6
                                model: usedModel
                                property int rowHeight: 32

                                delegate: Rectangle {
                                    id: usedCard
                                    property string blockKey: key
                                    property bool dragging: false
                                    width: Math.max(92, labelText.implicitWidth + 34)
                                    height: usedList.rowHeight
                                    radius: 7
                                    color: dragging ? Theme.accentAlt : Theme.accent
                                    border.width: 1
                                    border.color: dragging ? "#ffffff88" : Theme.blockBorder
                                    scale: dragging ? 1.04 : 1.0
                                    opacity: dragging ? 0.96 : 1.0
                                    z: dragging ? 10 : 1
                                    Behavior on scale { NumberAnimation { duration: 90 } }

                                    Text {
                                        id: labelText
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: root.labelFor(zone, blockKey)
                                        color: Theme.textOnAccent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeight
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        property int dragIndex: -1
                                        property real pressX: 0
                                        property bool didDrag: false

                                        onPressed: function(mouse) {
                                            dragIndex = index
                                            pressX = mouse.x
                                            didDrag = false
                                            usedCard.dragging = false
                                        }

                                        onPositionChanged: function(mouse) {
                                            if (!(mouse.buttons & Qt.LeftButton) || dragIndex < 0) {
                                                return
                                            }
                                            var deltaX = mouse.x - pressX
                                            if (!didDrag && Math.abs(deltaX) > 4) {
                                                didDrag = true
                                                usedCard.dragging = true
                                            }
                                            if (!didDrag) {
                                                return
                                            }

                                            var p = dragArea.mapToItem(usedList.contentItem, mouse.x, mouse.y)
                                            var cursorX = p.x

                                            var prev = usedList.itemAtIndex(dragIndex - 1)
                                            if (prev && cursorX < (prev.x + prev.width / 2)) {
                                                root.moveUsedZoneBlock(zone, dragIndex, dragIndex - 1)
                                                dragIndex -= 1
                                            } else {
                                                var next = usedList.itemAtIndex(dragIndex + 1)
                                                if (next && cursorX > (next.x + next.width / 2)) {
                                                    root.moveUsedZoneBlock(zone, dragIndex, dragIndex + 1)
                                                    dragIndex += 1
                                                }
                                            }
                                        }

                                        onReleased: {
                                            if (!didDrag) {
                                                root.toggleZoneBlock(zone, blockKey)
                                            }
                                            dragIndex = -1
                                            didDrag = false
                                            usedCard.dragging = false
                                        }

                                        onCanceled: {
                                            dragIndex = -1
                                            didDrag = false
                                            usedCard.dragging = false
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "사용안함 (클릭: 사용함으로)"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                            }

                            Flow {
                                width: zoneColumn.width
                                spacing: 6

                                Repeater {
                                    model: unusedModel
                                    delegate: Rectangle {
                                        property string blockKey: key
                                        width: Math.max(88, chipLabel.implicitWidth + 16)
                                        height: 28
                                        radius: 7
                                        color: Theme.accentAlt
                                        border.width: 1
                                        border.color: Theme.blockBorder

                                        Text {
                                            id: chipLabel
                                            anchors.centerIn: parent
                                            text: root.labelFor(zone, blockKey)
                                            color: Theme.textOnAccent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeight
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleZoneBlock(zone, blockKey)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.saveNoticeOpen
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.rightMargin: 12
            radius: 8
            color: Theme.accent
            border.width: 1
            border.color: Theme.blockBorder
            implicitWidth: saveNoticeText.implicitWidth + 18
            implicitHeight: saveNoticeText.implicitHeight + 10

            Text {
                id: saveNoticeText
                anchors.centerIn: parent
                text: "저장되었습니다!"
                color: Theme.textOnAccent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeight
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.resetConfirmOpen
            color: "#00000088"

            MouseArea {
                anchors.fill: parent
                onClicked: root.resetConfirmOpen = false
            }

            Rectangle {
                property int popupPad: 14
                width: 320
                implicitHeight: confirmColumn.implicitHeight + popupPad * 2
                height: implicitHeight
                anchors.centerIn: parent
                radius: Theme.blockRadius
                color: Theme.blockBg
                border.width: 1
                border.color: Theme.blockBorder

                Column {
                    id: confirmColumn
                    anchors.fill: parent
                    anchors.margins: parent.popupPad
                    spacing: 10

                    Text {
                        text: "Reset this panel?"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Theme.fontWeight
                    }

                    Text {
                        text: "Unsaved block layout changes will be discarded."
                        color: Theme.textPrimary
                        opacity: 0.85
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeight
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        Rectangle {
                            width: 84
                            height: 32
                            radius: 8
                            color: Theme.blockBg
                            border.width: 1
                            border.color: Theme.blockBorder
                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.resetConfirmOpen = false
                            }
                        }

                        Rectangle {
                            width: 84
                            height: 32
                            radius: 8
                            color: Theme.accentAlt
                            Text {
                                anchors.centerIn: parent
                                text: "Reset"
                                color: Theme.textOnAccent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirmReset()
                            }
                        }
                    }
                }
            }
        }
    }
}
