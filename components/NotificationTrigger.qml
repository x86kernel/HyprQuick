import QtQuick
import ".."

Item {
    id: root
    property int count: 0
    signal clicked

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

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

            Item {
                id: bellWrapper
                width: bellIcon.implicitWidth
                height: bellIcon.implicitHeight

                Text {
                    id: bellIcon
                    anchors.centerIn: parent
                    text: Theme.notificationIcon
                    color: Theme.textPrimary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize
                    font.weight: Theme.fontWeight
                }

                Rectangle {
                    visible: root.count > 0
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.accent
                    z: 2
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.rightMargin: -2
                }
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
