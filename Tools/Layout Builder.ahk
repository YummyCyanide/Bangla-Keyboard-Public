; ===========================================================================
;  Bangla Layout Builder - make and edit keyboard layouts (.xml) for Bangla Keyboard
;  Needs AutoHotkey v2 (portable exe is fine).
;  The files it writes are the same format as the ones in Bangla Keyboard's Layouts folder.
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon            ; no tray icon - the window shows on the taskbar only
Persistent()
ListLines(false)                  ; no line history: less memory and CPU
KeyHistory(0)                     ; this tool installs a key hook: no key history logging
SetTimer(TrimMemory, -3000)         ; once, shortly after start: hand unused memory back to Windows
SetWorkingDir A_ScriptDir

; ---------------------------------------------------------------------------
;  Engine: copied unchanged from Bangla Keyboard (used by the "Try it" tab)
; ---------------------------------------------------------------------------
class Engine {
    static HAS := Chr(0x09CD)
    static ZWNJ := Chr(0x200C)
    static ZWJ := Chr(0x200D)
    static MAXBUF := 24

    buf := ""       ; what we typed recently (so joining rules can look back)
    vowel := ""     ; a vowel sign (i, e, ai) still waiting to follow its consonant
    mode := ""      ; "lead" = typed before its consonant, "tail" = already after it

    __New(lay) {
        this.lay := lay
    }

    Reset() {
        this.buf := ""
        this.vowel := ""
        this.mode := ""
    }

    Track(ch) {
        b := this.buf . ch
        if (StrLen(b) > Engine.MAXBUF)
            b := SubStr(b, -Engine.MAXBUF)
        this.buf := b
        this.vowel := ""
        this.mode := ""
    }

    static IsCons(ch) {
        o := Ord(ch)
        return (o >= 0x0995 && o <= 0x09B9) || o = 0x09CE || o = 0x09DC || o = 0x09DD || o = 0x09DF
    }

    static IsSign(ch) {
        o := Ord(ch)
        return (o >= 0x09BE && o <= 0x09C4) || o = 0x09C7 || o = 0x09C8 || o = 0x09CB || o = 0x09CC
            || o = 0x09D7 || o = 0x0981 || o = 0x0982 || o = 0x0983 || o = 0x09BC
    }

    ; 1-based index where the last consonant cluster starts (0 = none). Used for ref (র্).
    static ClusterStart(s) {
        i := StrLen(s)
        while (i >= 1 && Engine.IsSign(SubStr(s, i, 1)))
            i--
        if (i < 1 || !Engine.IsCons(SubStr(s, i, 1)))
            return 0
        Loop {
            if (i < 3 || SubStr(s, i - 1, 1) != Engine.HAS)
                break
            j := i - 2
            c := SubStr(s, j, 1)
            if (c == Engine.ZWNJ || c == Engine.ZWJ) {
                j--
                if (j < 1)
                    break
                c := SubStr(s, j, 1)
            }
            if !Engine.IsCons(c)
                break
            i := j
        }
        return i
    }

    ; Returns [backspaces, text] or false when this layout has nothing for the key.
    Press(vk, shifted) {
        lay := this.lay
        if shifted {
            if !lay.sh.Has(vk)
                return false
            out := lay.sh[vk]
            opt := lay.optS.Get(vk, "")
        } else {
            if !lay.nor.Has(vk)
                return false
            out := lay.nor[vk]
            opt := lay.optN.Get(vk, "")
        }
        old := this.buf
        vw := this.vowel
        md := this.mode
        hasTail := (vw != "" && md != "" && SubStr(old, -StrLen(vw)) == vw)
        base := hasTail ? SubStr(old, 1, StrLen(old) - StrLen(vw)) : old
        nw := old . out
        nvw := ""
        nmd := ""
        reorder := false

        if (opt = "Delay") {
            ; vowel typed before its consonant (Bijoy style): show it now, move it later
            nvw := out
            nmd := "lead"
        } else if (opt = "DeInc1" || opt = "DeInc2") {
            ; hasanta / ra-phala / ya-phala: goes before a waiting vowel sign
            o2 := out
            if (opt = "DeInc1" && out == (Engine.HAS . Chr(0x09AF)) && SubStr(base, -1) == Chr(0x09B0))
                o2 := Engine.ZWNJ . out
            if hasTail {
                nw := base . o2 . vw
                nvw := vw
                nmd := "tail"
                reorder := (md = "tail")
            } else {
                nw := old . o2
            }
        } else if (opt = "MoveL") {
            ; ref (র্) is typed after the letter but belongs before the whole cluster
            st := Engine.ClusterStart(old)
            if st
                nw := SubStr(old, 1, st - 1) . out . SubStr(old, st)
            else
                nw := old . out
        } else if (StrLen(out) = 1 && Engine.IsCons(out)) {
            if (hasTail && (md = "lead" || (md = "tail" && SubStr(base, -1) == Engine.HAS))) {
                nw := base . out . vw
                nvw := vw
                nmd := "tail"
                reorder := true
            }
        }

        ; joining rules: longest typed sequence at the end wins
        changed := false
        if !reorder {
            L := Min(lay.maxSeq, StrLen(nw))
            while (L >= 1) {
                s := SubStr(nw, -L)
                if lay.juks.Has(s) {
                    r := lay.juks[s]
                    if !(r == s) {
                        nw := SubStr(nw, 1, StrLen(nw) - L) . r
                        changed := true
                    }
                    break
                }
                L--
            }
        }
        if changed {
            nvw := ""
            nmd := ""
        }

        ; what must change on screen: delete the differing tail, type the rest
        n := Min(StrLen(old), StrLen(nw))
        lcp := 0
        while (lcp < n && Ord(SubStr(old, lcp + 1, 1)) = Ord(SubStr(nw, lcp + 1, 1)))
            lcp++
        bs := StrLen(old) - lcp
        txt := SubStr(nw, lcp + 1)
        if (StrLen(nw) > Engine.MAXBUF)
            nw := SubStr(nw, -Engine.MAXBUF)
        this.buf := nw
        this.vowel := nvw
        this.mode := nmd
        return [bs, txt]
    }
}

; ---------------------------------------------------------------------------
;  Layout Builder
; ---------------------------------------------------------------------------
; the script sits in the "Tools" folder; Icons and Layouts stay one level up
RootDir() {
    SplitPath(A_ScriptDir, &nm, &par)
    return (nm = "Tools") ? par : A_ScriptDir
}

class LB {
    static dir := RootDir()      ; Icons and Layouts live next to the Tools folder
    static dataDir := A_AppData . "\Bangla Keyboard"
    static ini := A_AppData . "\Bangla Keyboard\Layout Builder.dat"
    static layoutsDir := ""
    static g := ""
    static tab := ""
    static keys := Map()        ; vk -> {nor, shf, nOpt, sOpt}   (keys that are drawn on the keyboard picture)
    static extra := Map()       ; same, for keys found in a file that are not on the picture (kept as they are)
    static juks := []           ; [{seq, out}]
    static file := ""
    static dirty := false
    static sel := 0
    static loading := false
    static lastEd := 1
    static caps := Map()        ; vk -> the key picture (Text control)
    static curName := ""
    static curIcon := ""
    static curHk := ""
    static scWarn := false
    static lblFile := ""
    static edName := ""
    static cbIcon := ""
    static hkSc := ""
    static lblSel := ""
    static edN := ""
    static edS := ""
    static ddN := ""
    static ddS := ""
    static lblOpt := ""
    static edFind := ""
    static lblCount := ""
    static lv := ""
    static edSeq := ""
    static edOut := ""
    static edIn := ""
    static edRes := ""
    static cbFont := ""
    static ddSize := ""
    static kScale := 100        ; size of the Bangla text on the key pictures, in percent
    static pSize := 2           ; preview text size: 1 small, 2 medium, 3 large
    static fontSet := false
    static pFont := ""          ; preview font picked by the person ("" = automatic for the type)
    static tryFrac := 0.3       ; share of the height given to the input box on "Try your layout"
    static tryTop := 0
    static tryAvail := 100
    static ddType := ""         ; Auto / Unicode / ANSI / Other
    static lblType := ""        ; coloured indicator
    static lastEff := 0
    static undo := []
    static redo := []
    static lastTag := ""
    static lastTick := 0
    static clip := ""
    static btnUndo := ""
    static btnRedo := ""
    static vcaps := Map()       ; vk -> key picture on the Layout Viewer tab
    static kp := Map()          ; vk -> {b, e, s, n} parts of a key on the Keys tab (back, English key, Shift value, Normal value)
    static vp := Map()          ; same, on the Layout Viewer tab
    static lblV1 := ""
    static ui := Map()          ; named groups of controls used by Relayout()
    static kb := []             ; keyboard picture on the Keys tab
    static vkb := []            ; keyboard picture on the Layout Viewer tab
    static pad := [0, 0, 0, 0]  ; tab frame thickness (left, top, right, bottom)
    static ready := false
    static sc := 1
    static ddH := 24
    static maxed := false
    static fixing := false
    static starting := false       ; true while the window is built hidden, so it only appears once, at its final size and place
}

