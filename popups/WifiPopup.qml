import QtQuick
import Quickshell
import Quickshell.Wayland
import "../components"

PopupWindow {
    id: root
    property var bar
    property var wifiIndicator
    property var i18nStrings: I18n.activeStrings
    function tr(key, fallbackText) {
        // Touch active strings so QML re-evaluates bindings when locale data changes.
        var _unused = root.i18nStrings
        var v = I18n.t(key)
        return v === key ? fallbackText : v
    }

    implicitWidth: Theme.wifiPopupWidth
    implicitHeight: Math.max(1, wifiBox.implicitHeight)
    property bool open: false
    property real anim: open ? 1 : 0
    property int pageIndex: 0
    property real pageAnim: pageIndex
    property var selectedNetwork: null
    property int securityIndex: 0
    property bool securityDropdownOpen: false
    property bool passwordHover: false
    property real securityDropdownX: 0
    property real securityDropdownY: 0
    property bool connectReady: {
        if (!selectedNetwork) {
            return false
        }
        if (!selectedNetwork.secure) {
            return true
        }
        return passwordInput && passwordInput.text.length > 0
    }
    visible: open || anim > 0.01
    Behavior on anim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    Behavior on pageAnim { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }
    color: "transparent"
    anchor.window: bar

    function guessSecurityIndex(securityText) {
        if (!Theme.wifiSecurityOptions || Theme.wifiSecurityOptions.length === 0) {
            return 0
        }
        var text = securityText || ""
        if (text.indexOf("WPA3") !== -1) {
            return Math.min(2, Theme.wifiSecurityOptions.length - 1)
        }
        if (text.indexOf("WPA") !== -1) {
            return Math.min(1, Theme.wifiSecurityOptions.length - 1)
        }
        if (text.indexOf("WEP") !== -1) {
            return Math.min(3, Theme.wifiSecurityOptions.length - 1)
        }
        return 0
    }

    function selectedSecurityValue() {
        if (!Theme.wifiSecurityOptionValues || Theme.wifiSecurityOptionValues.length === 0) {
            return ""
        }
        if (securityIndex < 0 || securityIndex >= Theme.wifiSecurityOptionValues.length) {
            return ""
        }
        return Theme.wifiSecurityOptionValues[securityIndex] || ""
    }

    function focusPasswordInput() {
        acquireKeyboardFocus()
        if (passwordInput) {
            passwordInput.forceActiveFocus()
        }
    }

    function acquireKeyboardFocus() {
        if (bar && bar.WlrLayershell) {
            bar.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand
        }
    }

    function openConnect(network) {
        selectedNetwork = network
        securityIndex = guessSecurityIndex(network ? network.security : "")
        securityDropdownOpen = false
        updateSecurityDropdownPos()
        if (passwordInput) {
            passwordInput.text = ""
        }
        pageIndex = 1
        acquireKeyboardFocus()
        if (network && network.secure) {
            Qt.callLater(function() { root.focusPasswordInput() })
        }
    }

    function closeConnect() {
        pageIndex = 0
        selectedNetwork = null
        securityDropdownOpen = false
        updateSecurityDropdownPos()
        if (passwordInput) {
            passwordInput.text = ""
        }
    }

    function updateSecurityDropdownPos() {
        if (!securityTrigger || !wifiBox) {
            return
        }
        var pos = securityTrigger.mapToItem(wifiBox, 0, securityTrigger.height + 6)
        securityDropdownX = pos.x
        securityDropdownY = pos.y
    }

    function connectSelected() {
        if (!wifiIndicator || !selectedNetwork || !connectReady) {
            return
        }
        var passwordValue = passwordInput ? passwordInput.text : ""
        var securityValue = selectedNetwork.secure ? selectedSecurityValue() : ""
        wifiIndicator.connectTo(selectedNetwork.ssid, passwordValue, securityValue)
        closeConnect()
    }

    Rectangle {
        id: wifiBox
        anchors.fill: parent
        radius: Theme.wifiPopupRadius
        color: Theme.wifiPopupBg
        border.width: 1
        border.color: Theme.wifiPopupBorder
        implicitHeight: wifiContent.implicitHeight + Theme.wifiPopupPadding * 2
        opacity: root.anim
        scale: 0.98 + 0.02 * root.anim

        Item {
            id: wifiContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.wifiPopupPadding
            implicitHeight: Math.max(listPage.implicitHeight, connectPage.implicitHeight)
            clip: true

            Row {
                id: wifiPages
                spacing: 0
                x: -root.pageAnim * wifiContent.width
                Behavior on x { NumberAnimation { duration: Theme.controllerAnimMs; easing.type: Easing.OutCubic } }

                Column {
                    id: listPage
                    width: wifiContent.width
                    spacing: 8

                    Text {
                        text: root.tr("wifi.title", "WiFi")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSize
                        font.weight: Theme.fontWeight
                    }

                    Text {
                        text: wifiIndicator && wifiIndicator.ssid.length > 0
                            ? wifiIndicator.ssid
                            : root.tr("wifi.not_connected", "Not connected")
                        color: Theme.wifiText
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
                            text: wifiIndicator && wifiIndicator.radioOn
                                ? root.tr("wifi.turn_off", "Turn WiFi Off")
                                : root.tr("wifi.turn_on", "Turn WiFi On")
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
                                if (wifiIndicator) {
                                    wifiIndicator.setWifiPower(!wifiIndicator.radioOn)
                                }
                            }
                        }
                    }

                    Text {
                        text: root.tr("wifi.networks", "Networks")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSizeSmall
                        font.weight: Theme.fontWeight
                    }

                    Grid {
                        id: wifiGrid
                        width: parent.width
                        property int columnCount: Math.max(1, Theme.wifiNetworkColumns)
                        columns: columnCount
                        columnSpacing: Theme.wifiNetworkColumnSpacing
                        rowSpacing: Theme.wifiNetworkRowSpacing

                        Repeater {
                            model: wifiIndicator ? wifiIndicator.networks : []

                            delegate: Rectangle {
                                width: (wifiContent.width - wifiGrid.columnSpacing * (wifiGrid.columnCount - 1)) / wifiGrid.columnCount
                                height: 38
                                radius: 6
                                color: modelData.active ? Theme.wifiText : Theme.blockBg
                                border.width: 1
                                border.color: Theme.blockBorder

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.blockPaddingX
                                    spacing: 6

                                    Text {
                                        text: modelData.ssid
                                        color: modelData.active ? Theme.textOnAccent : Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.controllerFontSizeSmall
                                        font.weight: Theme.fontWeight
                                        width: parent.width - Theme.wifiSignalWidth - Theme.wifiSecureIconWidth - 12
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                        height: parent.height
                                    }

                                    Text {
                                        text: modelData.secure ? Theme.wifiSecureIcon : ""
                                        color: modelData.active ? Theme.textOnAccent : Theme.textPrimary
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.controllerFontSizeSmall
                                        verticalAlignment: Text.AlignVCenter
                                        height: parent.height
                                        width: Theme.wifiSecureIconWidth
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        text: modelData.signal + "%"
                                        color: modelData.active ? Theme.textOnAccent : Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.controllerFontSizeSmall
                                        verticalAlignment: Text.AlignVCenter
                                        height: parent.height
                                        width: Theme.wifiSignalWidth
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!wifiIndicator)
                                            return
                                        if (modelData.active) {
                                            wifiIndicator.disconnectActive()
                                        } else {
                                            root.openConnect(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: !wifiIndicator || wifiIndicator.networks.length === 0
                        text: root.tr("wifi.no_networks", "No networks")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSizeSmall
                    }
                }

                Column {
                    id: connectPage
                    width: wifiContent.width
                    spacing: 12

                    Text {
                        text: root.selectedNetwork
                            ? root.tr("wifi.connect_question", "Connect to {ssid}?").replace("{ssid}", root.selectedNetwork.ssid)
                            : root.tr("wifi.connect_question", "Connect to {ssid}?").replace("{ssid}", "")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSize
                        font.weight: Theme.fontWeight
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        visible: root.selectedNetwork && root.selectedNetwork.security
                        text: root.selectedNetwork
                            ? root.tr("wifi.security_label", "Security") + ": " + root.selectedNetwork.security
                            : ""
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.controllerFontSizeSmall
                        font.weight: Theme.fontWeight
                    }

                    Column {
                        id: passwordSection
                        visible: root.selectedNetwork && root.selectedNetwork.secure
                        spacing: 6
                        width: connectPage.width
                        onVisibleChanged: {
                            if (visible) {
                                root.acquireKeyboardFocus()
                                Qt.callLater(function() { root.focusPasswordInput() })
                            }
                        }

                        Text {
                            text: root.tr("wifi.security_label", "Security")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            id: securityTrigger
                            width: parent.width
                            height: Theme.wifiConnectFieldHeight
                            radius: Theme.wifiConnectRadius
                            color: Theme.wifiConnectFieldBg
                            border.width: 1
                            border.color: Theme.wifiConnectFieldBorder

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Text {
                                    id: securityLabel
                                    text: Theme.wifiSecurityOptions && Theme.wifiSecurityOptions.length > 0
                                        ? Theme.wifiSecurityOptions[root.securityIndex] || Theme.wifiSecurityOptions[0]
                                        : "Auto"
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.controllerFontSizeSmall
                                    font.weight: Theme.fontWeight
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    width: parent.width - 22
                                }

                                Text {
                                    text: root.securityDropdownOpen ? "▴" : "▾"
                                    color: Theme.focusPipInactive
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.controllerFontSizeSmall
                                    verticalAlignment: Text.AlignVCenter
                                    width: 12
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!Theme.wifiSecurityOptions || Theme.wifiSecurityOptions.length === 0) {
                                        return
                                    }
                                    root.securityDropdownOpen = !root.securityDropdownOpen
                                    if (root.securityDropdownOpen) {
                                        root.updateSecurityDropdownPos()
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        visible: root.selectedNetwork && root.selectedNetwork.secure
                        spacing: 6
                        width: connectPage.width

                        Text {
                            text: root.tr("wifi.password_label", "Password")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        Rectangle {
                            width: parent.width
                            height: Theme.wifiConnectFieldHeight
                            radius: Theme.wifiConnectRadius
                            color: root.passwordHover ? Theme.wifiConnectFieldBgHover : Theme.wifiConnectFieldBg
                            border.width: 1
                            border.color: root.passwordHover ? Theme.wifiConnectFieldBorderHover : Theme.wifiConnectFieldBorder

                            TextInput {
                                id: passwordInput
                                anchors.fill: parent
                                anchors.margins: 10
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                                echoMode: TextInput.Password
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.textOnAccent
                                activeFocusOnTab: true
                                selectByMouse: true
                                clip: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: false
                                propagateComposedEvents: true
                                onPressed: function(mouse) {
                                    root.focusPasswordInput()
                                    mouse.accepted = false
                                }
                            }

                            HoverHandler {
                                cursorShape: Qt.IBeamCursor
                                onHoveredChanged: root.passwordHover = hovered
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 10
                                text: root.tr("wifi.password_placeholder", "Enter password")
                                color: Theme.wifiConnectMutedText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.controllerFontSizeSmall
                                visible: passwordInput.text.length === 0 && !passwordInput.activeFocus
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: 1
                    }
                }
            }
        }

        Item {
            id: wifiOverlay
            anchors.fill: parent
            z: 6
            visible: root.selectedNetwork && root.selectedNetwork.secure && root.securityDropdownOpen

            Rectangle {
                id: securityDropdown
                x: root.securityDropdownX
                y: root.securityDropdownY
                width: securityTrigger ? securityTrigger.width : 200
                height: Math.min(Theme.wifiConnectFieldHeight * 4, securityList.implicitHeight + 12)
                radius: Theme.wifiConnectRadius
                color: Theme.wifiConnectFieldBg
                border.width: 1
                border.color: Theme.wifiConnectFieldBorder
            }

            Column {
                id: securityList
                x: securityDropdown.x
                y: securityDropdown.y
                width: securityDropdown.width
                anchors.margins: 6
                spacing: 4

                Repeater {
                    model: Theme.wifiSecurityOptions ? Theme.wifiSecurityOptions.length : 0

                    delegate: Rectangle {
                        width: parent.width
                        height: Theme.wifiConnectFieldHeight - 6
                        radius: Theme.wifiConnectRadius - 2
                        color: index === root.securityIndex ? Theme.accentAlt : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: Theme.wifiSecurityOptions[index]
                            color: index === root.securityIndex ? Theme.textOnAccent : Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.controllerFontSizeSmall
                            font.weight: Theme.fontWeight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.securityIndex = index
                                root.securityDropdownOpen = false
                            }
                        }
                    }
                }
            }
        }

        Row {
            id: connectButtons
            anchors.left: wifiContent.left
            anchors.right: wifiContent.right
            anchors.bottom: wifiContent.bottom
            spacing: 8
            visible: root.pageIndex === 1

            Rectangle {
                width: (wifiContent.width - 8) / 2
                height: Theme.wifiConnectButtonHeight
                radius: Theme.wifiConnectRadius
                color: Theme.wifiConnectFieldBg
                border.width: 1
                border.color: Theme.wifiConnectFieldBorder

                Text {
                    anchors.centerIn: parent
                    text: root.tr("wifi.connect_no", "No")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.controllerFontSizeSmall
                    font.weight: Theme.fontWeight
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeConnect()
                }
            }

            Rectangle {
                width: (wifiContent.width - 8) / 2
                height: Theme.wifiConnectButtonHeight
                radius: Theme.wifiConnectRadius
                color: Theme.accent
                opacity: root.connectReady ? 1 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: root.tr("wifi.connect_yes", "Yes")
                    color: Theme.textOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.controllerFontSizeSmall
                    font.weight: Theme.fontWeight
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.connectSelected()
                }
            }
        }
    }

    onOpenChanged: {
        if (open) {
            acquireKeyboardFocus()
            bar.updateWifiPopupAnchor()
            if (wifiIndicator) {
                wifiIndicator.scanNow()
            }
        } else {
            if (bar && bar.WlrLayershell) {
                bar.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
            }
            closeConnect()
        }
    }

    onVisibleChanged: {
        if (visible && open) {
            acquireKeyboardFocus()
            if (pageIndex === 1 && selectedNetwork && selectedNetwork.secure) {
                Qt.callLater(function() { root.focusPasswordInput() })
            }
        }
    }

    onPageAnimChanged: {
        if (open && pageIndex === 1 && selectedNetwork && selectedNetwork.secure && Math.abs(pageAnim - 1) < 0.01) {
            Qt.callLater(function() { root.focusPasswordInput() })
        }
    }

    onWidthChanged: updateSecurityDropdownPos()
    onHeightChanged: updateSecurityDropdownPos()
}
