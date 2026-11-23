#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
ListLines(false)                  ; no line history: less memory and CPU
KeyHistory(0)                     ; this tool installs a key hook: no key history logging
SetTimer(TrimMemory, -3000)         ; once, shortly after start: hand unused memory back to Windows

; ============================================================
;  Quick Note - a small rich-text editor (AutoHotkey v2)
;  Uses the Windows RichEdit 5.0 control (Msftedit.dll)
; ============================================================

APP := "Quick Note"
APP_VER := "3.1.6"         ; same as Bangla Keyboard
DEF_FONT := "Nirmala UI"   ; default font for new documents (has Bangla glyphs; Calibri is used if it is missing)
DEF_SIZE := 12             ; default size (pt)
PAD_OUT := 0               ; space between window edge and the editor (px)
PAD_IN := 8                ; space between the editor border and the text (px)
PS := A_PtrSize

; settings file: %AppData%\Bangla Keyboard\Quick Note.dat
SETTINGS_DIR := A_AppData "\Bangla Keyboard"
SETTINGS_INI := SETTINGS_DIR "\Quick Note.dat"
REC_RTF := SETTINGS_DIR "\Quick Note Recovery.rtf"          ; auto-saved draft (crash recovery)
REC_META := SETTINGS_DIR "\Quick Note Recovery.dat"
if !FileExist(SETTINGS_INI) {
    for prevName in ["easy_note_settings.ini", "qnt_cfg.dat"] {              ; names used by earlier builds
        if FileExist(SETTINGS_DIR "\" prevName) {
            try FileMove(SETTINGS_DIR "\" prevName, SETTINGS_INI)
            break
        }
    }
}
MAX_RECENT := 8

; toolbar geometry (px)
TB_X := 6                  ; left/right margin
TB_Y := 5                  ; top margin
TB_H := 24                 ; button height
TB_BW := 28                ; icon button width
TB_TW := 24                ; B / I / U / S button width
TB_GAP := 2                ; gap between buttons
TB_SEP := 12               ; gap between button groups
TB := []                   ; toolbar items, left to right
GRP := Map("file", 1, "font", 1, "style", 1, "clip", 1, "undo", 1, "color", 1, "align", 1, "find", 1)  ; toolbar sections shown
SBTXT := ["", "", "", "", ""]  ; status bar texts (needed for the dark, owner-drawn status bar)
DK_BG := 0x202020          ; dark theme: window
DK_ED := 0x1B1B1B          ; dark theme: editor
DK_TXT := 0xE0E0E0         ; dark theme: text (RTF save swaps this colour for black, see WriteFile)

CoordMode "Mouse", "Screen"
CoordMode "Caret", "Screen"
CoordMode "Menu", "Screen"

; --- application state -------------------------------------
S := {file: "", enc: "UTF-8", fmt: false, wrap: false, closing: false, saved: false, cleanExit: false, starting: true, reopen: true, last: "", recent: [], fontOnly: false, langDef: 0, words: 0, top: TB_Y * 2 + TB_H, sbOn: true, aot: false
    , dark: false, defFont: DEF_FONT, defSize: DEF_SIZE, zoom: 100, hasPos: false, maxed: false, pl: 0, pt: 0, pw: 0, ph: 0}
STR := {data: "", size: 0, pos: 0, out: "", opos: 0}
ENCMAP := Map("UTF-8", "UTF-8-RAW", "UTF-8 with BOM", "UTF-8", "UTF-16 LE", "UTF-16", "ANSI", "CP0")
SIZES := [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 32, 36, 48, 72]
SIZEIDX := Map()
for i, v in SIZES
    SIZEIDX[v] := i

; file dialog filters: [description, pattern, default extension]
SAVE_FILTERS := [["Plain Text (*.txt)", "*.txt", "txt"]
    , ["Rich Text Format (*.rtf)", "*.rtf", "rtf"]
    , ["Markdown (*.md)", "*.md", "md"]
    , ["Log File (*.log)", "*.log", "log"]
    , ["All Files (*.*)", "*.*", ""]]
OPEN_FILTERS := [["All Supported Files", "*.txt;*.rtf;*.md;*.log;*.ini;*.csv", ""]
    , ["Plain Text (*.txt)", "*.txt", ""]
    , ["Rich Text Format (*.rtf)", "*.rtf", ""]
    , ["Markdown (*.md)", "*.md", ""]
    , ["Log File (*.log)", "*.log", ""]
    , ["All Files (*.*)", "*.*", ""]]

DllCall("LoadLibrary", "Str", "Msftedit.dll")

; --- font list ---------------------------------------------
FONTS := Map()
FCS := Map()                               ; font name -> set of charsets it was enumerated with
FONTARR := BuildFontList()
FONTIDX := Map()
FONTIDX.CaseSense := false
for i, v in FONTARR
    FONTIDX[v] := i
; --- keyboard shortcuts: the ones listed in File > Settings can be changed (ed = only while the typing area has the focus) ---
; Cut, copy, paste, undo, redo and select all (Ctrl+X / C / V / Z / Y / A) are handled by the editor itself and are not listed.
ACT := [{id: "New", label: "New", def: "^n", ed: false, fn: (*) => NewDoc()}
    , {id: "Open", label: "Open...", def: "^o", ed: false, fn: (*) => OpenDlg()}
    , {id: "Save", label: "Save", def: "^s", ed: false, fn: (*) => Save()}
    , {id: "SaveAs", label: "Save As...", def: "^+s", ed: false, fn: (*) => SaveAs()}
    , {id: "Print", label: "Print...", def: "^p", ed: false, fn: (*) => PrintDoc()}
    , {id: "Find", label: "Find / Replace...", def: "^f", ed: false, fn: (*) => ShowFind()}
    , {id: "Replace", label: "Replace (opens the same window)", def: "^h", ed: false, fn: (*) => ShowFind()}
    , {id: "FindNext", label: "Find Next", def: "F3", ed: false, fn: (*) => FindNext()}
    , {id: "FindPrev", label: "Find Previous", def: "+F3", ed: false, fn: (*) => FindNext(-1)}
    , {id: "GoTo", label: "Go To Line...", def: "^g", ed: false, fn: (*) => GotoLine()}
    , {id: "DateTime", label: "Insert Date/Time", def: "F5", ed: false, fn: (*) => InsertDateTime()}
    , {id: "Bold", label: "Bold", def: "^b", ed: false, fn: (*) => Toggle(1)}
    , {id: "Italic", label: "Italic", def: "^i", ed: false, fn: (*) => Toggle(2)}
    , {id: "Underline", label: "Underline", def: "^u", ed: false, fn: (*) => Toggle(4)}
    , {id: "Strike", label: "Strikethrough", def: "^+x", ed: false, fn: (*) => Toggle(8)}
    , {id: "AlignLeft", label: "Align Left", def: "^l", ed: true, fn: (*) => SetAlign(1)}
    , {id: "AlignCenter", label: "Align Center", def: "^e", ed: true, fn: (*) => SetAlign(3)}
    , {id: "AlignRight", label: "Align Right", def: "^r", ed: true, fn: (*) => SetAlign(2)}
    , {id: "Bullet", label: "Bulleted List", def: "^+l", ed: true, fn: (*) => ToggleBullet()}
    , {id: "Indent", label: "Increase Indent", def: "^]", ed: true, fn: (*) => Indent(360)}
    , {id: "Outdent", label: "Decrease Indent", def: "^[", ed: true, fn: (*) => Indent(-360)}
    , {id: "ZoomIn", label: "Zoom In", def: "^NumpadAdd", ed: false, fn: (*) => ZoomBy(10)}
    , {id: "ZoomOut", label: "Zoom Out", def: "^NumpadSub", ed: false, fn: (*) => ZoomBy(-10)}
    , {id: "ZoomReset", label: "Restore Default Zoom", def: "^0", ed: false, fn: (*) => ZoomReset()}
    , {id: "Wrap", label: "Word Wrap on / off", def: "", ed: false, fn: (*) => SetWrap(!S.wrap)}
    , {id: "Top", label: "Always on Top on / off", def: "", ed: false, fn: (*) => ToggleAOT()}
    , {id: "Status", label: "Status Bar on / off", def: "", ed: false, fn: (*) => ToggleStatusBar()}
    , {id: "Theme", label: "Light / Dark theme", def: "", ed: false, fn: (*) => SetTheme(!S.dark)}]
SK := Map()            ; action id -> shortcut in use ("" = none)
MREG := []             ; menu items that show a shortcut (kept up to date when it changes)
TREG := []             ; toolbar buttons that show a shortcut in their tool tip
SETDLG := ""           ; the Settings / About windows while they are open, and the key recorder
SETST := ""
ABOUTDLG := ""
KB_IH := ""
LoadSettings()
LoadShortcuts()
if !FONTIDX.Has(S.defFont)
    S.defFont := FONTIDX.Has("Calibri") ? "Calibri" : "Segoe UI"

; Toolbar icons come from the Segoe MDL2 Assets font that ships with Windows 10/11.
; If it is missing, the buttons fall back to text labels.
ICONFONT := "Segoe MDL2 Assets"
HAS_ICONS := FONTIDX.Has(ICONFONT)
TIPS := Map()                          ; control hwnd -> tooltip text

; --- main window -------------------------------------------
G := Gui("+Resize +E0x10 +MinSize320x240", APP)
G.SetFont("s9", "Segoe UI")

; One toolbar row made of sections (each can be shown/hidden from View > Toolbar):
; file | font | style | clipboard | undo/redo | colour | alignment/list | find.
; Buttons that do not fit the window width are hidden from the right and come back as it grows.
RegTip(IBtn(0xE7C3, "New", TipText("New", "New"), (*) => NewDoc(), "file"), "New", "New")
RegTip(IBtn(0xE838, "Open", TipText("Open...", "Open"), (*) => OpenDlg(), "file"), "Open...", "Open")
RegTip(IBtn(0xE74E, "Save", TipText("Save", "Save"), (*) => Save(), "file"), "Save", "Save")
RegTip(IBtn(0xE792, "Save As", TipText("Save As...", "SaveAs"), (*) => SaveAs(), "file"), "Save As...", "SaveAs")

; editable combo boxes: pick from the list, or type a value and press Enter
fontBox := G.Add("ComboBox", "x0 y0 w150 r16 -TabStop", FONTARR)
fontBox.OnCommand(1, FontSel)               ; CBN_SELCHANGE (list pick)
TBPush(fontBox, 150, "font", "Font - pick one, or type a name and press Enter", true)
sizeBox := G.Add("ComboBox", "x0 y0 w52 r16 -TabStop", SIZES)
sizeBox.OnCommand(1, SizeSel)
TBPush(sizeBox, 52, "font", "Font size - pick one, or type a size and press Enter", true)

bBold := RegTip(Tgl("B", TipText("Bold", "Bold"), (*) => Toggle(1), "bold", "style"), "Bold", "Bold")
bItalic := RegTip(Tgl("I", TipText("Italic", "Italic"), (*) => Toggle(2), "italic", "style"), "Italic", "Italic")
bUnder := RegTip(Tgl("U", TipText("Underline", "Underline"), (*) => Toggle(4), "underline", "style"), "Underline", "Underline")
bStrike := RegTip(Tgl("S", TipText("Strikethrough", "Strike"), (*) => Toggle(8), "strike", "style"), "Strikethrough", "Strike")

IBtn(0xE8C6, "Cut", "Cut (Ctrl+X)", (*) => EditCmd(0x300), "clip")
IBtn(0xE8C8, "Copy", "Copy (Ctrl+C)", (*) => EditCmd(0x301), "clip")
IBtn(0xE77F, "Paste", "Paste (Ctrl+V)", (*) => EditCmd(0x302), "clip")

IBtn(0xE7A7, "Undo", "Undo (Ctrl+Z)", (*) => EditCmd(0xC7), "undo")
IBtn(0xE7A6, "Redo", "Redo (Ctrl+Y)", (*) => EditCmd(0x454), "undo")

IBtn(0xE790, "Color", "Text color", (*) => PickColor(), "color")
IBtn(0xE7E6, "Highlight", "Highlight color", (*) => PickHighlight(), "color")

IBtn(0xE8E4, "Left", "Align left", (*) => SetAlign(1), "align")
IBtn(0xE8E3, "Center", "Align center", (*) => SetAlign(3), "align")
IBtn(0xE8E2, "Right", "Align right", (*) => SetAlign(2), "align")
bBul := IBtn(0xE8FD, "• List", "Bulleted list", (*) => ToggleBullet(), "align", "CheckBox")

RegTip(IBtn(0xE721, "Find", TipText("Find / Replace", "Find"), (*) => ShowFind(), "find"), "Find / Replace", "Find")

; Rich edit control
re := G.Add("Custom", "ClassRICHEDIT50W x0 y34 w900 h500 +0x200000 +0x100000 +0x4 +0x40 +0x80 +0x1000 +0x100 +0x10000 -Border")

; Status bar
sb := G.Add("StatusBar")
sb.SetParts(210, 200, 60, 95)

; --- menus ---------------------------------------------------
fileMenu := Menu()
AddMI(fileMenu, "New", "New", (*) => NewDoc())
AddMI(fileMenu, "Open", "Open...", (*) => OpenDlg())
AddMI(fileMenu, "Save", "Save", (*) => Save())
AddMI(fileMenu, "SaveAs", "Save As...", (*) => SaveAs())
fileMenu.Add()
recentMenu := Menu()
recentMenu.Add("(none)", (*) => 0)           ; placeholder, rebuilt by RebuildRecent()
fileMenu.Add("Recent Files", recentMenu)
fileMenu.Add("Reopen Last File at Startup", (*) => ToggleReopen())
fileMenu.Add()
AddMI(fileMenu, "Print", "Print...", (*) => PrintDoc())
fileMenu.Add("Export as PDF...", (*) => PrintDoc(true))
fileMenu.Add()
fileMenu.Add("Settings...", (*) => ShowSettings())
fileMenu.Add()
fileMenu.Add("Exit", (*) => GuiClose())

toolsMenu := Menu()
toolsMenu.Add("UPPERCASE", (*) => TextTool("upper"))
toolsMenu.Add("lowercase", (*) => TextTool("lower"))
toolsMenu.Add("Title Case", (*) => TextTool("title"))
toolsMenu.Add()
toolsMenu.Add("Sort Lines A-Z", (*) => TextTool("sort"))
toolsMenu.Add("Remove Duplicate Lines", (*) => TextTool("dedupe"))
toolsMenu.Add("Trim Trailing Spaces", (*) => TextTool("trim"))

editMenu := Menu()
editMenu.Add("Undo`tCtrl+Z", (*) => EditCmd(0xC7))
editMenu.Add("Redo`tCtrl+Y", (*) => EditCmd(0x454))
editMenu.Add()
editMenu.Add("Cut`tCtrl+X", (*) => EditCmd(0x300))
editMenu.Add("Copy`tCtrl+C", (*) => EditCmd(0x301))
editMenu.Add("Paste`tCtrl+V", (*) => EditCmd(0x302))
editMenu.Add("Select All`tCtrl+A", (*) => (Msg(0xB1, 0, -1), FocusEd()))
editMenu.Add()
AddMI(editMenu, "Find", "Find / Replace...", (*) => ShowFind())
AddMI(editMenu, "FindNext", "Find Next", (*) => FindNext())
AddMI(editMenu, "FindPrev", "Find Previous", (*) => FindNext(-1))
AddMI(editMenu, "GoTo", "Go To Line...", (*) => GotoLine())
editMenu.Add()
AddMI(editMenu, "DateTime", "Insert Date/Time", (*) => InsertDateTime())
editMenu.Add()
editMenu.Add("Text Tools", toolsMenu)

encMenu := Menu()
for n in ENCMAP
    encMenu.Add(n, (name, *) => SetEnc(name))

spacingMenu := Menu()
spacingMenu.Add("Single", (*) => SetSpacing(0))
spacingMenu.Add("1.5 lines", (*) => SetSpacing(1))
spacingMenu.Add("Double", (*) => SetSpacing(2))

formatMenu := Menu()
formatMenu.Add("Text Color...", (*) => PickColor())
formatMenu.Add("Highlight Color...", (*) => PickHighlight())
formatMenu.Add("Remove Highlight", (*) => (SetCF(0x04000000, 0x04000000), FocusEd()))
formatMenu.Add("Reset Text Color", (*) => (SetCF(0x40000000, 0x40000000), FocusEd()))
formatMenu.Add("Clear Formatting", (*) => ClearFormatting())
formatMenu.Add()
formatMenu.Add("Increase Font Size", (*) => (Msg(0x4DF, 1), FocusEd(), UpdateToolbar()))
formatMenu.Add("Decrease Font Size", (*) => (Msg(0x4DF, -1), FocusEd(), UpdateToolbar()))
formatMenu.Add()
AddMI(formatMenu, "AlignLeft", "Align Left", (*) => SetAlign(1))
AddMI(formatMenu, "AlignCenter", "Align Center", (*) => SetAlign(3))
AddMI(formatMenu, "AlignRight", "Align Right", (*) => SetAlign(2))
AddMI(formatMenu, "Bullet", "Bulleted List", (*) => ToggleBullet())
formatMenu.Add("Numbered List", (*) => ToggleNumbered())
AddMI(formatMenu, "Indent", "Increase Indent", (*) => Indent(360))
AddMI(formatMenu, "Outdent", "Decrease Indent", (*) => Indent(-360))
formatMenu.Add("Line Spacing", spacingMenu)
formatMenu.Add()
formatMenu.Add("Superscript", (*) => ToggleScript(0x20000))
formatMenu.Add("Subscript", (*) => ToggleScript(0x10000))
formatMenu.Add()
formatMenu.Add("No Automatic Font Switching (for ANSI fonts)", (*) => SetFontOnly(!S.fontOnly))
formatMenu.Add()
formatMenu.Add("Encoding (for plain text)", encMenu)

viewMenu := Menu()
AddMI(viewMenu, "ZoomIn", "Zoom In", (*) => ZoomBy(10))
AddMI(viewMenu, "ZoomOut", "Zoom Out", (*) => ZoomBy(-10))
AddMI(viewMenu, "ZoomReset", "Restore Default Zoom", (*) => ZoomReset())
viewMenu.Add()
tbMenu := Menu()
for def in [["file", "New / Open / Save"], ["font", "Font and size"], ["style", "Bold / Italic / Underline / Strike"]
    , ["clip", "Cut / Copy / Paste"], ["undo", "Undo / Redo"], ["color", "Text and highlight color"]
    , ["align", "Alignment and bullets"], ["find", "Find"]] {
    tbMenu.Add(def[2], ToggleGroup.Bind(def[1], def[2]))
    if GRP[def[1]]
        tbMenu.Check(def[2])
}
viewMenu.Add("Toolbar", tbMenu)
themeMenu := Menu()
themeMenu.Add("Light", (*) => SetTheme(false))
themeMenu.Add("Dark", (*) => SetTheme(true))
themeMenu.Check(S.dark ? "Dark" : "Light")
viewMenu.Add("Theme", themeMenu)
viewMenu.Add()
viewMenu.Add("Status Bar", (*) => ToggleStatusBar())
viewMenu.Add("Always on Top", (*) => ToggleAOT())
viewMenu.Add("Word Wrap", (*) => SetWrap(!S.wrap))
if S.sbOn
    viewMenu.Check("Status Bar")
if S.aot
    viewMenu.Check("Always on Top")

helpMenu := Menu()
helpMenu.Add("Keyboard Shortcuts...", (*) => ShowSettings())
helpMenu.Add("About", (*) => ShowAbout())

mb := MenuBar()
mb.Add("&File", fileMenu)
mb.Add("&Edit", editMenu)
mb.Add("F&ormat", formatMenu)
mb.Add("&View", viewMenu)
mb.Add("&Help", helpMenu)
G.MenuBar := mb
RebuildRecent()
if S.reopen
    fileMenu.Check("Reopen Last File at Startup")
if S.aot
    G.Opt("+AlwaysOnTop")
if !S.sbOn
    sb.Visible := false

; --- right-click menu ----------------------------------------
CM_UNDO := "Undo`tCtrl+Z"
CM_REDO := "Redo`tCtrl+Y"
CM_CUT := "Cut`tCtrl+X"
CM_COPY := "Copy`tCtrl+C"
CM_PASTE := "Paste`tCtrl+V"
CM_DEL := "Delete`tDel"
CM_ALL := "Select All`tCtrl+A"
CM_BOLD := "Bold" . ScTab("Bold")
CM_ITAL := "Italic" . ScTab("Italic")
CM_UND := "Underline" . ScTab("Underline")
CM_STR := "Strikethrough" . ScTab("Strike")
CM_BUL := "Bulleted List"

alignMenu := Menu()
alignMenu.Add("Left", (*) => SetAlign(1))
alignMenu.Add("Center", (*) => SetAlign(3))
alignMenu.Add("Right", (*) => SetAlign(2))

ctxMenu := Menu()
ctxMenu.Add(CM_UNDO, (*) => EditCmd(0xC7))
ctxMenu.Add(CM_REDO, (*) => EditCmd(0x454))
ctxMenu.Add()
ctxMenu.Add(CM_CUT, (*) => EditCmd(0x300))
ctxMenu.Add(CM_COPY, (*) => EditCmd(0x301))
ctxMenu.Add(CM_PASTE, (*) => EditCmd(0x302))
ctxMenu.Add(CM_DEL, (*) => (InsertText(""), FocusEd()))
ctxMenu.Add()
ctxMenu.Add(CM_ALL, (*) => (Msg(0xB1, 0, -1), FocusEd()))
ctxMenu.Add()
AddMI(ctxMenu, "Bold", "Bold", (*) => Toggle(1))
AddMI(ctxMenu, "Italic", "Italic", (*) => Toggle(2))
AddMI(ctxMenu, "Underline", "Underline", (*) => Toggle(4))
AddMI(ctxMenu, "Strike", "Strikethrough", (*) => Toggle(8))
ctxMenu.Add()
ctxMenu.Add("Text Color...", (*) => PickColor())
ctxMenu.Add("Highlight Color...", (*) => PickHighlight())
ctxMenu.Add("Clear Formatting", (*) => ClearFormatting())
ctxMenu.Add()
ctxMenu.Add("Align", alignMenu)
ctxMenu.Add(CM_BUL, (*) => ToggleBullet())
ctxMenu.Add()
AddMI(ctxMenu, "Find", "Find / Replace...", (*) => ShowFind())
AddMI(ctxMenu, "DateTime", "Insert Date/Time", (*) => InsertDateTime())

; --- find / replace dialog -----------------------------------
FD := Gui("+Owner" G.Hwnd " +ToolWindow", "Find and Replace")
FD.SetFont("s9", "Segoe UI")
FD.MarginX := 12
FD.MarginY := 12
FD.Add("Text", "x12 y17 w80", "Find what:")
fFind := FD.Add("Edit", "x97 y14 w220")
FD.Add("Text", "x12 y49 w80", "Replace with:")
fRepl := FD.Add("Edit", "x97 y46 w220")
cCase := FD.Add("CheckBox", "x12 y84", "Match case")
cWord := FD.Add("CheckBox", "x122 y84", "Whole word")
cRegex := FD.Add("CheckBox", "x12 y110 w200", "Regular expression")
FD.Add("Button", "x332 y12 w95 h26 Default", "Find Next").OnEvent("Click", (*) => FindNext())
FD.Add("Button", "x332 y44 w95 h26", "Find Previous").OnEvent("Click", (*) => FindNext(-1))
FD.Add("Button", "x332 y76 w95 h26", "Replace").OnEvent("Click", (*) => ReplaceOne())
FD.Add("Button", "x332 y108 w95 h26", "Replace All").OnEvent("Click", (*) => ReplaceAll())
FD.Add("Button", "x332 y140 w95 h26", "Close").OnEvent("Click", (*) => FD.Hide())
FD.OnEvent("Close", (*) => FD.Hide())
FD.OnEvent("Escape", (*) => FD.Hide())

; --- events + show ------------------------------------------
G.OnEvent("Close", GuiClose)
G.OnEvent("Size", GuiSize)
G.OnEvent("DropFiles", GuiDrop)
re.OnCommand(0x300, ReChange)          ; EN_CHANGE
re.OnNotify(0x702, ReSelChange)        ; EN_SELCHANGE
re.OnNotify(0x703, ReDropFiles)        ; EN_DROPFILES
re.OnNotify(0x70B, ReLink)             ; EN_LINK (Ctrl+click opens a web link)

OnMessage(0x6, ActivateMsg)
OnMessage(0x2B, DrawItemMsg)               ; owner-drawn status bar (dark)
OnMessage(0x91, UahDrawMenu)               ; dark menu bar
OnMessage(0x92, UahDrawMenuItem)
OnMessage(0x85, UahNcPaint)
OnMessage(0x86, UahNcPaint)
if S.dark
    ApplyTheme()
OnExit((*) => Shutdown())
if S.hasPos {
    wp := Buffer(44, 0)                    ; WINDOWPLACEMENT
    NumPut("UInt", 44, "UInt", 0, "UInt", S.maxed ? 3 : 1, wp, 0)
    NumPut("Int", S.pl, "Int", S.pt, "Int", S.pl + S.pw, "Int", S.pt + S.ph, wp, 28)
    DllCall("SetWindowPlacement", "Ptr", G.Hwnd, "Ptr", wp)
} else
    G.Show("w900 h620")

Msg(0x445, 0, 0x4180001)               ; ENM_CHANGE | ENM_SELCHANGE | ENM_DROPFILES | ENM_LINK
Msg(0x45B, 1, 0)                       ; detect web links while typing
S.langDef := Msg(0x479)                ; EM_GETLANGOPTIONS (original auto-font behaviour)
SetFontOnly(S.fontOnly)
DllCall("shell32\DragAcceptFiles", "Ptr", re.Hwnd, "Int", 1)
SetWrap(S.wrap)
ResetFormat()
if S.zoom != 100
    Msg(0x4E1, S.zoom, 100)
SetEncState()
ResizeAll()
UpdateTitle()
UpdateStatus()
UpdateToolbar()
FocusEd()
SetTimer(ZoomTick, 400)
SetTimer(HoverTick, 100)

if A_Args.Length {
    argPath := A_Args[1]
    if !RegExMatch(argPath, "^[A-Za-z]:|^\\\\")
        argPath := A_WorkingDir "\" argPath
    OpenFile(argPath)
} else if !RestoreRecovery() && S.reopen && S.last != "" && FileExist(S.last)
    OpenFile(S.last)
S.starting := false
CountWords()
SetTimer(AutoSave, 30000)
ApplyShortcuts()

; ============================================================
;  Functions
; ============================================================

; Toolbar button with an icon glyph (falls back to a text label)
IBtn(glyph, label, tip, fn, grp, kind := "Button") {
    w := HAS_ICONS ? TB_BW : 56
    c := G.Add(kind, "x0 y0 w" w " h" TB_H " -TabStop" (kind = "CheckBox" ? " +0x1000" : "")
        , HAS_ICONS ? Chr(glyph) : label)
    if HAS_ICONS
        c.SetFont("s10", ICONFONT)
    c.OnEvent("Click", fn)
    TBPush(c, w, grp, tip)
    return c
}

; Push-button style toggle (B / I / U / S)
Tgl(text, tip, fn, fontOpt, grp) {
    c := G.Add("CheckBox", "x0 y0 w" TB_TW " h" TB_H " -TabStop +0x1000", text)
    c.SetFont(fontOpt)
    c.OnEvent("Click", fn)
    TBPush(c, TB_TW, grp, tip)
    return c
}

; Register a control in the toolbar order; grp = the View > Toolbar section it belongs to
TBPush(c, w, grp, tip, isCombo := false) {
    y := TB_Y
    if isCombo {
        ch := SendMessage(0x154, -1, 0, c) + 6      ; CB_GETITEMHEIGHT(-1) + frame = closed height
        y += Max(0, (TB_H - ch) // 2)
        e := DllCall("FindWindowExW", "Ptr", c.Hwnd, "Ptr", 0, "Str", "Edit", "Ptr", 0, "Ptr")
        if e
            TIPS[e] := tip                          ; tooltip also over the combo's edit part
    }
    TIPS[c.Hwnd] := tip
    TB.Push({c: c, w: w, g: grp, y: y, x: -1, vis: -1})
}

AnyGroup() {
    for k, v in GRP {
        if v
            return true
    }
    return false
}

ToggleGroup(key, label, *) {
    GRP[key] := !GRP[key]
    if GRP[key]
        tbMenu.Check(label)
    else
        tbMenu.Uncheck(label)
    ResizeAll()
}

; Place the visible sections in one row; hide whatever no longer fits
LayoutToolbar(cw) {
    x := TB_X
    full := false
    prev := ""
    for it in TB {
        if !GRP[it.g] || full {
            if it.vis != 0 {
                it.c.Visible := false
                it.vis := 0
            }
            continue
        }
        if prev != ""
            x += (prev = it.g) ? TB_GAP : TB_SEP
        if x + it.w > cw - TB_X {
            full := true
            if it.vis != 0 {
                it.c.Visible := false
                it.vis := 0
            }
            continue
        }
        prev := it.g
        if it.x != x {
            it.c.Move(x, it.y)
            it.x := x
        }
        if it.vis != 1 {
            it.c.Visible := true
            it.vis := 1
        }
        x += it.w
    }
}

; Show a tooltip when the mouse rests on a toolbar control
HoverTick() {
    if S.closing
        return
    static lastH := 0, ticks := 0
    MouseGetPos(, , , &h, 2)
    if (h && TIPS.Has(h)) {
        if GetKeyState("LButton") {
            ToolTip()
            ticks := 99
            lastH := h
            return
        }
        if h = lastH {
            ticks++
            if ticks = 4
                ToolTip(TIPS[h])
        } else {
            lastH := h
            ticks := 0
            ToolTip()
        }
    } else if lastH {
        ToolTip()
        lastH := 0
        ticks := 0
    }
}

; Select an item in a DropDownList without firing its Change event (0 = nothing)
SelectItem(ctrl, idx) {
    SendMessage(0x14E, idx - 1, 0, ctrl)       ; CB_SETCURSEL
}

; Set the edit text of a ComboBox without firing any event of ours
SetComboText(ctrl, txt) {
    txt := "" txt
    SendMessage(0xC, 0, StrPtr(txt), ctrl)     ; WM_SETTEXT
}

; Does keyboard focus sit in this control (or in a child of it, like a ComboBox's edit)?
FocusIn(ctrl) {
    h := DllCall("GetFocus", "Ptr")
    return h && (h = ctrl.Hwnd || DllCall("IsChild", "Ptr", ctrl.Hwnd, "Ptr", h))
}

Hint(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -1800)
}

; Send a message to the RichEdit control
Msg(m, w := 0, l := 0) {
    return DllCall("SendMessageW", "Ptr", re.Hwnd, "UInt", m
        , "Ptr", IsObject(w) ? w.Ptr : w
        , "Ptr", IsObject(l) ? l.Ptr : l, "Ptr")
}

EditCmd(m) {
    Msg(m)
    FocusEd()
}

; Windows may re-select everything when the window is re-activated: put the old selection back
ActivateMsg(wParam, lParam, m, hwnd) {
    static saved := 0
    if hwnd != G.Hwnd || S.closing
        return
    if (wParam & 0xFFFF) = 0 {
        saved := FocusIn(re) ? GetSel() : 0
    } else if saved {
        prev := saved
        saved := 0
        SetTimer(RestoreSel.Bind(prev), -10)
    }
}

RestoreSel(old) {
    if S.closing || !FocusIn(re)
        return
    cur := GetSel()
    len := Msg(0xE)
    ; only undo the "select all" side effect, never a real change of selection
    if cur[1] = 0 && cur[2] >= len && !(old[1] = 0 && old[2] >= len) {
        cr := Buffer(8, 0)
        NumPut("Int", Min(old[1], len), "Int", Min(old[2], len), cr, 0)
        Msg(0x437, 0, cr)
    }
}

InsertText(txt) {
    Msg(0xC2, 1, StrPtr(txt))     ; EM_REPLACESEL
}

InsertDateTime() {
    InsertText(FormatTime(, "h:mm tt M/d/yyyy"))
    FocusEd()
}

; ---------- fonts -------------------------------------------
BuildFontList() {
    lf := Buffer(92, 0)
    NumPut("UChar", 1, lf, 23)                 ; DEFAULT_CHARSET
    cb := CallbackCreate(FontCB, , 4)
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    DllCall("gdi32\EnumFontFamiliesExW", "Ptr", hdc, "Ptr", lf, "Ptr", cb, "Ptr", 0, "UInt", 0)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    CallbackFree(cb)
    list := ""
    for name in FONTS
        list .= name "`n"
    list := Sort(Trim(list, "`n"))
    return StrSplit(list, "`n")
}

FontCB(lpelfe, lpntme, ftype, lparam) {
    name := StrGet(lpelfe + 28, "UTF-16")
    if name != "" && SubStr(name, 1, 1) != "@" {
        FONTS[name] := 1
        if !FCS.Has(name)
            FCS[name] := Map()
        FCS[name][NumGet(lpelfe, 23, "UChar")] := 1     ; lfCharSet of this enumerated face
    }
    return 1
}

; ---------- character formatting ------------------------------
GetCF() {
    cf := Buffer(116, 0)
    NumPut("UInt", 116, cf, 0)
    Msg(0x43A, 1, cf)             ; EM_GETCHARFORMAT, SCF_SELECTION
    return cf
}

SetCF(mask, effects := 0, height := 0, color := 0, face := "", back := 0, cs := -1) {
    if cs >= 0
        mask |= 0x08000000                     ; CFM_CHARSET
    cf := Buffer(116, 0)
    NumPut("UInt", 116, "UInt", mask, "UInt", effects, "Int", height, cf, 0)
    NumPut("UInt", color, cf, 20)
    if cs >= 0
        NumPut("UChar", cs, cf, 24)
    if face != ""
        StrPut(face, cf.Ptr + 26, 31, "UTF-16")
    NumPut("UInt", back, cf, 96)
    Msg(0x444, 1, cf)             ; EM_SETCHARFORMAT, SCF_SELECTION
    S.fmt := true
}

; Legacy "ANSI" Bangla fonts (SutonnyMJ, Lipikar ANSI...) only exist in the ANSI (or Symbol) charset.
; RichEdit must be told that, otherwise it swaps in another font for characters like the oe ligature.
; Returns that charset (0 or 2), or 1 (DEFAULT_CHARSET) for normal Unicode fonts.
FontCharset(name) {
    if FCS.Has(name) && FCS[name].Count = 1 {
        for cs, v in FCS[name] {
            if cs = 0 || cs = 2
                return cs
        }
    }
    return 1
}

DefaultCF() {
    cf := Buffer(116, 0)
    mask := 0x80000000 | 0x40000000 | 0x20000000 | 0x04000000 | 0x08000000 | 0x0F
    NumPut("UInt", 116, "UInt", mask, "UInt", S.dark ? 0x04000000 : 0x44000000, "Int", Round(S.defSize * 20), cf, 0)
    if S.dark
        NumPut("UInt", DK_TXT, cf, 20)
    NumPut("UChar", FontCharset(S.defFont), cf, 24)
    StrPut(S.defFont, cf.Ptr + 26, 31, "UTF-16")
    return cf
}

ResetFormat() {
    cf := DefaultCF()
    Msg(0x444, 0, cf)             ; SCF_DEFAULT
    Msg(0x444, 4, cf)             ; SCF_ALL
}

ClearFormatting() {
    Msg(0x444, 1, DefaultCF())
    FocusEd()
    UpdateToolbar()
}

Toggle(bit) {
    cf := GetCF()
    isOn := (NumGet(cf, 4, "UInt") & bit) && (NumGet(cf, 8, "UInt") & bit)
    SetCF(bit, isOn ? 0 : bit)
    FocusEd()
    UpdateToolbar()
}

; Font / size picked from a list
FontSel(*) {
    idx := SendMessage(0x147, 0, 0, fontBox)    ; CB_GETCURSEL
    if idx >= 0 && idx < FONTARR.Length
        ApplyFontName(FONTARR[idx + 1])
}

SizeSel(*) {
    idx := SendMessage(0x147, 0, 0, sizeBox)
    if idx >= 0 && idx < SIZES.Length
        ApplySizePt(SIZES[idx + 1])
}

; Font / size typed by hand (Enter)
CommitFont() {
    name := Trim(ControlGetText(fontBox))
    if name = "" {
        CancelCombo()
        return
    }
    if !FONTIDX.Has(name) {
        Hint('Font not found: "' name '"')
        return
    }
    ApplyFontName(FONTARR[FONTIDX[name]])
}

CommitSize() {
    t := StrReplace(Trim(ControlGetText(sizeBox)), ",", ".")
    if !RegExMatch(t, "^\d+(\.\d+)?$") || t + 0 < 1 || t + 0 > 1638 {
        Hint("Enter a font size from 1 to 1638")
        return
    }
    ApplySizePt(Number(t))
}

ApplyFontName(name) {
    SetCF(0x20000000, 0, 0, 0, name, 0, FontCharset(name))
    if CanRemember()
        S.defFont := name
    FocusEd()
    SetTimer(UpdateToolbar, -40)
}

ApplySizePt(pt) {
    SetCF(0x80000000, 0, Round(pt * 20))
    if CanRemember()
        S.defSize := pt
    FocusEd()
    SetTimer(UpdateToolbar, -40)
}

; A font/size choice becomes the default for new text only when nothing is selected
; or the whole document is selected (so styling one heading does not change the default).
CanRemember() {
    sel := GetSel()
    return sel[1] = sel[2] || (sel[1] = 0 && sel[2] >= Msg(0xE))
}

InCombo() {
    return FocusIn(fontBox) || FocusIn(sizeBox)
}

CommitCombo() {
    isFont := FocusIn(fontBox)
    cb := isFont ? fontBox : sizeBox
    if SendMessage(0x157, 0, 0, cb) {          ; CB_GETDROPPEDSTATE: list open, use highlighted item
        idx := SendMessage(0x147, 0, 0, cb)
        SendMessage(0x14F, 0, 0, cb)           ; CB_SHOWDROPDOWN false
        if isFont && idx >= 0 && idx < FONTARR.Length {
            ApplyFontName(FONTARR[idx + 1])
            return
        }
        if !isFont && idx >= 0 && idx < SIZES.Length {
            ApplySizePt(SIZES[idx + 1])
            return
        }
    }
    if isFont
        CommitFont()
    else
        CommitSize()
}

CancelCombo() {
    for cb in [fontBox, sizeBox] {
        if FocusIn(cb) && SendMessage(0x157, 0, 0, cb) {
            SendMessage(0x14F, 0, 0, cb)       ; just close an open list
            return
        }
    }
    FocusEd()
    UpdateToolbar()                            ; put the real font/size back
}

PickColor() {
    c := ChooseColor()
    if c = -1
        return
    SetCF(0x40000000, 0, 0, c)
    FocusEd()
}

PickHighlight() {
    c := ChooseColor()
    if c = -1
        return
    SetCF(0x04000000, 0, 0, 0, "", c)
    FocusEd()
}

ChooseColor(init := 0) {
    static cust := Buffer(64, 0)
    cc := Buffer(9 * PS, 0)
    NumPut("UInt", 9 * PS, cc, 0)
    NumPut("Ptr", G.Hwnd, cc, PS)
    NumPut("UInt", init, cc, 3 * PS)
    NumPut("Ptr", cust.Ptr, cc, 4 * PS)
    NumPut("UInt", 0x103, cc, 5 * PS)          ; CC_RGBINIT | CC_FULLOPEN | CC_ANYCOLOR
    if !DllCall("comdlg32\ChooseColorW", "Ptr", cc, "Int")
        return -1
    return NumGet(cc, 3 * PS, "UInt")
}

; ---------- paragraph formatting --------------------------------
SetAlign(a) {
    pf := Buffer(188, 0)
    NumPut("UInt", 188, "UInt", 0x8, pf, 0)    ; PFM_ALIGNMENT
    NumPut("UShort", a, pf, 24)
    Msg(0x447, 0, pf)
    S.fmt := true
    FocusEd()
}

IsBullet() {
    pf := Buffer(188, 0)
    NumPut("UInt", 188, pf, 0)
    Msg(0x43D, 0, pf)
    return ((NumGet(pf, 4, "UInt") & 0x20) && NumGet(pf, 8, "UShort") = 1) ? 1 : 0
}

ToggleBullet() {
    isOn := IsBullet()
    pf2 := Buffer(188, 0)
    NumPut("UInt", 188, "UInt", 0x25, pf2, 0)  ; start indent | offset | numbering
    NumPut("UShort", isOn ? 0 : 1, pf2, 8)
    NumPut("Int", 0, "Int", 0, "Int", isOn ? 0 : 360, pf2, 12)
    Msg(0x447, 0, pf2)
    S.fmt := true
    FocusEd()
    UpdateToolbar()
}

IsNumbered() {
    pf := Buffer(188, 0)
    NumPut("UInt", 188, pf, 0)
    Msg(0x43D, 0, pf)
    return ((NumGet(pf, 4, "UInt") & 0x20) && NumGet(pf, 8, "UShort") >= 2) ? 1 : 0
}

ToggleNumbered() {
    isOn := IsNumbered()
    pf := Buffer(188, 0)
    NumPut("UInt", 188, "UInt", 0x25 | 0x2000 | 0x8000, pf, 0)   ; indent | offset | numbering | style | start
    NumPut("UShort", isOn ? 0 : 2, pf, 8)                        ; PFN_ARABIC
    NumPut("Int", 0, "Int", 0, "Int", isOn ? 0 : 360, pf, 12)
    NumPut("UShort", 1, pf, 176)
    NumPut("UShort", isOn ? 0 : 0x200, pf, 178)                  ; PFNS_PERIOD  ->  1.  2.  3.
    Msg(0x447, 0, pf)
    S.fmt := true
    FocusEd()
    UpdateToolbar()
}

Indent(delta) {
    pf := Buffer(188, 0)
    NumPut("UInt", 188, pf, 0)
    Msg(0x43D, 0, pf)
    cur := NumGet(pf, 12, "Int")
    pf2 := Buffer(188, 0)
    NumPut("UInt", 188, "UInt", 0x1, pf2, 0)                     ; PFM_STARTINDENT
    NumPut("Int", Max(0, cur + delta), pf2, 12)
    Msg(0x447, 0, pf2)
    S.fmt := true
    FocusEd()
}

SetSpacing(rule) {                                               ; 0 single, 1 one and a half, 2 double
    pf := Buffer(188, 0)
    NumPut("UInt", 188, "UInt", 0x100, pf, 0)                    ; PFM_LINESPACING
    NumPut("UChar", rule, pf, 170)
    Msg(0x447, 0, pf)
    S.fmt := true
    FocusEd()
}

ToggleScript(bit) {                                              ; 0x20000 superscript, 0x10000 subscript
    cf := GetCF()
    isOn := (NumGet(cf, 4, "UInt") & bit) && (NumGet(cf, 8, "UInt") & bit)
    SetCF(0x30000, isOn ? 0 : bit)
    FocusEd()
}

; Stop RichEdit from swapping fonts per character (fixes legacy ANSI fonts if the charset fix is not enough)
SetFontOnly(on) {
    S.fontOnly := on
    opts := S.langDef
    if on
        opts := opts & ~(0x2 | 0x10 | 0x80)    ; IMF_AUTOFONT | IMF_AUTOFONTSIZEADJUST | IMF_DUALFONT
    Msg(0x478, 0, opts)                        ; EM_SETLANGOPTIONS
    if on
        formatMenu.Check("No Automatic Font Switching (for ANSI fonts)")
    else
        formatMenu.Uncheck("No Automatic Font Switching (for ANSI fonts)")
    DllCall("InvalidateRect", "Ptr", re.Hwnd, "Ptr", 0, "Int", 1)
}

; ---------- view settings ----------------------------------------
SetWrap(wrapOn) {
    S.wrap := wrapOn
    Msg(0x448, 0, wrapOn ? 0 : 1)
    if wrapOn
        viewMenu.Check("Word Wrap")
    else
        viewMenu.Uncheck("Word Wrap")
}

GetZoom() {
    n := Buffer(4, 0)
    d := Buffer(4, 0)
    Msg(0x4E0, n, d)
    nn := NumGet(n, 0, "UInt")
    dd := NumGet(d, 0, "UInt")
    return (nn && dd) ? Round(nn * 100 / dd) : 100
}

ZoomBy(delta) {
    z := Min(500, Max(20, GetZoom() + delta))
    Msg(0x4E1, z, 100)
    UpdateStatus()
}

ZoomReset() {
    Msg(0x4E1, 0, 0)
    UpdateStatus()
}

ZoomTick() {
    if S.closing
        return
    SBSet("  " GetZoom() "%", 3)
}

ToggleStatusBar() {
    S.sbOn := !S.sbOn
    sb.Visible := S.sbOn
    if S.sbOn
        viewMenu.Check("Status Bar")
    else
        viewMenu.Uncheck("Status Bar")
    ResizeAll()
}

ToggleAOT() {
    S.aot := !S.aot
    G.Opt(S.aot ? "+AlwaysOnTop" : "-AlwaysOnTop")
    if S.aot
        viewMenu.Check("Always on Top")
    else
        viewMenu.Uncheck("Always on Top")
}

GuiSize(gObj, minMax, w, h) {
    if minMax = -1
        return
    ResizeAll()
}

ResizeAll() {
    G.GetClientPos(, , &w, &h)
    S.top := AnyGroup() ? TB_Y * 2 + TB_H : 0
    LayoutToolbar(w)
    sbH := 0
    if S.sbOn
        sb.GetPos(, , , &sbH)
    re.Move(PAD_OUT, S.top, Max(w - 2 * PAD_OUT, 50), Max(h - S.top - sbH - PAD_OUT, 50))
    ApplyPadding()
}

; Inner padding: keep the text away from the edit control's border
ApplyPadding() {
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", re.Hwnd, "Ptr", rc)
    cw := NumGet(rc, 8, "Int")
    ch := NumGet(rc, 12, "Int")
    r := Buffer(16, 0)
    NumPut("Int", PAD_IN, "Int", PAD_IN
        , "Int", Max(cw - PAD_IN, PAD_IN + 10), "Int", Max(ch - PAD_IN, PAD_IN + 10), r, 0)
    Msg(0xB3, 0, r)                            ; EM_SETRECT
}

; ---------- UI state sync ----------------------------------------
ReChange(*) {
    if S.closing
        return
    SetTimer(CountWords, -300)
    UpdateTitle()
    UpdateStatus()
}

ReSelChange(ctrl, lParam) {
    if S.closing
        return
    UpdateStatus()
    UpdateToolbar()
}

UpdateTitle() {
    name := "Untitled"
    if S.file != ""
        SplitPath(S.file, &name)
    mark := IsDirty() ? "*" : ""
    t := mark name " - " APP
    if G.Title != t
        G.Title := t
}

UpdateStatus() {
    if S.closing
        return
    cr := Buffer(8, 0)
    Msg(0x434, 0, cr)                          ; EM_EXGETSEL
    a := NumGet(cr, 0, "Int")
    b := NumGet(cr, 4, "Int")
    line := Msg(0x436, 0, b)                   ; EM_EXLINEFROMCHAR
    col := b - Msg(0xBB, line) + 1             ; EM_LINEINDEX
    ln := line + 1
    pos := "  Ln " ln ", Col " col
    if b > a {
        cnt := b - a
        pos .= " (" cnt " sel"
        if cnt <= 200000 {
            RegExReplace(GetSelText(), "\S+", "", &wc)
            pos .= ", " wc " words"
        }
        pos .= ")"
    }
    total := Msg(0xE)
    ext := ""
    if S.file != ""
        SplitPath(S.file, , , &ext)
    kind := (StrLower(ext) = "rtf" || S.fmt) ? "Rich Text" : "Plain Text"
    SBSet(pos, 1)
    SBSet("  " S.words " words, " total " chars", 2)
    SBSet("  " GetZoom() "%", 3)
    SBSet("  " kind, 4)
    SBSet("  " S.enc, 5)
}

UpdateToolbar() {
    if S.closing
        return
    cf := GetCF()
    mask := NumGet(cf, 4, "UInt")
    eff := NumGet(cf, 8, "UInt")
    for pair in [[bBold, 1], [bItalic, 2], [bUnder, 4], [bStrike, 8]]
        pair[1].Value := ((mask & pair[2]) && (eff & pair[2])) ? 1 : 0

    if !FocusIn(fontBox) {
        if (mask & 0x20000000) {
            name := StrGet(cf.Ptr + 26, "UTF-16")
            if FONTIDX.Has(name)
                SelectItem(fontBox, FONTIDX[name])
            else
                SetComboText(fontBox, name)
        } else
            SelectItem(fontBox, 0)
    }

    if !FocusIn(sizeBox) {
        if (mask & 0x80000000) {
            v := NumGet(cf, 12, "Int") / 20
            if v = Round(v) && SIZEIDX.Has(Integer(v))
                SelectItem(sizeBox, SIZEIDX[Integer(v)])
            else
                SetComboText(sizeBox, v = Round(v) ? Round(v) : Round(v, 1))
        } else
            SelectItem(sizeBox, 0)
    }

    bBul.Value := IsBullet()
}

SetEncState() {
    for n in ENCMAP
        encMenu.Uncheck(n)
    encMenu.Check(S.enc)
}

SetEnc(name) {
    S.enc := name
    SetEncState()
    Msg(0xB9, 1)                               ; mark modified
    UpdateTitle()
    UpdateStatus()
}

; ---------- file dialogs -------------------------------------------
; Native Open/Save dialog with several file-type entries.
; filters: array of [description, pattern, default extension]
; Returns {path, idx} or "" if cancelled.
FileDialog(isSave, title, filters, initDir := "", initName := "", initIdx := 1) {
    total := 4
    for f in filters
        total += StrLen(f[1]) + StrLen(f[2]) + 2
    fb := Buffer(total * 2 + 8, 0)
    off := 0
    for f in filters {
        off += StrPut(f[1], fb.Ptr + off, StrLen(f[1]) + 1, "UTF-16") * 2
        off += StrPut(f[2], fb.Ptr + off, StrLen(f[2]) + 1, "UTF-16") * 2
    }

    fileBuf := Buffer(65536, 0)
    if initName != ""
        StrPut(initName, fileBuf.Ptr, 32767, "UTF-16")

    if PS = 8
        o := {sz: 152, file: 48, max: 56, dir: 80, title: 88, flags: 96}
    else
        o := {sz: 88, file: 28, max: 32, dir: 44, title: 48, flags: 52}

    ; OFN_EXPLORER | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY | OFN_NOCHANGEDIR + (overwrite prompt | file must exist)
    flags := isSave ? 0x8080E : 0x8180C

    ofn := Buffer(o.sz, 0)
    NumPut("UInt", o.sz, ofn, 0)
    NumPut("Ptr", G.Hwnd, ofn, PS)
    NumPut("Ptr", fb.Ptr, ofn, 3 * PS)
    NumPut("UInt", initIdx, ofn, 5 * PS + 4)
    NumPut("Ptr", fileBuf.Ptr, ofn, o.file)
    NumPut("UInt", 32767, ofn, o.max)
    NumPut("Ptr", StrPtr(initDir), ofn, o.dir)
    NumPut("Ptr", StrPtr(title), ofn, o.title)
    NumPut("UInt", flags, ofn, o.flags)

    if isSave
        ok := DllCall("comdlg32\GetSaveFileNameW", "Ptr", ofn, "Int")
    else
        ok := DllCall("comdlg32\GetOpenFileNameW", "Ptr", ofn, "Int")
    if !ok
        return ""
    return {path: StrGet(fileBuf.Ptr, "UTF-16"), idx: NumGet(ofn, 5 * PS + 4, "UInt")}
}

; ---------- file handling ------------------------------------------
; Modified, and not just an empty never-saved document
IsDirty() {
    return Msg(0xB8) && !(S.file = "" && Msg(0xE) = 0)
}

ConfirmSave() {
    if !IsDirty()
        return true
    name := "Untitled"
    if S.file != ""
        SplitPath(S.file, &name)
    r := MsgBox("Do you want to save changes to " name "?", APP, "YesNoCancel Icon! Owner" G.Hwnd)
    if r = "Yes"
        return Save()
    return r = "No"
}

NewDoc() {
    if !ConfirmSave()
        return
    ClearDoc()
    DeleteRecovery()
    S.file := ""
    S.enc := "UTF-8"
    S.fmt := false
    SetEncState()
    Msg(0xB9, 0)
    UpdateTitle()
    UpdateStatus()
    UpdateToolbar()
    FocusEd()
}

ClearDoc() {
    empty := ""
    DllCall("SendMessageW", "Ptr", re.Hwnd, "UInt", 0xC, "Ptr", 0, "Ptr", StrPtr(empty), "Ptr")
    ResetFormat()
    Msg(0xCD)                                  ; EM_EMPTYUNDOBUFFER
}

OpenDlg() {
    dir := A_MyDocuments
    if S.file != ""
        SplitPath(S.file, , &dir)
    r := FileDialog(false, "Open", OPEN_FILTERS, dir, "", 1)
    if r
        OpenFile(r.path)
}

OpenFile(path) {
    attr := FileExist(path)
    if attr = "" || InStr(attr, "D") {
        MsgBox("File not found:`n" path, APP, "Icon! Owner" G.Hwnd)
        return
    }
    if !ConfirmSave()
        return
    try {
        buf := FileRead(path, "RAW")
    } catch as e {
        MsgBox("Could not open the file:`n" e.Message, APP, "Iconx Owner" G.Hwnd)
        return
    }
    SplitPath(path, , , &ext)
    encName := "UTF-8"
    ClearDoc()
    if StrLower(ext) = "rtf" {
        StreamIn(2, buf, buf.Size)             ; SF_RTF
        if S.dark
            ThemeTextColor()
        S.fmt := true
    } else {
        text := Decode(buf, &encName)
        if text != ""
            LoadPlain(text)
        S.fmt := false
    }
    S.file := path
    S.enc := encName
    AddRecent(path)
    if !S.starting
        DeleteRecovery()
    Msg(0xB1, 0, 0)
    Msg(0xCD)
    Msg(0xB9, 0)
    SetEncState()
    UpdateTitle()
    UpdateStatus()
    UpdateToolbar()
    FocusEd()
}

Decode(buf, &encName) {
    n := buf.Size
    p := buf.Ptr
    if n = 0 {
        encName := "UTF-8"
        return ""
    }
    b0 := NumGet(p, 0, "UChar")
    b1 := n > 1 ? NumGet(p, 1, "UChar") : 0
    b2 := n > 2 ? NumGet(p, 2, "UChar") : 0
    if (n >= 3 && b0 = 0xEF && b1 = 0xBB && b2 = 0xBF) {
        encName := "UTF-8 with BOM"
        return StrGet(p + 3, n - 3, "UTF-8")
    }
    if (n >= 2 && b0 = 0xFF && b1 = 0xFE) {
        encName := "UTF-16 LE"
        return StrGet(p + 2, (n - 2) // 2, "UTF-16")
    }
    if (n >= 2 && b0 = 0xFE && b1 = 0xFF) {
        encName := "UTF-16 LE"                  ; big-endian: swap bytes, saved as LE
        sw := Buffer(n - 2, 0)
        i := 0
        while i + 1 < n - 2 {
            NumPut("UChar", NumGet(p, 2 + i + 1, "UChar"), sw, i)
            NumPut("UChar", NumGet(p, 2 + i, "UChar"), sw, i + 1)
            i += 2
        }
        return StrGet(sw, (n - 2) // 2, "UTF-16")
    }
    ok := DllCall("MultiByteToWideChar", "UInt", 65001, "UInt", 8, "Ptr", p, "Int", n, "Ptr", 0, "Int", 0, "Int")
    if ok {
        encName := "UTF-8"
        return StrGet(p, n, "UTF-8")
    }
    encName := "ANSI"
    return StrGet(p, n, "CP0")
}

LoadPlain(text) {
    cnt := StrLen(text)
    buf := Buffer(cnt * 2 + 2, 0)
    StrPut(text, buf, cnt, "UTF-16")
    StreamIn(0x11, buf, cnt * 2)               ; SF_TEXT | SF_UNICODE
}

Save() {
    if S.file = ""
        return SaveAs()
    return WriteFile(S.file)
}

SaveAs() {
    dir := A_MyDocuments
    name := S.fmt ? "Untitled.rtf" : "Untitled.txt"
    idx := S.fmt ? 2 : 1
    if S.file != "" {
        SplitPath(S.file, &name, &dir, &cur)
        for i, f in SAVE_FILTERS {
            if f[3] != "" && StrLower(cur) = f[3] {
                idx := i
                break
            }
        }
    }
    r := FileDialog(true, "Save As", SAVE_FILTERS, dir, name, idx)
    if !r
        return false
    path := r.path
    SplitPath(path, , , &ext)
    if ext = "" {
        dext := SAVE_FILTERS[r.idx][3]         ; extension of the chosen file type
        if dext = ""
            dext := S.fmt ? "rtf" : "txt"
        path .= "." dext
        if FileExist(path) && MsgBox(path "`nalready exists. Replace it?", "Save As", "YesNo Icon! Owner" G.Hwnd) != "Yes"
            return false
    }
    return WriteFile(path)
}

WriteFile(path) {
    SplitPath(path, , , &ext)
    isRtf := (StrLower(ext) = "rtf")
    if !isRtf && S.fmt {
        r := MsgBox("This document has formatting that plain text cannot store.`n`n"
            . "Yes = save as RTF instead`nNo = save as plain text (formatting is lost)`nCancel = go back"
            , APP, "YesNoCancel Icon! Owner" G.Hwnd)
        if r = "Cancel"
            return false
        if r = "Yes" {
            newPath := ext = "" ? path ".rtf" : SubStr(path, 1, StrLen(path) - StrLen(ext)) "rtf"
            if FileExist(newPath) && MsgBox(newPath "`nalready exists. Replace it?", "Save As", "YesNo Icon! Owner" G.Hwnd) != "Yes"
                return false
            path := newPath
            isRtf := true
        }
    }
    try {
        if isRtf {
            rb := RtfBytes()
            f := FileOpen(path, "w")
            f.RawWrite(rb.buf, rb.n)
            f.Close()
        } else {
            f := FileOpen(path, "w", ENCMAP[S.enc])
            f.Write(GetPlainText())
            f.Close()
        }
    } catch as e {
        MsgBox("Could not save the file:`n" e.Message, APP, "Iconx Owner" G.Hwnd)
        return false
    }
    S.file := path
    if !isRtf
        S.fmt := false
    Msg(0xB9, 0)
    AddRecent(path)
    DeleteRecovery()
    UpdateTitle()
    UpdateStatus()
    return true
}

GetPlainText() {
    buf := StreamOut(0x11)                     ; SF_TEXT | SF_UNICODE
    if STR.opos < 2
        return ""
    text := StrGet(buf, STR.opos // 2, "UTF-16")
    text := StrReplace(text, "`r`n", "`n")
    text := StrReplace(text, "`r", "`n")
    return StrReplace(text, "`n", "`r`n")
}

; ---------- RichEdit streaming ---------------------------------------
StreamIn(fmt, buf, size, h := 0) {
    STR.data := buf
    STR.size := size
    STR.pos := 0
    cb := CallbackCreate(StreamRead, , 4)
    es := Buffer(2 * PS + 4, 0)                ; EDITSTREAM (pack 4)
    NumPut("Ptr", cb, es, PS + 4)
    if h
        DllCall("SendMessageW", "Ptr", h, "UInt", 0x449, "Ptr", fmt, "Ptr", es, "Ptr")
    else
        Msg(0x449, fmt, es)                    ; EM_STREAMIN
    CallbackFree(cb)
}

StreamRead(cookie, pbBuff, cb, pcb) {
    cb &= 0xFFFFFFFF
    n := Min(cb, STR.size - STR.pos)
    if n > 0 {
        DllCall("RtlMoveMemory", "Ptr", pbBuff, "Ptr", STR.data.Ptr + STR.pos, "UPtr", n)
        STR.pos += n
    } else
        n := 0
    NumPut("Int", n, pcb)
    return 0
}

StreamOut(fmt) {
    STR.out := Buffer(8192, 0)
    STR.opos := 0
    cb := CallbackCreate(StreamWrite, , 4)
    es := Buffer(2 * PS + 4, 0)
    NumPut("Ptr", cb, es, PS + 4)
    Msg(0x44A, fmt, es)                        ; EM_STREAMOUT
    CallbackFree(cb)
    return STR.out
}

StreamWrite(cookie, pbBuff, cb, pcb) {
    cb &= 0xFFFFFFFF
    if cb > 0 {
        need := STR.opos + cb
        if need > STR.out.Size
            STR.out.Size := Max(need, STR.out.Size * 2)
        DllCall("RtlMoveMemory", "Ptr", STR.out.Ptr + STR.opos, "Ptr", pbBuff, "UPtr", cb)
        STR.opos += cb
    }
    NumPut("Int", cb, pcb)
    return 0
}

; ---------- drag & drop -------------------------------------------------
GuiDrop(gObj, ctrl, files, x, y) {
    if files.Length
        SetTimer(OpenFile.Bind(files[1]), -10)
}

ReDropFiles(ctrl, lParam) {
    hDrop := NumGet(lParam, 3 * PS, "Ptr")
    cnt := DllCall("shell32\DragQueryFileW", "Ptr", hDrop, "UInt", 0xFFFFFFFF, "Ptr", 0, "UInt", 0, "UInt")
    if cnt {
        len := DllCall("shell32\DragQueryFileW", "Ptr", hDrop, "UInt", 0, "Ptr", 0, "UInt", 0, "UInt")
        pb := Buffer((len + 1) * 2, 0)
        DllCall("shell32\DragQueryFileW", "Ptr", hDrop, "UInt", 0, "Ptr", pb, "UInt", len + 1)
        SetTimer(OpenFile.Bind(StrGet(pb, "UTF-16")), -10)
    }
    return 1                                   ; we handled it
}

GuiClose(*) {
    if S.closing
        return true
    if !ConfirmSave()
        return true
    S.cleanExit := true
    ExitApp()
}

; Stop everything that touches the window, save settings once, hide at once (no visible lag)
Shutdown() {
    if S.closing
        return
    if S.cleanExit
        DeleteRecovery()                       ; the user chose to save or discard: no draft needed
    else
        AutoSave()                             ; closed some other way (log off...): keep a draft
    S.closing := true
    SetTimer(AutoSave, 0)
    SetTimer(CountWords, 0)
    SetTimer(HoverTick, 0)
    SetTimer(ZoomTick, 0)
    SetTimer(UpdateToolbar, 0)
    ToolTip()
    SaveSettings()
    try FD.Hide()
    try G.Hide()
}

; ---------- light / dark theme -----------------------------------------
SetTheme(dark) {
    S.dark := dark
    themeMenu.Uncheck(dark ? "Light" : "Dark")
    themeMenu.Check(dark ? "Dark" : "Light")
    ApplyTheme()
}

SetWinTheme(h, name := "") {
    if name = ""
        DllCall("uxtheme\SetWindowTheme", "Ptr", h, "Ptr", 0, "Ptr", 0)
    else
        DllCall("uxtheme\SetWindowTheme", "Ptr", h, "Str", name, "Ptr", 0)
}

ApplyTheme() {
    dark := S.dark ? 1 : 0
    ; dark popup menus (Windows 10 1809 or newer; silently ignored before that)
    hUx := DllCall("LoadLibrary", "Str", "uxtheme.dll", "Ptr")
    if f := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
        DllCall(f, "Int", dark ? 2 : 0)
    if f := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 136, "Ptr")
        DllCall(f)

    for gw in [G, FD] {
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gw.Hwnd, "Int", 20, "Int*", dark, "Int", 4)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gw.Hwnd, "Int", 19, "Int*", dark, "Int", 4)
        gw.BackColor := dark ? "202020" : "Default"
        ThemeControls(gw)
    }

    ; editor
    SetWinTheme(re.Hwnd, dark ? "DarkMode_Explorer" : "")
    if dark
        Msg(0x443, 0, DK_ED)                   ; EM_SETBKGNDCOLOR
    else
        Msg(0x443, 1, 0)
    ThemeTextColor()

    ; status bar: classic look so its background colour can be set; parts are owner-drawn when dark
    if dark
        DllCall("uxtheme\SetWindowTheme", "Ptr", sb.Hwnd, "Str", "", "Str", "")
    else
        SetWinTheme(sb.Hwnd)
    SendMessage(0x2001, 0, dark ? DK_BG : 0xFF000000, sb)   ; SB_SETBKCOLOR
    Loop 5
        SBTXT[A_Index] := ""
    UpdateStatus()

    DllCall("DrawMenuBar", "Ptr", G.Hwnd)
    DllCall("SetWindowPos", "Ptr", G.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x27)
}

; Text colour of the whole document follows the theme
ThemeTextColor() {
    cf := Buffer(116, 0)
    NumPut("UInt", 116, "UInt", 0x40000000, "UInt", S.dark ? 0 : 0x40000000, cf, 0)
    NumPut("UInt", DK_TXT, cf, 20)
    wasMod := Msg(0xB8)
    Msg(0x444, 0, cf)                          ; default
    Msg(0x444, 4, cf)                          ; all text
    Msg(0xB9, wasMod)
}

ThemeControls(gw) {
    dark := S.dark
    for hwnd, c in gw {
        t := c.Type
        if t = "Button" || (t = "CheckBox" && (ControlGetStyle(c) & 0x1000))
            SetWinTheme(hwnd, dark ? "DarkMode_Explorer" : "")
        else if t = "CheckBox"
            c.Opt(dark ? "-Theme cE0E0E0" : "+Theme cDefault")
        else if t = "Text"
            c.Opt(dark ? "cE0E0E0" : "cDefault")
        else if t = "Edit" {
            c.Opt(dark ? "+Background2B2B2B cE0E0E0" : "-Background cDefault")
            SetWinTheme(hwnd, dark ? "DarkMode_CFD" : "")
        } else if t = "ListView" {
            c.Opt(dark ? "+Background2B2B2B cE0E0E0" : "-Background cDefault")
            SetWinTheme(hwnd, dark ? "DarkMode_Explorer" : "")
        } else if t = "ComboBox" {
            SetWinTheme(hwnd, dark ? "DarkMode_CFD" : "")
            info := Buffer(40 + 3 * PS, 0)     ; COMBOBOXINFO: the drop-down list gets a dark scrollbar
            NumPut("UInt", info.Size, info, 0)
            if DllCall("GetComboBoxInfo", "Ptr", hwnd, "Ptr", info)
                SetWinTheme(NumGet(info, 40 + 2 * PS, "Ptr"), dark ? "DarkMode_Explorer" : "")
            c.Opt(dark ? "+Background2B2B2B cE0E0E0" : "-Background cDefault")
        }
    }
}

; Status bar text: plain in light mode, owner-drawn (see DrawItemMsg) in dark mode
SBSet(text, n) {
    if SBTXT[n] == text
        return
    SBTXT[n] := text
    if S.dark
        SendMessage(0x40B, (n - 1) | 0x1000, n - 1, sb)   ; SB_SETTEXTW | SBT_OWNERDRAW, item data = part index
    else
        sb.SetText(text, n)
}

DrawItemMsg(wParam, lParam, m, hwnd) {
    if !S.dark || hwnd != G.Hwnd
        return
    if NumGet(lParam, PS = 8 ? 24 : 20, "Ptr") != sb.Hwnd
        return
    hdc := NumGet(lParam, PS = 8 ? 32 : 24, "Ptr")
    rcP := lParam + (PS = 8 ? 40 : 28)
    idx := NumGet(lParam, PS = 8 ? 56 : 44, "UPtr") + 1
    br := DllCall("CreateSolidBrush", "UInt", DK_BG, "Ptr")
    DllCall("FillRect", "Ptr", hdc, "Ptr", rcP, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
    rc := Buffer(16, 0)
    DllCall("CopyRect", "Ptr", rc, "Ptr", rcP)
    NumPut("Int", NumGet(rc, 0, "Int") + 4, rc, 0)
    DllCall("SetBkMode", "Ptr", hdc, "Int", 1)
    DllCall("SetTextColor", "Ptr", hdc, "UInt", DK_TXT)
    if idx >= 1 && idx <= 5
        DllCall("DrawTextW", "Ptr", hdc, "Str", SBTXT[idx], "Int", -1, "Ptr", rc, "UInt", 0x824)   ; single line, v-centre, no prefix
    return 1
}

; --- dark menu bar (undocumented UAH messages, the same trick other dark-mode apps use) ---
UahDrawMenu(wParam, lParam, m, hwnd) {
    if !S.dark || hwnd != G.Hwnd
        return
    mbi := Buffer(48, 0)                       ; MENUBARINFO
    NumPut("UInt", PS = 8 ? 48 : 32, mbi, 0)
    if !DllCall("GetMenuBarInfo", "Ptr", hwnd, "Int", -3, "Int", 0, "Ptr", mbi)
        return
    wr := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", wr)
    ox := NumGet(wr, 0, "Int")
    oy := NumGet(wr, 4, "Int")
    rc := Buffer(16, 0)
    NumPut("Int", NumGet(mbi, 4, "Int") - ox, "Int", NumGet(mbi, 8, "Int") - oy
        , "Int", NumGet(mbi, 12, "Int") - ox, "Int", NumGet(mbi, 16, "Int") - oy, rc, 0)
    br := DllCall("CreateSolidBrush", "UInt", DK_BG, "Ptr")
    DllCall("FillRect", "Ptr", NumGet(lParam, PS, "Ptr"), "Ptr", rc, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
    return 1
}

UahDrawMenuItem(wParam, lParam, m, hwnd) {
    static hf := 0
    if !S.dark || hwnd != G.Hwnd
        return
    if !hf {                                   ; the system menu font
        ncm := Buffer(504, 0)
        NumPut("UInt", 504, ncm, 0)
        DllCall("SystemParametersInfoW", "UInt", 0x29, "UInt", 504, "Ptr", ncm, "UInt", 0)
        hf := DllCall("CreateFontIndirectW", "Ptr", ncm.Ptr + 224, "Ptr")
    }
    disSize := PS = 8 ? 64 : 48                ; DRAWITEMSTRUCT, then UAHMENU, then UAHMENUITEM
    umSize := PS = 8 ? 24 : 12
    state := NumGet(lParam, 16, "UInt")
    rcP := lParam + (PS = 8 ? 40 : 28)
    hmenu := NumGet(lParam, disSize, "Ptr")
    hdc := NumGet(lParam, disSize + PS, "Ptr")
    pos := NumGet(lParam, disSize + umSize, "Int")
    buf := Buffer(512, 0)
    DllCall("GetMenuStringW", "Ptr", hmenu, "UInt", pos, "Ptr", buf, "Int", 255, "UInt", 0x400)
    br := DllCall("CreateSolidBrush", "UInt", (state & 0x41) ? 0x3C3C3C : DK_BG, "Ptr")   ; hot or selected
    DllCall("FillRect", "Ptr", hdc, "Ptr", rcP, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hf, "Ptr")
    DllCall("SetBkMode", "Ptr", hdc, "Int", 1)
    DllCall("SetTextColor", "Ptr", hdc, "UInt", DK_TXT)
    DllCall("DrawTextW", "Ptr", hdc, "Ptr", buf, "Int", -1, "Ptr", rcP, "UInt", 0x25 | ((state & 0x100) ? 0x100000 : 0))
    DllCall("SelectObject", "Ptr", hdc, "Ptr", old, "Ptr")
    return 1
}

; The system paints a light line under the menu bar; paint it dark after the default handling
UahNcPaint(wParam, lParam, m, hwnd) {
    if !S.dark || hwnd != G.Hwnd
        return
    r := DllCall("DefWindowProcW", "Ptr", hwnd, "UInt", m, "Ptr", wParam, "Ptr", lParam, "Ptr")
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
    DllCall("MapWindowPoints", "Ptr", hwnd, "Ptr", 0, "Ptr", rc, "UInt", 2)
    wr := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", wr)
    ox := NumGet(wr, 0, "Int")
    oy := NumGet(wr, 4, "Int")
    top := NumGet(rc, 4, "Int") - oy
    ln := Buffer(16, 0)
    NumPut("Int", NumGet(rc, 0, "Int") - ox, "Int", top - 1, "Int", NumGet(rc, 8, "Int") - ox, "Int", top, ln, 0)
    hdc := DllCall("GetWindowDC", "Ptr", hwnd, "Ptr")
    br := DllCall("CreateSolidBrush", "UInt", DK_BG, "Ptr")
    DllCall("FillRect", "Ptr", hdc, "Ptr", ln, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
    DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
    return r
}

; ---------- settings (Quick Note.dat) --------------------------------
LoadSettings() {
    f := SETTINGS_INI
    if !FileExist(f)
        return
    fnt := IniRead(f, "Editor", "Font", "")
    if fnt != "" && FONTIDX.Has(fnt)
        S.defFont := FONTARR[FONTIDX[fnt]]
    sz := IniRead(f, "Editor", "FontSize", "")
    if RegExMatch(sz, "^\d+(\.\d+)?$") && sz + 0 >= 1 && sz + 0 <= 1638
        S.defSize := Number(sz)
    S.wrap := IniRead(f, "View", "Wrap", "0") = "1"
    S.sbOn := IniRead(f, "View", "StatusBar", "1") != "0"
    S.aot := IniRead(f, "View", "AlwaysOnTop", "0") = "1"
    S.dark := IniRead(f, "View", "Theme", "Light") = "Dark"
    S.fontOnly := IniRead(f, "View", "FontOnly", "0") = "1"
    S.reopen := IniRead(f, "Session", "Reopen", "1") != "0"
    S.last := IniRead(f, "Session", "Last", "")
    Loop MAX_RECENT {
        rp := IniRead(f, "Recent", A_Index, "")
        if rp != ""
            S.recent.Push(rp)
    }
    for k, v in GRP.Clone()
        GRP[k] := IniRead(f, "Toolbar", k, "1") != "0"
    z := IniRead(f, "View", "Zoom", "100")
    if IsInteger(z)
        S.zoom := Min(500, Max(20, Integer(z)))
    l := IniRead(f, "Window", "Left", "")
    t := IniRead(f, "Window", "Top", "")
    w := IniRead(f, "Window", "Width", "")
    h := IniRead(f, "Window", "Height", "")
    if IsInteger(l) && IsInteger(t) && IsInteger(w) && IsInteger(h)
        && Integer(w) >= 320 && Integer(h) >= 240 && OnAnyScreen(Integer(l) + 100, Integer(t) + 20) {
        S.hasPos := true
        S.pl := Integer(l)
        S.pt := Integer(t)
        S.pw := Integer(w)
        S.ph := Integer(h)
        S.maxed := IniRead(f, "Window", "Maximized", "0") = "1"
    }
}

OnAnyScreen(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        if x >= ml && x < mr && y >= mt && y < mb
            return true
    }
    return false
}

SaveSettings(*) {
    if S.saved
        return
    S.saved := true
    try {
        wp := Buffer(44, 0)
        NumPut("UInt", 44, wp, 0)
        DllCall("GetWindowPlacement", "Ptr", G.Hwnd, "Ptr", wp)
        flags := NumGet(wp, 4, "UInt")
        cmd := NumGet(wp, 8, "UInt")
        l := NumGet(wp, 28, "Int")
        t := NumGet(wp, 32, "Int")
        r := NumGet(wp, 36, "Int")
        b := NumGet(wp, 40, "Int")
        maxed := (cmd = 3 || (cmd = 2 && (flags & 2))) ? 1 : 0   ; maximized (or minimized from maximized)
        nl := "`r`n"
        txt := "[Window]" nl "Left=" l nl "Top=" t nl "Width=" (r - l) nl "Height=" (b - t) nl "Maximized=" maxed nl
        txt .= "[View]" nl "Wrap=" (S.wrap ? 1 : 0) nl "StatusBar=" (S.sbOn ? 1 : 0) nl "AlwaysOnTop=" (S.aot ? 1 : 0) nl
            . "Theme=" (S.dark ? "Dark" : "Light") nl "Zoom=" GetZoom() nl
            . "FontOnly=" (S.fontOnly ? 1 : 0) nl
        txt .= "[Toolbar]" nl
        for k, v in GRP
            txt .= k "=" (v ? 1 : 0) nl
        txt .= "[Editor]" nl "Font=" S.defFont nl "FontSize=" S.defSize nl
        txt .= "[Shortcuts]" nl
        for a in ACT
            txt .= a.id "=" (SK.Get(a.id, "") = "" ? "none" : SK[a.id]) nl
        txt .= "[Session]" nl "Reopen=" (S.reopen ? 1 : 0) nl "Last=" S.file nl "[Recent]" nl
        for i, rp in S.recent
            txt .= i "=" rp nl
        DirCreate(SETTINGS_DIR)
        f := FileOpen(SETTINGS_INI, "w", "UTF-16")   ; one Unicode write instead of ~20 IniWrite calls
        f.Write(txt)
        f.Close()
    }
    return 0
}

; ---------- right-click menu ---------------------------------------------
SetItem(m, item, on) {
    if on
        m.Enable(item)
    else
        m.Disable(item)
}

UpdateCtxState() {
    sel := GetSel()
    has := sel[2] > sel[1]
    SetItem(ctxMenu, CM_UNDO, Msg(0xC6))       ; EM_CANUNDO
    SetItem(ctxMenu, CM_REDO, Msg(0x455))      ; EM_CANREDO
    SetItem(ctxMenu, CM_CUT, has)
    SetItem(ctxMenu, CM_COPY, has)
    SetItem(ctxMenu, CM_DEL, has)
    SetItem(ctxMenu, CM_PASTE, Msg(0x432, 0))  ; EM_CANPASTE
    cf := GetCF()
    mk := NumGet(cf, 4, "UInt")
    ef := NumGet(cf, 8, "UInt")
    for pair in [[CM_BOLD, 1], [CM_ITAL, 2], [CM_UND, 4], [CM_STR, 8]] {
        if (mk & pair[2]) && (ef & pair[2])
            ctxMenu.Check(pair[1])
        else
            ctxMenu.Uncheck(pair[1])
    }
    if IsBullet()
        ctxMenu.Check(CM_BUL)
    else
        ctxMenu.Uncheck(CM_BUL)
}

OverEditor() {
    MouseGetPos(, , , &c, 2)
    return c = re.Hwnd && DllCall("IsWindowEnabled", "Ptr", G.Hwnd)
}

EditorContext() {
    if !WinActive("ahk_id " G.Hwnd)
        WinActivate("ahk_id " G.Hwnd)
    FocusEd()
    ; move the caret under the pointer unless the click is inside the current selection
    MouseGetPos(&mx, &my)
    pt := Buffer(8, 0)
    NumPut("Int", mx, "Int", my, pt, 0)
    DllCall("ScreenToClient", "Ptr", re.Hwnd, "Ptr", pt)
    idx := Msg(0xD7, 0, pt)                    ; EM_CHARFROMPOS
    sel := GetSel()
    if idx >= 0 && !(sel[2] > sel[1] && idx >= sel[1] && idx < sel[2])
        Msg(0xB1, idx, idx)
    UpdateCtxState()
    ctxMenu.Show()
}

ShowCtxAtCaret() {
    UpdateCtxState()
    if CaretGetPos(&cx, &cy)
        ctxMenu.Show(cx, cy + 22)
    else
        ctxMenu.Show()
}

; ---------- find / replace / go to ------------------------------------
GetSel() {
    cr := Buffer(8, 0)
    Msg(0x434, 0, cr)
    return [NumGet(cr, 0, "Int"), NumGet(cr, 4, "Int")]
}

GetSelText() {
    sel := GetSel()
    cnt := sel[2] - sel[1]
    if cnt <= 0
        return ""
    buf := Buffer((cnt + 1) * 2, 0)
    Msg(0x43E, 0, buf)                         ; EM_GETSELTEXT
    return StrGet(buf, "UTF-16")
}

ShowFind() {
    selTxt := GetSelText()
    if selTxt != "" && !InStr(selTxt, "`r") && !InStr(selTxt, "`n") && StrLen(selTxt) < 200
        fFind.Value := selTxt
    FD.Show("w440 h175")
    fFind.Focus()
    SendMessage(0xB1, 0, -1, fFind)
}

FindFlags() {
    return 1 | (cCase.Value ? 4 : 0) | (cWord.Value ? 2 : 0)
}

FindRange(txt, start, flags, endp := -1) {
    ft := Buffer(16 + PS, 0)                   ; FINDTEXTEXW
    NumPut("Int", start, "Int", endp, ft, 0)
    NumPut("Ptr", StrPtr(txt), ft, 8)
    r := Msg(0x47C, flags, ft)                 ; EM_FINDTEXTEXW
    if r = -1 || r = 0xFFFFFFFF
        return 0
    return [NumGet(ft, 8 + PS, "Int"), NumGet(ft, 12 + PS, "Int")]
}

; whole document as text; positions match the editor's selection positions
GetDocText() {
    len := Msg(0xE)
    if len = 0
        return ""
    buf := Buffer((len + 1) * 2, 0)
    gt := Buffer(32, 0)                        ; GETTEXTEX: cb, flags, codepage
    NumPut("UInt", buf.Size, "UInt", 0, "UInt", 1200, gt, 0)
    Msg(0x45E, gt, buf)                        ; EM_GETTEXTEX
    return StrGet(buf, "UTF-16")
}

BuildPattern() {
    pat := fFind.Value
    if !cRegex.Value
        pat := RegExReplace(pat, "[\\.*?+\[\]{}|()^$]", "\$0")
    if cWord.Value
        pat := "\b(?:" pat ")\b"
    return (cCase.Value ? "m)" : "im)") pat
}

NextMatch(text, pat, pos) {
    while RegExMatch(text, pat, &m, pos) {
        if m.Len > 0
            return m
        pos := m.Pos + 1
        if pos > StrLen(text)
            break
    }
    return ""
}

; regex search: returns [start, end], 0 (none) or -1 (bad pattern)
FindMatch(dir) {
    try {
        text := GetDocText()
        pat := BuildPattern()
        sel := GetSel()
        if dir > 0 {
            m := NextMatch(text, pat, sel[2] + 1)
            if !m
                m := NextMatch(text, pat, 1)
            return m ? [m.Pos - 1, m.Pos - 1 + m.Len] : 0
        }
        before := ""
        lastAny := ""
        pos := 1
        while (m := NextMatch(text, pat, pos)) {
            if m.Pos - 1 < sel[1]
                before := m
            lastAny := m
            pos := m.Pos + m.Len
        }
        m := before ? before : lastAny
        return m ? [m.Pos - 1, m.Pos - 1 + m.Len] : 0
    } catch {
        Hint("Invalid regular expression")
        return -1
    }
}

FindNext(dir := 1) {
    txt := fFind.Value
    if txt = "" {
        ShowFind()
        return false
    }
    if cRegex.Value
        r := FindMatch(dir)
    else {
        flags := FindFlags()
        sel := GetSel()
        if dir > 0 {
            r := FindRange(txt, sel[2], flags)
            if !r
                r := FindRange(txt, 0, flags)          ; wrap around
        } else {
            flags &= ~1                                ; search upwards
            r := FindRange(txt, sel[1], flags, 0)
            if !r
                r := FindRange(txt, Msg(0xE), flags, 0)
        }
    }
    if !IsObject(r) {
        if r = 0
            MsgBox('Cannot find "' txt '"', "Find", "Iconi Owner" G.Hwnd)
        return false
    }
    Msg(0xB1, r[1], r[2])
    Msg(0xB7)                                  ; EM_SCROLLCARET
    return true
}

ReplaceOne() {
    txt := fFind.Value
    if txt = ""
        return
    selTxt := GetSelText()
    if cRegex.Value {
        try {
            pat := BuildPattern()
            if selTxt != "" && RegExMatch(selTxt, pat, &m) && m.Pos = 1 && m.Len = StrLen(selTxt)
                InsertText(RegExReplace(selTxt, pat, fRepl.Value, , 1))
        } catch {
            Hint("Invalid regular expression")
            return
        }
    } else {
        same := cCase.Value ? (selTxt == txt) : (selTxt = txt)
        if same
            InsertText(fRepl.Value)
    }
    FindNext()
}

ReplaceAll() {
    txt := fFind.Value
    if txt = ""
        return
    repl := fRepl.Value
    count := 0
    Msg(0xB, 0, 0)                             ; WM_SETREDRAW off
    if cRegex.Value {
        try {
            text := GetDocText()
            pat := BuildPattern()
            list := []
            pos := 1
            while (m := NextMatch(text, pat, pos)) {
                list.Push([m.Pos - 1, m.Len, RegExReplace(m[0], pat, repl, , 1)])
                pos := m.Pos + m.Len
            }
            i := list.Length
            while i >= 1 {                     ; from the end, so earlier positions stay valid
                it := list[i]
                Msg(0xB1, it[1], it[1] + it[2])
                Msg(0xC2, 1, StrPtr(it[3]))
                i--
            }
            count := list.Length
        } catch {
            Msg(0xB, 1, 0)
            Hint("Invalid regular expression")
            return
        }
    } else {
        flags := FindFlags()
        pos := 0
        while (r := FindRange(txt, pos, flags)) {
            Msg(0xB1, r[1], r[2])
            Msg(0xC2, 1, StrPtr(repl))
            pos := r[1] + StrLen(repl)
            count++
        }
    }
    Msg(0xB, 1, 0)
    DllCall("InvalidateRect", "Ptr", re.Hwnd, "Ptr", 0, "Int", 1)
    MsgBox(count " replacement(s) made.", "Replace All", "Iconi Owner" G.Hwnd)
}

GotoLine() {
    ib := InputBox("Line number:", "Go To Line", "w220 h110")
    if ib.Result != "OK" || !IsInteger(ib.Value) || Integer(ib.Value) < 1
        return
    idx := Msg(0xBB, Integer(ib.Value) - 1)
    if idx < 0 || idx = 0xFFFFFFFF {
        MsgBox("The line number is beyond the end of the document.", APP, "Icon! Owner" G.Hwnd)
        return
    }
    Msg(0xB1, idx, idx)
    Msg(0xB7)
    FocusEd()
}

; ============================================================
;  Selection-safe focus, words, links, recovery, recent files, text tools, printing
; ============================================================

; Give the editor focus WITHOUT losing the current selection
FocusEd() {
    sel := GetSel()
    DllCall("SetFocus", "Ptr", re.Hwnd)
    cur := GetSel()
    if cur[1] != sel[1] || cur[2] != sel[2] {
        cr := Buffer(8, 0)
        NumPut("Int", sel[1], "Int", sel[2], cr, 0)
        Msg(0x437, 0, cr)                      ; EM_EXSETSEL
    }
}

CountWords() {
    if S.closing
        return
    RegExReplace(GetDocText(), "\S+", "", &n)
    S.words := n
    UpdateStatus()
}

; Ctrl+click on a link opens it
ReLink(ctrl, lParam) {
    if NumGet(lParam, 3 * PS, "UInt") != 0x202 || !GetKeyState("Ctrl", "P")    ; WM_LBUTTONUP
        return 0
    a := NumGet(lParam, 6 * PS, "Int")
    b := NumGet(lParam, 6 * PS + 4, "Int")
    if b <= a || b - a > 2000
        return 0
    buf := Buffer((b - a + 1) * 2, 0)
    tr := Buffer(16, 0)                        ; TEXTRANGE
    NumPut("Int", a, "Int", b, tr, 0)
    NumPut("Ptr", buf.Ptr, tr, 8)
    Msg(0x44B, 0, tr)                          ; EM_GETTEXTRANGE
    url := StrGet(buf, "UTF-16")
    if RegExMatch(url, "i)^www\.")
        url := "http://" url
    try Run(url)
    return 0
}

; ---------- draft auto-save / crash recovery ----------
RtfBytes() {
    buf := StreamOut(2)                        ; SF_RTF
    n := STR.opos
    if S.dark {                                ; do not store the theme's light text colour
        rtf := StrReplace(StrGet(buf, n, "CP0"), "\red224\green224\blue224", "\red0\green0\blue0")
        n := StrPut(rtf, "CP0")
        buf := Buffer(n, 0)
        StrPut(rtf, buf, "CP0")
        n -= 1
    }
    return {buf: buf, n: n}
}

AutoSave(*) {
    if S.closing || !IsDirty()
        return
    try {
        DirCreate(SETTINGS_DIR)
        rb := RtfBytes()
        f := FileOpen(REC_RTF, "w")
        f.RawWrite(rb.buf, rb.n)
        f.Close()
        nl := "`r`n"
        f := FileOpen(REC_META, "w", "UTF-16")
        f.Write("[Doc]" nl "File=" S.file nl "Enc=" S.enc nl "Fmt=" (S.fmt ? 1 : 0) nl)
        f.Close()
    }
}

DeleteRecovery() {
    try FileDelete(REC_RTF)
    try FileDelete(REC_META)
}

RestoreRecovery() {
    if !FileExist(REC_RTF)
        return false
    r := MsgBox("Quick Note found unsaved text from the last session (it may have closed unexpectedly).`n`nRestore it?"
        , APP, "YesNo Iconi Owner" G.Hwnd)
    if r != "Yes" {
        DeleteRecovery()
        return false
    }
    try {
        buf := FileRead(REC_RTF, "RAW")
        ClearDoc()
        StreamIn(2, buf, buf.Size)
        if S.dark
            ThemeTextColor()
    } catch {
        return false
    }
    S.file := IniRead(REC_META, "Doc", "File", "")
    enc := IniRead(REC_META, "Doc", "Enc", "UTF-8")
    S.enc := ENCMAP.Has(enc) ? enc : "UTF-8"
    S.fmt := IniRead(REC_META, "Doc", "Fmt", "0") = "1"
    Msg(0xB1, 0, 0)
    Msg(0xCD)
    Msg(0xB9, 1)                               ; still unsaved
    SetEncState()
    UpdateTitle()
    UpdateStatus()
    UpdateToolbar()
    return true
}

; ---------- recent files / session ----------
AddRecent(path) {
    for i, p in S.recent {
        if p = path {
            S.recent.RemoveAt(i)
            break
        }
    }
    S.recent.InsertAt(1, path)
    while S.recent.Length > MAX_RECENT
        S.recent.Pop()
    RebuildRecent()
}

RebuildRecent() {
    try recentMenu.Delete()
    if !S.recent.Length {
        recentMenu.Add("(none)", (*) => 0)
        recentMenu.Disable("(none)")
        return
    }
    for i, p in S.recent {
        shown := StrLen(p) > 60 ? SubStr(p, 1, 25) "..." SubStr(p, -30) : p
        recentMenu.Add(i ". " StrReplace(shown, "&", "&&"), OpenRecent.Bind(p))
    }
    recentMenu.Add()
    recentMenu.Add("Clear Recent Files", (*) => (S.recent := [], RebuildRecent()))
}

OpenRecent(path, *) {
    if FileExist(path) = "" {
        for i, p in S.recent {
            if p = path {
                S.recent.RemoveAt(i)
                break
            }
        }
        RebuildRecent()
    }
    OpenFile(path)
}

ToggleReopen() {
    S.reopen := !S.reopen
    if S.reopen
        fileMenu.Check("Reopen Last File at Startup")
    else
        fileMenu.Uncheck("Reopen Last File at Startup")
}

; ---------- text tools (selection, or the whole document when nothing is selected) ----------
TextTool(kind) {
    sel := GetSel()
    if sel[1] = sel[2]
        Msg(0xB1, 0, -1)
    txt := GetSelText()
    if txt = "" {
        FocusEd()
        return
    }
    start := GetSel()[1]
    t := StrReplace(StrReplace(txt, "`r`n", "`n"), "`r", "`n")
    if kind = "upper"
        t := StrUpper(t)
    else if kind = "lower"
        t := StrLower(t)
    else if kind = "title"
        t := StrTitle(t)
    else if kind = "sort" {
        t := Sort(RTrim(t, "`n"))
    } else if kind = "dedupe" {
        seen := Map()
        seen.CaseSense := "Off"
        out := ""
        for ln in StrSplit(t, "`n") {
            if seen.Has(ln)
                continue
            seen[ln] := 1
            out .= ln "`n"
        }
        t := RTrim(out, "`n")
    } else if kind = "trim"
        t := RegExReplace(t, "m)[ \t]+$", "")
    t := StrReplace(t, "`n", "`r")
    InsertText(t)
    Msg(0xB1, start, start + StrLen(t))
    FocusEd()
}

; ---------- printing / PDF export ----------
PrintDoc(toPdf := false) {
    outFile := ""
    if toPdf {
        base := "Untitled"
        dir := A_MyDocuments
        if S.file != ""
            SplitPath(S.file, , &dir, , &base)
        r := FileDialog(true, "Export as PDF", [["PDF (*.pdf)", "*.pdf", "pdf"]], dir, base ".pdf", 1)
        if !r
            return
        outFile := r.path
        if !RegExMatch(outFile, "i)\.pdf$")
            outFile .= ".pdf"
        printer := "Microsoft Print to PDF"
    } else {
        sz := 0
        DllCall("winspool.drv\GetDefaultPrinterW", "Ptr", 0, "UInt*", &sz)
        if !sz {
            MsgBox("No default printer is set up on this PC.", APP, "Icon! Owner" G.Hwnd)
            return
        }
        pb := Buffer(sz * 2, 0)
        DllCall("winspool.drv\GetDefaultPrinterW", "Ptr", pb, "UInt*", &sz)
        printer := StrGet(pb, "UTF-16")
        if MsgBox("Print this document on:`n" printer "?", APP, "OKCancel Iconi Owner" G.Hwnd) != "OK"
            return
    }
    hdc := DllCall("CreateDCW", "Str", "WINSPOOL", "Str", printer, "Ptr", 0, "Ptr", 0, "Ptr")
    if !hdc {
        MsgBox(toPdf ? "The 'Microsoft Print to PDF' printer is not available on this PC." : "Could not open the printer.", APP, "Icon! Owner" G.Hwnd)
        return
    }
    ; print from a hidden copy, so the dark theme's light text prints black and the document is untouched
    tmp := DllCall("CreateWindowExW", "UInt", 0, "Str", "RICHEDIT50W", "Str", "", "UInt", 0x40000004
        , "Int", 0, "Int", 0, "Int", 100, "Int", 100, "Ptr", G.Hwnd, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
    rb := RtfBytes()
    StreamIn(2, rb.buf, rb.n, tmp)
    textLen := DllCall("SendMessageW", "Ptr", tmp, "UInt", 0xE, "Ptr", 0, "Ptr", 0, "Ptr")

    dx := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 88, "Int")      ; LOGPIXELSX
    dy := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 90, "Int")
    pw := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 110, "Int")     ; PHYSICALWIDTH
    ph := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 111, "Int")
    ox := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 112, "Int")     ; PHYSICALOFFSETX
    oy := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 113, "Int")
    pageW := pw * 1440 // dx
    pageH := ph * 1440 // dy
    offX := ox * 1440 // dx
    offY := oy * 1440 // dy
    mar := 1440                                                       ; 1 inch margins (twips)
    fr := Buffer(2 * PS + 40, 0)                                      ; FORMATRANGE
    NumPut("Ptr", hdc, "Ptr", hdc, fr, 0)
    NumPut("Int", mar - offX, "Int", mar - offY, "Int", pageW - offX - mar, "Int", pageH - offY - mar, fr, 2 * PS)
    NumPut("Int", -offX, "Int", -offY, "Int", pageW - offX, "Int", pageH - offY, fr, 2 * PS + 16)

    di := Buffer(5 * PS, 0)                                           ; DOCINFOW
    docName := S.file != "" ? S.file : "Quick Note"
    NumPut("UInt", 5 * PS, di, 0)
    NumPut("Ptr", StrPtr(docName), di, PS)
    if outFile != ""
        NumPut("Ptr", StrPtr(outFile), di, 2 * PS)
    ok := DllCall("gdi32\StartDocW", "Ptr", hdc, "Ptr", di, "Int") > 0
    if ok {
        pos := 0
        while true {
            DllCall("gdi32\StartPage", "Ptr", hdc)
            NumPut("Int", pos, "Int", -1, fr, 2 * PS + 32)
            next := DllCall("SendMessageW", "Ptr", tmp, "UInt", 0x439, "Ptr", 1, "Ptr", fr, "Ptr")   ; EM_FORMATRANGE
            DllCall("gdi32\EndPage", "Ptr", hdc)
            if next >= textLen || next <= pos
                break
            pos := next
        }
        DllCall("SendMessageW", "Ptr", tmp, "UInt", 0x439, "Ptr", 0, "Ptr", 0, "Ptr")                 ; free cache
        DllCall("gdi32\EndDoc", "Ptr", hdc)
    }
    DllCall("DeleteDC", "Ptr", hdc)
    DllCall("DestroyWindow", "Ptr", tmp)
    if !ok
        MsgBox("The printer did not accept the document.", APP, "Icon! Owner" G.Hwnd)
    else
        Hint(toPdf ? "PDF saved: " outFile : "Sent to the printer")
}

