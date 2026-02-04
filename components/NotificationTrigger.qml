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

            Text {
                text: "NOTI"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
            }

            Rectangle {
                visible: root.count > 0
                width: 18
                height: 18
                radius: 9
                color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: root.count > 99 ? "99" : root.count
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeight
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.clicked()
        }
    }
}
