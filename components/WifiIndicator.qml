import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    property string ssid: ""
    property bool available: true
    property bool radioOn: true
    property var networks: []
    signal clicked

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function updateFromOutput(text) {
        var line = text.trim()
        if (line.length === 0) {
            ssid = ""
            available = false
            return
        }
        available = true
        ssid = line
    }

    function updateRadio(text) {
        var t = text.trim()
        radioOn = t === "enabled" || t === "yes" || t === "on"
    }

    function updateNetworks(text) {
        var lines = text.split(/\r?\n/)
        var list = []
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.length === 0) {
                continue
            }
            var parts = line.split(":")
            if (parts.length < 3) {
                continue
            }
            var active = parts[0] === "yes"
            var ssidValue = parts[1]
            var signal = Number(parts[2])
            if (ssidValue.length === 0) {
                continue
            }
            list.push({ active: active, ssid: ssidValue, signal: signal })
        }
        list.sort(function(a, b) {
            if (a.active === b.active) return 0
            return a.active ? -1 : 1
        })
        networks = list
    }

    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' | head -n 1 | cut -d: -f2-"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateFromOutput(this.text)
        }
    }

    Process {
        id: wifiListProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.updateNetworks(this.text)
        }
    }

    Process {
        id: wifiRadioProc
        command: ["sh", "-c", "nmcli -t -f WIFI general status | cut -d: -f2"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.updateRadio(this.text)
        }
    }

    Process {
        id: wifiRescanProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: wifiListProc.running = true
        }
    }

    Process {
        id: wifiConnectProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: wifiListProc.running = true
        }
    }

    Process {
        id: wifiDisconnectProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: wifiListProc.running = true
        }
    }

    Process {
        id: wifiToggleProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: wifiListProc.running = true
        }
    }

    function scanNow() {
        wifiRescanProc.command = ["sh", "-c", "nmcli dev wifi rescan"]
        wifiRescanProc.running = true
    }

    function connectTo(ssidValue) {
        if (!ssidValue || ssidValue.length === 0) {
            return
        }
        wifiConnectProc.command = ["sh", "-c", "nmcli dev wifi connect \"" + ssidValue.replace(/\"/g, '\\\\\"') + "\""]
        wifiConnectProc.running = true
    }

    function disconnectNow() {
        wifiDisconnectProc.command = ["sh", "-c", "nmcli networking off; nmcli networking on"]
        wifiDisconnectProc.running = true
    }

    function disconnectActive() {
        wifiDisconnectProc.command = ["sh", "-c", "nmcli dev disconnect $(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2==\"wifi\" && $3==\"connected\" {print $1; exit}')"]
        wifiDisconnectProc.running = true
    }

    function setWifiPower(on) {
        wifiToggleProc.command = ["sh", "-c", on ? "nmcli radio wifi on" : "nmcli radio wifi off"]
        wifiToggleProc.running = true
    }

    Timer {
        interval: Theme.wifiPollInterval
        running: true
        repeat: true
        onTriggered: {
            wifiProc.running = true
            wifiListProc.running = true
            wifiRadioProc.running = true
        }
    }

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: row.implicitWidth + paddingX * 2
        radius: Theme.blockRadius
        color: Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Row {
            id: row
            spacing: 8
            anchors.centerIn: parent
            height: Math.max(iconLabel.implicitHeight, label.implicitHeight)

            Text {
                id: iconLabel
                text: Theme.wifiIcon
                color: Theme.wifiText
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize
                font.weight: Theme.fontWeight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: label
                text: available && ssid.length > 0 ? ssid : Theme.wifiEmptyText
                color: Theme.wifiText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
                width: Math.min(implicitWidth, Theme.wifiMaxWidth)
                elide: Text.ElideRight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