; ============================================================
;  Hotkeys (active only while the editor window is active)
; ============================================================
; ============================================================
;  Keyboard shortcuts (customizable) + Settings + About
; ============================================================

HfMain(*) => IsMainActive()
HfEditor(*) => InEditor()

; "^+s" -> "Ctrl+Shift+S"
HkPretty(hk) {
    if (hk = "")
        return ""
    s := ""
    while (hk != "" && InStr("^!+#", SubStr(hk, 1, 1))) {
        m := SubStr(hk, 1, 1)
        s .= (m = "^") ? "Ctrl+" : (m = "!") ? "Alt+" : (m = "+") ? "Shift+" : "Win+"
        hk := SubStr(hk, 2)
    }
    n := GetKeyName(hk)
    return s . StrUpper(n != "" ? n : hk)
}

; the text after the tab in a menu item ("" = no shortcut)
ScTab(id) {
    hk := SK.Get(id, "")
    return (hk = "") ? "" : "`t" . HkPretty(hk)
}

; tool tip text: "Bold (Ctrl+B)"
TipText(base, id) {
    hk := SK.Get(id, "")
    return (hk = "") ? base : base . " (" . HkPretty(hk) . ")"
}

; menu item whose shortcut text follows the settings (see RefreshShortcutLabels)
AddMI(menu, id, base, fn) {
    nm := base . ScTab(id)
    menu.Add(nm, fn)
    MREG.Push({menu: menu, lbl: base, id: id, cur: nm})
}

