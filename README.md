# Bangla Keyboard

A small, fast **Bijoy-style Bangla typing engine for Windows**. It sits in a thin always-on-top bar and a tray icon, and lets you type Bangla in **any program**: no clipboard tricks, no installer. Written in AutoHotkey v2.

> **This is a core engine only.** It ships with the typing engine, three layouts, converters and a few helper tools. **No paid or licensed fonts are included.**

**Current version:** 4.2.8

---

## Contents

- [Download](#download)
- [Features](#features)
- [Included Tools](#included-tools-tools-folder)
- [Requirements](#requirements)
- [How to Use](#how-to-use)
- [Folder Structure](#folder-structure)
- [License](#license)
- [Disclaimer](#disclaimer)
- [Credits](#credits)

---

## Download

Get the latest ready-to-run build from the [**Releases**](https://github.com/YummyCyanide/Bangla-Keyboard-Public/releases) page.

1. Download **Bangla Keyboard vX.X.X.exe** (or the `.zip`, if one is attached, and extract it first).
2. Run it. The bar and tray icon appear. No installation needed.
3. Some antivirus tools may flag the exe as a false positive, because it is built with AutoHotkey. The full source code is in this repository so you can verify it yourself.

Prefer to run from source? See [Requirements](#requirements) and [How to Use](#how-to-use).

---

## Features

- **Type Bangla anywhere**: works in any Windows program.
- **Layouts included**: Bijoy Classic (ANSI), Bijoy Unicode and UniBijoy. More can be added or built.
- **Fast switching**: click the tray icon to toggle English / Bangla. Every layout can have its own shortcut key.
- **Mode switching**: one global mode, or let each window/application remember its own.
- **Multi Encoding**: type Unicode and get ANSI (Bijoy style) text in real time, with encodings from the `Library` folder.
- **Bangla Snippet**: a text expander with its own manager tool.
- **Automatic fonts**: the font follows the layout in Word, Excel, PowerPoint, Outlook, WPS Office and LibreOffice / OpenOffice Writer.
- **Quick Fonts**: up to 10 hotkeys, each applying a font and size to the cursor or selection.
- **Ten bar styles** (including Avro Classic [+] and Avro Flat [+]) with 23 colour themes (for the Default styles), adjustable icon size and extra buttons (two, or three in the Avro styles) that launch your own tools.
- **Emoji Picker and On Screen KB**: insert emoji from a small picker at the cursor, or type with an on-screen Bangla keyboard.
- **Performance Helper and error log**: the program is started again if it ever stops unexpectedly, and problems are logged quietly instead of opening error windows.
- **Settings** (9 tabs): General, TopBar Theme, Bangla Snippet, Layouts (all), Multi Encoding, Extra Tools, Auto Fonts, Quick Fonts, Extra Settings, with a per-tab reset to defaults.
- **Portable-friendly**: settings are stored in `%AppData%`, so updates never wipe your choices.

---

## Included Tools (`Tools` folder)

| Tool | What it does |
|---|---|
| **Docs Converter** | Converts Word / PowerPoint documents (and text files) between legacy ANSI fonts (Bijoy, Proshika...) and Unicode. You pick which fonts to convert; the original file is never changed. Every encoding is listed with a tag, `Script: name` (custom) or `Table: name` (standard). |
| **Text Converter** | Two boxes: paste in one, convert to ANSI or Unicode. Encodings come from `Library\Encoding Table` (standard tables) and `Library\Encoding Script` (custom scripts); **Settings > Encodings in the toolbar list** chooses *Encoding Table*, *Encoding Script* or *Table Plus Script*. Hover over the encoding dropdown to see what each kind does. Ctrl + mouse wheel zooms the text. |
| **Bangla Snippet** | Add, edit, find, export and import the texts of the text expander. The expander's options are in **Settings > Bangla Snippet**. |
| **Typing Tutor** | Typing practice and tests with a timer (or a stopwatch). Correct letters turn green, wrong ones red. Texts come from `Tools\Typing Tutor Data`, one `.dat` file per language. The **Test**, **Results** and **History** tabs show the current test, its result and every finished test. |
| **Layout Builder** | Create and edit layouts (`.xml`) with a "Try it" tab for testing. |
| **Quick Note** | A small rich-text editor for Bangla with an automatic recovery draft. Keyboard shortcuts can be customized in **File > Settings**, and **Help > About** lists everything it offers. |
| **Emoji Picker** | A replacement for the Windows emoji panel: it opens at the text cursor or the mouse and types the emoji you pick into the program you are using. It uses nothing while it is not running. |
| **On Screen KB** | An on-screen Bangla keyboard with Bangla and English pages. Resizable (keys and fonts scale with it), light and dark mode, button themes and key font settings. |

The **Performance Helper** is not a tool of this folder: it sits next to `Bangla Keyboard.ahk` and starts by itself (see **Settings > Extra Settings**).

Open the tools from the tray menu, or assign them to the bar's extra buttons (**Settings > TopBar Theme**). Any `.ahk` / `.exe` you drop into `Tools` also appears in the tray menu (as a **Tools** submenu, or as a plain list if you untick the option in **Settings > General**).

---

## Requirements

- Windows (uses Windows APIs, tray, RichEdit and Office COM)
- [AutoHotkey v2](https://www.autohotkey.com/) (the portable exe is fine).
- A Bangla font of your choice. Unicode layouts work with fonts like *Nirmala UI* (built into Windows). ANSI layouts (Bijoy Classic) need a matching ANSI font such as SutonnyMJ, which you must obtain yourself.
- The **Performance Helper** (`Performance Helper.ahk`) must stay next to `Bangla Keyboard.ahk`. It starts by itself and needs AutoHotkey v2 too when you run from source.

---

## How to Use

*(Running from source. If you downloaded the exe from Releases, just run it.)*

0. Just install the installer, else...
1. Install AutoHotkey v2.
2. Download / clone this repo and keep the folder structure intact.
3. Double-click **`Bangla Keyboard.ahk`**. The bar and tray icon appear.
4. Pick a layout from the bar's dropdown, or use the shortcuts below. Start typing.

**Default shortcuts**

| Layout | Shortcut |
|---|---|
| Bijoy Classic | `Ctrl + Alt + B` |
| Bijoy Unicode | `Ctrl + Alt + V` |
| UniBijoy | `Ctrl + Alt + U` |

All of these can be changed in **Settings > Layouts (all)**.

**Tray icon:** single click = toggle English / last Bangla layout, double click = show / hide the bar, right click = menu (layouts, tools, Settings, About, Exit).

**Settings** (nine tabs): *General* (mode, startup, splash, tray, options), *TopBar Theme* (style, colour, icon size, extra buttons), *Bangla Snippet*, *Layouts (all)* (shortcut keys), *Multi Encoding*, *Extra Tools* (shortcut keys for the tools), *Auto Fonts*, *Quick Fonts* and *Extra Settings* (the Performance Helper). Each tab has **Reset**, and nothing is saved until you press **Save**.

**Adding a layout:** drop a `.xml` file into `Layouts` and restart, or build one with the Layout Builder.

### Encoding Script and Encoding Table

The `Library` folder holds two kinds of encoding files:

| | Folder | Files | Best for |
|---|---|---|---|
| **Encoding Table** | `Library\Encoding Table` | `.txt` | **Standard (universal) conversion.** A plain list of ANSI and Unicode pairs, one per line. Simple and general. Read by Text Converter and Docs Converter. |
| **Encoding Script** | `Library\Encoding Script` | `.json` | **Custom, more controlled conversion.** A full set of rules (conjuncts, vowel signs, reph, corrections), the same rules the keyboard uses for Multi Encoding typing. Read by Bangla Keyboard, Text Converter and Docs Converter. |

Use a **Table** for ordinary conversion and a **Script** when you need more control. In **Text Converter**, *Settings > Encodings in the toolbar list* picks what the dropdown shows (*Encoding Table*, *Encoding Script* or *Table Plus Script*; with both, names start with `Script:` or `Table:`). **Docs Converter** always lists everything with the same tags.

**Adding an encoding:** drop a `.json` file into `Library\Encoding Script` and restart. It is listed in the Encoding menu automatically.

**Extra buttons:** in **Settings > TopBar Theme**, tick a button, choose the Tools program it starts and its icon. The [+] styles have two buttons; Avro Flat [+] and Avro Classic [+] have three. The built-in icons are grouped by tool (Docs, Text, Layout, Note); "App icon" keeps the skin's own picture in the Avro styles. For your own, put pictures in `Skins\Button Icons`, reopen Settings, then pick the file name from the icon list.

---

## Folder Structure

```
Bangla Keyboard/
├── Bangla Keyboard.ahk      Main program
├── Performance Helper.ahk   Restarts the program if it ever stops unexpectedly
├── README.md
├── LICENSE
├── Icons/                   Layout icons
├── Layouts/                 Layout files (.xml)
├── Library/
│   ├── Encoding Script/     Encoding files (.json): Unicode typing converted to ANSI
│   └── Encoding Table/      Mapping tables for the converters (.txt)
├── Skins/                   Bar skins and Button Icons; your own skins go here too
│   └── _Template/      Starting point for your own bar skin
├── Splash/                  Splash screen images (png / jpg / bmp)
├── Tools/
│   ├── Docs Converter.ahk
│   ├── Text Converter.ahk
│   ├── Layout Builder.ahk
│   ├── Quick Note.ahk
│   ├── Bangla Snippet.ahk
│   ├── Typing Tutor.ahk
│   ├── Typing Tutor Data/   Texts for the Typing Tutor (.dat)
│   ├── Emoji Picker.ahk
│   ├── On Screen KB.ahk
│   └── Emoji Picker Data/   Emoji pictures and lists for the Emoji Picker
```

---

## License

The source code of this project is released under the **[GNU General Public License v3.0](LICENSE)**. You may use, study, modify and share it, but any redistributed version must stay open source under the same license.

**Not covered by the GPL:** the bar skins, icons, splash images, and any other UI artwork inspired by existing Bangla keyboard software. Those remain the property of their respective owners and are for **non-commercial and personal use only**.

---

## Disclaimer

- This project is **only a core engine**. **No paid, commercial or licensed fonts are included or distributed.** Please obtain any fonts you need legally from their owners.
- All related names, designs and trademarks belong to their respective owners. This project is **not affiliated with or endorsed by** them.
- **I do not sell this app.** That is exactly why it is open source and free. Please do not sell or repackage it as a paid product.
- Provided **as is**, without warranty. Use at your own risk, and keep backups of important documents before bulk-converting them.

---

## Credits

Made by **Sherlock Holmes**, with the assistance of AI.
Issues and suggestions are welcome.

---
