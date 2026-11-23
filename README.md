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
- [Uninstall / Clear Everything](#uninstall--clear-everything)
- [License](#license)
- [Disclaimer](#disclaimer)
- [Credits](#credits)
- [Notes for using it as your main typing program](#notes-for-using-it-as-your-main-typing-program)

---

## Download

Get the latest ready-to-run build from the [**Releases**](https://github.com/YummyCyanide/Bangla-Keyboard/releases/latest) page.

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
- [AutoHotkey v2](https://www.autohotkey.com/) (the portable exe is fine). **Only needed to run from source** (`.ahk` files); the compiled release exe does not need it. Any tool in the `Tools` folder that is still an `.ahk` script also needs it.
- A Bangla font of your choice. Unicode layouts work with fonts like *Nirmala UI* (built into Windows). ANSI layouts (Bijoy Classic) need a matching ANSI font such as SutonnyMJ, which you must obtain yourself.
- Microsoft Office / WPS / LibreOffice is only needed for the automatic-font feature and for converting `.doc`, `.ppt` and similar older formats.
- The **Performance Helper** (`Performance Helper.ahk`) must stay next to `Bangla Keyboard.ahk`. It starts by itself and needs AutoHotkey v2 too when you run from source.

### System requirements for Pupo Encrypter

- Windows 10 or 11 (Windows 7 or later also works with AutoHotkey v2).
- [AutoHotkey v2](https://www.autohotkey.com/) to run `Pupo Encrypter.ahk` from source. A compiled exe needs nothing installed.
- A screen of at least 800 x 600; the window is resizable.
- Almost no resources: a few MB of memory and no extra disk space beyond the files you convert. No internet, no Office and no administrator rights.

---

## How to Use

*(Running from source. If you downloaded the exe from Releases, just run it.)*

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

**Adding an encoding:** drop a `.json` or `.menc` file into `Library\Encoding Script` and restart. It is listed in the Encoding menu automatically. If a `.menc` and a `.json` share a name, the `.menc` is used.

**Extra buttons:** in **Settings > TopBar Theme**, tick a button, choose the Tools program it starts and its icon. The [+] styles have two buttons; Avro Flat [+] and Avro Classic [+] have three. The built-in icons are grouped by tool (Docs, Text, Layout, Note); "App icon" keeps the skin's own picture in the Avro styles. For your own, put pictures in `Skins\Button Icons`, reopen Settings, then pick the file name from the icon list.

---

## Folder Structure

```
Bangla Keyboard/
├── Bangla Keyboard.ahk      Main program
├── Performance Helper.ahk   Restarts the program if it ever stops unexpectedly (started automatically)
├── README.md
├── LICENSE
├── Icons/                   Layout icons
├── Layouts/                 Layout files (.xml)
├── Library/
│   ├── Encoding Script/     Encoding files (.json): Unicode typing converted to ANSI
│   └── Encoding Table/      Mapping tables for the converters (.txt)
├── Skins/                   Bar skins and Button Icons; your own skins go here too
│   └── _Template/      Starting point for your own bar skin (a copy of Bijoy Ekattor)
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

## Uninstall / Clear Everything

There is no installer, so removal is manual:

1. Right-click the tray icon > **Exit**. The Performance Helper closes by itself a moment later (if it still shows in Task Manager, end it there before deleting the folder).
2. If you enabled *Start with Windows*, untick it in **Settings > General** first, or delete `Bangla Keyboard.lnk` from the Startup folder (`Win + R` > `shell:startup`).
3. Delete the program folder.
4. Delete saved settings: `%AppData%\Bangla Keyboard` (`Win + R`, paste the path).
5. Optional: delete the temp file `%Temp%\BanglaKeyboard_tray.ico`.

To only **reset settings**, press **Reset** in each Settings tab, or delete the `%AppData%\Bangla Keyboard` folder. Defaults are restored on next launch. Nothing is written to the registry.

---

## License

The source code of this project is released under the **[GNU General Public License v3.0](LICENSE)**. You may use, study, modify and share it, but any redistributed version must stay open source under the same license.

**Not covered by the GPL:** the bar skins, icons, splash images, and any other UI artwork inspired by existing Bangla keyboard software. Those remain the property of their respective owners and are for **non-commercial and personal use only**.

---

## Disclaimer

- This project is **only a core engine**. **No paid, commercial or licensed fonts are included or distributed.** Please obtain any fonts you need legally from their owners.
- All related names, designs and trademarks belong to their respective owners. This project is **not affiliated with or endorsed by** them.
- **I do not sell this app.** That is exactly why it is open source and free. Please do not sell or repackage it as a paid product.
- `.bkl` and `.een` files are only lightly scrambled to prevent accidental changes. They are **not secure encryption**.
- Provided **as is**, without warranty. Use at your own risk, and keep backups of important documents before bulk-converting them.

---

## Credits

Made by **Sherlock Holmes**, with the assistance of AI.

Issues and suggestions are welcome.

---

## Notes for using it as your main typing program

Bangla Keyboard is light and fast, and many people use it all day. But it is an AutoHotkey program, not a Windows input method (IME), and that has limits. Read these before you depend on it, so nothing surprises you in the middle of important work.

**1. Programs that run as administrator do not accept the typing.**
Windows does not let a normal program send keys into an administrator window (Task Manager, Registry Editor, an administrator Command Prompt, many installers, some accounting or office software that asks for "Run as administrator"). Nothing is shown; the keys just do not arrive.
What to do: the simple way is to start Bangla Keyboard as administrator too. To avoid the "Yes / No" window every time, create a task in Windows **Task Scheduler** that runs Bangla Keyboard **at log on** with **"Run with highest privileges"**, and untick *Start with Windows* in Settings > General (its startup shortcut cannot run as administrator silently). The price: the program and the tools you start from it then run with administrator rights, and dragging files into it from a normal Explorer window may stop working. An advanced option is a signed "UI access" build kept in `Program Files`; it types into administrator windows without running as administrator, but it needs set-up and is not included here.

**2. Secure Windows screens cannot be typed into.**
The "Yes / No" permission window (UAC), the lock screen, the sign-in screen and the Ctrl + Alt + Del screen are protected by Windows. No Bangla typing program can work there. Use English, or the on-screen keyboard of Windows, for passwords typed there.

**3. Remote Desktop, virtual machines and games.**
Keys sent by Bangla Keyboard may be blocked, arrive as English letters, or be ignored inside Remote Desktop, virtual machines, Citrix-type windows and many games. Some games with anti-cheat protection also dislike any program that sends keys. Switch Bangla off there (see *Mode switching* in Settings > General, so each program can keep its own mode), or use the keyboard set-up of the remote machine.

**4. It is not a Windows IME.**
There is no underlined "composition" text and no candidate list. The program sends the finished letters. Most programs work perfectly, but a few ignore, delay or reorder such text: some older Java or Swing programs, some terminal windows, some CAD and ERP programs, and some Store (UWP) or web-based input boxes. Test the programs you use every day before you trust it.

**5. Avro Phonetic rewrites what you just typed.**
While you type a word, Avro replaces the last letters with better ones. Auto-complete and auto-correct (Word AutoCorrect, the browser address bar, Excel AutoComplete, chat suggestions) can get in the way, **Ctrl + Z** may undo in small steps, and on a very slow program fast typing may look garbled for a moment. Finish a word with **Space** and keep the cursor where it is until the word is done. The Bijoy-style layouts type each letter directly and do not have this problem.

**6. A very busy or old PC.**
When the CPU is at 100 % (video rendering, big exports) or memory is nearly full, Windows may deliver keys late. The program is light and runs at a higher priority, but it cannot beat a frozen computer. Close heavy programs first, or give the machine more memory.

**7. If the program stops, typing stops.**
The Performance Helper starts Bangla Keyboard again after a crash or a kill, but it cannot tell that a program is frozen while it is still running. If the bar is on screen but nothing types, choose **Exit** from the tray menu and start it again, then look at `%AppData%\Bangla Keyboard\error.log`. The helper gives up after 3 restarts within 2 minutes, and shows a message when it does.

**8. Other keyboard software can clash.**
Another Bangla keyboard (Avro, Bijoy, Keyman), other AutoHotkey scripts, the software of a gaming keyboard, and the Windows language switch (Alt + Shift, Win + Space) can grab the same keys. Use one at a time, and change the shortcut keys in **Settings > Layouts (all)** if two programs use the same ones.

**9. Security software.**
A program that watches the keyboard and sends keys looks like a keylogger to some antivirus tools and company policies, and an exe built with AutoHotkey is often flagged by mistake. If it is blocked or quarantined, add an exclusion for its folder. The scripts in this package contain no network code, so what you type does not leave your computer, and you can read the source to check.

**10. ANSI text versus Unicode text.**
Bijoy Classic (ANSI) needs a matching ANSI font that is not included, and ANSI text pasted into a Unicode program (or the other way round) shows as garbage until it is converted (use **Text Converter** or **Docs Converter**). Unicode text depends on the program and the font to draw conjuncts correctly: older Office versions and some web forms may show them badly.

**11. Each window remembers its own mode.**
If you use *Per Application/Window* mode, a program that opens a new window or dialog may start it in the default mode. Look at the bar before you start typing in a new window.

**12. Good habits.**
- Keep *Start with Windows* and the Performance Helper switched on.
- Back up `%AppData%\Bangla Keyboard` now and then (your settings, snippets and layout choices).
- When you update, replace the program folder and keep your own layouts, skins and encodings aside; test the new version for a day before relying on it.
- If something goes wrong, `error.log` and `helper.log` in `%AppData%\Bangla Keyboard` tell what happened; send them with your report.