; toolbar button whose tool tip follows the settings
RegTip(ctrl, base, id) {
    TREG.Push({c: ctrl, lbl: base, id: id})
    return ctrl
}

LoadShortcuts() {
    for a in ACT {
        v := IniRead(SETTINGS_INI, "Shortcuts", a.id, "<default>")
        if (v = "<default>")
            v := a.def
        else if (v = "none")
            v := ""
        SK[a.id] := v
    }
}

; (re)register every shortcut; the editor-only ones work only while the typing area has the focus
ApplyShortcuts() {
    static reg := []
    for r in reg {
        try {
            HotIf(r.cond)
            Hotkey(r.hk, "Off")
        }
    }
    reg := []
    for a in ACT {
        hk := SK.Get(a.id, "")
        if (hk = "")
            continue
        cond := a.ed ? HfEditor : HfMain
        try {
            HotIf(cond)
            Hotkey(hk, a.fn, "On")
            reg.Push({hk: hk, cond: cond})
        }
    }
    HotIf()
}

; menu items and tool tips show the shortcut that is set now
RefreshShortcutLabels() {
    global CM_BOLD, CM_ITAL, CM_UND, CM_STR
    for r in MREG {
        nm := r.lbl . ScTab(r.id)
        if (nm != r.cur) {
            try r.menu.Rename(r.cur, nm)
            r.cur := nm
        }
    }
    CM_BOLD := "Bold" . ScTab("Bold")
    CM_ITAL := "Italic" . ScTab("Italic")
    CM_UND := "Underline" . ScTab("Underline")
    CM_STR := "Strikethrough" . ScTab("Strike")
    for r in TREG
        TIPS[r.c.Hwnd] := TipText(r.lbl, r.id)
    DllCall("DrawMenuBar", "Ptr", G.Hwnd)
}

