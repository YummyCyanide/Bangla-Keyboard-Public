; ===========================================================================
;  Typing Tutor  (version 2.1.8)
;  Typing test / practice. Same layout idea as the Docs Converter:
;  the typing area on the left, the options (inspector) on the right.
;
;  - Test time: 30s, 1m, 2m, 3m, 5m, 10m, 15m with a live countdown, or "No timer" (a stopwatch for beginners:
;    it counts up while you practise and stops when the paragraph is finished).
;  - Texts are read from the Typing Tutor Data folder (next to this script): one .dat file per
;    language (English.dat, Bangla.dat, Bangla ANSI.dat, Hindi.dat ...).
;    Paragraphs are separated by a blank line. One paragraph is shown at a time,
;    the next one appears when it is finished.
;  - Encoding: Auto (UTF-8 / UTF-16 / ANSI), or chosen by hand. Font and size are
;    chosen by hand and remembered for each file (needed for ANSI fonts like SutonnyMJ).
;  - Correct letters turn green, wrong letters turn red.
;  - The keyboard layout / typing software (Bijoy, Avro, ...) is the user's own choice:
;    the app only compares what is typed with the text.
;  Settings and history: %AppData%\Bangla Keyboard\ (Typing Tutor.dat - the same folder as the Docs Converter settings)
;  Your own texts (added, edited, new files): %AppData%\Bangla Keyboard\Custom Typing Tutor Files\  (a backup that stays after uninstall)
;  Needs AutoHotkey v2.
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
SetWorkingDir A_ScriptDir
ListLines(false)
SetTimer(TrimMemory, -3000)         ; once, shortly after start: hand unused memory back to Windows

class App {
    static title := "Typing Tutor"
    static dataDir := ""
    static ini := ""
    static hist := ""
    static dir := ""
    static cdir := ""
}

class K {
    ; viramas of the Indic scripts: the letter after one joins the cluster
    static vir := Chr(0x094D) . Chr(0x09CD) . Chr(0x0A4D) . Chr(0x0ACD) . Chr(0x0B4D) . Chr(0x0BCD) . Chr(0x0C4D) . Chr(0x0CCD) . Chr(0x0D4D) . Chr(0x0DCA)
}

class Th {
    static cur := ""
    static cname := "Dark"
    static names := ["Dark", "Light", "Gray", "Blue", "Green", "Purple", "Orange", "Rose", "Teal"]
    static all := Map()
}

class St {
    static files := []
    static paras := []
    static fileName := ""
    static note := ""
    static state := "idle"          ; idle / ready / run / done
    static dur := 60
    static t0 := 0
    static endTick := 0
    static lastSec := -1
    static target := ""
    static tlen := 0
    static cur := 0
    static prevN := 0
    static clu := []
    static cOf := []
    static cst := []
    static words := []
    static used := Map()
    static keys := 0
    static errs := 0
    static accOk := 0
    static accTyped := 0
    static accWords := 0
    static parasDone := 0
    static fixed := false
    static busy := false
    static loading := false
    static cw := 0
    static ch := 0
    static tab := 1
    static rtlIn := false
    static caps := false
    static res := ""
    static hideInsp := false
    static inspShown := true
    static inFrac := 0.30
    static drag := false
    static splitTop := 0
    static splitH := 0
    static spH := 8
    static pauseTick := 0
    static hlines := []
    static hmap := []
    static rawTags := []
    static tags := []
    static raw := []                ; all paragraphs of the file, before the punctuation / number options
    static textNote := ""
    static inspOff := 0             ; how far the right panel is scrolled (design units)
    static inspMax := 0
    static px := 99999              ; left edge of the right panel
}

class Ui {
    static g := ""
    static insp := []
    static tabs := []
    static tabBar := ""          ; the bar under the picked tab
    static tabLine := ""         ; a thin line under the three tabs
    static heads := []
    static themed := []
    static grp := []
    static fontList := []
    static fontSet := Map()
    static sizes := ["12", "14", "16", "18", "20", "22", "24", "26", "28", "32", "36", "40", "48", "56"]
    static face := "Segoe UI"
    static fsize := 18
    static ddDur := ""
    static ddFile := ""
    static ddPara := ""
    static ddEnc := ""
    static cbFont := ""
    static ddSize := ""
    static ddDir := ""
    static ddWpm := ""
    static ddTheme := ""
    static btnReload := ""
    static ddFin := ""
    static btnPanel := ""
    static split := ""
    static btnDelSel := ""
    static rBtnNext := ""
    static rBtnAgain := ""
    static btnNew := ""
    static btnRestart := ""
    static btnClear := ""
    static lblTimer := ""
    static lblWpm := ""
    static lblAcc := ""
    static lblWords := ""
    static lblCaps := ""
    static lblStatus := ""
    static lblBest := ""
    static rich := ""
    static edIn := ""
    static btnAddTxt := ""
    static btnEditTxt := ""
    static btnHelp := ""
    static links := []
    static rPic := ""
    static rW := 0
    static rH := 0
    static lv := ""
    static zoom := 1.0              ; interface size: 1.0 normal, 1.2 large, 1.4 extra large
    static inspH := 536             ; height of the whole right panel (design units)
    static ddPunct := ""
    static ddNum := ""
    static lnkSettings := ""
}

class Ew {
    static g := ""
    static mode := ""              ; add / edit
    static edit := ""
    static stat := ""
    static hint := ""
    static lblFile := ""
    static info := ""
    static file := ""
    static face := "Segoe UI"
    static sz := 13
    static top := 68
    static selA := 0
    static selB := 0
    static dirty := false
    static setting := false
    static bak := false
    static reload := false
    static fg := ""
    static fEdit := ""
    static fCase := ""
    static lastFind := ""
    static lastCase := false
}

class Pp {
    static g := ""
    static owner := ""
    static edit := ""
    static dd := ""
    static kind := ""
}

class Fw {
    static g := ""
}

class Hw {
    static g := ""
    static link := ""
    static tabs := []
    static names := []
    static tab := ""
    static fh := 0
    static eds := []
    static btns := []
    static pic := ""
    static pw := 0
    static ph := 0
    static cur := 1
}

class Hk {
    static acts := []               ; [id, label, default key, function]
    static cur := Map()             ; id -> key now in use ("" = none)
}

class Tp {
    static list := []               ; [control, text or function, hotkey id]
    static on := true
    static cur := 0
    static since := 0
    static shown := false
}

class Sw {
    static g := ""
    static hk := Map()
    static chkTips := ""
    static chkInfo := ""
    static ddScale := ""
}

Main()

; ---------------------------------------------------------------------------
;  Start
; ---------------------------------------------------------------------------
Main() {
    InitThemes()
    App.dataDir := A_AppData . "\Bangla Keyboard"           ; same folder as the Docs Converter settings
    try DirCreate(App.dataDir)
    App.cdir := App.dataDir . "\Custom Typing Tutor Files"    ; your own texts: they stay here even if the program is removed
    try DirCreate(App.cdir)
    App.ini := App.dataDir . "\Typing Tutor.dat"
    App.hist := App.dataDir . "\Typing Tutor History.dat"
    try {
        if !FileExist(App.ini)
            FileOpen(App.ini, "w", "UTF-16").Close()       ; UTF-16 with BOM, so any folder name is kept
    }
    App.dir := A_ScriptDir . "\Typing Tutor Data"                       ; the texts that come with the program
    try DirCreate(App.dir)
    EnsureSampleText()
    EnsureBeginnerFile()
    St.files := ListFiles()
    DllCall("LoadLibrary", "Str", "Msftedit.dll", "Ptr")    ; the rich edit control used for the text
    BuildFontList()
    scl := Ini("Settings", "UiScale", "1")
    Ui.zoom := (scl = "2" || scl = "3") ? 1.2 : 1.0
    Tp.on := (Ini("Settings", "Tips", "1") != "0")
    HkInit()
    St.hideInsp := (Ini("Settings", "HidePanel", "0") = "1")
    fr := Ini("Settings", "InFrac", "0.30")
    St.inFrac := (IsNumber(fr) && fr >= 0.10 && fr <= 0.65) ? (fr + 0) : 0.30
    BuildGui()

    ; saved settings
    di := Ini("Settings", "Dur", "2")
    if (IsInteger(di) && di >= 1 && di <= 8)
        Ui.ddDur.Choose(Integer(di))
    wi := Ini("Settings", "Wpm", "1")
    if (IsInteger(wi) && wi >= 1 && wi <= 2)
        Ui.ddWpm.Choose(Integer(wi))
    fi := Ini("Settings", "Finish", "1")
    if (IsInteger(fi) && fi >= 1 && fi <= 5)
        Ui.ddFin.Choose(Integer(fi))
    pu := Ini("Settings", "Punct", "1")
    if (IsInteger(pu) && pu >= 1 && pu <= 4)
        Ui.ddPunct.Choose(Integer(pu))
    nu := Ini("Settings", "Nums", "1")
    if (IsInteger(nu) && nu >= 1 && nu <= 3)
        Ui.ddNum.Choose(Integer(nu))
    tn := Ini("Settings", "Theme", "Dark")
    if (tn = "Colorful")
        tn := "Purple"
    ti := IndexOf(Th.names, tn)
    if (ti = 0)
        ti := 1
    Ui.ddTheme.Choose(ti)
    ApplyTheme(Th.names[ti])
    UpdatePanelBtn()
    RegisterTips()
    ApplyHotkeys()

    dpi := A_ScreenDPI / 96
    sw := Ini("Settings", "W3", "")
    sh := Ini("Settings", "H3", "")
    gw := (IsInteger(sw) && sw >= 820) ? Integer(sw) : 1000
    gh := (IsInteger(sh) && sh >= 560) ? Integer(sh) : 640
    gw := Min(Round(gw * dpi), A_ScreenWidth - 20)
    gh := Min(Round(gh * dpi), A_ScreenHeight - 90)
    Ui.g.Show("w" . gw . " h" . gh)
    Ui.g.GetClientPos(, , &cw, &ch)
    St.cw := cw
    St.ch := ch
    Layout()
    RenderResults()
    ShowTab(1)
    LoadHistory()
    ReloadList(Ini("Settings", "File", ""))
    SetTimer(UiTick, 500)
    SetTimer(TipTick, 200)
    OnMessage(0x201, WmLDown)
    OnMessage(0x200, WmMove)
    OnMessage(0x202, WmLUp)
    OnMessage(0x20, WmSetCursor)
    OnMessage(0x20A, WmWheel)
    OnExit(SaveSettings)
    if (Ini("Settings", "ShowInfo", "1") != "0")
        SetTimer(OpenHelp, -250)           ; the Info window opens at start (can be switched off in Settings)
}

InitThemes() {
    Th.all["Dark"] := {bg: 0x1E1F22, panel: 0x2B2D31, text: 0xD7DAE0, muted: 0x9AA0AA, ok: 0x6FD08C, bad: 0xFF6B6B, badBg: 0x5A2325, curBg: 0x44506A, curFg: 0xFFFFFF, accent: 0x5BA8FF, dark: true}
    Th.all["Light"] := {bg: 0xF1F3F6, panel: 0xFFFFFF, text: 0x20242A, muted: 0x6B7280, ok: 0x15803D, bad: 0xC81E1E, badBg: 0xFFD5D5, curBg: 0xBFDBFE, curFg: 0x111111, accent: 0x1D4ED8, dark: false}
    Th.all["Gray"] := {bg: 0x55595F, panel: 0x6A6E75, text: 0xF4F4F4, muted: 0xCCCFD4, ok: 0xB5F5BE, bad: 0xFFA0A0, badBg: 0x8A4A4A, curBg: 0xA9AEB6, curFg: 0x111111, accent: 0xFFD36B, dark: true}
    Th.all["Blue"] := {bg: 0x0E1A2E, panel: 0x172B4D, text: 0xE6EEFA, muted: 0x8FA8CC, ok: 0x7CE0A0, bad: 0xFF7B7B, badBg: 0x5A2A38, curBg: 0x2F5FA8, curFg: 0xFFFFFF, accent: 0x5CB0FF, dark: true}
    Th.all["Green"] := {bg: 0x0E2118, panel: 0x16372A, text: 0xE3F5EA, muted: 0x8DBFA3, ok: 0x9BF5B4, bad: 0xFF8A80, badBg: 0x5C2A2A, curBg: 0x2E7D55, curFg: 0xFFFFFF, accent: 0x4ADE80, dark: true}
    Th.all["Purple"] := {bg: 0x1A1230, panel: 0x2A1E4A, text: 0xF0EAFF, muted: 0xB6A6E0, ok: 0x7CF0B8, bad: 0xFF7A9C, badBg: 0x6A2048, curBg: 0x6D4BC4, curFg: 0xFFFFFF, accent: 0xB38CFF, dark: true}
    Th.all["Orange"] := {bg: 0x241608, panel: 0x3A2410, text: 0xFFF1E3, muted: 0xD1AE8A, ok: 0x8BE8A0, bad: 0xFF7B6B, badBg: 0x5E2420, curBg: 0xC76B12, curFg: 0xFFFFFF, accent: 0xFFA040, dark: true}
    Th.all["Rose"] := {bg: 0x2A1220, panel: 0x421C33, text: 0xFFEAF3, muted: 0xD9A3BF, ok: 0x8CF0B4, bad: 0xFF9A8A, badBg: 0x6A2030, curBg: 0xB8336E, curFg: 0xFFFFFF, accent: 0xFF6FA8, dark: true}
    Th.all["Teal"] := {bg: 0x0C2224, panel: 0x143A3D, text: 0xE0F7F7, muted: 0x8AC4C4, ok: 0x8CF0A8, bad: 0xFF8A80, badBg: 0x5A2A2E, curBg: 0x1F8A8A, curFg: 0xFFFFFF, accent: 0x2DD4CF, dark: true}
}

; ---------------------------------------------------------------------------
;  Small helpers
; ---------------------------------------------------------------------------
Hx(c) => Format("{:06X}", c)

; interface size: Dz() = pixels per design unit, Fp(n) = font size in points
Dz() => (A_ScreenDPI / 96) * Ui.zoom

Fp(n) => Max(8, Round(n * Ui.zoom))

Sd(n) => Round(n * A_ScreenDPI / 96)

Bgr(c) => ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF)

; colour between a and b (both 0xRRGGBB); f = 0..1
Mix(a, b, f) {
    r := Round(((a >> 16) & 255) * (1 - f) + ((b >> 16) & 255) * f)
    g := Round(((a >> 8) & 255) * (1 - f) + ((b >> 8) & 255) * f)
    bl := Round((a & 255) * (1 - f) + (b & 255) * f)
    return (r << 16) | (g << 8) | bl
}

Cp(s, i) {
    c := SubStr(s, i, 1)
    return (c = "") ? -1 : Ord(c)
}

IndexOf(arr, val) {
    for i, v in arr {
        if (v = val)
            return i
    }
    return 0
}

Ini(sec, key, def := "") {
    try {
        return IniRead(App.ini, sec, key, def)
    } catch {
        return def
    }
}

IniPut(sec, key, val) {
    try IniWrite(val, App.ini, sec, key)
}

