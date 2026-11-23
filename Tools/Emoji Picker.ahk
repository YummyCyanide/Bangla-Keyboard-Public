#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines(false)          ; keep memory use low
KeyHistory(0)
CoordMode("Caret", "Screen")      ; popup position must be in screen coordinates
CoordMode("Mouse", "Screen")

; =====================================================================
;  Emoji Picker - a replacement for the Windows Win+. panel
;  Start it whenever you need it: the picker opens at once. A tray icon (Open / Settings / Exit)
;  is shown while the app runs. When the app is not running it uses nothing at all.
;  Settings > Close button: "Close the app entirely" or "Minimize to the tray".
;  While minimized to the tray, what stays in memory is set in Settings > "Memory in the tray":
;    Lowest   everything is released (only the tray icon and your shortcut stay); rebuilt on open
;    Balanced the window and graphics are released, the emoji text stays (default)
;    Fastest  the window is only hidden, so it opens instantly
;  The tray icon is EmojiPicker.ico (in the data folder). Settings > "Always show the tray icon"
;  asks Windows 11 to keep it on the taskbar instead of the hidden-icons overflow.
;  1.3.1 fixes: GDI+ is no longer started / stopped / unloaded on every popup (crash after a few popups);
;         closing and pasting can no longer run twice or re-enter; clipboard errors no longer kill a paste;
;         a lost Direct2D target is recreated in place; popup appears at the caret / mouse (screen coords);
;         picture sheets stay loaded while the picker is open; hover highlight clears when the mouse leaves.
;  Needs the "Emoji Picker Data" folder next to this script
;  (EmojiData.dat, Flags.dat, Flags.png).
;  Your own data (settings, last tab, favorites, highlights, recently used) is saved in
;  %AppData%\Bangla Keyboard\Emoji Picker Data\
;
;  Your shortcut        open / close the picker (default Win+.; change it in Settings; shortcut and
;                       tray icon work while the app is running, e.g. minimized to the tray)
;  Type                 search
;  Click / Enter        paste (Enter pastes the first result)
;  Mouse wheel (over the picker), scrollbar (click / drag), Up/Down, PgUp/PgDn scroll
;  Right-click an emoji TWICE   add / remove it from Favorites (gold tint, pinned to the top of its tab)
;  Middle-click an emoji        add / remove a Highlight (blue tint, stays at its normal position)
;                               (both features can be switched off in Settings)
;  First tab shows your history (recently used)
;  Settings icon (left of the X) opens Settings
;  Emoji listed in Extra.dat are drawn from the picture sheet Extra.png (same layout as Flags.png)
;  Settings > "Don't close automatically after inserting an emoji"  keeps the picker open while you paste many emoji
;  X button / Esc / click away / pasting an emoji     do what "Close button" says in Settings
;                               (click away and pasting do nothing while that option is on)
;
;  Emoji are drawn in colour with Direct2D / DirectWrite (Segoe UI Emoji).
;  Emoji listed in Extra.dat and the country flags are drawn from picture sheets instead
;  (the Windows font draws newer emoji as two separate emoji, and flags as letters).
; =====================================================================

AppVersion := "1.3.1"
AppAuthor := "Sherlock Holmes"

; ---------- Fixed layout ----------
COLS := 7, ROWS := 5
CellBase := [36, 44, 52]               ; Small, Normal, Large
FsEmojiBase := [12, 14, 17]
FsTabBase := [11, 13, 16]
FlagCols := 20, FlagSize := 72        ; layout of Flags.png (sprite sheet)

; ---------- Files ----------
DataDir := A_ScriptDir "\Emoji Picker Data"
DataFile := DataDir "\EmojiData.dat"
FlagListFile := DataDir "\Flags.dat"
FlagSheetFile := DataDir "\Flags.png"
ExtraListFile := DataDir "\Extra.dat"      ; emoji drawn from a picture sheet (like the flags) because
ExtraSheetFile := DataDir "\Extra.png"     ; the Windows font cannot draw them
IconFile := DataDir "\EmojiPicker.ico"     ; tray icon
; Everything the app writes itself lives in %AppData%\Bangla Keyboard\Emoji Picker Data
UserDir := A_AppData "\Bangla Keyboard\Emoji Picker Data"
RecentFile := UserDir "\EmojiPicker_recent.dat"
FavFile := UserDir "\EmojiPicker_favorites.dat"
HlFile := UserDir "\EmojiPicker_highlights.dat"
SettingsFile := UserDir "\Settings.ini"
; locations used by older versions (moved automatically on first start)
OldSettingsDir := A_AppData "\Bangla Keyboard"
OldSettingsFile := OldSettingsDir "\Emoji Picker Data.dat"
DebugLog := false          ; set to true to write "EmojiPicker debug.log" next to the script
LogFile := A_ScriptDir "\EmojiPicker debug.log"

MigrateOldData()

; Step log: lets us see exactly where a Direct2D / DirectWrite call fails
if DebugLog {
    try FileDelete(LogFile)
    Step("AutoHotkey " A_AhkVersion ", " (A_PtrSize * 8) "-bit, Windows " A_OSVersion)
}

; ---------- State ----------
Cats := []
ItemMap := Map()
ExtraIdx := Map()
ExtraSheet := 0
ExtraTried := false
Recents := []
Favs := []
FavSet := Map()
Hls := []
HlSet := Map()
Results := []
LabelIcons := []
LabelNames := []
CurTab := 1
ColsNow := COLS
Scroll := 0
PrevWin := 0
InSettings := false        ; Settings window is open (picker is only stepped aside)
ReopenPicker := false      ; picker was open when Settings was opened
Quitting := false          ; picker is hidden because the app is about to quit
AllLoaded := false         ; all emoji categories parsed (only needed for search / names)
HoverCell := 0
HoverTab := 0
NeedRebuild := false
KeepOpen := false          ; Settings: do not close after inserting an emoji
FavOn := true              ; Settings: favorites feature
HlOn := true               ; Settings: highlight feature
ResMode := 2               ; Settings: memory in the tray  1 = lowest, 2 = balanced, 3 = fastest
PinTray := true            ; Settings: keep the tray icon on the taskbar (Windows 11)
g := 0
sg := 0
Canvas := 0
Inserting := false        ; an emoji is being pasted right now (blocks re-entry)
MouseTracked := false      ; WM_MOUSELEAVE tracking is active on the canvas
GdipToken := 0             ; GDI+ is started once and stays up (see GdipEnsure)
SettingsHbm := 0           ; bitmap of the Settings button icon (redrawn in the theme colour on every BuildGui)
CvH := 0, SprSize := 0
SpriteTried := false

; ---------- Direct2D / DirectWrite state ----------
D2F := 0, DWF := 0, RT := 0, Sprite := 0
Brushes := Map()
Fmts := Map()
FlagIdx := Map()
ClearCol := Buffer(16, 0)

; ---------- Settings (one read of the ini file) ----------
Theme := "dark", Thumb := 3, LastTab := 0
cfg := Map()
try {
    Loop Parse, IniRead(SettingsFile, "Settings"), "`n", "`r" {
        eq := InStr(A_LoopField, "=")
        if eq
            cfg[SubStr(A_LoopField, 1, eq - 1)] := SubStr(A_LoopField, eq + 1)
    }
}
try LastTab := Integer(cfg.Get("LastTab", 0))
try Thumb := Integer(cfg.Get("Size", 3))
try KeepOpen := (cfg.Get("KeepOpen", 0) = 1)
try FavOn := (cfg.Get("Favorites", 1) = 1)
try HlOn := (cfg.Get("Highlights", 1) = 1)
try ResMode := Max(1, Min(3, Integer(cfg.Get("TrayMemory", 2))))
try PinTray := (cfg.Get("PinTrayIcon", 1) = 1)
Theme := (cfg.Get("Theme", "dark") = "light") ? "light" : "dark"
Thumb := Max(1, Min(3, Thumb))
DefaultKey := "#."                       ; Win + .
HotkeyStr := cfg.Get("Hotkey", DefaultKey)
CloseMode := (cfg.Get("CloseAction", "exit") = "tray") ? "tray" : "exit"      ; what the close button does
cfg := ""

; ---------- Start Direct2D ----------
try {
    D2DStart()
} catch as err {
    MsgBox("Direct2D / DirectWrite could not be started:`n" err.Message, "Emoji Picker", 16)
    ExitApp
}

