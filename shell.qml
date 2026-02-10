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
            property var calendarMonthDate: new Date()
            property var calendarCells: []
            property var calendarDayNames: localizedDayNames()
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
                    general: {
                        locale: "ko-KR"
                    },
                    integrations: {
                        weather: {
                            apiKey: "",
                            location: "auto:ip"
                        },
                        holidays: {
                            countryCode: "KR"
                        }
                    },
                    theme: {
                        font: {
                            family: Theme.fontFamily,
                            size: Theme.fontSize,
                            iconFamily: Theme.iconFontFamily,
                            iconSize: Theme.iconSize
                        }
                    }
                }
            }

            function normalizedSettings(raw) {
                var defaults = defaultSettings()
                var next = raw || {}
                var general = next.general || {}
                var integrations = next.integrations || {}
                var weather = integrations.weather || {}
                var holidays = integrations.holidays || {}
                var theme = next.theme || {}
                var font = theme.font || {}
                return {
                    general: {
                        // Legacy flat key compatibility: locale
                        locale: I18n.normalizeLocale(general.locale !== undefined ? general.locale : (next.locale !== undefined ? next.locale : defaults.general.locale))
                    },
                    integrations: {
                        weather: {
                            // Legacy flat key compatibility: weatherApiKey, weatherLocation
                            apiKey: String(weather.apiKey !== undefined ? weather.apiKey : (next.weatherApiKey !== undefined ? next.weatherApiKey : defaults.integrations.weather.apiKey)),
                            location: String(weather.location !== undefined ? weather.location : (next.weatherLocation !== undefined ? next.weatherLocation : defaults.integrations.weather.location))
                        },
                        holidays: {
                            // Legacy flat key compatibility: holidayCountryCode
                            countryCode: String(holidays.countryCode !== undefined ? holidays.countryCode : (next.holidayCountryCode !== undefined ? next.holidayCountryCode : defaults.integrations.holidays.countryCode)).toUpperCase()
                        }
                    },
                    theme: {
                        font: {
                            family: String(font.family !== undefined ? font.family : defaults.theme.font.family),
                            size: Math.max(8, Number(font.size !== undefined ? font.size : defaults.theme.font.size) || defaults.theme.font.size),
                            iconFamily: String(font.iconFamily !== undefined ? font.iconFamily : defaults.theme.font.iconFamily),
                            iconSize: Math.max(8, Number(font.iconSize !== undefined ? font.iconSize : defaults.theme.font.iconSize) || defaults.theme.font.iconSize)
                        }
                    }
                }
            }

            function localizedDayNames() {
                function tr(key, fallback) {
                    var v = I18n.t(key)
                    return v === key ? fallback : v
                }
                return [
                    tr("calendar.day.sun", "일"),
                    tr("calendar.day.mon", "월"),
                    tr("calendar.day.tue", "화"),
                    tr("calendar.day.wed", "수"),
                    tr("calendar.day.thu", "목"),
                    tr("calendar.day.fri", "금"),
                    tr("calendar.day.sat", "토")
                ]
            }

            function refreshLocalizedState() {
                calendarDayNames = localizedDayNames()
            }

            function applyThemeSettings() {
                var font = appSettings.theme.font
                Theme.fontFamily = font.family
                Theme.fontSize = Math.round(font.size)
                Theme.iconFontFamily = font.iconFamily
                Theme.iconSize = Math.round(font.iconSize)
            }

            function applyRuntimeSettings() {
                I18n.setLocale(appSettings.general.locale)
                applyThemeSettings()
                refreshLocalizedState()
            }

            function tr(key, fallbackText) {
                var v = I18n.t(key)
                return v === key ? fallbackText : v
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
                var next = normalizedSettings(appSettings)
                var mapped = key
                if (key === "weatherApiKey")
                    mapped = "integrations.weather.apiKey"
                else if (key === "weatherLocation")
                    mapped = "integrations.weather.location"
                else if (key === "holidayCountryCode")
                    mapped = "integrations.holidays.countryCode"
                else if (key === "locale")
                    mapped = "general.locale"
                else if (key === "fontFamily")
                    mapped = "theme.font.family"
                else if (key === "fontSize")
                    mapped = "theme.font.size"
                else if (key === "iconFontFamily")
                    mapped = "theme.font.iconFamily"
                else if (key === "iconSize")
                    mapped = "theme.font.iconSize"

                var parts = mapped.split(".")
                var cursor = next
                for (var i = 0; i < parts.length - 1; i += 1) {
                    if (!cursor[parts[i]] || typeof cursor[parts[i]] !== "object") {
                        cursor[parts[i]] = {}
                    }
                    cursor = cursor[parts[i]]
                }
                cursor[parts[parts.length - 1]] = value
                appSettings = normalizedSettings(next)
                saveSettings()
                if (mapped === "integrations.holidays.countryCode") {
                    holidayLoadedKey = ""
                    ensureHolidayYear(calendarMonthDate.getFullYear())
                }
                if (mapped === "integrations.weather.apiKey" || mapped === "integrations.weather.location") {
                    refreshWeather(true)
                }
                if (mapped === "general.locale") {
                    applyRuntimeSettings()
                    refreshWeather(true)
                    return
                }
                if (mapped.indexOf("theme.font.") === 0) {
                    applyThemeSettings()
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
                var country = (appSettings.integrations.holidays.countryCode || "KR").toUpperCase()
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
                var apiKey = (appSettings.integrations.weather.apiKey || "").trim()
                if (apiKey.length === 0) {
                    return "printf '__QSERR__ missing:weatherapi-key\\n'"
                }
                var localeCode = String(appSettings.general.locale || "en-US").trim().toLowerCase()
                var weatherLang = "en"
                if (localeCode.indexOf("ko") === 0) {
                    weatherLang = "ko"
                } else if (localeCode.indexOf("ja") === 0) {
                    weatherLang = "ja"
                } else if (localeCode.indexOf("zh") === 0) {
                    weatherLang = "zh"
                }
                var location = appSettings.integrations.weather.location && appSettings.integrations.weather.location.length > 0
                    ? appSettings.integrations.weather.location
                    : "auto:ip"
                var encodedLocation = encodeURIComponent(location)
                var url = "https://api.weatherapi.com/v1/current.json?key="
                    + encodeURIComponent(apiKey)
                    + "&q=" + encodedLocation
                    + "&lang=" + encodeURIComponent(weatherLang)
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
                    weatherCondition = tr("weather.unavailable", Theme.weatherUnavailableText)
                    weatherTemperature = "--"
                    weatherFeelsLike = "--"
                    weatherHumidity = "--"
                    weatherWind = "--"
                    weatherIconUrl = ""
                    weatherLocationText = "--"
                    weatherError = tr("weather.unavailable", Theme.weatherUnavailableText)
                    return
                }
                if (text.indexOf("__QSERR__") === 0) {
                    weatherCondition = tr("weather.unavailable", Theme.weatherUnavailableText)
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
                    weatherCondition = tr("weather.unavailable", Theme.weatherUnavailableText)
                    weatherTemperature = "--"
                    weatherFeelsLike = "--"
                    weatherHumidity = "--"
                    weatherWind = "--"
                    weatherIconUrl = ""
                    weatherLocationText = "--"
                    weatherError = tr("weather.unavailable", Theme.weatherUnavailableText)
                    return
                }
                if (payload.error) {
                    weatherCondition = tr("weather.unavailable", Theme.weatherUnavailableText)
                    weatherTemperature = "--"
                    weatherFeelsLike = "--"
                    weatherHumidity = "--"
                    weatherWind = "--"
                    weatherIconUrl = ""
                    weatherLocationText = "--"
                    weatherError = payload.error.message || tr("weather.unavailable", Theme.weatherUnavailableText)
                    return
                }
                var location = payload.location || {}
                var current = payload.current || {}
                var condition = current.condition || {}
                weatherCondition = (condition.text || tr("weather.unavailable", Theme.weatherUnavailableText)).trim()
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
                applyRuntimeSettings()
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

            function updateVolumePopupAnchor() {
                if (!volumeIndicator || !volumePopup) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = volumeIndicator.mapToItem(anchorItem, 0, volumeIndicator.height)
                volumePopup.anchor.rect.x = pos.x + volumeIndicator.width - Theme.volumePopupWidth
                volumePopup.anchor.rect.y = pos.y + Theme.volumePopupOffset
                volumePopup.anchor.rect.width = 1
                volumePopup.anchor.rect.height = 1
            }

            function showVolumePopup(volumePercent, isMuted, isAvailable) {
                if (!volumePopup) {
                    return
                }
                volumePopup.reveal(volumePercent, isMuted, isAvailable)
            }

            function updateBrightnessPopupAnchor() {
                if (!batteryIndicator || !brightnessPopup) {
                    return
                }
                var anchorItem = bar.contentItem ? bar.contentItem : bar
                var pos = batteryIndicator.mapToItem(anchorItem, 0, batteryIndicator.height)
                brightnessPopup.anchor.rect.x = pos.x + batteryIndicator.width - Theme.brightnessPopupWidth
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
                        bar.applyRuntimeSettings()
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
                weatherCondition = tr("weather.loading", Theme.weatherLoadingText)
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

                        VolumeIndicator {
                            id: volumeIndicator
                            onOsdRequested: function(volumePercent, muted, available) {
                                bar.showVolumePopup(volumePercent, muted, available)
                            }
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
                            onBrightnessOsdRequested: function(brightnessPercent, available) {
                                bar.showBrightnessPopup(brightnessPercent, available)
                            }
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
                            summary: I18n.t("toast.screenshot_failed"),
                            body: reason,
                            appName: "QuickShell"
                        })
                        screenshotPopup.tempPath = ""
                        screenshotPopup.errorText = reason
                        screenshotPopup.open = true
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
                cpuUsageIndicator: cpuUsageIndicator
            }

            Connections {
                target: cpuUsageIndicator
                function onWidthChanged() { bar.updateCpuPopupAnchor() }
                function onHeightChanged() { bar.updateCpuPopupAnchor() }
            }

            BluetoothPopup {
                id: bluetoothPopup
                bar: bar
                bluetoothIndicator: bluetoothIndicator
            }

            Connections {
                target: bluetoothIndicator
                function onDeviceItemsChanged() { bar.updateBluetoothPopupAnchor() }
                function onWidthChanged() { bar.updateBluetoothPopupAnchor() }
                function onHeightChanged() { bar.updateBluetoothPopupAnchor() }
            }

            WifiPopup {
                id: wifiPopup
                bar: bar
                wifiIndicator: wifiIndicator
            }

            VolumePopup {
                id: volumePopup
                bar: bar
            }

            BrightnessPopup {
                id: brightnessPopup
                bar: bar
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
                updateVolumePopupAnchor()
                updateBrightnessPopupAnchor()
                updateDateWidgetPopupAnchor()
            }
            onHeightChanged: {
                updateBluetoothPopupAnchor()
                updateWifiPopupAnchor()
                updateCpuPopupAnchor()
                updateVolumePopupAnchor()
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
                target: dateTimeIndicator
                function onWidthChanged() { bar.updateDateWidgetPopupAnchor() }
                function onHeightChanged() { bar.updateDateWidgetPopupAnchor() }
            }

            Connections {
                target: volumeIndicator
                function onWidthChanged() { bar.updateVolumePopupAnchor() }
                function onHeightChanged() { bar.updateVolumePopupAnchor() }
            }

            Connections {
                target: batteryIndicator
                function onWidthChanged() { bar.updateBrightnessPopupAnchor() }
                function onHeightChanged() { bar.updateBrightnessPopupAnchor() }
            }

            Connections {
                target: I18n
                function onActiveStringsChanged() { bar.refreshLocalizedState() }
            }

            DateWidgetPopup {
                id: dateWidgetPopup
                bar: bar
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
