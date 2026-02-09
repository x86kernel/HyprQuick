import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    signal captureCompleted(string filePath)
    signal captureFailed(string reason)

    property bool awaitingResult: false
    property string pendingStatusPath: ""
    property string pendingImagePath: ""
    property int pollCount: 0

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth

    function shellQuote(text) {
        return "'" + (text || "").replace(/'/g, "'\\''") + "'"
    }

    function startCapture() {
        if (awaitingResult) {
            return
        }

        var token = Date.now() + "-" + Math.floor(Math.random() * 1000000)
        pendingStatusPath = "/tmp/qs-shot-status-" + token + ".txt"
        pendingImagePath = "/tmp/qs-shot-image-" + token + ".png"

        var cmd = "status=" + shellQuote(pendingStatusPath)
            + "; img=" + shellQuote(pendingImagePath)
            + "; rm -f \"$status\" \"$img\";"
            + " region=\"$(slurp 2>/dev/null || true)\";"
            + " if [ -z \"$region\" ]; then printf '__QSCANCEL__\\n' > \"$status\"; exit 0; fi;"
            + " if grim -g \"$region\" \"$img\" && [ -s \"$img\" ]; then printf '%s\\n' \"$img\" > \"$status\";"
            + " else printf '__QSERR__ capture-failed\\n' > \"$status\"; rm -f \"$img\"; fi"

        launchProc.command = ["sh", "-c", cmd]
        launchProc.startDetached()

        pollCount = 0
        awaitingResult = true
        pollTimer.start()
    }

    function finishCapture(reason) {
        awaitingResult = false
        pollTimer.stop()
        cleanupProc.command = ["sh", "-c", "rm -f " + shellQuote(pendingStatusPath)]
        cleanupProc.running = true

        if (reason === "cancelled") {
            cleanupProc2.command = ["sh", "-c", "rm -f " + shellQuote(pendingImagePath)]
            cleanupProc2.running = true
            captureFailed("cancelled")
            return
        }

        if (reason.indexOf("/") === 0) {
            captureCompleted(reason)
            return
        }

        cleanupProc2.command = ["sh", "-c", "rm -f " + shellQuote(pendingImagePath)]
        cleanupProc2.running = true
        captureFailed(reason)
    }

    Process {
        id: launchProc
    }

    Process {
        id: statusReadProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.awaitingResult) {
                    return
                }
                var value = this.text.trim()
                if (value.length === 0) {
                    return
                }
                if (value.indexOf("__QSCANCEL__") === 0) {
                    root.finishCapture("cancelled")
                    return
                }
                if (value.indexOf("__QSERR__") === 0) {
                    root.finishCapture(value.replace("__QSERR__", "").trim())
                    return
                }
                root.finishCapture(value.split(/\r?\n/)[0].trim())
            }
        }
    }

    Process { id: cleanupProc }
    Process { id: cleanupProc2 }

    Timer {
        id: pollTimer
        interval: 250
        repeat: true
        onTriggered: {
            if (!root.awaitingResult) {
                stop()
                return
            }
            pollCount += 1
            if (pollCount > 160) {
                root.finishCapture("capture-timeout")
                return
            }
            if (!statusReadProc.running) {
                statusReadProc.command = ["sh", "-c", "cat " + root.shellQuote(root.pendingStatusPath) + " 2>/dev/null"]
                statusReadProc.running = true
            }
        }
    }

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: iconLabel.implicitWidth + paddingX * 2
        radius: Theme.blockRadius
        color: root.awaitingResult ? Theme.accentAlt : Theme.blockBg
        border.width: 1
        border.color: Theme.blockBorder

        Text {
            id: iconLabel
            anchors.centerIn: parent
            text: Theme.screenshotIcon
            color: Theme.textPrimary
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize
            font.weight: Theme.fontWeight
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.startCapture()
        }
    }
}
