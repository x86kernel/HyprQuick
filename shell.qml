//@ pragma UseQApplication
//@ pragma IconTheme Adwaita
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Widgets
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

            function normalizeNotificationText(text) {
                var s = text || ""
                s = s.replace(/<br\s*\/?>/gi, "\n")
                s = s.replace(/\r\n/g, "\n")
                s = s.replace(/\\n/g, "\n")
                return s
            }

            function resolveNotificationIcon(iconValue) {
                if (!iconValue || iconValue.length === 0) {
                    return ""
                }
                if (iconValue.indexOf("image://icon/") === 0) {
                    var name = iconValue.slice("image://icon/".length)
                    var resolved = Quickshell.iconPath(name, "")
                    return resolved && resolved.length > 0 ? resolved : ""
                }
                if (iconValue.indexOf("image://") === 0 || iconValue.indexOf("file://") === 0 || iconValue.indexOf("/") === 0) {
                    return iconValue
                }
                var resolved = Quickshell.iconPath(iconValue, "")
                return resolved && resolved.length > 0 ? resolved : ""
            }

            function appendToast(notification) {
                var rawIcon = notification.appIcon
                    || notification.appIconName
                    || notification.icon
                    || notification.iconName
                    || ""
                var appIcon = resolveNotificationIcon(rawIcon)
                toastCounter += 1
                toastModel.append({
                    toastId: toastCounter,
                    summary: normalizeNotificationText(notification.summary),
                    body: normalizeNotificationText(notification.body),
                    appName: notification.appName || "",
                    iconSource: appIcon,
                    iconRaw: rawIcon
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

            function updateCpuPopupAnchor() {
                if (!cpuUsageIndicator) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = cpuUsageIndicator.mapToItem(anchorItem, 0, cpuUsageIndicator.height)
                cpuPopup.anchor.rect.x = pos.x + cpuUsageIndicator.width - Theme.cpuPopupWidth
                cpuPopup.anchor.rect.y = pos.y + Theme.cpuPopupOffset
                cpuPopup.anchor.rect.width = 1
                cpuPopup.anchor.rect.height = 1
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

            function updateWifiPopupAnchor() {
                if (!wifiIndicator) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = wifiIndicator.mapToItem(anchorItem, 0, wifiIndicator.height)
                wifiPopup.anchor.rect.x = pos.x + wifiIndicator.width - Theme.wifiPopupWidth
                wifiPopup.anchor.rect.y = pos.y + Theme.wifiPopupOffset
                wifiPopup.anchor.rect.width = 1
                wifiPopup.anchor.rect.height = 1
            }

            function closeControllers() {
                bluetoothPopup.open = false
                wifiPopup.open = false
                cpuPopup.open = false
                notificationPopup.open = false
            }

            function toggleBluetoothController() {
                if (bluetoothPopup.open) {
                    bluetoothPopup.open = false
                    return
                }
                wifiPopup.open = false
                cpuPopup.open = false
                notificationPopup.open = false
                bluetoothPopup.open = true
            }

            function toggleWifiController() {
                if (wifiPopup.open) {
                    wifiPopup.open = false
                    return
                }
                bluetoothPopup.open = false
                cpuPopup.open = false
                notificationPopup.open = false
                wifiPopup.open = true
            }

            function toggleCpuController() {
                if (cpuPopup.open) {
                    cpuPopup.open = false
                    return
                }
                bluetoothPopup.open = false
                wifiPopup.open = false
                notificationPopup.open = false
                cpuPopup.open = true
            }

            function toggleNotificationCenter() {
                if (notificationPopup.open) {
                    notificationPopup.open = false
                    return
                }
                bluetoothPopup.open = false
                wifiPopup.open = false
                cpuPopup.open = false
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
                            onClicked: bar.toggleCpuController()
                        }

                        MemoryUsageIndicator {
                            id: memoryUsageIndicator
                        }

                        BluetoothIndicator {
                            id: bluetoothIndicator
                            onClicked: bar.toggleBluetoothController()
                        }

                        WifiIndicator {
                            id: wifiIndicator
                            onClicked: bar.toggleWifiController()
                        }

                        BatteryIndicator {
                            id: batteryIndicator
                        }

                        NotificationTrigger {
                            id: notificationTrigger
                            count: notificationCount()
                            onClicked: bar.toggleNotificationCenter()
                            fixedWidth: bluetoothIndicator.implicitWidth
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

                Component {
                    id: iconImageComp
                    IconImage {
                        anchors.fill: parent
                        source: parent.iconRaw || ""
                    }
                }

                Component {
                    id: imageComp
                    Image {
                        anchors.fill: parent
                        source: parent.iconSource || ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        asynchronous: true
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
                                return s.length > Theme.toastTitleMaxChars ? (model.appName || s) : s
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

                                            Row {
                                                spacing: 8
                                                width: parent.width

                                                Item {
                                                    id: toastIconBox
                                                    width: 18
                                                    height: 18
                                                    property string iconRaw: model.iconRaw || ""
                                                    property string iconSource: model.iconSource || ""
                                                    property bool useIconImage: iconRaw.indexOf("image://icon/") === 0

                                                    Loader {
                                                        anchors.fill: parent
                                                        active: toastIconBox.useIconImage ? toastIconBox.iconRaw.length > 0 : toastIconBox.iconSource.length > 0
                                                        sourceComponent: toastIconBox.useIconImage ? iconImageComp : imageComp
                                                        property string iconRaw: toastIconBox.iconRaw
                                                        property string iconSource: toastIconBox.iconSource
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: Theme.notificationFallbackIcon
                                                        color: Theme.accent
                                                        font.family: Theme.iconFontFamily
                                                        font.pixelSize: Theme.iconSize
                                                        font.weight: Theme.fontWeight
                                                        visible: toastIconBox.useIconImage ? toastIconBox.iconRaw.length === 0 : toastIconBox.iconSource.length === 0
                                                    }
                                                }

                                                Text {
                                                    text: toastItem.displayTitle
                                                    color: Theme.accent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.toastTitleSize
                                                    font.weight: Theme.fontWeight
                                                    width: parent.width - 26
                                                    wrapMode: Text.Wrap
                                                }
                                            }

                                            Text {
                                                text: toastItem.displayBody
                                                color: Theme.textPrimary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.toastBodySize
                                                font.weight: Theme.fontWeight
                                                textFormat: Text.PlainText
                                                width: parent.width
                                                wrapMode: Text.Wrap
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
                id: cpuPopup
                width: Theme.cpuPopupWidth
                implicitHeight: Math.max(1, cpuBox.implicitHeight)
                property bool open: false
                property real anim: open ? 1 : 0
                visible: open || anim > 0.01
                Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
                color: "transparent"
                anchor.window: bar

                Rectangle {
                    id: cpuBox
                    anchors.fill: parent
                    radius: Theme.cpuPopupRadius
                    color: Theme.cpuPopupBg
                    border.width: 1
                    border.color: Theme.cpuPopupBorder
                    implicitHeight: cpuContent.implicitHeight + Theme.cpuPopupPadding * 2
                    opacity: cpuPopup.anim
                    scale: 0.98 + 0.02 * cpuPopup.anim

                    Column {
                        id: cpuContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.cpuPopupPadding
                        spacing: 10

                        Text {
                            text: "CPU"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSize
                            font.weight: Theme.fontWeight
                        }

                        Text {
                            text: "Usage"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            width: parent.width
                            height: 10
                            radius: 5
                            color: Theme.blockBg

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, (cpuUsageIndicator ? cpuUsageIndicator.usage : 0) / 100))
                                height: parent.height
                                radius: 5
                                color: Theme.cpuText
                            }
                        }

                        Text {
                            text: Math.round(cpuUsageIndicator ? cpuUsageIndicator.usage : 0) + "%"
                            color: Theme.cpuText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Text {
                            text: "Temperature"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Text {
                            text: cpuUsageIndicator ? cpuUsageIndicator.tooltipText : "Temp: n/a"
                            color: Theme.cpuTooltipText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                            width: parent.width
                            wrapMode: Text.Wrap
                        }
                    }
                }

                onOpenChanged: {
                    if (open) {
                        bar.updateCpuPopupAnchor()
                    }
                }
            }

            Connections {
                target: cpuUsageIndicator
                function onWidthChanged() { bar.updateCpuPopupAnchor() }
                function onHeightChanged() { bar.updateCpuPopupAnchor() }
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

            PopupWindow {
                id: wifiPopup
                width: Theme.wifiPopupWidth
                implicitHeight: Math.max(1, wifiBox.implicitHeight)
                property bool open: false
                property real anim: open ? 1 : 0
                visible: open || anim > 0.01
                Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
                color: "transparent"
                anchor.window: bar

                Rectangle {
                    id: wifiBox
                    anchors.fill: parent
                    radius: Theme.wifiPopupRadius
                    color: Theme.wifiPopupBg
                    border.width: 1
                    border.color: Theme.wifiPopupBorder
                    implicitHeight: wifiContent.implicitHeight + Theme.wifiPopupPadding * 2
                    opacity: wifiPopup.anim
                    scale: 0.98 + 0.02 * wifiPopup.anim

                    Column {
                        id: wifiContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.wifiPopupPadding
                        spacing: 8

                        Text {
                            text: "WiFi"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSize
                            font.weight: Theme.fontWeight
                        }

                        Text {
                            text: wifiIndicator && wifiIndicator.ssid.length > 0 ? wifiIndicator.ssid : "Not connected"
                            color: Theme.wifiText
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
                                text: wifiIndicator && wifiIndicator.radioOn ? "Turn WiFi Off" : "Turn WiFi On"
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
                                    if (wifiIndicator) {
                                        wifiIndicator.setWifiPower(!wifiIndicator.radioOn)
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Networks"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Grid {
                            width: parent.width
                            columns: 2
                            columnSpacing: 12
                            rowSpacing: 12

                            Repeater {
                                model: wifiIndicator ? wifiIndicator.networks : []

                                delegate: Rectangle {
                                    width: (wifiContent.width - 8) / 2
                                    height: 38
                                    radius: 6
                                    color: modelData.active ? Theme.wifiText : Theme.blockBg
                                    border.width: 1
                                    border.color: Theme.blockBorder

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: Theme.blockPaddingX
                                        spacing: 6

                                        Text {
                                            text: modelData.ssid
                                            color: modelData.active ? Theme.textOnAccent : Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            font.weight: Theme.fontWeight
                                            width: parent.width - Theme.wifiSignalWidth - 6
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            height: parent.height
                                        }

                                        Text {
                                            text: modelData.signal + "%"
                                            color: modelData.active ? Theme.textOnAccent : Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            verticalAlignment: Text.AlignVCenter
                                            height: parent.height
                                            width: Theme.wifiSignalWidth
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!wifiIndicator)
                                                return
                                            if (modelData.active) {
                                                wifiIndicator.disconnectActive()
                                            } else {
                                                wifiIndicator.connectTo(modelData.ssid)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: !wifiIndicator || wifiIndicator.networks.length === 0
                            text: "No networks"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                        }
                    }
                }

                onOpenChanged: {
                    if (open) {
                        bar.updateWifiPopupAnchor()
                        if (wifiIndicator) {
                            wifiIndicator.scanNow()
                        }
                    }
                }
            }

            Connections {
                target: wifiIndicator
                function onNetworksChanged() { bar.updateWifiPopupAnchor() }
                function onWidthChanged() { bar.updateWifiPopupAnchor() }
                function onHeightChanged() { bar.updateWifiPopupAnchor() }
            }

            onWidthChanged: {
                updateBluetoothPopupAnchor()
                updateWifiPopupAnchor()
                updateCpuPopupAnchor()
            }
            onHeightChanged: {
                updateBluetoothPopupAnchor()
                updateWifiPopupAnchor()
                updateCpuPopupAnchor()
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
                                            spacing: 8
                                            width: parent.width

                                            Item {
                                                id: listIconBox
                                                width: 18
                                                height: 18
                                                property string iconRaw: (modelData && (modelData.appIcon || modelData.appIconName || modelData.icon || modelData.iconName)) || ""
                                                property string iconSource: resolveNotificationIcon(iconRaw)
                                                property bool useIconImage: iconRaw.indexOf("image://icon/") === 0

                                                Loader {
                                                    anchors.fill: parent
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
                                                    font.pixelSize: Theme.iconSize
                                                    font.weight: Theme.fontWeight
                                                    visible: listIconBox.useIconImage ? listIconBox.iconRaw.length === 0 : listIconBox.iconSource.length === 0
                                                }
                                            }

                                            Text {
                                                text: displayTitle
                                                color: Theme.accent
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.toastTitleSize
                                                font.weight: Theme.fontWeight
                                                textFormat: Text.PlainText
                                                width: parent.width - 26
                                                wrapMode: Text.Wrap
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
