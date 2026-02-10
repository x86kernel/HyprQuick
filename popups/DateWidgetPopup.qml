import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"

PopupWindow {
    id: root
    property var bar
    property var i18nStrings: I18n.activeStrings
    property string pendingPowerAction: ""
    property bool powerActionRunning: false

    function tr(key, fallbackText) {
        var _unused = root.i18nStrings
        var v = I18n.t(key)
        return v === key ? fallbackText : v
    }

    function commandForPowerAction(actionId) {
        if (actionId === "lock") {
            var customLockCommand = ""
            if (bar && bar.appSettings && bar.appSettings.power && bar.appSettings.power.lockCommand !== undefined) {
                customLockCommand = String(bar.appSettings.power.lockCommand).trim()
            }
            return customLockCommand.length > 0 ? customLockCommand : Theme.powerLockCommand
        }
        if (actionId === "logout")
            return Theme.powerLogoutCommand
        if (actionId === "reboot")
            return Theme.powerRebootCommand
        if (actionId === "shutdown")
            return Theme.powerShutdownCommand
        return ""
    }

    function requestPowerAction(actionId) {
        if (powerActionRunning || actionId.length === 0)
            return
        if (pendingPowerAction === actionId) {
            var cmd = commandForPowerAction(actionId)
            pendingPowerAction = ""
            powerConfirmResetTimer.stop()
            if (cmd.length === 0)
                return
            powerActionProc.commandText = cmd
            powerActionRunning = true
            powerActionProc.running = true
            open = false
            return
        }
        pendingPowerAction = actionId
        powerConfirmResetTimer.restart()
    }

    implicitWidth: Theme.dateWidgetPopupWidth
    implicitHeight: dateWidgetContent.implicitHeight + Theme.dateWidgetPopupPaddingY * 2
    property bool open: false
    property real anim: open ? 1 : 0
    visible: open || anim > 0.01
    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    color: "transparent"
    anchor.window: bar

    Rectangle {
        anchors.fill: parent
        radius: Theme.dateWidgetPopupRadius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.popupBorder
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Row {
            id: dateWidgetContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.dateWidgetPopupPadding
            anchors.rightMargin: Theme.dateWidgetPopupPadding
            anchors.topMargin: Theme.dateWidgetPopupPaddingY
            spacing: Theme.dateWidgetPopupGap
            property int dividerWidth: 1
            property int powerPaneWidth: Math.floor((width - Theme.dateWidgetPopupGap * 2 - dividerWidth * 2) / 3)
            property int calendarPaneWidth: Math.floor((width - Theme.dateWidgetPopupGap * 2 - dividerWidth * 2) / 3)
            property int weatherPaneWidth: width - powerPaneWidth - calendarPaneWidth - Theme.dateWidgetPopupGap * 2 - dividerWidth * 2

            Column {
                id: powerPane
                width: dateWidgetContent.powerPaneWidth
                height: Math.max(calendarPane.implicitHeight, weatherPane.implicitHeight)
                spacing: Theme.dateWidgetPopupGap

                Grid {
                    id: powerGrid
                    width: parent.width
                    property real hintGap: powerHint.visible ? powerPane.spacing : 0
                    height: Math.max(120, powerPane.height - powerHint.height - hintGap)
                    columns: 2
                    columnSpacing: Theme.dateWidgetPopupGap
                    rowSpacing: Theme.dateWidgetPopupGap
                    property int rows: 2
                    property real itemWidth: (width - columnSpacing) / columns
                    property real itemHeight: (height - rowSpacing * (rows - 1)) / rows

                    Repeater {
                        model: [
                            { id: "lock", icon: "󰌾", label: root.tr("power.lock", "Lock"), danger: false },
                            { id: "logout", icon: "󰍃", label: root.tr("power.logout", "Logout"), danger: false },
                            { id: "reboot", icon: "󰜉", label: root.tr("power.reboot", "Reboot"), danger: true },
                            { id: "shutdown", icon: "󰐥", label: root.tr("power.shutdown", "Shutdown"), danger: true }
                        ]

                        delegate: Rectangle {
                            property string actionId: modelData.id
                            property bool isDanger: modelData.danger
                            property bool isConfirm: root.pendingPowerAction === actionId
                            width: powerGrid.itemWidth
                            height: powerGrid.itemHeight
                            radius: Theme.blockRadius
                            color: isConfirm
                                ? Theme.powerActionConfirmBg
                                : (isDanger ? Theme.powerActionDangerBg : Theme.powerActionBg)
                            border.width: 0
                            border.color: "transparent"

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: isDanger ? Theme.powerActionDangerText : Theme.powerActionText
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.powerActionIconSize
                                font.weight: Theme.fontWeight
                            }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: isDanger ? Theme.powerActionDangerText : Theme.powerActionText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.controllerFontSizeSmall
                                    font.weight: Theme.fontWeight
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.requestPowerAction(parent.actionId)
                            }
                        }
                    }
                }

                Text {
                    id: powerHint
                    width: parent.width
                    visible: root.powerActionRunning || root.pendingPowerAction.length > 0
                    height: visible ? implicitHeight : 0
                    text: root.powerActionRunning
                        ? root.tr("power.running", "Running...")
                        : root.tr("power.confirm_hint", "Press the same button again to confirm")
                    color: Theme.powerHintColor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeight
                    wrapMode: Text.Wrap
                }
            }

            Rectangle {
                width: dateWidgetContent.dividerWidth
                height: Math.max(powerPane.implicitHeight, calendarPane.implicitHeight, weatherPane.implicitHeight)
                color: Theme.blockBorder
                opacity: 0.7
            }

            ColumnLayout {
                id: calendarPane
                width: dateWidgetContent.calendarPaneWidth
                height: Math.max(powerPane.implicitHeight, weatherPane.implicitHeight)
                property int calendarCellWidth: Math.floor((width - Theme.dateWidgetCalendarGap * 6) / 7)
                property int calendarContentWidth: calendarCellWidth * 7 + Theme.dateWidgetCalendarGap * 6
                property int minGridHeight: Theme.dateWidgetCalendarCellHeight * 6 + Theme.dateWidgetCalendarGap * 5
                property int gridAvailableHeight: Math.max(minGridHeight,
                    Math.floor(calendarCenterGroup.height - calendarHeader.height - dayNamesRow.implicitHeight - calendarCenterGroup.spacing * 2))
                property int dynamicCalendarCellHeight: Math.floor((gridAvailableHeight - Theme.dateWidgetCalendarGap * 5) / 6)
                spacing: Theme.dateWidgetPopupGap

                Column {
                    id: calendarCenterGroup
                    width: calendarPane.calendarContentWidth
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                    Layout.fillHeight: true
                    spacing: Theme.dateWidgetPopupGap

                    Item {
                        id: calendarHeader
                        width: parent.width
                        height: Theme.dateWidgetNavButtonSize + Theme.dateWidgetHeaderBottomMargin

                        Item {
                            id: calendarHeaderControls
                            anchors.top: parent.top
                            width: parent.width
                            height: Theme.dateWidgetNavButtonSize

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: calendarPane.calendarCellWidth
                                height: Theme.dateWidgetNavButtonSize
                                radius: Theme.blockRadius
                                color: Theme.blockBg
                                border.width: 1
                                border.color: Theme.blockBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "◀"
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.controllerFontSizeSmall
                                    font.weight: Theme.fontWeight
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bar.setCalendarMonthOffset(-1)
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: Qt.formatDateTime(bar.calendarMonthDate, "yyyy년 MM월")
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSize
                                font.weight: Theme.fontWeight
                                verticalAlignment: Text.AlignVCenter
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: calendarPane.calendarCellWidth
                                height: Theme.dateWidgetNavButtonSize
                                radius: Theme.blockRadius
                                color: Theme.blockBg
                                border.width: 1
                                border.color: Theme.blockBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "▶"
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.controllerFontSizeSmall
                                    font.weight: Theme.fontWeight
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bar.setCalendarMonthOffset(1)
                                }
                            }
                        }
                    }

                    Row {
                        id: dayNamesRow
                        width: parent.width
                        spacing: Theme.dateWidgetCalendarGap

                        Repeater {
                            model: bar.calendarDayNames
                            delegate: Text {
                                width: calendarPane.calendarCellWidth
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Theme.accentAlt
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeight
                            }
                        }
                    }

                    Grid {
                        id: calendarGrid
                        width: parent.width
                        columns: 7
                        rowSpacing: Theme.dateWidgetCalendarGap
                        columnSpacing: Theme.dateWidgetCalendarGap

                        Repeater {
                            model: bar.calendarCells
                            delegate: Rectangle {
                                property bool isCurrentMonth: modelData.isCurrentMonth
                                property bool isToday: modelData.isToday
                                property bool isHoliday: modelData.isHoliday
                                width: calendarPane.calendarCellWidth
                                height: calendarPane.dynamicCalendarCellHeight
                                radius: Theme.blockRadius
                                color: isToday ? Theme.accentAlt : "transparent"
                                border.width: isCurrentMonth ? 1 : 0
                                border.color: Theme.blockBorder
                                opacity: isCurrentMonth ? 1 : 0.45

                                Column {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.topMargin: 3
                                    spacing: 2

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.day
                                        color: isToday ? Theme.textOnAccent : (isHoliday ? Theme.holidayTextColor : Theme.textPrimary)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeight
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.horizontalCenterOffset: 1
                                        width: Theme.holidayDotSize
                                        height: Theme.holidayDotSize
                                        radius: width / 2
                                        color: Theme.holidayDotColor
                                        visible: isHoliday && isCurrentMonth && !isToday
                                    }
                                }
                            }
                        }
                    }
                }

            }

            Rectangle {
                width: dateWidgetContent.dividerWidth
                height: Math.max(powerPane.implicitHeight, calendarPane.implicitHeight, weatherPane.implicitHeight)
                color: Theme.blockBorder
                opacity: 0.7
            }

            ColumnLayout {
                id: weatherPane
                width: dateWidgetContent.weatherPaneWidth
                height: Math.max(calendarPane.implicitHeight, powerPane.implicitHeight)
                spacing: 8
                clip: true

                Item {
                    width: 1
                    height: Theme.weatherIllustrationTopMargin
                    Layout.preferredHeight: Theme.weatherIllustrationTopMargin
                }

                Rectangle {
                    width: parent.width
                    height: Theme.weatherIllustrationSize
                    radius: Theme.weatherIllustrationRadius
                    color: "transparent"
                    border.width: 0

                    Image {
                        anchors.centerIn: parent
                        width: Theme.weatherIllustrationImageSize
                        height: Theme.weatherIllustrationImageSize
                        source: bar.weatherIconUrl
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        scale: Theme.weatherIllustrationScale
                    }
                }

                Text {
                    text: bar.weatherCondition + "  " + bar.weatherTemperature + " (" + root.tr("weather.feels_like_label", "Feels") + " " + bar.weatherFeelsLike + ")"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.controllerFontSizeSmall
                    font.weight: Theme.fontWeight
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    text: root.tr("weather.location_prefix", "Location") + ": " + bar.weatherLocationText
                    color: Theme.focusPipInactive
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeight
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    text: root.tr("weather.humidity_label", "Humidity") + ": " + bar.weatherHumidity
                        + "\n" + root.tr("weather.wind_label", "Wind") + ": " + bar.weatherWind
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeight
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    visible: bar.weatherError.length > 0
                    text: root.tr("weather.error_prefix", "Weather error:") + " " + bar.weatherError
                    color: Theme.cpuText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeight
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    text: root.tr("weather.updated_prefix", "Updated") + " " + bar.weatherUpdatedAt
                    color: Theme.focusPipInactive
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeight
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    Timer {
        id: powerConfirmResetTimer
        interval: Theme.powerConfirmTimeoutMs
        repeat: false
        onTriggered: root.pendingPowerAction = ""
    }

    Process {
        id: powerActionProc
        property string commandText: ""
        command: ["sh", "-c", commandText]
        running: false
        onRunningChanged: {
            if (!running)
                root.powerActionRunning = false
        }
    }

    onOpenChanged: {
        if (open) {
            bar.updateDateWidgetPopupAnchor()
            bar.resetCalendarToCurrentMonth()
            bar.ensureHolidayYear(bar.calendarMonthDate.getFullYear())
            if (bar.weatherLastFetchMs <= 0 || (Date.now() - bar.weatherLastFetchMs) >= Theme.weatherOpenRefreshMs) {
                bar.refreshWeather(true)
            }
        } else {
            pendingPowerAction = ""
            powerConfirmResetTimer.stop()
        }
    }
}