; ---------- Load data ----------
if !FileExist(DataFile) {
    MsgBox("EmojiData.dat was not found in the data folder:`n" DataFile, "Emoji Picker", 16)
    ExitApp
}
LoadCats()
LoadList(RecentFile, Recents)
LoadSet(FavFile, Favs, FavSet)
LoadSet(HlFile, Hls, HlSet)

; Picture-sheet lists + category text. Called at start and again after the "Lowest" tray mode freed them.
LoadCats() {
    global Cats
    try {
        if (FileExist(FlagListFile) && FileExist(FlagSheetFile) && !FlagIdx.Count)
            ReadIndexList(FlagListFile, FlagIdx)
        if (FileExist(ExtraListFile) && FileExist(ExtraSheetFile) && !ExtraIdx.Count)
            ReadIndexList(ExtraListFile, ExtraIdx)
    }
    if Cats.Length
        return
    ; Only the tab names / icons are read now; the emoji of a category are parsed when it is first needed
    raw := ""
    try raw := FileRead(DataFile, "UTF-8")
    raw := "`n" StrReplace(raw, "`r")
    list := []
    for i, part in StrSplit(raw, "`n@@") {              ; "@@tab name|tab icon" starts a category
        if (i = 1)
            continue
        nl := InStr(part, "`n")
        p := StrSplit(nl ? SubStr(part, 1, nl - 1) : part, "|")
        list.Push({name: p[1], icon: (p.Length > 1 ? p[2] : ""), raw: nl ? SubStr(part, nl + 1) : "", items: 0})
    }
    Cats := list
}

; Emoji of one category: each line is  emoji <TAB> search words
; (k = kind of drawing, filled in by ItemKind: -1 unknown, 0 text, 1 flag sheet, 2 extra sheet; si = sheet position)
EnsureCat(c) {
    if IsObject(c.items)
        return c.items
    items := []
    Loop Parse, c.raw, "`n" {
        tb := InStr(A_LoopField, "`t")
        if tb
            items.Push({e: SubStr(A_LoopField, 1, tb - 1), n: SubStr(A_LoopField, tb + 1), k: -1, si: 0})
    }
    c.items := items
    return items
}

; All categories + the emoji -> item map (needed for search and for the names of history items)
EnsureAll() {
    global AllLoaded
    if AllLoaded
        return
    for c in Cats {
        for it in EnsureCat(c) {
            if !ItemMap.Has(it.e)
                ItemMap[it.e] := it
        }
    }
    AllLoaded := true
}

; Item for a history emoji; its name is filled in only when needed (see ItemName)
ItemFor(e) {
    static lite := Map()
    if (AllLoaded && ItemMap.Has(e))
        return ItemMap[e]
    if !lite.Has(e)
        lite[e] := {e: e, n: "", k: -1, si: 0}
    return lite[e]
}

ItemName(it) {
    if (it.n != "")
        return it.n
    EnsureAll()
    return ItemMap.Has(it.e) ? ItemMap[it.e].n : ""
}

; How an emoji is drawn: 0 = text (Segoe UI Emoji), 1 = Flags.png, 2 = Extra.png. Cached on the item.
ItemKind(it) {
    if (it.k >= 0)
        return it.k
    e := it.e
    if FlagIdx.Has(e) {
        it.k := 1
        it.si := FlagIdx[e]
    } else {
        s := StrReplace(e, Chr(0xFE0F), "")
        if ExtraIdx.Has(s) {
            it.k := 2
            it.si := ExtraIdx[s]
        } else
            it.k := 0
    }
    return it.k
}

LoadList(path, arr) {
    txt := ""
    try txt := FileRead(path, "UTF-8")
    Loop Parse, txt, "`n", "`r" {
        if (A_LoopField != "")
            arr.Push(A_LoopField)
    }
}

LoadSet(path, arr, set) {
    txt := ""
    try txt := FileRead(path, "UTF-8")
    Loop Parse, txt, "`n", "`r" {
        if (A_LoopField != "" && !set.Has(A_LoopField)) {
            arr.Push(A_LoopField)
            set[A_LoopField] := 1
        }
    }
}

SetTimer(TrimMem, -3000)          ; once, shortly after start: hand unused memory back to Windows
OnMessage(0x0006, OnActivate)     ; WM_ACTIVATE      -> close when focus is lost
OnMessage(0x002B, OnDrawItem)     ; WM_DRAWITEM      -> paint the Direct2D canvas
OnMessage(0x0200, OnMouseMove)    ; WM_MOUSEMOVE     -> hover highlight + name
OnMessage(0x02A3, OnMouseLeave)   ; WM_MOUSELEAVE    -> clear the hover highlight
OnMessage(0x0201, OnLButtonDown)  ; WM_LBUTTONDOWN   -> pick / switch tab / drag window
OnMessage(0x0203, OnLButtonDown)  ; WM_LBUTTONDBLCLK
OnMessage(0x0204, OnRButtonDown)  ; WM_RBUTTONDOWN   -> favorite (needs two right-clicks)
OnMessage(0x0206, OnRButtonDown)  ; WM_RBUTTONDBLCLK -> favorite (needs two right-clicks)
OnMessage(0x0207, OnMButtonDown)  ; WM_MBUTTONDOWN   -> highlight
OnMessage(0x0209, OnMButtonDown)  ; WM_MBUTTONDBLCLK -> highlight

; ---------- Tray menu ----------
A_TrayMenu.Delete()
A_TrayMenu.Add("Open", TrayOpen)
A_TrayMenu.Add("Settings", OpenSettings)
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Open"
A_TrayMenu.ClickCount := 1
A_IconTip := "Emoji Picker"
A_IconHidden := false                       ; the tray icon is always created
if FileExist(IconFile)
    try TraySetIcon(IconFile)
if PinTray
    SetTimer(PinTrayIcon.Bind(true, 1), -2000)

; Windows 11 keeps new tray icons in the hidden-icons overflow. Its per-icon switch lives in
; HKCU\Control Panel\NotifyIconSettings\<id>\IsPromoted (1 = shown on the taskbar). Windows creates
; that entry a moment after the icon appears, so this retries a few times. The entry belongs to the
; program that runs the script (AutoHotkey64.exe). Nothing happens on systems without that key.
PinTrayIcon(on, attempt) {
    static root := "HKCU\Control Panel\NotifyIconSettings"
    me := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
    SplitPath(me, &exe)
    found := false
    try {
        Loop Reg, root, "K" {
            key := root "\" A_LoopRegName
            p := RegRead(key, "ExecutablePath", "")
            if (p = "")
                continue
            SplitPath(p, &pexe)
            if (pexe != exe)
                continue
            found := true
            if (RegRead(key, "IsPromoted", 0) != (on ? 1 : 0))
                RegWrite(on ? 1 : 0, "REG_DWORD", key, "IsPromoted")
        }
    }
    if (!found && attempt < 4)
        SetTimer(PinTrayIcon.Bind(on, attempt + 1), -3000)
}

; ---------- Shortcut ----------
if !ApplyHotkey(HotkeyStr)
    ApplyHotkey(DefaultKey)

; ---------- Open the picker right away ----------
ShowPicker()

; Reads a list file (one emoji per line) into a Map: emoji -> position in its picture sheet
ReadIndexList(path, m) {
    txt := ""
    try txt := FileRead(path, "UTF-8")
    n := 0
    Loop Parse, txt, "`n", "`r" {
        if (A_LoopField != "") {
            m[A_LoopField] := n
            n += 1
        }
    }
}

; Registers the open / close shortcut (and removes the previous one). Returns false if it is not usable.
ApplyHotkey(key) {
    global HotkeyStr
    old := HotkeyStr
    try {
        HotIf()
        Hotkey(key, HotkeyOpen, "On")
    } catch {
        return false
    }
    if (old != key)
        try Hotkey(old, "Off")
    HotkeyStr := key
    return true
}

HotkeyOpen(*) {
    global PrevWin
    if Inserting
        return
    if InSettings {
        try WinActivate("ahk_id " sg.Hwnd)
        return
    }
    if PickerVisible() {
        if WinActive("ahk_id " g.Hwnd)
            DoClose()
        else {
            PrevWin := WinExist("A")
            WinActivate("ahk_id " g.Hwnd)
            SearchBox.Focus()
        }
        return
    }
    ShowPicker()
}

TrayOpen(*) {
    global PrevWin
    if Inserting
        return
    if InSettings {
        try WinActivate("ahk_id " sg.Hwnd)
        return
    }
    if PickerVisible() {
        WinActivate("ahk_id " g.Hwnd)
        SearchBox.Focus()
        return
    }
    PrevWin := LastAppWindow()                 ; the tray menu itself is not the target window
    ShowPicker(true)
}

