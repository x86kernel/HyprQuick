//@ pragma UseQApplication
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "components"

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            property var modelData
            screen: modelData
            property var hyprMonitor: Hyprland.monitorFor(screen)

            anchors.top: true
            anchors.left: true
            anchors.right: true
            margins.top: Theme.barMarginTop
            margins.left: Theme.barMarginX
            margins.right: Theme.barMarginX
            implicitHeight: Theme.blockHeight + 6
            exclusiveZone: implicitHeight + Theme.barReserveBottom
            color: "transparent"

            NotificationServer {
                id: notificationServer
                keepOnReload: true
                onNotification: function(notification) {
                    if (!bar.hyprMonitor || !bar.hyprMonitor.focused) {
                        return
                    }
                    notification.tracked = true
                    appendToast(notification)
                }
            }

            function notificationCount() {
                if (!notificationServer.trackedNotifications) {
                    return 0
                }
                if (notificationServer.trackedNotifications.values !== undefined) {
                    return notificationServer.trackedNotifications.values.length
                }
                if (notificationServer.trackedNotifications.count !== undefined) {
                    return notificationServer.trackedNotifications.count
                }
                if (notificationServer.trackedNotifications.length !== undefined) {
                    return notificationServer.trackedNotifications.length
                }
                return 0
            }

            property int maxToasts: 10
            property int toastCounter: 0

            ListModel {
                id: toastModel
            }

            function appendToast(notification) {
                toastCounter += 1
                toastModel.append({
                    toastId: toastCounter,
                    summary: notification.summary || "",
                    body: notification.body || "",
                    appName: notification.appName || ""
                })
                while (toastModel.count > maxToasts) {
                    toastModel.remove(0)
                }
            }

            function removeToastById(toastId) {
                for (var i = 0; i < toastModel.count; i += 1) {
                    if (toastModel.get(i).toastId === toastId) {
                        toastModel.remove(i)
                        return
                    }
                }
            }

            function updateCpuTooltipAnchor() {
                if (!cpuUsageIndicator) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = cpuUsageIndicator.mapToItem(anchorItem, 0, cpuUsageIndicator.height)
                cpuTooltipPopup.anchor.rect.x = pos.x + cpuUsageIndicator.width - Theme.cpuTooltipWidth
                cpuTooltipPopup.anchor.rect.y = pos.y + Theme.cpuTooltipOffset
                cpuTooltipPopup.anchor.rect.width = 1
                cpuTooltipPopup.anchor.rect.height = 1
            }

            function updateBluetoothPopupAnchor() {
                if (!bluetoothIndicator) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = bluetoothIndicator.mapToItem(anchorItem, 0, bluetoothIndicator.height)
                bluetoothPopup.anchor.rect.x = pos.x + bluetoothIndicator.width - Theme.bluetoothPopupWidth
                bluetoothPopup.anchor.rect.y = pos.y + Theme.bluetoothPopupOffset
                bluetoothPopup.anchor.rect.width = 1
                bluetoothPopup.anchor.rect.height = 1
            }

            function closeControllers() {
                bluetoothPopup.open = false
                notificationPopup.open = false
            }

            function toggleBluetoothController() {
                if (bluetoothPopup.open) {
                    bluetoothPopup.open = false
                    return
                }
                notificationPopup.open = false
                bluetoothPopup.open = true
            }

            function toggleNotificationCenter() {
                if (notificationPopup.open) {
                    notificationPopup.open = false
                    return
                }
                bluetoothPopup.open = false
                notificationPopup.open = true
            }

            RowLayout {
                id: barLayout
                anchors.fill: parent
                anchors.leftMargin: Theme.barMarginX
                anchors.rightMargin: Theme.barMarginX
                spacing: Theme.blockGap

                Item {
                    id: leftArea
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    implicitHeight: leftRow.implicitHeight
                    implicitWidth: leftRow.implicitWidth

                    Row {
                        id: leftRow
                        spacing: Theme.blockGap
                        anchors.verticalCenter: parent.verticalCenter

                        WorkspaceIndicator {
                            id: workspaceIndicator
                            monitor: bar.hyprMonitor
                        }

                        FocusedWindowIndicator {
                            id: focusedWindowIndicator
                        }

                        MediaIndicator {
                            id: mediaIndicator
                        }
                    }
                }

                Item {
                    id: centerArea
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    id: rightArea
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                    Row {
                        id: rightRow
                        spacing: Theme.blockGap
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right

                        SystemTrayIndicator {
                            id: systemTrayIndicator
                            parentWindow: bar
                        }

                        ClipboardIndicator {
                            id: clipboardIndicator
                        }

                        CPUUsageIndicator {
                            id: cpuUsageIndicator
                            parentWindow: bar
                        }

                        MemoryUsageIndicator {
                            id: memoryUsageIndicator
                        }

                        BluetoothIndicator {
                            id: bluetoothIndicator
                            onClicked: bar.toggleBluetoothController()
                        }

                        NotificationTrigger {
                            id: notificationTrigger
                            count: notificationCount()
                            onClicked: bar.toggleNotificationCenter()
                        }
                    }
                }
            }

            DateTimeIndicator {
                id: dateTimeIndicator
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            PanelWindow {
                id: toastPopup
                width: Theme.toastWidth
                height: Math.max(1, toastStack.implicitHeight)
                visible: toastModel.count > 0 && bar.hyprMonitor && bar.hyprMonitor.focused
                color: "transparent"
                screen: bar.screen
                anchors.top: true
                anchors.right: true
                margins.top: Theme.barMarginTop + bar.height + Theme.popupOffset
                margins.right: Theme.barMarginX
                exclusionMode: ExclusionMode.Ignore

                Component.onCompleted: {
                    if (toastPopup.WlrLayershell) {
                        toastPopup.WlrLayershell.layer = WlrLayer.Overlay
                    }
                }

                // No height animation to avoid compressing stacked toasts on removal.

                Item {
                    id: toastStack
                    anchors.left: parent.left
                    anchors.right: parent.right
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
                            implicitHeight: toastContent.implicitHeight
                            property int toastId: model.toastId
                            property bool appeared: false
                            property bool closing: false
                            property bool layoutVisible: true
                            property string displayTitle: {
                                var s = model.summary || ""
                                if (s.length > Theme.toastTitleMaxChars) {
                                    var app = model.appName || ""
                                    return app.length > 0 ? app : s
                                }
                                return s
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
                                ? -(Theme.toastWidth + Theme.toastSlideOffset)
                                : (appeared ? 0 : (Theme.toastWidth + Theme.toastSlideOffset))

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

                            opacity: appeared && !closing ? 1 : 0
                            scale: 1
                            Component.onCompleted: appeared = true
                            onClosingChanged: {
                                if (closing)
                                    removeTimer.restart()
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.toastAnimDuration
                                    easing.type: Easing.InOutSine
                                }
                            }

                            // No bottomMargin animation to avoid flicker during reflow.

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
                                        radius: Theme.blockRadius
                                        color: Theme.blockBg
                                        border.width: 1
                                        border.color: Theme.blockBorder

                                        Column {
                                            id: toastTextColumn
                                            anchors.fill: parent
                                            anchors.margins: Theme.toastPadding
                                            spacing: 6

                                            Text {
                                                text: toastItem.displayTitle
                                                color: Theme.accent
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.toastTitleSize
                                                font.weight: Theme.fontWeight
                                                width: parent.width
                                                wrapMode: Text.Wrap
                                            }

                                            Text {
                                                text: toastItem.displayBody
                                                color: Theme.textPrimary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.toastBodySize
                                                font.weight: Theme.fontWeight
                                                width: parent.width
                                                wrapMode: Text.WrapAnywhere
                                            }

                                            Item {
                                                width: parent.width
                                                height: 8
                                            }

                                            Rectangle {
                                                id: toastConfirmButton
                                                width: parent.width
                                                height: 28
                                                radius: 6
                                                color: Theme.accent

                                                Text {
                                                    id: confirmText
                                                    anchors.centerIn: parent
                                                    text: "확인"
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

            PopupWindow {
                id: cpuTooltipPopup
                width: Theme.cpuTooltipWidth
                height: Math.max(1, cpuTooltipText.implicitHeight)
                visible: cpuUsageIndicator && cpuUsageIndicator.hovered
                color: "transparent"
                anchor.window: bar

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cpuTooltipRadius
                    color: Theme.cpuTooltipBg
                    border.width: 1
                    border.color: Theme.cpuTooltipBorder

                    Text {
                        id: cpuTooltipText
                        anchors.fill: parent
                        anchors.margins: Theme.cpuTooltipPadding
                        text: cpuUsageIndicator && cpuUsageIndicator.tooltipText.length > 0
                            ? cpuUsageIndicator.tooltipText
                            : "CPU " + Math.round(cpuUsageIndicator ? cpuUsageIndicator.usage : 0) + "%\nTemp: n/a"
                        color: Theme.cpuTooltipText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSizeSmall
                        font.weight: Theme.fontWeight
                        wrapMode: Text.Wrap
                    }
                }

                onVisibleChanged: {
                    if (visible) {
                        bar.updateCpuTooltipAnchor()
                    }
                }
            }

            Connections {
                target: cpuUsageIndicator
                function onHoveredChanged() { bar.updateCpuTooltipAnchor() }
                function onWidthChanged() { bar.updateCpuTooltipAnchor() }
                function onHeightChanged() { bar.updateCpuTooltipAnchor() }
            }

            PopupWindow {
                id: bluetoothPopup
                width: Theme.bluetoothPopupWidth
                implicitHeight: Math.max(1, bluetoothBox.implicitHeight)
                property bool open: false
                property real anim: open ? 1 : 0
                visible: open || anim > 0.01
                Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
                color: "transparent"
                anchor.window: bar

                Rectangle {
                    id: bluetoothBox
                    anchors.fill: parent
                    radius: Theme.bluetoothPopupRadius
                    color: Theme.bluetoothPopupBg
                    border.width: 1
                    border.color: Theme.bluetoothPopupBorder
                    implicitHeight: bluetoothContent.implicitHeight + Theme.bluetoothPopupPadding * 2
                    opacity: bluetoothPopup.anim
                    scale: 0.98 + 0.02 * bluetoothPopup.anim

                    Column {
                        id: bluetoothContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.bluetoothPopupPadding
                        spacing: 8

                        Text {
                            text: "Bluetooth"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSize
                            font.weight: Theme.fontWeight
                        }

                        Text {
                            text: bluetoothIndicator
                                ? (bluetoothIndicator.powered ? "Powered On" : "Powered Off")
                                : "Powered Off"
                            color: Theme.bluetoothActiveText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            width: parent.width
                            height: 28
                            radius: 6
                            color: Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: bluetoothIndicator && bluetoothIndicator.powered ? "Turn Off" : "Turn On"
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
                                    if (bluetoothIndicator) {
                                        bluetoothIndicator.setPower(!bluetoothIndicator.powered)
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Devices"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Column {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: bluetoothIndicator ? bluetoothIndicator.deviceItems : []

                                delegate: Rectangle {
                                    width: parent.width
                                    height: 38
                                    radius: 6
                                    color: modelData.connected ? Theme.bluetoothActiveText : Theme.blockBg
                                    border.width: 1
                                    border.color: Theme.blockBorder

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Text {
                                            text: modelData.name
                                            color: modelData.connected ? Theme.textOnAccent : Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            font.weight: Theme.fontWeight
                                            width: parent.width - 72
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            height: parent.height
                                        }

                                        Item {
                                            width: 64
                                            height: parent.height

                                            Row {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6

                                                Rectangle {
                                                    id: pairButton
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: Theme.blockBg
                                                    opacity: pairArea.pressed ? 0.9 : 1
                                                    scale: pairArea.pressed ? 0.92 : 1
                                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: Theme.bluetoothPairIcon
                                                        color: Theme.bluetoothActiveText
                                                        font.family: Theme.iconFontFamily
                                                        font.pixelSize: Theme.iconSize
                                                    }

                                                    MouseArea {
                                                        id: pairArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (bluetoothIndicator) {
                                                                bluetoothIndicator.pairDevice(modelData.mac)
                                                            }
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    id: connectButton
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: Theme.blockBg
                                                    opacity: connectArea.pressed ? 0.9 : 1
                                                    scale: connectArea.pressed ? 0.92 : 1
                                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.connected ? Theme.bluetoothDisconnectIcon : Theme.bluetoothConnectIcon
                                                        color: Theme.bluetoothActiveText
                                                        font.family: Theme.iconFontFamily
                                                        font.pixelSize: Theme.iconSize
                                                    }

                                                    MouseArea {
                                                        id: connectArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (!bluetoothIndicator)
                                                                return
                                                            if (modelData.connected) {
                                                                bluetoothIndicator.disconnectDevice(modelData.mac)
                                                            } else {
                                                                bluetoothIndicator.connectDevice(modelData.mac)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: !bluetoothIndicator || bluetoothIndicator.deviceItems.length === 0
                                text: "No devices"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                            }
                        }
                    }

                }

                onVisibleChanged: {
                    if (visible) {
                        bar.updateBluetoothPopupAnchor()
                    }
                }

                onOpenChanged: {
                    if (open) {
                        bar.updateBluetoothPopupAnchor()
                        if (bluetoothIndicator) {
                            bluetoothIndicator.scanNow()
                        }
                    }
                }
            }

            Connections {
                target: bluetoothIndicator
                function onDeviceItemsChanged() { bar.updateBluetoothPopupAnchor() }
                function onWidthChanged() { bar.updateBluetoothPopupAnchor() }
                function onHeightChanged() { bar.updateBluetoothPopupAnchor() }
            }

            onWidthChanged: {
                updateBluetoothPopupAnchor()
                updateCpuTooltipAnchor()
            }
            onHeightChanged: {
                updateBluetoothPopupAnchor()
                updateCpuTooltipAnchor()
            }

            PopupWindow {
                id: notificationPopup
                width: Theme.popupWidth
                property int maxHeight: bar.screen
                    ? Math.max(200, bar.screen.height - (bar.height + Theme.popupOffset + Theme.barMarginTop + Theme.popupBottomMargin))
                    : Theme.popupHeight
                height: Math.min(maxHeight, listColumn.implicitHeight + Theme.popupPadding * 2)
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
                    radius: Theme.popupRadius
                    color: Theme.popupBg
                    border.width: 1
                    border.color: Theme.popupBorder
                    opacity: notificationPopup.anim
                    scale: 0.98 + 0.02 * notificationPopup.anim

                    Flickable {
                        id: notificationList
                        anchors.fill: parent
                        anchors.margins: Theme.popupPadding
                        contentWidth: width
                        contentHeight: listColumn.implicitHeight
                        clip: true

                        Column {
                            id: listColumn
                            spacing: Theme.toastGap
                            width: parent.width

                            Text {
                                text: "Notifications"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSize
                                font.weight: Font.DemiBold
                            }

                            Repeater {
                                model: notificationServer.trackedNotifications.values !== undefined
                                    ? notificationServer.trackedNotifications.values
                                    : notificationServer.trackedNotifications

                                delegate: Rectangle {
                                    width: parent.width
                                    radius: Theme.blockRadius
                                    color: Theme.blockBg
                                    border.width: 1
                                    border.color: Theme.blockBorder
                                    implicitHeight: contentColumn.implicitHeight + Theme.toastPadding * 2
                                    property string displayTitle: {
                                        var s = modelData.summary || ""
                                        if (s.length > Theme.toastTitleMaxChars) {
                                            var app = modelData.appName || ""
                                            return app.length > 0 ? app : s
                                        }
                                        return s
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

                                        Text {
                                            text: displayTitle
                                            color: Theme.accent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.toastTitleSize
                                            font.weight: Theme.fontWeight
                                            textFormat: Text.PlainText
                                            width: parent.width
                                            wrapMode: Text.Wrap
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
                                                text: "확인"
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
                                                    if (modelData && modelData.close) {
                                                        modelData.close()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: notificationCount() === 0
                                text: "No notifications"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                            }
                        }
                    }

                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.RightButton
                hoverEnabled: false
                onClicked: {
                    if (mouse.button === Qt.RightButton) {
                        bar.closeControllers()
                    }
                }
            }
        }
    }
}
