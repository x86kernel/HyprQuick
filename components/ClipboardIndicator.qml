import QtQuick
import "."

Item {
    id: root
    property bool hasClipboard: SystemState.clipboardHasData
    property bool flashActive: false
    property string lastKey: ""
    property var items: SystemState.clipboardItems

    signal clicked()
    signal rightClicked()

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function applyKey(key) {
        var trimmed = String(key || "").trim()
        hasClipboard = trimmed.length > 0
        if (trimmed.length > 0 && trimmed !== lastKey) {
            lastKey = trimmed
            flashActive = true
            flashTimer.restart()
        } else if (!hasClipboard) {
            flashActive = false
        }
    }

    function refreshItems() {
        SystemState.refreshClipboardItems()
    }

    function copyItem(itemId) {
        SystemState.copyClipboardItem(itemId)
    }

    Timer {
        id: flashTimer
        interval: Theme.clipboardFlashDuration
        repeat: false
        onTriggered: root.flashActive = false
    }

    Connections {
        target: SystemState
        function onClipboardKeyChanged() {
            root.applyKey(SystemState.clipboardKey)
        }
    }

    Component.onCompleted: root.applyKey(SystemState.clipboardKey)

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: iconLabel.implicitWidth + paddingX * 2
        radius: Theme.blockRadius
        color: root.flashActive ? Theme.textPrimary : Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Behavior on color {
            ColorAnimation { duration: Theme.clipboardFlashAnimMs }
        }

        Text {
            id: iconLabel
            anchors.centerIn: parent
            text: Theme.clipboardIcon
            color: root.flashActive ? Theme.textOnAccent : Theme.textPrimary
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize
            font.weight: Theme.fontWeight
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.rightClicked()
                    return
                }
                root.clicked()
            }
        }
    }
}
