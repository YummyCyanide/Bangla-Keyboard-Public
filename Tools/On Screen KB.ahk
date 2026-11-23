#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
DetectHiddenWindows True
ListLines(0)
SetTimer(TrimMemory, -3000)         ; once, shortly after start: hand unused memory back to Windows
KeyHistory(0)
SetWinDelay(-1)
; ============================================================
;  On-Screen Bangla Keyboard  (AutoHotkey v2)  -  v7
;  Tabs: Bangla | English (US-International).  Settings and About
;  open in their own windows (they are not tabs any more).
;  - The keyboard is drawn directly onto one surface (GDI), so
;    there are no per-key controls and no leftover/ghost text.
;  - Hover and click effects on every key.
;  - Minimize sends it to the taskbar; Close exits the program.
;  - Resizable: keys and fonts scale with the window.
;  - Settings: window position, light/dark mode, button theme,
;    key font and font zoom.
;  Save this file as UTF-8 (with BOM is safest).
; ============================================================

; per-monitor DPI awareness: the keyboard follows Windows scaling changes and monitors with a different scale
try DllCall("user32\SetProcessDpiAwarenessContext", "Ptr", -4, "Ptr")
try DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
SysDpi() {
    try return DllCall("user32\GetDpiForSystem", "UInt")
    return A_ScreenDPI
}
global S := SysDpi() / 96
global gapBase := 6, keyScale := 1.0          ; key spacing (px at 100%) and key size scale (0.7 - 1.6)
global M := Round(12 * S), GAP := Round(gapBase * S)
global rememberTab := true, lastTab := 1

global tabNames := ["বাংলা (Bangla)", "English (ইংরেজী)", "Settings", "About"]
global tabIdx := 1
global shiftOn := false, capsOn := false, ctrlOn := false, altOn := false, altgrOn := false
global deadAcc := ""

global items := []
global curRows := 8, curUnits := 12
global gKeyH := 36, gPitch := 68
global hovIdx := 0, pressIdx := 0, tracking := false

global posMode := "top"       ; "top" | "normal"
global darkMode := false
global themeName := "Default"
global fontScale := 1.0       ; key font zoom (0.6 - 2.0)
global fontName := "Nirmala UI"
global fontCache := Map()
global G := "", fontDDL := "", themeDDL := "", zoomLbl := "", szLbl := "", gapLbl := ""
global gMain := ""                                      ; the keyboard window itself (G is whichever window is being drawn)
global cur := "", ctxMain := "", ctxSet := "", ctxAbout := "", ctxList := [], ctxByHwnd := Map()
global pressCtx := ""
global soundOn := false, hiliteOn := true   ; click sound / press highlight
global soundDir := A_ScriptDir "\On Screen KB Data"      ; put the click sounds in this folder (next to the script)
global soundFiles := [], soundScanned := false, lastSound := 0
global conjOn := false, conjPage := 1                         ; conjunct panel on the Bangla tab
global fontsLoaded := false           ; the installed-font list is only read when Settings is first opened
global rcFill := Buffer(16), rcInv := Buffer(16)   ; reusable RECT buffers
global winX := "", winY := ""           ; remembered window position ("" = let Windows choose)
global settingsDir := A_AppData "\Bangla Keyboard"
global settingsFile := settingsDir "\On Screen Keyboard.dat"

; theme -> [key colour, hover, pressed,  active-tab colour, hover, pressed]
Th(a, b, c) => [a, b, c, a, b, c]
global themes := Map(
    "Default", ["0F9488", "14B8A6", "0A6B62", "2F80ED", "4C93F2", "1F63C4"],
    "Dark Red",    Th("A61B1B", "C42B2B", "7F1212"),
    "Dark Blue",   Th("1F4E9E", "2C63BD", "163A75"),
    "Dark Teal",   Th("0A6B62", "0E8277", "07514A"),
    "Dark Green",  Th("1E7B34", "269A44", "14582A"),
    "Dark Purple", Th("5B2A86", "7137A3", "431E63"),
    "Dark Orange", Th("B45309", "D06A12", "7C3A06"),
    "Dark Pink",   Th("A3195B", "C2246E", "7A1244"),
    "Dark Gray",   Th("374151", "4B5667", "1F2937"),
    "High Contrast", Th("FFD600", "FFFFFF", "00E5FF"))

DefSize(n, keyH := 36, ks := keyScale) => [Round(838 * S * ks), 2 * M + (n + 1) * Round(keyH * S * ks) + n * GAP]
DefKeyH() => Round(36 * S * keyScale)                                       ; height of the top row (never changes with the window size)
DefPitch() => (Round(838 * S * keyScale) - 2 * M + GAP) / 12                ; one key unit of the default-size window
DefSizes() => Map(1, DefSize(8), 2, DefSize(5), 3, DefSize(11, 36, 1), 4, DefSize(7, 36, 1))   ; 3 = Settings window, 4 = About window
global sizes := DefSizes()

; ---------- Remember settings (AppData\Bangla Keyboard\On Screen Keyboard.dat) ----------
LoadSettings() {
    global posMode, darkMode, themeName, fontScale, fontName, winX, winY, sizes, soundOn, hiliteOn, gapBase, keyScale, rememberTab, lastTab, GAP
    if !FileExist(settingsFile)
        return
    try txt := FileRead(settingsFile, "UTF-8")
    catch
        return
    cfg := Map()
    for line in StrSplit(txt, "`n", "`r") {
        p := InStr(line, "=")
        if (p > 1)
            cfg[Trim(SubStr(line, 1, p - 1))] := Trim(SubStr(line, p + 1))
    }
    if (cfg.Has("posMode") && (cfg["posMode"] = "top" || cfg["posMode"] = "normal"))
        posMode := cfg["posMode"]
    if (cfg.Has("darkMode") && IsInteger(cfg["darkMode"]))
        darkMode := cfg["darkMode"] ? true : false
    if (cfg.Has("clickSound") && IsInteger(cfg["clickSound"]))
        soundOn := cfg["clickSound"] ? true : false
    if (cfg.Has("keyHighlight") && IsInteger(cfg["keyHighlight"]))
        hiliteOn := cfg["keyHighlight"] ? true : false
    if (cfg.Has("gap") && IsInteger(cfg["gap"]))
        gapBase := Max(0, Min(16, Integer(cfg["gap"])))
    if (cfg.Has("keyScale") && IsNumber(cfg["keyScale"]))
        keyScale := Round(Max(0.7, Min(1.6, cfg["keyScale"] + 0)), 1)
    if (cfg.Has("rememberTab") && IsInteger(cfg["rememberTab"]))
        rememberTab := cfg["rememberTab"] ? true : false
    if (cfg.Has("lastTab") && RegExMatch(cfg["lastTab"], "^[1-2]$"))
        lastTab := Integer(cfg["lastTab"])
    if (cfg.Has("theme") && themes.Has(cfg["theme"]))
        themeName := cfg["theme"]
    if (cfg.Has("fontScale") && IsNumber(cfg["fontScale"]))
        fontScale := Round(Max(0.6, Min(2.0, cfg["fontScale"] + 0)), 1)
    if (cfg.Has("fontName") && cfg["fontName"] != "")
        fontName := cfg["fontName"]
    GAP := Round(gapBase * S)
    sizes := DefSizes()
    ratio := 1.0                          ; window sizes were saved at another Windows scale
    if (cfg.Has("dpi") && IsInteger(cfg["dpi"]) && cfg["dpi"] >= 48 && cfg["dpi"] != Round(S * 96))
        ratio := S * 96 / cfg["dpi"]
    Loop 4 {
        k := "size" A_Index
        if (cfg.Has(k) && RegExMatch(cfg[k], "^(\d+),(\d+)$", &m) && m[1] >= 200 && m[2] >= 150)
            sizes[A_Index] := [Round(Integer(m[1]) * ratio), Round(Integer(m[2]) * ratio)]
    }
    if (cfg.Has("winX") && cfg.Has("winY") && IsInteger(cfg["winX"]) && IsInteger(cfg["winY"])) {
        x := Integer(cfg["winX"]), y := Integer(cfg["winY"])
        ; only reuse the position if the title bar would still be on a monitor
        if (x + 100 > SysGet(76) && x < SysGet(76) + SysGet(78) - 100
            && y >= SysGet(77) - 10 && y < SysGet(77) + SysGet(79) - 40) {
            winX := x
            winY := y
        }
    }
}

