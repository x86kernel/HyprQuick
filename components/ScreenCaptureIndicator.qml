import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    signal captureCompleted(string filePath)
    signal captureFailed(string reason)
    signal recordingStarted(string filePath)
    signal recordingStopped(string filePath)
    signal recordingFailed(string reason)
    signal recordingScopeChanged(string scope)

    property bool awaitingResult: false
    property string pendingStatusPath: ""
    property string pendingImagePath: ""
    property int pollCount: 0

    property string mode: "capture"
    property bool awaitingRecordingStart: false
    property bool isRecording: false
    property bool recordScopePopupOpen: false
    property string scopePopupMode: "capture"
    property string captureScope: "region"
    property bool captureDelayActive: false
    property int captureDelayRemaining: 0
    property bool capturePreparing: false
    property string recordScope: "region"
    property var parentWindow: null
    property string pendingRecordStatusPath: ""
    property string pendingRecordPidPath: ""
    property string currentRecordingPath: ""
    property int recordPollCount: 0
    property string pendingModeAfterStop: ""
    property bool blinkOn: false

    implicitHeight: container.implicitHeight
    implicitWidth: container.implicitWidth
    onXChanged: updateRecordScopePopupAnchor()
    onYChanged: updateRecordScopePopupAnchor()
    onWidthChanged: updateRecordScopePopupAnchor()
    onHeightChanged: updateRecordScopePopupAnchor()

    function shellQuote(text) {
        return "'" + (text || "").replace(/'/g, "'\\''") + "'"
    }

    function applyTemplate(template, replacements) {
        var out = template || ""
        var keys = Object.keys(replacements || {})
        for (var i = 0; i < keys.length; i += 1) {
            var key = keys[i]
            out = out.split(key).join(replacements[key])
        }
        return out
    }

    function setMode(nextMode) {
        if (nextMode !== "capture" && nextMode !== "record") {
            return
        }
        if (mode === nextMode) {
            return
        }
        mode = nextMode
        recordScopePopupOpen = false
        cancelCaptureDelay()
        capturePreparing = false
    }

    function openScopePopup(forMode) {
        if (awaitingRecordingStart || awaitingResult || isRecording || captureDelayActive || capturePreparing) {
            return
        }
        if (forMode !== "capture" && forMode !== "record") {
            return
        }
        scopePopupMode = forMode
        recordScopePopupOpen = !recordScopePopupOpen
        if (recordScopePopupOpen) {
            updateRecordScopePopupAnchor()
        }
    }

    function startCaptureWithScope(scope) {
        if (scope !== "region" && scope !== "fullscreen") {
            return
        }
        captureScope = scope
        recordScopePopupOpen = false
        startCapture()
    }

    function startRecordingWithScope(scope) {
        if (scope !== "region" && scope !== "fullscreen") {
            return
        }
        recordScope = scope
        recordingScopeChanged(recordScope)
        recordScopePopupOpen = false
        startRecording()
    }

    function toggleMode() {
        if (awaitingResult || awaitingRecordingStart || capturePreparing) {
            return
        }
        cancelCaptureDelay()
        if (mode === "capture") {
            setMode("record")
            return
        }
        if (isRecording) {
            pendingModeAfterStop = "capture"
            stopRecording()
            return
        }
        setMode("capture")
    }

    function activatePrimary() {
        if (mode === "record") {
            if (isRecording) {
                recordScopePopupOpen = false
                stopRecording()
            } else {
                openScopePopup("record")
            }
            return
        }
        openScopePopup("capture")
    }

    function cancelCaptureDelay() {
        captureDelayActive = false
        captureDelayRemaining = 0
        captureDelayTimer.stop()
    }

    function launchCaptureProcess() {
        var token = Date.now() + "-" + Math.floor(Math.random() * 1000000)
        pendingStatusPath = "/tmp/qs-shot-status-" + token + ".txt"
        pendingImagePath = "/tmp/qs-shot-image-" + token + ".png"

        var cmdTemplate = captureScope === "fullscreen"
            ? Theme.screenshotCaptureFullscreenCommandTemplate
            : Theme.screenshotCaptureRegionCommandTemplate
        var cmd = applyTemplate(cmdTemplate, {
            "%STATUS%": shellQuote(pendingStatusPath),
            "%FILE%": shellQuote(pendingImagePath)
        })

        launchProc.command = ["sh", "-c", cmd]
        launchProc.startDetached()

        pollCount = 0
        awaitingResult = true
        pollTimer.start()
    }

    function beginCaptureDelay() {
        var seconds = Math.max(1, Math.round(Number(Theme.screenshotFullscreenDelaySeconds) || 0))
        captureDelayRemaining = seconds
        captureDelayActive = true
        captureDelayTimer.start()
    }

    function runCaptureNow() {
        cancelCaptureDelay()
        recordScopePopupOpen = false
        capturePreparing = true
        preCaptureFlashTimer.start()
    }

    function startCapture() {
        if (awaitingResult || awaitingRecordingStart || isRecording || captureDelayActive || capturePreparing) {
            return
        }
        recordScopePopupOpen = false

        if (captureScope === "fullscreen" && Theme.screenshotFullscreenDelaySeconds > 0) {
            beginCaptureDelay()
            return
        }
        runCaptureNow()
    }

    function finishCapture(reason) {
        cancelCaptureDelay()
        capturePreparing = false
        preCaptureFlashTimer.stop()
        postPrepareTimer.stop()
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

    function startRecording() {
        if (awaitingResult || awaitingRecordingStart || isRecording) {
            return
        }
        recordScopePopupOpen = false

        var token = Date.now() + "-" + Math.floor(Math.random() * 1000000)
        pendingRecordStatusPath = "/tmp/qs-rec-status-" + token + ".txt"
        pendingRecordPidPath = "/tmp/qs-rec-pid-" + token + ".txt"

        var cmdTemplate = recordScope === "fullscreen"
            ? Theme.screenRecordStartFullscreenCommandTemplate
            : Theme.screenRecordStartRegionCommandTemplate
        var cmd = applyTemplate(cmdTemplate, {
            "%STATUS%": shellQuote(pendingRecordStatusPath),
            "%PIDFILE%": shellQuote(pendingRecordPidPath),
            "%EXT%": shellQuote(Theme.screenRecordFileExtension)
        })

        recordLaunchProc.command = ["sh", "-c", cmd]
        recordLaunchProc.startDetached()

        recordPollCount = 0
        awaitingRecordingStart = true
        recordPollTimer.start()
    }

    function finishRecordingStart(reason) {
        awaitingRecordingStart = false
        recordPollTimer.stop()
        recordCleanupProc.command = ["sh", "-c", "rm -f " + shellQuote(pendingRecordStatusPath)]
        recordCleanupProc.running = true

        if (reason.indexOf("READY:") === 0) {
            currentRecordingPath = reason.slice(6).trim()
            isRecording = currentRecordingPath.length > 0
            blinkOn = false
            recordBlinkTimer.start()
            recordingStarted(currentRecordingPath)
            return
        }

        recordCleanupProc2.command = ["sh", "-c", "rm -f " + shellQuote(pendingRecordPidPath)]
        recordCleanupProc2.running = true
        recordingFailed(reason)
    }

    function stopRecording() {
        recordScopePopupOpen = false
        if (!isRecording && !awaitingRecordingStart) {
            if (pendingModeAfterStop.length > 0) {
                setMode(pendingModeAfterStop)
                pendingModeAfterStop = ""
            }
            return
        }
        if (awaitingRecordingStart) {
            return
        }
        var path = currentRecordingPath
        isRecording = false
        blinkOn = false
        recordBlinkTimer.stop()

        var cmd = applyTemplate(Theme.screenRecordStopCommandTemplate, {
            "%PIDFILE%": shellQuote(pendingRecordPidPath)
        })
        recordStopProc.recordedPath = path
        recordStopProc.command = ["sh", "-c", cmd]
        recordStopProc.running = true
    }

    function updateRecordScopePopupAnchor() {
        if (!recordScopePopupWindow || !parentWindow || !recordScopePopupOpen) {
            return
        }
        var anchorItem = parentWindow.contentItem ? parentWindow.contentItem : parentWindow
        var pos = root.mapToItem(anchorItem, 0, root.height)
        recordScopePopupWindow.anchor.rect.x = Math.round(pos.x + (root.width - recordScopePopupWindow.width) / 2)
        recordScopePopupWindow.anchor.rect.y = Math.round(pos.y + Theme.popupOffset)
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
    Process { id: recordLaunchProc }
    Process {
        id: recordReadProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.awaitingRecordingStart) {
                    return
                }
                var value = this.text.trim()
                if (value.length === 0) {
                    return
                }
                if (value.indexOf("__QSCANCEL__") === 0) {
                    root.finishRecordingStart("cancelled")
                    return
                }
                if (value.indexOf("__QSERR__") === 0) {
                    root.finishRecordingStart(value.replace("__QSERR__", "").trim())
                    return
                }
                root.finishRecordingStart(value.split(/\r?\n/)[0].trim())
            }
        }
    }
    Process { id: recordCleanupProc }
    Process { id: recordCleanupProc2 }
    Process {
        id: recordStopProc
        property string recordedPath: ""
        running: false
        onExited: function(exitCode) {
            var path = recordedPath
            recordedPath = ""
            currentRecordingPath = ""
            recordCleanupProc2.command = ["sh", "-c", "rm -f " + shellQuote(pendingRecordPidPath)]
            recordCleanupProc2.running = true

            if (exitCode !== 0) {
                recordingFailed("record-stop-failed")
            } else if (path.length > 0) {
                recordingStopped(path)
            } else {
                recordingStopped("")
            }

            if (pendingModeAfterStop.length > 0) {
                setMode(pendingModeAfterStop)
                pendingModeAfterStop = ""
            }
        }
    }

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

    Timer {
        id: captureDelayTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (!root.captureDelayActive) {
                stop()
                return
            }
            root.captureDelayRemaining -= 1
            if (root.captureDelayRemaining <= 0) {
                stop()
                root.runCaptureNow()
            }
        }
    }

    Timer {
        id: preCaptureFlashTimer
        interval: Math.max(0, Theme.screenshotPreCaptureUiDelayMs)
        repeat: false
        onTriggered: {
            root.capturePreparing = false
            postPrepareTimer.start()
        }
    }

    Timer {
        id: postPrepareTimer
        interval: Math.max(0, Theme.screenshotPostPrepareDelayMs)
        repeat: false
        onTriggered: root.launchCaptureProcess()
    }

    Timer {
        id: recordPollTimer
        interval: 250
        repeat: true
        onTriggered: {
            if (!root.awaitingRecordingStart) {
                stop()
                return
            }
            recordPollCount += 1
            if (recordPollCount > 160) {
                root.finishRecordingStart("record-timeout")
                return
            }
            if (!recordReadProc.running) {
                recordReadProc.command = ["sh", "-c", "cat " + root.shellQuote(root.pendingRecordStatusPath) + " 2>/dev/null"]
                recordReadProc.running = true
            }
        }
    }

    Timer {
        id: recordBlinkTimer
        interval: Theme.screenRecordBlinkIntervalMs
        repeat: true
        running: root.isRecording
        onTriggered: root.blinkOn = !root.blinkOn
    }

    Rectangle {
        id: container
        property int paddingX: Theme.blockPaddingX
        property int paddingY: Theme.blockPaddingY

        implicitHeight: Theme.blockHeight
        implicitWidth: iconLabel.implicitWidth + paddingX * 2
        radius: Theme.blockRadius
        color: root.awaitingRecordingStart || root.capturePreparing
            ? Theme.accentAlt
            : (root.mode === "record" ? Theme.screenRecordModeBg : Theme.blockBg)
        border.width: 1
        border.color: root.isRecording ? Theme.screenRecordActiveColor : Theme.blockBorder

        Text {
            id: iconLabel
            anchors.centerIn: parent
            text: root.captureDelayActive
                ? String(root.captureDelayRemaining)
                : (root.isRecording
                ? Theme.screenRecordActiveIcon
                : (root.mode === "record"
                    ? (root.recordScope === "fullscreen" ? Theme.screenRecordFullscreenIcon : Theme.screenRecordRegionIcon)
                    : (root.captureScope === "fullscreen" ? Theme.screenshotFullscreenIcon : Theme.screenshotRegionIcon)))
            color: root.isRecording
                ? (root.blinkOn ? Theme.screenRecordActiveColor : Theme.screenRecordBlinkOffColor)
                : (root.capturePreparing ? Theme.textOnAccent
                : (root.captureDelayActive
                    ? Theme.accent
                    : (root.mode === "record" ? Theme.screenRecordModeIconColor : Theme.textPrimary)))
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize
            font.weight: Theme.fontWeight
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.toggleMode()
                    return
                }
                if (root.captureDelayActive) {
                    root.cancelCaptureDelay()
                    return
                }
                root.activatePrimary()
            }
        }
    }

    PopupWindow {
        id: recordScopePopupWindow
        property real anim: root.recordScopePopupOpen ? 1 : 0
        visible: root.parentWindow && (root.recordScopePopupOpen || anim > 0.01)
        color: "transparent"
        anchor.window: root.parentWindow
        width: Theme.screenRecordScopePopupWidth
        implicitHeight: popupContent.implicitHeight + Theme.screenRecordScopePopupPadding * 2
        Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
        onVisibleChanged: {
            if (visible) {
                root.updateRecordScopePopupAnchor()
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.popupRadius
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.popupBorder
            opacity: recordScopePopupWindow.anim
            scale: 0.98 + 0.02 * recordScopePopupWindow.anim

            Column {
                id: popupContent
                anchors.fill: parent
                anchors.margins: Theme.screenRecordScopePopupPadding
                spacing: Theme.screenRecordScopePopupGap

                Text {
                    text: root.scopePopupMode === "record"
                        ? Theme.screenRecordScopeTitle
                        : Theme.screenshotScopeTitle
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Theme.fontWeight
                }

                Rectangle {
                    width: parent.width
                    height: Theme.screenRecordScopeButtonHeight
                    radius: Theme.blockRadius
                    color: Theme.blockBg
                    border.width: 1
                    border.color: Theme.blockBorder

                    Text {
                        anchors.centerIn: parent
                        text: root.scopePopupMode === "record"
                            ? Theme.screenRecordScopeRegionText
                            : Theme.screenshotScopeRegionText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Theme.fontWeight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.scopePopupMode === "record") {
                                root.startRecordingWithScope("region")
                            } else {
                                root.startCaptureWithScope("region")
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Theme.screenRecordScopeButtonHeight
                    radius: Theme.blockRadius
                    color: Theme.blockBg
                    border.width: 1
                    border.color: Theme.blockBorder

                    Text {
                        anchors.centerIn: parent
                        text: root.scopePopupMode === "record"
                            ? Theme.screenRecordScopeFullscreenText
                            : Theme.screenshotScopeFullscreenText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Theme.fontWeight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.scopePopupMode === "record") {
                                root.startRecordingWithScope("fullscreen")
                            } else {
                                root.startCaptureWithScope("fullscreen")
                            }
                        }
                    }
                }
            }
        }
    }
}
