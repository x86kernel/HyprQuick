import QtQuick
import "."

Item {
    id: root
    property bool powered: SystemState.bluetoothPowered
    property int connectedCount: SystemState.bluetoothConnectedCount
    property bool available: SystemState.bluetoothAvailable
    property var deviceItems: SystemState.bluetoothDeviceItems
    signal clicked

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function setPower(on) {
        SystemState.setBluetoothPower(on)
    }

    function toggleDevice(mac, connected) {
        if (connected) {
            disconnectDevice(mac)
        } else {
            pairDevice(mac)
            connectDevice(mac)
        }
    }

    function pairDevice(mac) {
        SystemState.pairBluetoothDevice(mac)
    }

    function connectDevice(mac) {
        SystemState.connectBluetoothDevice(mac)
    }

    function disconnectDevice(mac) {
        SystemState.disconnectBluetoothDevice(mac)
    }

    function scanNow() {
        SystemState.scanBluetoothNow()
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
