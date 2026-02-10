import QtQuick
import "."

Item {
    id: root
    property bool active: SystemState.mediaActive
    property string displayText: SystemState.mediaDisplayText

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        visible: true
        implicitHeight: Theme.blockHeight
        implicitWidth: label.width + Theme.iconSize + row.spacing + paddingX * 2
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
                text: Theme.mediaIcon
                color: Theme.mediaText
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize
                font.weight: Theme.fontWeight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: label
                text: root.displayText.length > 0 ? root.displayText : Theme.mediaEmptyText
                color: Theme.mediaText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
                width: Math.min(implicitWidth, Theme.mediaMaxWidth)
                elide: Text.ElideRight
                height: row.height
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
