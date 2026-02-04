import QtQuick
import "."

Item {
    id: root
    property int count: 0
    property int fixedWidth: 0
    signal clicked

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: (root.fixedWidth > 0 ? root.fixedWidth : (bellIcon.implicitWidth + paddingX * 2))
        radius: Theme.blockRadius
        color: root.count > 0 ? Theme.accent : Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Text {
            id: bellIcon
            anchors.centerIn: parent
            text: Theme.notificationIcon
            color: root.count > 0 ? Theme.textOnAccent : Theme.accent
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
