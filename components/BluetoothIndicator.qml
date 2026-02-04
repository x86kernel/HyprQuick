import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    property bool powered: false
    property int connectedCount: 0
    property bool available: true
    property var deviceItems: []
    signal clicked

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function updateFromOutput(text) {
        var trimmed = text.trim()
        if (trimmed.length === 0) {
            available = false
            powered = false
            connectedCount = 0
            return
        }
        available = true
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
        powered = pow
        connectedCount = count
        var connectedMacs = {}
        for (var c = 0; c < names.length; c += 1) {
            connectedMacs[names[c].mac] = true
        }
        var filtered = all.filter(function(d) {
            if (connectedMacs[d.mac]) {
                return false
            }
            for (var n = 0; n < names.length; n += 1) {
                if (names[n].name === d.name) {
                    return false
                }
            }
            return true
        })
        deviceItems = names.concat(filtered)
    }

    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show; echo __CONNECTED__; bluetoothctl devices Connected; echo __ALL__; bluetoothctl devices"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateFromOutput(this.text)
        }
    }

    Process {
        id: powerProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: btProc.running = true
        }
    }

    Process {
        id: deviceProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: btProc.running = true
        }
    }

    Process {
        id: pairProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: btProc.running = true
        }
    }

    Process {
        id: connectProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: btProc.running = true
        }
    }

    Process {
        id: scanProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: btProc.running = true
        }
    }

    function setPower(on) {
        powerProc.command = ["sh", "-c", on ? "bluetoothctl power on" : "bluetoothctl power off"]
        powerProc.running = true
    }

    function toggleDevice(mac, connected) {
        if (!mac || mac.length === 0) {
            return
        }
        if (connected) {
            deviceProc.command = ["sh", "-c", "bluetoothctl disconnect " + mac]
        } else {
            deviceProc.command = ["sh", "-c", "bluetoothctl pair " + mac + "; bluetoothctl connect " + mac]
        }
        deviceProc.running = true
    }

    function pairDevice(mac) {
        if (!mac || mac.length === 0) {
            return
        }
        pairProc.command = ["sh", "-c", "bluetoothctl pair " + mac]
        pairProc.running = true
    }

    function connectDevice(mac) {
        if (!mac || mac.length === 0) {
            return
        }
        connectProc.command = ["sh", "-c", "bluetoothctl connect " + mac]
        connectProc.running = true
    }

    function disconnectDevice(mac) {
        if (!mac || mac.length === 0) {
            return
        }
        deviceProc.command = ["sh", "-c", "bluetoothctl disconnect " + mac]
        deviceProc.running = true
    }

    function scanNow() {
        scanProc.command = ["sh", "-c", "bluetoothctl scan on; sleep 4; bluetoothctl scan off"]
        scanProc.running = true
    }

    Timer {
        interval: Theme.bluetoothPollInterval
        running: true
        repeat: true
        onTriggered: btProc.running = true
    }

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: iconLabel.implicitWidth + paddingX * 2
        radius: Theme.blockRadius
        color: connectedCount > 0 ? Theme.bluetoothActiveText : Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Text {
            id: iconLabel
            anchors.centerIn: parent
            text: Theme.bluetoothIcon
            color: connectedCount > 0 ? Theme.textOnAccent : Theme.bluetoothActiveText
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize
            font.weight: Theme.fontWeight
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
