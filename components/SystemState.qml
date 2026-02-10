pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: state

    // Volume
    property int volumePercent: 0
    property int volumePercentRaw: 0
    property bool volumeMuted: false
    property bool volumeAvailable: true

    // Battery / AC
    property int batteryPercent: 0
    property string batteryState: "unknown"
    property bool batteryAvailable: true
    property bool acOnline: false

    // Brightness
    property int brightnessPercent: 0
    property bool brightnessAvailable: true

    // CPU / Memory
    property real cpuUsage: 0
    property real cpuLastTotal: 0
    property real cpuLastIdle: 0
    property string cpuTemperatureText: ""
    property real memoryUsage: 0

    // Media / Clipboard / VPN
    property bool mediaActive: false
    property string mediaDisplayText: ""
    property string clipboardKey: ""
    property bool clipboardHasData: false
    property bool vpnConnected: false
    property string vpnActiveName: ""

    // WiFi / Bluetooth
    property string wifiSsid: ""
    property bool wifiAvailable: true
    property bool wifiRadioOn: true
    property var wifiNetworks: []

    property bool bluetoothPowered: false
    property int bluetoothConnectedCount: 0
    property bool bluetoothAvailable: true
    property var bluetoothDeviceItems: []

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(Number(value) || 0)))
    }

    function shellEscape(value) {
        return "\"" + String(value || "").replace(/\\/g, "\\\\").replace(/\"/g, "\\\"") + "\""
    }

    // Volume
    function parseVolume(text) {
        var out = (text || "").trim()
        if (out.length === 0 || out.indexOf("__QSERR__") !== -1) {
            volumeAvailable = false
            volumeMuted = false
            volumePercent = 0
            volumePercentRaw = 0
            return
        }

        volumeAvailable = true
        var lower = out.toLowerCase()
        volumeMuted = lower.indexOf("muted") !== -1 || /\byes\b/.test(lower)

        var matches = out.match(/([0-9]{1,3})%/g)
        if (matches && matches.length > 0) {
            var pct = Number(matches[matches.length - 1].replace("%", ""))
            if (!isNaN(pct)) {
                volumePercentRaw = Math.max(0, Math.round(pct))
                volumePercent = clampPercent(volumePercentRaw)
                return
            }
        }

        var volMatch = out.match(/volume:\s*([0-9]+(?:\.[0-9]+)?)/i)
        if (volMatch && volMatch[1]) {
            var ratio = Number(volMatch[1])
            if (!isNaN(ratio)) {
                volumePercentRaw = Math.max(0, Math.round(ratio * 100))
                volumePercent = clampPercent(volumePercentRaw)
                return
            }
        }

        volumePercent = 0
        volumePercentRaw = 0
    }

    function refreshVolume() {
        volumeReadProc.running = true
    }

    function setVolumePercent(target) {
        var pct = clampPercent(target)
        volumePercentRaw = pct
        volumePercent = pct
        volumeSetProc.command = ["sh", "-c",
            "if command -v wpctl >/dev/null 2>&1; then " +
            "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + String(pct) + "%; " +
            "elif command -v pactl >/dev/null 2>&1; then " +
            "pactl set-sink-volume @DEFAULT_SINK@ " + String(pct) + "%; fi"]
        volumeSetProc.running = true
    }

    Process {
        id: volumeReadProc
        command: ["sh", "-c", "if command -v wpctl >/dev/null 2>&1; then wpctl get-volume @DEFAULT_AUDIO_SINK@; elif command -v pactl >/dev/null 2>&1; then pactl get-sink-volume @DEFAULT_SINK@ | head -n1; pactl get-sink-mute @DEFAULT_SINK@; else printf '__QSERR__ missing:wpctl-or-pactl\\n'; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseVolume(this.text) }
    }

    Process {
        id: volumeSetProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshVolume() }
    }

    Timer {
        interval: Theme.volumePollInterval
        running: true
        repeat: true
        onTriggered: state.refreshVolume()
    }

    // Battery
    function parseBattery(text) {
        var lines = (text || "").split(/\r?\n/)
        var pct = 0
        var st = "unknown"
        batteryAvailable = true
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.indexOf("percentage:") === 0) {
                pct = Number(line.replace(/[^0-9]/g, ""))
            } else if (line.indexOf("state:") === 0) {
                st = line.split(":")[1].trim()
            } else if (line.indexOf("online:") === 0) {
                acOnline = line.split(":")[1].trim() === "yes"
            } else if (line === "NO_BATTERY") {
                batteryAvailable = false
            }
        }
        if (!batteryAvailable) {
            batteryPercent = 0
            batteryState = "unknown"
            return
        }
        batteryPercent = pct
        batteryState = st
    }

    function refreshBattery() {
        batteryReadProc.running = true
    }

    Process {
        id: batteryReadProc
        command: ["sh", "-c", "b=$(upower -e | grep -m1 BAT); a=$(upower -e | grep -m1 line_power); if [ -z \"$b\" ]; then echo NO_BATTERY; else upower -i \"$b\" | grep -E 'state:|percentage:'; if [ -n \"$a\" ]; then upower -i \"$a\" | grep -E 'online:'; fi; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseBattery(this.text) }
    }

    Timer {
        interval: Theme.batteryPollInterval
        running: true
        repeat: true
        onTriggered: state.refreshBattery()
    }

    // Brightness
    function parseBrightness(text) {
        var out = (text || "").trim()
        if (out.length === 0 || out.indexOf("__QSERR__") !== -1) {
            brightnessAvailable = false
            brightnessPercent = 0
            return
        }
        brightnessAvailable = true
        var match = out.match(/([0-9]{1,3})(?:\.[0-9]+)?%?/) 
        if (match && match[1]) {
            brightnessPercent = clampPercent(match[1])
            return
        }
        brightnessPercent = 0
    }

    function refreshBrightness() {
        brightnessReadProc.running = true
    }

    function setBrightnessPercent(target) {
        var pct = clampPercent(target)
        brightnessPercent = pct
        brightnessSetProc.command = ["sh", "-c",
            "if command -v brightnessctl >/dev/null 2>&1; then " +
            "brightnessctl set " + String(pct) + "%; " +
            "elif command -v light >/dev/null 2>&1; then " +
            "light -S " + String(pct) + "; " +
            "else printf '__QSERR__ missing:brightnessctl-or-light\\n'; fi"]
        brightnessSetProc.running = true
    }

    function adjustBrightnessBy(stepCount) {
        if (!stepCount || stepCount === 0) {
            return
        }
        var step = Math.max(1, Theme.brightnessStepPercent)
        setBrightnessPercent(brightnessPercent + stepCount * step)
    }

    Process {
        id: brightnessReadProc
        command: ["sh", "-c", "if command -v brightnessctl >/dev/null 2>&1; then brightnessctl -m | awk -F, 'NR==1{print $4}'; elif command -v light >/dev/null 2>&1; then light -G | awk '{printf \"%d%%\\n\", $1}'; else printf '__QSERR__ missing:brightnessctl-or-light\\n'; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseBrightness(this.text) }
    }

    Process {
        id: brightnessSetProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshBrightness() }
    }

    Timer {
        interval: Theme.brightnessPollInterval
        running: true
        repeat: true
        onTriggered: state.refreshBrightness()
    }

    // CPU usage and temp
    function parseCpuStat(text) {
        var line = (text || "").trim()
        if (line.length === 0) return
        var parts = line.split(/\s+/)
        if (parts.length < 5 || parts[0] !== "cpu") return

        var total = 0
        for (var i = 1; i < parts.length; i += 1) total += Number(parts[i])
        var idle = Number(parts[4]) + (parts.length > 5 ? Number(parts[5]) : 0)

        if (cpuLastTotal > 0) {
            var deltaTotal = total - cpuLastTotal
            var deltaIdle = idle - cpuLastIdle
            if (deltaTotal > 0) {
                cpuUsage = Math.max(0, Math.min(100, (deltaTotal - deltaIdle) / deltaTotal * 100))
            }
        }

        cpuLastTotal = total
        cpuLastIdle = idle
    }

    function parseSensors(text) {
        var lines = (text || "").split(/\r?\n/)
        var temps = []
        var packageLine = ""
        var coreLine = ""

        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.length === 0) continue
            if (!/[+-]?[0-9.]+\s*°?C/.test(line)) continue
            temps.push(line)
            if (packageLine.length === 0 && line.indexOf("Package id 0:") === 0) packageLine = line
            if (coreLine.length === 0 && line.indexOf("Core 0:") === 0) coreLine = line
        }

        function extractTemp(line) {
            var m = line.match(/[+-]?[0-9.]+\s*°?C/)
            return m && m[0] ? m[0].replace(/\s+/g, "") : ""
        }

        if (temps.length === 0) {
            cpuTemperatureText = I18n.t("cpu.temp_na")
            return
        }
        if (packageLine.length > 0) {
            cpuTemperatureText = extractTemp(packageLine)
            return
        }
        if (coreLine.length > 0) {
            cpuTemperatureText = extractTemp(coreLine)
            return
        }
        cpuTemperatureText = extractTemp(temps[0])
    }

    function refreshCpu() { cpuReadProc.running = true }
    function refreshCpuTemp() { cpuTempProc.running = true }

    Process {
        id: cpuReadProc
        command: ["sh", "-c", "grep '^cpu ' /proc/stat"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseCpuStat(this.text) }
    }

    Process {
        id: cpuTempProc
        command: ["sh", "-c", "sensors"]
        running: false
        stdout: StdioCollector { onStreamFinished: state.parseSensors(this.text) }
    }

    Timer {
        interval: Theme.cpuPollInterval
        running: true
        repeat: true
        onTriggered: state.refreshCpu()
    }

    Timer {
        interval: Theme.cpuTooltipPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: state.refreshCpuTemp()
    }

    // Memory
    function parseMeminfo(text) {
        var lines = (text || "").split(/\r?\n/)
        var total = 0
        var availableMem = 0
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i]
            if (line.indexOf("MemTotal:") === 0) {
                total = Number(line.replace(/[^0-9]/g, ""))
            } else if (line.indexOf("MemAvailable:") === 0) {
                availableMem = Number(line.replace(/[^0-9]/g, ""))
            }
        }
        if (total > 0) {
            memoryUsage = Math.max(0, Math.min(100, (total - availableMem) / total * 100))
        }
    }

    function refreshMemory() { memReadProc.running = true }

    Process {
        id: memReadProc
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseMeminfo(this.text) }
    }

    Timer {
        interval: Theme.memPollInterval
        running: true
        repeat: true
        onTriggered: state.refreshMemory()
    }

    // Media
    function parseMedia(text) {
        var lines = (text || "").split(/\r?\n/)
        var chosen = ""
        var fallback = ""
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.length === 0) continue
            if (line.indexOf("Playing|") === 0) {
                chosen = line
                break
            }
            if (fallback.length === 0 && line.indexOf("Paused|") === 0) {
                fallback = line
            }
        }
        if (chosen.length === 0) chosen = fallback
        if (chosen.length === 0) {
            mediaActive = false
            mediaDisplayText = ""
            return
        }

        var parts = chosen.split("|")
        var title = parts.length > 2 ? parts[2] : ""
        var artist = parts.length > 3 ? parts[3] : ""
        var textOut = title
        if (artist && title) textOut = artist + " - " + title
        else if (artist) textOut = artist

        mediaActive = textOut.length > 0
        mediaDisplayText = textOut
    }

    function refreshMedia() { mediaReadProc.running = true }

    Process {
        id: mediaReadProc
        command: ["sh", "-c", "playerctl -a metadata --format '{{status}}|{{playerName}}|{{title}}|{{artist}}' 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseMedia(this.text) }
    }

    Timer {
        interval: Theme.mediaPollInterval
        running: true
        repeat: true
        onTriggered: state.refreshMedia()
    }

    // Clipboard
    function parseClipboard(text) {
        var key = String(text || "").trim()
        clipboardKey = key
        clipboardHasData = key.length > 0
    }

    function refreshClipboard() { clipboardReadProc.running = true }

    Process {
        id: clipboardReadProc
        command: ["sh", "-c", "cliphist list | head -n 1"]
        running: false
        stdout: StdioCollector { onStreamFinished: state.parseClipboard(this.text) }
    }

    Timer {
        interval: Theme.clipboardPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: state.refreshClipboard()
    }

    // VPN
    function parseVpn(text) {
        var line = String(text || "").trim()
        vpnConnected = line.length > 0
        vpnActiveName = line
    }

    function refreshVpn() { vpnReadProc.running = true }

    Process {
        id: vpnReadProc
        command: ["sh", "-c", "if ! command -v nmcli >/dev/null 2>&1; then exit 0; fi; nmcli -t -f TYPE,NAME connection show --active | awk -F: '$1==\"vpn\" || $1==\"wireguard\" {print $2; exit}'"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseVpn(this.text) }
    }

    Timer {
        interval: Theme.vpnPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: state.refreshVpn()
    }

    // WiFi
    function parseWifiSsid(text) {
        var line = String(text || "").trim()
        if (line.length === 0) {
            wifiSsid = ""
            wifiAvailable = false
            return
        }
        wifiAvailable = true
        wifiSsid = line
    }

    function parseWifiRadio(text) {
        var t = String(text || "").trim()
        wifiRadioOn = t === "enabled" || t === "yes" || t === "on"
    }

    function parseWifiNetworks(text) {
        var lines = String(text || "").split(/\r?\n/)
        var list = []
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.length === 0) continue
            var parts = line.split(":")
            if (parts.length < 4) continue
            var active = parts[0] === "yes"
            var ssidValue = parts[1]
            var securityValue = parts[2]
            var signal = Number(parts[3])
            if (ssidValue.length === 0) continue
            var secure = securityValue.length > 0 && securityValue !== "--"
            list.push({
                active: active,
                ssid: ssidValue,
                security: securityValue,
                signal: signal,
                secure: secure
            })
        }
        list.sort(function(a, b) {
            if (a.active !== b.active) return a.active ? -1 : 1
            if (a.signal === b.signal) return 0
            return a.signal > b.signal ? -1 : 1
        })
        wifiNetworks = list
    }

    function refreshWifi() {
        wifiReadProc.running = true
        wifiListProc.running = true
        wifiRadioProc.running = true
    }

    function scanWifiNow() {
        wifiRescanProc.command = ["sh", "-c", "nmcli dev wifi rescan"]
        wifiRescanProc.running = true
    }

    function connectWifi(ssidValue, passwordValue, securityValue) {
        if (!ssidValue || ssidValue.length === 0) {
            return
        }
        var cmd = "nmcli dev wifi connect " + shellEscape(ssidValue)
        if (passwordValue && passwordValue.length > 0) cmd += " password " + shellEscape(passwordValue)
        if (securityValue && securityValue.length > 0) cmd += " wifi-sec.key-mgmt " + shellEscape(securityValue)
        wifiConnectProc.command = ["sh", "-c", cmd]
        wifiConnectProc.running = true
    }

    function disconnectWifiNow() {
        wifiDisconnectProc.command = ["sh", "-c", "nmcli networking off; nmcli networking on"]
        wifiDisconnectProc.running = true
    }

    function disconnectWifiActive() {
        wifiDisconnectProc.command = ["sh", "-c", "nmcli dev disconnect $(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2==\"wifi\" && $3==\"connected\" {print $1; exit}')"]
        wifiDisconnectProc.running = true
    }

    function setWifiPower(on) {
        wifiToggleProc.command = ["sh", "-c", on ? "nmcli radio wifi on" : "nmcli radio wifi off"]
        wifiToggleProc.running = true
    }

    Process {
        id: wifiReadProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' | head -n 1 | cut -d: -f2-"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseWifiSsid(this.text) }
    }

    Process {
        id: wifiListProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SECURITY,SIGNAL dev wifi list"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseWifiNetworks(this.text) }
    }

    Process {
        id: wifiRadioProc
        command: ["sh", "-c", "nmcli -t -f WIFI general status | cut -d: -f2"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseWifiRadio(this.text) }
    }

    Process {
        id: wifiRescanProc
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshWifi() }
    }

    Process {
        id: wifiConnectProc
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshWifi() }
    }

    Process {
        id: wifiDisconnectProc
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshWifi() }
    }

    Process {
        id: wifiToggleProc
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshWifi() }
    }

    Timer {
        interval: Theme.wifiPollInterval
        running: true
        repeat: true
        onTriggered: state.refreshWifi()
    }

    // Bluetooth
    function parseBluetooth(text) {
        var trimmed = String(text || "").trim()
        if (trimmed.length === 0) {
            bluetoothAvailable = false
            bluetoothPowered = false
            bluetoothConnectedCount = 0
            bluetoothDeviceItems = []
            return
        }

        bluetoothAvailable = true
        var lines = trimmed.split(/\r?\n/)
        var pow = false
        var count = 0
        var names = []
        var all = []
        var mode = ""

        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line === "__CONNECTED__") {
                mode = "connected"
                continue
            }
            if (line === "__ALL__") {
                mode = "all"
                continue
            }
            if (line.indexOf("Powered:") === 0) {
                pow = line.indexOf("yes") !== -1
            } else if (line.indexOf("Device ") === 0) {
                var parts = line.split(" ")
                if (parts.length >= 3) {
                    var mac = parts[1]
                    var name = parts.slice(2).join(" ")
                    if (mode === "connected") {
                        count += 1
                        names.push({ mac: mac, name: name, connected: true })
                    } else if (mode === "all") {
                        all.push({ mac: mac, name: name, connected: false })
                    }
                }
            }
        }

        bluetoothPowered = pow
        bluetoothConnectedCount = count

        var connectedMacs = {}
        for (var c = 0; c < names.length; c += 1) connectedMacs[names[c].mac] = true

        var filtered = all.filter(function(d) {
            if (connectedMacs[d.mac]) return false
            for (var n = 0; n < names.length; n += 1) {
                if (names[n].name === d.name) return false
            }
            return true
        })

        bluetoothDeviceItems = names.concat(filtered)
    }

    function refreshBluetooth() { bluetoothReadProc.running = true }

    function setBluetoothPower(on) {
        bluetoothPowerProc.command = ["sh", "-c", on ? "bluetoothctl power on" : "bluetoothctl power off"]
        bluetoothPowerProc.running = true
    }

    function pairBluetoothDevice(mac) {
        if (!mac || mac.length === 0) return
        bluetoothPairProc.command = ["sh", "-c", "bluetoothctl pair " + mac]
        bluetoothPairProc.running = true
    }

    function connectBluetoothDevice(mac) {
        if (!mac || mac.length === 0) return
        bluetoothConnectProc.command = ["sh", "-c", "bluetoothctl connect " + mac]
        bluetoothConnectProc.running = true
    }

    function disconnectBluetoothDevice(mac) {
        if (!mac || mac.length === 0) return
        bluetoothDeviceProc.command = ["sh", "-c", "bluetoothctl disconnect " + mac]
        bluetoothDeviceProc.running = true
    }

    function scanBluetoothNow() {
        bluetoothScanProc.command = ["sh", "-c", "bluetoothctl scan on; sleep 4; bluetoothctl scan off"]
        bluetoothScanProc.running = true
    }

    Process {
        id: bluetoothReadProc
        command: ["sh", "-c", "bluetoothctl show; echo __CONNECTED__; bluetoothctl devices Connected; echo __ALL__; bluetoothctl devices"]
        running: true
        stdout: StdioCollector { onStreamFinished: state.parseBluetooth(this.text) }
    }

    Process {
        id: bluetoothPowerProc
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshBluetooth() }
    }

    Process {
        id: bluetoothDeviceProc
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshBluetooth() }
    }

    Process {
        id: bluetoothPairProc
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshBluetooth() }
    }

    Process {
        id: bluetoothConnectProc
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshBluetooth() }
    }

    Process {
        id: bluetoothScanProc
        running: false
        stdout: StdioCollector { onStreamFinished: state.refreshBluetooth() }
    }

    Timer {
        interval: Theme.bluetoothPollInterval
        running: true
        repeat: true
        onTriggered: state.refreshBluetooth()
    }

    // Settings / Calendar / Weather / Holiday
    property bool initialized: false
    property var appSettings: defaultSettings()
    property string settingsFileUrl: Qt.resolvedUrl("../settings.json")
    property string settingsFilePath: settingsFileUrl.indexOf("file://") === 0
        ? decodeURIComponent(settingsFileUrl.slice(7))
        : settingsFileUrl

    property var holidayMap: ({})
    property string holidayLoadedKey: ""

    property var calendarMonthDate: normalizedMonthDate(new Date())
    property var calendarCells: []
    property var calendarDayNames: localizedDayNames()

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

    function tr(key, fallbackText) {
        var v = I18n.t(key)
        return v === key ? fallbackText : v
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
                locale: I18n.normalizeLocale(general.locale !== undefined ? general.locale : (next.locale !== undefined ? next.locale : defaults.general.locale))
            },
            integrations: {
                weather: {
                    apiKey: String(weather.apiKey !== undefined ? weather.apiKey : (next.weatherApiKey !== undefined ? next.weatherApiKey : defaults.integrations.weather.apiKey)),
                    location: String(weather.location !== undefined ? weather.location : (next.weatherLocation !== undefined ? next.weatherLocation : defaults.integrations.weather.location))
                },
                holidays: {
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

    function shellQuote(text) {
        return "'" + (text || "").replace(/'/g, "'\\''") + "'"
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

    function isoDateKey(year, month, day) {
        function pad2(v) {
            return v < 10 ? "0" + v : String(v)
        }
        return String(year) + "-" + pad2(month) + "-" + pad2(day)
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

    function initialize() {
        if (initialized) {
            return
        }
        initialized = true
        applyRuntimeSettings()
        loadSettings()
        resetCalendarToCurrentMonth()
    }

    Process {
        id: settingsReadProc
        property string commandText: ""
        command: ["sh", "-c", commandText]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                state.applySettingsText(this.text)
                state.saveSettings()
                state.applyRuntimeSettings()
                state.holidayLoadedKey = ""
                state.ensureHolidayYear(state.calendarMonthDate.getFullYear())
                state.refreshWeather(true)
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
        command: ["sh", "-c", state.buildWeatherCommand()]
        running: false
        stdout: StdioCollector {
            onStreamFinished: state.parseWeatherOutput(this.text)
        }
    }

    Process {
        id: holidayProc
        property int requestYear: 0
        property string requestCountry: "KR"
        running: false
        stdout: StdioCollector {
            onStreamFinished: state.parseHolidayOutput(this.text, holidayProc.requestYear, holidayProc.requestCountry)
        }
    }

    Timer {
        interval: Theme.weatherPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: state.refreshWeather(false)
    }

    Connections {
        target: I18n
        function onActiveStringsChanged() {
            state.refreshLocalizedState()
        }
    }
}
