import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    property bool active: false
    property string displayText: ""

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function applyPlayerInfo(text) {
        var lines = text.split(/\r?\n/)
        var chosen = ""
        var fallback = ""
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.length === 0)
                continue
            if (line.indexOf("Playing|") === 0) {
                chosen = line
                break
            }
            if (fallback.length === 0 && line.indexOf("Paused|") === 0) {
                fallback = line
            }
        }
        if (chosen.length === 0) {
            chosen = fallback
        }
        if (chosen.length === 0) {
            active = false
            displayText = ""
            return
        }
        var parts = chosen.split("|")
        var title = parts.length > 2 ? parts[2] : ""
        var artist = parts.length > 3 ? parts[3] : ""
        var textOut = title
        if (artist && title) {
            textOut = artist + " - " + title
        } else if (artist) {
            textOut = artist
        }
        active = textOut.length > 0
        displayText = textOut
    }

    Process {
        id: playerProc
        command: ["sh", "-c", "playerctl -a metadata --format '{{status}}|{{playerName}}|{{title}}|{{artist}}' 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.applyPlayerInfo(this.text)
        }
    }

    Timer {
        interval: Theme.mediaPollInterval
        running: true
        repeat: true
        onTriggered: playerProc.running = true
    }

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