PickerVisible() {
    return (IsObject(g) && DllCall("IsWindowVisible", "ptr", g.Hwnd))
}

; Window that was in use before the picker was opened from the tray menu
LastAppWindow() {
    gh := IsObject(g) ? g.Hwnd : 0
    for hwnd in WinGetList() {
        if (hwnd = gh)
            continue
        try {
            id := "ahk_id " hwnd
            cls := WinGetClass(id)
            if (cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd" || cls = "NotifyIconOverflowWindow"
                || cls = "TopLevelWindowForOverflowXamlIsland" || cls = "Windows.UI.Core.CoreWindow"
                || cls = "Progman" || cls = "WorkerW" || cls = "#32768" || cls = "AutoHotkey")
                continue
            if (WinGetExStyle(id) & 0x80)                 ; tool window
                continue
            if (WinGetMinMax(id) = -1 || WinGetTitle(id) = "")
                continue
            cloaked := 0
            DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 14, "uint*", &cloaked, "uint", 4)
            if cloaked
                continue
            return hwnd
        }
    }
    return 0
}

; X button / Esc / click away / after pasting: what happens is set in Settings > Close button.
; (scheduled, so a window is never destroyed from inside its own message handler)
ClosePicker() {
    SetTimer(DoClose, -1)
}

DoClose() {
    if (CloseMode = "tray")
        HideToTray()
    else
        ExitApp()
}

; Minimize to the tray: the window, the graphics and the emoji data are released.
; Only the tray icon and the shortcut stay; ShowPicker builds everything again.
HideToTray() {
    global g, Canvas, Quitting
    SetTimer(DoClose, 0)                         ; forget a duplicate close request that is still queued
    SetTimer(DragScroll, 0)
    PickerKeys(false)
    if (ResMode = 3 && IsObject(g)) {            ; "Fastest": only hide, so it opens instantly
        Quitting := true                          ; hiding must not count as "click away"
        try g.Hide()
        Quitting := false
        FreeSprite()
        FreeExtra()
        SetTimer(TrimMem, -300)
        return
    }
    Quitting := true                              ; destroying the window must not count as "click away"
    old := g
    g := 0                                        ; message handlers see "no window" while it is torn down
    Canvas := 0
    D2DRelease()
    if IsObject(old)
        try old.Destroy()
    FreeData()
    Quitting := false
    SetTimer(TrimMem, -300)
}

FreeData() {
    global ItemMap, AllLoaded, Results, Cats
    for c in Cats
        c.items := 0
    ItemMap := Map()
    AllLoaded := false
    Results := []
    if (ResMode = 1) {                           ; "Lowest": also drop the emoji text and picture lists
        Cats := []                               ; (LoadCats reads them again on the next open)
        FlagIdx.Clear()
        ExtraIdx.Clear()
    }
}

PickerActive(*) {
    return (IsObject(g) && WinActive("ahk_id " g.Hwnd))
}

; Keys used only while the picker is open (so no keyboard / mouse hook work happens in the tray)
PickerKeys(on) {
    static keys := [["Esc", (*) => ClosePicker()]
                  , ["Enter", (*) => PickIndex(1)]
                  , ["NumpadEnter", (*) => PickIndex(1)]
                  , ["Up", (*) => ChangeScroll(-1)]
                  , ["Down", (*) => ChangeScroll(1)]
                  , ["PgUp", (*) => ChangeScroll(-ROWS)]
                  , ["PgDn", (*) => ChangeScroll(ROWS)]]
    static wheel := [["WheelUp", (*) => ChangeScroll(-2)]
                   , ["WheelDown", (*) => ChangeScroll(2)]]
    static made := false
    if (!on && !made)
        return
    try {
        HotIf(PickerActive)
        for k in keys {
            if made
                Hotkey(k[1], on ? "On" : "Off")
            else
                Hotkey(k[1], k[2], "On")
        }
        HotIf(PickerUnderMouse)
        for k in wheel {
            if made
                Hotkey(k[1], on ? "On" : "Off")
            else
                Hotkey(k[1], k[2], "On")
        }
        made := true
    }
    HotIf()
}

; Moves files written by older versions into the new user-data folder
MigrateOldData() {
    if FileExist(SettingsFile)                         ; already on the new layout
        return
    try DirCreate(UserDir)
    moves := [[A_ScriptDir "\Emoji Picker Data\EmojiPicker_recent.dat", RecentFile]
            , [A_ScriptDir "\Emoji Picker Data\EmojiPicker_favorites.dat", FavFile]
            , [OldSettingsFile, SettingsFile]]
    for m in moves {
        if (FileExist(m[1]) && !FileExist(m[2]))
            try FileMove(m[1], m[2])
    }
    try FileDelete(UserDir "\Emoji Picker font check.crash")      ; no longer used
    try FileDelete(OldSettingsDir "\Emoji Picker font check.crash")
}

; =====================================================================
;  Direct2D / DirectWrite helpers
; =====================================================================
Step(txt) {
    if DebugLog
        try FileAppend(txt "`n", LogFile)
}

; Calls method number idx of a COM interface pointer (own version of ComCall).
; Returns the HRESULT (negative = failure).
VCall(idx, obj, params*) {
    if !obj
        throw Error("VCall: null interface pointer (method " idx ")")
    fn := NumGet(NumGet(obj, "ptr"), idx * A_PtrSize, "ptr")
    a := ["ptr", obj]
    a.Push(params*)
    a.Push("int")
    return DllCall(fn, a*)
}

D2DStart() {
    global D2F, DWF
    ; Keep both DLLs loaded for the whole run. Without this, AutoHotkey unloads a DLL
    ; again after a DllCall, which leaves the COM objects pointing at unmapped code.
    DllCall("kernel32\LoadLibraryW", "wstr", "d2d1.dll", "ptr")
    DllCall("kernel32\LoadLibraryW", "wstr", "dwrite.dll", "ptr")
    guid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", "{06152247-6F50-465A-9245-118BFD3B6007}", "ptr", guid)   ; ID2D1Factory
    Step("D2D1CreateFactory")
    fac := 0
    if DllCall("d2d1\D2D1CreateFactory", "uint", 0, "ptr", guid, "ptr", 0, "ptr*", &fac, "uint")
        throw Error("D2D1CreateFactory failed")
    D2F := fac
    Step("D2F = " D2F)

    DllCall("ole32\CLSIDFromString", "wstr", "{b859ee5a-d838-4b5b-a2e8-1adc7d93db48}", "ptr", guid)   ; IDWriteFactory
    Step("DWriteCreateFactory")
    dw := 0
    if DllCall("dwrite\DWriteCreateFactory", "uint", 0, "ptr", guid, "ptr*", &dw, "uint")
        throw Error("DWriteCreateFactory failed")
    DWF := dw
    Step("DWF = " DWF)
    if (!D2F || !DWF)
        throw Error("A factory pointer is empty: D2F=" D2F "  DWF=" DWF)
    Step("D2F vtable=" NumGet(D2F, "ptr") "  method14=" NumGet(NumGet(D2F, "ptr"), 14 * A_PtrSize, "ptr"))
    Step("DWF vtable=" NumGet(DWF, "ptr") "  method3=" NumGet(NumGet(DWF, "ptr"), 3 * A_PtrSize, "ptr"))
}

D2DRelease() {
    global RT, Brushes, Fmts
    FreeExtra()
    FreeSprite()
    for , b in Brushes {
        if b
            ObjRelease(b)
    }
    Brushes := Map()
    for , f in Fmts {
        if f
            ObjRelease(f)
    }
    Fmts := Map()
    if RT {
        ObjRelease(RT)
        RT := 0
    }
}

