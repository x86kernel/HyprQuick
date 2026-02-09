import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    property var bar
    property var bluetoothIndicator

    implicitWidth: Theme.bluetoothPopupWidth
    implicitHeight: Math.max(1, bluetoothBox.implicitHeight)
    property bool open: false
    property real anim: open ? 1 : 0
    visible: open || anim > 0.01
    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    color: "transparent"
    anchor.window: bar

    Rectangle {
        id: bluetoothBox
        anchors.fill: parent
        radius: Theme.bluetoothPopupRadius
        color: Theme.bluetoothPopupBg
        border.width: 1
        border.color: Theme.bluetoothPopupBorder
        implicitHeight: bluetoothContent.implicitHeight + Theme.bluetoothPopupPadding * 2
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Column {
            id: bluetoothContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.bluetoothPopupPadding
            spacing: 8

            Text {
                text: "Bluetooth"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSize
                font.weight: Theme.fontWeight
            }

            Text {
                text: bluetoothIndicator
                    ? (bluetoothIndicator.powered ? "Powered On" : "Powered Off")
                    : "Powered Off"
                color: Theme.bluetoothActiveText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                font.weight: Theme.fontWeight
            }

            Rectangle {
                width: parent.width
                height: 28
                radius: 6
                color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: bluetoothIndicator && bluetoothIndicator.powered ? "Turn Off" : "Turn On"
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.controllerFontSizeSmall
                    font.weight: Theme.fontWeight
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (bluetoothIndicator) {
                            bluetoothIndicator.setPower(!bluetoothIndicator.powered)
                        }
                    }
                }
            }

            Text {
                text: "Devices"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.controllerFontSizeSmall
                font.weight: Theme.fontWeight
            }

            Column {
                width: parent.width
                spacing: 6

                Repeater {
                    model: bluetoothIndicator ? bluetoothIndicator.deviceItems : []

                    delegate: Rectangle {
                        width: parent.width
                        height: 38
                        radius: 6
                        color: modelData.connected ? Theme.bluetoothActiveText : Theme.blockBg
                        border.width: 1
                        border.color: Theme.blockBorder

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                text: modelData.name
                                color: modelData.connected ? Theme.textOnAccent : Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                                font.weight: Theme.fontWeight
                                width: parent.width - 72
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }

                            Item {
                                width: 64
                                height: parent.height

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: Theme.blockBg
                                        opacity: pairArea.pressed ? 0.9 : 1
                                        scale: pairArea.pressed ? 0.92 : 1
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.bluetoothPairIcon
                                            color: Theme.bluetoothActiveText
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.iconSize
                                        }

                                        MouseArea {
                                            id: pairArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (bluetoothIndicator) {
                                                    bluetoothIndicator.pairDevice(modelData.mac)
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: Theme.blockBg
                                        opacity: connectArea.pressed ? 0.9 : 1
                                        scale: connectArea.pressed ? 0.92 : 1
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.connected ? Theme.bluetoothDisconnectIcon : Theme.bluetoothConnectIcon
                                            color: Theme.bluetoothActiveText
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.iconSize
                                        }

                                        MouseArea {
                                            id: connectArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!bluetoothIndicator)
                                                    return
                                                if (modelData.connected) {
                                                    bluetoothIndicator.disconnectDevice(modelData.mac)
                                                } else {
                                                    bluetoothIndicator.connectDevice(modelData.mac)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !bluetoothIndicator || bluetoothIndicator.deviceItems.length === 0
                    text: "No devices"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.controllerFontSizeSmall
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            bar.updateBluetoothPopupAnchor()
        }
    }

    onOpenChanged: {
        if (open) {
            bar.updateBluetoothPopupAnchor()
            if (bluetoothIndicator) {
                bluetoothIndicator.scanNow()
            }
        }
    }
}