; same colours as the main window (light / dark) for the small windows below
ThemeDlg(gw) {
    dark := S.dark ? 1 : 0
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gw.Hwnd, "Int", 20, "Int*", dark, "Int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gw.Hwnd, "Int", 19, "Int*", dark, "Int", 4)
    gw.BackColor := dark ? "202020" : "Default"
    ThemeControls(gw)
}

; ---- key recorder (the box records the keys you press while it has the focus) ----
KbBegin(*) {
    global KB_IH
    KbEnd()
    ih := InputHook()
    ih.KeyOpt("{All}", "NS")                                       ; see every key and keep it away from the window
    ih.KeyOpt("{Tab}{Enter}{Esc}{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}", "-S")   ; these must keep working normally
    ih.OnKeyDown := KbDown
    ih.Start()
    KB_IH := ih
}

KbEnd(*) {
    global KB_IH
    if IsObject(KB_IH)
        try KB_IH.Stop()
    KB_IH := ""
}

KbDown(ih, vk, sc) {
    if (vk = 0xE7 || (vk >= 0x10 && vk <= 0x12) || (vk >= 0xA0 && vk <= 0xA5) || vk = 0x5B || vk = 0x5C)
        return                                                     ; a modifier key on its own
    if !(IsObject(SETDLG) && WinActive("ahk_id " SETDLG.Hwnd)) {
        KbEnd()                                                    ; never keep the keyboard captured outside the Settings window
        return
    }
    if (vk = 0x09 || vk = 0x0D || vk = 0x1B)
        return
    mods := (GetKeyState("Ctrl", "P") ? "^" : "") . (GetKeyState("Alt", "P") ? "!" : "") . (GetKeyState("Shift", "P") ? "+" : "")
    if (mods = "" && (vk = 0x08 || vk = 0x2E)) {
        KbSet("")                                                  ; Backspace / Delete clear the shortcut
        return
    }
    n := GetKeyName(Format("vk{:X}sc{:03X}", vk, sc))
    if (n = "")
        n := Format("vk{:X}", vk)
    else if (StrLen(n) = 1)
        n := RegExMatch(n, "i)^[a-z0-9]$") ? StrLower(n) : Format("vk{:X}", vk)
    KbSet(mods . n)
}