FmtClock(sec) => Format("{}:{:02d}", sec // 60, Mod(sec, 60))

DurLabel(sec) => (sec < 60) ? sec . " sec" : (sec // 60) . " min"

SetStatus(s) {
    Ui.lblStatus.Text := s
}

ShowStats(wpm, acc, words) {
    Ui.lblWpm.Text := "WPM  " . Round(wpm)
    Ui.lblAcc.Text := "Accuracy  " . Round(acc) . "%"
    Ui.lblWords.Text := "Words  " . words
}

FocusInput() {
    if (St.tab = 1 && (St.state = "ready" || St.state = "run")) {
        try Ui.edIn.Focus()
    }
}

; ---------------------------------------------------------------------------
;  Text files
; ---------------------------------------------------------------------------
EnsureSampleText() {
    if (ListFiles().Length > 0)
        return
    t := "Typing is a skill, and like every skill it grows with calm, regular practice. Sit up straight, keep your wrists relaxed, and let your fingers rest on the home row.`n`n"
    t .= "Speed is the reward of accuracy. When you slow down a little and fix every mistake, your fingers learn the right paths across the keyboard.`n`n"
    t .= "The river ran quietly past the old stone bridge, carrying yellow leaves toward the sea. By evening the sky turned orange, and the whole valley seemed to hold its breath.`n"
    try FileAppend(t, App.cdir . "\English.dat", "UTF-8-RAW")
}

; the beginner exercise file is put in your custom files folder once; delete it if you do not want it
EnsureBeginnerFile() {
    if (Ini("Settings", "BeginnerDone", "0") = "1")
        return
    IniPut("Settings", "BeginnerDone", "1")
    if FileKnown("Beginner English")
        return
    try {
        f := FileOpen(App.cdir . "\Beginner English.dat", "w", "UTF-8")
        f.Write(ExerciseText())
        f.Close()
    }
}

; Texts that come with the program (Typing Tutor Data folder) + your own texts (AppData custom folder)
ListFiles() {
    seen := Map()
    seen.CaseSense := "Off"
    s := ""
    for d in [App.dir, App.cdir] {
        Loop Files d . "\*.dat", "F" {
            SplitPath(A_LoopFileName, , , , &nm)
            if seen.Has(nm)
                continue
            seen[nm] := 1
            s .= (s = "" ? "" : "|") . nm
        }
    }
    if (s = "")
        return []
    return StrSplit(Sort(s, "D|"), "|")
}

FileKnown(name) {
    return (FileExist(App.cdir . "\" . name . ".dat") || FileExist(App.dir . "\" . name . ".dat")) ? true : false
}

; where to read a text from: your custom copy first, then the program's own Typing Tutor Data folder
TxtPath(name) {
    c := App.cdir . "\" . name . ".dat"
    if FileExist(c)
        return c
    return App.dir . "\" . name . ".dat"
}

; where to write a text: always the custom folder (a program text is copied there first)
WritePath(name) {
    c := App.cdir . "\" . name . ".dat"
    if !FileExist(c) {
        src := App.dir . "\" . name . ".dat"
        if FileExist(src) {
            try DirCreate(App.cdir)
            try FileCopy(src, c, 1)
        }
    }
    return c
}

IsUtf8(buf, off) {
    n := buf.Size - off
    if (n <= 0)
        return true
    r := DllCall("MultiByteToWideChar", "UInt", 65001, "UInt", 8, "Ptr", buf.Ptr + off, "Int", n, "Ptr", 0, "Int", 0, "Int")
    return (r > 0)
}

; mode: 1 Auto, 2 UTF-8, 3 UTF-16, 4 ANSI (Windows-1252), 5 ANSI (system default)
; info (optional): how the file is stored: UTF-8BOM, UTF-8, UTF-16, UTF-16BE, CP1252 or CP0
ReadTextFile(path, mode, name, &info := "") {
    info := InStr(StrLower(name), "ansi") ? "CP1252" : "UTF-8BOM"
    buf := FileRead(path, "RAW")
    n := buf.Size
    if (n = 0)
        return ""
    b0 := NumGet(buf, 0, "UChar")
    b1 := (n >= 2) ? NumGet(buf, 1, "UChar") : 0
    b2 := (n >= 3) ? NumGet(buf, 2, "UChar") : 0
    off := 0
    enc := ""
    if (n >= 3 && b0 = 0xEF && b1 = 0xBB && b2 = 0xBF) {
        off := 3
        if (mode = 1 || mode = 2)
            enc := "UTF-8"
    } else if (n >= 2 && b0 = 0xFF && b1 = 0xFE) {
        off := 2
        if (mode = 1 || mode = 3)
            enc := "UTF-16"
    } else if (n >= 2 && b0 = 0xFE && b1 = 0xFF && (mode = 1 || mode = 3)) {
        info := "UTF-16BE"
        m2 := (n - 2) // 2
        if (m2 < 1)
            return ""
        tmp := Buffer(m2 * 2, 0)
        Loop m2 {
            k := (A_Index - 1) * 2
            NumPut("UChar", NumGet(buf, 2 + k + 1, "UChar"), tmp, k)
            NumPut("UChar", NumGet(buf, 2 + k, "UChar"), tmp, k + 1)
        }
        return StrGet(tmp, m2, "UTF-16")
    }
    if (enc = "") {
        if (mode = 2)
            enc := "UTF-8"
        else if (mode = 3)
            enc := "UTF-16"
        else if (mode = 4)
            enc := "CP1252"
        else if (mode = 5)
            enc := "CP0"
        else if InStr(StrLower(name), "ansi")
            enc := "CP1252"
        else if IsUtf8(buf, off)
            enc := "UTF-8"
        else
            enc := "CP1252"
    }
    if (enc = "UTF-8")
        info := (off = 3) ? "UTF-8BOM" : "UTF-8"
    else if (enc = "UTF-16")
        info := "UTF-16"
    else
        info := enc
    if (n - off <= 0)
        return ""
    if (enc = "UTF-16")
        txt := StrGet(buf.Ptr + off, (n - off) // 2, "UTF-16")
    else
        txt := StrGet(buf.Ptr + off, n - off, enc)
    if (SubStr(txt, 1, 1) = Chr(0xFEFF))
        txt := SubStr(txt, 2)
    return txt
}

; Paragraphs are separated by a blank line. If the file has no blank line at all,
; every line is a paragraph. Very long paragraphs are cut at a space.
; a line that starts with # (for example #Lesson_01) in front of a paragraph is the name of that paragraph:
; it is listed in the Paragraph box and is not typed. tags[] holds one name (or "") for every paragraph.
IsHashLine(l) {
    return (SubStr(l, 1, 1) = "#" && StrLen(l) <= 60 && RegExMatch(l, "^#\s*[^\s#]") && !RegExMatch(l, "[.!?\x{0964}]$"))
}

SplitParas(txt, &tags := "") {
    txt := StrReplace(txt, "`r`n", "`n")
    txt := StrReplace(txt, "`r", "`n")
    blocks := []
    if RegExMatch(txt, "\n[ \t]*\n") {
        cur := []
        Loop Parse txt, "`n" {
            line := Trim(A_LoopField)
            if (line = "") {
                if (cur.Length > 0) {
                    blocks.Push(cur)
                    cur := []
                }
            } else {
                cur.Push(line)
            }
        }
        if (cur.Length > 0)
            blocks.Push(cur)
    } else {
        Loop Parse txt, "`n" {
            line := Trim(A_LoopField)
            if (line != "")
                blocks.Push([line])
        }
    }
    out := []
    tags := []
    pend := ""
    for b in blocks {
        while (b.Length > 0 && IsHashLine(b[1])) {
            pend := Trim(RegExReplace(StrReplace(StrReplace(b[1], "_", " "), ".", " "), "^[#\s]+|\s+(?=\s)"))
            b.RemoveAt(1)
        }
        if (b.Length = 0)
            continue
        p := ""
        for ln in b
            p .= (p = "" ? "" : " ") . ln
        p := Trim(RegExReplace(p, "\s+", " "))
        while (StrLen(p) > 900) {
            cut := InStr(SubStr(p, 1, 700), " ", false, -1)
            if (cut < 200)
                cut := 700
            out.Push(Trim(SubStr(p, 1, cut)))
            tags.Push(pend)
            pend := ""
            p := Trim(SubStr(p, cut + 1))
        }
        if (p != "") {
            out.Push(p)
            tags.Push(pend)
        }
        pend := ""
    }
    return out
}

BuildFontList() {
    seen := Map()
    seen.CaseSense := "Off"
    Ui.fontSet.CaseSense := "Off"
    for root in ["HKLM", "HKCU"] {
        try {
            Loop Reg root . "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts", "V" {
                n := RegExReplace(A_LoopRegName, "\s*\([^)]*\)\s*$")
                for part in StrSplit(n, " & ") {
                    part := Trim(part)
                    if (part = "" || RegExMatch(part, "i)\s(Bold|Italic|Oblique|Light|Semibold|Semilight|Black|Regular)$"))
                        continue
                    seen[part] := 1
                    Ui.fontSet[part] := 1
                }
            }
        }
    }
    for n in ["Segoe UI", "Consolas", "Nirmala UI", "Kalpurush", "SutonnyMJ", "SolaimanLipi", "Siyam Rupali", "Vrinda", "Arial", "Tahoma"]
        seen[n] := 1
    s := ""
    for k in seen
        s .= (s = "" ? "" : "|") . k
    Ui.fontList := StrSplit(Sort(s, "D|"), "|")
}

GuessFont(name) {
    l := StrLower(name)
    if InStr(l, "ansi")
        return "SutonnyMJ"
    if (InStr(l, "bangla") || InStr(l, "bengali") || InStr(l, "hindi") || InStr(l, "nepali") || InStr(l, "marathi"))
        return "Nirmala UI"
    if InStr(l, "arab")
        return "Segoe UI"
    return "Consolas"
}

; ---------------------------------------------------------------------------
;  Window
; ---------------------------------------------------------------------------
BuildGui() {
    d := Dz()
    g := Gui("+Resize +0x2000000 +MinSize" . Min(Round(820 * d), A_ScreenWidth) . "x" . Min(Round(520 * d), A_ScreenHeight - 60), App.title)
    Ui.g := g
    g.SetFont("s" . Fp(9), "Segoe UI")

    ; ---- left: tab labels and their pages ----
    for i, nm in ["Test", "Results", "History"] {
        c := g.Add("Text", "x10 y10 w90 h26 0x200 0x100 Center", nm)
        c.OnEvent("Click", TabClick.Bind(i))
        Ui.tabs.Push(c)
    }
    Ui.tabBar := g.Add("Text", "x10 y30 w62 h3")
    Ui.tabLine := g.Add("Text", "x10 y34 w600 h1")
    Ui.btnPanel := g.Add("Text", "x500 y8 w112 h20 0x200 0x100 Center", "Hide panel")
    Ui.lnkSettings := g.Add("Text", "x420 y8 w70 h20 0x200 0x100 Center", "Settings")
    Ui.btnHelp := g.Add("Text", "x360 y8 w50 h20 0x200 0x100 Center", "Info")
    Ui.lblTimer := g.Add("Text", "x10 y46 w150 h50 0x200 Center", "1:00")
    Ui.lblWpm := g.Add("Text", "x170 y56 w100 h32 0x200 Center", "")
    Ui.lblAcc := g.Add("Text", "x280 y56 w100 h32 0x200 Center", "")
    Ui.lblWords := g.Add("Text", "x390 y56 w100 h32 0x200 Center", "")
    Ui.lblCaps := g.Add("Text", "x600 y56 w150 h26 0x200 Right", "")
    Ui.rich := g.Add("Custom", "ClassRichEdit50W +0x200844 +E0x200 x10 y100 w600 h250")
    Ui.split := g.Add("Text", "x10 y352 w600 h10 +0x100 0x200 Center", "· · · · ·")
    Ui.edIn := g.Add("Edit", "x10 y364 w600 h80 Multi -WantReturn -VScroll +0x40", "")

    ; Results page: a title, big cards, an accuracy bar, a tip and two buttons
    Ui.rPic := g.Add("Picture", "x10 y50 w300 h300 0xE")
    Ui.rBtnNext := g.Add("Button", "x10 y360 w120 h32", "Next text  (F5)")
    Ui.rBtnAgain := g.Add("Button", "x140 y360 w180 h32", "Restart same text  (F6)")

    ; History page
    Ui.lv := g.Add("ListView", "x10 y50 w600 h300 +Grid", ["Date and time", "Duration", "Text file", "Net WPM", "Accuracy %", "Words", "Mistakes"])
    Ui.lv.ModifyCol(1, Round(130 * d))
    Ui.lv.ModifyCol(2, Round(110 * d))
    Ui.lv.ModifyCol(3, Round(150 * d))
    Ui.lv.ModifyCol(4, Round(75 * d))
    Ui.lv.ModifyCol(5, Round(85 * d))
    Ui.lv.ModifyCol(6, Round(60 * d))
    Ui.lv.ModifyCol(7, Round(75 * d))
    Ui.btnDelSel := g.Add("Text", "x10 y320 w100 h26 0x200 0x100", "Delete selected")
    Ui.btnClear := g.Add("Text", "x120 y320 w90 h26 0x200 0x100", "Clear history")
    Ui.lblBest := g.Add("Text", "x266 y324 w300 h20 0x200", "")
    Ui.lblStatus := g.Add("Text", "x10 y640 w600 h20 0x200 0x4000", "")

    ; ---- right: inspector ----
    Ui.heads.Push(AddI("Text", 0, 6, 250, 18, "", "Test duration"))
    Ui.ddDur := AddI("DropDownList", 0, 24, 250, 0, "R9 Choose2", ["30 seconds", "1 minute", "2 minutes", "3 minutes", "5 minutes", "10 minutes", "15 minutes", "No timer (stopwatch)"])
    Ui.btnNew := AddI("Button", 0, 54, 120, 28, "", "Next  (F5)")
    Ui.btnRestart := AddI("Button", 126, 54, 124, 28, "", "Restart same  (F6)")
    Ui.heads.Push(AddI("Text", 0, 92, 250, 18, "", "Text file"))
    Ui.ddFile := AddI("DropDownList", 0, 110, 152, 0, "R15", St.files)
    Ui.btnReload := AddI("Button", 158, 109, 92, 26, "", "Reload files")
    Ui.heads.Push(AddI("Text", 0, 142, 250, 18, "", "Paragraph"))
    Ui.ddPara := AddI("DropDownList", 0, 160, 250, 0, "R15 Choose1", ["Random paragraph"])
    Ui.heads.Push(AddI("Text", 0, 192, 122, 18, "", "Punctuation"))
    Ui.heads.Push(AddI("Text", 128, 192, 122, 18, "", "Numbers"))
    Ui.ddPunct := AddI("DropDownList", 0, 210, 122, 0, "R4 Choose1", ["As in the text", "Basic marks only", "No punctuation", "Rich punctuation"])
    Ui.ddNum := AddI("DropDownList", 128, 210, 122, 0, "R3 Choose1", ["As in the text", "No numbers", "With numbers"])
    Ui.heads.Push(AddI("Text", 0, 242, 250, 18, "", "File encoding"))
    Ui.ddEnc := AddI("DropDownList", 0, 260, 250, 0, "R6 Choose1", ["Auto detect", "UTF-8", "UTF-16", "ANSI (Windows-1252)", "ANSI (system default)"])
    Ui.heads.Push(AddI("Text", 0, 292, 250, 18, "", "Font and size"))
    Ui.cbFont := AddI("ComboBox", 0, 310, 176, 0, "R15", Ui.fontList)
    Ui.ddSize := AddI("DropDownList", 182, 310, 68, 0, "R14 Choose4", Ui.sizes)
    Ui.heads.Push(AddI("Text", 0, 342, 122, 18, "", "Text direction"))
    Ui.heads.Push(AddI("Text", 128, 342, 122, 18, "", "Count words by"))
    Ui.ddDir := AddI("DropDownList", 0, 360, 122, 0, "R4 Choose1", ["Auto", "Left to right", "Right to left"])
    Ui.ddWpm := AddI("DropDownList", 128, 360, 122, 0, "R4 Choose1", ["Standard (5 chars)", "Real words"])
    Ui.heads.Push(AddI("Text", 0, 392, 250, 18, "", "When a paragraph is finished early"))
    Ui.ddFin := AddI("DropDownList", 0, 410, 250, 0, "R6 Choose1", ["Load the next paragraph", "Repeat the same paragraph", "Show the result now", "Restart the test (same paragraph)", "Ask me every time"])
    Ui.heads.Push(AddI("Text", 0, 442, 250, 18, "", "Theme"))
    Ui.ddTheme := AddI("DropDownList", 0, 460, 250, 0, "R10 Choose1", Th.names)
    Ui.btnAddTxt := AddI("Button", 0, 498, 122, 28, "", "Add text...")
    Ui.btnEditTxt := AddI("Button", 128, 498, 122, 28, "", "Edit text...")

    ; groups shown / hidden by the tab labels
    rg := [Ui.rPic, Ui.rBtnNext, Ui.rBtnAgain]
    Ui.grp := [[Ui.lblTimer, Ui.lblWpm, Ui.lblAcc, Ui.lblWords, Ui.lblCaps, Ui.rich, Ui.split, Ui.edIn], rg, [Ui.lv, Ui.btnDelSel, Ui.btnClear, Ui.lblBest]]

    ; controls that get the dark / light control theme
    for c in [Ui.ddDur, Ui.ddFile, Ui.ddPara, Ui.ddPunct, Ui.ddNum, Ui.ddEnc, Ui.ddSize, Ui.ddDir, Ui.ddWpm, Ui.ddFin, Ui.ddTheme]
        Ui.themed.Push([c, "combo"])
    Ui.themed.Push([Ui.cbFont, "cbox"])
    Ui.links := [Ui.btnPanel, Ui.lnkSettings, Ui.btnHelp, Ui.btnDelSel, Ui.btnClear]
    for c in [Ui.btnReload, Ui.btnNew, Ui.btnRestart, Ui.btnAddTxt, Ui.btnEditTxt, Ui.rBtnNext, Ui.rBtnAgain]
        Ui.themed.Push([c, "btn"])
    Ui.themed.Push([Ui.edIn, "edit"])
    Ui.themed.Push([Ui.lv, "list"])
    Ui.themed.Push([Ui.rich, "list"])

    ; events
    Ui.edIn.OnEvent("Change", OnType)
    Ui.btnReload.OnEvent("Click", (*) => ReloadList())
    Ui.btnNew.OnEvent("Click", (*) => PrepareTest(false))
    Ui.btnRestart.OnEvent("Click", (*) => PrepareTest(true))
    Ui.rBtnNext.OnEvent("Click", (*) => PrepareTest(false))
    Ui.rBtnAgain.OnEvent("Click", (*) => PrepareTest(true))
    Ui.btnPanel.OnEvent("Click", TogglePanel)
    Ui.btnClear.OnEvent("Click", ClearHistory)
    Ui.btnDelSel.OnEvent("Click", DeleteSelectedHistory)
    Ui.btnAddTxt.OnEvent("Click", OpenAddText)
    Ui.btnEditTxt.OnEvent("Click", OpenEditText)
    Ui.btnHelp.OnEvent("Click", OpenHelp)
    Ui.lnkSettings.OnEvent("Click", OpenSettings)
    Ui.ddPunct.OnEvent("Change", OnTextMode)
    Ui.ddNum.OnEvent("Change", OnTextMode)
    Ui.ddDur.OnEvent("Change", OnDur)
    Ui.ddFile.OnEvent("Change", OnFile)
    Ui.ddPara.OnEvent("Change", OnPara)
    Ui.ddEnc.OnEvent("Change", OnEnc)
    Ui.ddFin.OnEvent("Change", OnFin)
    Ui.cbFont.OnEvent("Change", FontChanged)
    Ui.cbFont.OnEvent("LoseFocus", FontChanged)
    Ui.ddSize.OnEvent("Change", FontChanged)
    Ui.ddDir.OnEvent("Change", OnDir)
    Ui.ddWpm.OnEvent("Change", OnWpm)
    Ui.ddTheme.OnEvent("Change", OnTheme)
    g.OnEvent("Size", OnSize)
    g.OnEvent("DropFiles", OnDrop)
    g.OnEvent("Close", (*) => ExitApp())
}

; adds a control to the right-hand inspector (positions are in design units, Layout() scales them)
AddI(type, x, y, w, h, opts, content := "") {
    o := "x" . (700 + x) . " y" . y . " w" . w
    if (h > 0)
        o .= " h" . h
    c := Ui.g.Add(type, o . " " . opts, content)
    Ui.insp.Push([c, x, y, w, h])
    return c
}

OnSize(g, minMax, w, h) {
    if (minMax = -1)
        return
    St.cw := w
    St.ch := h
    Layout()
}

UpdatePanelBtn() {
    Ui.btnPanel.Text := St.hideInsp ? "Show panel" : "Hide panel"
}

TogglePanel(*) {
    St.hideInsp := !St.hideInsp
    IniPut("Settings", "HidePanel", St.hideInsp ? "1" : "0")
    UpdatePanelBtn()
    Layout()
    FocusInput()
}

Layout() {
    w := St.cw
    h := St.ch
    if (w < 100 || h < 100)
        return
    d := Dz()
    m := Round(10 * d)
    pw := Round(250 * d)
    showI := !St.hideInsp
    if showI {
        px := w - m - pw
        lw := Max(Round(200 * d), px - m - Round(6 * d))
    } else {
        px := w
        lw := Max(Round(200 * d), w - 2 * m)
    }
    St.px := showI ? px : 99999

    ; inspector (hidden completely when the panel is switched off). When the window is too
    ; short for all the rows, the mouse wheel over the panel scrolls it.
    if (showI != St.inspShown) {
        St.inspShown := showI
        if !showI {
            for r in Ui.insp
                r[1].Visible := false
        }
    }
    if showI {
        St.inspMax := Max(0, Ceil(Ui.inspH - (h / d - 6)))
        if (St.inspOff > St.inspMax)
            St.inspOff := St.inspMax
        for r in Ui.insp {
            yy := r[3] - St.inspOff
            hh := (r[5] > 0) ? r[5] : 24
            if (yy < 0 || (yy + hh) * d > h - Round(4 * d)) {
                r[1].Visible := false
                continue
            }
            if (r[5] > 0)
                r[1].Move(px + Round(r[2] * d), Round(yy * d), Round(r[4] * d), Round(r[5] * d))
            else
                r[1].Move(px + Round(r[2] * d), Round(yy * d), Round(r[4] * d))
            r[1].Visible := true
        }
    }

    ; tab labels, header links, status line
    m0 := Round(4 * d)
    tabH := Round(28 * d)                                ; the tab and the bar under it
    tw := Round(78 * d)                                  ; Test / Results / History sit close together
    barH := Max(2, Round(3 * d))
    for i, c in Ui.tabs
        c.Move(m + (i - 1) * tw, m0, tw, tabH - barH)
    Ui.tabLine.Move(m, m0 + tabH, lw, Max(1, Round(d)))
    PlaceTabBar()                                        ; the bar goes under the picked tab
    bwP := Round(72 * d)                                 ; Hide panel
    bwS := Round(54 * d)                                 ; Settings
    bwH := Round(32 * d)                                 ; Info
    gp := Round(2 * d)                                   ; Info and Settings sit close to Hide panel
    ly := m0 + Round(1 * d)
    lh := Round(20 * d)
    Ui.btnPanel.Move(m + lw - bwP, ly, bwP, lh)
    Ui.lnkSettings.Move(m + lw - bwP - bwS - gp, ly, bwS, lh)
    Ui.btnHelp.Move(m + lw - bwP - bwS - bwH - 2 * gp, ly, bwH, lh)
    top := m0 + tabH + Round(4 * d)
    stH := Round(24 * d)
    stY := h - m - stH
    Ui.lblStatus.Move(m, stY, w - 2 * m, stH)
    areaH := stY - top - Round(6 * d)

    ; Test page: timer row, the text, a bar you can drag, the typing box (30 % of the window height at first)
    tmH := Round(32 * d)
    colW := Max(Round(60 * d), lw // 4)                  ; four equal columns across the whole width, each text centred
    Ui.lblTimer.Move(m, top, colW, tmH)
    Ui.lblWpm.Move(m + colW, top, colW, tmH)
    Ui.lblAcc.Move(m + 2 * colW, top, colW, tmH)
    Ui.lblWords.Move(m + 3 * colW, top, colW, tmH)
    Ui.lblCaps.Move(m + 3 * tw + Round(10 * d), m0, Max(Round(60 * d), lw - 3 * tw - bwP - bwS - bwH - 3 * gp - Round(20 * d)), tabH)
    ry := top + tmH + Round(8 * d)
    H2 := areaH - tmH - Round(8 * d)
    spH := Round(10 * d)
    minRich := Round(60 * d)
    minIn := Round(Max(32, Ui.fsize * 2.1) * d / Ui.zoom)
    inH := Round(St.inFrac * h)
    inH := Max(minIn, Min(inH, H2 - minRich - spH))
    rH := Max(minRich, H2 - inH - spH)
    St.splitTop := ry
    St.splitH := H2
    St.spH := spH
    Ui.rich.Move(m, ry, lw, rH)
    Ui.split.Move(m, ry + rH, lw, spH)
    Ui.edIn.Move(m, ry + rH + spH, lw, inH)

    ; Results page: one picture (drawn with GDI+) and the two buttons
    hB := Round(32 * d)
    yB := top + areaH - hB
    gb := Round(6 * d)
    picH := Max(Round(120 * d), yB - top - Round(8 * d))
    Ui.rPic.Move(m, top, lw, picH)
    if (lw != Ui.rW || picH != Ui.rH) {
        Ui.rW := lw
        Ui.rH := picH
        DrawResults()
    }
    bwN := Round((lw - gb) * 0.4)
    Ui.rBtnNext.Move(m, yB, bwN, hB)
    Ui.rBtnAgain.Move(m + bwN + gb, yB, lw - gb - bwN, hB)

    ; History
    bh := Round(28 * d)
    Ui.lv.Move(m, top, lw, areaH - bh - Round(6 * d))
    Ui.btnDelSel.Move(m, top + areaH - bh, Round(124 * d), bh)
    Ui.btnClear.Move(m + Round(134 * d), top + areaH - bh, Round(108 * d), bh)
    Ui.lblBest.Move(m + Round(256 * d), top + areaH - bh + Round(5 * d), Max(Round(50 * d), lw - Round(256 * d)), Round(24 * d))
}

; ----- the bar between the text and the typing box can be dragged -----
WmLDown(wParam, lParam, msg, hwnd) {
    if (IsObject(Ui.split) && hwnd = Ui.split.Hwnd && St.tab = 1) {
        St.drag := true
        DllCall("SetCapture", "Ptr", hwnd)
    }
}

WmMove(wParam, lParam, msg, hwnd) {
    if !St.drag
        return
    if !(wParam & 1) {
        WmLUp(0, 0, 0, 0)
        return
    }
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    DllCall("ScreenToClient", "Ptr", Ui.g.Hwnd, "Ptr", pt)
    y := NumGet(pt, 4, "Int")
    inH := (St.splitTop + St.splitH) - y - Round(St.spH / 2)
    fr := Max(0.10, Min(0.65, inH / St.ch))
    if (Abs(fr - St.inFrac) < 0.002)
        return
    St.inFrac := fr
    Layout()
}

WmLUp(wParam, lParam, msg, hwnd) {
    if !St.drag
        return
    St.drag := false
    DllCall("ReleaseCapture")
    IniPut("Settings", "InFrac", Format("{:.3f}", St.inFrac))
    FocusInput()
}

; mouse wheel: over the right panel it scrolls the panel (when the window is short), over the typing box it
; scrolls the box; Ctrl + wheel over the typing box makes the text bigger / smaller
WmWheel(wParam, lParam, msg, hwnd) {
    if (!IsObject(Ui.g) || !IsObject(Ui.edIn))
        return
    delta := (wParam >> 16) & 0xFFFF
    if (delta > 32767)
        delta -= 65536
    if (delta = 0)
        return
    mx := 0
    win := 0
    ctl := 0
    try {
        MouseGetPos(&mx, , &win, &ctl, 2)
    } catch
        return
    if (win = Ui.g.Hwnd && St.inspMax > 0 && !St.hideInsp && mx >= St.px) {
        St.inspOff := Max(0, Min(St.inspMax, St.inspOff + (delta > 0 ? -56 : 56)))
        Layout()
        return 0
    }
    if (St.tab != 1 || ctl != Ui.edIn.Hwnd)
        return
    if (wParam & 0x8) {                      ; Ctrl held: zoom
        TextZoom(delta > 0 ? 1 : -1)
    } else {                                 ; plain wheel: scroll the box
        SendMessage(0x00B6, 0, (delta > 0 ? -3 : 3), Ui.edIn.Hwnd)      ; EM_LINESCROLL
    }
    return 0
}

WmSetCursor(wParam, lParam, msg, hwnd) {
    try {
        if (IsObject(Hw.link) && wParam = Hw.link.Hwnd) {
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"))
            return 1
        }
    }
    for c in Ui.links {
        if (wParam = c.Hwnd) {
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"))
            return 1
        }
    }
    if (IsObject(Ui.split) && wParam = Ui.split.Hwnd) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32645, "Ptr"))
        return 1
    }
}

TabClick(k, *) {
    ShowTab(k)
}

ShowTab(k) {
    St.tab := k
    for i, grp in Ui.grp {
        for c in grp
            c.Visible := (i = k)
    }
    SetTabs()
    FocusInput()
}

StyleLinks() {
    if !IsObject(Th.cur)
        return
    for c in Ui.links
        c.SetFont("s" . Fp(9) . " norm underline c" . Hx(Th.cur.accent), "Segoe UI")
    try Ui.btnClear.SetFont("s" . Fp(9) . " norm underline c" . Hx(Th.cur.bad), "Segoe UI")
}

; moves the bar under the picked tab (only the position; the colours are set in SetTabs)
PlaceTabBar() {
    try {
        Ui.tabs[St.tab].GetPos(&x, &y, &w, &h)
        Ui.tabBar.Move(x, y + h, w, Max(2, Round(3 * Dz())))
    }
}

; the picked tab is a filled block (the panel colour) with bold accent text and an accent bar under it; the others are
; flat, slightly tinted and muted - the same idea as the tab strip of the Help & Guide window of Bangla Snippet
SetTabs() {
    if !IsObject(Th.cur)
        return
    t := Th.cur
    for i, c in Ui.tabs {
        if (i = St.tab) {
            c.Opt("+Background" . Hx(t.panel))
            c.SetFont("s" . Fp(10) . " w700 c" . Hx(t.accent), "Segoe UI")
            try {
                Ui.tabBar.Opt("+Background" . Hx(t.accent))
                PlaceTabBar()
                Ui.tabBar.Redraw()
            }
        } else {
            c.Opt("+Background" . Hx(Mix(t.bg, t.text, 0.07)))
            c.SetFont("s" . Fp(10) . " norm c" . Hx(Mix(t.muted, t.text, 0.15)), "Segoe UI")
        }
        c.Redraw()
    }
    try {
        Ui.tabLine.Opt("+Background" . Hx(Mix(t.bg, t.muted, 0.30)))
        Ui.tabLine.Redraw()
    }
}

; ---------------------------------------------------------------------------
;  Themes and fonts
; ---------------------------------------------------------------------------
SetCtlTheme(c, kind, dark) {
    if (kind = "cbox") {
        ThemeCbox(c, dark)
        return
    }
    try {
        if !dark {
            DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Ptr", 0, "Ptr", 0)
        } else if (kind = "combo") {
            DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_CFD", "Str", "ComboBox")
        } else if (kind = "edit") {
            DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
        } else {
            DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        }
    }
}

; An editable combo box (the font box, the size boxes of the text windows) is made of three
; windows: the box, the edit field inside it and the drop-down list. All three get the theme.
ThemeCbox(c, dark) {
    t := Th.cur
    hE := 0
    hL := 0
    try {
        sz := (A_PtrSize = 8) ? 64 : 52
        cbi := Buffer(sz, 0)
        NumPut("UInt", sz, cbi, 0)
        if DllCall("GetComboBoxInfo", "Ptr", c.Hwnd, "Ptr", cbi) {
            hE := NumGet(cbi, (A_PtrSize = 8) ? 48 : 44, "Ptr")
            hL := NumGet(cbi, (A_PtrSize = 8) ? 56 : 48, "Ptr")
        }
    }
    try {
        if dark {
            DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_CFD", "Str", "ComboBox")
            if hE
                DllCall("uxtheme\SetWindowTheme", "Ptr", hE, "Str", "DarkMode_CFD", "Ptr", 0)
            if hL
                DllCall("uxtheme\SetWindowTheme", "Ptr", hL, "Str", "DarkMode_Explorer", "Ptr", 0)
        } else {
            DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Ptr", 0, "Ptr", 0)
            if hE
                DllCall("uxtheme\SetWindowTheme", "Ptr", hE, "Ptr", 0, "Ptr", 0)
            if hL
                DllCall("uxtheme\SetWindowTheme", "Ptr", hL, "Ptr", 0, "Ptr", 0)
        }
    }
    try c.Opt("+Background" . Hx(t.panel))
    try c.SetFont("s" . Fp(9) . " norm c" . Hx(t.text), "Segoe UI")
}

ApplyTheme(name) {
    if !Th.all.Has(name)
        name := "Dark"
    t := Th.all[name]
    Th.cur := t
    Th.cname := name
    g := Ui.g
    g.BackColor := Hx(t.bg)
    try {
        v := Buffer(4, 0)
        NumPut("Int", t.dark ? 1 : 0, v)
        if (DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 20, "Ptr", v, "Int", 4) != 0)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 19, "Ptr", v, "Int", 4)
    }
    for c in Ui.heads
        c.SetFont("s" . Fp(9) . " w700 c" . Hx(Mix(t.muted, t.text, 0.4)), "Segoe UI")
    Ui.lblTimer.SetFont("s" . Fp(16) . " w700 c" . Hx(t.accent), "Segoe UI")
    for c in [Ui.lblWpm, Ui.lblAcc, Ui.lblWords]
        c.SetFont("s" . Fp(13) . " norm c" . Hx(t.text), "Segoe UI")
    Ui.lblCaps.SetFont("s" . Fp(10) . " w700 c" . Hx(t.bad), "Segoe UI")
    Ui.lblStatus.SetFont("s" . Fp(9) . " norm c" . Hx(Mix(t.muted, t.text, 0.35)), "Segoe UI")
    Ui.lblBest.SetFont("s" . Fp(10) . " norm c" . Hx(t.text), "Segoe UI")
    try Ui.edIn.Opt("+Background" . Hx(t.panel))
    try Ui.split.Opt("+Background" . Hx(Mix(t.bg, t.muted, 0.30)))
    Ui.split.SetFont("s" . Fp(9) . " w700 c" . Hx(t.muted), "Segoe UI")
    try {
        SendMessage(0x1001, 0, Bgr(t.panel), Ui.lv.Hwnd)     ; LVM_SETBKCOLOR
        SendMessage(0x1026, 0, Bgr(t.panel), Ui.lv.Hwnd)     ; LVM_SETTEXTBKCOLOR
        SendMessage(0x1024, 0, Bgr(t.text), Ui.lv.Hwnd)      ; LVM_SETTEXTCOLOR
    }
    for pair in Ui.themed
        SetCtlTheme(pair[1], pair[2], t.dark)
    SetTabs()
    StyleLinks()
    StyleResults()
    ApplyFont()
    try DllCall("RedrawWindow", "Ptr", g.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
}

; ---------------------------------------------------------------------------
;  Results page: cards, bar and tip, drawn with ordinary controls
; ---------------------------------------------------------------------------
StyleResults() {
    DrawResults()
}

RenderResults() {
    DrawResults()
}

; ---- GDI+ helpers (the result page is drawn as one picture) ----
GdipStart() {
    static tok := 0
    if tok
        return
    DllCall("LoadLibrary", "Str", "gdiplus")
    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, si, 0)
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok, "Ptr", si, "Ptr", 0)
}