D2DInit(hwnd, w, h, sizes) {
    global RT, Brushes, Fmts, ClearCol
    rtp := Buffer(28, 0)                      ; D2D1_RENDER_TARGET_PROPERTIES
    NumPut("float", 96, rtp, 12)              ; dpiX
    NumPut("float", 96, rtp, 16)              ; dpiY  (1 DIP = 1 pixel)
    hp := Buffer(24, 0)                       ; D2D1_HWND_RENDER_TARGET_PROPERTIES
    NumPut("ptr", hwnd, hp, 0)
    NumPut("uint", w, hp, A_PtrSize)
    NumPut("uint", h, hp, A_PtrSize + 4)
    NumPut("uint", 2, hp, A_PtrSize + 8)      ; present immediately
    Step("CreateHwndRenderTarget")
    rt := 0
    hr := VCall(14, D2F, "ptr", rtp, "ptr", hp, "ptr*", &rt)   ; CreateHwndRenderTarget
    if (hr < 0 || !rt)
        throw Error("CreateHwndRenderTarget failed (HRESULT 0x" Format("{:X}", hr & 0xFFFFFFFF) ")")
    RT := rt
    Step("brushes")

    for name in ["bg", "tab", "tabSel", "cell", "fav", "hl", "hlLine", "text", "hover", "sbTrack", "sbThumb"]
        Brushes[name] := MakeBrush(Col.%name%)
    v := Integer("0x" Col.bg)
    NumPut("float", ((v >> 16) & 255) / 255, "float", ((v >> 8) & 255) / 255, "float", (v & 255) / 255, "float", 1.0, ClearCol)

    Step("text formats")
    Fmts["e"] := MakeFmt("Segoe UI Emoji", sizes.e, false)
    Fmts["t"] := MakeFmt("Segoe UI Emoji", sizes.t, false)
    Step("D2DInit done")
}

MakeBrush(hex) {
    v := Integer("0x" hex)
    c := Buffer(16)
    NumPut("float", ((v >> 16) & 255) / 255, "float", ((v >> 8) & 255) / 255, "float", (v & 255) / 255, "float", 1.0, c)
    b := 0
    VCall(8, RT, "ptr", c, "ptr", 0, "ptr*", &b)         ; CreateSolidColorBrush
    return b
}

MakeFmt(family, size, wrap) {
    tf := 0
    VCall(15, DWF, "wstr", family, "ptr", 0, "int", 400, "int", 0, "int", 5, "float", size, "wstr", "en-us", "ptr*", &tf)   ; CreateTextFormat
    VCall(3, tf, "int", 2)                               ; text alignment: center
    VCall(4, tf, "int", 2)                               ; paragraph alignment: center
    VCall(5, tf, "int", wrap ? 0 : 1)                    ; word wrapping
    return tf
}

; The picture sheets are loaded the first time an emoji that needs one is on screen and are
; kept until the picker is hidden (reloading them on every scroll / tab change was slow)
FreeSprite() {
    global Sprite, SpriteTried
    if Sprite {
        ObjRelease(Sprite)
        Sprite := 0
    }
    SpriteTried := false
}

FreeExtra() {
    global ExtraSheet, ExtraTried
    if ExtraSheet {
        ObjRelease(ExtraSheet)
        ExtraSheet := 0
    }
    ExtraTried := false
}

LoadSprite() {
    global Sprite, SpriteTried
    if (Sprite || SpriteTried || !FlagIdx.Count || !FileExist(FlagSheetFile))
        return
    SpriteTried := true                          ; a failed load is not retried on every repaint
    Sprite := LoadBitmapFile(FlagSheetFile)
}

LoadExtra() {
    global ExtraSheet, ExtraTried
    if (ExtraSheet || ExtraTried || !ExtraIdx.Count || !FileExist(ExtraSheetFile))
        return
    ExtraTried := true
    ExtraSheet := LoadBitmapFile(ExtraSheetFile)
}

TrimMem() {
    DllCall("psapi\EmptyWorkingSet", "ptr", DllCall("kernel32\GetCurrentProcess", "ptr"))
}

; GDI+ is started ONCE and then kept for the whole run. Starting / stopping it and unloading
; gdiplus.dll again around every picture load (what 1.3.0 did on every popup) can crash the
; process, because GDI+ has a background thread that may still be running inside the DLL.
GdipEnsure() {
    global GdipToken
    if GdipToken
        return true
    if !DllCall("kernel32\LoadLibraryW", "wstr", "gdiplus.dll", "ptr")
        return false
    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("uint", 1, si)                                      ; GdiplusVersion = 1
    tok := 0
    if (DllCall("gdiplus\GdiplusStartup", "ptr*", &tok, "ptr", si, "ptr", 0, "uint") != 0 || !tok)
        return false
    GdipToken := tok
    return true
}

; Loads a PNG as a Direct2D bitmap (0 on failure). The pixels are copied into the Direct2D
; bitmap, so the GDI+ image is disposed again at once.
LoadBitmapFile(path) {
    d2b := 0, img := 0
    if (!RT || !GdipEnsure())
        return 0
    try {
        DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", path, "ptr*", &img)
        if img {
            w := 0, h := 0
            DllCall("gdiplus\GdipGetImageWidth", "ptr", img, "uint*", &w)
            DllCall("gdiplus\GdipGetImageHeight", "ptr", img, "uint*", &h)
            rc := Buffer(16, 0)
            NumPut("int", 0, "int", 0, "int", w, "int", h, rc)
            bd := Buffer(16 + 2 * A_PtrSize, 0)                ; BitmapData
            if (DllCall("gdiplus\GdipBitmapLockBits", "ptr", img, "ptr", rc, "uint", 1, "int", 0xE200B, "ptr", bd, "uint") = 0) {   ; read, 32bpp PARGB
                try {
                    stride := NumGet(bd, 8, "int")
                    scan0 := NumGet(bd, 16, "ptr")
                    props := Buffer(16, 0)                     ; D2D1_BITMAP_PROPERTIES
                    NumPut("uint", 87, "uint", 1, "float", 96, "float", 96, props)   ; B8G8R8A8_UNORM, premultiplied
                    if (A_PtrSize = 8)
                        VCall(4, RT, "int64", w | (h << 32), "ptr", scan0, "uint", stride, "ptr", props, "ptr*", &d2b)
                    else
                        VCall(4, RT, "uint", w, "uint", h, "ptr", scan0, "uint", stride, "ptr", props, "ptr*", &d2b)
                }
                DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", img, "ptr", bd)
            }
        }
    }
    if img
        DllCall("gdiplus\GdipDisposeImage", "ptr", img)
    return d2b
}

