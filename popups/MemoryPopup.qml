import QtQuick
import Quickshell
import Quickshell.Io
import "../components"

PopupWindow {
    id: root
    property var bar
    property var memoryUsageIndicator
    property var i18nStrings: I18n.activeStrings
    property int topProcessLimit: 15
    property int pidColumnWidth: 52
    property int rssColumnWidth: 84
    property string fetchError: ""
    function tr(key, fallbackText) {
        var _unused = root.i18nStrings
        var v = I18n.t(key)
        return v === key ? fallbackText : v
    }

    implicitWidth: Theme.memoryPopupWidth
    implicitHeight: Math.max(1, memoryBox.implicitHeight)
    property bool open: false
    property real anim: open ? 1 : 0
    visible: open || anim > 0.01
    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    color: "transparent"
    anchor.window: bar

    function formatBytesFromKiB(kib) {
        var n = Math.max(0, Number(kib) || 0) * 1024
        var units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var i = 0
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024
            i += 1
        }
        var precision = (i >= 2) ? 1 : 0
        return n.toFixed(precision) + " " + units[i]
    }

    function parseTopProcessList(raw) {
        processListModel.clear()
        var text = String(raw || "").trim()
        if (text.length === 0) {
            fetchError = tr("memory.no_process_data", "No process data")
            return
        }
        var lines = text.split(/\r?\n/)
        for (var i = 0; i < lines.length; i += 1) {
            var line = String(lines[i] || "").trim()
            if (line.length === 0) {
                continue
            }
            var parts = line.split("\t")
            if (parts.length < 3) {
                continue
            }
            processListModel.append({
                pid: parseInt(parts[0], 10) || 0,
                name: parts[1] || "-",
                rssKiB: parseInt(parts[2], 10) || 0
            })
        }
        fetchError = processListModel.count > 0 ? "" : tr("memory.unexpected_ps_output", "Unexpected ps output")
    }

    function refreshTopProcess() {
        if (topProc.running) {
            return
        }
        fetchError = ""
        topProc.running = true
    }

    ListModel {
        id: processListModel
    }

    Rectangle {
        id: memoryBox
        anchors.fill: parent
        radius: Theme.memoryPopupRadius
        color: Theme.memoryPopupBg
        border.width: 1
        border.color: Theme.memoryPopupBorder
        implicitHeight: memoryContent.implicitHeight + Theme.memoryPopupPadding * 2
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Column {
            id: memoryContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.memoryPopupPadding
            spacing: 10

            Text {
                text: root.tr("memory.title", "Memory")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSize
                font.weight: Theme.fontWeight
            }

            Text {
                text: root.tr("memory.usage", "Usage")
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
                    width: parent.width * Math.max(0, Math.min(1, (memoryUsageIndicator ? memoryUsageIndicator.usage : 0) / 100))
                    height: parent.height
                    radius: 5
                    color: Theme.memText
                }
            }

            Text {
                text: Math.round(memoryUsageIndicator ? memoryUsageIndicator.usage : 0) + "%"
                color: Theme.memText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                font.weight: Theme.fontWeight
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.blockBorder
                opacity: 0.45
            }

            Text {
                text: root.tr("memory.top_processes", "Top memory processes")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                font.weight: Theme.fontWeight
            }

            Item {
                width: parent.width
                height: 280

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Theme.blockBg
                    border.width: 1
                    border.color: Theme.blockBorder
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: root.tr("memory.header.process", "PROC")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                            width: parent.width - root.pidColumnWidth - root.rssColumnWidth - parent.spacing * 2
                            elide: Text.ElideRight
                        }

                        Text {
                            id: pidHeader
                            text: root.tr("memory.header.pid", "PID")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                            width: root.pidColumnWidth
                            horizontalAlignment: Text.AlignRight
                        }

                        Text {
                            id: rssHeader
                            text: root.tr("memory.header.rss", "RSS")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                            width: root.rssColumnWidth
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Flickable {
                        id: processListView
                        width: parent.width
                        height: parent.height - 24
                        contentWidth: width
                        contentHeight: processListColumn.implicitHeight
                        clip: true

                        Column {
                            id: processListColumn
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: processListModel

                                delegate: Rectangle {
                                    width: parent.width
                                    height: 28
                                    radius: 6
                                    color: Theme.memoryPopupBg
                                    border.width: 1
                                    border.color: Theme.blockBorder

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8

                                        Text {
                                            text: name
                                            color: Theme.memText
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            font.weight: Theme.fontWeight
                                            width: parent.width - root.pidColumnWidth - root.rssColumnWidth - parent.spacing * 2
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Text {
                                            id: pidText
                                            text: String(pid)
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            width: root.pidColumnWidth
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Text {
                                            id: rssText
                                            text: root.formatBytesFromKiB(rssKiB)
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.controllerFontSizeSmall
                                            width: root.rssColumnWidth
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }

                            Text {
                                text: topProc.running
                                    ? root.tr("common.loading", "Loading...")
                                    : root.tr("common.no_data", "No data")
                                visible: processListModel.count === 0 && fetchError.length === 0
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            Text {
                text: fetchError
                visible: fetchError.length > 0
                color: Theme.workspaceUrgentText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                width: parent.width
                wrapMode: Text.Wrap
            }
        }
    }

    Process {
        id: topProc
        command: ["sh", "-c", "ps -eo pid=,comm=,rss= --sort=-rss | head -n " + root.topProcessLimit + " | awk '{printf \"%s\\t%s\\t%s\\n\", $1, $2, $3}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.parseTopProcessList(this.text)
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.fetchError.length === 0) {
                root.fetchError = root.tr("memory.read_process_list_failed", "Failed to read process list")
            }
        }
    }

    onOpenChanged: {
        if (open) {
            if (bar) {
                bar.updateMemoryPopupAnchor()
            }
            refreshTopProcess()
        }
    }
}