Col(c, a := 255) => (a << 24) | c

GBrush(argb) {
    b := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &b)
    return b
}

GPen(argb, w) {
    p := 0
    DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", w, "Int", 2, "Ptr*", &p)
    DllCall("gdiplus\GdipSetPenStartCap", "Ptr", p, "Int", 2)
    DllCall("gdiplus\GdipSetPenEndCap", "Ptr", p, "Int", 2)
    return p
}

GFillEll(G, argb, x, y, w, h) {
    b := GBrush(argb)
    DllCall("gdiplus\GdipFillEllipse", "Ptr", G, "Ptr", b, "Float", x, "Float", y, "Float", w, "Float", h)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
}

GArc(G, argb, pw, x, y, w, h, st, sw) {
    p := GPen(argb, pw)
    DllCall("gdiplus\GdipDrawArc", "Ptr", G, "Ptr", p, "Float", x, "Float", y, "Float", w, "Float", h, "Float", st, "Float", sw)
    DllCall("gdiplus\GdipDeletePen", "Ptr", p)
}

GLine(G, argb, pw, x1, y1, x2, y2) {
    p := GPen(argb, pw)
    DllCall("gdiplus\GdipDrawLine", "Ptr", G, "Ptr", p, "Float", x1, "Float", y1, "Float", x2, "Float", y2)
    DllCall("gdiplus\GdipDeletePen", "Ptr", p)
}

GPoly(G, argb, pts) {
    buf := Buffer(pts.Length * 8, 0)
    for i, q in pts {
        NumPut("Float", q[1], buf, (i - 1) * 8)
        NumPut("Float", q[2], buf, (i - 1) * 8 + 4)
    }
    b := GBrush(argb)
    DllCall("gdiplus\GdipFillPolygon", "Ptr", G, "Ptr", b, "Ptr", buf, "Int", pts.Length, "Int", 0)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
}

; rounded rectangle: fill (fillArgb = 0 for none) and / or outline (penArgb = 0 for none)
GRRect(G, fillArgb, penArgb, pw, x, y, w, h, r) {
    path := 0
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path)
    dd := r * 2
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y, "Float", dd, "Float", dd, "Float", 180, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - dd, "Float", y, "Float", dd, "Float", dd, "Float", 270, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - dd, "Float", y + h - dd, "Float", dd, "Float", dd, "Float", 0, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y + h - dd, "Float", dd, "Float", dd, "Float", 90, "Float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
    if fillArgb {
        b := GBrush(fillArgb)
        DllCall("gdiplus\GdipFillPath", "Ptr", G, "Ptr", b, "Ptr", path)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
    }
    if penArgb {
        p := GPen(penArgb, pw)
        DllCall("gdiplus\GdipDrawPath", "Ptr", G, "Ptr", p, "Ptr", path)
        DllCall("gdiplus\GdipDeletePen", "Ptr", p)
    }
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
}

; align / valign: 0 = near, 1 = centre, 2 = far
GText(G, text, argb, px, bold, x, y, w, h, align := 1, valign := 1, wrap := false) {
    fam := 0
    font := 0
    fmt := 0
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam)
    DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", px, "Int", bold ? 1 : 0, "Int", 2, "Ptr*", &font)
    DllCall("gdiplus\GdipCreateStringFormat", "Int", wrap ? 0 : 0x1000, "Int", 0, "Ptr*", &fmt)
    DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", align)
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", valign)
    rc := Buffer(16, 0)
    NumPut("Float", x, "Float", y, "Float", w, "Float", h, rc)
    b := GBrush(argb)
    DllCall("gdiplus\GdipDrawString", "Ptr", G, "WStr", text, "Int", -1, "Ptr", font, "Ptr", rc, "Ptr", fmt, "Ptr", b)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
    DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
    DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
    DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam)
}

GTextW(G, text, px, bold) {
    fam := 0
    font := 0
    fmt := 0
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam)
    DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", px, "Int", bold ? 1 : 0, "Int", 2, "Ptr*", &font)
    DllCall("gdiplus\GdipCreateStringFormat", "Int", 0x1000, "Int", 0, "Ptr*", &fmt)
    rc := Buffer(16, 0)
    NumPut("Float", 0, "Float", 0, "Float", 3000, "Float", 300, rc)
    bound := Buffer(16, 0)
    DllCall("gdiplus\GdipMeasureString", "Ptr", G, "WStr", text, "Int", -1, "Ptr", font, "Ptr", rc, "Ptr", fmt, "Ptr", bound, "Ptr", 0, "Ptr", 0)
    w := NumGet(bound, 8, "Float")
    DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
    DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
    DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam)
    return w
}

; small icons, centred on (cx, cy); u = size unit
GIcon(G, kind, cx, cy, u, t) {
    if (kind = "bolt") {
        GPoly(G, Col(t.accent), [[cx + 0.25 * u, cy - u], [cx - 0.65 * u, cy + 0.15 * u], [cx - 0.05 * u, cy + 0.15 * u], [cx - 0.3 * u, cy + u], [cx + 0.65 * u, cy - 0.25 * u], [cx + 0.05 * u, cy - 0.25 * u]])
    } else if (kind = "x") {
        GLine(G, Col(t.bad), 0.28 * u, cx - 0.65 * u, cy - 0.65 * u, cx + 0.65 * u, cy + 0.65 * u)
        GLine(G, Col(t.bad), 0.28 * u, cx - 0.65 * u, cy + 0.65 * u, cx + 0.65 * u, cy - 0.65 * u)
    } else if (kind = "kb") {
        GRRect(G, 0, Col(t.accent), 0.2 * u, cx - u, cy - 0.65 * u, 2 * u, 1.3 * u, 0.28 * u)
        for k in [-0.5, 0, 0.5]
            GFillEll(G, Col(t.accent), cx + k * u - 0.12 * u, cy - 0.3 * u - 0.12 * u, 0.24 * u, 0.24 * u)
        GLine(G, Col(t.accent), 0.2 * u, cx - 0.5 * u, cy + 0.28 * u, cx + 0.5 * u, cy + 0.28 * u)
    } else if (kind = "clock") {
        GArc(G, Col(t.accent), 0.2 * u, cx - 0.9 * u, cy - 0.9 * u, 1.8 * u, 1.8 * u, 0, 360)
        GLine(G, Col(t.accent), 0.2 * u, cx, cy, cx, cy - 0.55 * u)
        GLine(G, Col(t.accent), 0.2 * u, cx, cy, cx + 0.42 * u, cy + 0.2 * u)
    }
}

DrawResults() {
    if (!IsObject(Th.cur) || !IsObject(Ui.rPic) || Ui.rW < 60 || Ui.rH < 60)
        return
    GdipStart()
    t := Th.cur
    W := Ui.rW
    H := Ui.rH
    d := Dz()
    sc := Max(0.8, Min(1.6, Min(W / (700 * d), H / (440 * d)))) * d
    mut := Mix(t.muted, t.text, 0.45)               ; secondary text: still easy to read
    bmp := 0
    G := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &G)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", G, "Int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", G, "Int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", G, "UInt", Col(t.bg))

    r := St.res
    ; header: check circle, title, text file and time
    title := "No result yet"
    sub := "Finish a test and your result will show here."
    if IsObject(r) {
        title := (r.dur = 0) ? "Practice complete" : (r.early ? "Finished early" : "Test complete")
        sub := r.file . "   ·   " . r.stamp
    }
    GText(G, title, Col(t.text), 30 * sc, true, 4 * sc, 0, W - 4 * sc, 38 * sc, 0, 1)
    GText(G, sub, Col(mut), 16 * sc, false, 4 * sc, 38 * sc, W - 4 * sc, 22 * sc, 0, 1)

    if IsObject(r) {
        ac := (r.acc >= 97) ? t.ok : ((r.acc >= 90) ? t.accent : t.bad)
        rating := (r.acc >= 97) ? "Excellent" : ((r.acc >= 90) ? "Good" : "Slow down a little")
        cWords := t.dark ? 0xC4A1FF : 0x7E22CE        ; a strong colour, so the ring looks as alive as the other two
        wTarget := (r.dur = 0) ? Max(1, r.words) : Max(15, 40 * (r.dur / 60))
        vals := [Format("{:.1f}", r.wpm), Format("{:.1f}%", r.acc), String(r.words)]
        frs := [Min(1, r.wpm / 80), Min(1, r.acc / 100), Min(1, r.words / wTarget)]
        cols := [t.accent, ac, cWords]
        labs := ["NET SPEED`n(WPM)", "ACCURACY", "CORRECT WORDS"]
        caps := ["counted by " . r.basis, rating, r.paras . ((r.paras = 1) ? " paragraph" : " paragraphs") . " finished"]
        top := 72 * sc
        D := 136 * sc
        pw := 12 * sc
        colW := W / 3
        ry := top + 46 * sc
        Loop 3 {
            i := A_Index
            cx := colW * (i - 0.5)
            GText(G, labs[i], Col(t.text), 15 * sc, true, colW * (i - 1), top, colW, 42 * sc, 1, 1)
            GArc(G, Col(cols[i], 0x55), pw, cx - D / 2 + pw / 2, ry + pw / 2, D - pw, D - pw, 0, 360)
            if (frs[i] > 0.005)
                GArc(G, Col(cols[i]), pw, cx - D / 2 + pw / 2, ry + pw / 2, D - pw, D - pw, -90, 359.9 * frs[i])
            GText(G, vals[i], Col(cols[i]), 38 * sc, true, cx - D / 2, ry, D, D, 1, 1)
            GText(G, caps[i], Col((i = 2) ? ac : mut), 14 * sc, (i = 2), colW * (i - 1) + 6 * sc, ry + D + 8 * sc, colW - 12 * sc, 40 * sc, 1, 0, true)
        }
        yDiv := ry + D + 52 * sc
        GLine(G, Col(t.muted, 0x70), 1, 4 * sc, yDiv, W - 4 * sc, yDiv)

        ; one line with the other numbers
        yc := yDiv + 28 * sc
        items := [["bolt", Format("Raw {:.1f} WPM", r.raw)]
            , ["x", r.errs . ((r.errs = 1) ? " mistake" : " mistakes")]
            , ["kb", r.ok . " / " . r.typed . " characters"]
            , ["clock", r.timeTxt]]
        c4 := W / 4
        Loop 4 {
            i := A_Index
            tw := GTextW(G, items[i][2], 15 * sc, false)
            iw := 22 * sc
            x0 := c4 * (i - 0.5) - (iw + 8 * sc + tw) / 2
            GIcon(G, items[i][1], x0 + iw / 2, yc, 10 * sc, t)
            GText(G, items[i][2], Col(t.text), 15 * sc, false, x0 + iw + 8 * sc, yc - 14 * sc, tw + 14 * sc, 28 * sc, 0, 1)
            if (i < 4)
                GLine(G, Col(t.muted, 0x70), 1, c4 * i, yc - 12 * sc, c4 * i, yc + 12 * sc)
        }

        ; the tip
        tip := ""
        if (r.dur = 0)
            tip := "You took " . r.timeTxt . " for this paragraph. Try to beat your time next round.  "
        else if r.early
            tip := "You finished before the time ended.  "
        if (r.acc < 90)
            tip .= "Tip: slow down. Aim for at least 95% accuracy first; speed comes by itself later."
        else if (r.acc < 97)
            tip .= "Good. Keep your accuracy above 97% and push the speed up a little."
        else
            tip .= "Excellent accuracy! Try a longer test or a slightly faster pace."
        yP := yc + 30 * sc
        hP := Min(Max(52 * sc, H - yP - 2 * sc), 74 * sc)
        GRRect(G, Col(Mix(t.bg, t.accent, 0.14)), 0, 0, 4 * sc, yP, W - 8 * sc, hP, 12 * sc)
        bx := 28 * sc
        by := yP + hP / 2
        GFillEll(G, Col(0xF5B83D), bx - 8 * sc, by - 12 * sc, 16 * sc, 16 * sc)
        GLine(G, Col(0xF5B83D), 2.5 * sc, bx - 4 * sc, by + 7 * sc, bx + 4 * sc, by + 7 * sc)
        GLine(G, Col(0xF5B83D), 2.5 * sc, bx - 3 * sc, by + 11 * sc, bx + 3 * sc, by + 11 * sc)
        GText(G, tip, Col(t.text), 16 * sc, false, 52 * sc, yP, W - 52 * sc - 16 * sc, hP, 0, 1, true)
    }

    hbm := 0
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bmp, "Ptr*", &hbm, "UInt", Col(t.bg))
    old := SendMessage(0x172, 0, hbm, Ui.rPic.Hwnd)         ; STM_SETIMAGE, IMAGE_BITMAP
    if old
        DllCall("DeleteObject", "Ptr", old)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", G)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
    Ui.rPic.Visible := (St.tab = 2)                          ; setting the image can show a hidden picture: keep it on its own tab
}

ApplyFont() {
    face := Trim(Ui.cbFont.Text)
    if (face = "")
        face := "Segoe UI"
    sz := Ui.ddSize.Text
    sz := IsInteger(sz) ? Integer(sz) : 18
    Ui.face := face
    Ui.fsize := sz
    t := Th.cur
    Ui.edIn.SetFont("s" . sz . " norm c" . Hx(t.text), face)
    RefreshRich()
    Layout()
}

SetFontBox(face) {
    SendMessage(0x000C, 0, StrPtr(face), Ui.cbFont.Hwnd)      ; WM_SETTEXT on the combo box edit part
}

FontChanged(*) {
    if St.loading
        return
    SetTimer(FontApply, -250)       ; the drop-down text needs a moment to update
}

FontApply() {
    if St.loading
        return
    ApplyFont()
    SaveFileSettings()
}

; ---------------------------------------------------------------------------
;  Rich edit: the text on screen, coloured letter by letter
; ---------------------------------------------------------------------------
RichFmt(start0, end0, fg, bg) {
    cf := Buffer(116, 0)
    NumPut("UInt", 116, cf, 0)
    NumPut("UInt", 0x44000000, cf, 4)               ; CFM_COLOR | CFM_BACKCOLOR
    NumPut("UInt", Bgr(fg), cf, 20)
    NumPut("UInt", Bgr(bg), cf, 96)
    SendMessage(0x00B1, start0, end0, Ui.rich.Hwnd)  ; EM_SETSEL
    SendMessage(0x0444, 1, cf.Ptr, Ui.rich.Hwnd)     ; EM_SETCHARFORMAT, selection only
    SendMessage(0x00B1, start0, start0, Ui.rich.Hwnd)  ; no selection left over (it would show as a blue block)
}

; whole text: font, size and the colours of letters that are not typed yet; then the states again
RefreshRich() {
    if !IsObject(Th.cur)
        return
    t := Th.cur
    SendMessage(0x0443, 0, Bgr(t.panel), Ui.rich.Hwnd)     ; EM_SETBKGNDCOLOR
    cf := Buffer(116, 0)
    NumPut("UInt", 116, cf, 0)
    NumPut("UInt", 0xE4000001, cf, 4)               ; colour, back colour, face, size, bold (off)
    NumPut("UInt", 0, cf, 8)
    NumPut("Int", Ui.fsize * 20, cf, 12)            ; twips
    NumPut("UInt", Bgr(t.text), cf, 20)
    NumPut("UInt", Bgr(t.panel), cf, 96)
    StrPut(SubStr(Ui.face, 1, 31), cf.Ptr + 26, 32, "UTF-16")
    SendMessage(0x0444, 0, cf.Ptr, Ui.rich.Hwnd)    ; EM_SETCHARFORMAT, default
    SendMessage(0x0444, 4, cf.Ptr, Ui.rich.Hwnd)    ; EM_SETCHARFORMAT, all text
    SendMessage(0x00D3, 3, 12 | (12 << 16), Ui.rich.Hwnd)   ; EM_SETMARGINS: 12 px left and right
    for i, s in St.cst {
        if (s != 0)
            ApplyState(i, s)
    }
}

ApplyState(c, s) {
    t := Th.cur
    a := St.clu[c][1] - 1
    b := St.clu[c][2]
    if (s = 1)
        RichFmt(a, b, t.ok, t.panel)
    else if (s = 2)
        RichFmt(a, b, t.bad, t.badBg)
    else if (s = 3)
        RichFmt(a, b, t.curFg, t.curBg)
    else
        RichFmt(a, b, t.text, t.panel)
}