SaveSettings(*) {
    global winX, winY
    try {
        if (IsObject(gMain) && gMain.Hwnd && WinGetMinMax("ahk_id " gMain.Hwnd) = 0) {
            WinGetPos(&x, &y, , , "ahk_id " gMain.Hwnd)
            if (x > -30000 && y > -30000)
                winX := x, winY := y
        }
    }
    out := "posMode=" posMode "`n"
        . "darkMode=" (darkMode ? 1 : 0) "`n"
        . "theme=" themeName "`n"
        . "gap=" gapBase "`n"
        . "keyScale=" keyScale "`n"
        . "rememberTab=" (rememberTab ? 1 : 0) "`n"
        . "lastTab=" tabIdx "`n"
        . "dpi=" Round(S * 96) "`n"
        . "clickSound=" (soundOn ? 1 : 0) "`n"
        . "keyHighlight=" (hiliteOn ? 1 : 0) "`n"
        . "fontScale=" fontScale "`n"
        . "fontName=" fontName "`n"
    Loop 4
        out .= "size" A_Index "=" sizes[A_Index][1] "," sizes[A_Index][2] "`n"
    if (winX != "" && winY != "")
        out .= "winX=" winX "`n" "winY=" winY "`n"
    try {
        DirCreate(settingsDir)
        f := FileOpen(settingsFile, "w", "UTF-8")
        f.Write(out)
        f.Close()
    }
}

; kind -> [font-size adjustment (px), weight]
global styles := Map(
    "key",         [0, 400],
    "special",     [-2, 700],
    "ctl",         [-2, 700],
    "tabOn",       [-2, 700],
    "tabOff",      [-2, 700],
    "settingsOff", [-1, 700],
    "label",       [0, 700],
    "body",        [-2, 400])

IsHC() => themeName = "High Contrast"      ; accessibility theme: black, white and yellow
UiDark() => darkMode || IsHC()
BgCol() => IsHC() ? "000000" : darkMode ? "1E1E1E" : "F3F3F3"
BorderCol() => IsHC() ? "FFFFFF" : darkMode ? "5A5A5A" : "6E6E6E"

; returns [normal, hover, pressed] colours for buttons, or "" for plain text kinds
Pal(kind) {
    static cache := Map()
    key := kind "|" themeName "|" darkMode
    if cache.Has(key)
        return cache[key]
    return cache[key] := PalMake(kind)
}

PalMake(kind) {
    t := themes[themeName]
    switch kind {
        case "special", "ctl": return [t[1], t[2], t[3]]
        case "tabOn":          return [t[4], t[5], t[6]]
        case "key", "tabOff", "settingsOff":
            if IsHC()
                return ["000000", "0033CC", "990000"]
            return darkMode ? ["2B2B2B", "3E3E3E", "575757"] : ["FFFFFF", "DCEBFF", "B4D2FA"]
    }
    return ""
}

TextCol(kind) {
    hc := IsHC()
    switch kind {
        case "special", "ctl", "tabOn": return hc ? "000000" : "FFFFFF"
        case "key", "tabOff":           return hc ? "FFFFFF" : darkMode ? "F2F2F2" : "000000"
        case "settingsOff":             return hc ? "FFFF00" : "E8761A"
        case "label":                   return hc ? "FFFFFF" : darkMode ? "EDEDED" : "333333"
    }
    return hc ? "FFFFFF" : darkMode ? "D0D0D0" : "444444"
}

; ---------- Key helpers ----------
; l=label, o=output, w/h=size in cells, t=type, s=shifted, a=AltChar, a2=AltChar+Shift
K(l, o := "", w := 1, h := 1, t := "n", s := "", a := "", a2 := "") {
    return {l: l, o: (o = "" ? l : o), w: w, h: h, t: t, s: s, a: a, a2: a2}
}
Sp(l, t, w := 1, h := 1) => K(l, "", w, h, t)
D(c) => K(Chr(0x25CC) c, c)          ; dotted-circle label for signs

Row(items*) {
    r := []
    for it in items {
        if (it is String) {
            for ch in StrSplit(it)
                r.Push(K(ch))
        } else
            r.Push(it)
    }
    return r
}

Join(parts*) {
    r := []
    for p in parts {
        if (p is Array) {
            for x in p
                r.Push(x)
        } else
            r.Push(p)
    }
    return r
}

; ---------- Bangla layout ----------
BanglaLayout() {
    static L := ""
    if IsObject(L)
        return L
    zwj := Chr(0x200D), zwnj := Chr(0x200C)
    r3 := [D("্")]
    for ch in StrSplit("ািীুূৃেৈোৌ")
        r3.Push(D(ch))
    r3.Push(K("ZWNJ", zwnj))
    return L := [
        Row("০১২৩৪৫৬৭৮৯", Sp("Backspace", "bs", 2)),
        Row("অআইঈউঊঋএঐওঔ", K("ZWJ", zwj)),
        r3,
        Row("কখগঘঙচছজঝঞ", K("ৎ"), D("ং")),
        Row("টঠডঢণতথদধন", D("ঃ"), D("ঁ")),
        Row("পফবভমযরলশষ", K("য-ফলা", "্য"), K("র-ফলা", "্র")),
        Row("সহ", K(Chr(0x09DC)), K(Chr(0x09DD)), K(Chr(0x09DF)), ",", ".", "?", "!", "।",
            K("র" zwj "্য"), K("রেফ (র্)", "র্")),
        [Sp("যুক্তাক্ষর", "conj", 2), Sp("Space (স্পেস)", "space", 8), Sp("Enter", "enter", 2)]
    ]
}

