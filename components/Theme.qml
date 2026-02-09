pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: theme

    property int blockHeight: 30
    property int blockRadius: 8
    property int blockPaddingX: 12
    property int blockPaddingY: 6
    property int blockGap: 8
    property int workspaceGap: 0

    property int barMarginTop: 8
    property int barMarginX: 8
    property int barReserveBottom: 0

    property string fontFamily: "SF Pro Text"
    property string iconFontFamily: "SauceCodePro Nerd Font"
    property int fontSize: 13
    property int fontSizeSmall: 12
    property int controllerFontSize: 15
    property int controllerFontSizeSmall: 14
    property int iconSize: 15
    property int toastTitleSize: 16
    property int toastBodySize: 14
    property int toastWidth: 360
    property int toastTitleMaxChars: 32
    property int toastGap: 8
    property int toastPadding: 14
    property int toastTitleGap: 12
    property int toastIconSize: 26
    property int toastIconCircleSize: 40
    property int toastBodyTopMargin: 4
    property int toastCardRadius: 12
    property color toastCardBg: "#242438"
    property color toastCardBorder: "#000000"
    property color toastTitleText: "#f5c2e7"
    property color toastBodyText: "#cdd6f4"
    property color toastIconBg: "#2c2c45"
    property color toastIconBorder: "transparent"
    property color toastIconShadow: "#0000005c"
    property int toastIconShadowRadius: 20
    property int toastIconShadowOffsetY: 3
    property color toastCardShadow: "#000000b3"
    property int toastCardShadowRadius: 20
    property int toastCardShadowOffsetY: 8
    property int toastCardShadowPadding: 14
    property int toastDuration: 3500
    property int toastAnimDuration: 520
    property int toastSlideOffset: 80
    property int fontWeight: Font.DemiBold
    property string notificationIcon: "󰂚"
    property string screenshotIcon: "󰄀"
    property string screenshotCaptureCommand: "for c in slurp grim; do command -v \"$c\" >/dev/null 2>&1 || { printf '__QSERR__ missing:%s\\n' \"$c\"; exit 0; }; done; tmp=\"$(mktemp /tmp/qs-shot-XXXXXX.png)\"; slurp_out=\"$(slurp 2>&1)\"; slurp_status=$?; if [ \"$slurp_status\" -ne 0 ]; then rm -f \"$tmp\"; printf '__QSERR__ slurp-failed:%s\\n' \"$slurp_out\"; exit 0; fi; region=\"$slurp_out\"; grim_err=\"$(grim -g \"$region\" \"$tmp\" 2>&1)\"; grim_status=$?; if [ \"$grim_status\" -ne 0 ] || [ ! -s \"$tmp\" ]; then rm -f \"$tmp\"; printf '__QSERR__ grim-failed:%s\\n' \"$grim_err\"; exit 0; fi; printf '%s\\n' \"$tmp\""
    property string screenshotSaveCommandTemplate: "mkdir -p \"$HOME/Pictures/Screenshots\"; cp %FILE% \"$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png\""
    property string screenshotCopyCommandTemplate: "wl-copy < %FILE%"
    property string screenshotDiscardCommandTemplate: "rm -f %FILE%"
    property int screenshotPopupWidth: 560
    property int screenshotPopupHeight: 380
    property int screenshotPopupRadius: 14
    property int screenshotPopupPadding: 14
    property int screenshotPopupGap: 10
    property int screenshotActionButtonHeight: 38
    property string screenshotTitle: "Screenshot Preview"
    property string screenshotSelectingText: "Select an area to capture..."
    property string screenshotSaveText: "Save"
    property string screenshotCopyText: "Copy"
    property string screenshotCloseText: "Close"
    property string notificationFallbackIcon: "󰂚"
    property string cpuIcon: "󰍛"
    property int cpuPollInterval: 2000
    property color cpuText: "#f2a3a3"
    property string memIcon: "󰘚"
    property int memPollInterval: 2000
    property color memText: "#f9e2af"
    property string bluetoothIcon: "󰂯"
    property int bluetoothPollInterval: 3000
    property string bluetoothOnText: "On"
    property string bluetoothOffText: "Off"
    property string bluetoothUnavailableText: "BT?"
    property color bluetoothActiveText: "#89dceb"
    property color bluetoothInactiveText: "#585b70"
    property int bluetoothPopupWidth: 360
    property int bluetoothPopupPadding: 12
    property int bluetoothPopupRadius: 12
    property int bluetoothPopupOffset: 8
    property color bluetoothPopupBg: "#181826"
    property color bluetoothPopupBorder: "transparent"
    property string bluetoothConnectIcon: "󰂯"
    property string bluetoothPairIcon: "󰌆"
    property string bluetoothDisconnectIcon: "󰂲"
    property string wifiIcon: "󰖩"
    property int wifiPollInterval: 3000
    property int wifiMaxWidth: 140
    property string wifiEmptyText: "No WiFi"
    property color wifiText: "#a6e3a1"
    property int wifiPopupWidth: 560
    property int wifiPopupPadding: 12
    property int wifiPopupRadius: 12
    property int wifiPopupOffset: 8
    property color wifiPopupBg: "#181826"
    property color wifiPopupBorder: "transparent"
    property int wifiSignalWidth: 40
    property int wifiNetworkColumns: 2
    property int wifiNetworkColumnSpacing: 12
    property int wifiNetworkRowSpacing: 12
    property string wifiSecureIcon: "󰌾"
    property int wifiSecureIconWidth: 16
    property string wifiConnectQuestion: "Connect to %1?"
    property string wifiConnectYesText: "Yes"
    property string wifiConnectNoText: "No"
    property string wifiSecurityLabel: "Security"
    property string wifiPasswordLabel: "Password"
    property string wifiPasswordPlaceholder: "Enter password"
    property var wifiSecurityOptions: ["Auto", "WPA-PSK", "WPA3-SAE", "WEP"]
    property var wifiSecurityOptionValues: ["", "wpa-psk", "sae", "none"]
    property int wifiConnectButtonHeight: 38
    property int wifiConnectFieldHeight: 38
    property int wifiConnectRadius: 10
    property color wifiConnectFieldBg: "#1f1f30"
    property color wifiConnectFieldBorder: "#2b2b42"
    property color wifiConnectFieldBorderHover: "#3a3a5a"
    property color wifiConnectFieldBgHover: "#24243a"
    property color wifiConnectMutedText: "#9aa0b7"
    property string batteryIconCharging: "󰂄"
    property string batteryIconDischargingLow: "󰁺"
    property string batteryIconDischargingMid: "󰁼"
    property string batteryIconDischargingHigh: "󰁾"
    property string batteryIconFull: "󰁹"
    property int batteryPollInterval: 5000
    property string batteryUnavailableText: "--"
    property color batteryText: "#f5c2e7"
    property string vpnIcon: ""
    property int vpnPollInterval: 3000
    property color vpnText: "#cba6f7"
    property int cpuTooltipWidth: 220
    property int cpuTooltipPadding: 10
    property int cpuTooltipRadius: 10
    property int cpuTooltipOffset: 6
    property int cpuTooltipMaxLines: 3
    property int cpuTooltipPollInterval: 2000
    property color cpuTooltipBg: "#1c1c2b"
    property color cpuTooltipBorder: "transparent"
    property color cpuTooltipText: "#f5c2e7"
    property int cpuPopupWidth: 360
    property int cpuPopupPadding: 12
    property int cpuPopupRadius: 12
    property int cpuPopupOffset: 8
    property color cpuPopupBg: "#181826"
    property color cpuPopupBorder: "transparent"

    property string clipboardIcon: "󰅌"
    property int clipboardFlashDuration: 1500
    property int clipboardFlashAnimMs: 240
    property color clipboardFlashBg: "#f5c2e7"
    property color clipboardActiveText: "#0b0b16"
    property color clipboardInactiveText: "#585b70"
    property int clipboardPollInterval: 400

    property color blockBg: "#242438"
    property color blockBorder: "transparent"

    property color accent: "#f5c2e7"
    property color accentAlt: "#b4befe"
    property color textPrimary: "#cdd6f4"
    property color textOnAccent: "#0b0b16"
    property color focusPipInactive: "#585b70"

    property color otherMonitorBg: "#242438"
    property color otherMonitorBorder: "transparent"
    property color otherMonitorText: "#cdd6f4"

    property int trayIconSize: 16
    property int trayItemGap: 4
    property int trayMinWidth: 40

    property int popupWidth: 360
    property int popupHeight: 320
    property int popupBottomMargin: 12
    property int popupPadding: toastPadding
    property int popupRadius: 14
    property int popupOffset: 8
    property color popupBg: "#181826"
    property color popupBorder: "transparent"
    property int dateWidgetPopupWidth: 640
    property int dateWidgetPopupHeight: 330
    property int dateWidgetPopupRadius: 14
    property int dateWidgetPopupPadding: 14
    property int dateWidgetPopupPaddingY: 14
    property int dateWidgetPopupGap: 10
    property int dateWidgetPopupOffset: 8
    property int dateWidgetNavButtonSize: 28
    property int dateWidgetCalendarGap: 6
    property int dateWidgetCalendarCellHeight: 28
    property color holidayTextColor: "#ff9ac1"
    property color holidayDotColor: "#ff6da8"
    property int holidayDotSize: 5
    property int weatherPollInterval: 900000
    property int weatherMinRefreshMs: 120000
    property int weatherOpenRefreshMs: 600000
    property string weatherUpdatedFormat: "MM/dd HH:mm"
    property string weatherSectionTitle: "Weather"
    property string weatherLocationPrefix: "Location"
    property string weatherFeelsLikeLabel: "Feels"
    property string weatherHumidityLabel: "Humidity"
    property string weatherWindLabel: "Wind"
    property string weatherUpdatedPrefix: "Updated"
    property string weatherErrorPrefix: "Weather error:"
    property string weatherLoadingText: "날씨 정보를 불러오는 중..."
    property string weatherUnavailableText: "날씨 정보를 불러올 수 없음"
    property int weatherIllustrationSize: 128
    property int weatherIllustrationRadius: 16
    property color weatherIllustrationBg: "#2a223a"
    property color weatherIllustrationBorder: "#ffffff22"
    property int weatherIllustrationMargin: 2
    property int weatherIllustrationImageSize: 148
    property int weatherIllustrationTopMargin: Math.max(0, Math.ceil((weatherIllustrationImageSize - weatherIllustrationSize) / 2))
    property real weatherIllustrationScale: 1.0
    property int notificationEmptyMinHeight: 220
    property int notificationEmptyGifSize: 96
    property string notificationEmptyText: "알림이 없습니다"
    property int controllerAnimMs: 160
    property string mediaIcon: "󰝚"
    property int mediaPollInterval: 1200
    property int mediaMaxWidth: 220
    property color mediaText: "#f5c2e7"
    property string mediaEmptyText: "미디어 없음"

    property var windowIconMappings: [
        { match: "class", pattern: "qBittorrent$", icon: "", name: "QBittorrent" },
        { match: "class", pattern: "rofi", icon: "", name: "Rofi" },
        { match: "class", pattern: "brave-browser", icon: "󰖟", name: "Brave Browser" },
        { match: "class", pattern: "chromium", icon: "", name: "Chromium" },
        { match: "class", pattern: "firefox", icon: "󰈹", name: "Firefox" },
        { match: "class", pattern: "floorp", icon: "󰈹", name: "Floorp" },
        { match: "class", pattern: "google-chrome", icon: "", name: "Google Chrome" },
        { match: "class", pattern: "microsoft-edge", icon: "󰇩", name: "Edge" },
        { match: "class", pattern: "opera", icon: "", name: "Opera" },
        { match: "class", pattern: "thorium", icon: "󰖟", name: "Thorium" },
        { match: "class", pattern: "tor-browser", icon: "", name: "Tor Browser" },
        { match: "class", pattern: "vivaldi", icon: "󰖟", name: "Vivaldi" },
        { match: "class", pattern: "waterfox", icon: "󰖟", name: "Waterfox" },
        { match: "class", pattern: "zen", icon: "", name: "Zen Browser" },
        { match: "class", pattern: "^st$", icon: "", name: "st Terminal" },
        { match: "class", pattern: "alacritty", icon: "", name: "Alacritty" },
        { match: "class", pattern: "com.mitchellh.ghostty", icon: "󰊠", name: "Ghostty" },
        { match: "class", pattern: "foot", icon: "󰽒", name: "Foot Terminal" },
        { match: "class", pattern: "gnome-terminal", icon: "", name: "GNOME Terminal" },
        { match: "class", pattern: "kitty", icon: "󰄛", name: "Kitty Terminal" },
        { match: "class", pattern: "konsole", icon: "", name: "Konsole" },
        { match: "class", pattern: "tilix", icon: "", name: "Tilix" },
        { match: "class", pattern: "urxvt", icon: "", name: "URxvt" },
        { match: "class", pattern: "wezterm", icon: "", name: "Wezterm" },
        { match: "class", pattern: "xterm", icon: "", name: "XTerm" },
        { match: "class", pattern: "DBeaver", icon: "", name: "DBeaver" },
        { match: "class", pattern: "android-studio", icon: "󰀴", name: "Android Studio" },
        { match: "class", pattern: "atom", icon: "", name: "Atom" },
        { match: "class", pattern: "code", icon: "󰨞", name: "Visual Studio Code" },
        { match: "class", pattern: "docker", icon: "", name: "Docker" },
        { match: "class", pattern: "eclipse", icon: "", name: "Eclipse" },
        { match: "class", pattern: "emacs", icon: "", name: "Emacs" },
        { match: "class", pattern: "jetbrains-idea", icon: "", name: "IntelliJ IDEA" },
        { match: "class", pattern: "jetbrains-phpstorm", icon: "", name: "PhpStorm" },
        { match: "class", pattern: "jetbrains-pycharm", icon: "", name: "PyCharm" },
        { match: "class", pattern: "jetbrains-webstorm", icon: "", name: "WebStorm" },
        { match: "class", pattern: "neovide", icon: "", name: "Neovide" },
        { match: "class", pattern: "neovim", icon: "", name: "Neovim" },
        { match: "class", pattern: "netbeans", icon: "", name: "NetBeans" },
        { match: "class", pattern: "sublime-text", icon: "", name: "Sublime Text" },
        { match: "class", pattern: "vim", icon: "", name: "Vim" },
        { match: "class", pattern: "vscode", icon: "󰨞", name: "VS Code" },
        { match: "class", pattern: "discord", icon: "", name: "Discord" },
        { match: "class", pattern: "legcord", icon: "", name: "Legcord" },
        { match: "class", pattern: "webcord", icon: "", name: "WebCord" },
        { match: "class", pattern: "org.telegram.desktop", icon: "", name: "Telegram" },
        { match: "class", pattern: "skype", icon: "󰒯", name: "Skype" },
        { match: "class", pattern: "slack", icon: "󰒱", name: "Slack" },
        { match: "class", pattern: "teams", icon: "󰊻", name: "Microsoft Teams" },
        { match: "class", pattern: "teamspeak", icon: "", name: "TeamSpeak" },
        { match: "class", pattern: "telegram-desktop", icon: "", name: "Telegram" },
        { match: "class", pattern: "thunderbird", icon: "", name: "Thunderbird" },
        { match: "class", pattern: "vesktop", icon: "", name: "Vesktop" },
        { match: "class", pattern: "whatsapp", icon: "󰖣", name: "WhatsApp" },
        { match: "class", pattern: "doublecmd", icon: "󰝰", name: "Double Commander" },
        { match: "class", pattern: "krusader", icon: "󰝰", name: "Krusader" },
        { match: "class", pattern: "nautilus", icon: "󰝰", name: "Files (Nautilus)" },
        { match: "class", pattern: "nemo", icon: "󰝰", name: "Nemo" },
        { match: "class", pattern: "org.kde.dolphin", icon: "", name: "Dolphin" },
        { match: "class", pattern: "pcmanfm", icon: "󰝰", name: "PCManFM" },
        { match: "class", pattern: "ranger", icon: "󰝰", name: "Ranger" },
        { match: "class", pattern: "thunar", icon: "󰝰", name: "Thunar" },
        { match: "class", pattern: "mpv", icon: "", name: "MPV" },
        { match: "class", pattern: "plex", icon: "󰚺", name: "Plex" },
        { match: "class", pattern: "rhythmbox", icon: "󰓃", name: "Rhythmbox" },
        { match: "class", pattern: "ristretto", icon: "󰋩", name: "Ristretto" },
        { match: "class", pattern: "spotify", icon: "󰓇", name: "Spotify" },
        { match: "class", pattern: "vlc", icon: "󰕼", name: "VLC Media Player" },
        { match: "class", pattern: "blender", icon: "󰂫", name: "Blender" },
        { match: "class", pattern: "gimp", icon: "", name: "GIMP" },
        { match: "class", pattern: "inkscape", icon: "", name: "Inkscape" },
        { match: "class", pattern: "krita", icon: "", name: "Krita" },
        { match: "class", pattern: "kdenlive", icon: "", name: "Kdenlive" },
        { match: "class", pattern: "csgo", icon: "󰺵", name: "CS:GO" },
        { match: "class", pattern: "dota2", icon: "󰺵", name: "Dota 2" },
        { match: "class", pattern: "heroic", icon: "󰺵", name: "Heroic Games Launcher" },
        { match: "class", pattern: "lutris", icon: "󰺵", name: "Lutris" },
        { match: "class", pattern: "minecraft", icon: "󰍳", name: "Minecraft" },
        { match: "class", pattern: "steam", icon: "", name: "Steam" },
        { match: "class", pattern: "evernote", icon: "", name: "Evernote" },
        { match: "class", pattern: "libreoffice-base", icon: "", name: "LibreOffice Base" },
        { match: "class", pattern: "libreoffice-calc", icon: "", name: "LibreOffice Calc" },
        { match: "class", pattern: "libreoffice-draw", icon: "", name: "LibreOffice Draw" },
        { match: "class", pattern: "libreoffice-impress", icon: "", name: "LibreOffice Impress" },
        { match: "class", pattern: "libreoffice-math", icon: "", name: "LibreOffice Math" },
        { match: "class", pattern: "libreoffice-writer", icon: "", name: "LibreOffice Writer" },
        { match: "class", pattern: "obsidian", icon: "󱓧", name: "Obsidian" },
        { match: "class", pattern: "sioyek", icon: "", name: "Sioyek" },
        { match: "class", pattern: "libreoffice", icon: "", name: "LibreOffice Default" },
        { match: "title", pattern: "LibreOffice", icon: "", name: "LibreOffice Dialogs" },
        { match: "class", pattern: "soffice", icon: "", name: "LibreOffice Base Selector" },
        { match: "class", pattern: "dropbox", icon: "󰇣", name: "Dropbox" }
    ]
}