; "" when the shortcut can be used for this action, otherwise what is wrong with it
CheckHk(hk, id, work) {
    mods := ""
    key := hk
    while (key != "" && InStr("^!+", SubStr(key, 1, 1))) {
        mods .= SubStr(key, 1, 1)
        key := SubStr(key, 2)
    }
    if (key = "")
        return "Press a key together with Ctrl or Alt."
    if (mods == "^" && RegExMatch(key, "i)^[xcvzya]$"))
        return HkPretty(hk) . " is used by the editor itself (cut, copy, paste, undo, redo, select all)."
    if (!InStr(mods, "^") && !RegExMatch(key, "i)^F\d+$")) {
        if !InStr(mods, "!")
            return "Add Ctrl or Alt, or use an F-key, so it is not typed as text."
        if RegExMatch(key, "i)^[a-z]$")
            return "Alt + letter opens the menus. Add Ctrl, or use another key."
    }
    for a in ACT {
        if (a.id != id && work.Get(a.id, "") == hk)
            return HkPretty(hk) . " is already used by " . a.label . "."
    }
    return ""
}

KbSet(hk) {
    st := SETST
    row := st.lv.GetNext(0)
    if !row
        return
    a := ACT[row]
    if (hk != "") {
        err := CheckHk(hk, a.id, st.work)
        if (err != "") {
            st.hint.Text := err
            return
        }
    }
    st.work[a.id] := hk
    st.lv.Modify(row, , a.label, HkPretty(hk))
    st.box.Value := HkPretty(hk)
    st.hint.Text := ""
}