; ---------- Common conjuncts (juktakkhor), 2 pages of 82 keys ----------
; each entry is written as its letters; they are joined with hasanta (্) when the keys are built
ConjLayout(page) {
    static cache := Map(), all := ""
    if cache.Has(page)
        return cache[page]
    if !IsObject(all) {
        all := []
        hasanta := Chr(0x09CD)
        src := "কক কট কত কন কব কম কর কল কষ কষম কস খর গধ গন গম গর গল ঘন ঘর ঙক ঙখ ঙগ ঙঘ চচ চছ চঞ "
            . "জজ জঝ জঞ জব ঞচ ঞছ ঞজ ঞঝ টট টর ডড ডর ণট ণঠ ণড ণণ ণম তত তথ তন তব তম তর ততব "
            . "দঘ দদ দধ দব দভ দম দর ধন ধব ধম ধর নট নঠ নড নত নথ নদ নধ নন নব নম নস নতর "
            . "পট পত পন পপ পর পল পস ফর ফল বজ বদ বধ বব বভ বর বল ভর মন মপ মব মভ মম মর মল "
            . "যয লক লগ লট লড লপ লফ লব লম লল শচ শছ শন শব শম শর শল ষক ষট ষঠ ষণ ষপ ষফ ষব ষম "
            . "সক সখ সট সত সথ সন সপ সফ সব সম সল সতর হন হম হল হব হর"
        for tok in StrSplit(src, " ") {
            j := ""
            for ch in StrSplit(tok)
                j .= (A_Index > 1 ? hasanta : "") ch
            all.Push(K(j))
        }
    }
    pos := (page - 1) * 82
    r := []
    Loop 7 {
        rn := A_Index
        row := []
        Loop (rn = 1 ? 10 : 12) {
            pos++
            if (pos <= all.Length)
                row.Push(all[pos])
        }
        if (rn = 1)
            row.Push(Sp("Backspace", "bs", 2))
        r.Push(row)
    }
    r.Push([Sp("◀ বর্ণ", "conj", 2), Sp(page = 1 ? "পরের ▶" : "◀ আগের", "conjpg", 2)
        , Sp("Space (স্পেস)", "space", 6), Sp("Enter", "enter", 2)])
    return cache[page] := r
}

; ---------- English layout (US-International, 15-unit rows) ----------
KeysOf(n, s, a, a2) {
    r := []
    Loop StrLen(n)
        r.Push(K(SubStr(n, A_Index, 1), "", 1, 1, "n", SubStr(s, A_Index, 1), a[A_Index], a2[A_Index]))
    return r
}

