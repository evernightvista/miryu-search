# Fenestra Search

A Windows 11 style search box for the KDE Plasma 6 panel.

Part of the **Fenestra** series, designed in particular for people coming from Windows, so they don't feel lost on a KDE Plasma desktop.

## Features

- **Search box in the panel**, rounded like the Windows 11 taskbar search. Just click it and type: the text appears in the box, the results in a window above it.
- **Search for apps, files, folders and settings** through KRunner, the KDE search engine.
- Results **grouped by category**, an exact match always first (the file name counts without its extension: `report` finds `report.pdf` first).
- **Filters**: All, Apps, Docs, Images, Folders, Web.
- **Calculator**: type `10+10`, the result is shown large at the top; click it to copy it.
- **Document preview**: when the first result is a document, its thumbnail is shown at the top.
- **Web search** as the last line, with the engine of your choice: follow KDE settings (default), DuckDuckGo, Google, Bing, Qwant, Ecosia, Startpage or Brave Search.
- **Home page** when nothing is typed: recent documents, quick searches (Audio, Bluetooth, Wi-Fi, Display, Colors, Wallpaper) and top apps, like the start menu.
- Keyboard: Up / Down, Enter to open, Escape to close.
- Follows light and dark themes.

## Requirements

- **KDE Plasma 6** (Qt 6). Plasma 5 is not supported.
- **Wayland** session. X11 is not supported.

## Installation

### From the KDE Store

Right-click the panel → **Add or Manage Widgets** → **Get New Widgets** → search for **Fenestra Search**.

### Manual

```bash
git clone https://github.com/naykkalak/fenestra-search.git
kpackagetool6 -t Plasma/Applet -i fenestra-search
```

Then right-click the panel → **Add or Manage Widgets** → **Fenestra Search**.

To update a manual install: `kpackagetool6 -t Plasma/Applet -u fenestra-search`.

## Settings

Right-click the search box → **Configure Fenestra Search…**: width of the search box and web search engine.

## Languages

English, Chinese (Simplified), Dutch, French, German, Italian, Japanese, Polish, Portuguese, Russian, Spanish and Turkish. The widget follows the language of your system and falls back to English.

Translations other than French are machine-assisted and **should be reviewed by native speakers**: corrections are welcome (files in `translate/`).

## Credits

- Result ranking inspired by [MFile Search](https://github.com/MCC45TR/kde-plasma6-widgets/tree/main/file-search) by MCC45TR (GPL-3.0).

## Also in the Fenestra series

- [Fenestra Menu 11](https://github.com/naykkalak/fenestra-menu-11): start menu with KDE Connect panel
- [Fenestra Weather](https://github.com/naykkalak/fenestra-weather-icons): weather icon pack
- [Fenestra Weather Widget](https://github.com/naykkalak/fenestra-weather-widget): weather widget
- [Fenestra SDDM](https://github.com/naykkalak/fenestra-sddm): login screen
- [Fenestra This PC](https://github.com/naykkalak/fenestra-ce-pc): “This PC” window

## License

Fenestra Search is distributed under the **GNU General Public License v3.0 or later** (see [LICENSE](LICENSE)).

*Not affiliated with or endorsed by Microsoft. “Windows” is a trademark of Microsoft Corporation and is only used here to describe the style.*
