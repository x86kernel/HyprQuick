//@ pragma UseQApplication
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "components"

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            property var modelData
            screen: modelData
            property var hyprMonitor: Hyprland.monitorFor(screen)

            anchors.top: true
            anchors.left: true
            anchors.right: true
            margins.top: Theme.barMarginTop
            margins.left: Theme.barMarginX
            margins.right: Theme.barMarginX
            implicitHeight: Theme.blockHeight + 6
            exclusiveZone: implicitHeight + margins.top
            color: "transparent"

            NotificationServer {
                id: notificationServer
                keepOnReload: true
                onNotification: function(notification) {
                    notification.tracked = true
                    appendToast(notification)
                }
            }

            function notificationCount() {
                if (!notificationServer.trackedNotifications) {
                    return 0
                }
                if (notificationServer.trackedNotifications.values !== undefined) {
                    return notificationServer.trackedNotifications.values.length
                }
                if (notificationServer.trackedNotifications.count !== undefined) {
                    return notificationServer.trackedNotifications.count
                }
                if (notificationServer.trackedNotifications.length !== undefined) {
                    return notificationServer.trackedNotifications.length
                }
                return 0
            }

            property int maxToasts: 10
            property int toastCounter: 0

            ListModel {
                id: toastModel
            }

            function appendToast(notification) {
                toastCounter += 1
                toastModel.append({
                    toastId: toastCounter,
                    summary: notification.summary || "",
                    body: notification.body || ""
                })
                while (toastModel.count > maxToasts) {
                    toastModel.remove(0)
                }
            }

            function removeToastById(toastId) {
                for (var i = 0; i < toastModel.count; i += 1) {
                    if (toastModel.get(i).toastId === toastId) {
                        toastModel.remove(i)
                        return
                    }
                }
            }

            RowLayout {
                id: barLayout
                anchors.fill: parent
                anchors.leftMargin: Theme.barMarginX
                anchors.rightMargin: Theme.barMarginX
                spacing: Theme.blockGap

                Item {
                    id: leftArea
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    implicitHeight: leftRow.implicitHeight
                    implicitWidth: leftRow.implicitWidth

                    Row {
                        id: leftRow
                        spacing: Theme.blockGap
                        anchors.verticalCenter: parent.verticalCenter

                        WorkspaceIndicator {
                            id: workspaceIndicator
                            monitor: bar.hyprMonitor
                        }

                        FocusedWindowIndicator {
                            id: focusedWindowIndicator
                        }
                    }
                }

                Item {
                    id: centerArea
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    id: rightArea
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                    Row {
                        id: rightRow
                        spacing: Theme.blockGap
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right

                        SystemTrayIndicator {
                            id: systemTrayIndicator
                            parentWindow: bar
                        }

                        NotificationTrigger {
                            id: notificationTrigger
                            count: notificationCount()
                            onClicked: notificationPopup.visible = !notificationPopup.visible
                        }
                    }
                }
            }

            DateTimeIndicator {
                id: dateTimeIndicator
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            PopupWindow {
                id: toastPopup
                width: Theme.toastWidth
                height: Math.max(1, toastStack.implicitHeight)
                visible: toastModel.count > 0
                color: "transparent"
                anchor.window: bar
                anchor.rect.x: bar.width - width - Theme.barMarginX
                anchor.rect.y: bar.height + Theme.popupOffset

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.toastAnimDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: toastStack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    implicitHeight: {
                        var h = -Theme.toastGap
                        for (var i = 0; i < toastRepeater.count; i += 1) {
                            var item = toastRepeater.itemAt(i)
                            if (item && item.layoutVisible)
                                h += item.implicitHeight + Theme.toastGap
                        }
                        return Math.max(0, h)
                    }

                    Repeater {
                        id: toastRepeater
                        model: toastModel

                        delegate: Item {
                            id: toastItem
                            width: toastPopup.width
                            implicitHeight: toastContent.implicitHeight
                            property int toastId: model.toastId
                            property bool appeared: false
                            property bool closing: false
                            property bool layoutVisible: !closing

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: {
                                var y = 0
                                for (var i = 0; i < index; i += 1) {
                                    var item = toastRepeater.itemAt(i)
                                    if (item && item.layoutVisible)
                                        y += item.implicitHeight + Theme.toastGap
                                }
                                return y
                            }

                            opacity: appeared && !closing ? 1 : 0
                            scale: appeared && !closing ? 1 : 0.7

                            Component.onCompleted: appeared = true
                            onClosingChanged: {
                                if (closing)
                                    removeTimer.restart()
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.toastAnimDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.toastAnimDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on anchors.bottomMargin {
                                NumberAnimation {
                                    duration: Theme.toastAnimDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Timer {
                                id: lifeTimer
                                interval: Theme.toastDuration
                                running: true
                                repeat: false
                                onTriggered: toastItem.closing = true
                            }

                            Timer {
                                id: removeTimer
                                interval: Theme.toastAnimDuration
                                repeat: false
                                onTriggered: bar.removeToastById(toastItem.toastId)
                            }

                            Rectangle {
                                id: toastContent
                                width: parent.width
                                implicitHeight: toastTextColumn.implicitHeight + 20
                                radius: Theme.blockRadius
                                color: Theme.blockBg
                                border.width: 1
                                border.color: Theme.blockBorder

                                Column {
                                    id: toastTextColumn
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Text {
                                        text: model.summary
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.toastTitleSize
                                        font.weight: Theme.fontWeight
                                        wrapMode: Text.Wrap
                                    }

                                    Text {
                                        text: model.body
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.toastBodySize
                                        font.weight: Theme.fontWeight
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                }
            }

            PopupWindow {
                id: notificationPopup
                width: Theme.popupWidth
                height: Theme.popupHeight
                visible: false
                color: "transparent"
                anchor.window: bar
                anchor.rect.x: bar.width - width - Theme.barMarginX
                anchor.rect.y: bar.height + Theme.popupOffset

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.popupRadius
                    color: Theme.popupBg
                    border.width: 1
                    border.color: Theme.popupBorder

                    Flickable {
                        id: notificationList
                        anchors.fill: parent
                        anchors.margins: Theme.popupPadding
                        contentWidth: width
                        contentHeight: listColumn.implicitHeight
                        clip: true

                        Column {
                            id: listColumn
                            spacing: 10
                            width: parent.width

                            Text {
                                text: "Notifications"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                            }

                            Repeater {
                                model: notificationServer.trackedNotifications.values !== undefined
                                    ? notificationServer.trackedNotifications.values
                                    : notificationServer.trackedNotifications

                                delegate: Rectangle {
                                    width: parent.width
                                    radius: 10
                                    color: Theme.blockBg
                                    border.width: 1
                                    border.color: Theme.blockBorder
                                    implicitHeight: contentColumn.implicitHeight + 16

                                    Column {
                                        id: contentColumn
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        spacing: 4

                                        Text {
                                            text: modelData.appName && modelData.appName.length > 0 ? modelData.appName : "App"
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeight
                                            textFormat: Text.PlainText
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            width: parent.width
                                        }

                                        Text {
                                            text: modelData.summary
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                            font.weight: Theme.fontWeight
                                            textFormat: Text.PlainText
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                        }

                                        Text {
                                            text: modelData.body
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            textFormat: Text.PlainText
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: notificationCount() === 0
                                text: "No notifications"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }
    }
}
