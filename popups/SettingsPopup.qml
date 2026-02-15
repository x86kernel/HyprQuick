import QtQuick
import Quickshell
import Quickshell.Io
import "../components"

PanelWindow {
    id: root
    property var bar
    property bool open: false
    property real anim: open ? 1 : 0
    property bool resetConfirmOpen: false
    property bool saveNoticeOpen: false
    property string activeTab: "general"
    property var draftSettings: ({})
    property bool saveValidationRunning: false
    property string saveValidationError: ""
    property bool pendingWeatherValidation: false
    property bool pendingHolidayValidation: false
    property var pendingSaveSettings: ({})
    property var systemFontFamilies: []
    property bool fontsLoaded: false
    property bool uiFontDropdownOpen: false
    property bool iconFontDropdownOpen: false
    property string uiFontSearchText: ""
    property string iconFontSearchText: ""
    property var uiFontFilteredFamilies: []
    property var iconFontFilteredFamilies: []

    property var blockDefinitions: [
        { key: "workspace" },
        { key: "focusedWindow" },
        { key: "media" },
        { key: "vpn" },
        { key: "clock" },
        { key: "screenCapture" },
        { key: "systemTray" },
        { key: "volume" },
        { key: "clipboard" },
        { key: "cpu" },
        { key: "memory" },
        { key: "bluetooth" },
        { key: "wifi" },
        { key: "battery" },
        { key: "notifications" }
    ]

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

    function tr(key, fallbackText) {
        var v = I18n.t(key)
        return v === key ? fallbackText : v
    }

    function draftGet(path, fallbackValue) {
        var parts = String(path || "").split(".")
        var cur = draftSettings
        for (var i = 0; i < parts.length; i += 1) {
            if (!cur || cur[parts[i]] === undefined) {
                return fallbackValue
            }
            cur = cur[parts[i]]
        }
        return cur
    }

    function draftSet(path, value) {
        saveValidationError = ""
        var next = deepCopy(draftSettings)
        var parts = String(path || "").split(".")
        if (parts.length === 0) {
            return
        }
        var cursor = next
        for (var i = 0; i < parts.length - 1; i += 1) {
            if (!cursor[parts[i]] || typeof cursor[parts[i]] !== "object") {
                cursor[parts[i]] = {}
            }
            cursor = cursor[parts[i]]
        }
        cursor[parts[parts.length - 1]] = value
        draftSettings = bar.normalizedSettings(next)
        syncZoneModelsFromDraft()
    }

    function labelFor(key) {
        if (key === "workspace") return tr("settings.block.workspace", "Workspace")
        if (key === "focusedWindow") return tr("settings.block.focused_window", "Focused Window")
        if (key === "media") return tr("settings.block.media", "Media")
        if (key === "vpn") return tr("settings.block.vpn", "VPN")
        if (key === "clock") return tr("settings.block.clock", "Clock")
        if (key === "screenCapture") return tr("settings.block.capture_record", "Capture/Record")
        if (key === "systemTray") return tr("settings.block.system_tray", "System Tray")
        if (key === "volume") return tr("settings.block.volume", "Volume")
        if (key === "clipboard") return tr("settings.block.clipboard", "Clipboard")
        if (key === "cpu") return tr("settings.block.cpu", "CPU")
        if (key === "memory") return tr("settings.block.memory", "Memory")
        if (key === "bluetooth") return tr("settings.block.bluetooth", "Bluetooth")
        if (key === "wifi") return tr("settings.block.wifi", "WiFi")
        if (key === "battery") return tr("settings.block.battery", "Battery")
        if (key === "notifications") return tr("settings.block.notifications", "Notifications")
        return key
    }

    function zoneLabel(zone) {
        if (zone === "left") return tr("settings.zone.left", "Left")
        if (zone === "center") return tr("settings.zone.center", "Center")
        return tr("settings.zone.right", "Right")
    }

    function loadSystemFontFamilies() {
        var list = []
        try {
            list = Qt.fontFamilies()
        } catch (e) {
            list = []
        }
        var out = []
        var seen = {}
        for (var i = 0; i < (list && list.length !== undefined ? list.length : 0); i += 1) {
            var name = String(list[i] || "").trim()
            if (name.length === 0) {
                continue
            }
            var key = name.toLowerCase()
            if (seen[key]) {
                continue
            }
            seen[key] = true
            out.push(name)
        }
        if (out.length === 0) {
            out.push(String(Theme.fontFamily || "Sans Serif"))
            if (String(Theme.iconFontFamily || "").length > 0 && Theme.iconFontFamily !== Theme.fontFamily) {
                out.push(String(Theme.iconFontFamily))
            }
        }
        out.sort(function(a, b) { return a.localeCompare(b) })
        systemFontFamilies = out
        fontsLoaded = true
        refreshFontFilters()
    }

    function ensureFontFamiliesLoaded() {
        if (fontsLoaded || fontLoadTimer.running) {
            return
        }
        fontLoadTimer.start()
    }

    function filterFontFamilies(searchText) {
        var q = String(searchText || "").trim().toLowerCase()
        var out = []
        for (var i = 0; i < systemFontFamilies.length; i += 1) {
            var name = String(systemFontFamilies[i] || "")
            if (q.length === 0 || name.toLowerCase().indexOf(q) !== -1) {
                out.push(name)
            }
        }
        return out
    }

    function refreshFontFilters() {
        uiFontFilteredFamilies = filterFontFamilies(uiFontSearchText)
        iconFontFilteredFamilies = filterFontFamilies(iconFontSearchText)
    }

    function syncFontSearchWithDraft() {
        uiFontSearchText = String(draftGet("theme.font.family", Theme.fontFamily))
        iconFontSearchText = String(draftGet("theme.font.iconFamily", Theme.iconFontFamily))
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
        var usedLeft = zoneUsedModel("left")
        var usedCenter = zoneUsedModel("center")
        var usedRight = zoneUsedModel("right")
        var unused = zoneUnusedModel(zone)
        unused.clear()
        for (var i = 0; i < blockDefinitions.length; i += 1) {
            var key = blockDefinitions[i].key
            if (!modelHasKey(usedLeft, key) && !modelHasKey(usedCenter, key) && !modelHasKey(usedRight, key)) {
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

    function removeFromModel(model, key) {
        for (var i = 0; i < model.count; i += 1) {
            if (model.get(i).key === key) {
                model.remove(i)
                return true
            }
        }
        return false
    }

    function removeKeyFromAllUsed(key) {
        removeFromModel(leftUsedModel, key)
        removeFromModel(centerUsedModel, key)
        removeFromModel(rightUsedModel, key)
    }

    function toggleZoneBlock(zone, key) {
        var used = zoneUsedModel(zone)
        if (removeFromModel(used, key)) {
            syncDraftFromUsedModels()
            return
        }
        removeKeyFromAllUsed(key)
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
        syncFontSearchWithDraft()
    }

    function requestReset() {
        resetConfirmOpen = true
    }

    function confirmReset() {
        ensureDraft()
        resetConfirmOpen = false
    }

    function weatherLangForLocale(localeCode) {
        var normalized = String(localeCode || "en-US").trim().toLowerCase()
        if (normalized.indexOf("ko") === 0) return "ko"
        if (normalized.indexOf("ja") === 0) return "ja"
        if (normalized.indexOf("zh") === 0) return "zh"
        return "en"
    }

    function buildWeatherValidationCommand(settings) {
        var weather = (settings && settings.integrations && settings.integrations.weather) ? settings.integrations.weather : {}
        var general = (settings && settings.general) ? settings.general : {}
        var apiKey = String(weather.apiKey || "").trim()
        if (apiKey.length === 0) {
            return "printf '__QSERR__ missing:weatherapi-key\\n'"
        }
        var location = String(weather.location || "").trim()
        if (location.length === 0) {
            location = "auto:ip"
        }
        var weatherLang = weatherLangForLocale(general.locale || "en-US")
        var url = "https://api.weatherapi.com/v1/current.json?key="
            + encodeURIComponent(apiKey)
            + "&q=" + encodeURIComponent(location)
            + "&lang=" + encodeURIComponent(weatherLang)
            + "&aqi=no"
        return "if command -v curl >/dev/null 2>&1; then curl -sS --max-time 8 '" + url + "'; " +
            "elif command -v wget >/dev/null 2>&1; then wget -qO- '" + url + "'; " +
            "else printf '__QSERR__ missing:curl-or-wget\\n'; fi"
    }

    function buildHolidayValidationCommand(settings) {
        var holidays = (settings && settings.integrations && settings.integrations.holidays) ? settings.integrations.holidays : {}
        var countryCode = String(holidays.countryCode || "KR").trim().toUpperCase()
        if (countryCode.length === 0) {
            countryCode = "KR"
        }
        var year = new Date().getFullYear()
        var url = "https://date.nager.at/api/v3/PublicHolidays/" + String(year) + "/" + countryCode
        return "if command -v curl >/dev/null 2>&1; then curl -sS --max-time 8 '" + url + "'; " +
            "elif command -v wget >/dev/null 2>&1; then wget -qO- '" + url + "'; " +
            "else printf '__QSERR__ missing:curl-or-wget\\n'; fi"
    }

    function parseWeatherValidationError(rawText) {
        var text = String(rawText || "").trim()
        if (text.length === 0) {
            return tr("settings.error.weather_empty", "Weather validation failed: empty response.")
        }
        if (text.indexOf("__QSERR__") === 0) {
            return tr("settings.error.weather_prefix", "Weather validation failed:")
                + " " + text.replace("__QSERR__", "").trim()
        }
        var payload = null
        try {
            payload = JSON.parse(text)
        } catch (e) {
            return tr("settings.error.weather_invalid_response", "Weather validation failed: invalid response.")
        }
        if (!payload || typeof payload !== "object") {
            return tr("settings.error.weather_invalid_payload", "Weather validation failed: invalid payload.")
        }
        if (payload.error) {
            return tr("settings.error.weather_prefix", "Weather validation failed:")
                + " " + String(payload.error.message || tr("settings.error.unknown", "unknown error"))
        }
        if (!payload.location || !payload.current) {
            return tr("settings.error.weather_incomplete_payload", "Weather validation failed: incomplete payload.")
        }
        return ""
    }

    function parseHolidayValidationError(rawText) {
        var text = String(rawText || "").trim()
        if (text.length === 0) {
            return tr("settings.error.holiday_empty", "Holiday validation failed: empty response.")
        }
        if (text.indexOf("__QSERR__") === 0) {
            return tr("settings.error.holiday_prefix", "Holiday validation failed:")
                + " " + text.replace("__QSERR__", "").trim()
        }
        var payload = null
        try {
            payload = JSON.parse(text)
        } catch (e) {
            return tr("settings.error.holiday_invalid_response", "Holiday validation failed: invalid response.")
        }
        if (Array.isArray(payload)) {
            return ""
        }
        if (payload && payload.message) {
            return tr("settings.error.holiday_prefix", "Holiday validation failed:")
                + " " + String(payload.message)
        }
        return tr("settings.error.holiday_invalid_country", "Holiday validation failed: invalid country code or API response.")
    }

    function syncGeneralInputsToDraft() {
        draftSet("integrations.weather.apiKey", weatherApiInput.text)
        draftSet("integrations.weather.location", weatherLocationInput.text)
        draftSet("integrations.holidays.countryCode", holidayCodeInput.text)
    }

    function finishSave() {
        if (!bar) {
            return
        }
        bar.replaceSettings(pendingSaveSettings)
        saveNoticeOpen = true
        saveNoticeTimer.restart()
        saveValidationRunning = false
    }

    function runNextValidation() {
        if (pendingWeatherValidation) {
            pendingWeatherValidation = false
            weatherValidationProc.command = ["sh", "-c", buildWeatherValidationCommand(pendingSaveSettings)]
            weatherValidationProc.running = true
            return
        }
        if (pendingHolidayValidation) {
            pendingHolidayValidation = false
            holidayValidationProc.command = ["sh", "-c", buildHolidayValidationCommand(pendingSaveSettings)]
            holidayValidationProc.running = true
            return
        }
        finishSave()
    }

    function saveSettings() {
        if (!bar || saveValidationRunning) {
            return
        }
        syncGeneralInputsToDraft()
        var current = bar.normalizedSettings(bar.appSettings || bar.defaultSettings())
        var next = bar.normalizedSettings(draftSettings || {})
        pendingSaveSettings = next
        saveValidationError = ""

        var currentWeather = (current.integrations && current.integrations.weather) ? current.integrations.weather : {}
        var nextWeather = (next.integrations && next.integrations.weather) ? next.integrations.weather : {}
        var currentHolidays = (current.integrations && current.integrations.holidays) ? current.integrations.holidays : {}
        var nextHolidays = (next.integrations && next.integrations.holidays) ? next.integrations.holidays : {}

        var weatherChanged = String(nextWeather.apiKey || "") !== String(currentWeather.apiKey || "")
            || String(nextWeather.location || "") !== String(currentWeather.location || "")
        pendingWeatherValidation = weatherChanged && String(nextWeather.apiKey || "").trim().length > 0

        var nextHolidayCode = String(nextHolidays.countryCode || "KR").trim().toUpperCase()
        var currentHolidayCode = String(currentHolidays.countryCode || "KR").trim().toUpperCase()
        pendingHolidayValidation = nextHolidayCode !== currentHolidayCode

        if (!pendingWeatherValidation && !pendingHolidayValidation) {
            finishSave()
            return
        }

        saveValidationRunning = true
        runNextValidation()
    }

    onOpenChanged: {
        if (open) {
            ensureDraft()
        } else {
            resetConfirmOpen = false
            saveNoticeOpen = false
            saveValidationRunning = false
            saveValidationError = ""
            uiFontDropdownOpen = false
            iconFontDropdownOpen = false
            uiFontSearchText = ""
            iconFontSearchText = ""
        }
    }

    onActiveTabChanged: {
        if (activeTab === "theme") {
            ensureFontFamiliesLoaded()
            syncFontSearchWithDraft()
            return
        }
        uiFontDropdownOpen = false
        iconFontDropdownOpen = false
    }

    onUiFontSearchTextChanged: refreshFontFilters()
    onIconFontSearchTextChanged: refreshFontFilters()

    Timer {
        id: saveNoticeTimer
        interval: 1600
        running: false
        repeat: false
        onTriggered: root.saveNoticeOpen = false
    }

    Timer {
        id: fontLoadTimer
        interval: 1
        running: false
        repeat: false
        onTriggered: root.loadSystemFontFamilies()
    }

    Process {
        id: weatherValidationProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.saveValidationRunning) {
                    return
                }
                var err = root.parseWeatherValidationError(this.text)
                if (err.length > 0) {
                    root.saveValidationRunning = false
                    root.saveValidationError = err
                    return
                }
                root.runNextValidation()
            }
        }
    }

    Process {
        id: holidayValidationProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.saveValidationRunning) {
                    return
                }
                var err = root.parseHolidayValidationError(this.text)
                if (err.length > 0) {
                    root.saveValidationRunning = false
                    root.saveValidationError = err
                    return
                }
                root.runNextValidation()
            }
        }
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
            text: root.tr("settings.title", "Settings")
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.controllerFontSize
            font.weight: Theme.fontWeight
        }

        Row {
            id: tabRow
            anchors.left: parent.left
            anchors.top: titleText.bottom
            anchors.leftMargin: 14
            anchors.topMargin: 8
            spacing: 8

            Rectangle {
                width: 86
                height: 30
                radius: 8
                color: root.activeTab === "general" ? Theme.accent : Theme.blockBg
                border.width: 1
                border.color: Theme.blockBorder
                Text {
                    anchors.centerIn: parent
                    text: root.tr("settings.tab.general", "General")
                    color: root.activeTab === "general" ? Theme.textOnAccent : Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeight
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = "general"
                }
            }

            Rectangle {
                width: 86
                height: 30
                radius: 8
                color: root.activeTab === "blocks" ? Theme.accent : Theme.blockBg
                border.width: 1
                border.color: Theme.blockBorder
                Text {
                    anchors.centerIn: parent
                    text: root.tr("settings.tab.blocks", "Blocks")
                    color: root.activeTab === "blocks" ? Theme.textOnAccent : Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeight
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = "blocks"
                }
            }

            Rectangle {
                width: 86
                height: 30
                radius: 8
                color: root.activeTab === "theme" ? Theme.accent : Theme.blockBg
                border.width: 1
                border.color: Theme.blockBorder
                Text {
                    anchors.centerIn: parent
                    text: root.tr("settings.tab.theme", "Theme")
                    color: root.activeTab === "theme" ? Theme.textOnAccent : Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeight
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = "theme"
                }
            }
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
                    text: root.tr("settings.button.reset", "Reset")
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
                    text: root.tr("settings.button.close", "Close")
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
                    text: root.saveValidationRunning
                        ? root.tr("settings.button.validating", "Validating...")
                        : root.tr("settings.button.save", "Save")
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Theme.fontWeight
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.saveValidationRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.saveSettings()
                }
            }
        }

        Text {
            visible: root.saveValidationError.length > 0
            anchors.left: parent.left
            anchors.right: actionRow.left
            anchors.bottom: actionRow.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            text: root.saveValidationError
            color: "#ff8fa3"
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeight
        }

        Flickable {
            id: scroll
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabRow.bottom
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

                Rectangle {
                    visible: root.activeTab === "general"
                    width: parent.width
                    radius: Theme.blockRadius
                    color: Theme.blockBg
                    border.width: 1
                    border.color: Theme.blockBorder
                    implicitHeight: generalColumn.implicitHeight + 14

                    Column {
                        id: generalColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 7
                        spacing: 10

                        Text {
                            text: root.tr("settings.general.title", "General")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Theme.fontWeight
                        }

                        Text {
                            text: root.tr("settings.general.locale", "Locale")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Row {
                            spacing: 6
                            Repeater {
                                model: ["ko-KR", "en-US"]
                                delegate: Rectangle {
                                    width: 76
                                    height: 28
                                    radius: 7
                                    color: String(root.draftGet("general.locale", "ko-KR")) === modelData ? Theme.accent : Theme.accentAlt
                                    border.width: 1
                                    border.color: Theme.blockBorder
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: Theme.textOnAccent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeight
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.draftSet("general.locale", modelData)
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.tr("settings.general.weather_api_key", "Weather API Key")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            width: generalColumn.width
                            height: 34
                            radius: 8
                            color: "#1f2133"
                            border.width: 1
                            border.color: weatherApiInput.activeFocus ? "#8c79b3" : "#3a3f63"
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                            TextInput {
                                id: weatherApiInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: String(root.draftGet("integrations.weather.apiKey", ""))
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                selectionColor: "#8c79b355"
                                selectedTextColor: Theme.textOnAccent
                                verticalAlignment: TextInput.AlignVCenter
                                onTextEdited: root.draftSet("integrations.weather.apiKey", text)
                            }
                        }

                        Text {
                            text: root.tr("settings.general.weather_location", "Weather Location")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            width: generalColumn.width
                            height: 34
                            radius: 8
                            color: "#1f2133"
                            border.width: 1
                            border.color: weatherLocationInput.activeFocus ? "#8c79b3" : "#3a3f63"
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                            TextInput {
                                id: weatherLocationInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: String(root.draftGet("integrations.weather.location", "auto:ip"))
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                selectionColor: "#8c79b355"
                                selectedTextColor: Theme.textOnAccent
                                verticalAlignment: TextInput.AlignVCenter
                                onTextEdited: root.draftSet("integrations.weather.location", text)
                            }
                        }

                        Text {
                            text: root.tr("settings.general.holiday_country_code", "Holiday Country Code")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            width: generalColumn.width
                            height: 34
                            radius: 8
                            color: "#1f2133"
                            border.width: 1
                            border.color: holidayCodeInput.activeFocus ? "#8c79b3" : "#3a3f63"
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                            TextInput {
                                id: holidayCodeInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: String(root.draftGet("integrations.holidays.countryCode", "KR"))
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                selectionColor: "#8c79b355"
                                selectedTextColor: Theme.textOnAccent
                                verticalAlignment: TextInput.AlignVCenter
                                onTextEdited: root.draftSet("integrations.holidays.countryCode", text)
                            }
                        }
                    }
                }

                Rectangle {
                    id: themePanel
                    visible: root.activeTab === "theme"
                    width: parent.width
                    radius: Theme.blockRadius
                    color: Theme.blockBg
                    border.width: 1
                    border.color: Theme.blockBorder
                    implicitHeight: themeColumn.implicitHeight + 14

                    Column {
                        id: themeColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 7
                        spacing: 10

                        Text {
                            text: root.tr("settings.theme.title", "Theme")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Theme.fontWeight
                        }

                        Text {
                            text: root.tr("settings.theme.font_family", "UI Font Family")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            id: uiFontSelector
                            width: themeColumn.width
                            height: 34
                            radius: 8
                            color: "#1f2133"
                            border.width: 1
                            border.color: Theme.blockBorder
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                            TextInput {
                                id: uiFontInput
                                anchors.left: parent.left
                                anchors.right: dropdownIcon.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                text: root.uiFontSearchText
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                verticalAlignment: TextInput.AlignVCenter
                                onTextEdited: {
                                    root.ensureFontFamiliesLoaded()
                                    root.uiFontSearchText = text
                                    root.uiFontDropdownOpen = true
                                    root.iconFontDropdownOpen = false
                                }
                                onActiveFocusChanged: {
                                    if (activeFocus) {
                                        root.ensureFontFamiliesLoaded()
                                        root.uiFontDropdownOpen = true
                                        root.iconFontDropdownOpen = false
                                    }
                                }
                            }
                            Text {
                                id: dropdownIcon
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 10
                                text: root.uiFontDropdownOpen ? "▴" : "▾"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            MouseArea {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                width: 26
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.ensureFontFamiliesLoaded()
                                    root.uiFontDropdownOpen = !root.uiFontDropdownOpen
                                    if (root.uiFontDropdownOpen) {
                                        root.iconFontDropdownOpen = false
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.tr("settings.theme.icon_font_family", "Icon Font Family")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            id: iconFontSelector
                            width: themeColumn.width
                            height: 34
                            radius: 8
                            color: "#1f2133"
                            border.width: 1
                            border.color: Theme.blockBorder
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                            TextInput {
                                id: iconFontInput
                                anchors.left: parent.left
                                anchors.right: iconDropdownIcon.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                text: root.iconFontSearchText
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                                verticalAlignment: TextInput.AlignVCenter
                                onTextEdited: {
                                    root.ensureFontFamiliesLoaded()
                                    root.iconFontSearchText = text
                                    root.iconFontDropdownOpen = true
                                    root.uiFontDropdownOpen = false
                                }
                                onActiveFocusChanged: {
                                    if (activeFocus) {
                                        root.ensureFontFamiliesLoaded()
                                        root.iconFontDropdownOpen = true
                                        root.uiFontDropdownOpen = false
                                    }
                                }
                            }
                            Text {
                                id: iconDropdownIcon
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 10
                                text: root.iconFontDropdownOpen ? "▴" : "▾"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            MouseArea {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                width: 26
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.ensureFontFamiliesLoaded()
                                    root.iconFontDropdownOpen = !root.iconFontDropdownOpen
                                    if (root.iconFontDropdownOpen) {
                                        root.uiFontDropdownOpen = false
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: 12

                            Column {
                                spacing: 6
                                Text {
                                    text: root.tr("settings.theme.font_size", "Font Size")
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Theme.fontWeight
                                }
                                Rectangle {
                                    width: 96
                                    height: 34
                                    radius: 8
                                    color: "#1f2133"
                                    border.width: 1
                                    border.color: Theme.blockBorder
                                    HoverHandler { cursorShape: Qt.IBeamCursor }
                                    TextInput {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        text: String(root.draftGet("theme.font.size", Theme.fontSize))
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        verticalAlignment: TextInput.AlignVCenter
                                        validator: IntValidator { bottom: 8; top: 48 }
                                        onTextEdited: {
                                            var n = Number(text)
                                            if (!isNaN(n)) {
                                                root.draftSet("theme.font.size", Math.max(8, Math.min(48, Math.round(n))))
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                spacing: 6
                                Text {
                                    text: root.tr("settings.theme.icon_size", "Icon Size")
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Theme.fontWeight
                                }
                                Rectangle {
                                    width: 96
                                    height: 34
                                    radius: 8
                                    color: "#1f2133"
                                    border.width: 1
                                    border.color: Theme.blockBorder
                                    HoverHandler { cursorShape: Qt.IBeamCursor }
                                    TextInput {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        text: String(root.draftGet("theme.font.iconSize", Theme.iconSize))
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        verticalAlignment: TextInput.AlignVCenter
                                        validator: IntValidator { bottom: 8; top: 64 }
                                        onTextEdited: {
                                            var n = Number(text)
                                            if (!isNaN(n)) {
                                                root.draftSet("theme.font.iconSize", Math.max(8, Math.min(64, Math.round(n))))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: themeOverlay
                        anchors.fill: parent
                        z: 40
                        visible: root.activeTab === "theme"

                        Rectangle {
                            visible: root.uiFontDropdownOpen
                            width: uiFontSelector.width
                            height: Math.min(210, Math.max(44, root.uiFontFilteredFamilies.length * 30 + 8))
                            radius: Theme.blockRadius
                            color: "#1f2133"
                            border.width: 1
                            border.color: Theme.blockBorder
                            clip: true
                            z: 2
                            x: uiFontSelector.mapToItem(themeOverlay, 0, 0).x
                            y: uiFontSelector.mapToItem(themeOverlay, 0, uiFontSelector.height + 4).y

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 4
                                contentWidth: width
                                contentHeight: uiFontList.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Column {
                                    id: uiFontList
                                    width: parent.width
                                    spacing: 2

                                    Repeater {
                                        model: root.uiFontFilteredFamilies
                                        delegate: Rectangle {
                                            width: uiFontList.width
                                            height: 28
                                            radius: 6
                                            color: String(root.draftGet("theme.font.family", Theme.fontFamily)) === modelData
                                                ? Theme.accentAlt
                                                : "transparent"
                                            Text {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                text: modelData
                                                color: String(root.draftGet("theme.font.family", Theme.fontFamily)) === modelData
                                                    ? Theme.textOnAccent
                                                    : Theme.textPrimary
                                                elide: Text.ElideRight
                                                font.family: modelData
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Theme.fontWeight
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.draftSet("theme.font.family", modelData)
                                                    root.uiFontSearchText = String(modelData)
                                                    root.uiFontDropdownOpen = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: root.iconFontDropdownOpen
                            width: iconFontSelector.width
                            height: Math.min(180, Math.max(44, root.iconFontFilteredFamilies.length * 30 + 8))
                            radius: Theme.blockRadius
                            color: "#1f2133"
                            border.width: 1
                            border.color: Theme.blockBorder
                            clip: true
                            z: 2
                            x: iconFontSelector.mapToItem(themeOverlay, 0, 0).x
                            y: iconFontSelector.mapToItem(themeOverlay, 0, iconFontSelector.height + 4).y

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 4
                                contentWidth: width
                                contentHeight: iconFontList.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Column {
                                    id: iconFontList
                                    width: parent.width
                                    spacing: 2

                                    Repeater {
                                        model: root.iconFontFilteredFamilies
                                        delegate: Rectangle {
                                            width: iconFontList.width
                                            height: 28
                                            radius: 6
                                            color: String(root.draftGet("theme.font.iconFamily", Theme.iconFontFamily)) === modelData
                                                ? Theme.accentAlt
                                                : "transparent"
                                            Text {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                text: modelData
                                                color: String(root.draftGet("theme.font.iconFamily", Theme.iconFontFamily)) === modelData
                                                    ? Theme.textOnAccent
                                                    : Theme.textPrimary
                                                elide: Text.ElideRight
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Theme.fontWeight
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.draftSet("theme.font.iconFamily", modelData)
                                                    root.iconFontSearchText = String(modelData)
                                                    root.iconFontDropdownOpen = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: root.activeTab === "blocks" ? ["left", "center", "right"] : []
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
                                text: root.zoneLabel(zone) + " " + root.tr("settings.blocks.title_suffix", "Blocks")
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Theme.fontWeight
                            }

                            Text {
                                text: root.tr("settings.blocks.used_hint", "Used (Click: disable, Drag: reorder)")
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
                                        text: root.labelFor(blockKey)
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
                                text: root.tr("settings.blocks.unused_hint", "Unused (Click: enable)")
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
                                            text: root.labelFor(blockKey)
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
                text: root.tr("settings.saved", "Saved!")
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
                        text: root.tr("settings.reset_confirm.title", "Reset this panel?")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Theme.fontWeight
                    }

                    Text {
                        text: root.tr("settings.reset_confirm.body", "Unsaved block layout changes will be discarded.")
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
                                text: root.tr("settings.button.cancel", "Cancel")
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
                                text: root.tr("settings.button.reset", "Reset")
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
