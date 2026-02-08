//@ pragma UseQApplication
//@ pragma IconTheme Adwaita
import Quickshell
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
            focusable: true

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

            Component.onCompleted: {
                if (bar.WlrLayershell) {
                    bar.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand
                }
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
                var rawIcon = notification.image
                    || notification.appIcon
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

            HyprlandFocusGrab {
                id: controllerFocusGrab
                windows: [bar, cpuPopup, bluetoothPopup, wifiPopup, notificationPopup]
                active: bluetoothPopup.open || wifiPopup.open || cpuPopup.open || notificationPopup.open
                onCleared: bar.closeControllers()
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

                        Loader {
                            id: focusedWindowIndicatorLoader
                            active: true
                            sourceComponent: FocusedWindowIndicator {
                                monitor: bar.hyprMonitor
                            }
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
                implicitWidth: Theme.toastWidth
                implicitHeight: Math.max(1, toastStack.implicitHeight)
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
                                                id: toastTitleRow
                                                spacing: Theme.toastTitleGap
                                                width: parent.width
                                                height: Math.max(toastIconBox.height, titleText.implicitHeight)

                                                Item {
                                                    id: toastIconBox
                                                    width: Theme.toastIconCircleSize
                                                    height: Theme.toastIconCircleSize
                                                    property string iconRaw: model.iconRaw || ""
                                                    property string iconSource: model.iconSource || ""
                                                    property bool useIconImage: iconRaw.indexOf("image://icon/") === 0

                                                    DropShadow {
                                                        anchors.fill: toastIconCircle
                                                        source: toastIconCircle
                                                        radius: Theme.toastIconShadowRadius
                                                        samples: Theme.toastIconShadowRadius * 2
                                                        color: Theme.toastIconShadow
                                                        verticalOffset: Theme.toastIconShadowOffsetY
                                                        horizontalOffset: 0
                                                        transparentBorder: true
                                                    }

                                                    Rectangle {
                                                        id: toastIconCircle
                                                        anchors.fill: parent
                                                        radius: width / 2
                                                        color: Theme.toastIconBg
                                                        border.width: 0
                                                        border.color: Theme.toastIconBorder
                                                    }

                                                    Loader {
                                                        anchors.fill: parent
                                                        anchors.margins: 6
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
                                                        font.pixelSize: Theme.toastIconSize
                                                        font.weight: Theme.fontWeight
                                                        visible: toastIconBox.useIconImage ? toastIconBox.iconRaw.length === 0 : toastIconBox.iconSource.length === 0
                                                    }
                                                }

                                                Text {
                                                    id: titleText
                                                    text: toastItem.displayTitle
                                                    color: Theme.accent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.toastTitleSize
                                                    font.weight: Theme.fontWeight
                                                    width: parent.width - toastIconBox.width - toastTitleRow.spacing
                                                    wrapMode: Text.Wrap
                                                    height: toastTitleRow.height
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }

                                            Item {
                                                width: parent.width
                                                height: Theme.toastBodyTopMargin
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
                implicitWidth: Theme.cpuPopupWidth
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
                implicitWidth: Theme.bluetoothPopupWidth
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
                implicitWidth: Theme.wifiPopupWidth
                implicitHeight: Math.max(1, wifiBox.implicitHeight)
                property bool open: false
                property real anim: open ? 1 : 0
                property int pageIndex: 0
                property real pageAnim: pageIndex
                property var selectedNetwork: null
                property int securityIndex: 0
                property bool securityDropdownOpen: false
                property bool passwordHover: false
                property real securityDropdownX: 0
                property real securityDropdownY: 0
                property bool connectReady: {
                    if (!selectedNetwork) {
                        return false
                    }
                    if (!selectedNetwork.secure) {
                        return true
                    }
                    return passwordInput && passwordInput.text.length > 0
                }
                visible: open || anim > 0.01
                Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
                Behavior on pageAnim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
                color: "transparent"
                anchor.window: bar

                Component.onCompleted: {
                    if (wifiPopup.WlrLayershell) {
                        wifiPopup.WlrLayershell.layer = WlrLayer.Overlay
                        wifiPopup.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
                    }
                }

                function guessSecurityIndex(securityText) {
                    if (!Theme.wifiSecurityOptions || Theme.wifiSecurityOptions.length === 0) {
                        return 0
                    }
                    var text = securityText || ""
                    if (text.indexOf("WPA3") !== -1) {
                        return Math.min(2, Theme.wifiSecurityOptions.length - 1)
                    }
                    if (text.indexOf("WPA") !== -1) {
                        return Math.min(1, Theme.wifiSecurityOptions.length - 1)
                    }
                    if (text.indexOf("WEP") !== -1) {
                        return Math.min(3, Theme.wifiSecurityOptions.length - 1)
                    }
                    return 0
                }

                function selectedSecurityValue() {
                    if (!Theme.wifiSecurityOptionValues || Theme.wifiSecurityOptionValues.length === 0) {
                        return ""
                    }
                    if (securityIndex < 0 || securityIndex >= Theme.wifiSecurityOptionValues.length) {
                        return ""
                    }
                    return Theme.wifiSecurityOptionValues[securityIndex] || ""
                }

                function focusPasswordInput() {
                    if (passwordInput) {
                        passwordInput.forceActiveFocus()
                    }
                }

                function openConnect(network) {
                    selectedNetwork = network
                    securityIndex = guessSecurityIndex(network ? network.security : "")
                    securityDropdownOpen = false
                    updateSecurityDropdownPos()
                    if (passwordInput) {
                        passwordInput.text = ""
                    }
                    pageIndex = 1
                    if (network && network.secure) {
                        Qt.callLater(function() { wifiPopup.focusPasswordInput() })
                    }
                }

                function closeConnect() {
                    pageIndex = 0
                    selectedNetwork = null
                    securityDropdownOpen = false
                    updateSecurityDropdownPos()
                    if (passwordInput) {
                        passwordInput.text = ""
                    }
                }

                function updateSecurityDropdownPos() {
                    if (!securityTrigger || !wifiBox) {
                        return
                    }
                    var pos = securityTrigger.mapToItem(wifiBox, 0, securityTrigger.height + 6)
                    securityDropdownX = pos.x
                    securityDropdownY = pos.y
                }

                function connectSelected() {
                    if (!wifiIndicator || !selectedNetwork || !connectReady) {
                        return
                    }
                    var passwordValue = passwordInput ? passwordInput.text : ""
                    var securityValue = selectedNetwork.secure ? selectedSecurityValue() : ""
                    wifiIndicator.connectTo(selectedNetwork.ssid, passwordValue, securityValue)
                    closeConnect()
                }

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

                    Item {
                        id: wifiContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.wifiPopupPadding
                        implicitHeight: Math.max(listPage.implicitHeight, connectPage.implicitHeight)
                        clip: true

                        Row {
                            id: wifiPages
                            spacing: 0
                            x: -wifiPopup.pageAnim * wifiContent.width
                            Behavior on x { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }

                            Column {
                                id: listPage
                                width: wifiContent.width
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
                                    id: wifiGrid
                                    width: parent.width
                                    property int columnCount: Math.max(1, Theme.wifiNetworkColumns)
                                    columns: columnCount
                                    columnSpacing: Theme.wifiNetworkColumnSpacing
                                    rowSpacing: Theme.wifiNetworkRowSpacing

                                    Repeater {
                                        model: wifiIndicator ? wifiIndicator.networks : []

                                        delegate: Rectangle {
                                            width: (wifiContent.width - wifiGrid.columnSpacing * (wifiGrid.columnCount - 1)) / wifiGrid.columnCount
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
                                                    width: parent.width - Theme.wifiSignalWidth - Theme.wifiSecureIconWidth - 12
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                    height: parent.height
                                                }

                                                Text {
                                                    text: modelData.secure ? Theme.wifiSecureIcon : ""
                                                    color: modelData.active ? Theme.textOnAccent : Theme.textPrimary
                                                    font.family: Theme.iconFontFamily
                                                    font.pixelSize: Theme.controllerFontSizeSmall
                                                    verticalAlignment: Text.AlignVCenter
                                                    height: parent.height
                                                    width: Theme.wifiSecureIconWidth
                                                    horizontalAlignment: Text.AlignHCenter
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
                                                        wifiPopup.openConnect(modelData)
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

                            Column {
                                id: connectPage
                                width: wifiContent.width
                                spacing: 12

                                Text {
                                    text: wifiPopup.selectedNetwork
                                        ? Theme.wifiConnectQuestion.replace("%1", wifiPopup.selectedNetwork.ssid)
                                        : Theme.wifiConnectQuestion.replace("%1", "")
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.controllerFontSize
                                    font.weight: Theme.fontWeight
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    visible: wifiPopup.selectedNetwork && wifiPopup.selectedNetwork.security
                                    text: wifiPopup.selectedNetwork
                                        ? Theme.wifiSecurityLabel + ": " + wifiPopup.selectedNetwork.security
                                        : ""
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.controllerFontSizeSmall
                                    font.weight: Theme.fontWeight
                                }

                                Column {
                                    visible: wifiPopup.selectedNetwork && wifiPopup.selectedNetwork.secure
                                    spacing: 6
                                    width: connectPage.width

                                    Text {
                                        text: Theme.wifiSecurityLabel
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.controllerFontSizeSmall
                                        font.weight: Theme.fontWeight
                                    }

                                    Rectangle {
                                        id: securityTrigger
                                        width: parent.width
                                        height: Theme.wifiConnectFieldHeight
                                        radius: Theme.wifiConnectRadius
                                        color: Theme.wifiConnectFieldBg
                                        border.width: 1
                                        border.color: Theme.wifiConnectFieldBorder

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8

                                            Text {
                                                id: securityLabel
                                                text: Theme.wifiSecurityOptions && Theme.wifiSecurityOptions.length > 0
                                                    ? Theme.wifiSecurityOptions[wifiPopup.securityIndex] || Theme.wifiSecurityOptions[0]
                                                    : "Auto"
                                                color: Theme.textPrimary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.controllerFontSizeSmall
                                                font.weight: Theme.fontWeight
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                                width: parent.width - 22
                                            }

                                            Text {
                                                text: wifiPopup.securityDropdownOpen ? "▴" : "▾"
                                                color: Theme.focusPipInactive
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.controllerFontSizeSmall
                                                verticalAlignment: Text.AlignVCenter
                                                width: 12
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!Theme.wifiSecurityOptions || Theme.wifiSecurityOptions.length === 0) {
                                                    return
                                                }
                                                wifiPopup.securityDropdownOpen = !wifiPopup.securityDropdownOpen
                                                if (wifiPopup.securityDropdownOpen) {
                                                    wifiPopup.updateSecurityDropdownPos()
                                                }
                                            }
                                        }
                                    }
                                }

                                Column {
                                    visible: wifiPopup.selectedNetwork && wifiPopup.selectedNetwork.secure
                                    spacing: 6
                                    width: connectPage.width

                                    Text {
                                        text: Theme.wifiPasswordLabel
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.controllerFontSizeSmall
                                        font.weight: Theme.fontWeight
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: Theme.wifiConnectFieldHeight
                                        radius: Theme.wifiConnectRadius
                                        color: wifiPopup.passwordHover ? Theme.wifiConnectFieldBgHover : Theme.wifiConnectFieldBg
                                        border.width: 1
                                        border.color: wifiPopup.passwordHover ? Theme.wifiConnectFieldBorderHover : Theme.wifiConnectFieldBorder

                                        TextInput {
                                            id: passwordInput
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            echoMode: TextInput.Password
                                            selectionColor: Theme.accent
                                            selectedTextColor: Theme.textOnAccent
                                            activeFocusOnTab: true
                                            focus: true
                                            clip: true
                                        }

                                        HoverHandler {
                                            cursorShape: Qt.IBeamCursor
                                            onHoveredChanged: wifiPopup.passwordHover = hovered
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.margins: 10
                                            text: Theme.wifiPasswordPlaceholder
                                            color: Theme.wifiConnectMutedText
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            visible: passwordInput.text.length === 0 && !passwordInput.focus
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                Item {
                                    width: 1
                                    height: 1
                                }
                            }
                        }
                    }

                    Item {
                        id: wifiOverlay
                        anchors.fill: parent
                        z: 6
                        visible: wifiPopup.selectedNetwork && wifiPopup.selectedNetwork.secure && wifiPopup.securityDropdownOpen

                        Rectangle {
                            id: securityDropdown
                            x: wifiPopup.securityDropdownX
                            y: wifiPopup.securityDropdownY
                            width: securityTrigger ? securityTrigger.width : 200
                            height: Math.min(Theme.wifiConnectFieldHeight * 4, securityList.implicitHeight + 12)
                            radius: Theme.wifiConnectRadius
                            color: Theme.wifiConnectFieldBg
                            border.width: 1
                            border.color: Theme.wifiConnectFieldBorder
                        }

                        Column {
                            id: securityList
                            x: securityDropdown.x
                            y: securityDropdown.y
                            width: securityDropdown.width
                            anchors.margins: 6
                            spacing: 4

                            Repeater {
                                model: Theme.wifiSecurityOptions ? Theme.wifiSecurityOptions.length : 0

                                delegate: Rectangle {
                                    width: parent.width
                                    height: Theme.wifiConnectFieldHeight - 6
                                    radius: Theme.wifiConnectRadius - 2
                                    color: index === wifiPopup.securityIndex ? Theme.accentAlt : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.wifiSecurityOptions[index]
                                        color: index === wifiPopup.securityIndex ? Theme.textOnAccent : Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.controllerFontSizeSmall
                                        font.weight: Theme.fontWeight
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            wifiPopup.securityIndex = index
                                            wifiPopup.securityDropdownOpen = false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        id: connectButtons
                        anchors.left: wifiContent.left
                        anchors.right: wifiContent.right
                        anchors.bottom: wifiContent.bottom
                        spacing: 8
                        visible: wifiPopup.pageIndex === 1

                        Rectangle {
                            width: (wifiContent.width - 8) / 2
                            height: Theme.wifiConnectButtonHeight
                            radius: Theme.wifiConnectRadius
                            color: Theme.wifiConnectFieldBg
                            border.width: 1
                            border.color: Theme.wifiConnectFieldBorder

                            Text {
                                anchors.centerIn: parent
                                text: Theme.wifiConnectNoText
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                                font.weight: Theme.fontWeight
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiPopup.closeConnect()
                            }
                        }

                        Rectangle {
                            width: (wifiContent.width - 8) / 2
                            height: Theme.wifiConnectButtonHeight
                            radius: Theme.wifiConnectRadius
                            color: Theme.accent
                            opacity: wifiPopup.connectReady ? 1 : 0.5

                            Text {
                                anchors.centerIn: parent
                                text: Theme.wifiConnectYesText
                                color: Theme.textOnAccent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                                font.weight: Theme.fontWeight
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiPopup.connectSelected()
                            }
                        }
                    }
                }

                onOpenChanged: {
                    if (open) {
                        if (wifiPopup.WlrLayershell) {
                            wifiPopup.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
                        }
                        bar.updateWifiPopupAnchor()
                        if (wifiIndicator) {
                            wifiIndicator.scanNow()
                        }
                        if (pageIndex === 1 && selectedNetwork && selectedNetwork.secure) {
                            Qt.callLater(function() { wifiPopup.focusPasswordInput() })
                        }
                    } else {
                        if (wifiPopup.WlrLayershell) {
                            wifiPopup.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
                        }
                        closeConnect()
                    }
                }

                onWidthChanged: updateSecurityDropdownPos()
                onHeightChanged: updateSecurityDropdownPos()
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
                implicitWidth: Theme.popupWidth
                property int maxHeight: bar.screen
                    ? Math.max(200, bar.screen.height - (bar.height + Theme.popupOffset + Theme.barMarginTop + Theme.popupBottomMargin))
                    : Theme.popupHeight
                implicitHeight: Math.min(maxHeight, listColumn.implicitHeight + Theme.popupPadding * 2)
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
                                            id: listTitleRow
                                            spacing: Theme.toastTitleGap
                                            width: parent.width
                                            height: Math.max(listIconBox.height, listTitleText.implicitHeight)

                                            Item {
                                                id: listIconBox
                                                width: Theme.toastIconCircleSize
                                                height: Theme.toastIconCircleSize
                                                property string iconRaw: (modelData && (modelData.image || modelData.appIcon || modelData.appIconName || modelData.icon || modelData.iconName)) || ""
                                                property string iconSource: resolveNotificationIcon(iconRaw)
                                                property bool useIconImage: iconRaw.indexOf("image://icon/") === 0

                                                DropShadow {
                                                    anchors.fill: listIconCircle
                                                    source: listIconCircle
                                                    radius: Theme.toastIconShadowRadius
                                                    samples: Theme.toastIconShadowRadius * 2
                                                    color: Theme.toastIconShadow
                                                    verticalOffset: Theme.toastIconShadowOffsetY
                                                    horizontalOffset: 0
                                                    transparentBorder: true
                                                }

                                                Rectangle {
                                                    id: listIconCircle
                                                    anchors.fill: parent
                                                    radius: width / 2
                                                    color: Theme.toastIconBg
                                                    border.width: 0
                                                    border.color: Theme.toastIconBorder
                                                }

                                                Loader {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
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
                                                        font.pixelSize: Theme.toastIconSize
                                                        font.weight: Theme.fontWeight
                                                        visible: listIconBox.useIconImage ? listIconBox.iconRaw.length === 0 : listIconBox.iconSource.length === 0
                                                    }
                                                }

                                                Text {
                                                    id: listTitleText
                                                    text: displayTitle
                                                    color: Theme.accent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.toastTitleSize
                                                    font.weight: Theme.fontWeight
                                                    textFormat: Text.PlainText
                                                    width: parent.width - listIconBox.width - listTitleRow.spacing
                                                    wrapMode: Text.Wrap
                                                    height: listTitleRow.height
                                                    verticalAlignment: Text.AlignVCenter
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