; Right-to-left (Arabic, Hebrew ...) for the paragraph on screen and the typing box
ApplyDirection() {
    dir := Ui.ddDir.Value
    rtl := false
    if (dir = 3) {
        rtl := true
    } else if (dir = 1 && St.tlen > 0) {
        try rtl := (RegExMatch(St.target, "[\x{0590}-\x{08FF}]") > 0)
    }
    try {
        pf := Buffer(188, 0)
        NumPut("UInt", 188, pf, 0)
        NumPut("UInt", 0x10108, pf, 4)                 ; PFM_RTLPARA | PFM_LINESPACING | PFM_ALIGNMENT
        NumPut("UShort", rtl ? 1 : 0, pf, 10)           ; PFE_RTLPARA
        NumPut("UShort", rtl ? 2 : 1, pf, 24)           ; PFA_RIGHT / PFA_LEFT
        NumPut("Int", 30, pf, 164)                      ; line spacing 1.5 lines
        NumPut("UChar", 5, pf, 170)                     ; spacing rule: in 1/20 lines
        SendMessage(0x00B1, 0, -1, Ui.rich.Hwnd)
        SendMessage(0x0447, 0, pf.Ptr, Ui.rich.Hwnd)    ; EM_SETPARAFORMAT
    }
    if (rtl != St.rtlIn) {
        St.rtlIn := rtl
        try {
            if rtl
                Ui.edIn.Opt("+E0x2000 +E0x1000")
            else
                Ui.edIn.Opt("-E0x2000 -E0x1000")
        }
    }
}

; ---------------------------------------------------------------------------
;  Letters, clusters, words
; ---------------------------------------------------------------------------
; Bangla and other scripts: a consonant with its signs (and a conjunct) must be coloured as one
; piece, otherwise the shape breaks. Every character belongs to a cluster.
IsCont(ch, prev) {
    o := Ord(ch)
    if (o < 0x300)
        return false
    if (o >= 0xDC00 && o <= 0xDFFF)
        return true
    if (o >= 0xD800 && o <= 0xDBFF)
        return false
    if (o = 0x200C || o = 0x200D)
        return true
    if InStr(K.vir, prev)
        return true
    try {
        return RegExMatch(ch, "^\p{M}$") ? true : false
    } catch {
        return false
    }
}

BuildClusters(s) {
    clu := []
    cOf := []
    len := StrLen(s)
    i := 1
    while (i <= len) {
        j := i
        while (j < len && IsCont(SubStr(s, j + 1, 1), SubStr(s, j, 1)))
            j += 1
        clu.Push([i, j])
        Loop j - i + 1
            cOf.Push(clu.Length)
        i := j + 1
    }
    St.clu := clu
    St.cOf := cOf
}

BuildWords(s) {
    words := []
    pos := 1
    len := StrLen(s)
    while (pos <= len && RegExMatch(s, "\S+", &mt, pos)) {
        words.Push([mt.Pos, mt.Pos + mt.Len - 1])
        pos := mt.Pos + mt.Len
    }
    return words
}

; Unicode normalisation (NFC / NFD). Bangla letters such as য় ড় ঢ় and vowel signs like ো can be stored in two ways
; (one precomposed character, or a letter plus a sign). Both the text and what is typed are brought to the same form
; before they are compared, so a correct letter is never shown as a mistake because of how the keyboard stores it.
NormStr(s, form) {
    if (s = "")
        return ""
    n := DllCall("Normaliz\NormalizeString", "Int", form, "WStr", s, "Int", -1, "Ptr", 0, "Int", 0, "Int")
    if (n <= 0)
        return s
    buf := Buffer(n * 2, 0)
    r := DllCall("Normaliz\NormalizeString", "Int", form, "WStr", s, "Int", -1, "Ptr", buf, "Int", n, "Int")
    if (r <= 0)
        return s
    return StrGet(buf, "UTF-16")
}

Nfc(s) => NormStr(s, 1)

Nfd(s) => NormStr(s, 2)

; what has been typed so far, in the same form as the text on screen (ANSI texts are left as they are)
TypedNow() {
    t := Ui.edIn.Value
    return TextIsAnsi() ? t : Nfc(t)
}

; true when the typed text ends in the middle of a letter that the text writes as one piece
; (for example the sign ে is typed first and া follows to make ো): that is not a mistake yet
Partial(T, n) {
    if (n < 1 || n > St.tlen)
        return false
    c := St.cOf[n]
    a := St.clu[c][1]
    seg := SubStr(T, a, n - a + 1)
    ref := SubStr(St.target, a, St.clu[c][2] - a + 1)
    ns := Nfd(seg)
    nr := Nfd(ref)
    return (StrLen(ns) <= StrLen(nr) && StrCompare(ns, SubStr(nr, 1, StrLen(ns)), "On") = 0)
}

; 0 not typed yet, 1 correct, 2 wrong, 3 current (next to type)
CluState(c, n, T) {
    a := St.clu[c][1]
    b := St.clu[c][2]
    if (a > n)
        return (a = n + 1) ? 3 : 0
    m := Min(n, b)
    seg := SubStr(T, a, m - a + 1)
    ref := SubStr(St.target, a, m - a + 1)
    if (StrCompare(seg, ref, "On") != 0)
        return (m = n && Partial(T, n)) ? 3 : 2
    return (n >= b) ? 1 : 3
}

RecolorRange(oldN, n, T) {
    tl := St.tlen
    if (tl < 1 || St.clu.Length = 0)
        return
    lo := Min(oldN, n)
    hi := Max(oldN, n) + 1
    c1 := St.cOf[Max(1, Min(lo, tl))]
    c2 := St.cOf[Max(1, Min(hi, tl))]
    c1 := Max(1, c1 - 1)
    c2 := Min(St.clu.Length, c2 + 1)
    c := c1
    while (c <= c2) {
        s := CluState(c, n, T)
        if (s != St.cst[c]) {
            St.cst[c] := s
            ApplyState(c, s)
        }
        c += 1
    }
}

; keeps the letter to type on the second line of the text: when the text is longer than the box the
; box scrolls by itself, so you never have to scroll and start again
ScrollToCurrent(n) {
    if (St.tlen < 1)
        return
    h := Ui.rich.Hwnd
    c := St.cOf[Max(1, Min(n + 1, St.tlen))]
    p := St.clu[c][1] - 1
    SendMessage(0x00B1, p, p, h)                    ; EM_SETSEL
    si := Buffer(28, 0)
    NumPut("UInt", 28, si, 0)
    NumPut("UInt", 0x17, si, 4)                     ; SIF_ALL
    if !DllCall("GetScrollInfo", "Ptr", h, "Int", 1, "Ptr", si)
        return
    if (NumGet(si, 12, "Int") - NumGet(si, 8, "Int") + 1 <= NumGet(si, 16, "UInt"))
        return                                      ; everything is visible: nothing to scroll
    cur := SendMessage(0x00C9, p, 0, h)             ; EM_LINEFROMCHAR
    first := SendMessage(0x00CE, 0, 0, h)           ; EM_GETFIRSTVISIBLELINE
    d := cur - first - 1
    if (d != 0)
        SendMessage(0x00B6, 0, d, h)                ; EM_LINESCROLL
}

CountOk(T) {
    n := Min(StrLen(T), St.tlen)
    ok := 0
    Loop n {
        if (Ord(SubStr(T, A_Index, 1)) = Ord(SubStr(St.target, A_Index, 1)))
            ok += 1
    }
    return ok
}

CountWords(T) {
    n := StrLen(T)
    c := 0
    for w in St.words {
        if (w[2] > n)
            break
        len := w[2] - w[1] + 1
        if (StrCompare(SubStr(T, w[1], len), SubStr(St.target, w[1], len), "On") = 0)
            c += 1
    }
    return c
}

; ---------------------------------------------------------------------------
;  The test
; ---------------------------------------------------------------------------
ClearTest() {
    St.target := ""
    St.tlen := 0
    St.clu := []
    St.cOf := []
    St.cst := []
    St.words := []
    St.cur := 0
    St.prevN := 0
    SendMessage(0x000C, 0, StrPtr(""), Ui.rich.Hwnd)
}

LoadParagraph(idx) {
    St.cur := idx
    St.used[idx] := 1
    s := St.paras[idx]
    if !TextIsAnsi()
        s := Nfc(s)
    St.target := s
    St.tlen := StrLen(s)
    BuildClusters(s)
    St.words := BuildWords(s)
    St.cst := []
    Loop St.clu.Length
        St.cst.Push(0)
    if (St.cst.Length > 0)
        St.cst[1] := 3
    St.prevN := 0
    SendMessage(0x000C, 0, StrPtr(s), Ui.rich.Hwnd)         ; WM_SETTEXT
    ApplyDirection()
    RefreshRich()
    SendMessage(0x00B1, 0, 0, Ui.rich.Hwnd)
    SendMessage(0x00B7, 0, 0, Ui.rich.Hwnd)
}

NextIndex() {
    cnt := St.paras.Length
    if (cnt <= 1)
        return 1
    if St.fixed
        return (St.cur >= cnt) ? 1 : St.cur + 1
    if (St.used.Count >= cnt - 1)
        St.used := Map()
    r := St.cur
    Loop 100 {
        r := Random(1, cnt)
        if (r != St.cur && !St.used.Has(r))
            break
    }
    return r
}

PrepareTest(same := false) {
    SetTimer(Tick, 0)
    St.state := "idle"
    cnt := St.paras.Length
    if (cnt = 0) {
        ClearTest()
        St.busy := true
        Ui.edIn.Value := ""
        St.busy := false
        Ui.edIn.Enabled := false
        Ui.lblTimer.Text := FmtClock(St.dur)
        ShowStats(0, 100, 0)
        if (St.raw.Length = 0)
            SetStatus("This file has no text. Put paragraphs in it, separated by a blank line.")
        else
            SetStatus("No paragraph in this file matches the Punctuation / Numbers options. Choose 'As in the text' to see all paragraphs.")
        return
    }
    di := Ui.ddDur.Value
    if (di < 1 || di > 8)
        di := 2
    St.dur := [30, 60, 120, 180, 300, 600, 900, 0][di]      ; 0 = "No timer": a stopwatch
    St.keys := 0
    St.errs := 0
    St.accOk := 0
    St.accTyped := 0
    St.accWords := 0
    St.parasDone := 0
    St.lastSec := -1
    pv := Ui.ddPara.Value
    St.fixed := (pv > 1)
    if (same && St.cur >= 1 && St.cur <= cnt) {
        idx := St.cur
    } else if (pv > 1 && pv - 1 <= cnt) {
        idx := pv - 1
    } else {
        St.used := Map()
        idx := Random(1, cnt)
        if (cnt > 1 && idx = St.cur)
            idx := Mod(idx, cnt) + 1
    }
    St.busy := true
    Ui.edIn.Enabled := true
    Ui.edIn.Value := ""
    St.busy := false
    LoadParagraph(idx)
    St.state := "ready"
    Ui.lblTimer.Text := FmtClock(St.dur)
    ShowStats(0, 100, 0)
    ShowTab(1)
    FocusInput()
    if (St.dur = 0)
        SetStatus("No timer: the stopwatch starts with your first key and stops when you finish the paragraph.   " . St.note . St.textNote)
    else
        SetStatus("Start typing: the timer starts with your first key.   " . St.note . St.textNote)
}

OnType(*) {
    Critical
    if (St.busy || (St.state != "ready" && St.state != "run"))
        return
    T := TypedNow()
    n := StrLen(T)
    if (St.state = "ready") {
        if (n = 0)
            return
        St.state := "run"
        St.t0 := A_TickCount
        St.endTick := (St.dur > 0) ? St.t0 + St.dur * 1000 : 0
        SetTimer(Tick, 100)
    }
    old := St.prevN
    if (n > old) {
        Loop n - old {
            i := old + A_Index
            St.keys += 1
            if (Cp(T, i) != Cp(St.target, i) && !(i = n && Partial(T, n)))
                St.errs += 1
        }
    }
    RecolorRange(old, n, T)
    St.prevN := n
    if (n >= St.tlen) {
        ParaDone(T)
        return
    }
    ScrollToCurrent(n)
}

; the paragraph on screen was typed completely before the time ended
ParaDone(T) {
    St.accOk += CountOk(T)
    St.accWords += CountWords(T)
    St.accTyped += Min(StrLen(T), St.tlen)
    St.parasDone += 1
    act := Ui.ddFin.Value
    if (act < 1 || act > 5)
        act := 1
    if (St.dur = 0)
        act := 3                ; No timer: finishing the paragraph ends the practice and shows the total time
    if (act = 5) {
        AskFinish()
        return
    }
    DoFinish(act)
}

; 1 next paragraph, 2 same paragraph again, 3 show the result, 4 restart the test
DoFinish(act) {
    if (act = 3) {
        EndTest(true)
        return
    }
    if (act = 4) {
        PrepareTest(true)
        return
    }
    idx := (act = 2) ? St.cur : NextIndex()
    St.busy := true
    Ui.edIn.Value := ""
    St.busy := false
    LoadParagraph(idx)
}

; "Ask me every time": the timer waits while the window is open
AskFinish() {
    SetTimer(Tick, 0)
    St.state := "ask"
    St.pauseTick := A_TickCount
    Ui.g.Opt("+Disabled")
    g := NewWin("Paragraph finished", 420, 200, Ui.g.Hwnd)
    Fw.g := g
    g.Add("Text", "x16 y14 w388 h40", "You typed the whole paragraph before the time ended.`nWhat next?  (the timer waits until you choose)")
    WinBtn(g, "x16 y68 w188 h34 Default", "Next paragraph", FinChoose.Bind(1))
    WinBtn(g, "x216 y68 w188 h34", "Same paragraph again", FinChoose.Bind(2))
    WinBtn(g, "x16 y110 w188 h34", "Show the result", FinChoose.Bind(3))
    WinBtn(g, "x216 y110 w188 h34", "Restart the test", FinChoose.Bind(4))
    g.OnEvent("Close", FinChoose.Bind(1))
    g.OnEvent("Escape", FinChoose.Bind(1))
    g.Show("w420 h160")
}

FinChoose(k, *) {
    g := Fw.g
    if !IsObject(g)
        return true
    Fw.g := ""
    Ui.g.Opt("-Disabled")
    try g.Destroy()
    try WinActivate("ahk_id " . Ui.g.Hwnd)
    p := A_TickCount - St.pauseTick
    St.t0 += p
    St.endTick += p
    St.state := "run"
    SetTimer(Tick, 100)
    DoFinish(k)
    FocusInput()
    return true
}

Metrics(T, elSec) {
    ok := St.accOk + CountOk(T)
    words := St.accWords + CountWords(T)
    mins := Max(elSec, 2) / 60
    if (Ui.ddWpm.Value = 2)
        wpm := words / mins
    else
        wpm := (ok / 5) / mins
    acc := (St.keys > 0) ? 100 * (St.keys - St.errs) / St.keys : 100
    return {wpm: wpm, acc: acc, words: words, ok: ok}
}

Tick() {
    Critical
    if (St.state != "run") {
        SetTimer(Tick, 0)
        return
    }
    if (St.dur = 0) {
        ; stopwatch: count up from the first key
        sec := (A_TickCount - St.t0) // 1000
        if (sec != St.lastSec) {
            St.lastSec := sec
            Ui.lblTimer.Text := FmtClock(sec)
            T := TypedNow()
            res := Metrics(T, (A_TickCount - St.t0) / 1000)
            ShowStats(res.wpm, res.acc, res.words)
        }
        return
    }
    rem := St.endTick - A_TickCount
    if (rem <= 0) {
        EndTest()
        return
    }
    sec := Ceil(rem / 1000)
    if (sec != St.lastSec) {
        St.lastSec := sec
        Ui.lblTimer.Text := FmtClock(sec)
        T := TypedNow()
        res := Metrics(T, (A_TickCount - St.t0) / 1000)
        ShowStats(res.wpm, res.acc, res.words)
    }
}

EndTest(early := false) {
    if (St.state != "run")
        return
    SetTimer(Tick, 0)
    St.state := "done"
    T := early ? "" : TypedNow()
    el := early ? Max(1, (A_TickCount - St.t0) / 1000) : St.dur
    res := Metrics(T, el)
    typed := St.accTyped + Min(StrLen(T), St.tlen)
    raw := (typed / 5) / (Max(el, 2) / 60)
    rem := early ? Max(0, Ceil((St.endTick - A_TickCount) / 1000)) : 0
    if (St.dur = 0)
        rem := Round(el)        ; stopwatch: the label keeps the total time
    Ui.lblTimer.Text := FmtClock(rem)
    ShowStats(res.wpm, res.acc, res.words)

    timeTxt := early ? (FmtClock(Round(el)) . " / " . FmtClock(St.dur)) : FmtClock(St.dur)
    if (St.dur = 0)
        timeTxt := "Total time " . FmtClock(Round(el))
    stamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm")
    St.res := {wpm: res.wpm, raw: raw, acc: res.acc, words: res.words, ok: res.ok, typed: typed, errs: St.errs, paras: St.parasDone
        , timeTxt: timeTxt, early: early, file: St.fileName, stamp: stamp, dur: St.dur
        , basis: (Ui.ddWpm.Value = 2) ? "real words" : "correct characters / 5"}

    durTxt := early ? Format("{} of {}", FmtClock(Round(el)), DurLabel(St.dur)) : DurLabel(St.dur)
    if (St.dur = 0)
        durTxt := FmtClock(Round(el)) . " (no timer)"
    line := Format("{}`t{}`t{}`t{:.1f}`t{:.1f}`t{}`t{}`n", stamp, durTxt, St.fileName, res.wpm, res.acc, res.words, St.errs)
    try FileAppend(line, App.hist, "UTF-16")
    LoadHistory()

    RenderResults()
    Ui.edIn.Enabled := false
    ShowTab(2)
    SetStatus((St.dur = 0 ? "Well done! Your total time was " . FmtClock(Round(el)) . ". " : (early ? "Finished early. " : "Time is up. ")) . "Press " . HkOr("Next", "the Next button") . " for the next text or " . HkOr("Restart", "the Restart button") . " to repeat this one.")
}

UiTick() {
    try {
        if DllCall("IsIconic", "Ptr", Ui.g.Hwnd)          ; minimized: nothing to update
            return
    }
    caps := GetKeyState("CapsLock", "T")
    if (caps != St.caps) {
        St.caps := caps
        Ui.lblCaps.Text := caps ? "CAPS LOCK is ON" : ""
    }
    ; keep the keyboard focus in the typing box while a test is waiting or running
    if (St.tab = 1 && (St.state = "ready" || St.state = "run")) {
        try {
            if WinActive("ahk_id " . Ui.g.Hwnd) {
                fc := Ui.g.FocusedCtrl
                if (IsObject(fc) && fc.Hwnd = Ui.rich.Hwnd)
                    Ui.edIn.Focus()
            }
        }
    }
}

; ---------------------------------------------------------------------------
;  Inspector events
; ---------------------------------------------------------------------------
OnDur(*) {
    IniPut("Settings", "Dur", Ui.ddDur.Value)
    PrepareTest(true)
}

OnFile(*) {
    idx := Ui.ddFile.Value
    if (idx < 1 || idx > St.files.Length)
        return
    IniPut("Settings", "File", St.files[idx])
    LoadFile(St.files[idx])
}

OnPara(*) {
    PrepareTest(false)
}

OnFin(*) {
    IniPut("Settings", "Finish", Ui.ddFin.Value)
    FocusInput()
}

OnEnc(*) {
    SaveFileSettings()
    if (St.fileName != "")
        LoadFile(St.fileName)
}

OnDir(*) {
    SaveFileSettings()
    ApplyDirection()
    RefreshRich()
    FocusInput()
}

; ---------------------------------------------------------------------------
;  Punctuation and numbers (the two drop-downs under Paragraph) - the same for every language
;  Numbers:      No numbers = only paragraphs without numbers.  With numbers = only paragraphs that have numbers.
;  Punctuation:  Basic marks only / No punctuation = the extra marks are taken out of the text.
;                Rich punctuation = only paragraphs that have several kinds of marks.
;  When no paragraph fits, nothing is shown (the status line says so).
;  ANSI texts (Bijoy and similar): the punctuation options are not used, because their letters share
;  codes with punctuation marks; the Numbers option works (digits only).
; ---------------------------------------------------------------------------
OnTextMode(*) {
    IniPut("Settings", "Punct", Ui.ddPunct.Value)
    IniPut("Settings", "Nums", Ui.ddNum.Value)
    if (St.fileName = "" || St.loading)
        return
    St.paras := FilterParas(St.raw)
    FillParaList()
    St.cur := 0
    St.used := Map()
    PrepareTest(false)
}

TextIsAnsi() {
    return InStr(StrLower(St.fileName), "ansi") ? true : false
}

HasNum(p, ansi) {
    return RegExMatch(p, ansi ? "\d" : "\p{N}") ? true : false
}

; true when the paragraph has at least two kinds of marks and three marks in all
RichPunct(p) {
    kinds := 0
    total := 0
    for ch in [",", ";", ":", "!", "?", Chr(34), "(", ")", "-", "'", Chr(0x0964), Chr(0x060C), Chr(0x061F)] {
        c := 0
        StrReplace(p, ch, "", , &c)
        if (c > 0) {
            kinds += 1
            total += c
        }
    }
    return (kinds >= 2 && total >= 3)
}

FilterParas(raw) {
    pm := Ui.ddPunct.Value
    nm := Ui.ddNum.Value
    St.textNote := ""
    if (pm < 1 || pm > 4)
        pm := 1
    if (nm < 1 || nm > 3)
        nm := 1
    ansi := TextIsAnsi()
    if (ansi && pm != 1) {
        pm := 1
        St.textNote := "   (The punctuation options are not used for ANSI texts: their letters share codes with punctuation marks.)"
    }
    if ((pm = 1 && nm = 1) || raw.Length = 0) {
        St.tags := St.rawTags
        return raw
    }
    out := []
    St.tags := []
    for k, p in raw {
        if (nm = 2 && HasNum(p, ansi))
            continue
        if (nm = 3 && !HasNum(p, ansi))
            continue
        if (pm = 4 && !RichPunct(p))
            continue
        c := (pm = 2 || pm = 3) ? CleanPara(p, pm) : p
        if (StrLen(c) >= 3) {
            out.Push(c)
            St.tags.Push(k <= St.rawTags.Length ? St.rawTags[k] : "")
        }
    }
    return out
}

