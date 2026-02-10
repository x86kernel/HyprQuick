import QtQuick
import "."

Item {
    id: root
    property bool connected: SystemState.vpnConnected
    property string activeName: SystemState.vpnActiveName

    implicitHeight: connected ? container.implicitHeight : 0
    implicitWidth: connected ? container.implicitWidth : 0
    visible: connected

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