; ---- Settings window ----------------------------------------------------------------
ShowSettings(*) {
    global SETDLG, SETST
    if IsObject(SETDLG) {
        try SETDLG.Show()
        return
    }
    work := Map()
    for a in ACT
        work[a.id] := SK.Get(a.id, "")
    d := Gui("+Owner" G.Hwnd " +ToolWindow", APP . " - Settings")
    d.SetFont("s9", "Segoe UI")
    d.MarginX := 12
    d.MarginY := 12
    h := d.Add("Text", "x12 y10 w400", "Keyboard shortcuts")
    h.SetFont("s11 bold")
    d.Add("Text", "x12 y34 w400 h30", "Select an action, click the box below and press the new keys. Cut, copy, paste, undo, redo and select all keep their usual keys.")
    lv := d.Add("ListView", "x12 y70 w400 r13 -Multi NoSortHdr", ["Action", "Shortcut"])
    for a in ACT
        lv.Add(, a.label, HkPretty(work[a.id]))
    lv.ModifyCol(1, 250)
    lv.ModifyCol(2, 130)
    d.Add("Text", "x12 y+12 w60 h22 +0x200", "Shortcut:")
    box := d.Add("Edit", "x74 yp w170 h22 ReadOnly Center")
    btnClr := d.Add("Button", "x252 yp-1 w76 h24", "Clear")
    btnDef := d.Add("Button", "x336 yp w76 h24", "Default")
    hint := d.Add("Text", "x12 y+10 w400 h32 cC00000", "")
    btnAll := d.Add("Button", "x12 y+6 w100 h26", "Reset All")
    btnOk := d.Add("Button", "x252 yp w76 h26 Default", "Save")
    btnNo := d.Add("Button", "x336 yp w76 h26", "Cancel")
    SETST := {work: work, lv: lv, box: box, hint: hint}
    lv.OnEvent("ItemSelect", (ctrl, item, sel) => (sel ? (box.Value := HkPretty(work[ACT[item].id]), hint.Text := "") : 0))
    box.OnEvent("Focus", KbBegin)
    box.OnEvent("LoseFocus", KbEnd)
    btnClr.OnEvent("Click", (*) => KbSet(""))
    btnDef.OnEvent("Click", (*) => SettingsDefault())
    btnAll.OnEvent("Click", (*) => SettingsResetAll())
    btnOk.OnEvent("Click", (*) => SettingsSave())
    btnNo.OnEvent("Click", (*) => SettingsClose())
    d.OnEvent("Close", (*) => SettingsClose())
    d.OnEvent("Escape", (*) => SettingsClose())
    SETDLG := d
    d.Show("w424")
    ThemeDlg(d)
    lv.Modify(1, "Select Focus")
}