EnglishLayout() {
    static L := ""
    if IsObject(L)
        return L
    r1 := KeysOf("``1234567890-=", "~!@#$%^&*()_+",
        ["", "¡", "²", "³", "¤", "€", "¼", "½", "¾", "‘", "’", "¥", "×"],
        ["", "¹", "", "", "£", "", "", "", "", "", "", "", "÷"])
    r2 := KeysOf("qwertyuiop[]", "QWERTYUIOP{}",
        ["ä", "å", "é", "®", "þ", "ü", "ú", "í", "ó", "ö", "«", "»"],
        ["Ä", "Å", "É", "", "Þ", "Ü", "Ú", "Í", "Ó", "Ö", "", ""])
    bs := K("\", "", 1.5, 1, "n", "|", "¬", "¦")
    r3 := KeysOf("asdfghjkl;'", "ASDFGHJKL:`"",
        ["á", "ß", "ð", "", "", "", "", "", "ø", "¶", "´"],
        ["Á", "§", "Ð", "", "", "", "", "", "Ø", "°", "¨"])
    r4 := KeysOf("zxcvbnm,./", "ZXCVBNM<>?",
        ["æ", "", "©", "", "", "ñ", "µ", "ç", "", "¿"],
        ["Æ", "", "¢", "", "", "Ñ", "", "Ç", "", ""])
    return L := [
        Join(r1, Sp("Backspace", "bs", 2)),
        Join(Sp("Tab", "tab", 1.5), r2, bs),
        Join(Sp("Caps Lock", "caps", 1.75), r3, Sp("Enter", "enter", 2.25)),
        Join(Sp("Shift", "shift", 2.25), r4, Sp("Shift", "shift", 2.75)),
        [Sp("Ctrl", "ctrl", 1.75), Sp("Alt", "alt", 1.75), Sp("Space", "space", 7.5), Sp("AltChar", "altgr", 2), Sp("Ctrl", "ctrl", 2)]
    ]
}

; ---------- Dead-key composition (US-International) ----------
BuildCompose() {
    m := Map()
    tbl := Map("``", "aàeèiìoòuùAÀEÈIÌOÒUÙ",
               "'",  "aáeéiíoóuúyýAÁEÉIÍOÓUÚYÝ",
               "~",  "aãnñoõAÃNÑOÕ",
               "^",  "aâeêiîoôuûAÂEÊIÎOÔUÛ",
               "`"", "aäeëiïoöuüyÿAÄEËIÏOÖUÜ")
    for acc, s in tbl {
        Loop StrLen(s) // 2
            m[acc SubStr(s, A_Index * 2 - 1, 1)] := SubStr(s, A_Index * 2, 1)
    }
    return m
}
global compose := BuildCompose()
global deadSet := "``~'^`""

Resolve(k) {
    if (altgrOn && tabIdx = 2) {
        ch := shiftOn ? k.a2 : k.a
        if (ch != "")
            return ch
    }
    sh := shiftOn
    if (capsOn && StrLen(k.o) = 1 && RegExMatch(k.o, "^[a-z]$"))
        sh := !sh
    return (sh && k.s != "") ? k.s : k.o
}

Lbl(k) {
    switch k.t {
        case "shift": return shiftOn ? "SHIFT ●" : "Shift"
        case "caps":  return capsOn ? "CAPS ●" : "Caps Lock"
        case "ctrl":  return ctrlOn ? "CTRL ●" : "Ctrl"
        case "alt":   return altOn ? "ALT ●" : "Alt"
        case "altgr": return altgrOn ? "AltChar ●" : "AltChar"
        case "n":     return (tabIdx = 2) ? Resolve(k) : k.l
    }
    return k.l
}

IsActive(it) {
    if !IsObject(it.k)
        return false
    switch it.k.t {
        case "shift": return shiftOn
        case "caps":  return capsOn
        case "ctrl":  return ctrlOn
        case "alt":   return altOn
        case "altgr": return altgrOn
    }
    return false
}

; ---------- Windows: keyboard, Settings, About ----------
; Every window has its own drawn items and mouse state. The drawing code works on the "current" window
; (the globals G, items, curRows, ...). UseCtx() switches the current window, RunIn() runs a function inside one.
NewCtx(id, key, gui) {
    c := {id: id, key: key, gui: gui, items: [], rows: 8, units: 12, keyH: 36, pitch: 68
        , hov: 0, press: 0, tracking: false, placed: false}
    ctxList.Push(c)
    ctxByHwnd[gui.Hwnd] := c
    return c
}

CtxOf(hwnd) => ctxByHwnd.Has(hwnd) ? ctxByHwnd[hwnd] : ""

UseCtx(c) {
    global cur, G, items, curRows, curUnits, gKeyH, gPitch, hovIdx, pressIdx, tracking
    prev := cur
    if (!IsObject(c) || (IsObject(prev) && c.id = prev.id))
        return prev
    if IsObject(prev) {                     ; remember the state of the window we are leaving
        prev.items := items, prev.rows := curRows, prev.units := curUnits
        prev.keyH := gKeyH, prev.pitch := gPitch
        prev.hov := hovIdx, prev.press := pressIdx, prev.tracking := tracking
    }
    cur := c
    G := c.gui, items := c.items, curRows := c.rows, curUnits := c.units
    gKeyH := c.keyH, gPitch := c.pitch
    hovIdx := c.hov, pressIdx := c.press, tracking := c.tracking
    return prev
}

RunIn(c, fn, args*) {
    prev := UseCtx(c)
    try
        return fn(args*)
    finally
        UseCtx(prev)
}

CtxFn(c, fn) => (*) => RunIn(c, fn)

ForEachCtx(fn) {
    for c in ctxList.Clone()
        RunIn(c, fn)
}

IsVis(c) => IsObject(c) && DllCall("IsWindowVisible", "Ptr", c.gui.Hwnd)
SizeKey() => (cur.id = "main") ? tabIdx : cur.key

; ---------- Items (everything drawn on the surface) ----------
AddItem(kind, text, col, row, w, h, fn := "", k := "") {
    if IsObject(fn)
        fn := CtxFn(cur, fn)                 ; the click always runs inside the window it belongs to
    it := {kind: kind, text: text, col: col, row: row, w: w, h: h, fn: fn, k: k
         , act: IsObject(fn), x: 0, y: 0, ww: 0, hh: 0, isCtl: false, c: "", fix: ""
         , rep: IsObject(k) && InStr("|n|bs|del|space|tab|enter|", "|" k.t "|") > 0}   ; keys that repeat while held
    items.Push(it)
    return it
}

AddCtl(kind, ctl, col, row, w, h) {
    it := {kind: kind, text: "", col: col, row: row, w: w, h: h, fn: "", k: ""
         , act: false, x: 0, y: 0, ww: 0, hh: 0, isCtl: true, c: ctl, rep: false, fix: ""}
    items.Push(it)
    return it
}

ZoomText() => Round(fontScale * 100) "%"

BuildItems() {
    global items
    items := []
    if (cur.id = "main")
        BuildMain()
    else if (cur.id = "settings")
        BuildSettings()
    else
        BuildAbout()
}

BuildMain() {
    global curRows, curUnits
    layout := (tabIdx = 1) ? (conjOn ? ConjLayout(conjPage) : BanglaLayout()) : EnglishLayout()
    curUnits := (tabIdx = 1) ? 12 : 15
    curRows := layout.Length

    ; top row: fixed height, always spans the full width (see DoLayout). Tabs are 2.5 units wide, Delete is 2.
    ; Settings and About open their own windows.
    tw := 2.5
    for i, name in tabNames {
        kind := (i = tabIdx) ? "tabOn" : (i = 3 ? "settingsOff" : "tabOff")
        it := AddItem(kind, name, (i - 1) * tw, 0, tw, 1, MakeTab(i))
        it.fix := "L"
    }

    dk := Sp("Delete", "del")
    it := AddItem("special", "", 10, 0, 2, 1, MakeKey(dk), dk)
    it.fix := "R"
    for r, row in layout {
        col := 0
        for k in row {
            AddItem(k.t = "n" ? "key" : "special", "", col, r, k.w, k.h, MakeKey(k), k)
            col += k.w
        }
    }
}

BuildSettings() {
    global curRows, curUnits, zoomLbl, szLbl, gapLbl
    curUnits := 12
    curRows := 11
    AddItem("label", "Window position", 0, 0, 6, 1)
    AddItem("label", "Window mode", 6, 0, 6, 1)
    AddItem(posMode = "top" ? "tabOn" : "tabOff", "Always on top", 0, 1, 3, 1, MakePos("top"))
    AddItem(posMode = "normal" ? "tabOn" : "tabOff", "Normal", 3, 1, 3, 1, MakePos("normal"))
    AddItem(!darkMode ? "tabOn" : "tabOff", "Light", 6, 1, 3, 1, MakeMode(false))
    AddItem(darkMode ? "tabOn" : "tabOff", "Dark", 9, 1, 3, 1, MakeMode(true))
    AddItem("label", "Button theme (colour of the coloured keys)", 0, 2, 12, 1)
    AddCtl("ddl", themeDDL, 0, 3, 6, 1)
    AddItem("ctl", "Reset All", 6, 3, 3, 1, (*) => SetTimer(ResetAll, -10))
    AddItem("label", "Key font and size", 0, 4, 12, 1)
    AddCtl("ddl", fontDDL, 0, 5, 6, 1)
    AddItem("ctl", "A-", 6, 5, 2, 1, MakeZoom(-0.1))
    zoomLbl := AddItem("tabOff", ZoomText(), 8, 5, 2, 1)
    AddItem("ctl", "A+", 10, 5, 2, 1, MakeZoom(0.1))
    AddItem("label", "Key size and spacing", 0, 6, 12, 1)
    AddItem("ctl", "Size -", 0, 7, 2, 1, MakeSize(-0.1))
    szLbl := AddItem("tabOff", Round(keyScale * 100) "%", 2, 7, 2, 1)
    AddItem("ctl", "Size +", 4, 7, 2, 1, MakeSize(0.1))
    AddItem("ctl", "Spacing -", 6, 7, 2, 1, MakeGap(-1))
    gapLbl := AddItem("tabOff", String(gapBase), 8, 7, 2, 1)
    AddItem("ctl", "Spacing +", 10, 7, 2, 1, MakeGap(1))
    AddItem("label", "Feedback and start-up", 0, 8, 12, 1)
    AddItem(soundOn ? "tabOn" : "tabOff", "Click sound: " (soundOn ? "On" : "Off"), 0, 9, 4, 1, MakeOpt("sound"))
    AddItem(hiliteOn ? "tabOn" : "tabOff", "Key highlight: " (hiliteOn ? "On" : "Off"), 4, 9, 4, 1, MakeOpt("hilite"))
    AddItem(rememberTab ? "tabOn" : "tabOff", "Remember last tab: " (rememberTab ? "On" : "Off"), 8, 9, 4, 1, MakeOpt("tab"))
    AddItem("label", "Preview", 0, 10, 12, 1)
    Loop 12
        AddItem("key", SubStr("কখগঘঙঅআই১২Aa", A_Index, 1), A_Index - 1, 11, 1, 1)
}

BuildAbout() {
    global curRows, curUnits
    curUnits := 12
    curRows := 7
    AddItem("label", "On-Screen Bangla Keyboard", 0, 0, 12, 1)
    AddItem("body", "Version 1.2.6   •   Built by Sherlock Holmes", 0, 1, 12, 1)
    AddItem("body", "Click the keys to type Bangla or English into whichever window you were using. "
        . "The keyboard never takes focus, so your cursor stays exactly where it was.", 0, 2, 12, 3)
    AddItem("body", "Tips: Minimizing sends the keyboard to the taskbar - click its taskbar button to bring it back. "
        . "Drag the window edges to resize it. Hold a key to repeat it. Settings lets you change the window position, light/dark mode, button theme "
        . "(including a high-contrast one), key font, key size and spacing, click sound, key highlight and whether the last tab is remembered.", 0, 5, 12, 3)
}

; Bangla / English switch the keyboard tab; Settings and About open their own window
MakeTab(i) => (*) => SetTimer(() => OpenTab(i), -10)
OpenTab(i) {
    if (i = 3)
        OpenAux("settings")
    else if (i = 4)
        OpenAux("about")
    else
        SwitchTab(i)
}
MakeKey(k) => (*) => KeyPress(k)
MakePos(m) => (*) => SetPos(m)
MakeMode(d) => (*) => SetMode(d)
MakeZoom(d) => (*) => ZoomBy(d)
MakeOpt(n) => (*) => ToggleOpt(n)
MakeSize(d) => (*) => SizeBy(d)
MakeGap(d) => (*) => GapBy(d)

; ---------- Layout ----------
DoLayout(w, h) {
    global gKeyH, gPitch
    if (w < 100 || h < 100)
        return
    n := curRows
    isMain := (cur.id = "main")
    topH := DefKeyH()
    if isMain       ; the top row keeps its default height; the other rows share what is left
        gKeyH := Max(14, (h - 2 * M - topH - n * GAP) / n)
    else
        gKeyH := Max(14, (h - 2 * M - n * GAP) / (n + 1))
    gPitch := (w - 2 * M + GAP) / curUnits
    ; the top row always spans the full width (12 units: 4 tabs of 2.5 + Delete of 2), only its height is fixed
    tp := (w - 2 * M + GAP) / 12
    for it in items {
        if (isMain && it.row = 0) {
            it.x := Round(M + it.col * tp)
            it.ww := (it.fix = "R") ? w - M - it.x : Round(it.w * tp - GAP)     ; Delete ends exactly at the right margin
            it.hh := topH
            it.y := M
        } else {
            it.x := Round(M + it.col * gPitch)
            it.y := isMain ? Round(M + topH + GAP + (it.row - 1) * (gKeyH + GAP)) : Round(M + it.row * (gKeyH + GAP))
            it.ww := Round(it.w * gPitch - GAP)
            it.hh := Round(it.h * gKeyH + (it.h - 1) * GAP)
        }
        if it.isCtl {
            it.c.GetPos(, , , &chh)
            it.c.Move(it.x, it.y + Max(0, (it.hh - chh) // 2), it.ww)
        }
    }
}

Relayout() {
    G.GetClientPos(, , &w, &h)
    DoLayout(w, h)
    Invalidate()
}

OnSize(c, g, minMax, w, h) {
    if (minMax = -1) {           ; minimized to the taskbar: nothing to lay out, give memory back
        DllCall("psapi\EmptyWorkingSet", "Ptr", DllCall("GetCurrentProcess", "Ptr"))
        return
    }
    RunIn(c, SizeBody, w, h)
}

SizeBody(w, h) {
    sizes[SizeKey()] := [w, h]
    DoLayout(w, h)
    Invalidate()
}

Invalidate() {
    if IsObject(G)
        DllCall("InvalidateRect", "Ptr", G.Hwnd, "Ptr", 0, "Int", 0)
}

InvalidateAll() {
    for c in ctxList
        DllCall("InvalidateRect", "Ptr", c.gui.Hwnd, "Ptr", 0, "Int", 0)
}

; repaint just one key instead of the whole window (hover / press effects)
InvalidateItem(i) {
    if (i < 1 || i > items.Length)
        return
    it := items[i]
    NumPut("Int", it.x, "Int", it.y, "Int", it.x + it.ww, "Int", it.y + it.hh, rcInv)
    DllCall("InvalidateRect", "Ptr", G.Hwnd, "Ptr", rcInv, "Int", 0)
}

; ---------- Drawing (GDI, double-buffered) ----------
RGB(hex) {
    static cache := Map()
    if cache.Has(hex)
        return cache[hex]
    return cache[hex] := Integer("0x" SubStr(hex, 1, 2)) | (Integer("0x" SubStr(hex, 3, 2)) << 8) | (Integer("0x" SubStr(hex, 5, 2)) << 16)
}

; one GDI brush per colour, created once and reused
Brush(hex) {
    static cache := Map()
    if !cache.Has(hex)
        cache[hex] := DllCall("CreateSolidBrush", "UInt", RGB(hex), "Ptr")
    return cache[hex]
}

FillRectC(dc, x, y, w, h, hex) {
    NumPut("Int", x, "Int", y, "Int", x + w, "Int", y + h, rcFill)
    DllCall("FillRect", "Ptr", dc, "Ptr", rcFill, "Ptr", Brush(hex))
}

GetFont(px, wt) {
    key := fontName "|" px "|" wt
    if !fontCache.Has(key)
        fontCache[key] := DllCall("CreateFontW", "Int", -px, "Int", 0, "Int", 0, "Int", 0, "Int", wt
            , "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 5, "UInt", 0
            , "WStr", fontName, "Ptr")
    return fontCache[key]
}

ClearFonts() {
    for key, hf in fontCache
        DllCall("DeleteObject", "Ptr", hf)
    fontCache.Clear()
}

FontPx() => Max(12, Min(34, Round(Min(gKeyH * 0.46, gPitch * 0.38))))

DrawItem(dc, i, it) {
    if it.isCtl
        return
    kind := it.kind
    st := styles[kind]
    base := (it.fix != "") ? Max(12, Min(34, Round(Min(DefKeyH() * 0.46, DefPitch() * 0.38)))) : FontPx()
    if (kind = "key" || kind = "special")
        base := Round(base * fontScale)        ; zoom applies to the keys only
    px := Max(8, Min(64, base + st[1]))
    rc := rcFill
    NumPut("Int", it.x, "Int", it.y, "Int", it.x + it.ww, "Int", it.y + it.hh, rc)

    colors := Pal(kind)
    if IsObject(colors) {
        state := (hiliteOn && it.act && i = pressIdx) ? 3 : ((it.act && i = hovIdx) ? 2 : 1)
        bg := colors[state]
        if (state = 1 && IsActive(it))
            bg := Pal("special")[3]
        DllCall("FillRect", "Ptr", dc, "Ptr", rc, "Ptr", Brush(bg))
        DllCall("FrameRect", "Ptr", dc, "Ptr", rc, "Ptr", Brush(BorderCol()))
    }

    text := IsObject(it.k) ? Lbl(it.k) : it.text
    if (text = "")
        return
    NumPut("Int", it.x + 3, "Int", it.y + 1, "Int", it.x + it.ww - 3, "Int", it.y + it.hh - 1, rc)
    flags := (kind = "label") ? 0x824 : (kind = "body") ? 0x810 : 0x825
    DllCall("SelectObject", "Ptr", dc, "Ptr", GetFont(px, st[2]))
    DllCall("SetTextColor", "Ptr", dc, "UInt", RGB(TextCol(kind)))
    DllCall("DrawTextW", "Ptr", dc, "WStr", text, "Int", -1, "Ptr", rc, "UInt", flags)
}

; draws only the part of the window that needs repainting (l,t,r,b)
Render(hdc, l, t, r, b) {
    w := r - l, h := b - t
    if (w <= 0 || h <= 0)
        return
    mdc := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    bmp := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", w, "Int", h, "Ptr")
    oldBmp := DllCall("SelectObject", "Ptr", mdc, "Ptr", bmp, "Ptr")
    DllCall("SetViewportOrgEx", "Ptr", mdc, "Int", -l, "Int", -t, "Ptr", 0)
    FillRectC(mdc, l, t, w, h, BgCol())
    DllCall("SetBkMode", "Ptr", mdc, "Int", 1)
    for i, it in items {
        if (it.x < r && it.x + it.ww > l && it.y < b && it.y + it.hh > t)
            DrawItem(mdc, i, it)
    }
    DllCall("BitBlt", "Ptr", hdc, "Int", l, "Int", t, "Int", w, "Int", h, "Ptr", mdc, "Int", l, "Int", t, "UInt", 0x00CC0020)
    DllCall("SelectObject", "Ptr", mdc, "Ptr", oldBmp)
    DllCall("DeleteObject", "Ptr", bmp)
    DllCall("DeleteDC", "Ptr", mdc)
}

OnPaint(wParam, lParam, msg, hwnd) {
    c := CtxOf(hwnd)
    if !IsObject(c)
        return
    return RunIn(c, PaintBody, hwnd)
}

PaintBody(hwnd) {
    ps := Buffer(72, 0)
    hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")
    o := A_PtrSize + 4                      ; PAINTSTRUCT.rcPaint
    Render(hdc, NumGet(ps, o, "Int"), NumGet(ps, o + 4, "Int"), NumGet(ps, o + 8, "Int"), NumGet(ps, o + 12, "Int"))
    DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    return 0
}

OnErase(wParam, lParam, msg, hwnd) {
    if !IsObject(CtxOf(hwnd))
        return
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rcInv)
    DllCall("FillRect", "Ptr", wParam, "Ptr", rcInv, "Ptr", Brush(BgCol()))
    return 1
}

; ---------- Mouse: hover + click effects ----------
SX(lParam) {
    v := lParam & 0xFFFF
    return v >= 0x8000 ? v - 0x10000 : v
}
SY(lParam) {
    v := (lParam >> 16) & 0xFFFF
    return v >= 0x8000 ? v - 0x10000 : v
}

HitIdx(x, y) {
    for i, it in items {
        if (it.act && x >= it.x && x < it.x + it.ww && y >= it.y && y < it.y + it.hh)
            return i
    }
    return 0
}

OnMouseMove(wParam, lParam, msg, hwnd) {
    c := CtxOf(hwnd)
    if IsObject(c)
        RunIn(c, MouseMoveBody, lParam)
}

MouseMoveBody(lParam) {
    global hovIdx, tracking
    idx := HitIdx(SX(lParam), SY(lParam))
    if (idx != hovIdx) {
        old := hovIdx
        hovIdx := idx
        InvalidateItem(old)
        InvalidateItem(idx)
    }
    if !tracking {
        tme := Buffer(24, 0)
        NumPut("UInt", 24, "UInt", 2, "Ptr", G.Hwnd, tme)      ; TME_LEAVE
        DllCall("TrackMouseEvent", "Ptr", tme)
        tracking := true
    }
}

OnMouseLeave(wParam, lParam, msg, hwnd) {
    c := CtxOf(hwnd)
    if IsObject(c)
        RunIn(c, MouseLeaveBody)
}

MouseLeaveBody() {
    global hovIdx, tracking
    tracking := false
    if (hovIdx != 0) {
        old := hovIdx
        hovIdx := 0
        InvalidateItem(old)
    }
}

OnLDown(wParam, lParam, msg, hwnd) {
    c := CtxOf(hwnd)
    if IsObject(c)
        RunIn(c, LDownBody, lParam)
}

LDownBody(lParam) {
    global pressIdx, pressCtx
    pressIdx := HitIdx(SX(lParam), SY(lParam))
    if (pressIdx != 0) {
        pressCtx := cur
        DllCall("SetCapture", "Ptr", G.Hwnd)
        InvalidateItem(pressIdx)
        if soundOn
            SetTimer(PlayKeySound, -1)
        if items[pressIdx].rep {          ; typing keys act on press and repeat while held
            SetTimer(items[pressIdx].fn, -1)
            SetTimer(RepeatBegin, -450)
        }
    }
}

RepeatBegin() => RunIn(pressCtx, RepeatBeginBody)
RepeatTick() => RunIn(pressCtx, RepeatTickBody)

RepeatBeginBody() {
    if (pressIdx != 0 && GetKeyState("LButton", "P"))
        SetTimer(RepeatTick, 40)
}

RepeatTickBody() {
    if (pressIdx < 1 || pressIdx > items.Length || !items[pressIdx].rep || !GetKeyState("LButton", "P")) {
        SetTimer(RepeatTick, 0)
        return
    }
    items[pressIdx].fn()
}

OnLUp(wParam, lParam, msg, hwnd) {
    c := CtxOf(hwnd)
    if IsObject(c)
        RunIn(c, LUpBody, lParam)
}

LUpBody(lParam) {
    global pressIdx
    DllCall("ReleaseCapture")
    SetTimer(RepeatBegin, 0)
    SetTimer(RepeatTick, 0)
    if (pressIdx = 0)
        return
    idx := HitIdx(SX(lParam), SY(lParam))
    if (idx = pressIdx) {
        if !items[idx].rep
            SetTimer(items[idx].fn, -1)
        SetTimer(ClearPress.Bind(cur), -110)      ; keep the "pressed" colour briefly so it is visible
    } else {
        old := pressIdx
        pressIdx := 0
        InvalidateItem(old)
    }
}

ClearPress(c) => RunIn(c, ClearPressBody)

ClearPressBody() {
    global pressIdx
    old := pressIdx
    pressIdx := 0
    InvalidateItem(old)
}

; ---------- Tabs (Bangla / English) ----------
SwitchTab(i, force := false) => RunIn(ctxMain, SwitchTabBody, i, force)

SwitchTabBody(i, force) {
    global tabIdx, shiftOn, capsOn, ctrlOn, altOn, altgrOn, deadAcc, hovIdx, pressIdx, winX, winY, conjOn, conjPage
    if (i = tabIdx && !force)
        return
    tabIdx := i
    conjOn := false, conjPage := 1
    shiftOn := capsOn := ctrlOn := altOn := altgrOn := false
    deadAcc := ""
    hovIdx := pressIdx := 0
    BuildItems()
    sz := sizes[i]
    pos := ""
    if (winX != "" && winY != "") {
        pos := Format(" x{} y{}", winX, winY)
        winX := winY := ""          ; only needed for the first show
    }
    G.Show(Format("w{} h{}{} NoActivate", sz[1], sz[2], pos))
    Relayout()
}

; ---------- Settings and About: their own windows ----------
AuxOpts() => "+Resize -MaximizeBox -MinimizeBox -DPIScale +MinSize" Round(480 * S) "x" Round(200 * S)
    . " +0x02000000 +E0x08000000 +Owner" gMain.Hwnd

CreateSettingsWin() {
    global ctxSet, themeDDL, fontDDL
    g := Gui(AuxOpts(), "Settings")
    g.BackColor := BgCol()
    g.SetFont("s10", "Segoe UI")
    names := []
    for n, v in themes
        names.Push(n)
    idx := 1
    for i, n in names {
        if (n = themeName)
            idx := i
    }
    themeDDL := g.Add("DropDownList", "x-2000 y-2000 w300 R12 Choose" idx, names)
    themeDDL.OnEvent("Change", (c, *) => RunIn(ctxSet, OnThemeChange, c))
    fontDDL := g.Add("DropDownList", "x-2000 y-2000 w300 R14 Choose1", [fontName])
    fontDDL.OnEvent("Change", (c, *) => RunIn(ctxSet, OnFontChange, c))
    ctxSet := NewCtx("settings", 3, g)
    g.OnEvent("Close", (*) => (g.Hide(), true))
    g.OnEvent("Size", (gg, mm, w, h) => OnSize(ctxSet, gg, mm, w, h))
    FixDdlFonts()
    ApplySettings()
    return ctxSet
}

CreateAboutWin() {
    global ctxAbout
    g := Gui(AuxOpts(), "About")
    g.BackColor := BgCol()
    g.SetFont("s10", "Segoe UI")
    ctxAbout := NewCtx("about", 4, g)
    g.OnEvent("Close", (*) => (g.Hide(), true))
    g.OnEvent("Size", (gg, mm, w, h) => OnSize(ctxAbout, gg, mm, w, h))
    ApplySettings()
    return ctxAbout
}

OpenAux(which) {
    c := (which = "settings") ? ctxSet : ctxAbout
    if !IsObject(c)
        c := (which = "settings") ? CreateSettingsWin() : CreateAboutWin()
    RunIn(c, ShowAux)
}

ShowAux() {
    global hovIdx, pressIdx
    hovIdx := pressIdx := 0
    if (cur.id = "settings")
        EnsureFontList()
    BuildItems()
    sz := sizes[cur.key]
    if IsVis(cur) {
        G.Show("NoActivate")
    } else if !cur.placed {
        cur.placed := true
        ; first time: centre it over the keyboard window, kept inside the screen
        WinGetPos(&mx, &my, &mw, &mh, "ahk_id " gMain.Hwnd)
        vl := SysGet(76), vt := SysGet(77), vr := vl + SysGet(78), vb := vt + SysGet(79)
        x := Max(vl, Min(mx + (mw - sz[1]) // 2, vr - sz[1] - 16))
        y := Max(vt, Min(my + (mh - sz[2]) // 2, vb - sz[2] - 48))
        G.Show(Format("w{} h{} x{} y{} NoActivate", sz[1], sz[2], x, y))
    } else {
        G.Show("NoActivate")          ; Windows remembers where it was last time
    }
    Relayout()
}

; ---------- Typing ----------
FlushDead() {
    global deadAcc
    if (deadAcc != "") {
        SendText(deadAcc)
        deadAcc := ""
    }
}

TypeChar(ch) {
    global deadAcc
    if (ctrlOn || altOn) {
        FlushDead()
        if (StrLen(ch) = 1 && Ord(ch) < 128) {
            key := (ch = "{") ? "{{}" : (ch = "}") ? "{}}" : "{" ch "}"
            Send((ctrlOn ? "^" : "") (altOn ? "!" : "") key)
        } else
            SendText(ch)
        return
    }
    if (deadAcc != "") {
        acc := deadAcc
        deadAcc := ""
        if (ch = " ") {
            SendText(acc)
            return
        }
        if (compose.Has(acc ch)) {
            SendText(compose[acc ch])
            return
        }
        SendText(acc)
    }
    if (tabIdx = 2 && ch != "" && InStr(deadSet, ch)) {
        deadAcc := ch
        return
    }
    SendText(ch)
}

ResetOneShot() {
    global shiftOn, ctrlOn, altOn, altgrOn
    if (shiftOn || ctrlOn || altOn || altgrOn) {
        shiftOn := ctrlOn := altOn := altgrOn := false
        Invalidate()
    }
}

KeyPress(k) {
    global shiftOn, capsOn, ctrlOn, altOn, altgrOn
    switch k.t {
        case "conj":   ToggleConj()
        case "conjpg": ToggleConjPage()
        case "shift": shiftOn := !shiftOn, Invalidate()
        case "caps":  capsOn := !capsOn, Invalidate()
        case "ctrl":  ctrlOn := !ctrlOn, Invalidate()
        case "alt":   altOn := !altOn, Invalidate()
        case "altgr": altgrOn := !altgrOn, Invalidate()
        case "bs":    FlushDead(), Send("{BackSpace}"), ResetOneShot()
        case "del":   FlushDead(), Send("{Delete}"), ResetOneShot()
        case "enter": FlushDead(), Send("{Enter}"), ResetOneShot()
        case "tab":   FlushDead(), Send("{Tab}"), ResetOneShot()
        case "space": TypeChar(" "), ResetOneShot()
        default:
            TypeChar(Resolve(k))
            ResetOneShot()
    }
}

; ---------- Settings ----------
ApplySettings() {
    for c in ctxList
        ApplyGuiTheme(c.gui)
    th := UiDark() ? "DarkMode_CFD" : "Explorer"
    for c in [fontDDL, themeDDL] {
        if IsObject(c)
            DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", th, "Ptr", 0)
    }
    InvalidateAll()
}

ApplyGuiTheme(g) {
    WinSetAlwaysOnTop(posMode = "top" ? 1 : 0, "ahk_id " g.Hwnd)
    g.BackColor := BgCol()
    v := UiDark() ? 1 : 0
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 20, "Int*", v, "Int", 4)   ; dark title bar
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 19, "Int*", v, "Int", 4)
    ; force Windows to redraw the title bar now, so it matches the mode immediately
    DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x37)
    DllCall("RedrawWindow", "Ptr", g.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x401)   ; INVALIDATE | FRAME
}

SetPos(m) {
    global posMode, hovIdx
    posMode := m
    hovIdx := 0
    SaveSettings()
    ApplySettings()
    BuildItems()
    Relayout()
}

SetMode(d) {
    global darkMode, hovIdx
    darkMode := d
    hovIdx := 0
    SaveSettings()
    ApplySettings()
    BuildItems()
    Relayout()
}

ZoomBy(d) {
    global fontScale
    fontScale := Round(Max(0.6, Min(2.0, fontScale + d)), 1)
    zoomLbl.text := ZoomText()
    SaveSettings()
    InvalidateAll()
}

OnThemeChange(ctl, *) {
    global themeName
    themeName := ctl.Text
    SaveSettings()
    ApplySettings()
}

OnFontChange(ctl, *) {
    global fontName
    fontName := ctl.Text
    ClearFonts()
    SaveSettings()
    InvalidateAll()
}

SizeBy(d) {
    global keyScale, sizes
    nv := Round(Max(0.7, Min(1.6, keyScale + d)), 1)
    if (nv = keyScale)
        return
    keyScale := nv
    nd := DefSizes()
    sizes[1] := nd[1], sizes[2] := nd[2]          ; only the keyboard window changes size; Settings / About keep theirs
    szLbl.text := Round(keyScale * 100) "%"
    sz := sizes[tabIdx]
    gMain.Show(Format("w{} h{} NoActivate", sz[1], sz[2]))
    ForEachCtx(Relayout)
    SaveSettings()
}

GapBy(d) {
    global gapBase, GAP
    nv := Max(0, Min(16, gapBase + d))
    if (nv = gapBase)
        return
    gapBase := nv
    GAP := Round(gapBase * S)
    gapLbl.text := String(gapBase)
    ForEachCtx(Relayout)
    SaveSettings()
}

; ---------- Windows scaling changes (WM_DPICHANGED) ----------
OnDpiChanged(wParam, lParam, msg, hwnd) {
    if !IsObject(CtxOf(hwnd))
        return
    ApplyDpi(wParam & 0xFFFF)
    l := NumGet(lParam, 0, "Int"), t := NumGet(lParam, 4, "Int")
    r := NumGet(lParam, 8, "Int"), b := NumGet(lParam, 12, "Int")
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", l, "Int", t, "Int", r - l, "Int", b - t, "UInt", 0x14)   ; NOZORDER | NOACTIVATE
    return 0
}

ApplyDpi(dpi) {
    global S, M, GAP, sizes
    if (dpi < 48 || dpi = Round(S * 96))
        return
    ratio := dpi / (S * 96)
    S := dpi / 96
    M := Round(12 * S)
    GAP := Round(gapBase * S)
    Loop 4
        sizes[A_Index] := [Round(sizes[A_Index][1] * ratio), Round(sizes[A_Index][2] * ratio)]
    for c in ctxList
        c.gui.Opt("+MinSize" Round(480 * S) "x" Round(c.id = "main" ? 240 * S : 200 * S))
    ClearFonts()
    FixDdlFonts()
}

; the drop-down lists keep their own font, so give them one that matches the new scale
FixDdlFonts() {
    static hf := 0
    nf := DllCall("CreateFontW", "Int", -Round(10 * S * 96 / 72), "Int", 0, "Int", 0, "Int", 0, "Int", 400
        , "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 5, "UInt", 0
        , "WStr", "Segoe UI", "Ptr")
    for c in [fontDDL, themeDDL] {
        if IsObject(c)
            SendMessage(0x30, nf, 1, c)          ; WM_SETFONT
    }
    if hf
        DllCall("DeleteObject", "Ptr", hf)
    hf := nf
}

; ---------- Click sound (reads every audio file in the "On Screen KB Data" folder, plays one at random) ----------
ScanSounds() {
    global soundFiles, soundScanned, lastSound
    soundFiles := []
    soundScanned := true
    lastSound := 0
    if !DirExist(soundDir)
        return
    exts := "|wav|mp3|wma|wm|aac|m4a|flac|ogg|oga|opus|mid|midi|rmi|aif|aiff|aifc|au|snd|ac3|amr|3gp|mp2|"
    Loop Files soundDir "\*", "F" {
        if InStr(exts, "|" StrLower(A_LoopFileExt) "|")
            soundFiles.Push(A_LoopFileFullPath)
    }
}

PlayKeySound() {
    global lastSound
    if !soundOn
        return
    if !soundScanned
        ScanSounds()
    n := soundFiles.Length
    if (n = 0) {                     ; folder missing or empty: plain beep so the option still does something
        SoundBeep(1500, 12)
        return
    }
    i := Random(1, n)
    while (n > 1 && i = lastSound)   ; do not repeat the same sound twice in a row
        i := Random(1, n)
    lastSound := i
    try SoundPlay(soundFiles[i])
}

ToggleOpt(n) {
    global soundOn, hiliteOn, rememberTab, hovIdx
    switch n {
        case "tab":    rememberTab := !rememberTab
        case "sound":
            soundOn := !soundOn
            if soundOn {                 ; re-read the folder, so newly added files are picked up
                ScanSounds()
                SetTimer(PlayKeySound, -1)
            }
        case "hilite": hiliteOn := !hiliteOn
    }
    hovIdx := 0
    SaveSettings()
    BuildItems()
    Relayout()
}

ToggleConj() {
    global conjOn, conjPage, hovIdx
    conjOn := !conjOn
    conjPage := 1
    hovIdx := 0
    BuildItems()
    Relayout()
}

ToggleConjPage() {
    global conjPage, hovIdx
    conjPage := 3 - conjPage
    hovIdx := 0
    BuildItems()
    Relayout()
}

ResetAll() => RunIn(ctxSet, ResetAllBody)

ResetAllBody() {
    global posMode, darkMode, themeName, fontScale, fontName, sizes, hovIdx, pressIdx, soundOn, hiliteOn, gapBase, keyScale, rememberTab, GAP
    soundOn := false, hiliteOn := true
    gapBase := 6, keyScale := 1.0, rememberTab := true
    GAP := Round(gapBase * S)
    posMode := "top"
    darkMode := false
    themeName := "Default"
    fontScale := 1.0
    fontName := "Nirmala UI"
    sizes := DefSizes()
    hovIdx := pressIdx := 0
    try themeDDL.Choose(themeName)
    try fontDDL.Choose(fontName)
    ClearFonts()
    ApplySettings()
    ForEachCtx(BuildItems)
    sz := sizes[tabIdx]
    gMain.Show(Format("w{} h{} Center NoActivate", sz[1], sz[2]))
    sz := sizes[3]
    G.Show(Format("w{} h{} NoActivate", sz[1], sz[2]))
    if IsVis(ctxAbout) {
        sz := sizes[4]
        ctxAbout.gui.Show(Format("w{} h{} NoActivate", sz[1], sz[2]))
    }
    ForEachCtx(Relayout)
    SaveSettings()
}

; reads the installed fonts only the first time Settings is opened (saves start-up time and memory)
EnsureFontList() {
    global fontsLoaded, fontName
    if fontsLoaded
        return
    fontsLoaded := true
    list := GetFontList()
    idx := 0
    for i, n in list {
        if (n = fontName)
            idx := i
    }
    if (idx = 0) {                   ; remembered font is no longer installed
        fontName := "Nirmala UI"
        ClearFonts()
        for i, n in list {
            if (n = fontName)
                idx := i
        }
        idx := Max(idx, 1)
    }
    fontDDL.Delete()
    fontDDL.Add(list)
    fontDDL.Choose(idx)
}

GetFontList() {
    seen := Map()
    names := ""
    for root in ["HKLM", "HKCU"] {
        try {
            regKey := root "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            Loop Reg regKey {
                n := RegExReplace(A_LoopRegName, "\s*\([^)]*\)\s*$")
                if (n = "" || InStr(n, " & ")
                    || RegExMatch(n, "i)\b(Bold|Italic|Oblique|Light|Black|Semibold|SemiLight|Medium|Thin|Regular|Condensed|Narrow|Heavy|Demi|Extra\w*|Ultra\w*)\b"))
                    continue
                if !seen.Has(n) {
                    seen[n] := 1
                    names .= n "`n"
                }
            }
        }
    }
    names := Trim(names, "`n")
    if (names = "")
        return ["Nirmala UI", "Segoe UI", "Arial"]
    return StrSplit(Sort(names, "U"), "`n")
}

; ---------- Create the window ----------
LoadSettings()
OnExit(SaveSettings)
gMain := Gui("+Resize -DPIScale +MinSize" Round(480 * S) "x" Round(240 * S) " +0x02000000 +E0x08000000 +E0x40000 +AlwaysOnTop"
    , "On-Screen Bangla Keyboard")
gMain.BackColor := BgCol()
gMain.SetFont("s10", "Segoe UI")
gMain.OnEvent("Close", (*) => ExitApp())
gMain.OnEvent("Size", (g, mm, w, h) => OnSize(ctxMain, g, mm, w, h))
ctxMain := NewCtx("main", 1, gMain)
UseCtx(ctxMain)

OnMessage(0x000F, OnPaint)        ; WM_PAINT
OnMessage(0x0014, OnErase)        ; WM_ERASEBKGND
OnMessage(0x0200, OnMouseMove)    ; WM_MOUSEMOVE
OnMessage(0x02A3, OnMouseLeave)   ; WM_MOUSELEAVE
OnMessage(0x0201, OnLDown)        ; WM_LBUTTONDOWN
OnMessage(0x0203, OnLDown)        ; WM_LBUTTONDBLCLK
OnMessage(0x0202, OnLUp)          ; WM_LBUTTONUP
OnMessage(0x02E0, OnDpiChanged)   ; WM_DPICHANGED

ApplySettings()                  ; before the first show, so the title bar starts in the right mode
SwitchTab(rememberTab ? lastTab : 1, true)
ApplySettings()

; Hands the memory the program does not need back to Windows (only idle pages; they return when used)
TrimMemory() {
    DllCall("psapi\EmptyWorkingSet", "Ptr", DllCall("kernel32\GetCurrentProcess", "Ptr"))
}