CleanPara(p, pm) {
    p := StrReplace(p, Chr(0x2018), "'")
    p := StrReplace(p, Chr(0x2019), "'")
    p := StrReplace(p, Chr(0x201C), Chr(34))
    p := StrReplace(p, Chr(0x201D), Chr(34))
    p := StrReplace(p, Chr(0x2026), "...")
    p := StrReplace(p, Chr(0xA0), " ")
    if (pm = 3) {
        p := RegExReplace(p, "[\x2D\x{2013}\x{2014}/]+", " ")
        p := RegExReplace(p, "[\p{P}\p{S}]", "")
    } else {
        p := RegExReplace(p, "[\x{2013}\x{2014}]", "-")
        p := RegExReplace(p, "[^\p{L}\p{M}\p{N}\s.,?!\x27\x22:;\x2D\x{0964}\x{0965}\x{060C}\x{061B}\x{061F}\x{06D4}\x{200C}\x{200D}]", "")
    }
    p := RegExReplace(p, "\s+([.,;:!?\x{0964}])", "$1")
    p := RegExReplace(p, "([,;:])\1+", "$1")
    p := RegExReplace(p, "^[\s.,;:!?\x2D\x{0964}]+", "")
    return Trim(RegExReplace(p, "\s+", " "))
}

OnWpm(*) {
    IniPut("Settings", "Wpm", Ui.ddWpm.Value)
    FocusInput()
}

OnTheme(*) {
    idx := Ui.ddTheme.Value
    if (idx < 1 || idx > Th.names.Length)
        return
    ApplyTheme(Th.names[idx])
    IniPut("Settings", "Theme", Th.cname)
    FocusInput()
}

; ---------------------------------------------------------------------------
;  Files: list, load, add
; ---------------------------------------------------------------------------
ReloadList(sel := "") {
    St.files := ListFiles()
    Ui.ddFile.Delete()
    if (St.files.Length > 0)
        Ui.ddFile.Add(St.files)
    if (sel = "")
        sel := St.fileName
    idx := IndexOf(St.files, sel)
    if (idx = 0 && St.files.Length > 0)
        idx := 1
    if (idx > 0) {
        Ui.ddFile.Choose(idx)
        LoadFile(St.files[idx])
    } else {
        St.fileName := ""
        St.raw := []
        St.rawTags := []
        St.tags := []
        St.paras := []
        FillParaList()
        ClearTest()
        St.state := "idle"
        SetStatus("No text files found.   Use 'Add text...' to create one, or drop a .dat file on this window.")
    }
}

FillParaList() {
    items := ["Random paragraph"]
    for i, p in St.paras {
        if (i <= St.tags.Length && St.tags[i] != "")
            items.Push(St.tags[i])
        else
            items.Push(Format("{}. {}", i, SubStr(p, 1, 26) . (StrLen(p) > 26 ? "..." : "")))
    }
    Ui.ddPara.Delete()
    Ui.ddPara.Add(items)
    Ui.ddPara.Choose(1)
}

LoadFile(name) {
    St.loading := true
    St.fileName := name
    St.note := ""
    font := ""
    size := ""
    enc := 1
    dir := 1
    v := Ini("Files", name, "")
    if (v != "") {
        p := StrSplit(v, "|")
        if (p.Length >= 4) {
            font := p[1]
            size := p[2]
            enc := p[3]
            dir := p[4]
        }
    }
    if (font = "") {
        font := GuessFont(name)
        size := "18"
        enc := 1
        dir := 1
        if (Ui.fontSet.Count > 0 && !Ui.fontSet.Has(font)) {
            St.note := "The font '" . font . "' is not installed - choose another one under Font and size."
            font := "Segoe UI"
        }
    }
    SetFontBox(font)
    si := IndexOf(Ui.sizes, size)
    Ui.ddSize.Choose(si ? si : 4)
    Ui.ddEnc.Choose((IsInteger(enc) && enc >= 1 && enc <= 5) ? Integer(enc) : 1)
    Ui.ddDir.Choose((IsInteger(dir) && dir >= 1 && dir <= 3) ? Integer(dir) : 1)

    txt := ""
    msg := ""
    try {
        txt := ReadTextFile(TxtPath(name), Ui.ddEnc.Value, name)
    } catch as e {
        msg := e.Message
    }
    tg := []
    St.raw := SplitParas(txt, &tg)
    St.rawTags := tg
    St.paras := FilterParas(St.raw)
    FillParaList()
    St.cur := 0
    St.used := Map()
    St.loading := false
    ApplyFont()
    if (St.raw.Length = 0) {
        ClearTest()
        St.state := "idle"
        SetStatus(name . ".dat has no text" . (msg != "" ? " (" . msg . ")" : "") . ". Put paragraphs in it, separated by a blank line.")
        return
    }
    PrepareTest(false)
}

SaveFileSettings() {
    if (St.fileName = "" || St.loading)
        return
    IniPut("Files", St.fileName, Trim(Ui.cbFont.Text) . "|" . Ui.ddSize.Text . "|" . Ui.ddEnc.Value . "|" . Ui.ddDir.Value)
}

OnDrop(g, ctrl, files, x, y) {
    ImportFiles(files)
}

; dropped .dat (or .txt) files are copied into your custom files folder (AppData\Bangla Keyboard\Custom Typing Tutor Files)
ImportFiles(arr) {
    last := ""
    for src in arr {
        ext := StrLower(SubStr(src, -4))
        if (ext != ".dat" && ext != ".txt")
            continue
        SplitPath(src, &fn, &fdir, , &nm)
        fn := nm . ".dat"                   ; a dropped .txt is saved as .dat
        fd := StrLower(RTrim(fdir, "\"))
        if (fd = StrLower(App.dir) && ext = ".dat") {
            last := nm                      ; already one of the program's own texts
            continue
        }
        dest := App.cdir . "\" . fn
        if (fd != StrLower(App.cdir) || ext != ".dat") {
            if FileExist(dest) {
                if (MsgBox(fn . " already exists in your custom files.`nReplace it?", App.title, "YesNo Icon?") != "Yes")
                    continue
            }
            try {
                FileCopy(src, dest, 1)
            } catch as e {
                MsgBox("Could not copy " . fn . ":`n" . e.Message, App.title, "Icon!")
                continue
            }
        }
        last := nm
    }
    if (last != "")
        ReloadList(last)
}

; ---------------------------------------------------------------------------
;  History
; ---------------------------------------------------------------------------
LoadHistory() {
    Ui.lv.Delete()
    txt := ""
    if FileExist(App.hist) {
        try txt := FileRead(App.hist, "UTF-16")
    }
    if (SubStr(txt, 1, 1) = Chr(0xFEFF))
        txt := SubStr(txt, 2)
    lines := []
    Loop Parse txt, "`n", "`r" {
        if (A_LoopField != "")
            lines.Push(A_LoopField)
    }
    St.hlines := lines
    St.hmap := []
    cnt := 0
    best := 0
    sum := 0
    shown := 0
    i := lines.Length
    while (i >= 1) {
        f := StrSplit(lines[i], "`t")
        if (f.Length >= 7) {
            cnt += 1
            w := IsNumber(f[4]) ? f[4] + 0 : 0
            sum += w
            if (w > best)
                best := w
            if (shown < 1000) {
                Ui.lv.Add("", f[1], f[2], f[3], f[4], f[5], f[6], f[7])
                St.hmap.Push(i)
                shown += 1
            }
        }
        i -= 1
    }
    avg := cnt ? sum / cnt : 0
    Ui.lblBest.Text := Format("Tests: {}        Best: {:.1f} WPM        Average: {:.1f} WPM", cnt, best, avg)
}

; removes only the selected rows (Ctrl / Shift + click for several; the Delete key does the same)
DeleteSelectedHistory(*) {
    rows := []
    r := 0
    while (r := Ui.lv.GetNext(r))
        rows.Push(r)
    if (rows.Length = 0) {
        MsgBox("Select the result you want to delete first.`nUse Ctrl or Shift + click to select several.", App.title, "Iconi")
        return
    }
    q := (rows.Length = 1) ? "Delete the selected result?" : Format("Delete the {} selected results?", rows.Length)
    if (MsgBox(q, App.title, "YesNo Icon?") != "Yes")
        return
    del := Map()
    for r in rows {
        if (r <= St.hmap.Length)
            del[St.hmap[r]] := 1
    }
    out := ""
    for i, ln in St.hlines {
        if !del.Has(i)
            out .= ln . "`n"
    }
    try {
        if (out = "") {
            FileDelete(App.hist)
        } else {
            f := FileOpen(App.hist, "w", "UTF-16")
            f.Write(out)
            f.Close()
        }
    } catch as e {
        MsgBox("Could not change the history file:`n" . e.Message, App.title, "Icon!")
    }
    LoadHistory()
}

HistFocus() {
    try {
        if (IsObject(Ui.g) && St.tab = 3 && WinActive("ahk_id " . Ui.g.Hwnd)) {
            fc := Ui.g.FocusedCtrl
            return (IsObject(fc) && fc.Hwnd = Ui.lv.Hwnd)
        }
    }
    return false
}

ClearHistory(*) {
    if (MsgBox("Delete all saved results?", App.title, "YesNo Icon?") != "Yes")
        return
    try FileDelete(App.hist)
    LoadHistory()
}

SaveSettings(*) {
    try {
        IniPut("Settings", "Dur", Ui.ddDur.Value)
        IniPut("Settings", "Theme", Th.cname)
        IniPut("Settings", "Wpm", Ui.ddWpm.Value)
        IniPut("Settings", "Finish", Ui.ddFin.Value)
        IniPut("Settings", "HidePanel", St.hideInsp ? "1" : "0")
        IniPut("Settings", "InFrac", Format("{:.3f}", St.inFrac))
        IniPut("Settings", "File", St.fileName)
        if (WinGetMinMax(Ui.g.Hwnd) = 0) {
            d := A_ScreenDPI / 96
            IniPut("Settings", "W3", Round(St.cw / d))
            IniPut("Settings", "H3", Round(St.ch / d))
        }
    }
}

; ---------------------------------------------------------------------------
;  Help
; ---------------------------------------------------------------------------
HelpText() {
    t := "HOW TO USE`r`n"
    t .= "`r`n1. On the right panel choose the test time, the text file and, if you like, one particular paragraph. The text appears on the Test tab at once.`r`n"
    t .= "2. Just start typing (the typing box under the text has the keyboard focus). The timer starts with your first key.`r`n"
    t .= "3. Green letters are correct, red letters are wrong. Fix a mistake with Backspace, or carry on.`r`n"
    t .= "4. If you finish the paragraph before the time ends, the program does what you chose under 'When a paragraph is finished early': load the next paragraph, repeat the same one, show the result, restart the test, or ask you every time.`r`n"
    t .= "5. When the test ends the Results tab shows your speed and accuracy, and the test is saved in History.`r`n"
    t .= "   Beginner? Choose 'No timer (stopwatch)' as the test duration: there is no time limit, the clock counts up from your first key, and when you finish the paragraph the Results tab shows your total time.`r`n"
    t .= "`r`nKeys (you can change them in Settings): " . HkSummary() . ".`r`n"
    t .= "`r`nCLEAR VIEW`r`n"
    t .= "`r`nRoll the mouse wheel over the typing box to scroll it; hold Ctrl and roll the wheel to make the text bigger or smaller. Press 'Hide panel' (or its hotkey, see Settings) to practise with nothing but the text and the typing box. Press it again to bring the panel back. The program remembers your choice.`r`n"
    t .= "Drag the small dotted bar between the text and the typing box up or down to make the text or the typing box bigger. The typing box starts at 30% of the window height and keeps its share when you resize the window.`r`n"
    t .= "`r`nPUNCTUATION AND NUMBERS`r`n"
    t .= "`r`nUnder 'Paragraph' there are two lists, Punctuation and Numbers, like on typing practice websites.`r`n"
    t .= "Punctuation:  As in the text = nothing changes.  Basic marks only = keeps . , ? ! ' quotes : `; - and the Bangla danda, and drops the other symbols.  No punctuation = only letters and words.  Rich punctuation = only paragraphs that have many different marks.`r`n"
    t .= "Numbers:  As in the text = nothing changes.  No numbers = only paragraphs without numbers.  With numbers = only paragraphs that contain numbers.`r`n"
    t .= "These options work for every language. If no paragraph fits, nothing is shown and the status line says so: choose 'As in the text' to see all paragraphs again. ANSI texts (Bijoy and similar) ignore the punctuation options, because their letters share codes with punctuation marks.`r`n"
    t .= "`r`nSETTINGS, HOTKEYS AND HOVER TIPS`r`n"
    t .= "`r`nPress 'Settings' (top right) to change every hotkey, switch the hover tips on or off, choose whether the Info window opens at start, and choose the interface size (Normal or Large; it applies after a restart).`r`n"
    t .= "Rest the mouse on any option, button or tab for a moment and a small tip tells you what it does. If the window is too short for the whole right panel, roll the mouse wheel over the panel to scroll it.`r`n"
    t .= "`r`nHISTORY`r`n"
    t .= "`r`nSelect one result (Ctrl or Shift + click for several) and press 'Delete selected' or the Delete key to remove just those. 'Clear history' removes everything.`r`n"
    t .= "`r`nTEXT FILES`r`n"
    t .= "`r`nThe texts that come with the program are in the Typing Tutor Data folder next to it. Your own texts are saved in %AppData%\Bangla Keyboard\Custom Typing Tutor Files, so they stay there as a backup even if you uninstall the program.`r`n"
    t .= "'Add text...' (right panel) first asks which text file to use, then opens a window where you type or paste your own practice text; Save / Insert asks you to confirm and adds it to that file. 'Edit text...' asks which file, then you can type, paste and delete in the box (or select a part and press Delete selected); Save writes it to the file (a .bak copy of the original is kept; Undo brings changes back). A- / A+ make the text smaller or bigger. If you change a text that came with the program, your changed copy is saved in the custom folder and is used from then on.`r`n"
    t .= "You can also drop .dat (or .txt) files on the main window to add them. A dropped .txt is saved as .dat. Separate paragraphs with a blank line. If a file has no blank line, every line is one paragraph.`r`n"
    t .= "In both text windows the Size box is a list you can also type your own number into.`r`n"
    t .= "`r`nENCODING AND FONT`r`n"
    t .= "`r`n'Auto detect' reads UTF-8 and UTF-16 files, and treats a file whose name contains 'ANSI' as ANSI (Windows-1252). If a text looks wrong, choose the encoding by hand.`r`n"
    t .= "For ANSI texts (Bijoy and similar) choose the matching font, for example SutonnyMJ, so the letters look right. Font, size, encoding and direction are remembered for each file.`r`n"
    t .= "`r`nKEYBOARD`r`n"
    t .= "`r`nThe keyboard layout or typing software (Bijoy, Avro, a system keyboard ...) is your own choice. The app only compares what you type with the text. A Unicode Bangla text needs a Unicode Bangla keyboard, an ANSI text needs an ANSI keyboard.`r`n"
    t .= "If a letter that looks right is shown red, the file and your keyboard store that letter with different codes (some Bangla letters with a dot below can be stored in two ways). Re-type that text in the file with your own keyboard.`r`n"
    t .= "`r`nSPEED`r`n"
    t .= "`r`nStandard: correct characters / 5 per minute. Real words: only completely correct words are counted (a fairer count for Bangla). Accuracy counts every wrong key, even if you fix it later.`r`n"
    t .= "`r`nMore help: see the other tabs of the Info window.`r`n"
    return t
}

; ===========================================================================
;  Help window, Add text window, Edit text window
;  (all of them are modal: the main window waits until they are closed)
; ===========================================================================
SetDarkTitle(hwnd, dark) {
    try {
        v := Buffer(4, 0)
        NumPut("Int", dark ? 1 : 0, v)
        if (DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20, "Ptr", v, "Int", 4) != 0)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 19, "Ptr", v, "Int", 4)
    }
}

NewWin(title, w, h, ownerHwnd, resizable := false, minW := 0, minH := 0) {
    d := A_ScreenDPI / 96
    t := Th.cur
    o := "+Owner" . ownerHwnd . " +0x2000000"
    if resizable
        o .= " +Resize"
    if (minW > 0)
        o .= " +MinSize" . Round(minW * d) . "x" . Round(minH * d)
    g := Gui(o, title)
    g.BackColor := Hx(t.bg)
    g.SetFont("s9 c" . Hx(t.text), "Segoe UI")
    SetDarkTitle(g.Hwnd, t.dark)
    return g
}

WinBtn(g, opts, text, fn) {
    b := g.Add("Button", opts, text)
    b.OnEvent("Click", fn)
    SetCtlTheme(b, "btn", Th.cur.dark)
    return b
}

WinEdit(g, opts, text := "") {
    e := g.Add("Edit", opts . " Background" . Hx(Th.cur.panel), text)
    SetCtlTheme(e, "edit", Th.cur.dark)
    SendMessage(0x00C5, 0x7FFFFFFE, 0, e.Hwnd)           ; EM_SETLIMITTEXT: no 32 K limit
    return e
}

Toolbar(g, y, items) {
    x := 10
    for it in items {
        w := Round(it[2] * 1.06)
        b := WinBtn(g, "x" . x . " y" . y . " w" . w . " h30", it[1], it[3])
        if (it.Length >= 4)
            Tip(b, it[4])
        x += w + 4
    }
}

ToCRLF(t) {
    t := StrReplace(t, "`r`n", "`n")
    t := StrReplace(t, "`r", "`n")
    return StrReplace(t, "`n", "`r`n")
}

FileEncMode(name) {
    v := Ini("Files", name, "")
    if (v != "") {
        p := StrSplit(v, "|")
        if (p.Length >= 3 && IsInteger(p[3]) && p[3] >= 1 && p[3] <= 5)
            return Integer(p[3])
    }
    return 1
}

FileFont(name) {
    face := ""
    v := Ini("Files", name, "")
    if (v != "") {
        p := StrSplit(v, "|")
        if (p.Length >= 1)
            face := p[1]
    }
    if (face = "")
        face := GuessFont(name)
    if (Ui.fontSet.Count > 0 && !Ui.fontSet.Has(face))
        face := "Segoe UI"
    return face
}

; the encoding to write a whole file with / to append to a file with
WriteEnc(info) {
    if (info = "UTF-8BOM")
        return "UTF-8"
    if (info = "UTF-8")
        return "UTF-8-RAW"
    if (info = "UTF-16" || info = "UTF-16BE")
        return "UTF-16"
    return info
}

AppendEnc(info) {
    if (info = "UTF-8BOM" || info = "UTF-8")
        return "UTF-8-RAW"
    if (info = "UTF-16" || info = "UTF-16BE")
        return "UTF-16"
    return info
}

EncLabel(info) {
    if (info = "UTF-8BOM")
        return "UTF-8 (with BOM)"
    if (info = "UTF-8")
        return "UTF-8"
    if (info = "UTF-16" || info = "UTF-16BE")
        return "UTF-16"
    if (info = "CP1252")
        return "ANSI (Windows-1252)"
    return "ANSI (system default)"
}

; true when the text survives a round trip through the ANSI code page
CanEncode(txt, cp) {
    n := StrPut(txt, cp)
    b := Buffer(n, 0)
    StrPut(txt, b, cp)
    return (StrCompare(StrGet(b, cp), txt, "On") = 0)
}

RefreshFileDDL() {
    St.files := ListFiles()
    Ui.ddFile.Delete()
    if (St.files.Length > 0)
        Ui.ddFile.Add(St.files)
    idx := IndexOf(St.files, St.fileName)
    if (idx > 0)
        Ui.ddFile.Choose(idx)
}

; ---------------------------------------------------------------------------
;  Popups: new file name, choose the file to edit
; ---------------------------------------------------------------------------
PpEnd(reenable := true) {
    o := Pp.owner
    g := Pp.g
    Pp.g := ""
    Pp.owner := ""
    if (reenable && IsObject(o)) {
        try o.Opt("-Disabled")
    }
    try g.Destroy()
    if (reenable && IsObject(o)) {
        try WinActivate("ahk_id " . o.Hwnd)
    }
}

PpCancel(*) {
    PpEnd()
    return true
}

PpOK(*) {
    if (Pp.kind = "new")
        PpNewOK()
    else
        PpPickOK()
}

PpNewOK() {
    name := Trim(Pp.edit.Value)
    if (StrLower(SubStr(name, -4)) = ".dat" || StrLower(SubStr(name, -4)) = ".txt")
        name := SubStr(name, 1, StrLen(name) - 4)
    name := Trim(name, " .")
    if (name = "") {
        MsgBox("Please type a name for the new file.", App.title, "Icon!")
        return
    }
    if RegExMatch(name, '[\\/:*?"<>|]') {
        MsgBox('A file name cannot contain any of these characters:   \ / : * ? " < > |', App.title, "Icon!")
        return
    }
    if (StrLen(name) > 100) {
        MsgBox("That name is too long.", App.title, "Icon!")
        return
    }
    path := App.cdir . "\" . name . ".dat"
    if FileKnown(name) {
        MsgBox(name . ".dat already exists. Please choose another name.", App.title, "Icon!")
        return
    }
    try {
        if InStr(StrLower(name), "ansi")
            FileOpen(path, "w", "CP1252").Close()
        else
            FileOpen(path, "w", "UTF-8").Close()
    } catch as e {
        MsgBox("Could not create the file:`n" . e.Message, App.title, "Icon!")
        return
    }
    PpEnd()
    EwAfterNew(name)
}

PpPickOK() {
    name := Pp.dd.Text
    if (name = "")
        return
    kind := Pp.kind
    PpEnd(false)                  ; the main window stays disabled until the editor closes
    if (kind = "pickadd")
        OpenAddWin(name)
    else
        OpenEditWin(name)
}

; asks first which text file to work on (kind: "pickadd" or "pick")
OpenPick(kind) {
    files := ListFiles()
    Ui.g.Opt("+Disabled")
    Pp.owner := Ui.g
    Pp.kind := kind
    adding := (kind = "pickadd")
    g := NewWin(adding ? "Add text" : "Edit text", 420, 150, Ui.g.Hwnd)
    Pp.g := g
    g.Add("Text", "x16 y14 w388 h20", adding ? "Choose the text file to add your text into:" : "Choose the text file you want to edit:")
    Pp.dd := g.Add("DropDownList", "x16 y40 w388 R15", files)
    SetCtlTheme(Pp.dd, "combo", Th.cur.dark)
    idx := IndexOf(files, St.fileName)
    Pp.dd.Choose(idx ? idx : 1)
    WinBtn(g, "x214 y96 w90 h30 Default", "OK", PpOK)
    WinBtn(g, "x314 y96 w90 h30", "Cancel", PpCancel)
    g.OnEvent("Close", PpCancel)
    g.OnEvent("Escape", PpCancel)
    g.Show("w420 h150")
}

; ---------------------------------------------------------------------------
;  Add text window
; ---------------------------------------------------------------------------
OpenAddText(*) {
    if (IsObject(Ew.g) || IsObject(Pp.g) || IsObject(Hw.g) || IsObject(Fw.g))
        return
    if (ListFiles().Length = 0) {
        Ui.g.Opt("+Disabled")
        OpenAddWin("")
        return
    }
    OpenPick("pickadd")
}