SettingsDefault() {
    st := SETST
    row := st.lv.GetNext(0)
    if row
        KbSet(ACT[row].def)
}

SettingsResetAll() {
    st := SETST
    for i, a in ACT {
        st.work[a.id] := a.def
        st.lv.Modify(i, , a.label, HkPretty(a.def))
    }
    row := st.lv.GetNext(0)
    st.box.Value := row ? HkPretty(ACT[row].def) : ""
    st.hint.Text := ""
}

SettingsSave() {
    st := SETST
    for a in ACT {
        SK[a.id] := st.work[a.id]
        try IniWrite(st.work[a.id] = "" ? "none" : st.work[a.id], SETTINGS_INI, "Shortcuts", a.id)
    }
    ApplyShortcuts()
    RefreshShortcutLabels()
    SettingsClose()
}

SettingsClose() {
    global SETDLG, SETST
    KbEnd()
    try SETDLG.Destroy()
    SETDLG := ""
    SETST := ""
    FocusEd()
}

; ---- About window ---------------------------------------------------------------------
AboutText() {
    nl := "`r`n"
    t := "A small, quick rich-text editor for notes, drafts and plain text files. It needs no installer and opens at once. It comes with Bangla Keyboard and shares its settings folder." nl nl
    t .= "WHAT IT OFFERS" nl
    t .= "  - Opens and saves .txt, .rtf, .md and .log files (also opens .ini and .csv). Drag a file onto the window to open it." nl
    t .= "  - Font and size, bold, italic, underline, strikethrough, superscript, subscript, text and highlight colours." nl
    t .= "  - Left / center / right alignment, bulleted and numbered lists, indents and line spacing." nl
    t .= "  - Find and Replace with Match case, Whole word and Regular expression; Go To Line; Insert Date/Time." nl
    t .= "  - Text tools: UPPERCASE, lowercase, Title Case, sort lines, remove duplicate lines, trim trailing spaces." nl
    t .= "  - Plain-text encodings: UTF-8, UTF-8 with BOM, UTF-16 LE and ANSI. An option stops automatic font switching, for ANSI fonts." nl
    t .= "  - Print, and export as PDF." nl
    t .= "  - Light and dark theme, zoom, word wrap, status bar, always on top. Ctrl+click opens a web link." nl
    t .= "  - Safety: a recovery draft is saved every 30 seconds and offered again after a crash. Recent files, and an option to reopen the last file at startup." nl nl
    t .= "KEYBOARD SHORTCUTS (File > Settings changes these)" nl
    for a in ACT {
        hk := SK.Get(a.id, "")
        t .= "  " . a.label . ":  " . (hk = "" ? "(none)" : HkPretty(hk)) . nl
    }
    t .= "  Fixed: Ctrl+X cut, Ctrl+C copy, Ctrl+V paste, Ctrl+Z undo, Ctrl+Y redo, Ctrl+A select all, Tab inserts a tab, Shift+F10 / Menu key opens the right-click menu." nl nl
    t .= "GOOD TO KNOW" nl
    t .= "  - Free and open source (GNU GPL v3). It is not sold, so please do not sell or repackage it." nl
    t .= "  - Your settings are saved in %AppData%\Bangla Keyboard\Quick Note.dat, so updates never erase them." nl nl
    t .= "CREDITS" nl
    t .= "  The design, functionality and features are designed by Sherlock Holmes (nickname), with the assistance of AI."
    return t
}

