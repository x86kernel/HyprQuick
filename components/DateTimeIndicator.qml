import QtQuick
import Quickshell
import "."

Item {
    id: root
    signal clicked

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: label.implicitWidth + paddingX * 2
        radius: Theme.blockRadius
        color: Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Text {
            id: label
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "yyyy년 MM월 dd일 HH:mm")
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
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
