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
import Quickshell.Io
import "components"
import "popups"

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
            property var calendarMonthDate: SystemState.calendarMonthDate
            property var calendarCells: SystemState.calendarCells
            property var calendarDayNames: SystemState.calendarDayNames
            property var appSettings: SystemState.appSettings
            property var holidayMap: SystemState.holidayMap
            property string holidayLoadedKey: SystemState.holidayLoadedKey
            property string weatherCondition: SystemState.weatherCondition
            property string weatherTemperature: SystemState.weatherTemperature
            property string weatherFeelsLike: SystemState.weatherFeelsLike
            property string weatherHumidity: SystemState.weatherHumidity
            property string weatherWind: SystemState.weatherWind
            property string weatherIconUrl: SystemState.weatherIconUrl
            property string weatherLocationText: SystemState.weatherLocationText
            property string weatherUpdatedAt: SystemState.weatherUpdatedAt
            property string weatherError: SystemState.weatherError
            property double weatherLastFetchMs: SystemState.weatherLastFetchMs
            property var cpuUsageIndicatorRef: null
            property var bluetoothIndicatorRef: null
            property var wifiIndicatorRef: null
            property var volumeIndicatorRef: null
            property var clipboardIndicatorRef: null
            property var batteryIndicatorRef: null
            property var dateTimeIndicatorRef: null

            ListModel {
                id: toastModel
            }

            function defaultSettings() { return SystemState.defaultSettings() }
            function normalizedSettings(raw) { return SystemState.normalizedSettings(raw) }
            function refreshLocalizedState() { SystemState.refreshLocalizedState() }
            function applyThemeSettings() { SystemState.applyThemeSettings() }
            function applyRuntimeSettings() { SystemState.applyRuntimeSettings() }

            function tr(key, fallbackText) {
                var v = I18n.t(key)
                return v === key ? fallbackText : v
            }

            function applySettingsText(text) { SystemState.applySettingsText(text) }
            function loadSettings() { SystemState.loadSettings() }
            function saveSettings() { SystemState.saveSettings() }
            function updateSetting(key, value) { SystemState.updateSetting(key, value) }
            function replaceSettings(settingsObj) { SystemState.replaceSettings(settingsObj) }
            function normalizedMonthDate(d) { return SystemState.normalizedMonthDate(d) }
            function buildCalendarCells(referenceDate) { return SystemState.buildCalendarCells(referenceDate) }
            function rebuildCalendar() { SystemState.rebuildCalendar() }
            function setCalendarMonthOffset(offset) { SystemState.setCalendarMonthOffset(offset) }
            function resetCalendarToCurrentMonth() { SystemState.resetCalendarToCurrentMonth() }
            function isoDateKey(year, month, day) { return SystemState.isoDateKey(year, month, day) }
            function buildHolidayCommand(year, countryCode) { return SystemState.buildHolidayCommand(year, countryCode) }
            function ensureHolidayYear(year) { SystemState.ensureHolidayYear(year) }
            function parseHolidayOutput(rawText, year, country) { SystemState.parseHolidayOutput(rawText, year, country) }
            function buildWeatherCommand() { return SystemState.buildWeatherCommand() }
            function parseWeatherOutput(rawText) { SystemState.parseWeatherOutput(rawText) }
            function refreshWeather(force) { SystemState.refreshWeather(force) }

            function normalizeNotificationText(text) {
                var s = text || ""
                s = s.replace(/<br\s*\/?>/gi, "\n")
                s = s.replace(/\r\n/g, "\n")
                s = s.replace(/\\n/g, "\n")
                return s
            }

            Component.onCompleted: {
                if (bar.WlrLayershell) {
                    bar.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
                }
                SystemState.initialize()
            }

            function enforcePopupNoKeyboardFocus(popup) {
                if (!popup || !popup.open || !popup.WlrLayershell) {
                    return
                }
                popup.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
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

            function defaultZoneLayout(zone) {
                if (zone === "left") {
                    return ["workspace", "focusedWindow", "media"]
                }
                if (zone === "center") {
                    return ["vpn", "clock", "screenCapture"]
                }
                return ["systemTray", "volume", "clipboard", "cpu", "memory", "bluetooth", "wifi", "battery", "notifications"]
            }

            function zoneLayout(zone) {
                var settings = appSettings && appSettings.bar && appSettings.bar.layout
                    ? appSettings.bar.layout
                    : null
                if (!settings || !settings[zone] || settings[zone].length === undefined) {
                    return defaultZoneLayout(zone)
                }
                return settings[zone]
            }

            function registerBlockRef(blockKey, item) {
                if (blockKey === "cpu") cpuUsageIndicatorRef = item
                else if (blockKey === "bluetooth") bluetoothIndicatorRef = item
                else if (blockKey === "wifi") wifiIndicatorRef = item
                else if (blockKey === "volume") volumeIndicatorRef = item
                else if (blockKey === "clipboard") clipboardIndicatorRef = item
                else if (blockKey === "battery") batteryIndicatorRef = item
                else if (blockKey === "clock") dateTimeIndicatorRef = item
            }

            function componentForBlock(blockKey) {
                if (blockKey === "workspace") return workspaceIndicatorComp
                if (blockKey === "focusedWindow") return focusedWindowIndicatorComp
                if (blockKey === "media") return mediaIndicatorComp
                if (blockKey === "vpn") return vpnIndicatorComp
                if (blockKey === "clock") return dateTimeIndicatorComp
                if (blockKey === "screenCapture") return screenCaptureIndicatorComp
                if (blockKey === "systemTray") return systemTrayIndicatorComp
                if (blockKey === "volume") return volumeIndicatorComp
                if (blockKey === "clipboard") return clipboardIndicatorComp
                if (blockKey === "cpu") return cpuUsageIndicatorComp
                if (blockKey === "memory") return memoryUsageIndicatorComp
                if (blockKey === "bluetooth") return bluetoothIndicatorComp
                if (blockKey === "wifi") return wifiIndicatorComp
                if (blockKey === "battery") return batteryIndicatorComp
                if (blockKey === "notifications") return notificationTriggerComp
                return null
            }

            function updateCpuPopupAnchor() {
                if (!cpuUsageIndicatorRef) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = cpuUsageIndicatorRef.mapToItem(anchorItem, 0, cpuUsageIndicatorRef.height)
                cpuPopup.anchor.rect.x = pos.x + cpuUsageIndicatorRef.width - Theme.cpuPopupWidth
                cpuPopup.anchor.rect.y = pos.y + Theme.cpuPopupOffset
                cpuPopup.anchor.rect.width = 1
                cpuPopup.anchor.rect.height = 1
            }

            function updateBluetoothPopupAnchor() {
                if (!bluetoothIndicatorRef) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = bluetoothIndicatorRef.mapToItem(anchorItem, 0, bluetoothIndicatorRef.height)
                bluetoothPopup.anchor.rect.x = pos.x + bluetoothIndicatorRef.width - Theme.bluetoothPopupWidth
                bluetoothPopup.anchor.rect.y = pos.y + Theme.bluetoothPopupOffset
                bluetoothPopup.anchor.rect.width = 1
                bluetoothPopup.anchor.rect.height = 1
            }

            function updateWifiPopupAnchor() {
                if (!wifiIndicatorRef) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = wifiIndicatorRef.mapToItem(anchorItem, 0, wifiIndicatorRef.height)
                wifiPopup.anchor.rect.x = pos.x + wifiIndicatorRef.width - Theme.wifiPopupWidth
                    + Theme.wifiPopupAnchorOffsetX
                wifiPopup.anchor.rect.y = pos.y + Theme.wifiPopupOffset + Theme.wifiPopupAnchorOffsetY
                wifiPopup.anchor.rect.width = 1
                wifiPopup.anchor.rect.height = 1
            }

            function updateVolumePopupAnchor() {
                if (!volumeIndicatorRef || !volumePopup) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = volumeIndicatorRef.mapToItem(anchorItem, 0, volumeIndicatorRef.height)
                volumePopup.anchor.rect.x = pos.x + volumeIndicatorRef.width - Theme.volumePopupWidth
                volumePopup.anchor.rect.y = pos.y + Theme.volumePopupOffset
                volumePopup.anchor.rect.width = 1
                volumePopup.anchor.rect.height = 1
            }

            function updateClipboardPopupAnchor() {
                if (!clipboardIndicatorRef || !clipboardPopup) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = clipboardIndicatorRef.mapToItem(anchorItem, 0, clipboardIndicatorRef.height)
                clipboardPopup.anchor.rect.x = pos.x + clipboardIndicatorRef.width - Theme.clipboardPopupWidth
                clipboardPopup.anchor.rect.y = pos.y + Theme.clipboardPopupOffset
                clipboardPopup.anchor.rect.width = 1
                clipboardPopup.anchor.rect.height = 1
            }

            function showVolumePopup(volumePercent, isMuted, isAvailable) {
                if (!volumePopup) {
                    return
                }
                volumePopup.reveal(volumePercent, isMuted, isAvailable)
            }

            function updateBrightnessPopupAnchor() {
                if (!batteryIndicatorRef || !brightnessPopup) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = batteryIndicatorRef.mapToItem(anchorItem, 0, batteryIndicatorRef.height)
                brightnessPopup.anchor.rect.x = pos.x + batteryIndicatorRef.width - Theme.brightnessPopupWidth
                brightnessPopup.anchor.rect.y = pos.y + Theme.brightnessPopupOffset
                brightnessPopup.anchor.rect.width = 1
                brightnessPopup.anchor.rect.height = 1
            }

            function showBrightnessPopup(brightnessPercent, isAvailable) {
                if (!brightnessPopup) {
                    return
                }
                brightnessPopup.reveal(brightnessPercent, isAvailable)
            }

            function updateDateWidgetPopupAnchor() {
                if (!dateTimeIndicatorRef) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = dateTimeIndicatorRef.mapToItem(anchorItem, 0, dateTimeIndicatorRef.height)
                var x = pos.x + (dateTimeIndicatorRef.width - Theme.dateWidgetPopupWidth) / 2
                var minX = Theme.barMarginX
                var maxX = Math.max(minX, bar.width - Theme.dateWidgetPopupWidth - Theme.barMarginX)
                dateWidgetPopup.anchor.rect.x = Math.min(maxX, Math.max(minX, x))
                dateWidgetPopup.anchor.rect.y = pos.y + Theme.dateWidgetPopupOffset
                dateWidgetPopup.anchor.rect.width = 1
                dateWidgetPopup.anchor.rect.height = 1
            }

            function shellQuote(text) {
                return "'" + (text || "").replace(/'/g, "'\\''") + "'"
            }

            function commandWithFile(template, path) {
                return (template || "").replace(/%FILE%/g, shellQuote(path || ""))
            }

            function openScreenshotPreview(path) {
                if (!path || path.length === 0) {
                    return
                }
                if (screenshotPopup.tempPath.length > 0 && screenshotPopup.tempPath !== path) {
                    screenshotDiscardProc.commandText = commandWithFile(Theme.screenshotDiscardCommandTemplate, screenshotPopup.tempPath)
                    screenshotDiscardProc.running = true
                }
                bluetoothPopup.open = false
                wifiPopup.open = false
                cpuPopup.open = false
                clipboardPopup.open = false
                notificationPopup.open = false
                dateWidgetPopup.open = false
                screenshotPopup.errorText = ""
                screenshotPopup.tempPath = path
                screenshotPopup.open = true
            }

            function closeScreenshotPreview(removeTempFile) {
                var path = screenshotPopup.tempPath
                screenshotPopup.open = false
                screenshotPopup.tempPath = ""
                screenshotPopup.errorText = ""
                if (removeTempFile && path && path.length > 0) {
                    screenshotDiscardProc.commandText = commandWithFile(Theme.screenshotDiscardCommandTemplate, path)
                    screenshotDiscardProc.running = true
                }
            }

            Process {
                id: screenshotSaveProc
                property string commandText: ""
                command: ["sh", "-c", commandText]
                running: false
            }

            Process {
                id: screenshotCopyProc
                property string commandText: ""
                command: ["sh", "-c", commandText]
                running: false
            }

            Process {
                id: screenshotDiscardProc
                property string commandText: ""
                command: ["sh", "-c", commandText]
                running: false
            }

            function closeControllers() {
                bluetoothPopup.open = false
                wifiPopup.open = false
                cpuPopup.open = false
                clipboardPopup.open = false
                notificationPopup.open = false
                dateWidgetPopup.open = false
                settingsPopup.open = false
                volumePopup.open = false
                brightnessPopup.open = false
                closeScreenshotPreview(true)
            }

            function toggleBluetoothController() {
                if (bluetoothPopup.open) {
                    bluetoothPopup.open = false
                    return
                }
                wifiPopup.open = false
                cpuPopup.open = false
                clipboardPopup.open = false
                notificationPopup.open = false
                dateWidgetPopup.open = false
                closeScreenshotPreview(true)
                bluetoothPopup.open = true
            }

            function toggleWifiController() {
                if (wifiPopup.open) {
                    wifiPopup.open = false
                    return
                }
                bluetoothPopup.open = false
                cpuPopup.open = false
                clipboardPopup.open = false
                notificationPopup.open = false
                dateWidgetPopup.open = false
                closeScreenshotPreview(true)
                wifiPopup.open = true
            }

            function toggleCpuController() {
                if (cpuPopup.open) {
                    cpuPopup.open = false
                    return
                }
                bluetoothPopup.open = false
                wifiPopup.open = false
                clipboardPopup.open = false
                notificationPopup.open = false
                dateWidgetPopup.open = false
                closeScreenshotPreview(true)
                cpuPopup.open = true
            }

            function toggleClipboardController() {
                if (clipboardPopup.open) {
                    clipboardPopup.open = false
                    return
                }
                bluetoothPopup.open = false
                wifiPopup.open = false
                cpuPopup.open = false
                notificationPopup.open = false
                dateWidgetPopup.open = false
                closeScreenshotPreview(true)
                clipboardPopup.open = true
            }

            function toggleNotificationCenter() {
                if (notificationPopup.open) {
                    notificationPopup.open = false
                    return
                }
                bluetoothPopup.open = false
                wifiPopup.open = false
                cpuPopup.open = false
                clipboardPopup.open = false
                dateWidgetPopup.open = false
                closeScreenshotPreview(true)
                notificationPopup.open = true
            }

            function toggleDateWidget() {
                if (dateWidgetPopup.open) {
                    dateWidgetPopup.open = false
                    return
                }
                bluetoothPopup.open = false
                wifiPopup.open = false
                cpuPopup.open = false
                clipboardPopup.open = false
                notificationPopup.open = false
                closeScreenshotPreview(true)
                dateWidgetPopup.open = true
            }

            function toggleSettingsPanel() {
                if (settingsPopup.open) {
                    return
                }
                bluetoothPopup.open = false
                wifiPopup.open = false
                cpuPopup.open = false
                clipboardPopup.open = false
                notificationPopup.open = false
                dateWidgetPopup.open = false
                closeScreenshotPreview(true)
                settingsPopup.open = true
            }

            function clearTrackedNotifications() {
                var source = []
                if (!notificationServer.trackedNotifications) {
                    return
                }
                if (notificationServer.trackedNotifications.values !== undefined) {
                    source = notificationServer.trackedNotifications.values
                } else {
                    source = notificationServer.trackedNotifications
                }
                var notifications = []
                for (var i = 0; i < source.length; i += 1) {
                    notifications.push(source[i])
                }
                for (var j = notifications.length - 1; j >= 0; j -= 1) {
                    markNotificationRead(notifications[j])
                }
            }

            function markNotificationRead(notification) {
                if (!notification) {
                    return
                }
                if (notification.tracked !== undefined) {
                    notification.tracked = false
                    return
                }
                if (notification.dismiss) {
                    notification.dismiss()
                    return
                }
                if (notification.close) {
                    notification.close()
                }
            }

            HyprlandFocusGrab {
                id: controllerFocusGrab
                windows: [bar, cpuPopup, bluetoothPopup, wifiPopup, clipboardPopup, notificationPopup, dateWidgetPopup, settingsPopup, volumePopup, brightnessPopup, screenshotPopup]
                active: bluetoothPopup.open
                    || wifiPopup.open
                    || cpuPopup.open
                    || clipboardPopup.open
                    || notificationPopup.open
                    || dateWidgetPopup.open
                    || settingsPopup.open
                    || volumePopup.open
                    || brightnessPopup.open
                    || screenshotPopup.open
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
                        Repeater {
                            model: bar.zoneLayout("left")
                            delegate: Item {
                                property string blockKey: modelData
                                implicitWidth: blockLoader.implicitWidth
                                implicitHeight: blockLoader.implicitHeight

                                Loader {
                                    id: blockLoader
                                    sourceComponent: bar.componentForBlock(parent.blockKey)
                                    onLoaded: bar.registerBlockRef(parent.blockKey, item)
                                    onItemChanged: {
                                        if (!item) {
                                            bar.registerBlockRef(parent.blockKey, null)
                                        }
                                    }
                                }

                                DropShadow {
                                    anchors.fill: blockLoader
                                    source: blockLoader
                                    horizontalOffset: Theme.blockShadowOffsetX
                                    verticalOffset: Theme.blockShadowOffsetY
                                    radius: Theme.blockShadowRadius
                                    samples: Theme.blockShadowSamples
                                    color: Theme.blockShadowColor
                                    transparentBorder: true
                                    cached: true
                                    visible: Theme.blockShadowEnabled && !!blockLoader.item
                                    z: -1
                                }
                            }
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
                        Repeater {
                            model: bar.zoneLayout("right")
                            delegate: Item {
                                property string blockKey: modelData
                                implicitWidth: blockLoader.implicitWidth
                                implicitHeight: blockLoader.implicitHeight

                                Loader {
                                    id: blockLoader
                                    sourceComponent: bar.componentForBlock(parent.blockKey)
                                    onLoaded: bar.registerBlockRef(parent.blockKey, item)
                                    onItemChanged: {
                                        if (!item) {
                                            bar.registerBlockRef(parent.blockKey, null)
                                        }
                                    }
                                }

                                DropShadow {
                                    anchors.fill: blockLoader
                                    source: blockLoader
                                    horizontalOffset: Theme.blockShadowOffsetX
                                    verticalOffset: Theme.blockShadowOffsetY
                                    radius: Theme.blockShadowRadius
                                    samples: Theme.blockShadowSamples
                                    color: Theme.blockShadowColor
                                    transparentBorder: true
                                    cached: true
                                    visible: Theme.blockShadowEnabled && !!blockLoader.item
                                    z: -1
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: centerCluster
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.blockGap
                Repeater {
                    model: bar.zoneLayout("center")
                    delegate: Item {
                        property string blockKey: modelData
                        implicitWidth: blockLoader.implicitWidth
                        implicitHeight: blockLoader.implicitHeight

                        Loader {
                            id: blockLoader
                            sourceComponent: bar.componentForBlock(parent.blockKey)
                            onLoaded: bar.registerBlockRef(parent.blockKey, item)
                            onItemChanged: {
                                if (!item) {
                                    bar.registerBlockRef(parent.blockKey, null)
                                }
                            }
                        }

                        DropShadow {
                            anchors.fill: blockLoader
                            source: blockLoader
                            horizontalOffset: Theme.blockShadowOffsetX
                            verticalOffset: Theme.blockShadowOffsetY
                            radius: Theme.blockShadowRadius
                            samples: Theme.blockShadowSamples
                            color: Theme.blockShadowColor
                            transparentBorder: true
                            cached: true
                            visible: Theme.blockShadowEnabled && !!blockLoader.item
                            z: -1
                        }
                    }
                }
            }

            Component { id: workspaceIndicatorComp; WorkspaceIndicator { monitor: bar.hyprMonitor } }
            Component { id: focusedWindowIndicatorComp; FocusedWindowIndicator { monitor: bar.hyprMonitor } }
            Component { id: mediaIndicatorComp; MediaIndicator {} }
            Component { id: vpnIndicatorComp; VpnIndicator {} }
            Component {
                id: dateTimeIndicatorComp
                DateTimeIndicator {
                    onClicked: bar.toggleDateWidget()
                    onMiddleClicked: bar.toggleSettingsPanel()
                }
            }
            Component {
                id: screenCaptureIndicatorComp
                ScreenCaptureIndicator {
                    parentWindow: bar
                    onCaptureCompleted: function(filePath) {
                        bar.openScreenshotPreview(filePath)
                    }
                    onCaptureFailed: function(reason) {
                        if (reason === "cancelled") {
                            bar.closeScreenshotPreview(true)
                            return
                        }
                        bar.appendToast({
                            summary: I18n.t("toast.screenshot_failed"),
                            body: reason,
                            appName: "QuickShell"
                        })
                        screenshotPopup.tempPath = ""
                        screenshotPopup.errorText = reason
                        screenshotPopup.open = true
                    }
                    onRecordingStopped: function(filePath) {
                        bar.appendToast({
                            summary: I18n.t("toast.recording_stopped"),
                            body: filePath && filePath.length > 0 ? filePath : "",
                            appName: "QuickShell"
                        })
                    }
                    onRecordingFailed: function(reason) {
                        if (reason === "cancelled") {
                            return
                        }
                        bar.appendToast({
                            summary: I18n.t("toast.recording_failed"),
                            body: reason,
                            appName: "QuickShell"
                        })
                    }
                }
            }
            Component { id: systemTrayIndicatorComp; SystemTrayIndicator { parentWindow: bar } }
            Component {
                id: volumeIndicatorComp
                VolumeIndicator {
                    onOsdRequested: function(volumePercent, muted, available) {
                        bar.showVolumePopup(volumePercent, muted, available)
                    }
                }
            }
            Component {
                id: clipboardIndicatorComp
                ClipboardIndicator {
                    onClicked: bar.toggleClipboardController()
                    onRightClicked: {
                        SystemState.wipeClipboardItems()
                        clipboardPopup.open = false
                    }
                }
            }
            Component { id: memoryUsageIndicatorComp; MemoryUsageIndicator {} }
            Component {
                id: cpuUsageIndicatorComp
                CPUUsageIndicator {
                    parentWindow: bar
                    onClicked: bar.toggleCpuController()
                }
            }
            Component {
                id: bluetoothIndicatorComp
                BluetoothIndicator {
                    onClicked: bar.toggleBluetoothController()
                }
            }
            Component {
                id: wifiIndicatorComp
                WifiIndicator {
                    onClicked: bar.toggleWifiController()
                }
            }
            Component {
                id: batteryIndicatorComp
                BatteryIndicator {
                    onBrightnessOsdRequested: function(brightnessPercent, available) {
                        bar.showBrightnessPopup(brightnessPercent, available)
                    }
                }
            }
            Component {
                id: notificationTriggerComp
                NotificationTrigger {
                    count: notificationCount()
                    fixedWidth: bar.bluetoothIndicatorRef ? bar.bluetoothIndicatorRef.implicitWidth : 0
                    onClicked: bar.toggleNotificationCenter()
                    onRightClicked: {
                        if (notificationCount() > 0) {
                            bar.clearTrackedNotifications()
                        }
                    }
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

            ToastPopup {
                id: toastPopup
                bar: bar
                toastModel: toastModel
                iconImageComp: iconImageComp
                imageComp: imageComp
            }

            CpuPopup {
                id: cpuPopup
                bar: bar
                cpuUsageIndicator: bar.cpuUsageIndicatorRef
            }

            Connections {
                target: bar.cpuUsageIndicatorRef
                function onWidthChanged() { bar.updateCpuPopupAnchor() }
                function onHeightChanged() { bar.updateCpuPopupAnchor() }
            }

            Connections {
                target: cpuPopup
                function onOpenChanged() { bar.enforcePopupNoKeyboardFocus(cpuPopup) }
            }

            BluetoothPopup {
                id: bluetoothPopup
                bar: bar
                bluetoothIndicator: bar.bluetoothIndicatorRef
            }

            Connections {
                target: bar.bluetoothIndicatorRef
                function onDeviceItemsChanged() { bar.updateBluetoothPopupAnchor() }
                function onWidthChanged() { bar.updateBluetoothPopupAnchor() }
                function onHeightChanged() { bar.updateBluetoothPopupAnchor() }
            }

            Connections {
                target: bluetoothPopup
                function onOpenChanged() { bar.enforcePopupNoKeyboardFocus(bluetoothPopup) }
            }

            WifiPopup {
                id: wifiPopup
                bar: bar
                wifiIndicator: bar.wifiIndicatorRef
            }

            VolumePopup {
                id: volumePopup
                bar: bar
            }

            ClipboardPopup {
                id: clipboardPopup
                bar: bar
                clipboardIndicator: bar.clipboardIndicatorRef
            }

            BrightnessPopup {
                id: brightnessPopup
                bar: bar
            }

            Connections {
                target: bar.wifiIndicatorRef
                function onNetworksChanged() { bar.updateWifiPopupAnchor() }
                function onWidthChanged() { bar.updateWifiPopupAnchor() }
                function onHeightChanged() { bar.updateWifiPopupAnchor() }
            }

            onWidthChanged: {
                updateBluetoothPopupAnchor()
                updateWifiPopupAnchor()
                updateCpuPopupAnchor()
                updateVolumePopupAnchor()
                updateClipboardPopupAnchor()
                updateBrightnessPopupAnchor()
                updateDateWidgetPopupAnchor()
            }
            onHeightChanged: {
                updateBluetoothPopupAnchor()
                updateWifiPopupAnchor()
                updateCpuPopupAnchor()
                updateVolumePopupAnchor()
                updateClipboardPopupAnchor()
                updateBrightnessPopupAnchor()
                updateDateWidgetPopupAnchor()
            }

            ScreenshotPopup {
                id: screenshotPopup
                bar: bar
                screenshotSaveProc: screenshotSaveProc
                screenshotCopyProc: screenshotCopyProc
            }

            NotificationPopup {
                id: notificationPopup
                bar: bar
                notificationServer: notificationServer
                notificationCountFn: function() { return bar.notificationCount() }
                resolveNotificationIconFn: function(v) { return bar.resolveNotificationIcon(v) }
                iconImageComp: iconImageComp
                imageComp: imageComp
            }

            Connections {
                target: bar.dateTimeIndicatorRef
                function onWidthChanged() { bar.updateDateWidgetPopupAnchor() }
                function onHeightChanged() { bar.updateDateWidgetPopupAnchor() }
            }

            Connections {
                target: dateWidgetPopup
                function onOpenChanged() { bar.enforcePopupNoKeyboardFocus(dateWidgetPopup) }
            }

            Connections {
                target: bar.volumeIndicatorRef
                function onWidthChanged() { bar.updateVolumePopupAnchor() }
                function onHeightChanged() { bar.updateVolumePopupAnchor() }
            }

            Connections {
                target: bar.clipboardIndicatorRef
                function onWidthChanged() { bar.updateClipboardPopupAnchor() }
                function onHeightChanged() { bar.updateClipboardPopupAnchor() }
            }

            Connections {
                target: bar.batteryIndicatorRef
                function onWidthChanged() { bar.updateBrightnessPopupAnchor() }
                function onHeightChanged() { bar.updateBrightnessPopupAnchor() }
            }

            DateWidgetPopup {
                id: dateWidgetPopup
                bar: bar
            }

            SettingsPopup {
                id: settingsPopup
                bar: bar
            }

            Connections {
                target: notificationPopup
                function onOpenChanged() { bar.enforcePopupNoKeyboardFocus(notificationPopup) }
            }

            Connections {
                target: screenshotPopup
                function onOpenChanged() { bar.enforcePopupNoKeyboardFocus(screenshotPopup) }
            }

            Connections {
                target: volumePopup
                function onOpenChanged() { bar.enforcePopupNoKeyboardFocus(volumePopup) }
            }

            Connections {
                target: clipboardPopup
                function onOpenChanged() { bar.enforcePopupNoKeyboardFocus(clipboardPopup) }
            }

            Connections {
                target: brightnessPopup
                function onOpenChanged() { bar.enforcePopupNoKeyboardFocus(brightnessPopup) }
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