; ---- the plain English keyboard: what an unchanged key types -------------------
KeyDefs() {
    static d := ""
    if IsObject(d)
        return d
    d := Map()
    d[32] := [" ", " "]
    d[192] := [Chr(96), "~"]
    d[49] := ["1", "!"]
    d[50] := ["2", "@"]
    d[51] := ["3", "#"]
    d[52] := ["4", "$"]
    d[53] := ["5", "%"]
    d[54] := ["6", "^"]
    d[55] := ["7", "&"]
    d[56] := ["8", "*"]
    d[57] := ["9", "("]
    d[48] := ["0", ")"]
    d[189] := ["-", "_"]
    d[187] := ["=", "+"]
    d[219] := ["[", "{"]
    d[221] := ["]", "}"]
    d[220] := ["\", "|"]
    d[186] := [";", ":"]
    d[222] := ["'", '"']
    d[188] := [",", "<"]
    d[190] := [".", ">"]
    d[191] := ["/", "?"]
    Loop 26
        d[64 + A_Index] := [StrLower(Chr(64 + A_Index)), Chr(64 + A_Index)]
    return d
}

; rows of the keyboard picture: left offset (px) and the key codes
KeyRows() {
    r := []
    r.Push({off: 0, keys: [192, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 189, 187]})
    r.Push({off: 14, keys: [81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 219, 221, 220]})
    r.Push({off: 28, keys: [65, 83, 68, 70, 71, 72, 74, 75, 76, 186, 222]})
    r.Push({off: 42, keys: [90, 88, 67, 86, 66, 78, 77, 188, 190, 191]})
    r.Push({off: 112, keys: [32]})
    return r
}

AllVks() {
    a := []
    for row in KeyRows() {
        for vk in row.keys
            a.Push(vk)
    }
    for vk in LB.extra
        a.Push(vk)
    return a
}

OptNames() {
    return ["", "Delay", "DeInc1", "DeInc2", "MoveL", "Xtra"]
}

OptLabels() {
    return ["(none)", "Delay", "DeInc1", "DeInc2", "MoveL", "Xtra"]
}

OptIndex(n) {
    for i, v in OptNames() {
        if (v = n)
            return i
    }
    return 1
}

OptText(o) {
    switch o {
        case "Delay":
            return "Delay: vowel sign typed BEFORE its consonant (Bijoy style); shows at once, moves behind the consonant when typed."
        case "DeInc1":
            return "DeInc1: hasanta / ra-phala / ya-phala; goes before a waiting vowel sign (with the special ra + ya-phala rule)."
        case "DeInc2":
            return "DeInc2: like DeInc1, without the special ra + ya-phala rule."
        case "MoveL":
            return "MoveL: ref. It is typed after the letter but placed in front of the whole conjunct."
        case "Xtra":
            return "Xtra: kept for compatibility with Bijoy layout files; Bangla Keyboard gives it no special action."
    }
    return ""
}

OptHelp(a, b) {
    t := ""
    if (a != "")
        t .= "Normal key - " . OptText(a) . "`n"
    if (b != "")
        t .= "Shift key - " . OptText(b)
    if (t = "")
        t := "No special option: the key simply types its output. (An empty field means the normal English character.)"
    return t
}

NewKeyObj() {
    return {nor: "", shf: "", nOpt: "", sOpt: ""}
}

ResetModel() {
    LB.keys := Map()
    LB.extra := Map()
    LB.juks := []
    LB.file := ""
    LB.dirty := false
    LB.sel := 0
    for row in KeyRows() {
        for vk in row.keys
            LB.keys[vk] := NewKeyObj()
    }
}

CapName(vk) {
    if (vk = 32)
        return "Space"
    return StrUpper(KeyDefs()[vk][1])
}

EffNor(vk) {
    k := LB.keys[vk]
    return (k.nor = "") ? KeyDefs()[vk][1] : k.nor
}

EffShf(vk) {
    k := LB.keys[vk]
    return (k.shf = "") ? KeyDefs()[vk][2] : k.shf
}

; a key counts as changed when it differs from the English key (or has an option)
IsCustom(vk) {
    k := LB.keys[vk]
    d := KeyDefs()[vk]
    return (k.nor != "" && k.nor !== d[1]) || (k.shf != "" && k.shf !== d[2]) || k.nOpt != "" || k.sOpt != ""
}

KeyColor(vk) {
    if (vk = LB.sel)
        return "8FC1FF"
    k := LB.keys[vk]
    if (k.nOpt != "" || k.sOpt != "")
        return "FFE2A0"
    if IsCustom(vk)
        return "CFEFD6"
    return "EDEDED"
}

RefreshKey(vk) {
    if !LB.caps.Has(vk)
        return
    PaintKey(vk, false)
}

; fill one key picture: English key on the left, Shift value top right, Normal value bottom right
PaintKey(vk, viewer) {
    parts := viewer ? LB.vp : LB.kp
    if !parts.Has(vk)
        return
    p := parts[vk]
    custom := IsCustom(vk)
    col := viewer ? ViewColor(vk) : KeyColor(vk)
    p.s.Text := custom ? EffShf(vk) : ""
    p.n.Text := custom ? EffNor(vk) : ""
    for ctl in [p.b, p.e, p.s, p.n] {
        ctl.Opt("Background" . col)
        ctl.Redraw()
    }
}

RefreshAllKeys() {
    for vk in LB.caps
        RefreshKey(vk)
}

; ---- XML in / out (same format as the Bangla Keyboard layout files) --------------
Unesc(s) {
    while RegExMatch(s, "&#(\d+);", &m)
        s := StrReplace(s, m[0], Chr(Integer(m[1])))
    while RegExMatch(s, "i)&#x([0-9a-f]+);", &m)
        s := StrReplace(s, m[0], Chr(Integer("0x" m[1])))
    s := StrReplace(s, "&lt;", "<")
    s := StrReplace(s, "&gt;", ">")
    s := StrReplace(s, "&quot;", '"')
    s := StrReplace(s, "&apos;", "'")
    return StrReplace(s, "&amp;", "&")
}

XmlEsc(s) {
    s := StrReplace(s, "&", "&amp;")
    s := StrReplace(s, "<", "&lt;")
    return StrReplace(s, ">", "&gt;")
}

LoadFile(path) {
    txt := FileRead(path, "UTF-8")
    ResetModel()
    name := ""
    if RegExMatch(txt, "s)<Name>(.*?)</Name>", &m) {
        name := Unesc(m[1])
    } else {
        SplitPath(path, , , , &nm)
        name := nm
    }
    icon := ""
    if RegExMatch(txt, "s)<IconName>(.*?)</IconName>", &m)
        icon := Trim(Unesc(m[1]))
    hk := ""
    if RegExMatch(txt, "s)<Shortcut>(.*?)</Shortcut>", &m) {
        sc := m[1]
        mods := ""
        if InStr(sc, "<Ctrl>True")
            mods .= "^"
        if InStr(sc, "<Alt>True")
            mods .= "!"
        if InStr(sc, "<Shift>True")
            mods .= "+"
        if RegExMatch(sc, "<KeyCode>(\d+)</KeyCode>", &kc) {
            kn := GetKeyName(Format("vk{:X}", Integer(kc[1])))
            if (kn != "")
                hk := mods . kn
        }
    }
    keyRe := 's)<Key KeyCode="(\d+)"([^>]*)>\s*<Normal>(.*?)</Normal>\s*<Shift>(.*?)</Shift>\s*</Key>'
    pos := 1
    while (pos := RegExMatch(txt, keyRe, &m, pos)) {
        pos += m.Len[0]
        vk := Integer(m[1])
        o := NewKeyObj()
        o.nor := Unesc(m[3])
        o.shf := Unesc(m[4])
        if RegExMatch(m[2], 'Normal_Option="([^"]*)"', &q)
            o.nOpt := q[1]
        if RegExMatch(m[2], 'Shift_Option="([^"]*)"', &q)
            o.sOpt := q[1]
        if LB.keys.Has(vk)
            LB.keys[vk] := o
        else
            LB.extra[vk] := o
    }
    jukRe := 's)<Juk>\s*<Seq>(.*?)</Seq>\s*<Out>(.*?)</Out>\s*</Juk>'
    pos := 1
    while (pos := RegExMatch(txt, jukRe, &m, pos)) {
        pos += m.Len[0]
        LB.juks.Push({seq: Unesc(m[1]), out: Unesc(m[2])})
    }
    LB.file := path
    LB.ddType.Choose(TypeFromIni(path))
    LB.pFont := FontFromIni(path)
    ApplyModelToUI(name, icon, hk)
    ApplyPreviewFont()
}

; the shortcut box -> the <Shortcut> block ("" when empty)
ShortcutXml() {
    nl := "`r`n"
    hk := LB.hkSc.Value
    ctrl := false
    alt := false
    shift := false
    while (hk != "" && InStr("^!+#", SubStr(hk, 1, 1))) {
        c := SubStr(hk, 1, 1)
        if (c = "^")
            ctrl := true
        else if (c = "!")
            alt := true
        else if (c = "+")
            shift := true
        hk := SubStr(hk, 2)
    }
    if (hk = "")
        return ""
    vk := GetKeyVK(hk)
    if !vk
        return ""
    if (!ctrl && !alt && !RegExMatch(hk, "i)^F\d+$"))
        LB.scWarn := true
    s := "  <Shortcut>" . nl
    s .= "    <Alt>" . (alt ? "True" : "False") . "</Alt>" . nl
    s .= "    <Ctrl>" . (ctrl ? "True" : "False") . "</Ctrl>" . nl
    s .= "    <Shift>" . (shift ? "True" : "False") . "</Shift>" . nl
    s .= "    <KeyCode>" . vk . "</KeyCode>" . nl
    s .= "  </Shortcut>" . nl
    return s
}

KeyXml(vk, k) {
    nl := "`r`n"
    d := KeyDefs().Get(vk, ["", ""])
    n := (k.nor = "") ? d[1] : k.nor
    s := (k.shf = "") ? d[2] : k.shf
    attr := ""
    if (k.nOpt != "")
        attr .= ' Normal_Option="' . k.nOpt . '"'
    if (k.sOpt != "")
        attr .= ' Shift_Option="' . k.sOpt . '"'
    x := '    <Key KeyCode="' . vk . '"' . attr . '>' . nl
    x .= "      <Normal>" . XmlEsc(n) . "</Normal>" . nl
    x .= "      <Shift>" . XmlEsc(s) . "</Shift>" . nl
    x .= "    </Key>" . nl
    return x
}

BuildXml(name) {
    nl := "`r`n"
    LB.scWarn := false
    x := '<?xml version="1.0" encoding="utf-8" standalone="yes"?>' . nl
    x .= "<!--Start of Layout-->" . nl
    x .= "<KeyLayout>" . nl
    x .= "  <Name>" . XmlEsc(name) . "</Name>" . nl
    x .= ShortcutXml()
    icon := Trim(LB.cbIcon.Text)
    if (icon != "")
        x .= "  <IconName>" . XmlEsc(icon) . "</IconName>" . nl
    x .= "  <Keys>" . nl
    for vk in AllVks() {
        if LB.keys.Has(vk) {
            if (vk != 32 && !IsCustom(vk))
                continue                                  ; unchanged English keys are simply left out
            x .= KeyXml(vk, LB.keys[vk])
        } else {
            x .= KeyXml(vk, LB.extra[vk])
        }
    }
    x .= "  </Keys>" . nl
    x .= "  <Juks>" . nl
    for j in LB.juks {
        x .= "    <Juk>" . nl
        x .= "      <Seq>" . XmlEsc(j.seq) . "</Seq>" . nl
        x .= "      <Out>" . XmlEsc(j.out) . "</Out>" . nl
        x .= "    </Juk>" . nl
    }
    x .= "  </Juks>" . nl
    x .= "</KeyLayout>" . nl
    x .= "<!--End of Layout-->"
    return x
}

SafeName(n) {
    return RegExReplace(n, '[\\/:*?"<>|]', "_")
}

; returns true when the file was written
SaveLayout(saveAs := false) {
    name := Trim(LB.edName.Value)
    if (name = "") {
        MsgBox("Please type a name for the layout first.", "Bangla Layout Builder", "0x30 Owner" . LB.g.Hwnd)
        return false
    }
    path := LB.file
    if (saveAs || path = "") {
        path := FileSelect("S16", LB.layoutsDir . "\" . SafeName(name) . ".xml", "Save layout (.xml)", "Layout (*.xml)")
        if (path = "")
            return false
        if !RegExMatch(path, "i)\.xml$")
            path .= ".xml"
    }
    if !CheckBeforeSave(name, path)
        return false
    xml := BuildXml(name)
    try {
        f := FileOpen(path, "w", "UTF-8-RAW")
        f.Write(xml)
        f.Close()
    } catch as e {
        MsgBox("Could not save the file:`n`n" . e.Message, "Bangla Layout Builder", "0x10 Owner" . LB.g.Hwnd)
        return false
    }
    LB.file := path
    SaveTypeSetting()
    SaveFontSetting()
    LB.dirty := false
    LB.curName := LB.edName.Value
    LB.curIcon := LB.cbIcon.Text
    LB.curHk := LB.hkSc.Value
    SplitPath(path, , &dp)
    if (dp != "") {
        LB.layoutsDir := dp
        SaveFolder()
    }
    UpdateTitle()
    msg := "Saved:`n" . path
    if LB.scWarn
        msg .= "`n`nNote: Bangla Keyboard only accepts a shortcut that has Ctrl or Alt in it (or a single F-key)."
    MsgBox(msg, "Bangla Layout Builder", "0x40 Owner" . LB.g.Hwnd)
    return true
}

; ---- window state ---------------------------------------------------------------
MarkDirty() {
    LB.dirty := true
    UpdateTitle()
}

UpdateTitle() {
    fn := "(not saved yet)"
    if (LB.file != "")
        SplitPath(LB.file, &fn)
    LB.g.Title := "Bangla Layout Builder  -  " . fn . (LB.dirty ? "  *" : "")
    LB.lblFile.Text := "Layouts folder:  " . LB.layoutsDir
}

LoadSettings() {
    d := IniRead(LB.ini, "General", "LayoutsDir", LB.dir . "\Layouts")
    if !DirExist(d)
        d := LB.dir . "\Layouts"
    if !DirExist(d) {
        try DirCreate(d)
    }
    LB.layoutsDir := d
    try LB.pSize := Integer(IniRead(LB.ini, "General", "PreviewSize", "2"))
    if (LB.pSize < 1 || LB.pSize > 3)
        LB.pSize := 2
    try LB.kScale := Integer(IniRead(LB.ini, "General", "KeyTextScale", "100"))
    if (LB.kScale < 50 || LB.kScale > 250)
        LB.kScale := 100
}

SaveFolder() {
    try IniWrite(LB.layoutsDir, LB.ini, "General", "LayoutsDir")
}

IconNames() {
    a := []
    Loop Files LB.dir . "\Icons\*.ico" {
        SplitPath(A_LoopFileName, , , , &nm)
        a.Push(nm)
    }
    if (a.Length = 0)
        a := ["Unicode", "Classic", "English"]
    return a
}

; put a loaded / new layout on screen
ApplyModelToUI(name, icon, hk) {
    LB.loading := true
    LB.edName.Value := name
    LB.cbIcon.Text := icon
    LB.hkSc.Value := hk
    LB.curName := name
    LB.curIcon := icon
    LB.curHk := hk
    LB.edFind.Value := ""
    LB.edSeq.Value := ""
    LB.edOut.Value := ""
    LB.loading := false
    LB.dirty := false
    LB.sel := 0
    RefreshAllKeys()
    FillJuks()
    SelectKey(65)
    ClearUndo()
    UpdateEncoding(true)
    RefreshViewer()
    LB.dirty := false
    UpdateTitle()
}

ConfirmDiscard() {
    if !LB.dirty
        return true
    r := MsgBox("Save the changes to this layout first?", "Bangla Layout Builder", "0x23 Owner" . LB.g.Hwnd)
    if (r = "Cancel")
        return false
    if (r = "Yes")
        return SaveLayout()
    return true
}

NewLayout(*) {
    if !ConfirmDiscard()
        return
    ResetModel()
    LB.ddType.Choose(1)
    LB.pFont := ""
    names := IconNames()
    ApplyModelToUI("My Layout", names[1], "")
    ApplyPreviewFont()
    MarkDirty()
}

OpenLayout(*) {
    if !ConfirmDiscard()
        return
    p := FileSelect(3, LB.layoutsDir . "\", "Open layout", "Layout (*.xml)")
    if (p = "")
        return
    OpenPath(p)
}

OpenPath(p) {
    try {
        LoadFile(p)
    } catch as e {
        MsgBox("Could not read this layout:`n`n" . e.Message, "Bangla Layout Builder", "0x10 Owner" . LB.g.Hwnd)
        return
    }
    SplitPath(p, , &dp)
    if (dp != "") {
        LB.layoutsDir := dp
        SaveFolder()
        UpdateTitle()
    }
}

SaveClick(*) {
    SaveLayout()
}

SaveAsClick(*) {
    SaveLayout(true)
}

PickFolder(*) {
    p := DirSelect("*" . LB.layoutsDir, 3, "Choose the folder that holds your layout files")
    if (p = "")
        return
    LB.layoutsDir := RTrim(p, "\")
    SaveFolder()
    UpdateTitle()
}

ShowFolder(*) {
    try Run('explorer.exe "' . LB.layoutsDir . '"')
}

AppClose(*) {
    if ConfirmDiscard()
        ExitApp()
    return true
}

HeaderChanged(*) {
    if LB.loading
        return
    if (LB.edName.Value !== LB.curName || LB.cbIcon.Text !== LB.curIcon || LB.hkSc.Value !== LB.curHk)
        MarkDirty()
}

ClearShortcut(*) {
    LB.hkSc.Value := ""
    HeaderChanged()
}

; ---- keys tab -----------------------------------------------------------------------
SelectKey(vk, *) {
    old := LB.sel
    LB.sel := vk
    if (old && old != vk)
        RefreshKey(old)
    RefreshKey(vk)
    MoveSelFrame()
    LoadEditor()
}

LoadEditor() {
    vk := LB.sel
    if !vk
        return
    k := LB.keys[vk]
    LB.loading := true
    LB.lblSel.Text := "Selected key:   " . CapName(vk)
    LB.edN.Value := EffNor(vk)
    LB.edS.Value := EffShf(vk)
    LB.ddN.Choose(OptIndex(k.nOpt))
    LB.ddS.Choose(OptIndex(k.sOpt))
    LB.lblOpt.Text := OptHelp(k.nOpt, k.sOpt)
    LB.loading := false
}

KeyChanged() {
    MarkDirty()
    RefreshKey(LB.sel)
    UpdateEncoding()
}

FocusN(*) {
    LB.lastEd := 1
}

FocusS(*) {
    LB.lastEd := 2
}

EdNChange(*) {
    if (LB.loading || !LB.sel)
        return
    v := LB.edN.Value
    if (v == EffNor(LB.sel))
        return
    PushUndo("N" . LB.sel)
    LB.keys[LB.sel].nor := v
    KeyChanged()
}

EdSChange(*) {
    if (LB.loading || !LB.sel)
        return
    v := LB.edS.Value
    if (v == EffShf(LB.sel))
        return
    PushUndo("S" . LB.sel)
    LB.keys[LB.sel].shf := v
    KeyChanged()
}

DdNChange(*) {
    if (LB.loading || !LB.sel)
        return
    k := LB.keys[LB.sel]
    v := OptNames()[LB.ddN.Value]
    if (v == k.nOpt)
        return
    PushUndo()
    k.nOpt := v
    LB.lblOpt.Text := OptHelp(k.nOpt, k.sOpt)
    KeyChanged()
}

DdSChange(*) {
    if (LB.loading || !LB.sel)
        return
    k := LB.keys[LB.sel]
    v := OptNames()[LB.ddS.Value]
    if (v == k.sOpt)
        return
    PushUndo()
    k.sOpt := v
    LB.lblOpt.Text := OptHelp(k.nOpt, k.sOpt)
    KeyChanged()
}

; puts a special character at the cursor of the box that was used last
InsertText(s, *) {
    ed := (LB.lastEd = 2) ? LB.edS : LB.edN
    SendMessage(0xC2, 1, StrPtr(s), ed)          ; EM_REPLACESEL
    ed.Focus()
}

ResetKey(*) {
    if !LB.sel
        return
    PushUndo()
    k := LB.keys[LB.sel]
    k.nor := ""
    k.shf := ""
    k.nOpt := ""
    k.sOpt := ""
    LoadEditor()
    KeyChanged()
}

; ---- joining rules tab ------------------------------------------------------------------
FillJuks() {
    f := LB.edFind.Value
    LB.lv.Opt("-Redraw")
    LB.lv.Delete()
    shown := 0
    for j in LB.juks {
        if (f != "" && !InStr(j.seq, f) && !InStr(j.out, f))
            continue
        LB.lv.Add(, j.seq, j.out)
        shown++
    }
    LB.lv.Opt("+Redraw")
    LB.lblCount.Text := shown . " of " . LB.juks.Length . " rules shown"
}

FindChanged(*) {
    if !LB.loading
        FillJuks()
}

JukPick(lv, item, selected, *) {
    if (!selected || !item)
        return
    LB.edSeq.Value := lv.GetText(item, 1)
    LB.edOut.Value := lv.GetText(item, 2)
}

SelectJukRow(seq) {
    Loop LB.lv.GetCount() {
        if (LB.lv.GetText(A_Index, 1) == seq) {
            LB.lv.Modify(A_Index, "Select Focus Vis")
            return
        }
    }
}

JukAdd(*) {
    seq := LB.edSeq.Value
    out := LB.edOut.Value
    if (seq = "") {
        MsgBox("Type the sequence first (what the keys produce, in order).", "Bangla Layout Builder", "0x30 Owner" . LB.g.Hwnd)
        return
    }
    PushUndo()
    found := false
    for j in LB.juks {
        if (j.seq == seq) {
            j.out := out
            found := true
            break
        }
    }
    if !found
        LB.juks.Push({seq: seq, out: out})
    MarkDirty()
    FillJuks()
    SelectJukRow(seq)
    UpdateEncoding()
}

JukDelete(*) {
    row := LB.lv.GetNext(0)
    if !row
        return
    PushUndo()
    seq := LB.lv.GetText(row, 1)
    for i, j in LB.juks {
        if (j.seq == seq) {
            LB.juks.RemoveAt(i)
            break
        }
    }
    LB.edSeq.Value := ""
    LB.edOut.Value := ""
    MarkDirty()
    FillJuks()
    UpdateEncoding()
}

; ---- "Try it" tab: runs Bangla Keyboard's own typing engine on what you type ------------------
ReverseDefaults() {
    r := Map()
    for vk, d in KeyDefs() {
        r[d[1]] := [vk, false]
        if (d[2] !== d[1])
            r[d[2]] := [vk, true]
    }
    return r
}

BuildTestLayout() {
    lay := {nor: Map(), sh: Map(), optN: Map(), optS: Map(), juks: Map(), maxSeq: 1}
    for vk in AllVks() {
        if LB.keys.Has(vk) {
            if (vk != 32 && !IsCustom(vk))
                continue
            k := LB.keys[vk]
        } else {
            k := LB.extra[vk]
        }
        d := KeyDefs().Get(vk, ["", ""])
        lay.nor[vk] := (k.nor = "") ? d[1] : k.nor
        lay.sh[vk] := (k.shf = "") ? d[2] : k.shf
        if (k.nOpt != "")
            lay.optN[vk] := k.nOpt
        if (k.sOpt != "")
            lay.optS[vk] := k.sOpt
    }
    for j in LB.juks {
        seq := j.seq
        out := j.out
        if (seq = "")
            continue
        if (SubStr(out, 1, 1) == " " && SubStr(seq, 1, 1) != " ")
            out := LTrim(out, " ")
        lay.juks[seq] := out
        if (StrLen(seq) > lay.maxSeq)
            lay.maxSeq := StrLen(seq)
    }
    return lay
}

TryTyping(*) {
    try {
        lay := BuildTestLayout()
        eng := Engine(lay)
        rev := ReverseDefaults()
        doc := ""
        inp := LB.edIn.Value
        Loop Parse inp {
            ch := A_LoopField
            if !rev.Has(ch) {
                eng.Reset()
                doc .= ch
                continue
            }
            vk := rev[ch][1]
            sh := rev[ch][2]
            has := sh ? lay.sh.Has(vk) : lay.nor.Has(vk)
            if !has {
                eng.Reset()
                doc .= ch
                continue
            }
            txt := sh ? lay.sh[vk] : lay.nor[vk]
            if (txt == " ") {
                eng.Track(" ")
                doc .= " "
                continue
            }
            r := eng.Press(vk, sh)
            keep := Max(0, StrLen(doc) - r[1])
            doc := SubStr(doc, 1, keep) . r[2]
        }
        LB.edRes.Value := doc
    } catch as e {
        LB.edRes.Value := "(could not run the test: " . e.Message . ")"
    }
}

TabChanged(*) {
    if (LB.tab.Value = 3)
        TryTyping()
    else if (LB.tab.Value = 4)
        RefreshViewer()
}

; ---- layout type: Unicode / ANSI / other language -------------------------------------
; the font used for the preview: the one the person picked, or the usual font of the type
PreviewFace() {
    if (LB.pFont != "")
        return LB.pFont
    t := EffType()
    return (t = 2) ? "SutonnyMJ" : (t = 3) ? "Segoe UI" : "Nirmala UI"
}

TrySize() {
    return [12, 16, 22][LB.pSize]
}

ApplyPreviewFont() {
    if !IsObject(LB.cbFont)
        return
    f := PreviewFace()
    LB.edRes.SetFont("s" . TrySize(), f)
    if (LB.cbFont.Text != f) {
        LB.fontSet := true
        LB.cbFont.Text := f
        LB.fontSet := false
    }
    ApplyViewerFont()
}

; every installed font family (names only)
InstalledFontMap() {
    static m := ""
    if IsObject(m)
        return m
    m := Map()
    m.CaseSense := "Off"
    lf := Buffer(92, 0)
    NumPut("uchar", 1, lf, 23)                          ; DEFAULT_CHARSET
    cb := CallbackCreate(FontEnumCb.Bind(m), "F", 4)
    dc := DllCall("GetDC", "ptr", 0, "ptr")
    DllCall("EnumFontFamiliesExW", "ptr", dc, "ptr", lf, "ptr", cb, "ptr", 0, "uint", 0)
    DllCall("ReleaseDC", "ptr", 0, "ptr", dc)
    CallbackFree(cb)
    return m
}

FontEnumCb(m, lpelfe, lpntme, fontType, lParam) {
    n := StrGet(lpelfe + 28, 32, "UTF-16")
    if (n != "" && SubStr(n, 1, 1) != "@" && !m.Has(n))
        m[n] := n
    return 1
}

InstalledFonts() {
    list := ""
    for n in InstalledFontMap()
        list .= n . "`n"
    list := Sort(RTrim(list, "`n"), "D`n")
    return StrSplit(list, "`n")
}

; the person picked (or typed) a font name in the box
FontComboChanged(*) {
    if LB.fontSet
        return
    t := Trim(LB.cbFont.Text)
    fonts := InstalledFontMap()
    if (t = "" || !fonts.Has(t))
        return
    if (fonts[t] = LB.pFont)
        return
    LB.pFont := fonts[t]
    SaveFontSetting()
    ApplyPreviewFont()
}

SizeChanged(*) {
    LB.pSize := LB.ddSize.Value
    try IniWrite(LB.pSize, LB.ini, "General", "PreviewSize")
    ApplyPreviewFont()
}

DefaultFont(*) {
    LB.pFont := ""
    SaveFontSetting()
    ApplyPreviewFont()
}

FontFromIni(path) {
    SplitPath(path, &fn)
    v := ""
    try v := IniRead(LB.ini, "PreviewFont", fn, "")
    return v
}

SaveFontSetting() {
    if (LB.file = "")
        return
    SplitPath(LB.file, &fn)
    try {
        if (LB.pFont = "")
            IniDelete(LB.ini, "PreviewFont", fn)
        else
            IniWrite(LB.pFont, LB.ini, "PreviewFont", fn)
    }
}

; ---- draggable divider on "Try your layout" -----------------------------------------------
SplitCursor(wParam, lParam, msg, hwnd) {
    if (LB.ready && LB.ui.Has("splitTry") && wParam = LB.ui["splitTry"].Hwnd) {
        DllCall("SetCursor", "ptr", DllCall("LoadCursor", "ptr", 0, "ptr", 32645, "ptr"))
        return true
    }
}

SplitDown(wParam, lParam, msg, hwnd) {
    if !(LB.ready && LB.ui.Has("splitTry") && hwnd = LB.ui["splitTry"].Hwnd)
        return
    pt := Buffer(8, 0)
    while GetKeyState("LButton", "P") {
        DllCall("GetCursorPos", "ptr", pt)
        DllCall("ScreenToClient", "ptr", LB.g.Hwnd, "ptr", pt)
        y := NumGet(pt, 4, "int")
        avail := Max(1, LB.tryAvail)
        fr := (y - LB.tryTop - Px(4)) / avail
        fr := Min(Max(fr, Px(36) / avail), 1 - Px(50) / avail)
        if (Abs(fr - LB.tryFrac) > 0.0005) {
            LB.tryFrac := fr
            Relayout()
        }
        Sleep(10)
    }
    return 0
}

Win1252Extra() {
    static m := ""
    if IsObject(m)
        return m
    m := Map()
    for o in [0x20AC, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x017D, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x017E, 0x0178]
        m[o] := 1
    return m
}

; true when the character exists in the ANSI (Windows-1252) set
IsAnsiChar(ch) {
    o := Ord(ch)
    return (o >= 32 && o <= 126) || (o >= 0xA0 && o <= 0xFF) || Win1252Extra().Has(o)
}

; what the layout looks like: 1 = Unicode Bangla, 2 = ANSI, 3 = other language
DetectType() {
    all := ""
    for vk, k in LB.keys {
        if (vk != 32 && IsCustom(vk))
            all .= EffNor(vk) . EffShf(vk)
    }
    for vk, k in LB.extra
        all .= k.nor . k.shf
    for j in LB.juks
        all .= j.seq . j.out
    if (all = "")
        return 1
    hasBn := false
    hasOth := false
    Loop Parse all {
        o := Ord(A_LoopField)
        if (o >= 0x0980 && o <= 0x09FF) {
            hasBn := true
        } else if (o >= 0x0370 && !(o >= 0x2000 && o <= 0x206F) && !IsAnsiChar(A_LoopField)) {
            hasOth := true
        }
    }
    if hasBn
        return 1
    return hasOth ? 3 : 2
}

; the type in force: what the person chose, or what was detected
EffType() {
    v := LB.ddType.Value
    return (v <= 1) ? DetectType() : v - 1
}

UpdateEncoding(force := false) {
    if !IsObject(LB.ddType)
        return
    t := EffType()
    isAuto := (LB.ddType.Value <= 1)
    names := ["Unicode", "ANSI", "Other-language"]
    cols := ["1E7B34", "B35C00", "2A5DB0"]
    LB.lblType.SetFont("s9 bold c" . cols[t], "Segoe UI")
    LB.lblType.Text := Chr(0x25CF) . " " . names[t] . " layout" . (isAuto ? " (auto)" : "")
    if (force || t != LB.lastEff) {
        LB.lastEff := t
        ApplyPreviewFont()
    }
}

; ---- size of the text on the key pictures (A- / A+ / Reset in the header) ----------------
; Legacy ANSI fonts such as SutonnyMJ draw much smaller letters than Unicode fonts at the same
; point size, so they get an automatic boost; the person can then fine-tune with A- and A+.
FaceBoost() {
    f := PreviewFace()
    return (InStr(f, "MJ") || InStr(f, "Sutonny") || (EffType() = 2 && LB.pFont = "")) ? 1.5 : 1
}

SetKeyScale(v) {
    LB.kScale := Max(50, Min(250, v))
    try IniWrite(LB.kScale, LB.ini, "General", "KeyTextScale")
    if IsObject(LB.ui["lblKT"])
        LB.ui["lblKT"].Text := "Key text: " . LB.kScale . "%"
    ApplyViewerFont()
}

KeyTextSmaller(*) {
    SetKeyScale(LB.kScale - 25)
}

KeyTextBigger(*) {
    SetKeyScale(LB.kScale + 25)
}

KeyTextReset(*) {
    SetKeyScale(100)
}

ApplyViewerFont() {
    ; key fonts follow the key size and the preview font; Relayout() sets them
    for kb in [LB.kb, LB.vkb] {
        if (IsObject(kb) && kb.HasProp("fs"))
            kb.fs := ""
    }
    Relayout()
}

TypeChanged(*) {
    UpdateEncoding(true)
    SaveTypeSetting()
    RefreshViewer()
}

; the chosen type is remembered per layout file (it is not written into the xml)
TypeFromIni(path) {
    SplitPath(path, &fn)
    v := 1
    try v := Integer(IniRead(LB.ini, "LayoutType", fn, "1"))
    return (v >= 1 && v <= 4) ? v : 1
}

SaveTypeSetting() {
    if (LB.file = "")
        return
    SplitPath(LB.file, &fn)
    try IniWrite(LB.ddType.Value, LB.ini, "LayoutType", fn)
}

; ---- checks before saving --------------------------------------------------------------
BadChars(str) {
    bad := ""
    Loop Parse str {
        if (!IsAnsiChar(A_LoopField) && !InStr(bad, A_LoopField))
            bad .= A_LoopField
    }
    return bad
}

DescChars(bad) {
    r := ""
    Loop Parse bad
        r .= A_LoopField . " U+" . Format("{:04X}", Ord(A_LoopField)) . "   "
    return Trim(r)
}

KeyLabel(vk) {
    return KeyDefs().Has(vk) ? CapName(vk) : "code " . vk
}

AnsiProblems() {
    list := []
    for vk in AllVks() {
        if LB.keys.Has(vk) {
            if (vk != 32 && !IsCustom(vk))
                continue
            k := LB.keys[vk]
        } else {
            k := LB.extra[vk]
        }
        d := KeyDefs().Get(vk, ["", ""])
        nv := (k.nor = "") ? d[1] : k.nor
        sv := (k.shf = "") ? d[2] : k.shf
        bad := BadChars(nv)
        if (bad != "")
            list.Push("Key " . KeyLabel(vk) . " (Normal): " . DescChars(bad))
        bad := BadChars(sv)
        if (bad != "")
            list.Push("Key " . KeyLabel(vk) . " (Shift): " . DescChars(bad))
    }
    for j in LB.juks {
        bad := BadChars(j.seq . j.out)
        if (bad != "")
            list.Push("Joining rule  " . j.seq . "  ->  " . j.out . ":  " . DescChars(bad))
    }
    return list
}

; returns true when it is fine to go on and save
CheckBeforeSave(name, path) {
    SplitPath(path, , &folder)
    same := []
    Loop Files folder . "\*.*" {
        if !RegExMatch(A_LoopFileName, "i)\.xml$")
            continue
        if (StrLower(A_LoopFileFullPath) = StrLower(path))
            continue
        try {
            t := FileRead(A_LoopFileFullPath, "UTF-8")
            if (RegExMatch(t, "s)<n>(.*?)</n>", &mm) && StrLower(Trim(Unesc(mm[1]))) = StrLower(name))
                same.Push(A_LoopFileName)
        }
    }
    issues := ""
    if (same.Length > 0) {
        issues .= "- Another layout in this folder already uses the name '" . name . "':`n"
        for f in same
            issues .= "     " . f . "`n"
        issues .= "  Bangla Keyboard knows layouts by name, so only one of them will work properly.`n`n"
    }
    if (EffType() = 2) {
        probs := AnsiProblems()
        if (probs.Length > 0) {
            issues .= "- This is an ANSI layout, but these characters are not in the ANSI (Windows-1252) set, so an old Bangla font cannot show them:`n"
            cnt := 0
            for pr in probs {
                cnt++
                if (cnt > 8) {
                    issues .= "     ... and " . (probs.Length - 8) . " more`n"
                    break
                }
                issues .= "     " . pr . "`n"
            }
            issues .= "`n"
        }
    }
    if (issues = "")
        return true
    r := MsgBox(issues . "Save anyway?", "Bangla Layout Builder - check before saving", "0x34 Owner" . LB.g.Hwnd)
    return (r = "Yes")
}

; ---- undo / redo / copy key ----------------------------------------------------------------
Snap() {
    ks := Map()
    for vk, k in LB.keys
        ks[vk] := [k.nor, k.shf, k.nOpt, k.sOpt]
    ex := Map()
    for vk, k in LB.extra
        ex[vk] := [k.nor, k.shf, k.nOpt, k.sOpt]
    js := []
    for j in LB.juks
        js.Push([j.seq, j.out])
    return {keys: ks, extra: ex, juks: js}
}

KeyFrom(arr) {
    o := NewKeyObj()
    o.nor := arr[1]
    o.shf := arr[2]
    o.nOpt := arr[3]
    o.sOpt := arr[4]
    return o
}

RestoreSnap(sn) {
    for vk, arr in sn.keys
        LB.keys[vk] := KeyFrom(arr)
    LB.extra := Map()
    for vk, arr in sn.extra
        LB.extra[vk] := KeyFrom(arr)
    LB.juks := []
    for arr in sn.juks
        LB.juks.Push({seq: arr[1], out: arr[2]})
    RefreshAllKeys()
    FillJuks()
    LoadEditor()
    UpdateEncoding()
    RefreshViewer()
    MarkDirty()
}

; call BEFORE changing the model. A tag groups quick typing in one box into one step.
PushUndo(tag := "") {
    now := A_TickCount
    if (tag != "" && tag == LB.lastTag && now - LB.lastTick < 1500) {
        LB.lastTick := now
        return
    }
    LB.undo.Push(Snap())
    if (LB.undo.Length > 100)
        LB.undo.RemoveAt(1)
    LB.redo := []
    LB.lastTag := tag
    LB.lastTick := now
    UpdateUndoButtons()
}

ClearUndo() {
    LB.undo := []
    LB.redo := []
    LB.lastTag := ""
    UpdateUndoButtons()
}

UpdateUndoButtons() {
    if !IsObject(LB.btnUndo)
        return
    LB.btnUndo.Enabled := (LB.undo.Length > 0)
    LB.btnRedo.Enabled := (LB.redo.Length > 0)
}

DoUndo(*) {
    if (LB.undo.Length = 0)
        return
    LB.redo.Push(Snap())
    RestoreSnap(LB.undo.Pop())
    LB.lastTag := ""
    UpdateUndoButtons()
}

DoRedo(*) {
    if (LB.redo.Length = 0)
        return
    LB.undo.Push(Snap())
    RestoreSnap(LB.redo.Pop())
    LB.lastTag := ""
    UpdateUndoButtons()
}

; boxes that keep their own Ctrl+Z (typing undo) instead of the layout undo
NativeEditFocused() {
    try {
        hf := ControlGetFocus("ahk_id " . LB.g.Hwnd)
    } catch {
        return false
    }
    for c in [LB.edSeq, LB.edOut, LB.edFind, LB.edIn, LB.edName] {
        if (hf = c.Hwnd)
            return true
    }
    return false
}

UndoKey() {
    if NativeEditFocused()
        Send("^z")
    else
        DoUndo()
}

RedoKey() {
    if NativeEditFocused()
        Send("^y")
    else
        DoRedo()
}

CopyKey(*) {
    if !LB.sel
        return
    k := LB.keys[LB.sel]
    LB.clip := [k.nor, k.shf, k.nOpt, k.sOpt]
    ToolTip("Copied key " . CapName(LB.sel))
    SetTimer(HideTip, -1200)
}

HideTip(*) {
    ToolTip()
}

PasteKey(*) {
    if (!LB.sel || !IsObject(LB.clip))
        return
    PushUndo()
    k := LB.keys[LB.sel]
    k.nor := LB.clip[1]
    k.shf := LB.clip[2]
    k.nOpt := LB.clip[3]
    k.sOpt := LB.clip[4]
    LoadEditor()
    KeyChanged()
}

; ---- joining rule tools: import / export / standard rules -----------------------------------
UpsertJuk(seq, out) {
    for j in LB.juks {
        if (j.seq == seq) {
            j.out := out
            return 0
        }
    }
    LB.juks.Push({seq: seq, out: out})
    return 1
}

WriteText(path, txt) {
    f := FileOpen(path, "w", "UTF-8")
    f.Write(txt)
    f.Close()
}

ExportRules(*) {
    if (LB.juks.Length = 0) {
        MsgBox("There are no joining rules to export.", "Bangla Layout Builder", "0x40 Owner" . LB.g.Hwnd)
        return
    }
    path := FileSelect("S16", LB.layoutsDir . "\" . SafeName(LB.edName.Value) . " rules.txt", "Export joining rules", "Rules (*.txt; *.tsv; *.csv)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.(txt|tsv|csv)$")
        path .= ".txt"
    txt := "# Joining rules. One rule per line: typed sequence, then a TAB, then what it becomes." . "`r`n"
    for j in LB.juks
        txt .= j.seq . "`t" . j.out . "`r`n"
    try {
        WriteText(path, txt)
        MsgBox("Exported " . LB.juks.Length . " rules to:`n" . path, "Bangla Layout Builder", "0x40 Owner" . LB.g.Hwnd)
    } catch as e {
        MsgBox("Could not save the file:`n`n" . e.Message, "Bangla Layout Builder", "0x10 Owner" . LB.g.Hwnd)
    }
}

ImportRules(*) {
    path := FileSelect(3, LB.layoutsDir . "\", "Import joining rules", "Rules (*.txt; *.tsv; *.csv)")
    if (path = "")
        return
    try {
        txt := FileRead(path, "UTF-8")
    } catch as e {
        MsgBox("Could not read the file:`n`n" . e.Message, "Bangla Layout Builder", "0x10 Owner" . LB.g.Hwnd)
        return
    }
    PushUndo()
    added := 0
    updated := 0
    skipped := 0
    Loop Parse txt, "`n", "`r" {
        line := A_LoopField
        if (Trim(line) = "" || SubStr(line, 1, 1) = "#")
            continue
        cut := InStr(line, "`t")
        if !cut
            cut := InStr(line, ",")
        if !cut {
            skipped++
            continue
        }
        sq := SubStr(line, 1, cut - 1)
        ot := SubStr(line, cut + 1)
        if (sq = "") {
            skipped++
            continue
        }
        if UpsertJuk(sq, ot)
            added++
        else
            updated++
    }
    if (added + updated = 0) {
        LB.undo.Pop()
        UpdateUndoButtons()
        MsgBox("No rules were found in this file.`n`nUse one rule per line: typed sequence, a TAB, then what it becomes.", "Bangla Layout Builder", "0x30 Owner" . LB.g.Hwnd)
        return
    }
    MarkDirty()
    FillJuks()
    UpdateEncoding()
    msg := "Imported " . (added + updated) . " rules (" . added . " new, " . updated . " updated)."
    if skipped
        msg .= "`n" . skipped . " lines were skipped because they were not in the right form."
    MsgBox(msg, "Bangla Layout Builder", "0x40 Owner" . LB.g.Hwnd)
}

; the usual Bijoy-style Unicode rules
StdRules() {
    r := []
    for pr in [[0x09BF, 0x0987], [0x09C0, 0x0988], [0x09C1, 0x0989], [0x09C2, 0x098A], [0x09C3, 0x098B], [0x09C7, 0x098F], [0x09C8, 0x0990], [0x09CB, 0x0993], [0x09CC, 0x0994], [0x09D7, 0x0994], [0x09BE, 0x0986]]
        r.Push([Chr(0x09CD) . Chr(pr[1]), Chr(pr[2])])
    r.Push([Chr(0x0985) . Chr(0x09BE), Chr(0x0986)])
    r.Push([Chr(0x09C7) . Chr(0x09D7), Chr(0x09CC)])
    r.Push([Chr(0x09C7) . Chr(0x09BE), Chr(0x09CB)])
    return r
}

JukDeleteAll(*) {
    n := LB.juks.Length
    if (n = 0) {
        MsgBox("There are no joining rules to delete.", "Bangla Layout Builder", "0x40 Owner" . LB.g.Hwnd)
        return
    }
    r := MsgBox("Delete ALL " . n . " joining rules of this layout?`n`nYou can use Undo afterwards.", "Delete all rules", "0x124 Owner" . LB.g.Hwnd)
    if (r != "Yes")
        return
    PushUndo()
    LB.juks := []
    LB.edSeq.Value := ""
    LB.edOut.Value := ""
    MarkDirty()
    FillJuks()
    UpdateEncoding()
}

AddStdRules(*) {
    rules := StdRules()
    r := MsgBox("Add the " . rules.Length . " standard Bijoy-style vowel rules?`n`nExamples: hasanta + i-kar becomes the letter " . Chr(0x0987) . ", e-kar + aa-kar becomes o-kar " . Chr(0x09CB) . ".`n`nRules that already exist are updated, nothing is added twice. You can use Undo afterwards.", "Add standard vowel rules", "0x24 Owner" . LB.g.Hwnd)
    if (r != "Yes")
        return
    PushUndo()
    added := 0
    for rl in rules
        added += UpsertJuk(rl[1], rl[2])
    MarkDirty()
    FillJuks()
    UpdateEncoding()
    MsgBox(added . " new rules added, " . (rules.Length - added) . " already existed and were updated.", "Bangla Layout Builder", "0x40 Owner" . LB.g.Hwnd)
}

; ---- Layout Viewer tab ----------------------------------------------------------------------
ViewColor(vk) {
    k := LB.keys[vk]
    if (k.nOpt != "" || k.sOpt != "")
        return "FFE2A0"
    if IsCustom(vk)
        return "CFEFD6"
    return "EDEDED"
}

HkNice(hk) {
    if (hk = "")
        return "None"
    out := ""
    while (hk != "" && InStr("^!+#", SubStr(hk, 1, 1))) {
        ch := SubStr(hk, 1, 1)
        out .= (ch = "^") ? "Ctrl+" : (ch = "!") ? "Alt+" : (ch = "+") ? "Shift+" : "Win+"
        hk := SubStr(hk, 2)
    }
    return out . StrUpper(hk)
}

ChangedCount() {
    cnt := 0
    for vk in LB.keys {
        if (vk != 32 && IsCustom(vk))
            cnt++
    }
    return cnt
}

TypeName() {
    return ["Unicode", "ANSI (legacy font)", "Other language"][EffType()]
}

RefreshViewer(*) {
    if (LB.vcaps.Count = 0)
        return
    for vk in LB.vcaps
        PaintKey(vk, true)
    LB.lblV1.Text := "Layout: " . LB.edName.Value . "     Type: " . TypeName() . "     Shortcut: " . HkNice(LB.hkSc.Value) . "     Changed keys: " . ChangedCount() . "     Joining rules: " . LB.juks.Length
}

BuildChartHtml(autoPrint) {
    nl := "`r`n"
    t := EffType()
    if (LB.pFont != "")
        fam := "'" . LB.pFont . "', 'Nirmala UI', sans-serif"
    else if (t = 2)
        fam := "SutonnyMJ, 'Nirmala UI', sans-serif"
    else
        fam := "'Nirmala UI', 'Noto Sans Bengali', 'Segoe UI', sans-serif"
    ; text sizes follow the key size (as in the app); --u is the width of one key unit
    vf := Round(0.25 * (LB.kScale / 100) * FaceBoost(), 3)
    h := "<!DOCTYPE html>" . nl . "<html><head><meta charset='utf-8'><title>" . XmlEsc(LB.edName.Value) . " - keyboard layout</title>" . nl
    h .= "<meta name='viewport' content='width=device-width, initial-scale=1'>" . nl
    h .= "<style>" . nl
    h .= "body{margin:16px;background:#fff;color:#000}" . nl
    h .= ".kb{--u:min(84px,calc((100vw - 32px) / 15));width:calc(var(--u) * 15)}" . nl
    h .= ".row{display:flex;margin-bottom:4px}" . nl
    h .= ".key{box-sizing:border-box;position:relative;height:calc(var(--u) * 0.92 - 4px);margin-right:4px;border:1px solid #888;background:#fff;color:#000}" . nl
    h .= ".key.lab{background:#f3f3f3;color:#888;display:flex;align-items:center;justify-content:center;font:calc(var(--u) * 0.22) 'Segoe UI',Arial,sans-serif}" . nl
    h .= ".key .e{position:absolute;left:9%;top:50%;transform:translateY(-50%);font:calc(var(--u) * 0.34) 'Segoe UI',Arial,sans-serif}" . nl
    h .= ".key .s,.key .n{position:absolute;right:8%;line-height:1;font-family:" . fam . ";font-size:calc(var(--u) * " . vf . ")}" . nl
    h .= ".key .s{top:8%}" . nl
    h .= ".key .n{bottom:8%}" . nl
    h .= "@page{size:landscape;margin:10mm}" . nl
    h .= "</style>" . nl
    if autoPrint
        h .= "<script>window.onload=function(){setTimeout(function(){window.print()},400)}</script>" . nl
    h .= "</head><body><div class='kb'>" . nl
    for row in KbRows() {
        ks := ""
        for it in row {
            id := it[1]
            w := "calc(var(--u) * " . it[2] . " - 4px)"
            if IsInteger(id) {
                ks .= "<div class='key' style='width:" . w . "'><span class='e'>" . XmlEsc(CapName(id)) . "</span>"
                if IsCustom(id)
                    ks .= "<span class='s'>" . XmlEsc(EffShf(id)) . "</span><span class='n'>" . XmlEsc(EffNor(id)) . "</span>"
                ks .= "</div>"
            } else {
                ks .= "<div class='key lab' style='width:" . w . "'>" . XmlEsc(id) . "</div>"
            }
        }
        h .= "<div class='row'>" . ks . "</div>" . nl
    }
    h .= "</div></body></html>"
    return h
}

PrintChart(*) {
    f := A_Temp . "\BanglaLayoutChart.html"
    try {
        WriteText(f, BuildChartHtml(true))
        Run('"' . f . '"')
    } catch as e {
        MsgBox("Could not open the chart:`n`n" . e.Message, "Bangla Layout Builder", "0x10 Owner" . LB.g.Hwnd)
    }
}

; ---- Save as image: the keyboard picture exactly as it is drawn on the Layout Viewer tab ---------
SaveViewerImage(*) {
    if !LB.ui.Has("vRect")
        return
    path := FileSelect("S16", LB.layoutsDir . "\" . SafeName(LB.edName.Value) . " keyboard.png", "Save keyboard picture", "Image (*.png; *.jpg; *.bmp)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.(png|jpe?g|bmp)$")
        path .= ".png"
    RefreshViewer()
    Sleep(50)                                   ; let the keys finish drawing before the picture is taken
    ok := CaptureRegionToFile(LB.g.Hwnd, LB.ui["vRect"], path)
    if ok {
        try Run('"' . path . '"')
    } else {
        MsgBox("Could not save the picture.", "Bangla Layout Builder", "0x10 Owner" . LB.g.Hwnd)
    }
}

; copy a rectangle (client pixels) of the window, as drawn, into an image file (png / jpg / bmp)
CaptureRegionToFile(hwnd, r, path) {
    x := r[1], y := r[2], w := r[3], h := r[4]
    if (w < 4 || h < 4)
        return false
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "ptr", hwnd, "ptr", rc)
    cw := NumGet(rc, 8, "int")
    ch := NumGet(rc, 12, "int")
    hdc := DllCall("GetDC", "ptr", hwnd, "ptr")
    full := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
    fbm := DllCall("CreateCompatibleBitmap", "ptr", hdc, "int", cw, "int", ch, "ptr")
    fOld := DllCall("SelectObject", "ptr", full, "ptr", fbm, "ptr")
    DllCall("PrintWindow", "ptr", hwnd, "ptr", full, "uint", 3)        ; client area only, full content
    crop := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
    cbm := DllCall("CreateCompatibleBitmap", "ptr", hdc, "int", w, "int", h, "ptr")
    cOld := DllCall("SelectObject", "ptr", crop, "ptr", cbm, "ptr")
    DllCall("BitBlt", "ptr", crop, "int", 0, "int", 0, "int", w, "int", h, "ptr", full, "int", x, "int", y, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", crop, "ptr", cOld)
    DllCall("SelectObject", "ptr", full, "ptr", fOld)

    ok := false
    DllCall("LoadLibrary", "str", "gdiplus")
    si := Buffer((A_PtrSize = 8) ? 24 : 16, 0)
    NumPut("uint", 1, si)
    tok := 0
    if (DllCall("gdiplus\GdiplusStartup", "ptr*", &tok, "ptr", si, "ptr", 0) = 0) {
        pbm := 0
        if (DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", cbm, "ptr", 0, "ptr*", &pbm) = 0) {
            SplitPath(path, , , &ext)
            ext := StrLower(ext)
            mime := (ext = "jpg" || ext = "jpeg") ? "image/jpeg" : (ext = "bmp") ? "image/bmp" : "image/png"
            clsid := Buffer(16, 0)
            if EncoderClsid(mime, clsid)
                ok := (DllCall("gdiplus\GdipSaveImageToFile", "ptr", pbm, "wstr", path, "ptr", clsid, "ptr", 0) = 0)
            DllCall("gdiplus\GdipDisposeImage", "ptr", pbm)
        }
        DllCall("gdiplus\GdiplusShutdown", "ptr", tok)
    }
    DllCall("DeleteObject", "ptr", cbm)
    DllCall("DeleteObject", "ptr", fbm)
    DllCall("DeleteDC", "ptr", crop)
    DllCall("DeleteDC", "ptr", full)
    DllCall("ReleaseDC", "ptr", hwnd, "ptr", hdc)
    return ok
}

; find the GDI+ encoder for a mime type and copy its class id into clsid
EncoderClsid(mime, clsid) {
    n := 0
    sz := 0
    DllCall("gdiplus\GdipGetImageEncodersSize", "uint*", &n, "uint*", &sz)
    if (n = 0 || sz = 0)
        return false
    buf := Buffer(sz, 0)
    DllCall("gdiplus\GdipGetImageEncoders", "uint", n, "uint", sz, "ptr", buf)
    isz := 48 + 7 * A_PtrSize                  ; size of one ImageCodecInfo record
    Loop n {
        off := (A_Index - 1) * isz
        mt := StrGet(NumGet(buf, off + 32 + 4 * A_PtrSize, "ptr"), "UTF-16")
        if (mt = mime) {
            DllCall("RtlMoveMemory", "ptr", clsid, "ptr", buf.Ptr + off, "uptr", 16)
            return true
        }
    }
    return false
}

SaveChartHtml(*) {
    path := FileSelect("S16", LB.layoutsDir . "\" . SafeName(LB.edName.Value) . " chart.html", "Save keyboard chart", "Web page (*.html)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.html?$")
        path .= ".html"
    try {
        WriteText(path, BuildChartHtml(false))
        Run('"' . path . '"')
    } catch as e {
        MsgBox("Could not save the chart:`n`n" . e.Message, "Bangla Layout Builder", "0x10 Owner" . LB.g.Hwnd)
    }
}

; ---- drag and drop a layout file onto the window -----------------------------------------------
OnDropFiles(gObj, ctrlObj, files, x, y) {
    for f in files {
        if RegExMatch(f, "i)\.xml$") {
            SetTimer(OpenDropped.Bind(f), -10)         ; let Explorer finish the drop first
            return
        }
    }
    SetTimer(DropHint, -10)
}

OpenDropped(f) {
    if ConfirmDiscard()
        OpenPath(f)
}

DropHint() {
    MsgBox("Drop a layout file (.xml) here to open it.", "Bangla Layout Builder", "0x40 Owner" . LB.g.Hwnd)
}

GuideTextEn() {
    t := "
(
GUIDE  -  read from the top, or jump to the part you need
=============================================================
This program lets you make your own Bangla keyboard layout. A layout only says: 'when I press THIS key, write THAT letter'. You do not need to know programming. Read Part 1 and Part 2 first. Come back to the other parts when you need them.


CONTENTS
  Part 1  The Keys tab (the keyboard picture)
  Part 2  5-minute practice: make your first key
  Part 3  Options explained (Delay, DeInc1, DeInc2, MoveL, Xtra)
  Part 4  Joining rules
  Part 5  Try your layout
  Part 6  Making a Unicode layout, step by step
  Part 7  Making an ANSI layout, step by step
  Part 8  Saving and using your layout
  Part 9  Common problems and quick answers
  Part 10 Extra tools (type indicator, undo, viewer, import/export, drag and drop)


=============================================================
PART 1  -  THE KEYS TAB (the keyboard picture)
=============================================================
The picture on the Keys tab is your keyboard. Click a key to select it. Under the picture you will see two boxes for that key:
   Normal  =  what the key writes when you press it alone
   Shift   =  what the key writes when you hold Shift and press it
Type the letter you want inside the box. If you leave a box as it is (an English letter), the key stays a plain English key.


Colours of the keys:
   Grey   = plain English key (not changed)
   Green  = you changed it
   Orange = it has a special Option (see Part 3)
   Blue   = the key you have selected now


The small buttons next to the boxes put a special character into the box where your cursor was last: 'Hasanta' (the sign that joins two letters), 'ZWNJ' and 'ZWJ' (invisible helper characters). Click inside a box first, then press the button. 'Reset this key' turns the key back into a plain English key.


=============================================================
PART 2  -  5-MINUTE PRACTICE: MAKE YOUR FIRST KEY
=============================================================

 1. Click the K key on the picture.
 2. In the Normal box type:  ক     In the Shift box type:  খ
 3. The K key turns green. That means it is changed.
 4. Open the 'Try your layout' tab and type:  kK
    You will see:  কখ
    (small k gives the Normal letter, capital K gives the Shift letter)
 5. Press Save and choose a place. Done! Your first key works.


=============================================================
PART 3  -  OPTIONS EXPLAINED
=============================================================
Why do options exist? Bangla has a small problem. The i-kar sign (ি) is drawn on the LEFT of its letter, so people type it FIRST. But the computer must store it AFTER the letter. Options are tools that fix this for you. Most keys need NO option. Only a few special keys do. Every key has one Option box for Normal and one for Shift.


QUICK CHEAT SHEET
   If the key writes...                         Choose this Option
   ি   ে   ৈ   (signs that sit on the left)     Delay
   ্র   ্য   ্   (phala and hasanta keys)         DeInc1  (or DeInc2)
   র্   (ref)                                    MoveL
   everything else                               (none)

-------------------------------------------------------------
(none)
-------------------------------------------------------------
The key just writes what is in its box. Use it for letters, digits, punctuation, and for signs that go AFTER the letter (া ী ু ূ ৃ).
   Example: the K key = ক. You press K and you get ক.


-------------------------------------------------------------
Delay
-------------------------------------------------------------
Use it for the signs that sit on the LEFT:  ি (i-kar)   ে (e-kar)   ৈ (ai-kar).
The sign shows on screen at once, exactly like Bijoy. When you then type the letter, the sign jumps behind it.
   Example: D key, Normal = ি , Option = Delay
      press D, then press K (ক)   =>   কি
   It also works with conjuncts. The sign waits until the whole conjunct is finished:
      ে , then ক , then hasanta , then ষ   =>   ক্ষে
      (the hasanta key needs DeInc1 or DeInc2, see below)
   If you forget Delay, the sign stays in front of the letter in the file, which is the wrong order.


-------------------------------------------------------------
DeInc1
-------------------------------------------------------------
Use it for a key that writes a hasanta, or a hasanta + letter:  ্র (ra-phala)   ্য (ya-phala).
If a left sign (typed with Delay) is still waiting, this key puts its output IN FRONT of the waiting sign. So the conjunct is finished first and the sign goes to the very end.
   Example: Z key, Normal = ্র , Option = DeInc1
      ে , ক , Z   =>   ক্রে    (correct)
      Without DeInc1 you would get  কে্র   (wrong)
   Special rule (only DeInc1 does this): when ্য comes right after র, an invisible ZWNJ is added between them. This makes it read as র with ya-phala, not as ref + য.


-------------------------------------------------------------
DeInc2
-------------------------------------------------------------
Exactly like DeInc1, but WITHOUT the special র + ্য rule. Use it for a plain hasanta key, or any phala key that must never add a ZWNJ.
   Example: G key, Normal = ্ (hasanta) , Option = DeInc2
      ে , ক , G , ষ   =>   ক্ষে


-------------------------------------------------------------
MoveL
-------------------------------------------------------------
Use it for the ref key (র্).
You press it AFTER the letter, but the ref is written BEFORE the whole conjunct, as in real Bangla.
   Example: A key, Shift box = র্ , Shift Option = MoveL
      ধ , then Shift+A   =>   র্ধ
      ক্ষ , then Shift+A   =>   র্ক্ষ    (ref goes in front of the whole conjunct)


-------------------------------------------------------------
Xtra
-------------------------------------------------------------
Bangla Keyboard does nothing special with it. It exists only so old Bijoy layout files open and save without losing anything. Just leave it alone. It behaves like (none).


TIP
After you set an option, always test it in the 'Try your layout' tab. It uses the same typing engine as Bangla Keyboard.


=============================================================
PART 4  -  JOINING RULES
=============================================================
A joining rule turns a short typed sequence into something else, right after you press the key. It has two columns:
   Typed sequence  =  the characters the keys wrote, in order (NOT the English letters you pressed)
   Becomes         =  what should replace them
   Example 1:  ে + া   becomes   ো
      Press the e-kar key, then the aa-kar key, and you get the o-kar sign ো.
   Example 2:  ্ + ি   becomes   ই
      Press the hasanta key, then the i-kar key, and you get the full letter ই.


How to use the tab:
 1. Use the Search box to find a rule.
 2. Click a rule in the list. Its two parts appear in the boxes below.
 3. Change them, then press 'Add / Update'. If the same Typed sequence already exists, it is updated, not added twice.
 4. To remove a rule, select it and press 'Delete selected'.
 If two rules fit, the LONGEST typed sequence wins.


=============================================================
PART 5  -  TRY YOUR LAYOUT
=============================================================
Type ENGLISH letters in the top box, exactly like pressing the keys. The bottom box shows what your layout writes. It also works for changes you have not saved yet, so test after every change.
   Example (a layout with ি on D using Delay, and ক on K):
      type  dk   =>   কি
Keys you did not change stay English.
'Preview font' decides how the result is drawn: 'Unicode (Nirmala UI)' for normal Bangla layouts, 'ANSI (SutonnyMJ)' for ANSI layouts, 'Other language (Segoe UI)' for other scripts. It is chosen automatically. Change it by hand if the result looks strange.


=============================================================
PART 6  -  MAKING A UNICODE LAYOUT, STEP BY STEP
=============================================================
Unicode means every key writes a real Bangla letter (like ক). It works in every program and every Bangla font.
 1. Easiest start: press Open and load 'Bijoy Unicode.xml'. Change what you like. Then press 'Save As' and give a NEW name. (Or press New to begin from nothing.)
 2. Name: type a name that no other layout has. Icon: choose 'Unicode'. Shortcut: click the box and press the keys you want, for example Ctrl+Alt+M. It must contain Ctrl or Alt (or be a single F-key).
 3. Click a key. Type the Bangla letter in Normal and in Shift. You can type it with your current Bangla keyboard, or copy and paste it.
 4. Set Options on the special keys (see the cheat sheet in Part 3).
 5. Add Joining rules for combinations (Part 4).
 6. Test everything in 'Try your layout'.
 7. Press Save (or Ctrl+S).


=============================================================
PART 7  -  MAKING AN ANSI LAYOUT, STEP BY STEP
=============================================================
What is ANSI? In an ANSI layout the keys do NOT write real Bangla letters. They write ordinary English-looking characters, and an old Bangla font such as SutonnyMJ draws them as Bangla.
   Example: in SutonnyMJ the character  k  is drawn as ক  and  v  is drawn as া . In a normal font the same text looks like English nonsense. That is normal for ANSI.
The XML file is still saved as UTF-8. Only the characters you choose must belong to the Windows-1252 (ANSI) set.
Allowed: English letters, digits and punctuation; Latin-1 letters and signs (accented letters, the pound and copyright signs); and the Windows-1252 extras (curly quotes, dashes, the ellipsis, the trademark sign, the f-hook). Do NOT put real Bangla letters in an ANSI layout.


Step by step:
 1. Easiest start: press Open and load 'Bijoy Classic.xml' (it is an ANSI layout). Then press 'Save As' and give your copy a NEW name. Or press New and set Icon to 'Classic'.
 2. Name must be unique. Bangla Keyboard knows layouts by their name.
 3. Click a key. Type the ANSI character(s) in Normal and in Shift.
    How to type a special ANSI character:
      - hold Alt and type its code on the number pad, for example Alt + 0198
      - or copy it from the Character Map program (choose the font SutonnyMJ)
      - or copy it from an existing ANSI layout
 4. Leave every Option box EMPTY. Old fonts store each sign in the order you SEE it, so i-kar and e-kar are already typed before the letter. Delay, DeInc1, DeInc2 and MoveL are only for Unicode.
 5. Conjuncts: in an ANSI font a conjunct is ONE special character. Use the Joining rules tab. 'Typed sequence' = what the keys write, in order. 'Becomes' = the single ANSI glyph.
    Example from Bijoy Classic:  &v  becomes  Av   (hasanta + aa-kar becomes the letter আ)
 6. Open 'Try your layout'. Set Preview font to 'ANSI (SutonnyMJ)' (it is chosen for you when the layout has no Bangla letters). SutonnyMJ must be installed in Windows.
 7. Press Save.


Good to know: the boxes on the Keys tab show the raw ANSI characters, because they are drawn with a Unicode font. That is expected.


=============================================================
PART 8  -  SAVING AND USING YOUR LAYOUT
=============================================================

   Save         saves into the file you opened (asks for a place the first time)
   Save As...   saves a copy under a new name
   Ctrl+S       same as Save
   Layouts folder...   chooses the folder this program uses. You can point it straight at the Layouts folder of Bangla Keyboard.
   Show folder  opens that folder in Windows
To use your layout: copy the saved file into the Layouts folder of Bangla Keyboard, then restart Bangla Keyboard.
Save As ফাইলটি .xml হিসেবে সেভ করে। Open এবং ড্র্যাগ-অ্যান্ড-ড্রপ .xml ফাইল খুলতে পারে।


=============================================================
PART 9  -  COMMON PROBLEMS AND QUICK ANSWERS
=============================================================
Problem: I typed the sign first but it stays in front of the letter (েক instead of কে).
    Answer: the sign key has no Delay option. Set Option = Delay (Part 3).

Problem: the sign lands in the middle of a conjunct (কে্র instead of ক্রে).
    Answer: the hasanta or phala key needs DeInc1 or DeInc2.

Problem: the ref comes after the letter instead of before.
    Answer: the ref key needs the MoveL option.

Problem: strange English letters show in the result box.
    Answer: this is an ANSI layout. Set Preview font to 'ANSI (SutonnyMJ)' and make sure the font is installed.

Problem: a key stays grey after I typed into its box.
    Answer: grey means 'same as the English key'. If what you typed is the same English letter, nothing has changed.

Problem: my layout does not appear in Bangla Keyboard.
    Answer: check three things: (1) the .xml file is inside Bangla Keyboard's Layouts folder, (2) you restarted Bangla Keyboard, (3) the layout Name is different from every other layout.

Problem: the program says the shortcut is not accepted.
    Answer: a shortcut needs Ctrl or Alt in it (or must be a single F-key such as F8).

Problem: I made a mess and want to undo one key.
    Answer: select the key and press 'Reset this key'. If you have not saved, you can also just press Open and load the file again.

=============================================================
PART 10  -  EXTRA TOOLS
=============================================================
LAYOUT TYPE INDICATOR  (top right of the window)
   A coloured label shows what kind of layout you are making:
      green  = Unicode (real Bangla letters)
      orange = ANSI (old fonts like SutonnyMJ)
      blue   = Other language
   The 'Type' box next to it has four choices: Auto-detect, Unicode, ANSI (legacy font), Other language.
   Auto-detect looks at what your keys write: Bangla letters = Unicode; plain English-looking characters = ANSI; letters of another script = Other language. If it guesses wrong, choose the type yourself.
   The type decides the preview font in 'Try your layout' and 'Layout Viewer', and it switches on the ANSI check when you save. Your choice is remembered for that layout file on this computer. It is NOT written into the .xml file, so the file stays exactly as Bangla Keyboard expects.

CHECK BEFORE SAVING
   When you press Save, the program warns you if:
    - another layout file in the same folder has the same Name (Bangla Keyboard knows layouts by name, so only one of them would work properly)
    - an ANSI layout has characters that are not in the ANSI (Windows-1252) set, so an old font cannot show them
   You can still choose 'Yes' to save anyway.

UNDO AND REDO
   Use the Undo and Redo buttons at the top, or Ctrl+Z and Ctrl+Y. They go back or forward through your changes to keys, options and joining rules (up to 100 steps). Opening or creating a layout starts a fresh history.
   When your cursor is in the Name, Search or Try boxes, Ctrl+Z undoes the typing in that box instead.

COPY KEY AND PASTE KEY
   Select a key and press 'Copy key'. Select another key and press 'Paste key'. The letters and options of both Normal and Shift are copied. This is fast for making similar keys.

JOINING RULE TOOLS  (Joining rules tab)
   Import...   reads a text file with one rule per line: typed sequence, then a TAB, then what it becomes. Lines that start with # are ignored. If a sequence already exists it is updated.
   Export...   saves all your rules in the same simple format. Open it in Notepad or Excel, share it or keep it as a backup.
   Add standard vowel rules   adds the usual Bijoy-style Unicode rules: hasanta + vowel sign becomes the full vowel (for example  ্ + ি  becomes  ই ), e-kar + aa-kar becomes o-kar  ো , and so on. Rules that already exist are updated, nothing is added twice. Use Undo if you do not like the result.
   Note: ordinary conjuncts in a Unicode layout need no rule. Typing letter + hasanta + letter already makes the conjunct.

LAYOUT VIEWER TAB
   Shows your whole layout as a keyboard picture. Each key shows Shift on top and Normal below. Green = changed, orange = has a special Option. For ANSI layouts the keys are drawn with SutonnyMJ, so you see real Bangla if the font is installed.
   'Print...' opens the chart in your web browser, ready to print. 'Save as web page...' keeps it as an .html file you can share. The chart also lists your joining rules.

DRAG AND DROP
   Drag a layout .xml file from Windows Explorer and drop it on the window to open it. If you have unsaved changes you are asked about them first.
)"
    return t
}

GuideTextBn() {
    t := "
(
নির্দেশিকা  -  ওপর থেকে পড়ুন, অথবা যে অংশ দরকার সেখানে চলে যান
=============================================================

এই প্রোগ্রাম দিয়ে আপনি নিজের বাংলা কীবোর্ড লেআউট বানাতে পারবেন। লেআউট মানে শুধু এটুকু বলে দেওয়া: 'এই কী চাপলে ওই অক্ষর লেখা হবে'। প্রোগ্রামিং জানার দরকার নেই। আগে পর্ব ১ ও পর্ব ২ পড়ুন। বাকি পর্বগুলো দরকার হলে পরে দেখে নেবেন।

সূচিপত্র
  পর্ব ১  Keys ট্যাব (কীবোর্ডের ছবি)
  পর্ব ২  ৫ মিনিটের অনুশীলন: আপনার প্রথম কী বানান
  পর্ব ৩  অপশনের ব্যাখ্যা (Delay, DeInc1, DeInc2, MoveL, Xtra)
  পর্ব ৪  জয়েনিং রুল
  পর্ব ৫  নিজের লেআউট পরীক্ষা করুন
  পর্ব ৬  ইউনিকোড লেআউট বানানো, ধাপে ধাপে
  পর্ব ৭  ANSI লেআউট বানানো, ধাপে ধাপে
  পর্ব ৮  লেআউট সেভ ও ব্যবহার করা
  পর্ব ৯  সাধারণ সমস্যা ও দ্রুত সমাধান
  পর্ব ১০ অতিরিক্ত সুবিধা (ধরনের চিহ্ন, আনডু, ভিউয়ার, ইমপোর্ট/এক্সপোর্ট, ড্র্যাগ অ্যান্ড ড্রপ)


=============================================================
পর্ব ১  -  Keys ট্যাব (কীবোর্ডের ছবি)
=============================================================

Keys ট্যাবের ছবিটাই আপনার কীবোর্ড। কোনো কী-তে ক্লিক করলে সেটি সিলেক্ট হবে। ছবির নিচে ওই কী-এর জন্য দুটি ঘর দেখবেন:
   Normal  =  কী-টি একা চাপলে যা লেখা হবে
   Shift   =  Shift চেপে ধরে কী-টি চাপলে যা লেখা হবে
ঘরের ভেতরে আপনার পছন্দের অক্ষরটি লিখে দিন। ঘর যেমন ছিল (ইংরেজি অক্ষর) তেমন রেখে দিলে কী-টি সাধারণ ইংরেজি কী-ই থাকবে।


কী-এর রং:
   ধূসর  = সাধারণ ইংরেজি কী (বদলানো হয়নি)
   সবুজ  = আপনি বদলেছেন
   কমলা  = বিশেষ অপশন আছে (পর্ব ৩ দেখুন)
   নীল   = এই মুহূর্তে সিলেক্ট করা কী


ঘরগুলোর পাশের ছোট বোতামগুলো সবশেষ যে ঘরে কার্সর ছিল সেখানে একটি বিশেষ চিহ্ন বসিয়ে দেয়: 'Hasanta' (হসন্ত, দুই অক্ষর জোড়ার চিহ্ন), 'ZWNJ' ও 'ZWJ' (চোখে দেখা যায় না এমন সহায়ক অক্ষর)। আগে ঘরের ভেতরে ক্লিক করুন, তারপর বোতাম চাপুন। 'Reset this key' চাপলে কী-টি আবার সাধারণ ইংরেজি কী হয়ে যাবে।


=============================================================
পর্ব ২  -  ৫ মিনিটের অনুশীলন: আপনার প্রথম কী বানান
=============================================================


 ১. ছবিতে K কী-তে ক্লিক করুন।
 ২. Normal ঘরে লিখুন:  ক     Shift ঘরে লিখুন:  খ
 ৩. K কী সবুজ হয়ে যাবে। মানে কী-টি বদলেছে।
 ৪. 'Try your layout' ট্যাবে গিয়ে লিখুন:  kK
    দেখবেন লেখা হয়েছে:  কখ
    (ছোট হাতের k দিলে Normal অক্ষর, বড় হাতের K দিলে Shift অক্ষর আসে)
 ৫. Save চাপুন এবং ফাইল রাখার জায়গা বেছে নিন। হয়ে গেল! আপনার প্রথম কী কাজ করছে।


=============================================================
পর্ব ৩  -  অপশনের ব্যাখ্যা
=============================================================

অপশন কেন আছে? বাংলায় একটা ছোট সমস্যা আছে। ই-কার (ি) অক্ষরের বাঁ দিকে বসে, তাই মানুষ আগে ই-কার টাইপ করে। কিন্তু কম্পিউটারে সেটা জমা হতে হয় অক্ষরের পরে। অপশনগুলো এই সমস্যা আপনার হয়ে মিটিয়ে দেয়। বেশিরভাগ কী-তে কোনো অপশন লাগে না, শুধু কয়েকটি বিশেষ কী-তে লাগে। প্রতিটি কী-এর Normal ও Shift-এর জন্য আলাদা Option ঘর আছে।

সংক্ষেপে (চিটশিট)
   কী যা লেখে                                   যে Option বেছে নেবেন
   ি   ে   ৈ   (বাঁ দিকে বসা চিহ্ন)     Delay
   ্র   ্য   ্   (ফলা ও হসন্ত কী)         DeInc1  (or DeInc2)
   র্   (রেফ)                                  MoveL
   বাকি সব                                      (none)
ি ে ৈ হলে Delay। ্র ্য ্ হলে DeInc1 (বা DeInc2)। র্ (রেফ) হলে MoveL। বাকি সব কিছুর জন্য (none)।

-------------------------------------------------------------
(none)
-------------------------------------------------------------

কী-টি ঘরে যা লেখা আছে শুধু সেটাই লেখে, আর কিছু করে না। অক্ষর, সংখ্যা, যতিচিহ্ন আর যেসব চিহ্ন অক্ষরের পরে বসে (া ী ু ূ ৃ) সেগুলোর জন্য এটাই ঠিক।
   উদাহরণ: K কী = ক। K চাপলে ক লেখা হবে।

-------------------------------------------------------------
Delay
-------------------------------------------------------------

বাঁ দিকে বসা চিহ্নগুলোর জন্য ব্যবহার করুন:  ি (ই-কার)   ে (এ-কার)   ৈ (ঐ-কার)।
চিহ্নটি সঙ্গে সঙ্গে পর্দায় দেখা যায়, ঠিক বিজয়ের মতো। তারপর অক্ষর টাইপ করলে চিহ্নটি অক্ষরের পিছনে চলে যায়।
   উদাহরণ: D কী, Normal = ি , Option = Delay
      D চাপুন, তারপর K (ক) চাপুন   =>   কি
   যুক্তাক্ষরের সঙ্গেও কাজ করে। চিহ্নটি অপেক্ষা করে, যুক্তাক্ষর শেষ হলে বসে:
      ে , তারপর ক , তারপর হসন্ত , তারপর ষ   =>   ক্ষে
      (হসন্ত কী-তে DeInc1 বা DeInc2 লাগবে, নিচে দেখুন)
   Delay দিতে ভুলে গেলে চিহ্নটি ফাইলে অক্ষরের আগেই থেকে যায়, যা ভুল ক্রম।

-------------------------------------------------------------
DeInc1
-------------------------------------------------------------

যে কী হসন্ত লেখে, অথবা হসন্ত + অক্ষর লেখে তার জন্য ব্যবহার করুন:  ্র (র-ফলা)   ্য (য-ফলা)।
বাঁ দিকের কোনো চিহ্ন (Delay দিয়ে টাইপ করা) তখনও অপেক্ষায় থাকলে এই কী নিজের লেখাটি ওই চিহ্নের ঠিক আগে বসায়। ফলে আগে যুক্তাক্ষর শেষ হয়, আর চিহ্নটি একদম শেষে যায়।
   উদাহরণ: Z কী, Normal = ্র , Option = DeInc1
      ে , ক , Z   =>   ক্রে    (ঠিক)
      DeInc1 না দিলে হতো  কে্র   (ভুল)
   বিশেষ নিয়ম (শুধু DeInc1-এ): র-এর ঠিক পরে ্য এলে দুটোর মাঝে একটি অদৃশ্য ZWNJ বসে। এতে সেটি র-এ য-ফলা হিসেবে পড়া হয়, রেফ + য হিসেবে নয়।

-------------------------------------------------------------
DeInc2
-------------------------------------------------------------

ঠিক DeInc1-এর মতো, শুধু র + ্য-এর বিশেষ নিয়মটি নেই। সাধারণ হসন্ত কী-এর জন্য, অথবা যে ফলা কী কখনও ZWNJ বসাবে না তার জন্য ব্যবহার করুন।
   উদাহরণ: G কী, Normal = ্ (হসন্ত) , Option = DeInc2
      ে , ক , G , ষ   =>   ক্ষে

-------------------------------------------------------------
MoveL
-------------------------------------------------------------

রেফ (র্) কী-এর জন্য ব্যবহার করুন।
আপনি এটি অক্ষরের পরে চাপেন, কিন্তু আসল বাংলার মতোই রেফ বসে পুরো যুক্তাক্ষরের আগে।
   উদাহরণ: A কী, Shift ঘরে = র্ , Shift Option = MoveL
      ধ , তারপর Shift+A   =>   র্ধ
      ক্ষ , তারপর Shift+A   =>   র্ক্ষ    (রেফ পুরো যুক্তাক্ষরের সামনে যায়)

-------------------------------------------------------------
Xtra
-------------------------------------------------------------

বাংলা কীবোর্ড এটি দিয়ে বিশেষ কিছু করে না। পুরনো বিজয় লেআউট ফাইল খুললে ও সেভ করলে যাতে কিছু হারিয়ে না যায়, শুধু সেজন্যই এটি আছে। এটি যেমন আছে তেমনই রেখে দিন। এটি (none)-এর মতোই কাজ করে।

টিপ
অপশন ঠিক করার পর সবসময় 'Try your layout' ট্যাবে পরীক্ষা করে নিন। এটি বাংলা কীবোর্ডের মতো একই টাইপিং ইঞ্জিন ব্যবহার করে।


=============================================================
পর্ব ৪  -  জয়েনিং রুল (Joining rules)
=============================================================

জয়েনিং রুল মানে: কী চাপার পরপরই ছোট একটি লেখার ক্রমকে অন্য কিছু দিয়ে বদলে দেওয়া। এর দুটি কলাম আছে:
   Typed sequence  =  কী-গুলো পরপর যা লিখেছে (আপনি যে ইংরেজি অক্ষর চেপেছেন সেগুলো নয়)
   Becomes         =  তার বদলে যা বসবে
   উদাহরণ ১:  ে + া   হয়ে যাবে   ো
      এ-কার কী চেপে আ-কার কী চাপলে ও-কার চিহ্ন ো পাবেন।
   উদাহরণ ২:  ্ + ি   হয়ে যাবে   ই
      হসন্ত কী চেপে ই-কার কী চাপলে পূর্ণ অক্ষর ই পাবেন।


ট্যাবটি যেভাবে ব্যবহার করবেন:
 ১. Search ঘরে লিখে রুল খুঁজে নিন।
 ২. তালিকার কোনো রুলে ক্লিক করুন। তার দুই অংশ নিচের ঘরে চলে আসবে।
 ৩. বদলে নিয়ে 'Add / Update' চাপুন। একই Typed sequence আগে থেকে থাকলে সেটি আপডেট হবে, দুবার যোগ হবে না।
 ৪. রুল মুছতে চাইলে সিলেক্ট করে 'Delete selected' চাপুন।
 দুটি রুল মিলে গেলে সবচেয়ে লম্বা Typed sequence-টি জেতে।


=============================================================
পর্ব ৫  -  নিজের লেআউট পরীক্ষা করুন (Try your layout)
=============================================================

ওপরের ঘরে ইংরেজি অক্ষর টাইপ করুন, ঠিক কী চাপার মতো করে। নিচের ঘরে দেখাবে আপনার লেআউট কী লিখছে। যে বদল এখনও সেভ করেননি সেগুলোও এখানে পরীক্ষা করা যায়, তাই প্রতিটি বদলের পর পরীক্ষা করুন।
   উদাহরণ (যে লেআউটে D কী-তে Delay দেওয়া ি এবং K কী-তে ক আছে):
      লিখুন  dk   =>   কি
যে কী বদলাননি সেগুলো ইংরেজিই থাকবে।
'Preview font' ঠিক করে ফলাফল কোন ফন্টে দেখাবে: সাধারণ বাংলা লেআউটের জন্য 'Unicode (Nirmala UI)', ANSI লেআউটের জন্য 'ANSI (SutonnyMJ)', অন্য লিপির জন্য 'Other language (Segoe UI)'। এটি নিজে থেকেই বেছে নেওয়া হয়। ফলাফল অদ্ভুত দেখালে নিজে বদলে নিন।


=============================================================
পর্ব ৬  -  ইউনিকোড লেআউট বানানো, ধাপে ধাপে
=============================================================

ইউনিকোড মানে প্রতিটি কী আসল বাংলা অক্ষর লেখে (যেমন ক)। এটি সব প্রোগ্রামে ও সব বাংলা ফন্টে কাজ করে।
 ১. সহজ শুরু: Open চেপে 'Bijoy Unicode.xml' খুলুন। যা ইচ্ছা বদলান। তারপর 'Save As' চেপে একটি নতুন নাম দিন। (অথবা একদম শূন্য থেকে শুরু করতে New চাপুন।)
 ২. Name: এমন একটি নাম দিন যা অন্য কোনো লেআউটের নেই। Icon: 'Unicode' বেছে নিন। Shortcut: ঘরে ক্লিক করে পছন্দের কী-গুলো চাপুন, যেমন Ctrl+Alt+M। এতে Ctrl বা Alt থাকতেই হবে (অথবা শুধু একটি F-কী)।
 ৩. একটি কী-তে ক্লিক করুন। Normal ও Shift ঘরে বাংলা অক্ষর লিখুন। আপনার চালু বাংলা কীবোর্ড দিয়ে লিখতে পারেন, অথবা কপি-পেস্ট করতে পারেন।
 ৪. বিশেষ কী-গুলোতে Option ঠিক করুন (পর্ব ৩-এর চিটশিট দেখুন)।
 ৫. সংযোগের জন্য Joining rules যোগ করুন (পর্ব ৪)।
 ৬. 'Try your layout'-এ সবকিছু পরীক্ষা করুন।
 ৭. Save চাপুন (অথবা Ctrl+S)।


=============================================================
পর্ব ৭  -  ANSI লেআউট বানানো, ধাপে ধাপে
=============================================================

ANSI কী? ANSI লেআউটে কী-গুলো আসল বাংলা অক্ষর লেখে না। সেগুলো সাধারণ ইংরেজির মতো দেখতে অক্ষর লেখে, আর SutonnyMJ-এর মতো পুরনো বাংলা ফন্ট সেগুলোকে বাংলা করে আঁকে।
   উদাহরণ: SutonnyMJ ফন্টে  k  অক্ষরটি ক হিসেবে আর  v  অক্ষরটি া হিসেবে দেখায়। সাধারণ ফন্টে একই লেখা অর্থহীন ইংরেজি মনে হয়। ANSI-তে এটাই স্বাভাবিক।
XML ফাইলটি তবুও UTF-8 হিসেবেই সেভ হয়। শুধু আপনার বেছে নেওয়া অক্ষরগুলো Windows-1252 (ANSI) সেটের ভেতরে থাকতে হবে।
ব্যবহার করা যাবে: ইংরেজি অক্ষর, সংখ্যা ও যতিচিহ্ন; Latin-1 অক্ষর ও চিহ্ন (উচ্চারণচিহ্নওয়ালা অক্ষর, পাউন্ড ও কপিরাইট চিহ্ন); এবং Windows-1252-এর বাড়তি চিহ্ন (বাঁকা উদ্ধৃতিচিহ্ন, ড্যাশ, তিন বিন্দু, ট্রেডমার্ক চিহ্ন, f-হুক)। ANSI লেআউটে আসল বাংলা অক্ষর দেবেন না।


ধাপে ধাপে:
 ১. সহজ শুরু: Open চেপে 'Bijoy Classic.xml' খুলুন (এটি একটি ANSI লেআউট)। তারপর 'Save As' চেপে আপনার কপিকে একটি নতুন নাম দিন। অথবা New চেপে Icon-এ 'Classic' বেছে নিন।
 ২. নাম অবশ্যই আলাদা হতে হবে। বাংলা কীবোর্ড লেআউট চেনে নাম দিয়ে।
 ৩. একটি কী-তে ক্লিক করুন। Normal ও Shift ঘরে ANSI অক্ষর লিখুন।
    বিশেষ ANSI অক্ষর কীভাবে টাইপ করবেন:
      - Alt চেপে ধরে নাম্বার প্যাডে তার কোড টাইপ করুন, যেমন Alt + 0198
      - অথবা Character Map প্রোগ্রাম থেকে কপি করুন (ফন্ট হিসেবে SutonnyMJ বেছে নিন)
      - অথবা কোনো তৈরি ANSI লেআউট থেকে কপি করুন
 ৪. প্রতিটি Option ঘর ফাঁকা রাখুন। পুরনো ফন্টে প্রতিটি চিহ্ন আপনি যে ক্রমে দেখেন সেই ক্রমেই জমা হয়, তাই ই-কার ও এ-কার আগে থেকেই অক্ষরের আগে টাইপ করা থাকে। Delay, DeInc1, DeInc2 আর MoveL শুধু ইউনিকোডের জন্য।
 ৫. যুক্তাক্ষর: ANSI ফন্টে একটি যুক্তাক্ষর মানে একটিমাত্র বিশেষ অক্ষর। Joining rules ট্যাব ব্যবহার করুন। 'Typed sequence' = কী-গুলো পরপর যা লেখে। 'Becomes' = একটিমাত্র ANSI গ্লিফ।
    Bijoy Classic থেকে উদাহরণ:  &v  হয়ে যায়  Av   (হসন্ত + আ-কার হয়ে যায় অক্ষর আ)
 ৬. 'Try your layout' খুলুন। Preview font-এ 'ANSI (SutonnyMJ)' বেছে নিন (লেআউটে বাংলা অক্ষর না থাকলে এটি নিজে থেকেই বাছা হয়)। Windows-এ SutonnyMJ ইনস্টল থাকতে হবে।
 ৭. Save চাপুন।

জেনে রাখুন: Keys ট্যাবের ঘরগুলোতে কাঁচা ANSI অক্ষরই দেখা যায়, কারণ সেগুলো ইউনিকোড ফন্টে আঁকা হয়। এটাই স্বাভাবিক।


=============================================================
পর্ব ৮  -  লেআউট সেভ ও ব্যবহার করা
=============================================================


   Save         যে ফাইল খুলেছেন তাতেই সেভ করে (প্রথমবার জায়গা জিজ্ঞেস করে)
   Save As...   নতুন নামে একটি কপি সেভ করে
   Ctrl+S       Save-এর মতোই
   Layouts folder...   এই প্রোগ্রাম কোন ফোল্ডার ব্যবহার করবে তা ঠিক করে। চাইলে সরাসরি বাংলা কীবোর্ডের Layouts ফোল্ডার দেখিয়ে দিতে পারেন।
   Show folder  ওই ফোল্ডারটি Windows-এ খোলে
লেআউট ব্যবহার করতে: সেভ করা ফাইলটি বাংলা কীবোর্ডের Layouts ফোল্ডারে কপি করুন, তারপর বাংলা কীবোর্ড আবার চালু করুন।
Save As ফাইলটি .xml হিসেবে সেভ করে। Open এবং ড্র্যাগ-অ্যান্ড-ড্রপ .xml ফাইল খুলতে পারে।


=============================================================
পর্ব ৯  -  সাধারণ সমস্যা ও দ্রুত সমাধান
=============================================================
সমস্যা: চিহ্ন আগে টাইপ করেছি কিন্তু সেটি অক্ষরের সামনেই থেকে গেছে (কে-এর বদলে েক)।
    সমাধান: চিহ্নের কী-তে Delay অপশন দেওয়া হয়নি। Option = Delay দিন (পর্ব ৩)।

সমস্যা: চিহ্ন যুক্তাক্ষরের মাঝখানে বসে যাচ্ছে (ক্রে-এর বদলে কে্র)।
    সমাধান: হসন্ত বা ফলা কী-তে DeInc1 অথবা DeInc2 দিতে হবে।

সমস্যা: রেফ অক্ষরের আগে না বসে পরে বসছে।
    সমাধান: রেফ কী-তে MoveL অপশন দিতে হবে।

সমস্যা: ফলাফলের ঘরে অদ্ভুত ইংরেজি অক্ষর দেখাচ্ছে।
    সমাধান: এটি ANSI লেআউট। Preview font-এ 'ANSI (SutonnyMJ)' বেছে নিন এবং ফন্টটি ইনস্টল আছে কিনা দেখুন।

সমস্যা: ঘরে লেখার পরও কী ধূসর থেকে গেছে।
    সমাধান: ধূসর মানে 'ইংরেজি কী-এর মতোই'। আপনি যদি একই ইংরেজি অক্ষর লিখে থাকেন তাহলে আসলে কিছুই বদলায়নি।

সমস্যা: আমার লেআউট বাংলা কীবোর্ডে দেখা যাচ্ছে না।
    সমাধান: তিনটি জিনিস দেখুন: (১) .xml ফাইলটি বাংলা কীবোর্ডের Layouts ফোল্ডারের ভেতরে আছে কিনা, (২) বাংলা কীবোর্ড আবার চালু করেছেন কিনা, (৩) লেআউটের Name অন্য সব লেআউট থেকে আলাদা কিনা।

সমস্যা: প্রোগ্রাম বলছে শর্টকাট চলবে না।
    সমাধান: শর্টকাটে Ctrl বা Alt থাকতে হবে (অথবা শুধু একটি F-কী, যেমন F8)।

সমস্যা: গোলমাল করে ফেলেছি, একটি কী আগের মতো করতে চাই।
    সমাধান: কী-টি সিলেক্ট করে 'Reset this key' চাপুন। সেভ না করে থাকলে Open চেপে ফাইলটি আবার খুলে নিলেও হবে।

=============================================================
পর্ব ১০  -  অতিরিক্ত সুবিধা
=============================================================
লেআউটের ধরন দেখানোর চিহ্ন  (উইন্ডোর ওপরে ডানে)
   একটি রঙিন লেখা দেখায় আপনি কোন ধরনের লেআউট বানাচ্ছেন:
      সবুজ   = Unicode (আসল বাংলা অক্ষর)
      কমলা   = ANSI (SutonnyMJ-এর মতো পুরনো ফন্ট)
      নীল    = অন্য ভাষা (Other language)
   পাশের 'Type' ঘরে চারটি বিকল্প আছে: Auto-detect, Unicode, ANSI (legacy font), Other language।
   Auto-detect দেখে আপনার কী-গুলো কী লিখছে: বাংলা অক্ষর হলে Unicode; সাধারণ ইংরেজির মতো দেখতে অক্ষর হলে ANSI; অন্য কোনো লিপির অক্ষর হলে Other language। ভুল ধরলে নিজে ধরনটি বেছে নিন।
   ধরনটি ঠিক করে 'Try your layout' ও 'Layout Viewer'-এর ফন্ট কী হবে, এবং সেভ করার সময় ANSI পরীক্ষা চালু হবে কিনা। আপনার বাছাই এই কম্পিউটারে ওই লেআউট ফাইলের জন্য মনে রাখা হয়। এটি .xml ফাইলের ভেতরে লেখা হয় না, তাই ফাইল ঠিক সেভাবেই থাকে যেভাবে বাংলা কীবোর্ড চায়।

সেভ করার আগে পরীক্ষা
   Save চাপলে প্রোগ্রাম সতর্ক করবে যদি:
    - একই ফোল্ডারে অন্য কোনো লেআউট ফাইলের Name একই হয় (বাংলা কীবোর্ড নাম দিয়ে লেআউট চেনে, তাই দুটির একটি ঠিকমতো কাজ করবে না)
    - ANSI লেআউটে এমন অক্ষর থাকে যা ANSI (Windows-1252) সেটে নেই, ফলে পুরনো ফন্ট সেটি দেখাতে পারবে না
   তবুও চাইলে 'Yes' চেপে সেভ করে ফেলতে পারেন।

আনডু ও রিডু
   ওপরের Undo ও Redo বোতাম, অথবা Ctrl+Z ও Ctrl+Y ব্যবহার করুন। কী, অপশন ও জয়েনিং রুলের বদলগুলোতে পিছনে বা সামনে যাওয়া যায় (সর্বোচ্চ ১০০ ধাপ)। লেআউট খুললে বা নতুন বানালে ইতিহাস নতুন করে শুরু হয়।
   কার্সর Name, Search বা Try ঘরে থাকলে Ctrl+Z ওই ঘরের টাইপিং আনডু করে।

Copy key ও Paste key
   একটি কী সিলেক্ট করে 'Copy key' চাপুন। অন্য একটি কী সিলেক্ট করে 'Paste key' চাপুন। Normal ও Shift দুটোরই অক্ষর ও অপশন কপি হয়। একই রকম কী দ্রুত বানাতে কাজে লাগে।

জয়েনিং রুলের সরঞ্জাম  (Joining rules ট্যাব)
   Import...   একটি টেক্সট ফাইল পড়ে, যেখানে প্রতি লাইনে একটি রুল: typed sequence, তারপর একটি TAB, তারপর যা হবে। # দিয়ে শুরু লাইন বাদ যায়। কোনো sequence আগে থেকে থাকলে সেটি আপডেট হয়।
   Export...   আপনার সব রুল একই সরল ফরম্যাটে সেভ করে। নোটপ্যাড বা এক্সেলে খুলতে পারেন, অন্যকে দিতে পারেন, বা ব্যাকআপ রাখতে পারেন।
   Add standard vowel rules   বিজয়-ধাঁচের সাধারণ ইউনিকোড রুলগুলো যোগ করে: হসন্ত + স্বরচিহ্ন হয়ে যায় পূর্ণ স্বর (যেমন  ্ + ি  হয়ে যায়  ই ), এ-কার + আ-কার হয়ে যায় ও-কার  ো , ইত্যাদি। আগে থেকে থাকা রুল আপডেট হয়, কিছু দুবার যোগ হয় না। ফলাফল পছন্দ না হলে Undo করুন।
   মনে রাখবেন: ইউনিকোড লেআউটে সাধারণ যুক্তাক্ষরের জন্য রুল লাগে না। অক্ষর + হসন্ত + অক্ষর টাইপ করলেই যুক্তাক্ষর হয়ে যায়।

LAYOUT VIEWER ট্যাব
   আপনার পুরো লেআউট কীবোর্ডের ছবির মতো দেখায়। প্রতিটি কী-তে ওপরে Shift ও নিচে Normal অক্ষর থাকে। সবুজ = বদলানো, কমলা = বিশেষ Option আছে। ANSI লেআউটে কী-গুলো SutonnyMJ ফন্টে আঁকা হয়, ফন্ট ইনস্টল থাকলে আসল বাংলা দেখতে পাবেন।
   'Print...' চাপলে চার্টটি ব্রাউজারে খোলে, ছাপার জন্য তৈরি। 'Save as web page...' চার্টটিকে .html ফাইল হিসেবে রাখে, যা অন্যকে দেওয়া যায়। চার্টে জয়েনিং রুলগুলোর তালিকাও থাকে।

ড্র্যাগ অ্যান্ড ড্রপ
   Windows Explorer থেকে একটি লেআউট .xml ফাইল টেনে এনে উইন্ডোর ওপর ছেড়ে দিলে সেটি খুলে যাবে। সেভ না করা বদল থাকলে আগে সেটি নিয়ে জিজ্ঞেস করা হবে।
)"
    return t
}

; ---- the window ---------------------------------------------------------------------------------
; The window is resizable. Every control is placed by Relayout() from the current window size,
; so keys, buttons, tabs and boxes always fit the width. (Pixel sizes below are real pixels;
; Px() scales them for the screen DPI.)

Px(n) {
    return Round(n * LB.sc)
}

; the keyboard drawn on the Keys tab and on the Layout Viewer tab: [key or label, width in key units]
KbRows() {
    r := []
    row := []
    for vk in [192, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 189, 187]
        row.Push([vk, 1])
    row.Push([Chr(0x2190) . " Bksp", 2])
    r.Push(row)
    row := [["Tab", 1.5]]
    for vk in [81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 219, 221]
        row.Push([vk, 1])
    row.Push([220, 1.5])
    r.Push(row)
    row := [["Caps", 1.75]]
    for vk in [65, 83, 68, 70, 71, 72, 74, 75, 76, 186, 222]
        row.Push([vk, 1])
    row.Push(["Enter", 2.25])
    r.Push(row)
    row := [["Shift", 2.25]]
    for vk in [90, 88, 67, 86, 66, 78, 77, 188, 190, 191]
        row.Push([vk, 1])
    row.Push(["Shift", 2.75])
    r.Push(row)
    return r
}

; create the key controls (positions and font sizes are set later by PlaceKb).
; A letter key is four boxes with the same colour: the back (border), the English key on the
; left, the Shift value on the top right and the Normal value on the bottom right.
MakeKb(g, viewer) {
    items := []
    items.DefineProp("fs", {value: ""})            ; the font sizes in use (so fonts change only when needed)
    for ri, row in KbRows() {
        u := 0
        for it in row {
            id := it[1]
            if IsInteger(id) {
                col := viewer ? ViewColor(id) : "EDEDED"
                nt := viewer ? "" : " +0x100"      ; the Keys tab boxes can be clicked
                b := g.Add("Text", "x0 y0 w10 h10 +Border +0x80" . nt . " Background" . col, "")
                e := g.Add("Text", "x0 y0 w10 h10 +0x80 +0x200" . nt . " c000000 Background" . col, CapName(id))
                s := g.Add("Text", "x0 y0 w10 h10 +0x80 +0x200 +Right" . nt . " c000000 Background" . col, "")
                n := g.Add("Text", "x0 y0 w10 h10 +0x80 +0x200 +Right" . nt . " c000000 Background" . col, "")
                p := {b: b, e: e, s: s, n: n}
                if viewer {
                    LB.vcaps[id] := b
                    LB.vp[id] := p
                } else {
                    LB.caps[id] := b
                    LB.kp[id] := p
                    for ctl in [b, e, s, n]
                        ctl.OnEvent("Click", SelectKey.Bind(id))
                }
                items.Push({c: b, p: p, r: ri, u: u, w: it[2], lab: false})
            } else {
                c := g.Add("Text", "x0 y0 w10 h10 +Border +0x200 +0x80 +Disabled Center BackgroundDCDCDC", id)
                items.Push({c: c, p: "", r: ri, u: u, w: it[2], lab: true})
            }
            u += it[2]
        }
    }
    return items
}

; stretch the four key rows over the width; keys keep a natural (nearly square) shape.
; The text on the keys grows and shrinks with the key size, so it never spills out.
; returns the height that the keyboard really uses
PlaceKb(items, ax, ay, aw, maxH, stretch := false) {
    kg := Px(4)
    uw := (aw + kg) / 15
    rh := stretch ? (maxH + kg) / 4 : Min(uw * 0.92, (maxH + kg) / 4)
    kh := rh - kg                                    ; key height in pixels
    pxPt := 1.3333 * LB.sc                           ; pixels per point at this screen DPI
    ; automatic size: fits its half of the key (legacy fonts have a tighter line, so they get more room);
    ; then the person's A- / A+ percentage is applied on top, with no further limit
    boost := FaceBoost()
    ptMax := Max(6, Floor(((kh - 2 * Px(3)) / 2) / (pxPt * ((boost > 1) ? 1.0 : 1.15))))
    ptBase := Min(Round(kh * 0.27 / pxPt * boost), ptMax)
    ptV := Max(5, Round(ptBase * LB.kScale / 100))  ; assigned (Bangla) values
    ptE := Max(7, Min(26, Round(kh * 0.36 / pxPt)))  ; English key
    ptL := Max(6, Min(14, Round(kh * 0.30 / pxPt)))  ; Tab, Shift ... labels
    face := PreviewFace()
    fk := ptV . "|" . ptE . "|" . ptL . "|" . face
    redo := (items.fs != fk)
    if redo
        items.fs := fk
    insX := Px(6)
    insY := Px(3)
    for it in items {
        x1 := ax + Round(it.u * uw)
        x2 := ax + Round((it.u + it.w) * uw)
        y1 := ay + Round((it.r - 1) * rh)
        y2 := ay + Round(it.r * rh)
        kw := x2 - x1 - kg
        kh2 := y2 - y1 - kg
        it.c.Move(x1, y1, kw, kh2)
        if it.lab {
            if redo
                it.c.SetFont("s" . ptL . " norm", "Segoe UI")
            continue
        }
        p := it.p
        ix := x1 + insX
        iy := y1 + insY
        iw := Max(4, kw - 2 * insX)
        ih := Max(4, kh2 - 2 * insY)
        ew := Round(iw * 0.36)
        hh := ih // 2
        p.e.Move(ix, iy, ew, ih)
        p.s.Move(ix + ew, iy, iw - ew, hh)
        p.n.Move(ix + ew, iy + hh, iw - ew, ih - hh)
        if redo {
            p.e.SetFont("s" . ptE . " norm", "Segoe UI")
            p.s.SetFont("s" . ptV . " norm", face)
            p.n.SetFont("s" . ptV . " norm", face)
        }
    }
    return Round(4 * rh) - kg
}

; blue frame around the key that is being edited
MoveSelFrame() {
    if !LB.ui.Has("selBars")
        return
    bars := LB.ui["selBars"]
    t := Px(3)
    old := ""
    if LB.ui.Has("selRect") {
        old := LB.ui["selRect"]
        LB.ui.Delete("selRect")
    }
    if (!LB.sel || !LB.caps.Has(LB.sel)) {
        for b in bars
            b.Move(-200, -200, 1, 1)
    } else {
        LB.caps[LB.sel].GetPos(&x, &y, &w, &h)
        bars[1].Move(x - t, y - t, w + 2 * t, t)
        bars[2].Move(x - t, y + h, w + 2 * t, t)
        bars[3].Move(x - t, y, t, h)
        bars[4].Move(x + w, y, t, h)
        LB.ui["selRect"] := [x - t, y - t, x + w + t, y + h + t]
    }
    ; repaint where the frame was, so it leaves no trail on the keys
    if IsObject(old) {
        rc := Buffer(16, 0)
        NumPut("int", old[1] - 1, "int", old[2] - 1, "int", old[3] + 1, "int", old[4] + 1, rc)
        DllCall("RedrawWindow", "ptr", LB.g.Hwnd, "ptr", rc, "ptr", 0, "uint", 0x185)
    }
}

; put a row of controls side by side over the width w.
; items: [control, fixed width, flexible share]; the free width is shared by the flexible shares.
Spread(items, x0, y, w, h, gap) {
    fixed := 0
    flex := 0
    for it in items {
        fixed += it[2]
        flex += it[3]
    }
    avail := Max(0, w - fixed - gap * (items.Length - 1))
    x := x0
    acc := 0
    prevEnd := 0
    for it in items {
        acc += it[3]
        endF := flex ? Round(avail * acc / flex) : 0
        cw := Max(2, it[2] + (endF - prevEnd))
        prevEnd := endF
        c := it[1]
        if (c.Type = "DDL" || c.Type = "ComboBox")
            c.Move(x, y + Max(0, (h - LB.ddH) // 2), cw)
        else
            c.Move(x, y, cw, h)
        x += cw + gap
    }
}

; make the tabs split the full width of the tab control equally (works for any width and any number of tabs)
FitTabs(tab) {
    n := SendMessage(0x1304, 0, 0, tab)                 ; TCM_GETITEMCOUNT
    if (n < 1)
        return
    tab.Opt("+0x400 -0x200")                            ; TCS_FIXEDWIDTH on, TCS_MULTILINE off (one row, never wraps)
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", tab.Hwnd, "Ptr", rc)
    tw := NumGet(rc, 8, "Int")
    if (tw < 50)
        return
    ir := Buffer(16, 0)
    SendMessage(0x130A, 0, ir, tab)                     ; TCM_GETITEMRECT: keep the current tab height
    th := NumGet(ir, 12, "Int") - NumGet(ir, 4, "Int")
    if (th < 10)
        th := Px(24)
    SendMessage(0x1329, 0, ((th & 0xFFFF) << 16) | (((tw - 4) // n) & 0xFFFF), tab)   ; TCM_SETITEMSIZE
}

; put a window in the middle of the work area of the screen the mouse is on
CenterWin(g) {
    WinGetPos(, , &w, &h, g.Hwnd)
    MouseGetPos(&mx, &my)
    mon := MonitorGetPrimary()
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        if (mx >= ml && mx < mr && my >= mt && my < mb)
            mon := A_Index
    }
    MonitorGetWorkArea(mon, &l, &t, &r, &b)
    g.Move(l + (r - l - w) // 2, t + (b - t - h) // 2)
}

OnSize(g, minMax, w, h) {
    if (minMax = -1)
        return
    LB.maxed := (minMax = 1)
    Relayout()
}

Relayout() {
    if !LB.ready
        return
    g := LB.g
    g.GetClientPos(, , &W, &H)
    if (W < 100 || H < 100)
        return
    ui := LB.ui
    M := Px(6)
    GAP := Px(4)
    P := Px(4)
    IW := W - 2 * M
    ; The window height follows its content: the keys keep a natural shape, so the height only
    ; depends on the width. (When maximized, the keys stretch to fill the height instead.)
    pd0 := LB.pad
    pgWn := IW - pd0[1] - pd0[3] - 2 * P
    usedN := Round(4 * ((pgWn + Px(4)) / 15) * 0.92) - Px(4)
    needH := (M + Px(26) + GAP + Px(24) + GAP + Px(24) + GAP) + usedN + 2 * GAP + Px(124) + 2 * P + pd0[2] + pd0[4] + M
    if (!LB.maxed && !LB.fixing && Abs(H - needH) > 1) {
        LB.fixing := true
        try g.Show((LB.starting ? "Hide " : "NA ") . "w" . W . " h" . needH)
        Relayout()
        LB.fixing := false
        return
    }
    SendMessage(0x000B, 0, 0, g.Hwnd)                  ; stop repainting while moving
    try {
        ; ----- header -----
        yA := M
        yB := yA + Px(26) + GAP
        yC := yB + Px(24) + GAP
        ty := yC + Px(24) + GAP
        Spread(ui["top"], M, yA, IW, Px(26), GAP)
        Spread(ui["rowC"], M, yB, IW, Px(24), GAP)
        Spread(ui["rowB"], M, yC, IW, Px(24), GAP)

        ; ----- tab control and its page area -----
        tabH := H - ty - M
        LB.tab.Move(M, ty, IW, tabH)
        FitTabs(LB.tab)                                ; the tabs always share the full width
        pd := LB.pad
        pgX := M + pd[1] + P
        pgY := ty + pd[2] + P
        pgW := Max(Px(300), IW - pd[1] - pd[3] - 2 * P)
        pgH := Max(Px(240), tabH - pd[2] - pd[4] - 2 * P)

        ; ----- Keys -----
        edH := Px(124)
        KH := PlaceKb(LB.kb, pgX, pgY, pgW, pgH - edH - GAP, LB.maxed) + GAP
        e0 := pgY + KH + GAP
        lw := Round(pgW * 0.54)
        ui["lblSel"].Move(pgX, e0, lw, Px(22))
        Spread(ui["rowN"], pgX, e0 + Px(26), lw, Px(28), GAP)
        Spread(ui["rowS"], pgX, e0 + Px(58), lw, Px(28), GAP)
        rx := pgX + lw + Px(14)
        rw := pgW - lw - Px(14)
        ui["lblIns"].Move(rx, e0 + Px(2), rw, Px(22))
        Spread(ui["btnA"], rx, e0 + Px(26), rw, Px(28), GAP)
        Spread(ui["btnB"], rx, e0 + Px(58), rw, Px(28), GAP)
        LB.lblOpt.Move(pgX, e0 + Px(90), pgW, Max(Px(20), pgY + pgH - (e0 + Px(90))))

        ; ----- Joining rules -----
        Spread(ui["jFind"], pgX, pgY, pgW, Px(24), GAP)
        bottomH := Px(80)
        ry := pgY + pgH - bottomH
        lvY := pgY + Px(28)
        LB.lv.Move(pgX, lvY, pgW, Max(Px(60), ry - GAP - lvY))
        LB.lv.ModifyCol(1, Round(pgW * 0.47))
        LB.lv.ModifyCol(2, Round(pgW * 0.47))
        half := (pgW - GAP) // 2
        ui["lblSeq"].Move(pgX, ry, half, Px(20))
        ui["lblOut"].Move(pgX + half + GAP, ry, pgW - half - GAP, Px(20))
        LB.edSeq.Move(pgX, ry + Px(20), half, Px(28))
        LB.edOut.Move(pgX + half + GAP, ry + Px(20), pgW - half - GAP, Px(28))
        Spread(ui["jBtn"], pgX, ry + Px(52), pgW, Px(28), GAP)

        ; ----- Try your layout -----
        ui["lblTry"].Move(pgX, pgY, pgW, Px(20))
        spl := Px(8)
        avail := Max(Px(110), pgH - Px(84) - spl)
        inH := Min(Max(Round(avail * LB.tryFrac), Px(36)), avail - Px(50))
        LB.tryTop := pgY + Px(20)
        LB.tryAvail := avail
        LB.edIn.Move(pgX, pgY + Px(20), pgW, inH)
        sy := pgY + Px(20) + inH
        ui["splitTry"].Move(pgX, sy, pgW, spl)
        r2 := sy + spl
        Spread(ui["tryRow"], pgX, r2, pgW, Px(24), GAP)
        resY := r2 + Px(26)
        LB.edRes.Move(pgX, resY, pgW, Max(Px(40), pgY + pgH - Px(38) - resY))
        ui["lblTryNote"].Move(pgX, pgY + pgH - Px(34), pgW, Px(34))

        ; ----- Layout Viewer -----
        LB.lblV1.Move(pgX, pgY, pgW, Px(22))
        seg := pgW // 4
        for i, lg in ui["legend"] {
            lx := pgX + (i - 1) * seg
            if IsObject(lg[1])
                lg[1].Move(lx, pgY + Px(32), Px(14), Px(14))
            lg[2].Move(lx + (IsObject(lg[1]) ? Px(20) : 0), pgY + Px(30), seg - Px(24), Px(18))
        }
        vkY := pgY + Px(54)
        vkH := PlaceKb(LB.vkb, pgX, vkY, pgW, Max(Px(120), pgH - Px(54) - Px(70)), LB.maxed)
        by := vkY + vkH + GAP
        mx := Px(8)
        my := Px(3)
        ix0 := Max(0, pgX - mx)
        iy0 := Max(0, vkY - my)
        ui["vRect"] := [ix0, iy0, Min(W - ix0, pgW + 2 * mx), Min(H - iy0, vkH + 2 * my)]
        Spread([[ui["btnPrint"], 0, 1], [ui["btnHtml"], 0, 1], [ui["btnImg"], 0, 1]], pgX, by, pgW, Px(28), GAP)   ; three equal buttons across the full width
        ui["lblVNote"].Move(pgX, by + Px(32), pgW, Max(Px(20), pgY + pgH - (by + Px(32))))

        ; ----- Guides -----
        MoveSelFrame()
        ui["guideEn"].Move(pgX, pgY, pgW, pgH)
        ui["guideBn"].Move(pgX, pgY, pgW, pgH)
    } finally {
        SendMessage(0x000B, 1, 0, g.Hwnd)
        DllCall("RedrawWindow", "ptr", g.Hwnd, "ptr", 0, "ptr", 0, "uint", 0x185)
    }
}

; ---------------------------------------------------------------------------
;  Hover hints: rest the mouse on a button, box or key and a short tooltip says what it does.
; ---------------------------------------------------------------------------
Hint(ctl, text) {
    if IsObject(ctl)
        Hints[ctl.Hwnd] := text
}

HintPoll() {
    static last := 0, since := 0, shown := false
    txt := ""
    MouseGetPos(, , &win, &ctl, 2)
    if (IsObject(LB.g) && win = LB.g.Hwnd) {
        h := IsInteger(ctl) ? ctl : 0                     ; empty when the mouse is not over a control
        Loop 3 {
            if (!h || h = win)
                break
            if Hints.Has(h) {
                txt := Hints[h]
                break
            }
            h := DllCall("GetParent", "Ptr", h, "Ptr") || 0
        }
        if (h != last) {
            last := h
            since := A_TickCount
            if shown {
                ToolTip(, , , 19)
                shown := false
            }
        }
    } else
        last := 0
    if (txt = "") {
        if shown {
            ToolTip(, , , 19)
            shown := false
        }
        return
    }
    if (!shown && A_TickCount - since >= 600) {
        ToolTip(txt, , , 19)
        shown := true
    }
}

BuildGui() {
    g := Gui("+Resize -DPIScale", "Bangla Layout Builder")
    LB.g := g
    LB.sc := A_ScreenDPI / 96
    ui := LB.ui
    g.Opt("+E0x10")                                   ; accept dropped files
    g.OnEvent("DropFiles", OnDropFiles)
    g.SetFont("s9", "Segoe UI")
    g.OnEvent("Size", OnSize)
    OnMessage(0x201, SplitDown)                       ; drag the divider
    OnMessage(0x20, SplitCursor)                      ; up-down cursor over the divider
    g.Opt("+MinSize" . Px(740) . "x" . Px(300))

    ; ---------- top bar ----------
    top := []
    items := [["New", 64, NewLayout], ["Open...", 84, OpenLayout], ["Save", 64, SaveClick], ["Save As...", 84, SaveAsClick], ["Layouts folder...", 130, PickFolder], ["Show folder", 100, ShowFolder]]
    for b in items {
        c := g.Add("Button", "x0 y0 w10 h10", b[1])
        c.OnEvent("Click", b[3])
        top.Push([c, 0, b[2]])
    }
    LB.btnUndo := g.Add("Button", "x0 y0 w10 h10", "Undo")
    LB.btnUndo.OnEvent("Click", DoUndo)
    top.Push([LB.btnUndo, 0, 52])
    LB.btnRedo := g.Add("Button", "x0 y0 w10 h10", "Redo")
    LB.btnRedo.OnEvent("Click", DoRedo)
    top.Push([LB.btnRedo, 0, 52])
    ui["top"] := top

    ; ---------- file path + type ----------
    LB.lblFile := g.Add("Text", "x0 y0 w10 h10 +0x200 +0x8000 +0x80 c555555", "")
    LB.ddType := g.Add("DropDownList", "x0 y0 w10 Choose1", ["Auto-detect", "Unicode", "ANSI (legacy font)", "Other language"])
    LB.ddType.OnEvent("Change", TypeChanged)
    LB.lblType := g.Add("Text", "x0 y0 w10 h10 +0x200 +0x80", "")
    LB.lblType.Opt("+Right")
    ui["lblKT"] := g.Add("Text", "x0 y0 w10 h10 +0x200 +0x80 Right", "Key text: " . LB.kScale . "%")
    bKm := g.Add("Button", "x0 y0 w10 h10", "A-")
    bKm.OnEvent("Click", KeyTextSmaller)
    bKp := g.Add("Button", "x0 y0 w10 h10", "A+")
    bKp.OnEvent("Click", KeyTextBigger)
    bKr := g.Add("Button", "x0 y0 w10 h10", "Reset")
    bKr.OnEvent("Click", KeyTextReset)
    ui["rowB"] := [[LB.lblFile, 0, 5], [LB.lblType, 0, 3], [ui["lblKT"], Px(96), 0], [bKm, Px(30), 0], [bKp, Px(30), 0], [bKr, Px(50), 0], [LB.ddType, Px(150), 0]]
    LB.ddH := 0
    LB.ddType.GetPos(, , , &hh)
    LB.ddH := hh

    ; ---------- name / icon / shortcut ----------
    stName := g.Add("Text", "x0 y0 w10 h10 +0x200", "Name:")
    LB.edName := g.Add("Edit", "x0 y0 w10 h10")
    LB.edName.OnEvent("Change", HeaderChanged)
    stIcon := g.Add("Text", "x0 y0 w10 h10 +0x200", "Icon:")
    LB.cbIcon := g.Add("ComboBox", "x0 y0 w10 r8", IconNames())
    LB.cbIcon.OnEvent("Change", HeaderChanged)
    stSc := g.Add("Text", "x0 y0 w10 h10 +0x200", "Shortcut:")
    LB.hkSc := g.Add("Hotkey", "x0 y0 w10 h10")
    LB.hkSc.OnEvent("Change", HeaderChanged)
    btnClear := g.Add("Button", "x0 y0 w10 h10", "Clear")
    btnClear.OnEvent("Click", ClearShortcut)
    ui["rowC"] := [[stName, Px(40), 0], [LB.edName, 0, 5], [stIcon, Px(38), 0], [LB.cbIcon, 0, 3], [stSc, Px(62), 0], [LB.hkSc, 0, 4], [btnClear, Px(60), 0]]

    ; ---------- tab control ----------
    tab := g.Add("Tab3", "x0 y0 w800 h400", ["Keys", "Joining rules", "Try your layout", "Layout Viewer", "Guide En", "Guide Bn"])
    LB.tab := tab
    tab.OnEvent("Change", TabChanged)
    FitTabs(tab)
    rc := Buffer(16, 0)
    NumPut("int", 800, rc, 8)
    NumPut("int", 400, rc, 12)
    SendMessage(0x1328, 0, rc, tab)                    ; TCM_ADJUSTRECT: window rect -> page rect
    LB.pad := [NumGet(rc, 0, "int"), NumGet(rc, 4, "int"), 800 - NumGet(rc, 8, "int"), 400 - NumGet(rc, 12, "int")]

    ; ---------- Keys ----------
    tab.UseTab(1)
    LB.kb := MakeKb(g, false)
    bars := []
    Loop 4
        bars.Push(g.Add("Progress", "x-200 y-200 w1 h1 -Smooth -Theme c1565C0 Background1565C0", 100))
    ui["selBars"] := bars
    LB.lblSel := g.Add("Text", "x0 y0 w10 h10 +0x200", "Selected key:")
    ui["lblSel"] := LB.lblSel
    LB.lblSel.SetFont("s10 bold")
    stN := g.Add("Text", "x0 y0 w10 h10 +0x200", "Normal:")
    LB.edN := g.Add("Edit", "x0 y0 w10 h10")
    LB.edN.SetFont("s12", "Nirmala UI")
    LB.edN.OnEvent("Change", EdNChange)
    LB.edN.OnEvent("Focus", FocusN)
    stNo := g.Add("Text", "x0 y0 w10 h10 +0x200", "Option:")
    LB.ddN := g.Add("DropDownList", "x0 y0 w10 Choose1", OptLabels())
    LB.ddN.OnEvent("Change", DdNChange)
    ui["rowN"] := [[stN, Px(52), 0], [LB.edN, 0, 3], [stNo, Px(50), 0], [LB.ddN, 0, 2]]

    stS := g.Add("Text", "x0 y0 w10 h10 +0x200", "Shift:")
    LB.edS := g.Add("Edit", "x0 y0 w10 h10")
    LB.edS.SetFont("s12", "Nirmala UI")
    LB.edS.OnEvent("Change", EdSChange)
    LB.edS.OnEvent("Focus", FocusS)
    stSo := g.Add("Text", "x0 y0 w10 h10 +0x200", "Option:")
    LB.ddS := g.Add("DropDownList", "x0 y0 w10 Choose1", OptLabels())
    LB.ddS.OnEvent("Change", DdSChange)
    ui["rowS"] := [[stS, Px(52), 0], [LB.edS, 0, 3], [stSo, Px(50), 0], [LB.ddS, 0, 2]]

    ui["lblIns"] := g.Add("Text", "x0 y0 w10 h10 c555555", "Insert at the cursor of the last box you used:")
    b1 := g.Add("Button", "x0 y0 w10 h10", "Hasanta " . Chr(0x09CD))
    b1.OnEvent("Click", InsertText.Bind(Chr(0x09CD)))
    b2 := g.Add("Button", "x0 y0 w10 h10", "ZWNJ")
    b2.OnEvent("Click", InsertText.Bind(Chr(0x200C)))
    b3 := g.Add("Button", "x0 y0 w10 h10", "ZWJ")
    b3.OnEvent("Click", InsertText.Bind(Chr(0x200D)))
    ui["btnA"] := [[b1, 0, 1], [b2, 0, 1], [b3, 0, 1]]
    b4 := g.Add("Button", "x0 y0 w10 h10", "Reset this key")
    b4.OnEvent("Click", ResetKey)
    b5 := g.Add("Button", "x0 y0 w10 h10", "Copy key")
    b5.OnEvent("Click", CopyKey)
    b6 := g.Add("Button", "x0 y0 w10 h10", "Paste key")
    b6.OnEvent("Click", PasteKey)
    ui["btnB"] := [[b4, 0, 1], [b5, 0, 1], [b6, 0, 1]]
    LB.lblOpt := g.Add("Text", "x0 y0 w10 h10 c444444", "")

    ; ---------- Joining rules ----------
    tab.UseTab(2)
    stFind := g.Add("Text", "x0 y0 w10 h10 +0x200", "Search:")
    LB.edFind := g.Add("Edit", "x0 y0 w10 h10")
    LB.edFind.OnEvent("Change", FindChanged)
    LB.lblCount := g.Add("Text", "x0 y0 w10 h10 +0x200 c555555", "")
    ui["jFind"] := [[stFind, Px(54), 0], [LB.edFind, 0, 2], [LB.lblCount, 0, 3]]
    LB.lv := g.Add("ListView", "x0 y0 w100 h100 -Multi", ["Typed sequence", "Becomes"])
    LB.lv.SetFont("s10", "Nirmala UI")
    LB.lv.OnEvent("ItemSelect", JukPick)
    ui["lblSeq"] := g.Add("Text", "x0 y0 w10 h10", "Typed sequence (what the keys produce, in order):")
    LB.edSeq := g.Add("Edit", "x0 y0 w10 h10")
    LB.edSeq.SetFont("s12", "Nirmala UI")
    ui["lblOut"] := g.Add("Text", "x0 y0 w10 h10", "Becomes:")
    LB.edOut := g.Add("Edit", "x0 y0 w10 h10")
    LB.edOut.SetFont("s12", "Nirmala UI")
    j1 := g.Add("Button", "x0 y0 w10 h10", "Add / Update")
    j1.OnEvent("Click", JukAdd)
    j2 := g.Add("Button", "x0 y0 w10 h10", "Delete selected")
    j2.OnEvent("Click", JukDelete)
    j3 := g.Add("Button", "x0 y0 w10 h10", "Import...")
    j3.OnEvent("Click", ImportRules)
    j4 := g.Add("Button", "x0 y0 w10 h10", "Export...")
    j4.OnEvent("Click", ExportRules)
    j5 := g.Add("Button", "x0 y0 w10 h10", "Add standard vowel rules")
    j5.OnEvent("Click", AddStdRules)
    j6 := g.Add("Button", "x0 y0 w10 h10", "Delete all")
    j6.OnEvent("Click", JukDeleteAll)
    ui["jBtn"] := [[j1, 0, 105], [j2, 0, 115], [j6, 0, 85], [j3, 0, 90], [j4, 0, 90], [j5, 0, 185]]

    ; ---------- Try it ----------
    tab.UseTab(3)
    ui["lblTry"] := g.Add("Text", "x0 y0 w10 h10", "Type English letters here, as you would on the keyboard (for example the letters of a word):")
    LB.edIn := g.Add("Edit", "x0 y0 w10 h10 +Multi +VScroll")
    LB.edIn.SetFont("s11", "Consolas")
    LB.edIn.OnEvent("Change", TryTyping)
    ui["splitTry"] := g.Add("Text", "x0 y0 w10 h8 +0x10 +0x100")      ; drag to resize the two boxes
    lblWhat := g.Add("Text", "x0 y0 w10 h10 +0x200", "What this layout types:")
    stFont := g.Add("Text", "x0 y0 w10 h10 +0x200 Right", "Preview font:")
    LB.cbFont := g.Add("ComboBox", "x0 y0 w10 r14", InstalledFonts())
    LB.cbFont.OnEvent("Change", FontComboChanged)
    btnFontDef := g.Add("Button", "x0 y0 w10 h10", "Auto")
    btnFontDef.OnEvent("Click", DefaultFont)
    stSize := g.Add("Text", "x0 y0 w10 h10 +0x200 Right", "Size:")
    LB.ddSize := g.Add("DropDownList", "x0 y0 w10 Choose" . LB.pSize, ["Small", "Medium", "Large"])
    LB.ddSize.OnEvent("Change", SizeChanged)
    ui["tryRow"] := [[lblWhat, 0, 1], [stFont, Px(86), 0], [LB.cbFont, Px(190), 0], [btnFontDef, Px(50), 0], [stSize, Px(38), 0], [LB.ddSize, Px(84), 0]]
    LB.edRes := g.Add("Edit", "x0 y0 w10 h10 +Multi +ReadOnly +VScroll")
    LB.edRes.SetFont("s16", "Nirmala UI")
    ui["lblTryNote"] := g.Add("Text", "x0 y0 w10 h10 c555555", "This uses the same typing engine as Bangla Keyboard, with the layout as it is now (saved or not). Keys you have not changed stay English.")

    ; ---------- Layout Viewer ----------
    tab.UseTab(4)
    LB.lblV1 := g.Add("Text", "x0 y0 w10 h10 +0x200 +0x80", "")
    legend := []
    for it in [["EDEDED", "Plain English key"], ["CFEFD6", "Changed key"], ["FFE2A0", "Key with a special Option"]] {
        sq := g.Add("Text", "x0 y0 w14 h14 +Border Background" . it[1], "")
        tx := g.Add("Text", "x0 y0 w10 h18 +0x200 c444444", it[2])
        legend.Push([sq, tx])
    }
    legend.Push(["", g.Add("Text", "x0 y0 w10 h18 +0x200 c444444", "Top = Shift, bottom = Normal")])
    ui["legend"] := legend
    LB.vkb := MakeKb(g, true)
    ui["btnPrint"] := g.Add("Button", "x0 y0 w10 h10", "Print...")
    ui["btnPrint"].OnEvent("Click", PrintChart)
    ui["btnHtml"] := g.Add("Button", "x0 y0 w10 h10", "Save as web page...")
    ui["btnHtml"].OnEvent("Click", SaveChartHtml)
    ui["btnImg"] := g.Add("Button", "x0 y0 w10 h10", "Save as image...")
    ui["btnImg"].OnEvent("Click", SaveViewerImage)
    ui["lblVNote"] := g.Add("Text", "x0 y0 w10 h10 c555555", "Print opens the chart in your web browser, ready to print. Save as web page keeps the keyboard as an .html file you can share. Save as image saves the keyboard picture exactly as you see it here (.png).")

    ; ---------- Guide En / Guide Bn ----------
    tab.UseTab(5)
    ed := g.Add("Edit", "x0 y0 w10 h10 +Multi +ReadOnly +VScroll Limit400000")
    ed.SetFont("s10", "Nirmala UI")
    ed.Value := StrReplace(GuideTextEn(), "`n", "`r`n")
    ui["guideEn"] := ed
    tab.UseTab(6)
    ed2 := g.Add("Edit", "x0 y0 w10 h10 +Multi +ReadOnly +VScroll Limit400000")
    ed2.SetFont("s10", "Nirmala UI")
    ed2.Value := StrReplace(GuideTextBn(), "`n", "`r`n")
    ui["guideBn"] := ed2

    ; ---------- hover hints (always on): rest the mouse on anything to see what it does ----------
    tp := ["Start a new, empty layout.", "Open a saved layout file (.xml).", "Save the layout to its file. (Ctrl+S)"
        , "Save the layout under a new name or place.", "Choose the folder where your layouts are kept.", "Open the layouts folder in Windows Explorer."]
    for k, t in tp
        Hint(top[k][1], t)
    Hint(LB.btnUndo, "Undo the last change. (Ctrl+Z)")
    Hint(LB.btnRedo, "Redo the change you undid. (Ctrl+Y)")
    Hint(LB.ddType, "What kind of layout this is. Auto-detect is right for most layouts.")
    Hint(bKm, "Make the letters on the keys smaller.")
    Hint(bKp, "Make the letters on the keys bigger.")
    Hint(bKr, "Back to the normal key text size.")
    Hint(LB.edName, "The name of this layout, as shown in the keyboard's list.")
    Hint(LB.cbIcon, "The icon of this layout.`nPick a name, or type the name of a picture in the Icons folder.")
    Hint(LB.hkSc, "Key combination that switches the keyboard to this layout.")
    Hint(btnClear, "Remove the shortcut.")
    Hint(LB.tab, "Keys: set what each key types.`nJoining rules: letters that combine.`nTry your layout: test typing.`nLayout Viewer: print or save the chart.")
    for id, p in LB.kp {
        for c in [p.b, p.e, p.s, p.n]
            Hint(c, "Click a key to change what it types.")
    }
    Hint(LB.edN, "What this key types on its own (no Shift).")
    Hint(LB.ddN, "A special behaviour for this key when typed on its own.")
    Hint(LB.edS, "What this key types with Shift.")
    Hint(LB.ddS, "A special behaviour for this key when typed with Shift.")
    Hint(b1, "Insert a hasanta at the cursor of the last box you used.")
    Hint(b2, "Insert a ZWNJ at the cursor: it stops two letters from joining.")
    Hint(b3, "Insert a ZWJ at the cursor: it makes two letters join.")
    Hint(b4, "Put this key back to its plain English letter.")
    Hint(b5, "Copy this key's settings.")
    Hint(b6, "Paste the copied settings onto this key.")
    Hint(LB.edFind, "Type here to find a joining rule in the list.")
    Hint(LB.lv, "Your joining rules. Click one to edit it below.")
    Hint(LB.edSeq, "The letters as they are typed, in order.")
    Hint(LB.edOut, "What those letters turn into.")
    Hint(j1, "Save the rule above: adds it, or updates the selected one.")
    Hint(j2, "Delete the selected rule.")
    Hint(j3, "Load joining rules from a file.")
    Hint(j4, "Save the joining rules to a file.")
    Hint(j5, "Add the usual vowel-sign rules.")
    Hint(j6, "Delete every joining rule.")
    Hint(LB.edIn, "Type English letters here to test the layout as it is now.")
    Hint(ui["splitTry"], "Drag up or down to resize the two boxes.")
    Hint(LB.cbFont, "The font used to show the result. Pick one or type its name.")
    Hint(btnFontDef, "Use the automatic font.")
    Hint(LB.ddSize, "The size of the result text.")
    Hint(LB.edRes, "What your layout types for the letters on the left.")
    Hint(ui["btnPrint"], "Open the chart in your web browser, ready to print.")
    Hint(ui["btnHtml"], "Save the chart as a web page (.html) you can share.")
    Hint(ui["btnImg"], "Save the chart as a picture.")
    Hint(ed, "The guide in English. Scroll to read it.")
    Hint(ed2, "The guide in Bangla. Scroll to read it.")

    tab.UseTab()
    g.OnEvent("Close", AppClose)
    LB.ready := true
    LB.starting := true
    g.Show("Hide w" . Px(820) . " h" . Px(600))        ; not visible yet
    Relayout()                                         ; settle the final height first
    CenterWin(g)                                       ; then centre the finished size
    LB.starting := false
    g.Show()                                           ; appears once, already in the middle
}

; ---------------------------------------------------------------------------
;  Start
; ---------------------------------------------------------------------------
try {
    DirCreate(LB.dataDir)
    if !FileExist(LB.ini) {
        for prev in ["layout_builder_config.ini", "lyb_cfg.dat"] {          ; names used by earlier builds
            if FileExist(LB.dataDir . "\" . prev) {
                FileMove(LB.dataDir . "\" . prev, LB.ini)
                break
            }
        }
    }
    ; keep the settings of an earlier version: copy them once to the new place
    oldIni := A_AppData . "\BanglaLayoutBuilder\Settings.ini"
    if (FileExist(oldIni) && !FileExist(LB.ini))
        FileCopy(oldIni, LB.ini)
}
global Hints := Map()
SetTimer(HintPoll, 120)
LoadSettings()
ResetModel()
BuildGui()
ApplyModelToUI("My Layout", IconNames()[1], "")

#HotIf IsObject(LB.g) && WinActive("ahk_id " . LB.g.Hwnd)
^s::SaveLayout()
$^z::UndoKey()
$^y::RedoKey()
#HotIf

; Hands the memory the program does not need back to Windows (only idle pages; they return when used)
TrimMemory() {
    DllCall("psapi\EmptyWorkingSet", "Ptr", DllCall("kernel32\GetCurrentProcess", "Ptr"))
}
