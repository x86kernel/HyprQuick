import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    property var bar

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

            Column {
                id: calendarPane
                width: Math.floor((parent.width - Theme.dateWidgetPopupGap - 1) / 2)
                property int calendarCellWidth: Math.floor((width - Theme.dateWidgetCalendarGap * 6) / 7)
                property int calendarContentWidth: calendarCellWidth * 7 + Theme.dateWidgetCalendarGap * 6
                spacing: Theme.dateWidgetPopupGap

                Column {
                    id: calendarCenterGroup
                    width: calendarPane.calendarContentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.dateWidgetPopupGap

                    Item {
                        id: calendarHeader
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

                    Row {
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
                                height: Theme.dateWidgetCalendarCellHeight
                                radius: Theme.blockRadius
                                color: isToday ? Theme.accentAlt : "transparent"
                                border.width: isCurrentMonth ? 1 : 0
                                border.color: Theme.blockBorder
                                opacity: isCurrentMonth ? 1 : 0.45

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    color: isToday ? Theme.textOnAccent : (isHoliday ? Theme.holidayTextColor : Theme.textPrimary)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Theme.fontWeight
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
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

            Rectangle {
                width: 1
                height: Math.max(calendarPane.implicitHeight, weatherPane.implicitHeight)
                color: Theme.blockBorder
                opacity: 0.7
            }

            Column {
                id: weatherPane
                width: parent.width - calendarPane.width - Theme.dateWidgetPopupGap - 1
                spacing: 8
                clip: true

                Item {
                    width: 1
                    height: Theme.weatherIllustrationTopMargin
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
                    text: bar.weatherCondition + "  " + bar.weatherTemperature + " (" + Theme.weatherFeelsLikeLabel + " " + bar.weatherFeelsLike + ")"
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
                    text: Theme.weatherLocationPrefix + ": " + bar.weatherLocationText
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
                    text: Theme.weatherHumidityLabel + ": " + bar.weatherHumidity + "\n" + Theme.weatherWindLabel + ": " + bar.weatherWind
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
                    text: Theme.weatherErrorPrefix + " " + bar.weatherError
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
                    text: Theme.weatherUpdatedPrefix + " " + bar.weatherUpdatedAt
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

    onOpenChanged: {
        if (open) {
            bar.updateDateWidgetPopupAnchor()
            bar.resetCalendarToCurrentMonth()
            bar.ensureHolidayYear(bar.calendarMonthDate.getFullYear())
            if (bar.weatherLastFetchMs <= 0 || (Date.now() - bar.weatherLastFetchMs) >= Theme.weatherOpenRefreshMs) {
                bar.refreshWeather(true)
            }
        }
    }
}
