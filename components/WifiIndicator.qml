import QtQuick
import "."

Item {
    id: root
    property string ssid: SystemState.wifiSsid
    property bool available: SystemState.wifiAvailable
    property bool radioOn: SystemState.wifiRadioOn
    property var networks: SystemState.wifiNetworks
    signal clicked

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function scanNow() {
        SystemState.scanWifiNow()
    }

    function connectTo(ssidValue, passwordValue, securityValue) {
        SystemState.connectWifi(ssidValue, passwordValue, securityValue)
    }

    function disconnectNow() {
        SystemState.disconnectWifiNow()
    }

    function disconnectActive() {
        SystemState.disconnectWifiActive()
    }

    function setWifiPower(on) {
        SystemState.setWifiPower(on)
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