; Draws cell number fi of a picture sheet (same layout as Flags.png) centred in the given cell
DrawSprite(bmp, fi, x, y, w, h) {
    static dst := Buffer(16), src := Buffer(16)
    sx := Mod(fi, FlagCols) * FlagSize
    sy := (fi // FlagCols) * FlagSize
    dx := x + (w - SprSize) / 2, dy := y + (h - SprSize) / 2
    NumPut("float", dx, "float", dy, "float", dx + SprSize, "float", dy + SprSize, dst)
    NumPut("float", sx, "float", sy, "float", sx + FlagSize, "float", sy + FlagSize, src)
    VCall(26, RT, "ptr", bmp, "ptr", dst, "float", 1.0, "int", 1, "ptr", src)   ; DrawBitmap
}

FillRR(x, y, w, h, brush, rad) {
    static r := Buffer(24)
    NumPut("float", x, "float", y, "float", x + w, "float", y + h, "float", rad, "float", rad, r)
    VCall(19, RT, "ptr", r, "ptr", brush)                ; FillRoundedRectangle
}

DrawTxt(txt, fmt, x, y, w, h, brush) {
    static r := Buffer(16)
    NumPut("float", x, "float", y, "float", x + w, "float", y + h, r)
    ; options: 2 = clip, 4 = colour glyphs
    VCall(27, RT, "ptr", StrPtr(txt), "uint", StrLen(txt), "ptr", fmt, "ptr", r, "ptr", brush, "int", 6, "int", 0)   ; DrawText
}

; Paints tabs + result grid onto the canvas
PaintCanvas() {
    global NeedRebuild
    if (!RT || !IsObject(Canvas) || Quitting)
        return
    n := Results.Length
    if (FlagIdx.Count || ExtraIdx.Count) {
        needFlags := false, needExtra := false
        Loop ColsNow * ROWS {
            idx := Scroll * ColsNow + A_Index
            if (idx > n)
                break
            kd := ItemKind(Results[idx])
            if (kd = 1)
                needFlags := true
            else if (kd = 2)
                needExtra := true
        }
        if needFlags
            LoadSprite()
        if needExtra
            LoadExtra()
    }
    rad := Round(4 * k)
    VCall(48, RT)                                        ; BeginDraw
    try {
        VCall(47, RT, "ptr", ClearCol)                   ; Clear

        for i, icon in LabelIcons {
            x := GX + Mod(i - 1, COLS) * Cell
            y := ((i - 1) // COLS) * TabH
            nm := (i = CurTab) ? "tabSel" : (i = HoverTab ? "hover" : "tab")
            FillRR(x, y, Cell - 2, TabH - 2, Brushes[nm], rad)
            DrawTxt(icon, Fmts["t"], x, y, Cell - 2, TabH - 2, Brushes["text"])
        }

        gy0 := GridY - CvY
        fmt := Fmts["e"]
        Loop ColsNow * ROWS {
            i := A_Index
            idx := Scroll * ColsNow + i
            x := GX + Mod(i - 1, ColsNow) * Cell
            y := gy0 + ((i - 1) // ColsNow) * Cell
            isItem := (idx <= n)
            nm := "cell"
            isHl := false
            if isItem {
                e := Results[idx].e
                isHl := (HlOn && HlSet.Has(e))
                if (FavOn && FavSet.Has(e))
                    nm := "fav"
                else if isHl
                    nm := "hl"
                else if (i = HoverCell)
                    nm := "hover"
            }
            if isHl {                                    ; highlight mark = blue frame (also shown on favorites)
                bw := Max(2, Round(2 * k))
                FillRR(x, y, Cell - 2, Cell - 2, Brushes["hlLine"], rad)
                FillRR(x + bw, y + bw, Cell - 2 - 2 * bw, Cell - 2 - 2 * bw, Brushes[nm], Max(1, rad - bw))
            } else
                FillRR(x, y, Cell - 2, Cell - 2, Brushes[nm], rad)
            if !isItem
                continue
            it := Results[idx]
            kd := ItemKind(it)
            if (kd = 1 && Sprite)
                DrawSprite(Sprite, it.si, x, y, Cell - 2, Cell - 2)
            else if (kd = 2 && ExtraSheet)
                DrawSprite(ExtraSheet, it.si, x, y, Cell - 2, Cell - 2)
            else
                DrawTxt(it.e, fmt, x, y, Cell - 2, Cell - 2, Brushes["text"])
        }

        ; scrollbar (only when there is more than one page)
        totalRows := Ceil(n / ColsNow)
        if (totalRows > ROWS) {
            trackH := ROWS * Cell
            sbw := Round(6 * k)
            sbx := GX + COLS * Cell + (SB - sbw) // 2
            thumbH := Max(Round(24 * k), trackH * ROWS // totalRows)
            ty := gy0 + (trackH - 2 - thumbH) * Scroll / (totalRows - ROWS)
            FillRR(sbx, gy0, sbw, trackH - 2, Brushes["sbTrack"], sbw / 2)
            FillRR(sbx, ty, sbw, thumbH, Brushes["sbThumb"], sbw / 2)
        }
    } catch as err {
        Step("PaintCanvas: " err.Message)                ; never leave a BeginDraw without its EndDraw
    }

    if (VCall(49, RT, "ptr", 0, "ptr", 0) < 0 && !NeedRebuild) {     ; EndDraw: target lost (sleep, GPU reset, display change)
        NeedRebuild := true
        SetTimer(RecreateTarget, -10)
    }
}

; The Direct2D target was lost: make a new one for the same window (tab, search and position stay)
RecreateTarget() {
    global NeedRebuild
    NeedRebuild := false
    if (!IsObject(g) || !IsObject(Canvas))
        return
    vis := PickerVisible()
    try {
        D2DRelease()
        px := A_ScreenDPI / 72
        D2DInit(Canvas.Hwnd, W, CvH, {e: FsEmoji * px, t: FsTab * px})
        PaintCanvas()
        return
    }
    try {                                                ; could not recreate it: build the window again
        BuildGui()
        if vis
            ShowPicker(true)
    }
}

OnDrawItem(wParam, lParam, msg, hwnd) {
    if (!IsObject(g) || !IsObject(Canvas) || hwnd != g.Hwnd)
        return
    if (NumGet(lParam, A_PtrSize = 8 ? 24 : 20, "ptr") != Canvas.Hwnd)
        return
    PaintCanvas()
    return 1
}

; Which tab / grid cell is at canvas position (x, y)?
HitTest(x, y) {
    if (y >= 0 && y < TabRows * TabH) {
        if (x < GX)
            return 0
        c := (x - GX) // Cell
        if (c >= COLS)
            return 0
        i := (y // TabH) * COLS + c + 1
        return (i <= LabelIcons.Length) ? {kind: "t", i: i} : 0
    }
    gy := y - (GridY - CvY)
    if (gy < 0 || gy >= ROWS * Cell)
        return 0
    if (x < GX)
        return 0
    c := (x - GX) // Cell
    if (c >= ColsNow)
        return 0
    return {kind: "c", i: (gy // Cell) * ColsNow + c + 1}
}

; =====================================================================
;  GUI construction
; =====================================================================
FontPt(n) {
    return n
}

BuildGui() {
    global g, SearchBox, SettingsBtn, CloseBtn, Canvas, Status, RangeLbl, LabelIcons, LabelNames, HoverCell, HoverTab, MouseTracked, SettingsHbm
    global k, SB, Cell, Pad, GX, W, H, GridY, TabH, TabRows, CvY, CvH, ColsNow, Col, FsEmoji, FsTab, SprSize

    ; drop the old window first (g = 0, so no message handler touches it while it is destroyed)
    old := g
    g := 0
    Canvas := 0
    D2DRelease()
    if IsObject(old)
        try old.Destroy()
    if SettingsHbm {                                  ; the old window is gone, so its icon bitmap can be freed
        DllCall("gdi32\DeleteObject", "ptr", SettingsHbm)
        SettingsHbm := 0
    }
    HoverCell := 0, HoverTab := 0, MouseTracked := false

    if (Theme = "light")
        Col := {bg: "F3F3F3", input: "FFFFFF", text: "1F1F1F", tab: "E4E4E4", tabSel: "BDBDBD", cell: "FFFFFF", sub: "606060", btn: "E4E4E4", fav: "FFEFA8", hl: "D3E6FB", hlLine: "3B8EE0", hover: "D9D9D9", border: "8A8A8A", bar: "E1E1E1", barLine: "C4C4C4", sbTrack: "E4E4E4", sbThumb: "A6A6A6"}
    else
        Col := {bg: "1F1F1F", input: "2D2D2D", text: "FFFFFF", tab: "262626", tabSel: "555555", cell: "262626", sub: "A0A0A0", btn: "2D2D2D", fav: "4B4020", hl: "223F5F", hlLine: "4C9AEB", hover: "3A3A3A", border: "6E6E6E", bar: "2F2F2F", barLine: "454545", sbTrack: "2A2A2A", sbThumb: "6E6E6E"}

    k := A_ScreenDPI / 96
    Cell := Round(CellBase[Thumb] * k)
    Pad := Round(10 * k)
    SearchH := Round(28 * k)
    TabH := Round(Cell * 0.8)
    StatusH := Round(26 * k)
    SB := Pad                         ; scrollbar column = the normal right padding (no extra gap)
    W := Cell * COLS + 2 * Pad
    GX := Pad
    Tab1Y := Pad + SearchH + Round(8 * k)
    TabRows := Ceil((1 + Cats.Length) / COLS)
    GridY := Tab1Y + TabRows * TabH + Round(6 * k)
    StatusY := GridY + Cell * ROWS + Round(8 * k)     ; top of the status bar (full width, flush with the bottom)
    H := StatusY + StatusH
    CvY := Tab1Y
    CvH := GridY + Cell * ROWS - Tab1Y
    FsEmoji := FontPt(FsEmojiBase[Thumb])
    FsTab := FontPt(FsTabBase[Thumb])

    g := Gui("-Caption +AlwaysOnTop +ToolWindow +Border", "Emoji Picker")
    g.BackColor := Col.bg
    g.MarginX := 0, g.MarginY := 0

    ; search box | settings | close  (buttons have a thin border like the search box)
    btnW := SearchH, gap := Round(6 * k)
    g.SetFont("s" FontPt(11) " c" Col.text, "Segoe UI")
    SearchBox := g.Add("Edit", Format("x{} y{} w{} h{} Background{}", Pad, Pad, W - 2 * Pad - 2 * btnW - 2 * gap, SearchH, Col.input))
    SendMessage(0x1501, 1, StrPtr("Search emoji"), SearchBox)   ; placeholder text
    SearchBox.OnEvent("Change", OnSearch)

    SettingsBtn := AddIconBtn(W - Pad - 2 * btnW - gap, Pad, btnW, SearchH)
    SettingsBtn.OnEvent("Click", OpenSettings)
    SettingsBtn.OnEvent("DoubleClick", OpenSettings)

    g.SetFont("s" FontPt(12) " c" Col.text, "Segoe UI Symbol")
    CloseBtn := AddBtn("✕", W - Pad - btnW, Pad, btnW, SearchH)
    CloseBtn.OnEvent("Click", (*) => ClosePicker())
    CloseBtn.OnEvent("DoubleClick", (*) => ClosePicker())

    ; Category tabs: emoji groups on row 1, symbol sets + kaomoji on row 2
    LabelIcons := ["🕘"]
    LabelNames := ["Recently used"]
    for c in Cats {
        LabelIcons.Push(c.icon)
        LabelNames.Push(c.name)
    }

    ; One owner-drawn canvas (tabs + result grid) painted in colour by Direct2D
    ; 0x10D = SS_OWNERDRAW | SS_NOTIFY
    Canvas := g.Add("Text", Format("x0 y{} w{} h{} 0x10D", Tab1Y, W, CvH))

    ; Footer: hovered name | position
    g.SetFont("s" FontPt(9) " c" Col.sub, "Segoe UI")
    fw := W - 2 * Pad
    rangeW := Round(85 * k)
    g.Add("Text", Format("x0 y{} w{} h{} Background{}", StatusY, W, StatusH, Col.bar))            ; status bar background
    g.Add("Text", Format("x0 y{} w{} h1 Background{}", StatusY, W, Col.barLine))                 ; thin separator line on top
    Status := g.Add("Text", Format("x{} y{} w{} h{} +0x200 Background{}", Pad, StatusY + 1, fw - rangeW, StatusH - 1, Col.bar), "")
    RangeLbl := g.Add("Text", Format("x{} y{} w{} h{} Right +0x200 Background{}", Pad + fw - rangeW, StatusY + 1, rangeW, StatusH - 1, Col.bar), "")

    px := A_ScreenDPI / 72
    D2DInit(Canvas.Hwnd, W, CvH, {e: FsEmoji * px, t: FsTab * px})

    ColsNow := COLS
    SprSize := Round(FsEmoji * A_ScreenDPI / 72 * 1.15)        ; size of a flag / extra emoji picture
}

; A button = a 1px border frame with the button face inset inside it
AddBtn(txt, x, y, w, h) {
    g.Add("Text", Format("x{} y{} w{} h{} Background{}", x, y, w, h, Col.border))
    return g.Add("Text", Format("x{} y{} w{} h{} Center +0x200 Background{}", x + 1, y + 1, w - 2, h - 2, Col.tab), txt)
}

; Same frame as AddBtn, but the face shows a bitmap (0xE = SS_BITMAP) drawn in the current theme colours
AddIconBtn(x, y, w, h) {
    global SettingsHbm
    g.Add("Text", Format("x{} y{} w{} h{} Background{}", x, y, w, h, Col.border))
    face := g.Add("Text", Format("x{} y{} w{} h{} 0xE +0x200 Background{}", x + 1, y + 1, w - 2, h - 2, Col.tab))
    rc := Buffer(16, 0)
    DllCall("user32\GetClientRect", "ptr", face.Hwnd, "ptr", rc)         ; real size in pixels
    hbm := MakeSettingsBmp(NumGet(rc, 8, "int"), NumGet(rc, 12, "int"), Col.text, Col.tab)
    if hbm {
        SettingsHbm := hbm
        SendMessage(0x172, 0, hbm, face)                                   ; STM_SETIMAGE, IMAGE_BITMAP
    }
    return face
}

; Settings icon: two toggle switches (outline style), line colour = fg, face colour = bg.
; Drawn with GDI+ every time the window is built, so it always matches the Dark / Light theme.
MakeSettingsBmp(w, h, fg, bg) {
    if (w < 8 || h < 8 || !GdipEnsure())
        return 0
    bmp := 0, gfx := 0, pen := 0, hbm := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &bmp)   ; 32bpp ARGB
    if !bmp
        return 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &gfx)
    DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)                                                          ; anti-aliased
    DllCall("gdiplus\GdipGraphicsClear", "ptr", gfx, "uint", 0xFF000000 | Integer("0x" bg))

    s := Min(w, h)
    pw := s * 0.66, ph := s * 0.32, gap := s * 0.055                  ; switch width / height, space between the two
    sw := Max(1.3, s * 0.052)                                        ; line thickness
    x0 := (w - pw) / 2
    y0 := (h - (2 * ph + gap)) / 2
    kd := Max(1.5, (ph - 2 * sw) * 0.62 - sw)                        ; knob (circle) diameter, measured on the line centre

    DllCall("gdiplus\GdipCreatePen1", "uint", 0xFF000000 | Integer("0x" fg), "float", sw, "int", 2, "ptr*", &pen)
    Loop 2 {
        i := A_Index - 1                                             ; 0 = top switch (knob right), 1 = bottom switch (knob left)
        top := y0 + i * (ph + gap)
        px := x0 + sw / 2, py := top + sw / 2
        bw := pw - sw, bh := ph - sw
        path := 0
        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path)
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", px, "float", py, "float", bh, "float", bh, "float", 90, "float", 180)
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", px + bw - bh, "float", py, "float", bh, "float", bh, "float", 270, "float", 180)
        DllCall("gdiplus\GdipClosePathFigure", "ptr", path)
        DllCall("gdiplus\GdipDrawPath", "ptr", gfx, "ptr", pen, "ptr", path)
        DllCall("gdiplus\GdipDeletePath", "ptr", path)
        cx := (i = 0) ? x0 + pw - 0.6 * ph : x0 + 0.6 * ph
        cy := top + ph / 2
        DllCall("gdiplus\GdipDrawEllipse", "ptr", gfx, "ptr", pen, "float", cx - kd / 2, "float", cy - kd / 2, "float", kd, "float", kd)
    }
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", bmp, "ptr*", &hbm, "uint", 0xFF000000 | Integer("0x" bg))
    DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfx)
    DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
    return hbm
}

; =====================================================================
;  Settings window
; =====================================================================
OpenSettings(*) {
    global sg, InSettings, ReopenPicker
    if IsObject(sg) {
        try {
            if WinExist("ahk_id " sg.Hwnd) {
                WinActivate("ahk_id " sg.Hwnd)
                return
            }
        }
    }
    ReopenPicker := PickerVisible()
    InSettings := true                 ; the picker only steps aside, the app keeps running
    if IsObject(g) {
        g.Hide()
        FreeSprite()
        FreeExtra()
    }
    sg := Gui("+AlwaysOnTop", "Emoji Picker Settings")
    sg.SetFont("s10", "Segoe UI")
    sg.MarginX := 18, sg.MarginY := 16

    sg.Add("Text", "Section w120 h24 +0x200", "Theme")
    ddTheme := sg.Add("DropDownList", "ys w190 Choose" (Theme = "light" ? 2 : 1), ["Dark", "Light"])

    sg.Add("Text", "xs Section w120 h24 +0x200", "Size")
    ddThumb := sg.Add("DropDownList", "ys w190 Choose" Thumb, ["Small", "Normal", "Large"])

    ; shortcut: "Win" box + key box (the key box cannot capture the Windows key itself)
    sg.Add("Text", "xs Section w120 h24 +0x200", "Shortcut")
    cbWin := sg.Add("CheckBox", "ys h24 w56 Checked" (InStr(HotkeyStr, "#") ? 1 : 0), "Win +")
    hkKey := sg.Add("Hotkey", "x+4 yp w130", StrReplace(HotkeyStr, "#"))

    sg.Add("Text", "xs Section w120 h24 +0x200", "Close button")
    ddClose := sg.Add("DropDownList", "ys w190 Choose" (CloseMode = "tray" ? 2 : 1), ["Close the app entirely", "Minimize to the tray"])

    sg.Add("Text", "xs Section w120 h24 +0x200", "Memory in the tray")
    ddRes := sg.Add("DropDownList", "ys w190 Choose" ResMode, ["Lowest (release all)", "Balanced", "Fastest (keep ready)"])

    cbKeep := sg.Add("CheckBox", "xs y+14 Checked" (KeepOpen ? 1 : 0), "Don't close automatically after inserting an emoji")
    cbFav := sg.Add("CheckBox", "xs y+8 Checked" (FavOn ? 1 : 0), "Enable favorites (right-click an emoji twice)")
    cbHl := sg.Add("CheckBox", "xs y+8 Checked" (HlOn ? 1 : 0), "Enable highlights (middle-click an emoji)")
    cbPin := sg.Add("CheckBox", "xs y+8 Checked" (PinTray ? 1 : 0), "Always show the tray icon on the taskbar")

    ; short About, above the buttons
    sg.Add("Text", "xs y+18 w320 h1 0x10")                                   ; thin separator line
    sg.SetFont("s9 c808080", "Segoe UI")
    sg.Add("Text", "xs y+8 w320", "Version " AppVersion "`nMade by " AppAuthor)
    sg.SetFont("s10 cDefault", "Segoe UI")

    btnReset := sg.Add("Button", "xs y+16 w100", "Reset")
    btnSave := sg.Add("Button", "x+10 w100 Default", "Save")
    btnCancel := sg.Add("Button", "x+10 w100", "Cancel")

    ; Reset = put every option back to its default (nothing is saved until you press Save)
    btnReset.OnEvent("Click", (*) => (ddTheme.Choose(1), ddThumb.Choose(3), cbWin.Value := 1, hkKey.Value := SubStr(DefaultKey, 2)
        , ddClose.Choose(1), ddRes.Choose(2), cbKeep.Value := 0, cbFav.Value := 1, cbHl.Value := 1, cbPin.Value := 1))
    btnSave.OnEvent("Click", (*) => SaveSettings(ddTheme.Value, ddThumb.Value, cbWin.Value, hkKey.Value, ddClose.Value, cbKeep.Value, cbFav.Value, cbHl.Value, ddRes.Value, cbPin.Value))
    btnCancel.OnEvent("Click", CloseSettings)
    sg.OnEvent("Close", CloseSettings)
    sg.OnEvent("Escape", CloseSettings)
    sg.Show()
}

; Settings closed without saving
CloseSettings(*) {
    try sg.Destroy()
    ReturnFromSettings()
}

; Back to where we were: the picker if it was open, otherwise idle in the tray
ReturnFromSettings() {
    global InSettings
    InSettings := false
    if ReopenPicker
        ShowPicker(true)
    else
        SetTimer(TrimMem, -300)
}

SaveSettings(themeIdx, thumbIdx, win, key, closeIdx, keep, fav, hl, resIdx, pin) {
    global Theme, Thumb, KeepOpen, FavOn, HlOn, CloseMode, ResMode, PinTray
    if (key = "") {
        MsgBox("Click the shortcut box and press a key first.", "Emoji Picker", 48)
        return
    }
    newKey := (win ? "#" : "") key
    if (newKey != HotkeyStr && !ApplyHotkey(newKey)) {
        MsgBox("That shortcut cannot be used. Please choose another one.", "Emoji Picker", 48)
        return
    }
    Theme := (themeIdx = 2) ? "light" : "dark"
    Thumb := Max(1, Min(3, thumbIdx))
    CloseMode := (closeIdx = 2) ? "tray" : "exit"
    KeepOpen := (keep = 1), FavOn := (fav = 1), HlOn := (hl = 1)
    ResMode := Max(1, Min(3, resIdx))
    if ((pin = 1) != PinTray) {
        PinTray := (pin = 1)
        SetTimer(PinTrayIcon.Bind(PinTray, 1), -100)
    }
    try {
        IniWrite(ResMode, SettingsFile, "Settings", "TrayMemory")
        IniWrite(PinTray ? 1 : 0, SettingsFile, "Settings", "PinTrayIcon")
        DirCreate(UserDir)
        IniWrite(Theme, SettingsFile, "Settings", "Theme")
        IniWrite(Thumb, SettingsFile, "Settings", "Size")
        IniWrite(HotkeyStr, SettingsFile, "Settings", "Hotkey")
        IniWrite(CloseMode, SettingsFile, "Settings", "CloseAction")
        IniWrite(KeepOpen ? 1 : 0, SettingsFile, "Settings", "KeepOpen")
        IniWrite(FavOn ? 1 : 0, SettingsFile, "Settings", "Favorites")
        IniWrite(HlOn ? 1 : 0, SettingsFile, "Settings", "Highlights")
    }
    try sg.Destroy()
    if IsObject(g)
        BuildGui()                     ; new theme / size
    ReturnFromSettings()
}

; =====================================================================
;  Picker logic
; =====================================================================
ShowPicker(keepPrev := false) {
    global PrevWin, Quitting
    Quitting := false
    if !keepPrev                       ; window that was in use before the picker (it gets the pasted emoji)
        PrevWin := WinExist("A")
    LoadCats()                         ; no-op unless the "Lowest" tray mode released the data
    if !Cats.Length {
        MsgBox("EmojiData.dat could not be read:`n" DataFile, "Emoji Picker", 16)
        ExitApp
    }
    if !IsObject(g)
        BuildGui()                     ; the window is built only while it is needed
    PickerKeys(true)

    if CaretGetPos(&x, &y)
        y += 24
    else
        MouseGetPos(&x, &y)

    l := 0, t := 0, r := A_ScreenWidth, b := A_ScreenHeight
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if (x >= l && x < r && y >= t && y < b)
            break
    }
    x := Max(l, Min(x, r - W - 4))
    y := Max(t, Min(y, b - H - 4))

    SearchBox.Value := ""
    t := LastTab                                  ; reopen on the tab used last time
    if (t < 1 || t > Cats.Length + 1)
        t := Recents.Length ? 1 : 2
    SetTab(t)
    g.Show(Format("x{} y{} w{} h{}", x, y, W, H))
    if !WinActive("ahk_id " g.Hwnd)               ; a freshly started app may not get focus at once
        try WinActivate("ahk_id " g.Hwnd)
    SearchBox.Focus()
    PaintCanvas()
}

SetTab(i) {
    global CurTab
    CurTab := i
    LoadResults()
    Render()
}

LoadResults() {
    global Results, Scroll
    Results := []
    Scroll := 0
    q := Trim(SearchBox.Value)
    cat := (CurTab > 1) ? Cats[CurTab - 1] : ""
    if (q != "") {
        EnsureAll()
        words := StrSplit(q, " ")
        for c in Cats {
            for it in c.items {
                ok := true
                for wd in words {
                    if (wd = "")
                        continue
                    if !(InStr(it.n, wd) || InStr(it.e, wd)) {
                        ok := false
                        break
                    }
                }
                if ok
                    Results.Push(it)
            }
        }
    } else if (CurTab = 1) {
        ; first tab = history only (most recent first)
        for e in Recents
            Results.Push(ItemFor(e))
    } else {
        items := EnsureCat(cat)
        if (FavOn && FavSet.Count) {
            ; this tab's favorites are pinned to the top of the tab
            for it in items {
                if FavSet.Has(it.e)
                    Results.Push(it)
            }
            for it in items {
                if !FavSet.Has(it.e)
                    Results.Push(it)
            }
        } else {
            Results := items
        }
    }
}

Render() {
    cols := ColsNow
    per := cols * ROWS
    start := Scroll * cols
    n := Results.Length
    if n
        RangeLbl.Text := Format("{}-{} / {}", start + 1, Min(start + per, n), n)
    else
        RangeLbl.Text := "0"
    if n
        Status.Text := ""
    else if (Trim(SearchBox.Value) != "")
        Status.Text := "No results"
    else if (CurTab = 1)
        Status.Text := "No history yet"
    PaintCanvas()
}

; Scrollbar: jump / drag so the thumb follows the mouse (y = canvas coordinate)
SetScrollFromY(y) {
    global Scroll
    totalRows := Ceil(Results.Length / ColsNow)
    maxS := totalRows - ROWS
    if (maxS <= 0)
        return
    trackH := ROWS * Cell
    thumbH := Max(Round(24 * k), trackH * ROWS // totalRows)
    span := trackH - 2 - thumbH
    if (span <= 0)
        return
    s := Round((y - (GridY - CvY) - thumbH / 2) / span * maxS)
    s := Min(maxS, Max(0, s))
    if (s != Scroll) {
        Scroll := s
        Render()
    }
}

DragScroll() {
    if !GetKeyState("LButton", "P") {
        SetTimer(DragScroll, 0)
        return
    }
    if !IsObject(Canvas)
        return
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    DllCall("ScreenToClient", "ptr", Canvas.Hwnd, "ptr", pt)
    SetScrollFromY(NumGet(pt, 4, "int"))
}

PickerUnderMouse(*) {
    if !IsObject(g)
        return false
    MouseGetPos(, , &win)
    return (win = g.Hwnd)
}

ChangeScroll(d) {
    global Scroll
    maxS := Max(0, Ceil(Results.Length / ColsNow) - ROWS)
    Scroll := Min(maxS, Max(0, Scroll + d))
    Render()
}

OnSearch(*) {
    LoadResults()
    Render()
}

TabClick(i, *) {
    global LastTab
    if (i != LastTab) {                ; only touch the disk when the tab really changed
        LastTab := i
        try {
            DirCreate(UserDir)
            IniWrite(i, SettingsFile, "Settings", "LastTab")
        }
    }
    SearchBox.Value := ""
    SetTab(i)
    SearchBox.Focus()
}

PickIndex(i) {
    idx := Scroll * ColsNow + i
    if (idx <= Results.Length)
        InsertItem(Results[idx])
}

; Writes a list (one emoji per line); a temp file + rename, so a crash can never leave a half-written file
SaveList(path, arr) {
    txt := ""
    for v in arr
        txt .= v "`n"
    try {
        DirCreate(UserDir)
        tmp := path ".tmp"
        f := FileOpen(tmp, "w", "UTF-8")
        f.Write(txt)
        f.Close()
        FileMove(tmp, path, 1)
    }
}

AddRecent(e) {
    for i, v in Recents {
        if (v == e) {
            Recents.RemoveAt(i)
            break
        }
    }
    Recents.InsertAt(1, e)
    while (Recents.Length > 50)
        Recents.Pop()
    SaveList(RecentFile, Recents)
}

SaveFavs() {
    SaveList(FavFile, Favs)
}

SaveHls() {
    SaveList(HlFile, Hls)
}

; Highlight = blue mark only; the emoji keeps its normal position in the list
ToggleHl(it) {
    e := it.e
    if HlSet.Has(e) {
        for i, v in Hls {
            if (v == e) {
                Hls.RemoveAt(i)
                break
            }
        }
        HlSet.Delete(e)
        msg := "Highlight removed"
    } else {
        Hls.Push(e)
        HlSet[e] := 1
        msg := "◆ Highlighted"
    }
    SaveHls()
    PaintCanvas()
    Status.Text := msg
}

ToggleFav(it) {
    global Scroll
    e := it.e
    if FavSet.Has(e) {
        for i, v in Favs {
            if (v == e) {
                Favs.RemoveAt(i)
                break
            }
        }
        FavSet.Delete(e)
        msg := "Removed from favorites"
    } else {
        Favs.Push(e)
        FavSet[e] := 1
        msg := "★ Added to favorites"
    }
    SaveFavs()
    keep := Scroll
    LoadResults()
    Scroll := Min(keep, Max(0, Ceil(Results.Length / ColsNow) - ROWS))
    Render()
    Status.Text := msg
}

InsertItem(it) {
    global Quitting, Inserting
    if (Inserting || !IsObject(g))     ; a second click / Enter while a paste is running is ignored
        return
    Inserting := true
    if !KeepOpen {
        Quitting := true               ; hide now, quit right after pasting
        try g.Hide()
    }
    try PasteText(it.e)
    AddRecent(it.e)
    Inserting := false
    if !KeepOpen {
        DoClose()
    } else if PickerVisible() {        ; picker stays open: take the focus back so the keys keep working
        try WinActivate("ahk_id " g.Hwnd)
        try SearchBox.Focus()
    }
}

; Pastes text into the window that was in use before the picker; the clipboard is restored afterwards
PasteText(txt) {
    if (PrevWin && WinExist("ahk_id " PrevWin)) {
        try {
            WinActivate("ahk_id " PrevWin)
            WinWaitActive("ahk_id " PrevWin, , 1)
        }
    }
    saved := ""
    try saved := ClipboardAll()
    try {                              ; the clipboard can be locked by another program: never let that crash the app
        A_Clipboard := txt
        if ClipWait(1) {
            Send("^v")
            Sleep(200)
        }
    }
    if IsObject(saved)
        try A_Clipboard := saved
}

OnActivate(wParam, lParam, msg, hwnd) {
    if (IsObject(g) && hwnd = g.Hwnd && (wParam & 0xFFFF) = 0 && !KeepOpen && !InSettings && !Quitting)
        ClosePicker()
}

CanvasHover(x, y) {
    global HoverCell, HoverTab, MouseTracked
    if !MouseTracked {                 ; ask Windows for WM_MOUSELEAVE, so the highlight goes away with the mouse
        MouseTracked := true
        tme := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("uint", tme.Size, "uint", 2, "ptr", Canvas.Hwnd, tme)     ; TRACKMOUSEEVENT, TME_LEAVE
        DllCall("user32\TrackMouseEvent", "ptr", tme)
    }
    h := HitTest(x, y)
    cell := 0, tab := 0
    if IsObject(h) {
        if (h.kind = "t")
            tab := h.i
        else
            cell := h.i
    }
    if (cell = HoverCell && tab = HoverTab)
        return
    HoverCell := cell, HoverTab := tab
    if tab {
        Status.Text := LabelNames[tab]
    } else if cell {
        idx := Scroll * ColsNow + cell
        if (idx <= Results.Length) {
            nm := ItemName(Results[idx])
            if (HlOn && HlSet.Has(Results[idx].e))
                nm := "◆ " nm
            if (FavOn && FavSet.Has(Results[idx].e))
                nm := "★ " nm
            Status.Text := nm
        } else {
            HoverCell := 0
        }
    }
    PaintCanvas()
}

OnMouseLeave(wParam, lParam, msg, hwnd) {
    global HoverCell, HoverTab, MouseTracked
    if (!IsObject(g) || !IsObject(Canvas) || hwnd != Canvas.Hwnd)
        return
    MouseTracked := false
    if (HoverCell || HoverTab) {
        HoverCell := 0, HoverTab := 0
        PaintCanvas()
    }
}

OnMouseMove(wParam, lParam, msg, hwnd) {
    global HoverCell, HoverTab
    static last := 0
    if !IsObject(g)
        return
    if (IsObject(Canvas) && hwnd = Canvas.Hwnd) {
        last := hwnd
        CanvasHover(lParam & 0xFFFF, (lParam >> 16) & 0xFFFF)
        return
    }
    if (hwnd = last)
        return
    last := hwnd
    if (HoverCell || HoverTab) {
        HoverCell := 0, HoverTab := 0
        PaintCanvas()
    }
    if (hwnd = SettingsBtn.Hwnd)
        Status.Text := "Settings"
    else if (hwnd = CloseBtn.Hwnd)
        Status.Text := "Close"
}

OnLButtonDown(wParam, lParam, msg, hwnd) {
    if !IsObject(g)
        return
    if (hwnd = g.Hwnd) {
        PostMessage(0xA1, 2, 0, , "ahk_id " g.Hwnd)   ; WM_NCLBUTTONDOWN, HTCAPTION (drag)
        return
    }
    if (IsObject(Canvas) && hwnd = Canvas.Hwnd) {
        cx := lParam & 0xFFFF, cy := (lParam >> 16) & 0xFFFF
        gy0 := GridY - CvY
        if (cx >= GX + COLS * Cell && cy >= gy0 && cy < gy0 + ROWS * Cell) {
            SetScrollFromY(cy)
            SetTimer(DragScroll, 15)
            return
        }
        h := HitTest(cx, cy)
        if !IsObject(h)
            return
        if (h.kind = "t")
            TabClick(h.i)
        else
            SetTimer(PickIndex.Bind(h.i), -1)
    }
}

; Right-click an emoji twice (within the system double-click time) = add / remove favorite
OnRButtonDown(wParam, lParam, msg, hwnd) {
    static lastE := "", lastT := 0
    if (!FavOn || !IsObject(g) || !IsObject(Canvas) || hwnd != Canvas.Hwnd)
        return
    h := HitTest(lParam & 0xFFFF, (lParam >> 16) & 0xFFFF)
    idx := (IsObject(h) && h.kind = "c") ? Scroll * ColsNow + h.i : 0
    if (idx < 1 || idx > Results.Length) {
        lastE := ""
        return
    }
    e := Results[idx].e
    if (e == lastE && A_TickCount - lastT <= Max(DllCall("GetDoubleClickTime"), 400)) {
        lastE := ""
        ToggleFav(Results[idx])
    } else {
        lastE := e
        lastT := A_TickCount
    }
}

; Middle-click an emoji = add / remove highlight
OnMButtonDown(wParam, lParam, msg, hwnd) {
    if (!HlOn || !IsObject(g) || !IsObject(Canvas) || hwnd != Canvas.Hwnd)
        return
    h := HitTest(lParam & 0xFFFF, (lParam >> 16) & 0xFFFF)
    if (IsObject(h) && h.kind = "c") {
        idx := Scroll * ColsNow + h.i
        if (idx <= Results.Length)
            ToggleHl(Results[idx])
    }
}