OpenAddWin(name) {
    Ew.mode := "add"
    Ew.file := name
    Ew.sz := 13
    Ew.top := 68
    Ew.reload := false
    Ew.lastFind := ""
    g := NewWin("Add text to practise - " . App.title, 740, 540, Ui.g.Hwnd, true, 700, 420)
    Ew.g := g
    Toolbar(g, 8, [["New file...", 84, EwNewFile, "Create a new text file in your custom files folder."], ["Cut", 44, EwCut, "Cut the selected text (Ctrl+X)."], ["Copy", 50, EwCopy, "Copy the selected text (Ctrl+C)."], ["Paste", 52, EwPaste, "Paste text from the clipboard (Ctrl+V)."], ["Undo", 50, EwUndo, "Undo the last change (Ctrl+Z)."], ["Select all", 74, EwSelAll, "Select all the text (Ctrl+A)."], ["Find...", 56, EwFind, "Find text in the box (Ctrl+F)."], ["Clear", 50, EwClear, "Empty the box."], ["A-", 34, EwZoomOut, "Make the letters in this box smaller."], ["A+", 34, EwZoomIn, "Make the letters in this box bigger."], ["Save / Insert", 104, EwSaveInsert, "Add the text in the box to the file as new paragraph(s) (Ctrl+S)."]])
    Ew.hint := g.Add("Text", "x10 y44 w710 h22 0x200", "")
    Ew.edit := WinEdit(g, "x10 y68 w710 h410 Multi +VScroll +0x100")
    Ew.stat := g.Add("Text", "x10 y490 w710 h20 0x200", "")
    Ew.edit.OnEvent("Change", EwCount)
    g.OnEvent("Size", EwSize)
    g.OnEvent("Close", EwClose)
    g.OnEvent("Escape", EwClose)
    EwAddHint()
    EwApplyFont()
    EwCount()
    g.Show("w740 h540")
    try Ew.edit.Focus()
}

EwAddHint(extra := "") {
    if (Ew.file = "")
        Ew.hint.Text := "No text file yet. Press New file... to create one, then type or paste your text."
    else
        Ew.hint.Text := (extra != "") ? extra : ("Adding to  " . Ew.file . ".dat  -  type or paste your text, then press Save / Insert (added as a new paragraph).")
}

EwCount(*) {
    t := Ew.edit.Value
    chars := StrLen(t)
    words := 0
    pos := 1
    while (pos <= chars && RegExMatch(t, "\S+", &mt, pos)) {
        words += 1
        pos := mt.Pos + mt.Len
    }
    Ew.stat.Text := Format("Characters: {}        Words: {}        Paragraphs: {}", chars, words, SplitParas(t).Length)
}

EwNewFile(*) {
    if IsObject(Pp.g)
        return
    Pp.owner := Ew.g
    Pp.kind := "new"
    Ew.g.Opt("+Disabled")
    g := NewWin("New text file", 420, 160, Ew.g.Hwnd)
    Pp.g := g
    g.Add("Text", "x16 y14 w388 h20", "Name for the new file (it is saved in your custom files folder):")
    Pp.edit := WinEdit(g, "x16 y40 w388", "")
    g.Add("Text", "x16 y72 w388 h20", ".dat is added for you. Put 'ANSI' in the name to make an ANSI file.")
    WinBtn(g, "x214 y108 w90 h30 Default", "OK", PpOK)
    WinBtn(g, "x314 y108 w90 h30", "Cancel", PpCancel)
    g.OnEvent("Close", PpCancel)
    g.OnEvent("Escape", PpCancel)
    g.Show("w420 h160")
    try Pp.edit.Focus()
}

EwAfterNew(name) {
    Ew.file := name
    RefreshFileDDL()
    EwApplyFont()
    EwAddHint("Created " . name . ".dat. Type or paste your text and press Save / Insert.")
    try Ew.edit.Focus()
}

EwSaveInsert(*) {
    name := Ew.file
    txt := Trim(Ew.edit.Value, " `t`r`n")
    if (name = "") {
        MsgBox("Choose a text file first, or create one with New file...", App.title, "Icon!")
        return
    }
    if (txt = "") {
        MsgBox("Type or paste the text you want to add first.", App.title, "Icon!")
        return
    }
    path := TxtPath(name)
    if !FileExist(path) {
        MsgBox(name . ".dat was not found.", App.title, "Icon!")
        return
    }
    info := ""
    old := ""
    try {
        old := ReadTextFile(path, FileEncMode(name), name, &info)
    } catch as e {
        MsgBox("Could not read " . name . ".dat:`n" . e.Message, App.title, "Icon!")
        return
    }
    body := ToCRLF(txt)
    n := SplitParas(body).Length
    if ((info = "CP1252" || info = "CP0") && !CanEncode(body, info)) {
        if (MsgBox("This is an ANSI file and some of the characters you typed cannot be stored in ANSI (they would become '?').`nSave anyway?", App.title, "YesNo Icon!") != "Yes")
            return
    }
    if (MsgBox(Format("Add this text ({} paragraph(s)) to {}.dat?`n`nThe file will be changed.", n, name), App.title, "YesNo Icon?") != "Yes")
        return
    path := WritePath(name)             ; your own copy, in the custom files folder
    try {
        if (FileGetSize(path) = 0) {
            enc := InStr(StrLower(name), "ansi") ? "CP1252" : "UTF-8"
            f := FileOpen(path, "w", enc)
            f.Write(body . "`r`n")
            f.Close()
        } else if (info = "UTF-16BE") {
            f := FileOpen(path, "w", "UTF-16")
            f.Write(old . "`r`n`r`n" . body . "`r`n")
            f.Close()
        } else {
            pre := (Trim(old, " `t`r`n") = "") ? "" : "`r`n`r`n"
            FileAppend(pre . body . "`r`n", path, AppendEnc(info))
        }
    } catch as e {
        MsgBox("Could not save to " . name . ".dat:`n" . e.Message, App.title, "Icon!")
        return
    }
    Ew.edit.Value := ""
    if (name = St.fileName)
        Ew.reload := true
    EwAddHint(Format("Saved: {} paragraph(s) added to {}.dat. You can add more text now.", n, name))
    try Ew.edit.Focus()
}

; ---------------------------------------------------------------------------
;  Edit text window
; ---------------------------------------------------------------------------
OpenEditText(*) {
    if (IsObject(Ew.g) || IsObject(Pp.g) || IsObject(Hw.g))
        return
    if (ListFiles().Length = 0) {
        MsgBox("There are no text files in the source folder yet.", App.title, "Icon!")
        return
    }
    OpenPick("pick")
}

OpenEditWin(name) {
    path := TxtPath(name)
    info := ""
    txt := ""
    try {
        txt := ReadTextFile(path, FileEncMode(name), name, &info)
    } catch as e {
        MsgBox("Could not read " . name . ".dat:`n" . e.Message, App.title, "Icon!")
        Ui.g.Opt("-Disabled")
        try WinActivate("ahk_id " . Ui.g.Hwnd)
        return
    }
    Ew.mode := "edit"
    Ew.file := name
    Ew.info := info
    Ew.bak := false
    Ew.reload := false
    Ew.lastFind := ""
    Ew.sz := 14
    Ew.top := 68
    Ew.selA := 0
    Ew.selB := 0
    Ew.dirty := false
    Ew.face := FileFont(name)
    g := NewWin("Edit text - " . name . ".dat", 820, 560, Ui.g.Hwnd, true, 720, 400)
    Ew.g := g
    Toolbar(g, 8, [["Delete selected", 116, EwDelSel, "Delete the part of the text you selected."], ["Undo", 56, EwUndo, "Undo the last change (Ctrl+Z)."], ["Find...", 62, EwFind, "Find text in the file (Ctrl+F)."], ["Find next", 78, EwFindNext, "Find the next match (F3)."], ["Copy", 56, EwCopy, "Copy the selected text (Ctrl+C)."], ["Select all", 84, EwSelAll, "Select all the text (Ctrl+A)."], ["A-", 34, EwZoomOut, "Make the letters smaller."], ["A+", 34, EwZoomIn, "Make the letters bigger."], ["Save", 64, EwSave, "Write the changes to the file (Ctrl+S). A .bak copy of the original is kept."]])
    Ew.lblFile := g.Add("Text", "x10 y44 w790 h22 0x200", "")
    Ew.edit := WinEdit(g, "x10 y68 w790 h428 Multi +VScroll +0x100")
    Ew.stat := g.Add("Text", "x10 y510 w790 h20 0x200", "Type to edit the text, or select a part and press Delete selected. Press Save (Ctrl+S) to write it to the file.")
    SetTimer(EwTrackSel, 100)
    Ew.setting := true
    Ew.edit.Value := ToCRLF(txt)
    Ew.setting := false
    Ew.edit.OnEvent("Change", EwEditChange)
    EwApplyFont()
    g.OnEvent("Size", EwSize)
    g.OnEvent("Close", EwClose)
    g.OnEvent("Escape", EwClose)
    g.Show("w820 h560")
    SendMessage(0x00B1, 0, 0, Ew.edit.Hwnd)
    EwInfo()
    try Ew.edit.Focus()
}

; the user typed / pasted / deleted something in the editable box
EwEditChange(*) {
    if (Ew.setting || Ew.mode != "edit")
        return
    Ew.dirty := true
    SetTimer(EwInfo, -300)
}

; remembers the selection of the text, because pressing a button takes the focus away from it
EwTrackSel() {
    if (!IsObject(Ew.g) || Ew.mode != "edit" || !IsObject(Ew.edit)) {
        SetTimer(EwTrackSel, 0)
        return
    }
    if (DllCall("GetFocus", "Ptr") != Ew.edit.Hwnd)
        return
    EwGetSel(&a, &b)
    Ew.selA := a
    Ew.selB := b
}

EwInfo() {
    if (Ew.mode != "edit" || !IsObject(Ew.g))
        return
    n := SplitParas(Ew.edit.Value).Length
    Ew.lblFile.Text := Format("{}.dat        {}        {} paragraphs        {}", Ew.file, EncLabel(Ew.info), n, Ew.dirty ? "NOT SAVED" : "saved")
    Ew.g.Title := "Edit text - " . Ew.file . ".dat" . (Ew.dirty ? "  *" : "")
}

EwGetSel(&a, &b) {
    a := 0
    b := 0
    DllCall("SendMessage", "Ptr", Ew.edit.Hwnd, "UInt", 0x00B0, "UInt*", &a, "UInt*", &b, "Ptr")      ; EM_GETSEL
}

; puts new text into the (read-only) box and keeps the scroll position
EwSetText(nt, caret) {
    h := Ew.edit.Hwnd
    first := SendMessage(0x00CE, 0, 0, h)                  ; EM_GETFIRSTVISIBLELINE
    Ew.setting := true
    Ew.edit.Value := nt
    Ew.setting := false
    SendMessage(0x00B1, caret, caret, h)
    SendMessage(0x00B6, 0, first, h)                       ; EM_LINESCROLL
    EwInfo()
}

EwDelSel(*) {
    if (Ew.mode != "edit" || !IsObject(Ew.g))
        return
    EwGetSel(&a, &b)
    if (a = b) {                         ; the text lost the focus: use the selection it had
        a := Ew.selA
        b := Ew.selB
    }
    if (a = b || b > StrLen(Ew.edit.Value)) {
        Ew.stat.Text := "Select the text you want to delete first."
        return
    }
    h := Ew.edit.Hwnd
    SendMessage(0x00B1, a, b, h)                        ; EM_SETSEL
    SendMessage(0x00C2, 1, StrPtr(""), h)               ; EM_REPLACESEL (can be undone)
    Ew.selA := 0
    Ew.selB := 0
    Ew.stat.Text := Format("Deleted {} characters. Press Save to write the change to the file (Undo brings them back).", b - a)
    EwFocus()
}

EwSave(*) {
    if (Ew.mode != "edit" || !IsObject(Ew.g))
        return false
    path := WritePath(Ew.file)           ; saved in the custom files folder
    t := Ew.edit.Value
    t := RegExReplace(t, "(\r\n[ \t]*){3,}", "`r`n`r`n")        ; no more than one blank line between paragraphs
    t := Trim(t, " `t`r`n") . "`r`n"
    note := ""
    if !Ew.bak {
        try FileCopy(path, path . ".bak", 1)
        Ew.bak := true
        note := "  (the original is kept as " . Ew.file . ".dat.bak)"
    }
    try {
        f := FileOpen(path, "w", WriteEnc(Ew.info))
        f.Write(t)
        f.Close()
    } catch as e {
        MsgBox("Could not save the file:`n" . e.Message, App.title, "Icon!")
        return false
    }
    Ew.dirty := false
    EwGetSel(&a, &b)
    EwSetText(t, Min(a, StrLen(t)))
    if (Ew.file = St.fileName)
        Ew.reload := true
    Ew.stat.Text := "Saved." . note
    return true
}

; ---------------------------------------------------------------------------
;  Toolbar actions shared by both editor windows
; ---------------------------------------------------------------------------
EwFocus() {
    try Ew.edit.Focus()
}

EwCut(*) {
    EwFocus()
    SendMessage(0x0300, 0, 0, Ew.edit.Hwnd)          ; WM_CUT
}

EwCopy(*) {
    EwFocus()
    SendMessage(0x0301, 0, 0, Ew.edit.Hwnd)          ; WM_COPY
}

EwPaste(*) {
    EwFocus()
    SendMessage(0x0302, 0, 0, Ew.edit.Hwnd)          ; WM_PASTE
}

EwSelAll(*) {
    EwFocus()
    SendMessage(0x00B1, 0, -1, Ew.edit.Hwnd)         ; EM_SETSEL
}

EwClear(*) {
    if (Ew.edit.Value = "")
        return
    if (MsgBox("Clear all the text in this box?", App.title, "YesNo Icon?") != "Yes")
        return
    Ew.edit.Value := ""
    EwFocus()
}

EwUndo(*) {
    EwFocus()
    SendMessage(0x00C7, 0, 0, Ew.edit.Hwnd)      ; EM_UNDO
}

EwApplyFont() {
    if (Ew.mode = "add") {
        nm := Ew.file
        Ew.face := (nm = "") ? "Segoe UI" : FileFont(nm)
    }
    Ew.edit.SetFont("s" . Ew.sz . " norm c" . Hx(Th.cur.text), Ew.face)
}

; Zoom: A- / A+ buttons make the text smaller / bigger
EwZoom(dir) {
    if !IsObject(Ew.g)
        return
    v := Max(8, Min(72, Ew.sz + dir * 2))
    if (v != Ew.sz) {
        Ew.sz := v
        EwApplyFont()
    }
    EwFocus()
}

EwZoomIn(*) {
    EwZoom(1)
}

EwZoomOut(*) {
    EwZoom(-1)
}

EwSize(g, minMax, w, h) {
    if (minMax = -1 || !IsObject(Ew.edit))
        return
    d := A_ScreenDPI / 96
    m := Round(10 * d)
    y := Round(Ew.top * d)
    Ew.edit.Move(m, y, Max(50, w - 2 * m), Max(50, h - y - Round(34 * d)))
    Ew.stat.Move(m, h - Round(26 * d), Max(50, w - 2 * m), Round(20 * d))
}

; Find: a small window next to the editor. F3 / Find next goes on from the selection and wraps around.
EwFind(*) {
    if !IsObject(Ew.g)
        return
    if IsObject(Ew.fg) {
        try Ew.fg.Show()
        try Ew.fEdit.Focus()
        return
    }
    g := NewWin("Find", 380, 124, Ew.g.Hwnd)
    Ew.fg := g
    g.Add("Text", "x12 y16 w62 h22 0x200", "Find what:")
    Ew.fEdit := WinEdit(g, "x78 y14 w288", Ew.lastFind)
    g.Add("Text", "x12 y48 w62 h22 0x200", "Match:")
    Ew.fCase := g.Add("DropDownList", "x78 y46 w150 R3", ["Ignore case", "Match case"])
    Ew.fCase.Choose(Ew.lastCase ? 2 : 1)
    SetCtlTheme(Ew.fCase, "combo", Th.cur.dark)
    WinBtn(g, "x78 y84 w100 h28 Default", "Find next", EwFindNext)
    WinBtn(g, "x188 y84 w100 h28", "Close", EwFindClose)
    g.OnEvent("Close", EwFindClose)
    g.OnEvent("Escape", EwFindClose)
    g.Show("w380 h124")
    try Ew.fEdit.Focus()
}

EwFindClose(*) {
    if IsObject(Ew.fg) {
        try Ew.lastFind := Ew.fEdit.Value
        try Ew.lastCase := (Ew.fCase.Value = 2)
        try Ew.fg.Destroy()
    }
    Ew.fg := ""
    return true
}

EwFindNext(*) {
    if (!IsObject(Ew.g) || !IsObject(Ew.edit))
        return
    if IsObject(Ew.fg) {
        Ew.lastFind := Ew.fEdit.Value
        Ew.lastCase := (Ew.fCase.Value = 2)
    }
    what := Ew.lastFind
    if (what = "") {
        EwFind()
        return
    }
    txt := Ew.edit.Value
    s := Buffer(4, 0)
    e := Buffer(4, 0)
    SendMessage(0x00B0, s.Ptr, e.Ptr, Ew.edit.Hwnd)
    from := NumGet(e, 0, "UInt") + 1
    pos := InStr(txt, what, Ew.lastCase, from)
    wrapped := false
    if (pos = 0 && from > 1) {
        pos := InStr(txt, what, Ew.lastCase, 1)
        wrapped := true
    }
    if (pos = 0) {
        Ew.stat.Text := "Not found: " . what
        return
    }
    SendMessage(0x00B1, pos - 1, pos - 1 + StrLen(what), Ew.edit.Hwnd)
    SendMessage(0x00B7, 0, 0, Ew.edit.Hwnd)                 ; EM_SCROLLCARET
    Ew.stat.Text := wrapped ? "Found (started again from the top)." : "Found."
}

EwClose(*) {
    if !IsObject(Ew.g)
        return true
    if (Ew.mode = "edit" && Ew.dirty) {
        r := MsgBox("Save your changes to " . Ew.file . ".dat before closing?", App.title, "YesNoCancel Icon?")
        if (r = "Cancel")
            return true
        if (r = "Yes" && !EwSave())
            return true
    } else if (Ew.mode = "add" && Trim(Ew.edit.Value) != "") {
        if (MsgBox("The text you typed has not been saved. Close without saving?", App.title, "YesNo Icon?") != "Yes")
            return true
    }
    EwFinish()
    return true
}

EwFinish() {
    EwFindClose()
    g := Ew.g
    Ew.g := ""
    Ew.edit := ""
    SetTimer(EwTrackSel, 0)
    Ui.g.Opt("-Disabled")
    try g.Destroy()
    try WinActivate("ahk_id " . Ui.g.Hwnd)
    RefreshFileDDL()
    if (Ew.reload || (St.fileName = "" && St.files.Length > 0)) {
        Ew.reload := false
        ReloadList(St.fileName)
    }
    FocusInput()
}

; ---------------------------------------------------------------------------
;  Info window: Get started, Fingers, English, Bangla, Tutorials, About
; ---------------------------------------------------------------------------
OpenHelp(*) {
    if (IsObject(Hw.g) || IsObject(Ew.g) || IsObject(Pp.g) || IsObject(Fw.g) || IsObject(Sw.g))
        return
    TipHide()
    Ui.g.Opt("+Disabled")
    d := A_ScreenDPI / 96
    ; a plain window: normal tabs, normal text boxes with normal scrollbars, no custom colours or drawing
    g := Gui("+Owner" . Ui.g.Hwnd . " +Resize +MinSize" . Round(560 * d) . "x" . Round(380 * d), "Info - " . App.title)
    g.SetFont("s9", "Segoe UI")
    Hw.g := g
    Hw.eds := []
    Hw.cur := 1
    Hw.pw := 0
    Hw.ph := 0
    Hw.pic := ""
    Hw.names := ["Get started", "Fingers", "English", "Bangla", "Tutorials", "About"]
    texts := [TutorialText(), FingerText(), EnglishText(), BanglaText(), TutorialsText(), AboutTabText()]
    Hw.tab := g.Add("Tab3", "x10 y10 w700 h400", Hw.names)
    for i, tx in texts {
        Hw.tab.UseTab(i)
        if (i = 2)
            Hw.pic := g.Add("Picture", "x20 y40 w300 h200 0xE")
        e := g.Add("Edit", "x20 y40 w600 h300 ReadOnly Multi +VScroll BackgroundWhite", "")
        e.Value := tx
        if (i = 6)
            e.SetFont("s9", "Consolas")
        SendMessage(0x00B1, 0, 0, e.Hwnd)          ; EM_SETSEL 0,0: nothing selected
        Hw.eds.Push(e)
    }
    Hw.tab.UseTab(0)
    Hw.btns := []
    Hw.btns.Push(g.Add("Button", "x600 y420 w90 h30", "Close"))
    Hw.btns[1].OnEvent("Click", HwClose)
    Hw.link := g.Add("Text", "x10 y426 w170 h22 0x200 0x100 cBlue", "Open settings folder")
    Hw.link.SetFont("s9 underline", "Segoe UI")
    Hw.link.OnEvent("Click", OpenDataDir)
    Hw.link.Visible := false
    Hw.tab.OnEvent("Change", HwTabChange)
    g.OnEvent("Size", HwSize)
    g.OnEvent("Close", HwClose)
    g.OnEvent("Escape", HwClose)
    g.Show("w" . Round(750 * d) . " h" . Round(500 * d))
    cw := 0
    ch := 0
    g.GetClientPos(, , &cw, &ch)
    HwLayout(cw, ch)
}

HwTabChange(*) {
    Hw.cur := Hw.tab.Value
    Hw.link.Visible := (Hw.cur = 6)         ; the settings folder link belongs to the About tab only
    if (Hw.cur >= 1 && Hw.cur <= Hw.eds.Length) {
        HwRefreshScroll(Hw.eds[Hw.cur])
        SetTimer(HwRefreshCur, -30)
    }
}

HwRefreshCur() {
    if (IsObject(Hw.g) && Hw.cur >= 1 && Hw.cur <= Hw.eds.Length)
        HwRefreshScroll(Hw.eds[Hw.cur])
}

