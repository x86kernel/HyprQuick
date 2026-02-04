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
    property string iconFontFamily: "Symbols Nerd Font"
    property int fontSize: 13
    property int fontSizeSmall: 12
    property int iconSize: 15
    property int toastTitleSize: 16
    property int toastBodySize: 14
    property int toastWidth: 360
    property int toastTitleMaxChars: 28
    property int toastGap: 8
    property int toastPadding: 14
    property int toastDuration: 3500
    property int toastAnimDuration: 520
    property int toastSlideOffset: 80
    property int fontWeight: Font.DemiBold
    property string notificationIcon: "󰂚"
    property string cpuIcon: "󰍛"
    property int cpuPollInterval: 2000
    property color cpuText: "#f2a3a3"
    property string memIcon: "󰘚"
    property int memPollInterval: 2000
    property color memText: "#f9e2af"
    property int cpuTooltipWidth: 220
    property int cpuTooltipPadding: 10
    property int cpuTooltipRadius: 10
    property int cpuTooltipOffset: 6
    property int cpuTooltipMaxLines: 3
    property int cpuTooltipPollInterval: 2000
    property color cpuTooltipBg: "#1c1c2b"
    property color cpuTooltipBorder: "transparent"
    property color cpuTooltipText: "#f5c2e7"

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
    property int trayItemGap: 8
    property int trayMinWidth: 40

    property int popupWidth: 360
    property int popupHeight: 320
    property int popupPadding: toastPadding
    property int popupRadius: 14
    property int popupOffset: 8
    property color popupBg: "#181826"
    property color popupBorder: "transparent"

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
