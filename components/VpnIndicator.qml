import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    property bool connected: false
    property string activeName: ""

    implicitHeight: connected ? container.implicitHeight : 0
    implicitWidth: connected ? container.implicitWidth : 0
    visible: connected

    function updateFromOutput(text) {
        var line = text.trim()
        connected = line.length > 0
        activeName = line
    }

    Process {
        id: vpnProc
        command: [
            "sh",
            "-c",
            "if ! command -v nmcli >/dev/null 2>&1; then exit 0; fi; nmcli -t -f TYPE,NAME connection show --active | awk -F: '$1==\"vpn\" || $1==\"wireguard\" {print $2; exit}'"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateFromOutput(this.text)
        }
    }

    Timer {
        interval: Theme.vpnPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: vpnProc.running = true
    }

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: iconLabel.implicitWidth + paddingX * 2
        radius: Theme.blockRadius
        color: Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Text {
            id: iconLabel
            anchors.centerIn: parent
            text: Theme.vpnIcon
            color: Theme.vpnText
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize
            font.weight: Theme.fontWeight
        }
    }
}