; An edit that was resized while hidden never works out its scroll range, so a page that is shown
; later would have no scrollbar and no mouse wheel. A real resize (one pixel and back) while the
; page is visible makes the edit recalculate it.
HwRefreshScroll(e) {
    x := 0
    y := 0
    w := 0
    h := 0
    e.GetPos(&x, &y, &w, &h)
    if (w < 20 || h < 20)
        return
    e.Move(x, y, w, h - 1)
    e.Move(x, y, w, h)
    DllCall("RedrawWindow", "Ptr", e.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x405)
}

HwSize(g, minMax, w, h) {
    if (minMax = -1)
        return
    HwLayout(w, h)
}

HwLayout(w, h) {
    if (!IsObject(Hw.g) || Hw.eds.Length = 0 || Hw.btns.Length < 1)
        return
    d := A_ScreenDPI / 96
    m := Round(10 * d)
    pad := Round(6 * d)
    tw := Max(100, w - 2 * m)
    th := Max(100, h - m - Round(50 * d))
    Hw.tab.Move(m, m, tw, th)
    rc := Buffer(16, 0)                                    ; the page area inside the tab control
    NumPut("Int", 0, "Int", 0, "Int", tw, "Int", th, rc)
    SendMessage(0x1328, 0, rc, Hw.tab.Hwnd)                ; TCM_ADJUSTRECT
    cl := m + NumGet(rc, 0, "Int") + pad
    ct := m + NumGet(rc, 4, "Int") + pad
    cw := Max(50, NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int") - 2 * pad)
    full := Max(50, NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int") - 2 * pad)
    ph := Round(full * 0.62)
    gap := Round(6 * d)
    for i, e in Hw.eds {
        if (i = 2)
            e.Move(cl, ct + ph + gap, cw, Max(40, full - ph - gap))
        else
            e.Move(cl, ct, cw, full)
    }
    if IsObject(Hw.pic) {
        Hw.pic.Move(cl, ct, cw, ph)
        if (cw != Hw.pw || ph != Hw.ph) {
            Hw.pw := cw
            Hw.ph := ph
            HwDrawFingers()
        }
    }
    y := h - Round(40 * d)
    Hw.btns[1].Move(w - m - Round(90 * d), y, Round(90 * d), Round(30 * d))
    Hw.link.Move(m, y + Round(4 * d), Round(170 * d), Round(22 * d))
    if (Hw.cur >= 1 && Hw.cur <= Hw.eds.Length)
        HwRefreshScroll(Hw.eds[Hw.cur])
}

; the keyboard / finger picture (a PNG kept inside this script), loaded once
FingerImg() {
    static img := 0
    static stm := 0
    if img
        return img
    GdipStart()
    n := 0
    b64 := FingerB64()
    DllCall("crypt32\CryptStringToBinaryW", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &n, "Ptr", 0, "Ptr", 0)
    if (n < 100)
        return 0
    buf := Buffer(n, 0)
    DllCall("crypt32\CryptStringToBinaryW", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", buf, "UInt*", &n, "Ptr", 0, "Ptr", 0)
    hg := DllCall("GlobalAlloc", "UInt", 2, "UPtr", n, "Ptr")
    p := DllCall("GlobalLock", "Ptr", hg, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", p, "Ptr", buf, "UPtr", n)
    DllCall("GlobalUnlock", "Ptr", hg)
    DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hg, "Int", true, "Ptr*", &stm)       ; the stream must stay alive as long as the image
    DllCall("gdiplus\GdipCreateBitmapFromStream", "Ptr", stm, "Ptr*", &img)
    return img
}

HwDrawFingers() {
    if (!IsObject(Hw.pic) || Hw.pw < 100 || Hw.ph < 60)
        return
    GdipStart()
    t := Th.cur
    W := Hw.pw
    H := Hw.ph
    bmp := 0
    G := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &G)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", G, "Int", 4)
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", G, "Int", 7)       ; high quality bicubic
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", G, "Int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", G, "UInt", 0xFFFFFFFF)
    img := FingerImg()
    if img {
        iw := 0
        ih := 0
        DllCall("gdiplus\GdipGetImageWidth", "Ptr", img, "UInt*", &iw)
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", img, "UInt*", &ih)
        if (iw > 0 && ih > 0) {
            sc := Min(W / iw, H / ih)                                     ; fit the whole picture, keep its shape
            dw := iw * sc
            dh := ih * sc
            DllCall("gdiplus\GdipDrawImageRect", "Ptr", G, "Ptr", img, "Float", (W - dw) / 2, "Float", (H - dh) / 2, "Float", dw, "Float", dh)
        }
    }
    hbm := 0
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bmp, "Ptr*", &hbm, "UInt", 0xFFFFFFFF)
    old := SendMessage(0x172, 0, hbm, Hw.pic.Hwnd)          ; STM_SETIMAGE, IMAGE_BITMAP
    if old
        DllCall("DeleteObject", "Ptr", old)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", G)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
}

FingerText() {
    t := "WHICH FINGER TYPES WHICH KEY`r`n`r`n"
    t .= "Each colour in the picture is one finger: the coloured nails on the hands show which finger presses the keys of the same colour. Your fingers rest on the HOME ROW: A S D F for the left hand and J K L `; for the right hand. The small bumps on F and J are there so that your index fingers can find home without looking.`r`n`r`n"
    t .= "LEFT HAND`r`n"
    t .= "  Pinky          1  Q  A  Z   (also Tab, Caps Lock, left Shift)`r`n"
    t .= "  Ring finger    2  W  S  X`r`n"
    t .= "  Middle finger  3  E  D  C`r`n"
    t .= "  Index finger   4  5  R  T  F  G  V  B`r`n`r`n"
    t .= "RIGHT HAND`r`n"
    t .= "  Index finger   6  7  Y  U  H  J  N  M`r`n"
    t .= "  Middle finger  8  I  K  ,`r`n"
    t .= "  Ring finger    9  O  L  .`r`n"
    t .= "  Pinky          0  -  =  P  [  ]  \  `;  '  /   (also Enter, Backspace, right Shift)`r`n`r`n"
    t .= "THUMBS`r`n"
    t .= "  Either thumb presses the Space bar. Most people use the thumb of the stronger hand.`r`n`r`n"
    t .= "HOW TO USE THIS`r`n"
    t .= "  - Rest your fingers on the home row. Reach for a key with its own finger, then come straight back home.`r`n"
    t .= "  - Index fingers cover two columns each (4 5 and 6 7 on the number row, and so on).`r`n"
    t .= "  - Shift: press the Shift key on the OPPOSITE side of the letter you want as a capital.`r`n"
    t .= "  - Do not look at the keys. Look at the text on the screen."
    return t
}

EnglishText() {
    t := "HOW TO START TYPING IN ENGLISH`r`n`r`n"
    t .= "1. THE KEYBOARD`r`n"
    t .= "Most keyboards use the QWERTY layout (the first six letters on the top row). If your computer has more than one language, make sure English is selected: press Windows key + Space to switch the keyboard language, or look at the language code (ENG) at the right end of the taskbar.`r`n`r`n"
    t .= "2. SET UP THE PROGRAM`r`n"
    t .= "  - In the right panel, under 'Text file', choose 'Beginner English' to follow the lessons, or 'English' for normal paragraphs.`r`n"
    t .= "  - Choose a test time. 1 minute is a good start for a beginner.`r`n"
    t .= "  - A clear font such as Segoe UI or Consolas, size 18 or bigger, is easy to read.`r`n`r`n"
    t .= "3. LEARN IN THIS ORDER`r`n"
    t .= "  a) Home row: a s d f  j k l `;`r`n"
    t .= "  b) Add e and i, then the whole top row: q w e r t y u i o p`r`n"
    t .= "  c) Bottom row: z x c v b n m , .`r`n"
    t .= "  d) Capital letters with Shift (opposite hand)`r`n"
    t .= "  e) Punctuation: . , ? ! ' `" : `;`r`n"
    t .= "  f) Numbers 1 2 3 4 5 6 7 8 9 0`r`n"
    t .= "Do not move to the next step until the current one feels comfortable. See the Fingers tab for which finger presses which key.`r`n`r`n"
    t .= "4. A DAILY ROUTINE (15 to 20 minutes)`r`n"
    t .= "  - 5 minutes: warm up with the exercise text at a slow, easy speed.`r`n"
    t .= "  - 10 minutes: two or three 1-minute tests with normal paragraphs.`r`n"
    t .= "  - 2 minutes: look at the Results tab and note which kind of mistake you make most.`r`n`r`n"
    t .= "5. TARGETS`r`n"
    t .= "  Accuracy first: 95% or more. Then speed. A beginner at 15 to 20 WPM is normal. 30 to 40 WPM is good for office work. 50 WPM and above is fast.`r`n`r`n"
    t .= "6. COMMON PROBLEMS`r`n"
    t .= "  - Capital letters everywhere: Caps Lock is on (the program shows a warning at the top).`r`n"
    t .= "  - Your letters turn red but look right: check the keyboard language and the text file font.`r`n"
    t .= "  - You look at your hands: cover the keys with a cloth or just keep your eyes on the text.`r`n"
    t .= "  - Your hands feel tired: take a short break, relax your shoulders and keep your wrists straight."
    return t
}

BanglaText() {
    t := "HOW TO START TYPING IN BANGLA (FOR BEGINNERS)`r`n`r`n"
    t .= "1. WHAT YOU NEED`r`n"
    t .= "To type Bangla you need a Bangla keyboard on your computer. The program only compares what you type with the text; the keyboard itself is your choice. There are two main kinds:`r`n"
    t .= "  - PHONETIC (for example Avro Keyboard): you type Bangla sounds with English letters, so typing 'ami' gives the Bangla word for 'I'. It is the easiest to start with.`r`n"
    t .= "  - FIXED LAYOUT (for example Bijoy, or the National / Jatiya layout): every Bangla letter has its own key. It is faster once learned and common in offices. Letters sit on fixed keys, so the finger rules in the Fingers tab apply the same way.`r`n"
    t .= "Windows also comes with its own Bangla keyboards: add Bangla in Settings > Time and language > Language and region, then switch with Windows key + Space.`r`n`r`n"
    t .= "2. UNICODE OR ANSI?`r`n"
    t .= "  - Most modern texts are UNICODE. They need a Unicode Bangla keyboard and a font like Nirmala UI or Kalpurush.`r`n"
    t .= "  - Old Bijoy-style files are ANSI (the file name contains 'ANSI'). They need an ANSI Bijoy keyboard and a font such as SutonnyMJ.`r`n"
    t .= "Match the text file, the font and the keyboard. If they do not match, the letters will look wrong or turn red.`r`n`r`n"
    t .= "3. SET UP THE PROGRAM`r`n"
    t .= "  - Under 'Text file' choose a Bangla file (for example 'Bangla').`r`n"
    t .= "  - Under 'Font and size' choose a Bangla font and a size of 20 or more. The program remembers it for each file.`r`n"
    t .= "  - Switch your keyboard to Bangla, click in the typing box and start.`r`n"
    t .= "  - Under 'Count words by' you can choose 'Real words', a fairer count for Bangla.`r`n`r`n"
    t .= "4. HOW BANGLA LETTERS WORK`r`n"
    t .= "  - A consonant carries the vowel 'o' by itself. A vowel sign (kar) changes it, and is typed AFTER the consonant, even when it is drawn before it on the screen.`r`n"
    t .= "  - Two consonants can join into one shape (a conjunct, juktakkhor). On most keyboards you type the first consonant, the hasanta (virama) key, then the second consonant.`r`n"
    t .= "  - A few letters can be stored in two ways by different keyboards. The program treats both forms as the same, but if a letter that looks right is shown red, re-type that text in the file with your own keyboard.`r`n`r`n"
    t .= "5. LEARN IN SMALL STEPS`r`n"
    t .= "  a) Start with the home row letters of your layout.`r`n"
    t .= "  b) Practise single letters, then short words with no conjuncts.`r`n"
    t .= "  c) Add vowel signs, then the common conjuncts.`r`n"
    t .= "  d) Move to short sentences, then to full paragraphs.`r`n"
    t .= "Use 'Add text...' to put your own practice words into a file, one paragraph at a time.`r`n`r`n"
    t .= "6. TIPS`r`n"
    t .= "  - Accuracy first, speed later. Aim for 95% accuracy before you push the speed.`r`n"
    t .= "  - Short 1-minute tests every day are better than one long test a week.`r`n"
    t .= "  - Fix mistakes with Backspace as soon as you see a red letter."
    return t
}

TutorialsText() {
    t := "CUSTOMIZE THE PROGRAM TO HOW YOU WANT TO PRACTISE`r`n`r`n"
    t .= "Everything below is on the right panel of the main window unless it says otherwise. Rest the mouse on any option for a short tip.`r`n`r`n"
    t .= "CHOOSE WHAT TO PRACTISE`r`n"
    t .= "  Test duration         30 seconds to 15 minutes, or No timer (a stopwatch for beginners: no time limit, it shows how long you took to finish the paragraph).`r`n"
    t .= "  Text file             The language / lesson file. Each .dat file is one list of paragraphs.`r`n"
    t .= "  Paragraph             Random, or one particular paragraph. Lines starting with # name a paragraph.`r`n"
    t .= "  Punctuation, Numbers  Practise only with marks, without marks, or with numbers.`r`n"
    t .= "  Count words by        Standard (5 characters = 1 word) or Real words.`r`n"
    t .= "  When a paragraph is finished early   Load the next one, repeat it, show the result, restart, or ask every time.`r`n`r`n"
    t .= "CHOOSE HOW IT LOOKS`r`n"
    t .= "  Font and size, Text direction, File encoding (set for each file and remembered)`r`n"
    t .= "  Theme                 Nine colour themes.`r`n"
    t .= "  Hide panel            Clear view with only the text and the typing box.`r`n"
    t .= "  Drag bar              Drag the dotted bar to make the text or the typing box bigger.`r`n"
    t .= "  Ctrl + mouse wheel    Over the typing box: text bigger or smaller.`r`n"
    t .= "  Interface size        In Settings: Normal or Large (after a restart).`r`n`r`n"
    t .= "SETTINGS (top right)`r`n"
    t .= "  - Change every hotkey, or reset them.`r`n"
    t .= "  - Turn hover tips on or off.`r`n"
    t .= "  - Choose whether this Info window opens every time the program starts.`r`n`r`n"
    t .= "-----------------------------------------------------------`r`n`r`n"
    t .= HelpText()
    return t
}

AboutTabText() {
    return AboutText() . "`r`n`r`n-----------------------------------------------------------`r`n`r`nTECHNICAL INFORMATION`r`n`r`n" . InfoText()
}

OpenDataDir(*) {
    try DirCreate(App.dataDir)
    try Run('explorer.exe "' . App.dataDir . '"')
}

HwClose(*) {
    if !IsObject(Hw.g)
        return true
    g := Hw.g
    Hw.g := ""
    Hw.link := ""
    Hw.eds := []
    Ui.g.Opt("-Disabled")
    try g.Destroy()
    try WinActivate("ahk_id " . Ui.g.Hwnd)
    FocusInput()
    return true
}

ExerciseText() {
    t := "fff jjj ddd kkk sss lll aaa `;;; fj fj dk dk sl sl a; a; fj dk sl a; fj dk sl a; asdf jkl; asdf jkl; jf kd ls `;a jf kd ls `;a fdsa `;lkj fdsa `;lkj`r`n`r`n"
    t .= "ask dad fall sad lad flask salad alfalfa a lad asks dad; dad falls; sad lass asks a lad; all fall flask; a salad; fads; lads add; ask a lass; dad has a flask; a glad lad had a salad`r`n`r`n"
    t .= "he she see seed side life file kind lead field fish desk like kids ride hide sleek jelly; she likes fresh dill; he fed the elf; fill the field; see a kid ride; she held a kind knife`r`n`r`n"
    t .= "quiet power write tower pirate report trouble you our out top try yet yours; the quick type; try your pen; write the report; your top priority; require a quote; we were true to our word`r`n`r`n"
    t .= "zebra voice name black number vision cabin mix climb cave zoom exam mom bomb; a brave man; come back; become vivid; zoom in; mix ink; a calm moon; nine boxes; bring back the van`r`n`r`n"
    t .= "The Quick Brown Fox Jumps Over The Lazy Dog. Anna, Ben, and Carla went to Paris; Dan stayed home. Is it true? Yes! `"Maybe,`" she said. It's John's book - and it's very good.`r`n`r`n"
    t .= "1 2 3 4 5 6 7 8 9 0 12 34 56 78 90 2024 1999 3.14 10:30 5% $25.50 (12 + 8) = 20, 7 x 6 = 42, item #15 at 4 pm, room 301-B, call 555-0147.`r`n`r`n"
    t .= "Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump! The five boxing wizards jump quickly. Sphinx of black quartz, judge my vow. Amazingly few discotheques provide jukeboxes.`r`n"
    return t
}

AboutText() {
    t := "TYPING TUTOR`r`n`r`n"
    t .= "A typing test and practice program for English, Bangla, Hindi, Arabic and any other language that you can put in a text file.`r`n`r`n"
    t .= "Version: 2.1.8`r`n"
    t .= "Built with AutoHotkey v" . A_AhkVersion . "`r`n`r`n"
    t .= "WHAT IT GIVES YOU`r`n`r`n"
    t .= "  - Timed tests from 30 seconds to 15 minutes with a live countdown`r`n"
    t .= "  - One paragraph at a time from your own text files, random or chosen by you`r`n"
    t .= "  - You choose what happens when a paragraph is finished early`r`n"
    t .= "  - Green for correct letters, red for wrong letters`r`n"
    t .= "  - Speed (WPM), accuracy, mistakes, a result page, and a saved history of every test`r`n"
    t .= "  - Any encoding (UTF-8, UTF-16, ANSI) and any font, remembered for each file`r`n"
    t .= "  - Nine themes: Dark, Light, Gray, Blue, Green, Purple, Orange, Rose and Teal`r`n"
    t .= "  - Punctuation and number options, and your own hotkeys (Settings)`r`n"
    t .= "  - Hover tips on every option, and a clear view: hide the right panel`r`n"
    t .= "  - Add text, and remove text you do not want, from inside the program`r`n  - An Info window with guides: getting started, finger placement picture, English and Bangla beginner guides`r`n`r`n"
    t .= "WHERE THINGS ARE SAVED`r`n`r`n"
    t .= "  Program texts:  " . App.dir . "`r`n"
    t .= "  Your texts:     " . App.cdir . "`r`n"
    t .= "  Settings:       " . App.ini . "`r`n"
    t .= "  History:        " . App.hist . "`r`n`r`n"
    t .= "Your texts, the settings and the history live in %AppData%\Bangla Keyboard, next to the settings of the Docs Converter. They stay there when the program is removed."
    return t
}

TutorialText() {
    t := "HOW TO GET STARTED WITH TYPING`r`n`r`n"
    t .= "Typing without looking at the keyboard is called touch typing. It is a skill, not a talent: anybody can learn it with a little calm practice every day. Once you have it, you write faster, make fewer mistakes, and your eyes stay on the screen instead of your hands.`r`n`r`n"
    t .= "The secret is simple: accuracy first, speed later. If you type slowly and correctly, your fingers learn the right paths across the keyboard, and speed comes by itself. If you rush and make mistakes, you teach your fingers the wrong paths.`r`n`r`n"
    t .= "Below are the steps in the order to learn them. Look at the Fingers tab to see which finger belongs to which key, then the English or Bangla tab for the language you want.`r`n`r`n"
    t .= "A ready-made practice file called 'Beginner English' is in your Text file list. Choose it there; it follows the steps of this tutorial.`r`n`r`n"
    t .= "STEP 0 - SIT RIGHT`r`n"
    t .= "Sit straight, feet flat, screen at eye level. Keep your wrists relaxed and a little above the table. Do not look at the keys; look at the text.`r`n`r`n"
    t .= "STEP 1 - THE HOME ROW`r`n"
    t .= "Left hand rests on A S D F, right hand on J K L `;. The little bumps on F and J let your index fingers find home without looking. Thumbs rest on the space bar. Always return to the home row after reaching for another key.`r`n`r`n"
    t .= "   Left hand:  pinky A, ring S, middle D, index F (and G)`r`n"
    t .= "   Right hand: index J (and H), middle K, ring L, pinky `;`r`n`r`n"
    t .= "STEP 2 - HOME ROW WORDS`r`n"
    t .= "Type words like: ask, dad, fall, sad, salad, flask. Go slowly. Accuracy first.`r`n`r`n"
    t .= "STEP 3 - ADD E AND I, THEN THE TOP ROW`r`n"
    t .= "E is typed with the left middle finger (D), I with the right middle finger (K). The top row Q W E R T Y U I O P is reached by moving each finger straight up, then back home.`r`n`r`n"
    t .= "STEP 4 - THE BOTTOM ROW`r`n"
    t .= "Z X C V B N M , . / - move each finger straight down, then back home.`r`n`r`n"
    t .= "STEP 5 - CAPITALS AND PUNCTUATION`r`n"
    t .= "Use the Shift key on the OPPOSITE side of the letter: left Shift for letters typed by the right hand, right Shift for the left hand. Practise commas, full stops, question marks and quotes.`r`n`r`n"
    t .= "STEP 6 - NUMBERS AND SYMBOLS`r`n"
    t .= "The number row is one more row up. Practise it slowly, a few keys at a time.`r`n`r`n"
    t .= "STEP 7 - BUILD SPEED`r`n"
    t .= "Use a 1-minute test. Keep accuracy at 95% or more, then push the speed a little. Read the next word before you finish the current one. Do not stare at your mistakes; fix them and move on.`r`n`r`n"
    t .= "A GOOD PLAN`r`n"
    t .= "  Week 1: steps 1 and 2, 10 minutes every day`r`n"
    t .= "  Week 2: steps 3 and 4`r`n"
    t .= "  Week 3: steps 5 and 6`r`n"
    t .= "  Week 4 and later: step 7 with your own texts, 1 to 5 minute tests`r`n`r`n"
    t .= "BANGLA AND OTHER LANGUAGES`r`n"
    t .= "The same rules apply. See the Bangla tab for a beginner guide, and use 'Add text...' to add your own practice paragraphs."
    return t
}

InfoText() {
    t := Format("  Script folder   {}`r`n", A_ScriptDir)
    t .= Format("  AutoHotkey      v{}`r`n", A_AhkVersion)
    t .= Format("  Windows         {}`r`n", A_OSVersion)
    t .= Format("  Screen DPI      {}`r`n`r`n", A_ScreenDPI)
    t .= Format("  Program texts   {}`r`n", App.dir)
    t .= Format("  Your texts      {}`r`n", App.cdir)
    t .= Format("  Text files      {}`r`n", ListFiles().Length)
    t .= Format("  Settings file   {}`r`n", App.ini)
    t .= Format("  History file    {}`r`n`r`n", App.hist)
    t .= Format("  File            {}`r`n", St.fileName)
    t .= Format("  Paragraphs      {}  (of {} in the file)`r`n", St.paras.Length, St.raw.Length)
    t .= Format("  Font            {}  {} pt`r`n", Ui.face, Ui.fsize)
    t .= Format("  Theme           {}`r`n`r`n", Th.cname)
    for a in Hk.acts {
        k := HkKey(a[1])
        lab := (k = "") ? "(none)" : HkLabel(k)
        t .= "  " . lab . SubStr("                    ", 1, Max(1, 18 - StrLen(lab))) . a[2] . "`r`n"
    }
    t .= "  (change them in Settings)`r`n"
    t .= "  Delete          delete the selected results (History tab)`r`n"
    t .= "  Ctrl+F, F3      find / find next (in the text windows)`r`n"
    t .= "  Ctrl+S          save (in the text windows)`r`n"
    return t
}

; ===========================================================================
;  Hotkeys (Settings window) - the keys are stored in the [Hotkeys] part of the settings file
; ===========================================================================
HkInit() {
    Hk.acts := [["Next", "Next text", "F5", (*) => PrepareTest(false)]
        , ["Restart", "Restart the same text", "F6", (*) => PrepareTest(true)]
        , ["Finish", "Finish test (show result)", "F8", (*) => EndTest(true)]
        , ["Panel", "Hide / show right panel", "F4", (*) => TogglePanel()]
        , ["Settings", "Open Settings", "F2", (*) => OpenSettings()]
        , ["Help", "Open Info window", "F1", (*) => OpenHelp()]
        , ["Theme", "Switch to next theme", "F7", (*) => NextTheme()]
        , ["Bigger", "Typing text bigger", "^Up", (*) => TextZoom(1)]
        , ["Smaller", "Typing text smaller", "^Down", (*) => TextZoom(-1)]
        , ["TabTest", "Go to the Test tab", "^1", (*) => ShowTab(1)]
        , ["TabRes", "Go to the Results tab", "^2", (*) => ShowTab(2)]
        , ["TabHist", "Go to the History tab", "^3", (*) => ShowTab(3)]
        , ["AddTxt", "Add text...", "", (*) => OpenAddText()]
        , ["EditTxt", "Edit text...", "", (*) => OpenEditText()]]
}

HkOn(*) {
    return IsObject(Ui.g) && WinActive("ahk_id " . Ui.g.Hwnd)
}

; (re)registers every hotkey: they work while the main window is active
ApplyHotkeys() {
    HotIf(HkOn)
    for id, k in Hk.cur {
        if (k != "") {
            try Hotkey("$" . k, "Off")
        }
    }
    Hk.cur := Map()
    for a in Hk.acts {
        v := Ini("Hotkeys", a[1], a[3])
        k := (v = "none") ? "" : v
        Hk.cur[a[1]] := k
        if (k != "") {
            try Hotkey("$" . k, a[4], "On")
        }
    }
    HotIf()
    RefreshKeyLabels()
}

HkKey(id) {
    if Hk.cur.Has(id)
        return Hk.cur[id]
    for a in Hk.acts {
        if (a[1] = id)
            return a[3]
    }
    return ""
}

; readable name of a key, for example ^Up -> Ctrl+Up
HkLabel(k) {
    base := RegExReplace(k, "^[\^!+#<>*~$]+")
    mods := SubStr(k, 1, StrLen(k) - StrLen(base))
    s := ""
    if InStr(mods, "^")
        s .= "Ctrl+"
    if InStr(mods, "!")
        s .= "Alt+"
    if InStr(mods, "+")
        s .= "Shift+"
    if InStr(mods, "#")
        s .= "Win+"
    return s . base
}

HkOr(id, alt) {
    k := HkKey(id)
    return (k = "") ? alt : HkLabel(k)
}

HkSfx(id) {
    k := HkKey(id)
    return (k = "") ? "" : "  (" . HkLabel(k) . ")"
}

HkSummary() {
    s := ""
    for a in Hk.acts {
        k := HkKey(a[1])
        if (k != "")
            s .= (s = "" ? "" : ", ") . HkLabel(k) . " = " . StrLower(SubStr(a[2], 1, 1)) . SubStr(a[2], 2)
    }
    return (s = "") ? "none set" : s
}

; a hotkey must not disturb normal typing: F-keys, or Ctrl / Alt / Win with another key
HkCheck(k) {
    base := RegExReplace(k, "^[\^!+#<>*~$]+")
    mods := SubStr(k, 1, StrLen(k) - StrLen(base))
    if RegExMatch(base, "i)^F\d{1,2}$")
        return ""
    if (InStr(mods, "^") || InStr(mods, "!") || InStr(mods, "#"))
        return ""
    return "use an F-key, or Ctrl / Alt together with another key, so that normal typing is not disturbed."
}

RefreshKeyLabels() {
    Ui.btnNew.Text := "Next" . HkSfx("Next")
    Ui.btnRestart.Text := "Restart same" . HkSfx("Restart")
    Ui.rBtnNext.Text := "Next text" . HkSfx("Next")
    Ui.rBtnAgain.Text := "Restart same text" . HkSfx("Restart")
}

NextTheme(*) {
    n := Ui.ddTheme.Value + 1
    if (n > Th.names.Length)
        n := 1
    Ui.ddTheme.Choose(n)
    OnTheme()
}

TextZoom(dir) {
    idx := Ui.ddSize.Value
    if (idx < 1)
        idx := 1
    n := Max(1, Min(Ui.sizes.Length, idx + dir))
    if (n != idx) {
        Ui.ddSize.Choose(n)
        FontApply()
    }
}

; ===========================================================================
;  Hover tips: rest the mouse on a control for a moment
; ===========================================================================
Tip(ctrl, text, id := "") {
    Tp.list.Push([ctrl, text, id])
}

TipText(it) {
    s := it[2]
    if IsObject(s)
        s := s.Call()
    if (it[3] != "") {
        k := HkKey(it[3])
        if (k != "")
            s .= "`nHotkey: " . HkLabel(k)
    }
    return s
}

TipHide() {
    ToolTip()
    Tp.cur := 0
    Tp.shown := false
}

TipTick() {
    CoordMode("Mouse", "Screen")
    if (!Tp.on || !IsObject(Ui.g)) {
        if (Tp.cur != 0)
            TipHide()
        return
    }
    if DllCall("IsIconic", "Ptr", Ui.g.Hwnd) {              ; minimized: nothing to show, do no work
        if (Tp.cur != 0)
            TipHide()
        return
    }
    mx := 0
    my := 0
    win := 0
    try {
        MouseGetPos(&mx, &my, &win)
    } catch
        return
    hit := 0
    org := Map()
    dead := []
    for i, it in Tp.list {
        try {
            c := it[1]
            if (c.Gui.Hwnd != win || !c.Visible)
                continue
            if !org.Has(win) {
                WinGetClientPos(&ox, &oy, , , "ahk_id " . win)
                org[win] := [ox, oy]
            }
            c.GetPos(&cx, &cy, &cw, &ch)
            ax := org[win][1] + cx
            ay := org[win][2] + cy
            if (mx >= ax && mx < ax + cw && my >= ay && my < ay + ch) {
                hit := it
                break
            }
        } catch {
            dead.Push(i)
        }
    }
    Loop dead.Length
        Tp.list.RemoveAt(dead[dead.Length - A_Index + 1])
    if !IsObject(hit) {
        if (Tp.cur != 0)
            TipHide()
        return
    }
    hw := hit[1].Hwnd
    if (hw != Tp.cur) {
        TipHide()
        Tp.cur := hw
        Tp.since := A_TickCount
        return
    }
    if GetKeyState("LButton", "P") {
        ToolTip()
        Tp.shown := true
        return
    }
    if (!Tp.shown && A_TickCount - Tp.since >= 600) {
        ToolTip(TipText(hit))
        Tp.shown := true
        Tp.since := A_TickCount
    } else if (Tp.shown && A_TickCount - Tp.since >= 9000) {
        ToolTip()
    }
}

RegisterTips() {
    Tip(Ui.tabs[1], "Test: the text to type and the typing box.", "TabTest")
    Tip(Ui.tabs[2], "Results: speed, accuracy and details of your last test.", "TabRes")
    Tip(Ui.tabs[3], "History: every test you have finished.", "TabHist")
    Tip(Ui.btnPanel, "Hide or show the options panel on the right, for a clear view.", "Panel")
    Tip(Ui.lnkSettings, "Settings: hotkeys, hover tips and interface size.", "Settings")
    Tip(Ui.btnHelp, "Info: how to start, finger guide, English and Bangla guides, tutorials and about.", "Help")
    Tip(Ui.lblTimer, "Time left in this test (with 'No timer': the stopwatch, counting up). It starts with your first key.")
    Tip(Ui.lblWpm, "Live speed in words per minute.")
    Tip(Ui.lblAcc, "Live accuracy: the share of keys that were right.")
    Tip(Ui.lblWords, "Number of correctly typed words.")
    Tip(Ui.lblCaps, "Caps Lock is on: letters will be typed as capitals.")
    Tip(Ui.rich, "The text to type. Green letters are correct, red letters are wrong.")
    Tip(Ui.split, "Drag this bar up or down to give more room to the text or to the typing box.")
    Tip(Ui.edIn, "Type the text here. The mouse wheel scrolls the box; Ctrl + wheel makes the text bigger or smaller.")
    Tip(Ui.rPic, "The result of your last test.")
    Tip(Ui.rBtnNext, "Start a new test with the next text.", "Next")
    Tip(Ui.rBtnAgain, "Start a new test with the same text again.", "Restart")
    Tip(Ui.lv, "Your saved tests, newest first. Ctrl or Shift + click to select several rows.")
    Tip(Ui.btnDelSel, "Delete the selected rows from the history (the Delete key does the same).")
    Tip(Ui.btnClear, "Delete the whole history.")
    Tip(Ui.lblBest, "How many tests you did, your best speed and your average speed.")
    Tip(Ui.btnNew, "Start a new test with the next (or a random) paragraph.", "Next")
    Tip(Ui.btnRestart, "Start a new test with the same paragraph.", "Restart")
    Tip(Ui.btnReload, "Read the text folders again (use it after you add .dat files by hand).")
    Tip(Ui.btnAddTxt, "Add your own practice text to a file.", "AddTxt")
    Tip(Ui.btnEditTxt, "Edit or delete text in a file.", "EditTxt")
    ; each heading shares the tip of the option under it
    pairs := [[Ui.ddDur, "How long each test lasts. Choose 'No timer' for a stopwatch: no time limit, it counts how long you take to finish the paragraph. Changing it restarts the test."]
        , [Ui.ddFile, "The text file (language) to practise with."]
        , [Ui.ddPara, "Random paragraph, or pick one particular paragraph to practise."]
        , [Ui.ddPunct, "Punctuation in the typing text.`nAs in the text: nothing changes.`nBasic marks only: keeps . , ? ! ' quotes : `; - and drops other symbols.`nNo punctuation: only letters and words.`nRich punctuation: only paragraphs with many different marks.`nNot used for ANSI texts."]
        , [Ui.ddNum, "Numbers in the typing text.`nAs in the text: nothing changes.`nNo numbers: only paragraphs without numbers.`nWith numbers: only paragraphs that contain numbers.`nIf no paragraph fits, nothing is shown."]
        , [Ui.ddEnc, "How the text file is read. Auto detect works for most files; choose by hand if the letters look wrong."]
        , [Ui.cbFont, "The font of the typing text. ANSI texts (for example SutonnyMJ) need their own font. Remembered for each file."]
        , [Ui.ddDir, "Direction of the text: Auto, left to right, or right to left (Arabic, Urdu ...)."]
        , [Ui.ddWpm, "Standard: correct characters / 5 per minute. Real words: only fully correct words are counted."]
        , [Ui.ddFin, "What happens when you finish the paragraph before the time ends."]
        , [Ui.ddTheme, "The colours of the program."]]
    for i, pr in pairs {
        Tip(pr[1], pr[2])
        if (i <= Ui.heads.Length)
            Tip(Ui.heads[i], pr[2])
    }
    Tip(Ui.ddSize, "The size of the typing text. Ctrl + mouse wheel over the typing box does the same.")
}

; ===========================================================================
;  Settings window: hotkeys, hover tips, interface size
; ===========================================================================
OpenSettings(*) {
    if (IsObject(Sw.g) || IsObject(Hw.g) || IsObject(Ew.g) || IsObject(Pp.g) || IsObject(Fw.g))
        return
    TipHide()
    Ui.g.Opt("+Disabled")
    t := Th.cur
    g := NewWin("Settings - " . App.title, 700, 560, Ui.g.Hwnd)
    Sw.g := g
    Sw.hk := Map()
    hd := g.Add("Text", "x" . Sd(16) . " y" . Sd(12) . " w" . Sd(400) . " h" . Sd(26) . " 0x200", "HOTKEYS")
    hd.SetFont("s10 w700 c" . Hx(t.accent), "Segoe UI")
    g.Add("Text", "x" . Sd(16) . " y" . Sd(40) . " w" . Sd(668) . " h" . Sd(44), "Click a box, then press the keys you want. Backspace clears a box (no hotkey). Use an F-key, or Ctrl / Alt together with another key, so that normal typing is never disturbed.")
    per := Ceil(Hk.acts.Length / 2)
    for i, a in Hk.acts {
        col := (i > per) ? 1 : 0
        row := (i > per) ? (i - per - 1) : (i - 1)
        cx := Sd(16) + col * Sd(340)
        cy := Sd(90) + row * Sd(36)
        g.Add("Text", "x" . cx . " y" . cy . " w" . Sd(178) . " h" . Sd(26) . " 0x200", a[2])
        e := g.Add("Hotkey", "x" . (cx + Sd(180)) . " y" . cy . " w" . Sd(140) . " h" . Sd(26), HkKey(a[1]))
        Sw.hk[a[1]] := e
        Tip(e, "Press the keys for:  " . a[2] . "`nBackspace clears the box.  Default: " . ((a[3] = "") ? "none" : HkLabel(a[3])))
    }
    gy := Sd(90) + per * Sd(36) + Sd(6)
    b := WinBtn(g, "x" . Sd(16) . " y" . gy . " w" . Sd(230) . " h" . Sd(32), "Reset hotkeys to defaults", SwReset)
    Tip(b, "Put every hotkey back to its original key (nothing is saved until you press Save).")

    h2 := g.Add("Text", "x" . Sd(16) . " y" . Sd(404) . " w" . Sd(400) . " h" . Sd(26) . " 0x200", "GENERAL")
    h2.SetFont("s10 w700 c" . Hx(t.accent), "Segoe UI")
    Sw.chkTips := g.Add("CheckBox", "x" . Sd(16) . " y" . Sd(438) . " w" . Sd(668) . " h" . Sd(26) . (Tp.on ? " Checked" : ""), "Show hover tips (a short help text when you rest the mouse on an option)")
    Sw.chkInfo := g.Add("CheckBox", "x" . Sd(16) . " y" . Sd(470) . " w" . Sd(668) . " h" . Sd(26) . (Ini("Settings", "ShowInfo", "1") != "0" ? " Checked" : ""), "Show the Info window every time the program starts")
    Tip(Sw.chkInfo, "The Info window has the guides: getting started, finger placement, English, Bangla, customizing and about.")
    g.Add("Text", "x" . Sd(16) . " y" . Sd(506) . " w" . Sd(150) . " h" . Sd(26) . " 0x200", "Interface size:")
    Sw.ddScale := g.Add("DropDownList", "x" . Sd(170) . " y" . Sd(506) . " w" . Sd(170), ["Normal", "Large"])
    sc := Ini("Settings", "UiScale", "1")
    Sw.ddScale.Choose((sc = "2" || sc = "3") ? 2 : 1)
    SetCtlTheme(Sw.ddScale, "combo", t.dark)
    g.Add("Text", "x" . Sd(350) . " y" . Sd(506) . " w" . Sd(334) . " h" . Sd(26) . " 0x200", "(applies after a restart)")
    Tip(Sw.chkTips, "Turn the small help texts on or off.")
    Tip(Sw.ddScale, "Makes all the text and controls of the main window bigger. Applies after a restart.")
    WinBtn(g, "x" . Sd(450) . " y" . Sd(550) . " w" . Sd(110) . " h" . Sd(34), "Save", SwSave)
    WinBtn(g, "x" . Sd(574) . " y" . Sd(550) . " w" . Sd(110) . " h" . Sd(34), "Cancel", SwClose)
    g.OnEvent("Close", SwClose)
    g.OnEvent("Escape", SwClose)
    g.Show("w" . Sd(700) . " h" . Sd(596))
}

SwReset(*) {
    for a in Hk.acts {
        try Sw.hk[a[1]].Value := a[3]
    }
}

SwSave(*) {
    vals := Map()
    seen := Map()
    for a in Hk.acts {
        k := Sw.hk[a[1]].Value
        if (k != "") {
            msg := HkCheck(k)
            if (msg != "") {
                MsgBox(a[2] . ":  " . HkLabel(k) . " cannot be used - " . msg, App.title, "Icon!")
                return
            }
            lk := StrLower(k)
            if seen.Has(lk) {
                MsgBox(HkLabel(k) . " is set for both '" . seen[lk] . "' and '" . a[2] . "'. Please give them different keys.", App.title, "Icon!")
                return
            }
            seen[lk] := a[2]
        }
        vals[a[1]] := k
    }
    for id, k in vals
        IniPut("Hotkeys", id, (k = "") ? "none" : k)
    Tp.on := (Sw.chkTips.Value = 1)
    IniPut("Settings", "Tips", Tp.on ? "1" : "0")
    IniPut("Settings", "ShowInfo", (Sw.chkInfo.Value = 1) ? "1" : "0")
    old := Ini("Settings", "UiScale", "1")
    ns := String(Sw.ddScale.Value)
    IniPut("Settings", "UiScale", ns)
    SwClose()
    ApplyHotkeys()
    if (!Tp.on)
        TipHide()
    if (ns != old) {
        if (MsgBox("The new interface size is used after a restart.`n`nRestart now?", App.title, "YesNo Icon?") = "Yes")
            Reload()
    }
}

SwClose(*) {
    if !IsObject(Sw.g)
        return true
    g := Sw.g
    Sw.g := ""
    Sw.hk := Map()
    Ui.g.Opt("-Disabled")
    try g.Destroy()
    try WinActivate("ahk_id " . Ui.g.Hwnd)
    FocusInput()
    return true
}

; ---------------------------------------------------------------------------
;  Keys
; ---------------------------------------------------------------------------
; the main window hotkeys (F5, F6, F4, F1 ...) are set in Settings: see ApplyHotkeys()
#HotIf HistFocus()
Delete:: DeleteSelectedHistory()
#HotIf IsObject(Ew.g) && WinActive("ahk_id " . Ew.g.Hwnd)
^f:: EwFind()
F3:: EwFindNext()
#HotIf IsObject(Ew.g) && Ew.mode = "edit" && WinActive("ahk_id " . Ew.g.Hwnd)
^s:: EwSave()
#HotIf IsObject(Ew.g) && Ew.mode = "add" && WinActive("ahk_id " . Ew.g.Hwnd)
^s:: EwSaveInsert()
#HotIf

; ---------------------------------------------------------------------------
;  Finger picture (PNG, base64) used on the Fingers tab of the Info window
; ---------------------------------------------------------------------------
FingerB64() {
    return "
    (Join
iVBORw0KGgoAAAANSUhEUgAABAAAAAI8CAMAAABYqyldAAABgFBMVEX////9///7///+//3+//r7//z//v/+/v78/v/+/f/++v/+/vz9/f39+/
z++On6/fz5+fr4+ff48M7x8vLq7Ofq6urq6ubm6uXs6evp6enq5+vu59T96J/+45z556Ho6Ofh5N/Y5qbV5aTk3MvV1tPS1tXS0tLS1MzVzsnH
48PD4L+84Li/37zE4ae+4LO/37K/3r283bm+3rTJ1snA2rjPz8/HyMS63ru64Le54bW637S228Op0Nuc1fKb0/Oa1O+NycVkwutvwohvwnn4qC
P4piC6ubnjq1Gsr6yLtqZxu9RzvXz4pSD1oyaunoaIl5WKiIGKcmNuhJ1ubmtkv+oxs+YFrOgFqudgiLpehcBElMMTpN1cgr9ef61ceJ9eYmRT
fbpOfbhSdKE/YnTdPErmNkXtM0PoNETvMkTsMUPvL0TpMUPDSFNaSkieMDhSFhQuPD4jJyMfEA4iAAAIHicFDQ8FCA8CCAECBQ4EBAQCBAALAA
EBAQIAAQoAAgAAAAA1szuiAAEAAElEQVR42uydi0PTZvf40xvQliwJ0Vd20yrFrRUnSKmO4XS+WxfU0UB3QSdU6RQdC6TQNGl6yb/+O+d5kjTp
vbhXt++vZxNK2zRpkvN5zjnPec5hmIlMZCITmchEJjKRiUxkIhOZyEQmMpGJTGQiE5nIRCYykYlMZCITmchEJjKRiUxkIhOZyEQmMpGJTGQiE5
nIRCYykYlMZCITmchEJjKRiUxkIhOZyEQmMpGJTGQiE5nIRCYykYlMZCITmchEJjKRiUxkIhOZyEQmMpGJTGQiE5nIRCYykYlMZCITmchEJjKR
iUxkIhOZyEQmMpGJTGQiE5nIRCYykYlMZCITmchEJjKRiUxkIhOZyEQmMpGJTGQiE5nIRCYykYlMZCITmchEJjKRiUxkIhOZyEQmMpGJTGQiE5
nIRCYykYlMZCITmchEJvK3SCg0OQcTGU+mQCZngUogMAHARCYAmADg36r+HwIA8Xg0+iFOuP+7vus3/3cpwbt+W+/24wPg77rL/nnq9q8DQACE
cS+gC4D2FSVvOM+HjgIbKgiAqdF0KeBI++8Bw1K3dBxAIDDtORj3VAQCIY8E+snQHY5L2ncYSmHL9hEP2BMedveb/Od2wLXruZO/1QKYGiiD1G
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
JSgP5o2xb0Pzn5V7niPKLlAAAAAElFTkSuQmCC
    )"
}

; Hands the memory the program does not need back to Windows (only idle pages; they return when used)
TrimMemory() {
    DllCall("psapi\EmptyWorkingSet", "Ptr", DllCall("kernel32\GetCurrentProcess", "Ptr"))
}
