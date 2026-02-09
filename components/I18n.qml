pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: i18n

    property string defaultLocale: "ko-KR"
    property string fallbackLocale: "en-US"
    property string locale: defaultLocale
    property var availableLocales: ["ko-KR", "en-US"]
    property var activeStrings: ({})
    property var fallbackStrings: ({})
    property var localeStrings: ({})
    property var pendingLocales: []
    property string loadingLocale: ""

    function normalizeLocale(value) {
        var raw = String(value || "").trim()
        if (raw.length === 0) {
            return defaultLocale
        }
        raw = raw.replace(/_/g, "-")
        for (var i = 0; i < availableLocales.length; i += 1) {
            var exact = availableLocales[i]
            if (exact.toLowerCase() === raw.toLowerCase()) {
                return exact
            }
        }
        var lang = raw.split("-")[0].toLowerCase()
        for (var j = 0; j < availableLocales.length; j += 1) {
            var candidate = availableLocales[j]
            if (candidate.toLowerCase().split("-")[0] === lang) {
                return candidate
            }
        }
        return fallbackLocale
    }

    function localeFileUrl(localeCode) {
        return Qt.resolvedUrl("../i18n/" + localeCode + ".json")
    }

    function localPath(url) {
        var s = String(url || "")
        if (s.indexOf("file://") === 0) {
            return decodeURIComponent(s.slice(7))
        }
        return s
    }

    function shellQuote(text) {
        return "'" + String(text || "").replace(/'/g, "'\\''") + "'"
    }

    function parseJsonObject(text) {
        var raw = (text || "").trim()
        if (raw.length === 0) {
            return {}
        }
        try {
            var obj = JSON.parse(raw)
            return obj && typeof obj === "object" ? obj : {}
        } catch (e) {
            return {}
        }
    }

    function mergeStrings() {
        var next = {}
        var k = ""
        for (k in fallbackStrings) {
            if (Object.prototype.hasOwnProperty.call(fallbackStrings, k)) {
                next[k] = String(fallbackStrings[k])
            }
        }
        for (k in localeStrings) {
            if (Object.prototype.hasOwnProperty.call(localeStrings, k)) {
                next[k] = String(localeStrings[k])
            }
        }
        activeStrings = next
    }

    function queueLocales() {
        var normalized = normalizeLocale(locale)
        var queue = [fallbackLocale]
        if (normalized !== fallbackLocale) {
            queue.push(normalized)
        }
        pendingLocales = queue
        fallbackStrings = {}
        localeStrings = {}
        loadNext()
    }

    function loadNext() {
        if (!pendingLocales || pendingLocales.length === 0) {
            mergeStrings()
            return
        }
        loadingLocale = pendingLocales[0]
        pendingLocales = pendingLocales.slice(1)

        var path = localPath(localeFileUrl(loadingLocale))
        loadProc.command = [
            "sh", "-c",
            "if [ -f " + shellQuote(path) + " ]; then cat " + shellQuote(path) + "; else printf '{}' ; fi"
        ]
        loadProc.running = true
    }

    function setLocale(nextLocale) {
        var normalized = normalizeLocale(nextLocale)
        if (locale === normalized) {
            queueLocales()
            return
        }
        locale = normalized
    }

    function t(key, params) {
        var raw = activeStrings[key]
        var value = raw !== undefined ? String(raw) : String(key)
        if (!params) {
            return value
        }
        return value.replace(/\{([a-zA-Z0-9_]+)\}/g, function(_, name) {
            return params[name] !== undefined ? String(params[name]) : ""
        })
    }

    onLocaleChanged: queueLocales()
    Component.onCompleted: queueLocales()

    Process {
        id: loadProc
        command: ["sh", "-c", "printf '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = i18n.parseJsonObject(this.text)
                if (i18n.loadingLocale === i18n.fallbackLocale) {
                    i18n.fallbackStrings = parsed
                } else if (i18n.loadingLocale === i18n.locale) {
                    i18n.localeStrings = parsed
                }
                i18n.loadNext()
            }
        }
    }
}