ShowAbout(*) {
    global ABOUTDLG
    if IsObject(ABOUTDLG) {
        try ABOUTDLG.Show()
        return
    }
    d := Gui("+Owner" G.Hwnd " +ToolWindow", "About " . APP)
    d.SetFont("s9", "Segoe UI")
    d.MarginX := 14
    d.MarginY := 12
    h := d.Add("Text", "x14 y10 w452", APP)
    h.SetFont("s16 bold")
    d.Add("Text", "x14 y+0 w452", "Version " . APP_VER . "   -   Bangla Keyboard tools")
    d.Add("Edit", "x14 y+10 w452 r20 ReadOnly Multi VScroll", AboutText())
    btnSc := d.Add("Button", "x14 y+10 w160 h26", "Customize Shortcuts...")
    btnOk := d.Add("Button", "x390 yp w76 h26 Default", "Close")
    btnSc.OnEvent("Click", (*) => (AboutClose(), ShowSettings()))
    btnOk.OnEvent("Click", (*) => AboutClose())
    d.OnEvent("Close", (*) => AboutClose())
    d.OnEvent("Escape", (*) => AboutClose())
    ABOUTDLG := d
    d.Show("w480")
    ThemeDlg(d)
    btnOk.Focus()
}

AboutClose() {
    global ABOUTDLG
    try ABOUTDLG.Destroy()
    ABOUTDLG := ""
    FocusEd()
}

IsMainActive() {
    return WinActive("ahk_id " G.Hwnd)
}

InEditor() {
    if !WinActive("ahk_id " G.Hwnd)
        return false
    fc := G.FocusedCtrl
    return fc && fc.Hwnd = re.Hwnd
}

#HotIf IsMainActive() && InCombo()
Enter::CommitCombo()
NumpadEnter::CommitCombo()
Esc::CancelCombo()
#HotIf InEditor()
Tab::InsertText("`t")
AppsKey::ShowCtxAtCaret()
+F10::ShowCtxAtCaret()
#HotIf OverEditor()
RButton::EditorContext()
#HotIf

; Hands the memory the program does not need back to Windows (only idle pages; they return when used)
TrimMemory() {
    DllCall("psapi\EmptyWorkingSet", "Ptr", DllCall("kernel32\GetCurrentProcess", "Ptr"))
}
