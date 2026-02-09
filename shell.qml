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
            property var calendarMonthDate: new Date()
            property var calendarCells: []
            property var calendarDayNames: ["일", "월", "화", "수", "목", "금", "토"]
            property var appSettings: defaultSettings()
            property string settingsFileUrl: Qt.resolvedUrl("settings.json")
            property string settingsFilePath: settingsFileUrl.indexOf("file://") === 0
                ? decodeURIComponent(settingsFileUrl.slice(7))
                : settingsFileUrl
            property var holidayMap: ({})
            property string holidayLoadedKey: ""
            property string weatherCondition: Theme.weatherLoadingText
            property string weatherTemperature: "--"
            property string weatherFeelsLike: "--"
            property string weatherHumidity: "--"
            property string weatherWind: "--"
            property string weatherIconUrl: ""
            property string weatherLocationText: "--"
            property string weatherUpdatedAt: ""
            property string weatherError: ""
            property double weatherLastFetchMs: 0

            ListModel {
                id: toastModel
            }

            function defaultSettings() {
                return {
                    weatherApiKey: "",
                    weatherLocation: "auto:ip",
                    holidayCountryCode: "KR"
                }
            }

            function normalizedSettings(raw) {
                var defaults = defaultSettings()
                var next = raw || {}
                return {
                    weatherApiKey: String(next.weatherApiKey !== undefined ? next.weatherApiKey : defaults.weatherApiKey),
                    weatherLocation: String(next.weatherLocation !== undefined ? next.weatherLocation : defaults.weatherLocation),
                    holidayCountryCode: String(next.holidayCountryCode !== undefined ? next.holidayCountryCode : defaults.holidayCountryCode).toUpperCase()
                }
            }

            function applySettingsText(text) {
                var trimmed = (text || "").trim()
                if (trimmed.length === 0) {
                    appSettings = normalizedSettings({})
                    return
                }
                try {
                    appSettings = normalizedSettings(JSON.parse(trimmed))
                } catch (e) {
                    appSettings = normalizedSettings({})
                }
            }

            function loadSettings() {
                settingsReadProc.commandText = "if [ -f " + shellQuote(settingsFilePath) + " ]; then cat " + shellQuote(settingsFilePath)
                    + "; else printf '{}' ; fi"
                settingsReadProc.running = true
            }

            function saveSettings() {
                var payload = JSON.stringify(appSettings, null, 2)
                settingsWriteProc.commandText = "printf '%s\\n' " + shellQuote(payload) + " > " + shellQuote(settingsFilePath)
                settingsWriteProc.running = true
            }

            function updateSetting(key, value) {
                var next = {
                    weatherApiKey: appSettings.weatherApiKey,
                    weatherLocation: appSettings.weatherLocation,
                    holidayCountryCode: appSettings.holidayCountryCode
                }
                next[key] = value
                appSettings = normalizedSettings(next)
                saveSettings()
                if (key === "holidayCountryCode") {
                    holidayLoadedKey = ""
                    ensureHolidayYear(calendarMonthDate.getFullYear())
                }
                if (key === "weatherApiKey" || key === "weatherLocation") {
                    refreshWeather(true)
                }
            }

            function normalizedMonthDate(d) {
                return new Date(d.getFullYear(), d.getMonth(), 1)
            }

            function buildCalendarCells(referenceDate) {
                var firstDay = new Date(referenceDate.getFullYear(), referenceDate.getMonth(), 1)
                var startOffset = firstDay.getDay()
                var gridStart = new Date(firstDay.getFullYear(), firstDay.getMonth(), 1 - startOffset)
                var cells = []
                var today = new Date()
                var selectedMonth = referenceDate.getMonth()
                for (var i = 0; i < 42; i += 1) {
                    var cellDate = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + i)
                    var isToday = cellDate.getFullYear() === today.getFullYear()
                        && cellDate.getMonth() === today.getMonth()
                        && cellDate.getDate() === today.getDate()
                    var key = isoDateKey(cellDate.getFullYear(), cellDate.getMonth() + 1, cellDate.getDate())
                    var holidayName = holidayMap[key] || ""
                    cells.push({
                        day: cellDate.getDate(),
                        isCurrentMonth: cellDate.getMonth() === selectedMonth,
                        isToday: isToday,
                        isHoliday: holidayName.length > 0,
                        holidayName: holidayName
                    })
                }
                return cells
            }

            function rebuildCalendar() {
                calendarCells = buildCalendarCells(calendarMonthDate)
            }

            function setCalendarMonthOffset(offset) {
                calendarMonthDate = new Date(calendarMonthDate.getFullYear(), calendarMonthDate.getMonth() + offset, 1)
                ensureHolidayYear(calendarMonthDate.getFullYear())
                rebuildCalendar()
            }

            function resetCalendarToCurrentMonth() {
                calendarMonthDate = normalizedMonthDate(new Date())
                ensureHolidayYear(calendarMonthDate.getFullYear())
                rebuildCalendar()
            }

            function isoDateKey(year, month, day) {
                function pad2(v) {
                    return v < 10 ? "0" + v : String(v)
                }
                return String(year) + "-" + pad2(month) + "-" + pad2(day)
            }

            function buildHolidayCommand(year, countryCode) {
                var country = (countryCode || "KR").toUpperCase()
                var url = "https://date.nager.at/api/v3/PublicHolidays/" + String(year) + "/" + country
                return "if command -v curl >/dev/null 2>&1; then curl -fsS --max-time 8 '" + url + "'; " +
                    "elif command -v wget >/dev/null 2>&1; then wget -qO- '" + url + "'; " +
                    "else printf '__QSERR__ missing:curl-or-wget\\n'; fi"
            }

            function ensureHolidayYear(year) {
                var country = (appSettings.holidayCountryCode || "KR").toUpperCase()
                var key = String(year) + "-" + country
                if (holidayLoadedKey === key || holidayProc.running) {
                    return
                }
                holidayProc.requestYear = year
                holidayProc.requestCountry = country
                holidayProc.command = ["sh", "-c", buildHolidayCommand(year, country)]
                holidayProc.running = true
            }

            function parseHolidayOutput(rawText, year, country) {
                var text = (rawText || "").trim()
                if (text.length === 0 || text.indexOf("__QSERR__") === 0) {
                    return
                }
                var list = null
                try {
                    list = JSON.parse(text)
                } catch (e) {
                    return
                }
                if (!Array.isArray(list)) {
                    return
                }
                var map = {}
                for (var i = 0; i < list.length; i += 1) {
                    var entry = list[i] || {}
                    var dateKey = (entry.date || "").trim()
                    if (dateKey.length === 0) {
                        continue
                    }
                    map[dateKey] = (entry.localName || entry.name || "").trim()
                }
                holidayMap = map
                holidayLoadedKey = String(year) + "-" + String(country).toUpperCase()
                rebuildCalendar()
            }

            function buildWeatherCommand() {
                var apiKey = (appSettings.weatherApiKey || "").trim()
                if (apiKey.length === 0) {
                    return "printf '__QSERR__ missing:weatherapi-key\\n'"
                }
                var location = appSettings.weatherLocation && appSettings.weatherLocation.length > 0
                    ? appSettings.weatherLocation
                    : "auto:ip"
                var encodedLocation = encodeURIComponent(location)
                var url = "https://api.weatherapi.com/v1/current.json?key="
                    + encodeURIComponent(apiKey)
                    + "&q=" + encodedLocation
                    + "&aqi=no"
                return "if command -v curl >/dev/null 2>&1; then curl -fsS --max-time 6 '" + url + "'; " +
                    "elif command -v wget >/dev/null 2>&1; then wget -qO- '" + url + "'; " +
                    "else printf '__QSERR__ missing:curl-or-wget\\n'; fi"
            }

            function parseWeatherOutput(rawText) {
                var text = (rawText || "").trim()
                weatherLastFetchMs = Date.now()
                weatherUpdatedAt = Qt.formatDateTime(new Date(), Theme.weatherUpdatedFormat)
                weatherError = ""
                if (text.length === 0) {
                    weatherCondition = Theme.weatherUnavailableText
                    weatherTemperature = "--"
                    weatherFeelsLike = "--"
                    weatherHumidity = "--"
                    weatherWind = "--"
                    weatherIconUrl = ""
                    weatherLocationText = "--"
                    weatherError = Theme.weatherUnavailableText
                    return
                }
                if (text.indexOf("__QSERR__") === 0) {
                    weatherCondition = Theme.weatherUnavailableText
                    weatherTemperature = "--"
                    weatherFeelsLike = "--"
                    weatherHumidity = "--"
                    weatherWind = "--"
                    weatherIconUrl = ""
                    weatherLocationText = "--"
                    weatherError = text.replace("__QSERR__", "").trim()
                    return
                }
                var payload = null
                try {
                    payload = JSON.parse(text)
                } catch (e) {
                    weatherCondition = Theme.weatherUnavailableText
                    weatherTemperature = "--"
                    weatherFeelsLike = "--"
                    weatherHumidity = "--"
                    weatherWind = "--"
                    weatherIconUrl = ""
                    weatherLocationText = "--"
                    weatherError = Theme.weatherUnavailableText
                    return
                }
                if (payload.error) {
                    weatherCondition = Theme.weatherUnavailableText
                    weatherTemperature = "--"
                    weatherFeelsLike = "--"
                    weatherHumidity = "--"
                    weatherWind = "--"
                    weatherIconUrl = ""
                    weatherLocationText = "--"
                    weatherError = payload.error.message || Theme.weatherUnavailableText
                    return
                }
                var location = payload.location || {}
                var current = payload.current || {}
                var condition = current.condition || {}
                weatherCondition = (condition.text || Theme.weatherUnavailableText).trim()
                weatherTemperature = current.temp_c !== undefined ? (Math.round(Number(current.temp_c)) + "°C") : "--"
                weatherFeelsLike = current.feelslike_c !== undefined ? (Math.round(Number(current.feelslike_c)) + "°C") : "--"
                weatherHumidity = current.humidity !== undefined ? (String(current.humidity) + "%") : "--"
                weatherWind = current.wind_kph !== undefined ? (String(Math.round(Number(current.wind_kph))) + " km/h") : "--"
                var locName = (location.name || "").trim()
                var locRegion = (location.region || "").trim()
                var locCountry = (location.country || "").trim()
                var locationParts = []
                if (locName.length > 0) locationParts.push(locName)
                if (locRegion.length > 0 && locRegion !== locName) locationParts.push(locRegion)
                if (locCountry.length > 0) locationParts.push(locCountry)
                weatherLocationText = locationParts.length > 0 ? locationParts.join(", ") : "--"
                var iconPath = condition.icon || ""
                if (iconPath.indexOf("//") === 0) {
                    iconPath = "https:" + iconPath
                }
                iconPath = iconPath.replace("/64x64/", "/128x128/")
                weatherIconUrl = iconPath
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
                loadSettings()
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

            function updateDateWidgetPopupAnchor() {
                if (!dateTimeIndicator) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = dateTimeIndicator.mapToItem(anchorItem, 0, dateTimeIndicator.height)
                var x = pos.x + (dateTimeIndicator.width - Theme.dateWidgetPopupWidth) / 2
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

            Process {
                id: settingsReadProc
                property string commandText: ""
                command: ["sh", "-c", commandText]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        bar.applySettingsText(this.text)
                        bar.saveSettings()
                        bar.holidayLoadedKey = ""
                        bar.ensureHolidayYear(bar.calendarMonthDate.getFullYear())
                        bar.refreshWeather(true)
                    }
                }
            }

            Process {
                id: settingsWriteProc
                property string commandText: ""
                command: ["sh", "-c", commandText]
                running: false
            }

            Process {
                id: weatherProc
                command: ["sh", "-c", bar.buildWeatherCommand()]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: bar.parseWeatherOutput(this.text)
                }
            }

            Process {
                id: holidayProc
                property int requestYear: 0
                property string requestCountry: "KR"
                running: false
                stdout: StdioCollector {
                    onStreamFinished: bar.parseHolidayOutput(this.text, holidayProc.requestYear, holidayProc.requestCountry)
                }
            }

            function refreshWeather(force) {
                if (weatherProc.running) {
                    return
                }
                if (!force && (Date.now() - weatherLastFetchMs) < Theme.weatherMinRefreshMs) {
                    return
                }
                weatherCondition = Theme.weatherLoadingText
                weatherProc.command = ["sh", "-c", buildWeatherCommand()]
                weatherProc.running = true
            }

            Timer {
                id: weatherPollTimer
                interval: Theme.weatherPollInterval
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: bar.refreshWeather(false)
            }

            function closeControllers() {
                bluetoothPopup.open = false
                wifiPopup.open = false
                cpuPopup.open = false
                notificationPopup.open = false
                dateWidgetPopup.open = false
                closeScreenshotPreview(true)
            }

            function toggleBluetoothController() {
                if (bluetoothPopup.open) {
                    bluetoothPopup.open = false
                    return
                }
                wifiPopup.open = false
                cpuPopup.open = false
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
                notificationPopup.open = false
                dateWidgetPopup.open = false
                closeScreenshotPreview(true)
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
                notificationPopup.open = false
                closeScreenshotPreview(true)
                dateWidgetPopup.open = true
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
                windows: [bar, cpuPopup, bluetoothPopup, wifiPopup, notificationPopup, dateWidgetPopup]
                active: bluetoothPopup.open || wifiPopup.open || cpuPopup.open || notificationPopup.open || dateWidgetPopup.open
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
                            onRightClicked: {
                                if (notificationCount() > 0) {
                                    bar.clearTrackedNotifications()
                                }
                            }
                            fixedWidth: bluetoothIndicator.implicitWidth
                        }
                    }
                }
            }

            Row {
                id: centerCluster
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.blockGap

                VpnIndicator {
                    id: vpnIndicator
                }

                DateTimeIndicator {
                    id: dateTimeIndicator
                    onClicked: bar.toggleDateWidget()
                }

                ScreenCaptureIndicator {
                    id: screenCaptureIndicator
                    onCaptureCompleted: function(filePath) {
                        bar.openScreenshotPreview(filePath)
                    }
                    onCaptureFailed: function(reason) {
                        if (reason === "cancelled") {
                            bar.closeScreenshotPreview(true)
                            return
                        }
                        bar.appendToast({
                            summary: "Screenshot Failed",
                            body: reason,
                            appName: "QuickShell"
                        })
                        screenshotPopup.tempPath = ""
                        screenshotPopup.errorText = reason
                        screenshotPopup.open = true
                    }
                }
            }

            PanelWindow {
                id: toastPopup
                implicitWidth: Theme.toastWidth
                implicitHeight: bar.screen ? bar.screen.height : 1080
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
                    height: implicitHeight
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
                            height: implicitHeight
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
                                ? -(toastItem.width + Theme.toastSlideOffset)
                                : (appeared ? 0 : (toastItem.width + Theme.toastSlideOffset))

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

                            opacity: appeared ? 1 : 0
                            scale: 1
                            Component.onCompleted: appeared = true
                            onClosingChanged: {
                                if (closing) {
                                    lifeTimer.stop()
                                    removeTimer.restart()
                                }
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
                                        radius: Theme.toastCardRadius
                                        color: Theme.toastCardBg
                                        border.width: 1
                                        border.color: Theme.toastCardBorder

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
                                                    color: Theme.toastTitleText
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
                                                color: Theme.toastBodyText
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
                                                height: 32
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
                updateDateWidgetPopupAnchor()
            }
            onHeightChanged: {
                updateBluetoothPopupAnchor()
                updateWifiPopupAnchor()
                updateCpuPopupAnchor()
                updateDateWidgetPopupAnchor()
            }

            PopupWindow {
                id: screenshotPopup
                implicitWidth: Theme.screenshotPopupWidth
                implicitHeight: Theme.screenshotPopupHeight
                property bool open: false
                property real anim: open ? 1 : 0
                property string tempPath: ""
                property string errorText: ""
                visible: open || anim > 0.01
                Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
                color: "transparent"
                anchor.window: bar
                anchor.rect.x: (bar.width - width) / 2
                anchor.rect.y: bar.height + Theme.popupOffset

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.screenshotPopupRadius
                    color: Theme.popupBg
                    border.width: 1
                    border.color: Theme.popupBorder
                    opacity: screenshotPopup.anim
                    scale: 0.98 + 0.02 * screenshotPopup.anim

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.screenshotPopupPadding
                        spacing: Theme.screenshotPopupGap

                        Text {
                            id: screenshotTitleLabel
                            text: Theme.screenshotTitle
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSize
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            width: parent.width
                            height: Math.max(
                                90,
                                parent.height - screenshotTitleLabel.implicitHeight - actionsRow.height - (Theme.screenshotPopupGap * 2)
                            )
                            radius: Theme.blockRadius
                            color: Theme.blockBg
                            border.width: 1
                            border.color: Theme.blockBorder
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 6
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                asynchronous: true
                                source: screenshotPopup.tempPath.length > 0 ? ("file://" + screenshotPopup.tempPath) : ""
                                visible: screenshotPopup.tempPath.length > 0
                            }

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                visible: screenshotPopup.tempPath.length === 0 && screenshotPopup.errorText.length > 0
                                text: screenshotPopup.errorText
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                            }
                        }

                        Row {
                            id: actionsRow
                            width: parent.width
                            spacing: Theme.screenshotPopupGap

                            Rectangle {
                                width: (parent.width - Theme.screenshotPopupGap * 2) / 3
                                height: Theme.screenshotActionButtonHeight
                                radius: Theme.wifiConnectRadius
                                color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.screenshotSaveText
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
                                        if (screenshotPopup.tempPath.length === 0) {
                                            bar.closeScreenshotPreview(false)
                                            return
                                        }
                                        screenshotSaveProc.commandText = bar.commandWithFile(
                                            Theme.screenshotSaveCommandTemplate + "; " + Theme.screenshotDiscardCommandTemplate,
                                            screenshotPopup.tempPath
                                        )
                                        screenshotSaveProc.running = true
                                        bar.closeScreenshotPreview(false)
                                    }
                                }
                            }

                            Rectangle {
                                width: (parent.width - Theme.screenshotPopupGap * 2) / 3
                                height: Theme.screenshotActionButtonHeight
                                radius: Theme.wifiConnectRadius
                                color: Theme.blockBg
                                border.width: 1
                                border.color: Theme.blockBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.screenshotCopyText
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.controllerFontSizeSmall
                                    font.weight: Theme.fontWeight
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (screenshotPopup.tempPath.length === 0) {
                                            bar.closeScreenshotPreview(false)
                                            return
                                        }
                                        screenshotCopyProc.commandText = bar.commandWithFile(
                                            Theme.screenshotCopyCommandTemplate + "; " + Theme.screenshotDiscardCommandTemplate,
                                            screenshotPopup.tempPath
                                        )
                                        screenshotCopyProc.running = true
                                        bar.closeScreenshotPreview(false)
                                    }
                                }
                            }

                            Rectangle {
                                width: (parent.width - Theme.screenshotPopupGap * 2) / 3
                                height: Theme.screenshotActionButtonHeight
                                radius: Theme.wifiConnectRadius
                                color: Theme.blockBg
                                border.width: 1
                                border.color: Theme.blockBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.screenshotCloseText
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.controllerFontSizeSmall
                                    font.weight: Theme.fontWeight
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bar.closeScreenshotPreview(true)
                                }
                            }
                        }
                    }
                }
            }

            PopupWindow {
                id: notificationPopup
                implicitWidth: Theme.popupWidth
                property int maxHeight: bar.screen
                    ? Math.max(200, bar.screen.height - (bar.height + Theme.popupOffset + Theme.barMarginTop + Theme.popupBottomMargin))
                    : Theme.popupHeight
                implicitHeight: Math.min(
                    maxHeight,
                    Math.max(
                        listColumn.implicitHeight,
                        notificationCount() === 0 ? Theme.notificationEmptyMinHeight : 0
                    ) + Theme.popupPadding * 2
                )
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
                    radius: Theme.toastCardRadius
                    color: Theme.popupBg
                    border.width: 1
                    border.color: Theme.popupBorder
                    opacity: notificationPopup.anim
                    scale: 0.98 + 0.02 * notificationPopup.anim

                    Flickable {
                        id: notificationList
                        anchors.fill: parent
                        anchors.margins: Theme.popupPadding
                        visible: notificationCount() > 0
                        contentWidth: width
                        contentHeight: listColumn.implicitHeight
                        clip: true

                        Column {
                            id: listColumn
                            spacing: Theme.toastGap
                            width: parent.width

                            Repeater {
                                model: notificationServer.trackedNotifications.values !== undefined
                                    ? notificationServer.trackedNotifications.values
                                    : notificationServer.trackedNotifications

                                delegate: Rectangle {
                                    width: parent.width
                                    radius: Theme.toastCardRadius
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
                                                    bar.markNotificationRead(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: Theme.popupPadding
                        visible: notificationCount() === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 10

                            AnimatedImage {
                                Layout.alignment: Qt.AlignHCenter
                                source: Qt.resolvedUrl("assets/bongocat.gif")
                                fillMode: Image.PreserveAspectFit
                                width: Theme.notificationEmptyGifSize
                                height: Theme.notificationEmptyGifSize
                                playing: true
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Theme.notificationEmptyText
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                }
            }

            Connections {
                target: dateTimeIndicator
                function onWidthChanged() { bar.updateDateWidgetPopupAnchor() }
                function onHeightChanged() { bar.updateDateWidgetPopupAnchor() }
            }

            PopupWindow {
                id: dateWidgetPopup
                implicitWidth: Theme.dateWidgetPopupWidth
                implicitHeight: dateWidgetContent.implicitHeight + Theme.dateWidgetPopupPaddingY * 2
                property bool open: false
                property real anim: open ? 1 : 0
                visible: open || anim > 0.01
                Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
                color: "transparent"
                anchor.window: bar

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.dateWidgetPopupRadius
                    color: Theme.popupBg
                    border.width: 1
                    border.color: Theme.popupBorder
                    opacity: dateWidgetPopup.anim
                    scale: 0.98 + 0.02 * dateWidgetPopup.anim

                    Row {
                        id: dateWidgetContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: Theme.dateWidgetPopupPadding
                        anchors.rightMargin: Theme.dateWidgetPopupPadding
                        anchors.topMargin: Theme.dateWidgetPopupPaddingY
                        spacing: Theme.dateWidgetPopupGap

                        Column {
                            id: calendarPane
                            width: Math.floor((parent.width - Theme.dateWidgetPopupGap - 1) / 2)
                            property int calendarCellWidth: Math.floor((width - Theme.dateWidgetCalendarGap * 6) / 7)
                            property int calendarContentWidth: calendarCellWidth * 7 + Theme.dateWidgetCalendarGap * 6
                            spacing: Theme.dateWidgetPopupGap

                            Column {
                                id: calendarCenterGroup
                                width: calendarPane.calendarContentWidth
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Theme.dateWidgetPopupGap

                                Item {
                                    id: calendarHeader
                                    width: parent.width
                                    height: Theme.dateWidgetNavButtonSize

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: calendarPane.calendarCellWidth
                                        height: Theme.dateWidgetNavButtonSize
                                        radius: Theme.blockRadius
                                        color: Theme.blockBg
                                        border.width: 1
                                        border.color: Theme.blockBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: "◀"
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            font.weight: Theme.fontWeight
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: bar.setCalendarMonthOffset(-1)
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        text: Qt.formatDateTime(bar.calendarMonthDate, "yyyy년 MM월")
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.controllerFontSize
                                        font.weight: Theme.fontWeight
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: calendarPane.calendarCellWidth
                                        height: Theme.dateWidgetNavButtonSize
                                        radius: Theme.blockRadius
                                        color: Theme.blockBg
                                        border.width: 1
                                        border.color: Theme.blockBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: "▶"
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            font.weight: Theme.fontWeight
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: bar.setCalendarMonthOffset(1)
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.dateWidgetCalendarGap

                                    Repeater {
                                        model: bar.calendarDayNames
                                        delegate: Text {
                                            width: calendarPane.calendarCellWidth
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData
                                            color: Theme.accentAlt
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeight
                                        }
                                    }
                                }

                                Grid {
                                    id: calendarGrid
                                    width: parent.width
                                    columns: 7
                                    rowSpacing: Theme.dateWidgetCalendarGap
                                    columnSpacing: Theme.dateWidgetCalendarGap

                                    Repeater {
                                        model: bar.calendarCells
                                        delegate: Rectangle {
                                            property bool isCurrentMonth: modelData.isCurrentMonth
                                            property bool isToday: modelData.isToday
                                            property bool isHoliday: modelData.isHoliday
                                            width: calendarPane.calendarCellWidth
                                            height: Theme.dateWidgetCalendarCellHeight
                                            radius: Theme.blockRadius
                                            color: isToday ? Theme.accentAlt : "transparent"
                                            border.width: isCurrentMonth ? 1 : 0
                                            border.color: Theme.blockBorder
                                            opacity: isCurrentMonth ? 1 : 0.45

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.day
                                                color: isToday ? Theme.textOnAccent : (isHoliday ? Theme.holidayTextColor : Theme.textPrimary)
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Theme.fontWeight
                                            }

                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 3
                                                width: Theme.holidayDotSize
                                                height: Theme.holidayDotSize
                                                radius: width / 2
                                                color: Theme.holidayDotColor
                                                visible: isHoliday && isCurrentMonth && !isToday
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            height: Math.max(calendarPane.implicitHeight, weatherPane.implicitHeight)
                            color: Theme.blockBorder
                            opacity: 0.7
                        }

                        Column {
                            id: weatherPane
                            width: parent.width - calendarPane.width - Theme.dateWidgetPopupGap - 1
                            spacing: 8
                            clip: true

                            Item {
                                width: 1
                                height: Theme.weatherIllustrationTopMargin
                            }

                            Rectangle {
                                width: parent.width
                                height: Theme.weatherIllustrationSize
                                radius: Theme.weatherIllustrationRadius
                                color: "transparent"
                                border.width: 0

                                Image {
                                    anchors.centerIn: parent
                                    width: Theme.weatherIllustrationImageSize
                                    height: Theme.weatherIllustrationImageSize
                                    source: weatherIconUrl
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    asynchronous: true
                                    scale: Theme.weatherIllustrationScale
                                }
                            }

                            Text {
                                text: weatherCondition + "  " + weatherTemperature + " (" + Theme.weatherFeelsLikeLabel + " " + weatherFeelsLike + ")"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                                font.weight: Theme.fontWeight
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                text: Theme.weatherLocationPrefix + ": " + weatherLocationText
                                color: Theme.focusPipInactive
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                text: Theme.weatherHumidityLabel + ": " + weatherHumidity + "\n" + Theme.weatherWindLabel + ": " + weatherWind
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: weatherError.length > 0
                                text: Theme.weatherErrorPrefix + " " + weatherError
                                color: Theme.cpuText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                text: Theme.weatherUpdatedPrefix + " " + weatherUpdatedAt
                                color: Theme.focusPipInactive
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                width: parent.width
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }

                onOpenChanged: {
                    if (open) {
                        bar.updateDateWidgetPopupAnchor()
                        bar.resetCalendarToCurrentMonth()
                        bar.ensureHolidayYear(bar.calendarMonthDate.getFullYear())
                        if (bar.weatherLastFetchMs <= 0 || (Date.now() - bar.weatherLastFetchMs) >= Theme.weatherOpenRefreshMs) {
                            bar.refreshWeather(true)
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
