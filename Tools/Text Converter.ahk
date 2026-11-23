; ===========================================================================
;  Bangla Text Converter  -  ANSI (Bijoy) <-> Unicode
;  Two boxes: type or paste in one, then press "To ANSI" / "To Unicode" to convert.
;  Undo / Redo (Ctrl+Z, Ctrl+Y or Ctrl+Shift+Z, and the right-click menu) works for each box separately and also
;  covers a conversion and "Clear both". "Clear both" is in the right-click menu of the boxes.
;  Needs AutoHotkey v2.
;  The rules come from the Library folder: the same encodings (.json, or the locked .menc) that the keyboard
;  uses for Multi Encoding. Unicode -> ANSI is exactly what the keyboard types; ANSI -> Unicode turns the same
;  rules around, so one file serves both ways and nothing has to be kept in two places.
;  Two kinds of encoding, chosen in Settings (Encodings in the toolbar list):
;    Script (Library\Encoding Script, .json / .menc): custom, rule based conversion (the keyboard's own rules)
;    Table  (Library\Encoding Table, .txt / .een): standard (universal) conversion, one "ansi<TAB>unicode" pair per line
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
ListLines(false)                  ; no line history: less memory and CPU
SetTimer(TrimMemory, -3000)         ; once, shortly after start: hand unused memory back to Windows
SetWorkingDir A_ScriptDir

class Cv {
    static fw := ""              ; ANSI text -> Unicode text
    static rv := ""              ; Unicode text -> ANSI text
    static fwMax := 1
    static rvMax := 1
    static rephAnsi := ""
    static ansi := ""
    static uni := ""
    static gui := ""
    static sg := ""
    static sb := ""
    static subCb := 0
    static b1 := ""
    static b2 := ""
    static b4 := ""
    static b5 := ""              ; "?" (About) button
    static dd := ""
    static h := Map()            ; undo / redo history of the two boxes (key: the box's HWND)
    static ini := A_AppData . "\Bangla Keyboard\Text Converter.dat"
    static fontA := "SutonnyMJ"
    static sizeA := 15
    static fontU := "Nirmala UI"
    static sizeU := 13
    static files := []           ; the encodings in the list: Maps with kind (lib / txt), path and name
    static src := "B"            ; which encodings the toolbar list shows: T = Encoding Table, S = Encoding Script, B = both
    static tip := ""             ; the tooltip window of the toolbar
    static tipKeep := []         ; text buffers of the tooltips (they must stay alive)
    static mode := "lib"         ; lib = a Library encoding (JSON), txt = an old mapping table
    static lib := ""             ; the Library encoding in use (Unicode -> ANSI)
    static rev := ""             ; the same encoding turned around (ANSI -> Unicode)
    static cur := 1              ; list position of the encoding in use
    static layout := "H"         ; H = stacked, V = side by side, T = tabs
    static tab := ""
    static ek := "BanglaConverter"    ; scramble key for .een files (see EenDecode)
    ; draggable divider between the two boxes
    static ratioH := 0.5         ; share of the space the top box gets (stacked view)
    static ratioV := 0.5         ; share of the space the left box gets (side by side view)
    static sx := 0               ; divider rectangle (client pixels); sw = 0 means "no divider"
    static sy := 0
    static sw := 0
    static sh := 0
    static sOrigin := 0          ; where the box area starts along the drag axis
    static sTotal := 1           ; box area size along the drag axis (without the divider)
    static sMin := 40            ; smallest allowed box size
    static sGrip := 6            ; divider thickness
    static dragging := false
    static theme := "L"          ; L = light (the default), S = follow Windows, D = dark
    static dark := false
    static bg := "F0F0F0"        ; window colours (RRGGBB), set by CvApplyTheme
    static fg := "000000"
    static ebg := "FFFFFF"       ; text box colours
    static efg := "000000"
    static tabSel := "FFFFFF"    ; tab header colours
    static tabIdle := "E1E1E1"
    static tabLine := "ACACAC"
    static tabNames := ["Unicode", "ANSI"]
    static sgTab := ""           ; tab strip of the Settings window
    static sgTabNames := ["General", "Encoding Fonts"]
    static encFont := Map()      ; ANSI preview font per encoding: key "Script|name" / "Table|name" -> [font, size]
    static encDirty := false     ; the per-encoding fonts changed and still have to be written
    static fd := ""              ; toolbar: ANSI font dropdown
    static sz := ""              ; toolbar: ANSI font size box
    static fonts := []
    static sizes := ["8", "10", "12", "14", "16", "18", "20", "24", "28", "32", "36", "40", "48", "60", "72"]
    static lastDown := 0
    static wheel := 0            ; unused part of a Ctrl + mouse wheel turn (120 = one notch)
    ; Bangla characters (written as codes so the script does not depend on file encoding)
    static HAS := Chr(0x09CD)                    ; hasanta  ্
    static ZWNJ := Chr(0x200C)
    static ZWJ := Chr(0x200D)
    static VI := Chr(0x09BF)                     ; ি
    static VE := Chr(0x09C7)                     ; ে
    static VAI := Chr(0x09C8)                    ; ৈ
    static AA := Chr(0x09BE)                     ; া
    static AU := Chr(0x09D7)                     ; ৗ
    static O := Chr(0x09CB)                      ; ো
    static AUU := Chr(0x09CC)                    ; ৌ
    static RA := Chr(0x09B0)                     ; র
    static REPH := Chr(0x09B0) . Chr(0x09CD)     ; র্
    static SIGNS := Chr(0x09BE) . Chr(0x09BF) . Chr(0x09C0) . Chr(0x09C1) . Chr(0x09C2) . Chr(0x09C3) . Chr(0x09C7) . Chr(0x09C8) . Chr(0x09D7) . Chr(0x0981) . Chr(0x0982) . Chr(0x0983)
}

; ---------------------------------------------------------------------------
;  Mapping table
; ---------------------------------------------------------------------------
; .een = a text mapping file, scrambled byte by byte. Layout: "EEN" + 0x01 + the text length (4 bytes),
; then each byte is (plain XOR key[i]) + (i*31+17), all modulo 256. This is only meant to stop the
; file being read at a glance; it is not real encryption. A .een file that holds plain text is read as it is.
EenDecode(buf) {
    if (buf.Size = 0)
        return ""
    if (buf.Size < 8 || NumGet(buf, 0, "UChar") != 0x45 || NumGet(buf, 1, "UChar") != 0x45
        || NumGet(buf, 2, "UChar") != 0x4E || NumGet(buf, 3, "UChar") != 1)
        return StrGet(buf, buf.Size, "UTF-8")
    n := NumGet(buf, 4, "UInt")
    if (n > buf.Size - 8)
        throw Error("This .een file is damaged (it ends too early).")
    if (n = 0)
        return ""
    out := Buffer(n, 0)
    kl := StrLen(Cv.ek)
    Loop n {
        i := A_Index - 1
        e := NumGet(buf, 8 + i, "UChar")
        d := ((e - (i * 31 + 17)) & 0xFF) ^ Ord(SubStr(Cv.ek, Mod(i, kl) + 1, 1))
        NumPut("UChar", d, out, i)
    }
    return StrGet(out, n, "UTF-8")
}

LoadMapping(path) {
    SplitPath(path, , , &ext)
    if (StrLower(ext) = "een")
        txt := EenDecode(FileRead(path, "RAW"))
    else
        txt := FileRead(path, "UTF-8")
    if (SubStr(txt, 1, 1) == Chr(0xFEFF))
        txt := SubStr(txt, 2)
    fw := Map()
    fw.CaseSense := "On"
    rv := Map()
    rv.CaseSense := "On"
    fmax := 1
    rmax := 1
    Loop Parse txt, "`n", "`r" {
        line := A_LoopField
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        parts := StrSplit(line, "`t")
        if (parts.Length < 2)
            continue
        a := parts[1]
        u := parts[2]
        if (a = "" || u = "")
            continue
        if !fw.Has(a) {
            fw[a] := u
            fmax := Max(fmax, StrLen(a))
        }
        if !rv.Has(u) {
            rv[u] := a
            rmax := Max(rmax, StrLen(u))
        }
    }
    ; where the table lists several equal glyphs, prefer the usual ones
    if fw.Has(Chr(0x02C6))
        rv[Cv.VAI] := Chr(0x02C6)
    if fw.Has(Chr(0x00D6))
        rv[Cv.HAS . Cv.RA] := Chr(0x00D6)
    Cv.fw := fw
    Cv.rv := rv
    Cv.fwMax := fmax
    Cv.rvMax := rmax
    Cv.rephAnsi := rv.Get(Cv.REPH, "")
}

; ---------------------------------------------------------------------------
;  Helpers
; ---------------------------------------------------------------------------
IsConsCode(o) {
    return (o >= 0x0995 && o <= 0x09B9) || o = 0x09DC || o = 0x09DD || o = 0x09DF
}

IsConsTok(t) {
    return (t != "" && IsConsCode(Ord(t)))
}

IsZW(ch) {
    return (ch == Cv.ZWNJ || ch == Cv.ZWJ)
}

; Longest-match split of s using map m. Returns an array of converted pieces.
; Characters that are not in the table are passed through unchanged.
Tokenize(s, m, maxLen, skipKey := "") {
    toks := []
    n := StrLen(s)
    i := 1
    while (i <= n) {
        hit := false
        L := Min(maxLen, n - i + 1)
        while (L >= 1) {
            k := SubStr(s, i, L)
            if (m.Has(k) && !(skipKey != "" && k == skipKey)) {
                toks.Push(m[k])
                i += L
                hit := true
                break
            }
            L -= 1
        }
        if !hit {
            toks.Push(SubStr(s, i, 1))
            i += 1
        }
    }
    return toks
}

JoinTokens(arr) {
    r := ""
    for v in arr {
        r .= v
    }
    return r
}

MapUni(x) {
    return JoinTokens(Tokenize(x, Cv.rv, Cv.rvMax, Cv.REPH))
}

; ---------------------------------------------------------------------------
;  ANSI (Bijoy) -> Unicode
;  In ANSI the vowel signs i/e/oi come BEFORE the consonant group and the reph
;  comes AFTER it; Unicode wants the opposite, so the pieces are re-ordered.
; ---------------------------------------------------------------------------
AnsiToUni(s) {
    toks := Tokenize(s, Cv.fw, Cv.fwMax)
    n := toks.Length
    out := ""
    i := 1
    while (i <= n) {
        t := toks[i]
        pre := ""
        if (t == Cv.VI || t == Cv.VE || t == Cv.VAI) {
            if (i < n && IsConsTok(toks[i + 1])) {
                pre := t
                i += 1
                t := toks[i]
            } else {
                out .= t
                i += 1
                continue
            }
        }
        if IsConsTok(t) {
            cl := t
            i += 1
            while (i <= n) {
                u := toks[i]
                if (u == Cv.HAS) {
                    if (i < n && IsConsTok(toks[i + 1])) {
                        cl .= u . toks[i + 1]
                        i += 2
                    } else {
                        break
                    }
                } else if (SubStr(u, 1, 1) == Cv.HAS) {
                    cl .= u
                    i += 1
                } else {
                    break
                }
            }
            res := cl
            if (i <= n && toks[i] == Cv.REPH) {
                res := Cv.REPH . cl
                i += 1
            }
            if (pre == Cv.VE) {
                if (i <= n && toks[i] == Cv.AA) {
                    res .= Cv.O
                    i += 1
                } else if (i <= n && toks[i] == Cv.AU) {
                    res .= Cv.AUU
                    i += 1
                } else {
                    res .= pre
                }
            } else if (pre != "") {
                res .= pre
            }
            out .= res
        } else {
            out .= t
            i += 1
        }
    }
    return out
}

; ---------------------------------------------------------------------------
;  Unicode -> ANSI (Bijoy)
; ---------------------------------------------------------------------------
UniToAnsi(s) {
    s := StrReplace(s, Cv.O, Cv.VE . Cv.AA)
    s := StrReplace(s, Cv.AUU, Cv.VE . Cv.AU)
    s := StrReplace(s, Chr(0x09A1) . Chr(0x09BC), Chr(0x09DC))
    s := StrReplace(s, Chr(0x09A2) . Chr(0x09BC), Chr(0x09DD))
    s := StrReplace(s, Chr(0x09AF) . Chr(0x09BC), Chr(0x09DF))
    n := StrLen(s)
    out := ""
    i := 1
    while (i <= n) {
        c := SubStr(s, i, 1)
        j := i
        reph := false
        if (c == Cv.RA && j + 2 <= n && SubStr(s, j + 1, 1) == Cv.HAS && IsConsTok(SubStr(s, j + 2, 1))) {
            reph := true
            j += 2
        }
        if IsConsTok(SubStr(s, j, 1)) {
            k := j + 1
            while true {
                m := k
                if (m <= n && IsZW(SubStr(s, m, 1)))
                    m += 1
                if (m + 1 <= n && SubStr(s, m, 1) == Cv.HAS && IsConsTok(SubStr(s, m + 1, 1))) {
                    k := m + 2
                } else {
                    break
                }
            }
            chain := SubStr(s, j, k - j)
            pre := ""
            post := ""
            while (k <= n) {
                ch := SubStr(s, k, 1)
                if !InStr(Cv.SIGNS, ch, true)
                    break
                if (pre = "" && (ch == Cv.VI || ch == Cv.VE || ch == Cv.VAI)) {
                    pre := ch
                } else {
                    post .= ch
                }
                k += 1
            }
            a := ""
            if (pre != "")
                a := Cv.rv.Get(pre, pre)
            if reph {
                a .= MapUni(chain) . Cv.rephAnsi . MapUni(post)
            } else {
                a .= MapUni(chain . post)
            }
            out .= a
            i := k
        } else {
            out .= MapUni(c)
            i += 1
        }
    }
    return out
}

; ---------------------------------------------------------------------------
;  Library encodings (the code below is the one of Bangla Keyboard.ahk: EncJson, MencDecode, EncLib)
; ---------------------------------------------------------------------------
; .menc = an encoding (JSON) file scrambled the same way as .bkl. Layout: "MEN" + 0x01 + the text length (4 bytes), then each
; byte is (plain XOR key[i]) + (i*31+17), all modulo 256. It only stops the file being read or changed by accident; it is
; not real encryption. Keep the key the same as in Tools\Pupo Encrypter.ahk.
MencDecode(buf) {
    static key := "BanglaMultiEncKey"
    if (buf.Size < 8 || NumGet(buf, 0, "UChar") != 0x4D || NumGet(buf, 1, "UChar") != 0x45
        || NumGet(buf, 2, "UChar") != 0x4E || NumGet(buf, 3, "UChar") != 1)
        throw Error("This is not a valid .menc encoding file.")
    n := NumGet(buf, 4, "UInt")
    if (n > buf.Size - 8)
        throw Error("This .menc encoding file is damaged (it ends too early).")
    if (n = 0)
        return ""
    out := Buffer(n, 0)
    kl := StrLen(key)
    Loop n {
        i := A_Index - 1
        e := NumGet(buf, 8 + i, "UChar")
        NumPut("UChar", ((e - (i * 31 + 17)) & 0xFF) ^ Ord(SubStr(key, Mod(i, kl) + 1, 1)), out, i)
    }
    return StrGet(out, n, "UTF-8")
}

; a small JSON reader (objects become Maps, lists become Arrays)
class EncJson {
    __New(txt) {
        this.t := txt
        this.i := 1
        this.n := StrLen(txt)
    }

    static Parse(txt) {
        if (SubStr(txt, 1, 1) == Chr(0xFEFF))
            txt := SubStr(txt, 2)
        rd := EncJson(txt)
        return rd.Value()
    }

    Fail(msg) {
        throw Error(msg . " (position " . this.i . ")")
    }

    Ws() {
        while (this.i <= this.n) {
            c := SubStr(this.t, this.i, 1)
            if (c == " " || c == "`t" || c == "`n" || c == "`r")
                this.i += 1
            else
                break
        }
    }

    Value() {
        this.Ws()
        if (this.i > this.n)
            this.Fail("The file ends too early")
        c := SubStr(this.t, this.i, 1)
        if (c == "{")
            return this.Obj()
        if (c == "[")
            return this.Arr()
        if (c == '"')
            return this.Str()
        w := SubStr(this.t, this.i, 4)
        if (w == "true") {
            this.i += 4
            return true
        }
        if (w == "null") {
            this.i += 4
            return ""
        }
        if (SubStr(this.t, this.i, 5) == "false") {
            this.i += 5
            return false
        }
        if (RegExMatch(this.t, "-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?", &m, this.i) && m.Pos[0] = this.i) {
            this.i += m.Len[0]
            return Number(m[0])
        }
        this.Fail("Unexpected character")
    }

    Obj() {
        o := Map()
        this.i += 1
        this.Ws()
        if (SubStr(this.t, this.i, 1) == "}") {
            this.i += 1
            return o
        }
        Loop {
            this.Ws()
            if (SubStr(this.t, this.i, 1) != '"')
                this.Fail("A name in quotes was expected")
            k := this.Str()
            this.Ws()
            if (SubStr(this.t, this.i, 1) != ":")
                this.Fail("A ':' was expected")
            this.i += 1
            o[k] := this.Value()
            this.Ws()
            c := SubStr(this.t, this.i, 1)
            this.i += 1
            if (c == "}")
                return o
            if (c != ",")
                this.Fail("A ',' or '}' was expected")
        }
    }

    Arr() {
        a := []
        this.i += 1
        this.Ws()
        if (SubStr(this.t, this.i, 1) == "]") {
            this.i += 1
            return a
        }
        Loop {
            a.Push(this.Value())
            this.Ws()
            c := SubStr(this.t, this.i, 1)
            this.i += 1
            if (c == "]")
                return a
            if (c != ",")
                this.Fail("A ',' or ']' was expected")
        }
    }

    Str() {
        this.i += 1
        out := ""
        Loop {
            if !RegExMatch(this.t, '["\\]', &m, this.i)
                this.Fail("A text is not closed")
            p := m.Pos[0]
            out .= SubStr(this.t, this.i, p - this.i)
            if (SubStr(this.t, p, 1) == '"') {
                this.i := p + 1
                return out
            }
            e := SubStr(this.t, p + 1, 1)
            this.i := p + 2
            if (e == "n") {
                out .= "`n"
            } else if (e == "t") {
                out .= "`t"
            } else if (e == "r") {
                out .= "`r"
            } else if (e == "b") {
                out .= "`b"
            } else if (e == "f") {
                out .= "`f"
            } else if (e == "u") {
                h := SubStr(this.t, this.i, 4)
                if !RegExMatch(h, "^[0-9A-Fa-f]{4}$")
                    this.Fail("A \u code is not correct")
                out .= Chr(Integer("0x" . h))
                this.i += 4
            } else {
                out .= e
            }
        }
    }
}

; the rules of one encoding (one Library\*.json or *.menc file) and the Unicode -> ANSI conversion
class EncLib {
    static HAS := Chr(0x09CD)
    static ZWNJ := Chr(0x200C)
    static ZWJ := Chr(0x200D)
    static RA := Chr(0x09B0)
    static YA := Chr(0x09AF)
    static VI := Chr(0x09BF)
    static VE := Chr(0x09C7)
    static VAI := Chr(0x09C8)
    static AA := Chr(0x09BE)
    static AU := Chr(0x09D7)
    static O := Chr(0x09CB)
    static AUU := Chr(0x09CC)

    __New() {
        this.name := ""
        this.font := ""
        this.raw := ""                 ; the whole file as read (Map), kept for the ANSI -> Unicode side
        this.uni := Map()               ; Unicode text -> ANSI text
        this.uni.CaseSense := "On"
        this.maxKey := 2
        this.cons := Map()              ; constant name -> [Unicode text, ANSI text, section]
        this.vowel := Map()             ; vowel sign -> {def, rules}
        this.groups := Map()            ; group name -> list of Unicode texts
        this.ra := Map()                ; group name -> list of ANSI texts
        this.rfola := []                ; [{grp, val}]
        this.karFix := []               ; [{ch, src, dst}]
        this.kmid := Map()              ; ে ৈ in the middle of a word (the form that joins the headline); at the start of a word the usual form is used
        this.pre := []                  ; [[from, to]] applied before the conversion
        this.post := []                 ; [[from, to]] applied to the ANSI result
        this.reph := ""
        this.zfola := ""
        this.hasA := "&"
        this.q := ["", "", "", ""]      ; start / end of double quotes, start / end of single quotes
    }

    static F(e, a, b) {
        if e.Has(a)
            return e[a]
        return e.Has(b) ? e[b] : ""
    }

    static IsCons(ch) {
        if (ch == "")
            return false
        o := Ord(ch)
        return (o >= 0x0995 && o <= 0x09B9) || o = 0x09CE || o = 0x09DC || o = 0x09DD || o = 0x09DF
    }

    ; a Bengali letter / sign: what stands before ে ৈ decides which form of the sign is used (start of a word or middle)
    static IsWordChar(ch) {
        if (ch == "")
            return false
        o := Ord(ch)
        if (o = 0x200C || o = 0x200D)
            return true
        return o >= 0x0981 && o <= 0x09FF && !(o >= 0x09E6 && o <= 0x09EF) && !(o >= 0x09F2 && o <= 0x09FB)
    }

    static IsSign(ch) {
        if (ch == "")
            return false
        o := Ord(ch)
        return (o >= 0x09BE && o <= 0x09C4) || o = 0x09C7 || o = 0x09C8 || o = 0x09CB || o = 0x09CC
            || o = 0x09D7 || o = 0x0981 || o = 0x0982 || o = 0x0983 || o = 0x09BC
    }

    ; "#$09B0" = a character code, "#{A_K}" = another constant of the file (its ANSI text, or its Unicode text when uniMode)
    Tok(t, uniMode) {
        out := ""
        i := 1
        n := StrLen(t)
        while (i <= n) {
            c := SubStr(t, i, 1)
            if (c == "#" && i < n) {
                d := SubStr(t, i + 1, 1)
                if (d == "$" && RegExMatch(SubStr(t, i + 2, 4), "^[0-9A-Fa-f]{1,4}", &m)) {
                    out .= Chr(Integer("0x" . m[0]))
                    i += 2 + m.Len[0]
                    continue
                }
                if (d == "{") {
                    e := InStr(t, "}", true, i + 2)
                    if e {
                        nm := SubStr(t, i + 2, e - i - 2)
                        if this.cons.Has(nm)
                            out .= uniMode ? this.cons[nm][1] : this.cons[nm][2]
                        i := e + 1
                        continue
                    }
                }
            }
            out .= c
            i += 1
        }
        return out
    }

    CA(name) {
        return this.cons.Has(name) ? this.cons[name][2] : ""
    }

    static Load(path) {
        SplitPath(path, , , &fext)
        d := EncJson.Parse((StrLower(fext) = "menc") ? MencDecode(FileRead(path, "RAW")) : FileRead(path, "UTF-8"))
        if !(d is Map)
            throw Error("This is not an encoding file")
        L := EncLib()
        SplitPath(path, , , , &nm)
        L.name := nm
        L.raw := d
        meta := d.Has("Metadata") ? d["Metadata"] : Map()
        fnt := ""
        if (meta is Map)
            fnt := meta.Has("Suggested Font") ? meta["Suggested Font"] : (meta.Has("Font") ? meta["Font"] : "")
        parts := StrSplit(fnt, ",")
        L.font := (parts.Length > 0) ? Trim(parts[1]) : ""

        ; constants
        if (d.Has("Constants") && d["Constants"] is Map) {
            for sec, items in d["Constants"] {
                if !(items is Map)
                    continue
                for cn, e in items {
                    if !(e is Map)
                        continue
                    L.cons[cn] := [L.Tok(EncLib.F(e, "Unicode", "UnicodeKey"), true), L.Tok(EncLib.F(e, "Replace", "Value"), false), sec]
                }
            }
        }
        kar := Map()
        for cn, c in L.cons {
            sec := c[3]
            k := c[1]
            if (k == "" || sec = "FirstHalfForms" || sec = "SecondHalfForms")
                continue
            if (k == Chr(34) || k == "'")
                continue                                  ; quotes are chosen by position (start / end)
            if (sec = "VowelsAndKars" && StrLen(k) = 1 && Ord(k) >= 0x09BE && Ord(k) <= 0x09CC) {
                if (!kar.Has(k) || StrCompare(cn, kar[k]) < 0)
                    kar[k] := cn                          ; several forms of one sign: the first name is the usual one
                continue
            }
            L.uni[k] := c[2]
        }
        for k, cn in kar
            L.uni[k] := L.cons[cn][2]

        ; groups
        if (d.Has("ConsonantGroups") && d["ConsonantGroups"] is Map) {
            for gn, arr in d["ConsonantGroups"] {
                lst := []
                if (arr is Array) {
                    for x in arr
                        lst.Push(L.Tok(x, true))
                }
                L.groups[gn] := lst
            }
        }
        if (d.Has("RaPhalaGroups") && d["RaPhalaGroups"] is Map) {
            for gn, arr in d["RaPhalaGroups"] {
                lst := []
                if (arr is Array) {
                    for x in arr
                        lst.Push(L.Tok(x, false))
                }
                L.ra[gn] := lst
            }
        }

        ; ু ূ ৃ: the form depends on the letter before
        if (d.Has("VowelRules") && d["VowelRules"] is Map) {
            for k, r in d["VowelRules"] {
                ku := L.Tok(k, true)
                rules := []
                if (r.Has("mappings") && r["mappings"] is Array) {
                    for m in r["mappings"] {
                        cg := m.Has("consonants") ? m["consonants"] : ""
                        mem := []
                        proc := m.Has("process") ? m["process"] : "pre"
                        if (proc = "post")
                            mem := L.ra.Has(cg) ? L.ra[cg] : []
                        else if (SubStr(cg, 1, 2) == "#$")
                            mem := [L.Tok(cg, true)]
                        else
                            mem := L.groups.Has(cg) ? L.groups[cg] : []
                        rules.Push({mem: mem, val: L.Tok(m.Has("value") ? m["value"] : "", false), mode: m.Has("matchMode") ? m["matchMode"] : 1, proc: proc})
                    }
                }
                dflt := L.Tok(r.Has("default") ? r["default"] : "", false)
                L.vowel[ku] := {def: dflt, rules: rules}
                if (dflt != "")
                    L.uni[ku] := dflt
            }
        }
        if (d.Has("KarDefaults") && d["KarDefaults"] is Map) {
            for k, v in d["KarDefaults"]
                L.uni[L.Tok(k, true)] := L.Tok(v, false)
        }
        if (d.Has("KarMidWord") && d["KarMidWord"] is Map) {
            for k, v in d["KarMidWord"]
                L.kmid[L.Tok(k, true)] := L.Tok(v, false)
        }

        ; conjuncts (the extra list first, then the list that wins over everything else)
        for sec in ["ConjunctForms", "FullFormReplacements"] {
            if !(d.Has(sec) && d[sec] is Array)
                continue
            for r in d[sec] {
                if !(r is Map)
                    continue
                k := L.Tok(EncLib.F(r, "Unicode", "Key"), true)
                if (k != "")
                    L.uni[k] := L.Tok(EncLib.F(r, "Replace", "Value"), false)
            }
        }
        if (!L.uni.Has(EncLib.AU) && L.uni.Has(EncLib.AUU))
            L.uni[EncLib.AU] := L.uni[EncLib.AUU]
        for k in L.uni
            L.maxKey := Max(L.maxKey, StrLen(k))

        if (d.Has("RfolaRules") && d["RfolaRules"] is Array) {
            for r in d["RfolaRules"] {
                if (r is Map)
                    L.rfola.Push({grp: r.Has("consonants") ? r["consonants"] : "default", val: L.Tok(r.Has("value") ? r["value"] : "", false)})
            }
        }
        if (d.Has("KarCorrections") && d["KarCorrections"] is Array) {
            for r in d["KarCorrections"] {
                if (r is Map)
                    L.karFix.Push({ch: L.Tok(r.Has("char") ? r["char"] : "", false), src: L.Tok(r.Has("from") ? r["from"] : "", false), dst: L.Tok(r.Has("to") ? r["to"] : "", false)})
            }
        }
        for pair in [["PreReplacements", L.pre], ["PostReplacements", L.post]] {
            if !(d.Has(pair[1]) && d[pair[1]] is Array)
                continue
            for r in d[pair[1]] {
                if !(r is Map)
                    continue
                k := L.Tok(EncLib.F(r, "Unicode", "Key"), false)
                if (k != "")
                    pair[2].Push([k, L.Tok(EncLib.F(r, "Replace", "Value"), false)])
            }
        }
        L.reph := L.CA("A_Reph")
        L.zfola := L.CA("A_ZFola")
        if L.uni.Has(EncLib.HAS)
            L.hasA := L.uni[EncLib.HAS]
        L.q := [L.CA("A_StartDoubleQuote"), L.CA("A_EndDoubleQuote"), L.CA("A_StartSingleQuote"), L.CA("A_EndSingleQuote")]
        return L
    }

    ; র-ফলা: which form depends on the letter before it
    RfolaFor(prevU) {
        for r in this.rfola {
            if (r.grp = "default")
                return r.val
            if this.groups.Has(r.grp) {
                for x in this.groups[r.grp] {
                    if (x == prevU)
                        return r.val
                }
            }
        }
        return this.uni.Has(EncLib.HAS . EncLib.RA) ? this.uni[EncLib.HAS . EncLib.RA] : ""
    }

    ; ু ূ ৃ after a letter / conjunct: chain = the letters (Unicode), prevA = ANSI text just before the sign
    KarFor(k, chain, prevA) {
        v := this.vowel[k]
        val := v.def
        for m in v.rules {
            ok := false
            if (m.proc = "post") {
                for x in m.mem {
                    if (x == prevA) {
                        ok := true
                        break
                    }
                }
            } else if (m.mode = 1) {
                for x in m.mem {
                    if (x == chain) {
                        ok := true
                        break
                    }
                }
            } else {
                for x in m.mem {
                    if (x != "" && StrLen(chain) >= StrLen(x) && SubStr(chain, -StrLen(x)) == x) {
                        ok := true
                        break
                    }
                }
            }
            if ok {
                val := m.val
                break
            }
        }
        for c in this.karFix {
            if (prevA == c.ch && val == c.src)
                val := c.dst
        }
        return val
    }

    ; cuts the text into pieces (longest match first): [[Unicode, ANSI], ...]
    Tokenize(t) {
        toks := []
        n := StrLen(t)
        i := 1
        hr := EncLib.HAS . EncLib.RA
        hy := EncLib.HAS . EncLib.YA
        while (i <= n) {
            hit := false
            L := Min(this.maxKey, n - i + 1)
            while (L >= 1) {
                k := SubStr(t, i, L)
                if (L = 2 && k == hr && this.rfola.Length > 0) {
                    toks.Push([k, "<RF>"])
                    hit := true
                } else if (L = 2 && k == hy && this.zfola != "") {
                    toks.Push([k, this.zfola])
                    hit := true
                } else if this.uni.Has(k) {
                    toks.Push([k, this.uni[k]])
                    hit := true
                }
                if hit {
                    i += L
                    break
                }
                L -= 1
            }
            if !hit {
                toks.Push([SubStr(t, i, 1), SubStr(t, i, 1)])
                i += 1
            }
        }
        return toks
    }

    ; one letter group (letters, conjunct signs, then the vowel signs that follow) -> ANSI text
    ; pre = the sign that goes in front (ি ে ৈ), reph = the group starts with রেফ (র্)
    Cluster(chain, post, pre, reph) {
        toks := this.Tokenize(chain . post)
        res := ""
        prevU := ""
        prevA := ""
        pos := 0
        cl := StrLen(chain)
        rdone := !reph
        for tk in toks {
            k := tk[1]
            a := tk[2]
            if (a == "<RF>") {
                a := this.RfolaFor(prevU)
            } else if (StrLen(k) = 1 && pos >= cl && this.vowel.Has(k)) {
                a := this.KarFor(k, chain, prevA)
            }
            res .= a
            pos += StrLen(k)
            if (!rdone && pos >= cl) {
                res .= this.reph
                rdone := true
            }
            prevU := k
            prevA := a
        }
        if !rdone
            res .= this.reph
        return pre . res
    }

    ; Unicode text -> ANSI text
    Conv(s) {
        for p in this.pre
            s := StrReplace(s, p[1], p[2], "On")
        s := StrReplace(s, EncLib.O, EncLib.VE . EncLib.AA, "On")
        s := StrReplace(s, EncLib.AUU, EncLib.VE . EncLib.AU, "On")
        s := StrReplace(s, Chr(0x09A1) . Chr(0x09BC), Chr(0x09DC), "On")
        s := StrReplace(s, Chr(0x09A2) . Chr(0x09BC), Chr(0x09DD), "On")
        s := StrReplace(s, Chr(0x09AF) . Chr(0x09BC), Chr(0x09DF), "On")
        out := ""
        n := StrLen(s)
        i := 1
        while (i <= n) {
            c := SubStr(s, i, 1)
            if (c == EncLib.ZWNJ || c == EncLib.ZWJ) {
                i += 1
                continue
            }
            j := i
            reph := false
            if (c == EncLib.RA && i + 2 <= n && SubStr(s, i + 1, 1) == EncLib.HAS && EncLib.IsCons(SubStr(s, i + 2, 1))) {
                reph := true
                j := i + 2
            }
            if EncLib.IsCons(SubStr(s, j, 1)) {
                k := j + 1
                while true {
                    m := k
                    if (m <= n && (SubStr(s, m, 1) == EncLib.ZWNJ || SubStr(s, m, 1) == EncLib.ZWJ))
                        m += 1
                    if (m + 1 <= n && SubStr(s, m, 1) == EncLib.HAS && EncLib.IsCons(SubStr(s, m + 1, 1)))
                        k := m + 2
                    else
                        break
                }
                chain := SubStr(s, j, k - j)
                chain := StrReplace(chain, EncLib.ZWNJ, "")
                chain := StrReplace(chain, EncLib.ZWJ, "")
                tail := ""
                if (k <= n && SubStr(s, k, 1) == EncLib.HAS) {
                    tail := this.hasA                     ; a hasanta typed but its next letter is not here yet
                    k += 1
                }
                pre := ""
                post := ""
                mid := (i > 1 && EncLib.IsWordChar(SubStr(s, i - 1, 1))) ? true : false
                if (tail == "") {
                    while (k <= n) {
                        ch := SubStr(s, k, 1)
                        if !EncLib.IsSign(ch)
                            break
                        if (pre == "" && (ch == EncLib.VI || ch == EncLib.VE || ch == EncLib.VAI))
                            pre := (mid && this.kmid.Has(ch)) ? this.kmid[ch] : (this.uni.Has(ch) ? this.uni[ch] : ch)
                        else
                            post .= ch
                        k += 1
                    }
                }
                out .= this.Cluster(chain, post, pre, reph) . tail
                i := k
                continue
            }
            if (c == Chr(34) || c == "'") {
                p := (i > 1) ? SubStr(s, i - 1, 1) : ""
                st := (p == "" || InStr(" `t`r`n([{<", p, true)) ? true : false
                idx := (c == Chr(34)) ? (st ? 1 : 2) : (st ? 3 : 4)
                out .= (this.q[idx] != "") ? this.q[idx] : c
                i += 1
                continue
            }
            done := false
            L := Min(this.maxKey, n - i + 1)
            while (L >= 2) {
                k := SubStr(s, i, L)
                if this.uni.Has(k) {
                    out .= this.uni[k]
                    i += L
                    done := true
                    break
                }
                L -= 1
            }
            if !done {
                if ((c == EncLib.VE || c == EncLib.VAI) && i > 1 && EncLib.IsWordChar(SubStr(s, i - 1, 1)) && this.kmid.Has(c))
                    out .= this.kmid[c]
                else
                    out .= this.uni.Has(c) ? this.uni[c] : c
                i += 1
            }
        }
        for p in this.post
            out := StrReplace(out, p[1], p[2], "On")
        return out
    }
}

; ---------------------------------------------------------------------------
;  ANSI -> Unicode, from the SAME Library file
;  A Library encoding only says how Unicode becomes ANSI (that is what the keyboard needs). For the way back the
;  rules are turned around: every ANSI text the encoding can produce (letters, signs and all their glyph variants,
;  the conjunct lists, the first / second halves, the ya-phala / ra-phala forms) points back to its Unicode text.
;    - first halves (the glyph in front of a letter, e.g. of ম্ফ) are found from the conjunct lists themselves
;    - where two Unicode texts share one ANSI text, the later source wins (like the forward rules, where
;      FullFormReplacements win over everything), except that a first half always wins for its own letter
;    - the vowel signs i / e / oi stand BEFORE the letters in ANSI and the reph AFTER them; Unicode wants the
;      opposite, so the pieces are re-ordered (the same steps the old converter did)
; ---------------------------------------------------------------------------
class EncRev {
    __New(lib) {
        this.lib := lib
        this.map := Map()                ; ANSI text -> Unicode text
        this.map.CaseSense := "On"
        this.maxLen := 1
        this.Build()
    }

    ; a Bangla letter / sign / digit (the danda 0964 and 0965 count too)
    static HasBangla(u) {
        Loop Parse u {
            o := Ord(A_LoopField)
            if ((o >= 0x0980 && o <= 0x09FF) || o = 0x0964 || o = 0x0965)
                return true
        }
        return false
    }

    static IsConsTok(t) {
        return (t != "" && EncLib.IsCons(SubStr(t, 1, 1)))
    }

    ; the keys of a Map in a fixed (ordinal) order, so the result does not depend on how a Map happens to enumerate
    static SortedKeys(m) {
        names := []
        for k in m
            names.Push(k)
        Loop names.Length {
            i := A_Index
            v := names[i]
            j := i - 1
            while (j >= 1 && StrCompare(names[j], v, "On") > 0) {
                names[j + 1] := names[j]
                j--
            }
            names[j + 1] := v
        }
        return names
    }

    ; remember "ANSI text a stands for Unicode text u" (a list per ANSI text, in the order found)
    Add(cand, a, u) {
        u := StrReplace(u, EncLib.AUU, EncLib.AU, "On")      ; ৌ = ে + the au length mark; the re-ordering below puts them together again
        if (a = "" || u = "" || !EncRev.HasBangla(u))
            return
        if !cand.Has(a)
            cand[a] := []
        for x in cand[a] {
            if (x == u)
                return
        }
        cand[a].Push(u)
    }

    ; ANSI text -> Unicode text with what is known so far ("" when some part is unknown)
    Resolve(cand, t) {
        out := ""
        i := 1
        n := StrLen(t)
        while (i <= n) {
            hit := false
            k := n - i + 1
            while (k >= 1) {
                s := SubStr(t, i, k)
                if cand.Has(s) {
                    out .= cand[s][1]
                    i += k
                    hit := true
                    break
                }
                k -= 1
            }
            if !hit
                return ""
        }
        return out
    }

    ; a glyph that is not a letter of its own but starts a conjunct: ANSI "g + rest" = Unicode "C hasanta rest"
    InferHalf(cand, half1, a, u) {
        h := EncLib.HAS
        if (StrLen(a) < 2 || StrLen(u) < 3)
            return
        g := SubStr(a, 1, 1)
        if cand.Has(g)
            return
        c1 := SubStr(u, 1, 1)
        if (SubStr(u, 2, 1) !== h || !EncLib.IsCons(c1))
            return
        x := this.Resolve(cand, SubStr(a, 2))
        if (x != "" && u == c1 . h . x) {
            half1[g] := c1 . h
            this.Add(cand, g, c1 . h)
        }
    }

    Build() {
        L := this.lib
        d := L.raw
        h := EncLib.HAS
        cand := Map()
        cand.CaseSense := "On"
        half1 := Map()
        half1.CaseSense := "On"
        names := EncRev.SortedKeys(L.cons)
        byName := Map()                  ; "a_k" -> ক  (the letters, to read the names of the half forms)
        byName.CaseSense := "On"
        for cn in names {
            c := L.cons[cn]
            if (c[3] = "Consonants" && StrLen(c[1]) = 1)
                byName[StrLower(cn)] := c[1]
        }

        ; first / second halves (a constant that is marked "not added" / "missing" / "doesn't exist" is left out)
        for cn in names {
            c := L.cons[cn]
            sec := c[3]
            if (sec != "FirstHalfForms" && sec != "SecondHalfForms")
                continue
            e := d["Constants"][sec][cn]
            cm := (e is Map) ? e.Get("Comment", "") : ""
            if RegExMatch(cm, "i)Not added|Missing|Doesn.?t exist|Doens.?t exist")
                continue
            a := c[2]
            if (sec = "FirstHalfForms") {
                if (RegExMatch(cn, "^A_(.+?)_1H(?:_\d+)?$", &m) && byName.Has("a_" . StrLower(m[1]))) {
                    half1[a] := byName["a_" . StrLower(m[1])] . h
                    this.Add(cand, a, half1[a])
                }
            } else if (cn = "A_ZFola") {
                this.Add(cand, a, h . EncLib.YA)
            } else if RegExMatch(cn, "^A_RFola_\d+$") {
                this.Add(cand, a, h . EncLib.RA)
            } else if (StrLen(c[1]) = 1 && EncLib.IsCons(c[1])) {
                this.Add(cand, a, h . c[1])
            } else if (RegExMatch(cn, "^A_(.+?)_2H(?:_\d+)?$", &m) && byName.Has("a_" . StrLower(m[1]))) {
                this.Add(cand, a, h . byName["a_" . StrLower(m[1])])
            }
        }
        for r in L.rfola
            this.Add(cand, r.val, h . EncLib.RA)

        ; letters, digits, symbols, vowel signs (every glyph variant); the quotes are chosen by position, not reversed
        for cn in names {
            c := L.cons[cn]
            sec := c[3]
            if (sec = "FirstHalfForms" || sec = "SecondHalfForms" || c[1] == "")
                continue
            if (c[1] == Chr(34) || c[1] == "'")
                continue
            this.Add(cand, c[2], c[1])
        }

        ; the conjunct lists
        entries := []
        for sec in ["ConjunctForms", "FullFormReplacements"] {
            if !(d.Has(sec) && d[sec] is Array)
                continue
            for r in d[sec] {
                if !(r is Map)
                    continue
                a := L.Tok(EncLib.F(r, "Replace", "Value"), false)
                u := L.Tok(EncLib.F(r, "Unicode", "Key"), true)
                entries.Push([a, u])
                this.Add(cand, a, u)
            }
        }

        ; ু ূ ৃ and ে ৈ in the middle of a word: every form points back to its sign
        for k in EncRev.SortedKeys(L.vowel) {
            v := L.vowel[k]
            this.Add(cand, v.def, k)
            for m in v.rules
                this.Add(cand, m.val, k)
        }
        for k in EncRev.SortedKeys(L.kmid)
            this.Add(cand, L.kmid[k], k)

        ; first halves that no constant declares
        for p in entries
            this.InferHalf(cand, half1, p[1], p[2])
        for cn in names {
            c := L.cons[cn]
            if (c[3] = "FullForms")
                this.InferHalf(cand, half1, c[2], c[1])
        }

        ; one Unicode text for every ANSI text
        for a, us in cand {
            pick := us[us.Length]
            if (us.Length > 1) {
                g := SubStr(a, 1, 1)
                hh := half1.Has(g) ? half1[g] : ""
                if (hh != "") {
                    for u in us {
                        if (SubStr(u, 1, StrLen(hh)) == hh) {
                            pick := u
                            break
                        }
                    }
                }
            }
            this.map[a] := pick
            if (StrLen(a) > this.maxLen)
                this.maxLen := StrLen(a)
        }

        ; the reph glyph (র্) is re-ordered later; whatever ends with it is not needed
        rp := L.reph
        if (rp != "") {
            n := StrLen(rp)
            doomed := []
            for a in this.map {
                if (a !== rp && StrLen(a) > n && SubStr(a, -n) == rp)
                    doomed.Push(a)
            }
            for a in doomed
                this.map.Delete(a)
            this.map[rp] := EncLib.RA . h
        }
    }

    ; longest match first; text that is not in the table (spaces, punctuation, English ...) stays as it is
    Tokens(t) {
        toks := []
        n := StrLen(t)
        i := 1
        while (i <= n) {
            hit := false
            k := Min(this.maxLen, n - i + 1)
            while (k >= 1) {
                s := SubStr(t, i, k)
                if this.map.Has(s) {
                    toks.Push(this.map[s])
                    i += k
                    hit := true
                    break
                }
                k -= 1
            }
            if !hit {
                toks.Push(SubStr(t, i, 1))
                i += 1
            }
        }
        return toks
    }

    ; ANSI text -> Unicode text
    Conv(t) {
        toks := this.Tokens(t)
        n := toks.Length
        h := EncLib.HAS
        reph := EncLib.RA . h
        out := ""
        i := 1
        while (i <= n) {
            tk := toks[i]
            pre := ""
            if (tk == EncLib.VI || tk == EncLib.VE || tk == EncLib.VAI) {
                if (i < n && EncRev.IsConsTok(toks[i + 1])) {
                    pre := tk
                    i += 1
                    tk := toks[i]
                } else {
                    out .= tk
                    i += 1
                    continue
                }
            }
            if EncRev.IsConsTok(tk) {
                cl := tk
                i += 1
                while (i <= n) {
                    u := toks[i]
                    if (SubStr(cl, -1) == h && EncRev.IsConsTok(u)) {
                        cl .= u                                  ; the letter after a first half
                        i += 1
                    } else if (u == h) {
                        if (i < n && EncRev.IsConsTok(toks[i + 1])) {
                            cl .= u . toks[i + 1]
                            i += 2
                        } else {
                            break
                        }
                    } else if (SubStr(u, 1, 1) == h) {
                        cl .= u                                  ; ্য ্র ্ব ...
                        i += 1
                    } else {
                        break
                    }
                }
                ; a ra that starts a conjunct (র + ্য) must not turn into a reph
                if (StrLen(cl) > 2 && SubStr(cl, 1, 1) == EncLib.RA && SubStr(cl, 2, 1) == h)
                    cl := EncLib.RA . EncLib.ZWNJ . SubStr(cl, 2)
                res := cl
                if (i <= n && toks[i] == reph) {
                    res := reph . cl
                    i += 1
                }
                if (pre == EncLib.VE) {
                    if (i <= n && toks[i] == EncLib.AA) {
                        res .= EncLib.O
                        i += 1
                    } else if (i <= n && toks[i] == EncLib.AU) {
                        res .= EncLib.AUU
                        i += 1
                    } else {
                        res .= pre
                    }
                } else if (pre != "") {
                    res .= pre
                }
                out .= res
            } else {
                out .= tk
                i += 1
            }
        }
        return out
    }
}

; ---------------------------------------------------------------------------
;  Window
; ---------------------------------------------------------------------------
; Conversion only happens when one of the two buttons is pressed.
; "To Unicode": ANSI box -> Unicode box
CvToUnicode(*) {
    CvSetText(Cv.uni, (Cv.mode = "lib") ? Cv.rev.Conv(Cv.ansi.Value) : AnsiToUni(Cv.ansi.Value))
}

; "To ANSI": Unicode box -> ANSI box
CvToAnsi(*) {
    CvSetText(Cv.ansi, (Cv.mode = "lib") ? Cv.lib.Conv(Cv.uni.Value) : UniToAnsi(Cv.uni.Value))
}

; makes the chosen encoding the one in use
CvLoadItem(it) {
    if (it["kind"] = "lib") {
        lib := EncLib.Load(it["path"])
        rev := EncRev(lib)                  ; both are built before anything is replaced, so a broken file changes nothing
        Cv.lib := lib
        Cv.rev := rev
        Cv.mode := "lib"
    } else {
        LoadMapping(it["path"])
        Cv.mode := "txt"
    }
}

CvTitle() {
    t := "Bangla Text Converter  -  " . Cv.files[Cv.cur]["name"]
    if (Cv.mode = "lib" && Cv.lib.font != "")
        t .= "   (suggested font: " . Cv.lib.font . ")"
    Cv.gui.Title := t
}

CvMappingChanged(*) {
    idx := Cv.dd.Value
    if (idx < 1)
        return
    try {
        CvLoadItem(Cv.files[idx])
    } catch as e {
        MsgBox("Could not read the encoding:`n" . Cv.files[idx]["path"] . "`n`n" . e.Message, "Bangla Text Converter", 0x10)
        Cv.dd.Choose(Cv.cur)                ; back to the one that is still in use
        return
    }
    Cv.cur := idx
    CvApplyEncFont(Cv.files[idx])
    CvTitle()
    ; texts stay as they are; they are only converted when a button is pressed
}

; ANSI preview font / size, chosen from the toolbar. Both boxes accept a pick from the
; list or typed text. The text is read a moment after the event, because right after a
; list pick the box can still hold its old text.
CvToolFont(*) {
    SetTimer(CvApplyToolFont.Bind(false), -80)
}

CvToolFontDone(*) {                                  ; focus left the box: accept any typed name
    SetTimer(CvApplyToolFont.Bind(true), -10)
}

CvApplyToolFont(any) {
    f := Trim(Cv.fd.Text)
    if (f = "")
        return
    found := false
    for n in Cv.fonts {
        if (n = f) {                                 ; case-insensitive match with an installed font
            f := n
            found := true
            break
        }
    }
    if (!found && !any)
        return                                       ; still typing: wait for a full name
    if (f = Cv.fontA)
        return
    Cv.fontA := f
    CvApplyFonts()
    CvSaveSettings()
}

CvToolSize(*) {
    SetTimer(CvApplyToolSize, -80)
}

CvApplyToolSize() {
    v := Trim(Cv.sz.Text)
    if (!IsInteger(v) || v < 6 || v > 72)
        return                                       ; ignore half-typed values like "1"
    if (Integer(v) = Cv.sizeA)
        return
    Cv.sizeA := Integer(v)
    CvApplyFonts()
    CvSaveSettings()
}

CvClear(*) {
    CvSetText(Cv.ansi, "")
    CvSetText(Cv.uni, "")
    CvFocusBox()
}

; ---------------------------------------------------------------------------
;  Undo / Redo
;  Each box keeps its own list of texts (a step is added when typing pauses for a moment, and straight away for
;  a conversion, Clear both, Cut, Paste and Delete). The list is kept small: at most 100 steps per box.
; ---------------------------------------------------------------------------
CvHistInit(ctl) {
    hm := Map()
    hm["s"] := [ctl.Value]                           ; the texts
    hm["p"] := 1                                     ; which one is showing now
    hm["f"] := CvHistCommit.Bind(ctl)                ; one timer function per box, so a new keystroke restarts the wait
    Cv.h[ctl.Hwnd] := hm
    ctl.OnEvent("Change", CvHistChange)
}

CvHistChange(ctl, *) {
    SetTimer(Cv.h[ctl.Hwnd]["f"], -400)
}

; adds the text now in the box as a new step (nothing happens when it is the same as the current step)
CvHistCommit(ctl) {
    hm := Cv.h[ctl.Hwnd]
    s := hm["s"]
    txt := ctl.Value
    if (StrCompare(txt, s[hm["p"]], "On") = 0)
        return
    while (s.Length > hm["p"])                       ; a new edit after Undo drops the Redo steps
        s.Pop()
    s.Push(txt)
    tot := 0
    for x in s
        tot += StrLen(x)
    while (s.Length > 2 && (s.Length > 100 || tot > 10000000)) {
        tot -= StrLen(s[1])
        s.RemoveAt(1)
    }
    hm["p"] := s.Length
}

; the typing that is still waiting for its timer becomes a step now
CvHistFlush(ctl) {
    SetTimer(Cv.h[ctl.Hwnd]["f"], 0)
    CvHistCommit(ctl)
}

; sets the text of a box and records it as one step
CvSetText(ctl, txt) {
    CvHistFlush(ctl)
    ctl.Value := txt
    CvHistCommit(ctl)
}

; dir = -1 Undo, 1 Redo
CvHistStep(ctl, dir) {
    CvHistFlush(ctl)
    hm := Cv.h[ctl.Hwnd]
    np := hm["p"] + dir
    if (np < 1 || np > hm["s"].Length)
        return
    old := ctl.Value
    nt := hm["s"][np]
    hm["p"] := np
    ctl.Value := nt
    SetTimer(hm["f"], 0)                             ; the text equals the step already, nothing to add
    a := CvDiffStart(old, nt)
    e := StrLen(nt) - CvDiffTail(old, nt, a)         ; the cursor goes to the end of what changed
    SendMessage(0xB1, e, e, ctl.Hwnd)                ; EM_SETSEL
    SendMessage(0xB7, 0, 0, ctl.Hwnd)                ; EM_SCROLLCARET
}

; number of equal characters at the start of a and b
CvDiffStart(a, b) {
    n := Min(StrLen(a), StrLen(b))
    i := 0
    while (i + 4096 <= n && StrCompare(SubStr(a, i + 1, 4096), SubStr(b, i + 1, 4096), "On") = 0)
        i += 4096
    while (i < n && StrCompare(SubStr(a, i + 1, 1), SubStr(b, i + 1, 1), "On") = 0)
        i += 1
    return i
}

; number of equal characters at the end of a and b (not counting the first `start` characters)
CvDiffTail(a, b, start) {
    la := StrLen(a)
    lb := StrLen(b)
    n := Min(la, lb) - start
    i := 0
    while (i + 4096 <= n && StrCompare(SubStr(a, la - i - 4095, 4096), SubStr(b, lb - i - 4095, 4096), "On") = 0)
        i += 4096
    while (i < n && StrCompare(SubStr(a, la - i, 1), SubStr(b, lb - i, 1), "On") = 0)
        i += 1
    return i
}

; Cut / Paste / Delete from the menu: one step each
CvEditCmd(ctl, msg) {
    CvHistFlush(ctl)
    SendMessage(msg, 0, 0, ctl.Hwnd)
    CvHistCommit(ctl)
}

; Height (pixels) of the closed dropdown box, so the buttons can match it.
CvDdHeight() {
    try {
        buf := Buffer(A_PtrSize = 8 ? 64 : 52, 0)
        NumPut("UInt", buf.Size, buf, 0)
        SendMessage(0x164, 0, buf.Ptr, Cv.dd.Hwnd)      ; CB_GETCOMBOBOXINFO
        h := NumGet(buf, 24, "Int") + NumGet(buf, 32, "Int")
        if (h >= 16 && h <= 60)
            return h
    }
    return Round(23 * A_ScreenDPI / 96)
}

; Height of the tab strip (tab view only).
CvTabHeight() {
    d := A_ScreenDPI / 96
    try {
        rc := Buffer(16, 0)
        if SendMessage(0x130A, 0, rc.Ptr, Cv.tab.Hwnd) {     ; TCM_GETITEMRECT
            b := NumGet(rc, 12, "Int")
            if (b >= 10 && b <= 80)
                return b + Round(4 * d)
        }
    }
    return Round(28 * d)
}

; Make the two tab headers share the full width (50% each).
CvTabFit(availW) {
    try {
        rc := Buffer(16, 0)
        if !SendMessage(0x130A, 0, rc.Ptr, Cv.tab.Hwnd)         ; TCM_GETITEMRECT
            return
        ih := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
        iw := (availW - Round(5 * A_ScreenDPI / 96)) // 2
        if (ih > 0 && iw > 20)
            SendMessage(0x1329, 0, (ih << 16) | (iw & 0xFFFF), Cv.tab.Hwnd)   ; TCM_SETITEMSIZE
    }
}

CvSize(gObj, minMax, w, h) {
    if (minMax = -1)
        return
    d := A_ScreenDPI / 96
    m := Round(10 * d)                           ; side margin (toolbar, boxes)
    tm := Round(4 * d)
    gap := Round(3 * d)
    bh := CvDdHeight()
    bw := Round(88 * d)
    ddw := Round(150 * d)
    fdw := Round(140 * d)
    szw := Round(52 * d)
    ; toolbar (static sizes, like a native toolbar): everything is left aligned, Settings is always at the right edge
    x := m
    Cv.b1.Move(x, tm, bw, bh)
    x += bw + gap
    Cv.dd.Move(x, tm, ddw)
    x += ddw + gap
    Cv.b2.Move(x, tm, bw, bh)
    x += bw + gap
    Cv.fd.Move(x, tm, fdw)
    x += fdw + gap
    Cv.sz.Move(x, tm, szw)
    Cv.b4.Move(w - m - bw, tm, bw, bh)
    Cv.b5.Move(w - m - bw - gap - bh, tm, bh, bh)    ; "?" (About), just left of Settings

    ; the two boxes (area between the toolbar and the status bar)
    sbh := Round(22 * d)
    Cv.sb.Move(0, h - sbh, w, sbh)
    top := tm + bh + gap
    availW := w - 2 * m
    availH := h - sbh - top - gap
    if (availW < 100 || availH < 80)
        return
    sg := Round(Cv.sGrip * d)                    ; divider thickness
    mn := Round(60 * d)                          ; smallest box
    Cv.sMin := mn
    Cv.sw := 0
    if (Cv.layout = "V") {                       ; side by side, divider is vertical
        total := availW - sg
        w1 := Min(Max(Round(total * Cv.ratioV), mn), Max(mn, total - mn))
        Cv.uni.Move(m, top, w1, availH)
        Cv.ansi.Move(m + w1 + sg, top, total - w1, availH)
        Cv.sx := m + w1, Cv.sy := top, Cv.sw := sg, Cv.sh := availH
        Cv.sOrigin := m, Cv.sTotal := total
    } else if (Cv.layout = "T") {                ; tabs (no divider)
        th := CvTabHeight()
        Cv.tab.Move(m, top, availW, th)
        CvTabFit(availW)
        th := CvTabHeight()
        Cv.tab.Move(m, top, availW, th)
        Cv.uni.Move(m, top + th, availW, availH - th)
        Cv.ansi.Move(m, top + th, availW, availH - th)
    } else {                                     ; stacked: Unicode on top, ANSI underneath
        total := availH - sg
        h1 := Min(Max(Round(total * Cv.ratioH), mn), Max(mn, total - mn))
        Cv.uni.Move(m, top, availW, h1)
        Cv.ansi.Move(m, top + h1 + sg, availW, total - h1)
        Cv.sx := m, Cv.sy := top + h1, Cv.sw := availW, Cv.sh := sg
        Cv.sOrigin := top, Cv.sTotal := total
    }
}

; ---------------------------------------------------------------------------
;  Draggable divider between the two boxes (stacked and side by side views)
; ---------------------------------------------------------------------------
CvCursorClient(&x, &y) {
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    DllCall("ScreenToClient", "Ptr", Cv.gui.Hwnd, "Ptr", pt)
    x := NumGet(pt, 0, "Int")
    y := NumGet(pt, 4, "Int")
}

CvOnDivider(x, y) {
    if (Cv.sw <= 0)
        return false
    t := Round(2 * A_ScreenDPI / 96)             ; a little slack around the thin bar
    return (x >= Cv.sx - t && x < Cv.sx + Cv.sw + t && y >= Cv.sy - t && y < Cv.sy + Cv.sh + t)
}

CvSetRatio(x, y) {
    pos := (Cv.layout = "V") ? x : y
    half := Cv.sGrip * (A_ScreenDPI / 96) / 2
    first := pos - Cv.sOrigin - half             ; wanted size of the first box
    first := Min(Max(first, Cv.sMin), Max(Cv.sMin, Cv.sTotal - Cv.sMin))
    r := first / Cv.sTotal
    if (Cv.layout = "V")
        Cv.ratioV := r
    else
        Cv.ratioH := r
    CvRelayout()
}

CvWmSetCursor(wParam, lParam, msg, hwnd) {
    if (hwnd != Cv.gui.Hwnd)
        return
    CvCursorClient(&x, &y)
    if (Cv.dragging || (wParam = Cv.gui.Hwnd && CvOnDivider(x, y))) {
        cur := DllCall("LoadCursor", "Ptr", 0, "Ptr", (Cv.layout = "V") ? 32644 : 32645, "Ptr")   ; size WE / NS
        DllCall("SetCursor", "Ptr", cur)
        return 1
    }
}

CvWmLButtonDown(wParam, lParam, msg, hwnd) {
    if (hwnd != Cv.gui.Hwnd)
        return
    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    if !CvOnDivider(x, y)
        return
    now := A_TickCount
    if (now - Cv.lastDown <= DllCall("GetDoubleClickTime", "UInt")) {      ; double click: back to 50/50
        Cv.lastDown := 0
        if (Cv.layout = "V")
            Cv.ratioV := 0.5
        else
            Cv.ratioH := 0.5
        CvRelayout()
        CvSaveSettings()
        return 0
    }
    Cv.lastDown := now
    Cv.dragging := true
    DllCall("SetCapture", "Ptr", Cv.gui.Hwnd)
    return 0
}

CvWmMouseMove(wParam, lParam, msg, hwnd) {
    if (!Cv.dragging || hwnd != Cv.gui.Hwnd)
        return
    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    if (x > 32767)
        x -= 65536
    if (y > 32767)
        y -= 65536
    CvSetRatio(x, y)
    return 0
}

CvWmLButtonUp(wParam, lParam, msg, hwnd) {
    if (!Cv.dragging || hwnd != Cv.gui.Hwnd)
        return
    Cv.dragging := false
    DllCall("ReleaseCapture")
    CvSaveSettings()
    return 0
}

CvStatus(s) {
    Cv.sb.Text := s
}

CvRelayout() {
    try {
        Cv.gui.GetClientPos(, , &w, &h)
        CvSize(Cv.gui, 0, w, h)
    }
}

; Show / hide the boxes and the tab strip for the current layout.
CvApplyLayout() {
    isTab := (Cv.layout = "T")
    Cv.tab.Visible := isTab
    if isTab {
        sel := Cv.tab.Value
        Cv.uni.Visible := (sel = 1)
        Cv.ansi.Visible := (sel = 2)
        CvStatus("  Unicode and ANSI text are in separate tabs.")
    } else {
        Cv.uni.Visible := true
        Cv.ansi.Visible := true
        if (Cv.layout = "V")
            CvStatus("  Left box for Unicode text and right for ANSI. Drag the divider to resize.")
        else
            CvStatus("  Top box for Unicode text and bottom for ANSI. Drag the divider to resize.")
    }
    CvRelayout()
}

CvTabChanged(*) {
    sel := Cv.tab.Value
    Cv.uni.Visible := (sel = 1)
    Cv.ansi.Visible := (sel = 2)
    CvFocusBox()
}

; Put the cursor in a box that is actually visible.
CvFocusBox() {
    try {
        if (Cv.layout = "T" && Cv.tab.Value = 2)
            Cv.ansi.Focus()
        else
            Cv.uni.Focus()
    }
}

; ---------------------------------------------------------------------------
;  Light / dark theme
; ---------------------------------------------------------------------------
CvSysDark() {
    try return (RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") = 0)
    return false
}

CvIsDark() {
    if (Cv.theme = "D")
        return true
    if (Cv.theme = "L")
        return false
    return CvSysDark()
}

CvBGR(hex) {
    r := Integer("0x" . SubStr(hex, 1, 2))
    g := Integer("0x" . SubStr(hex, 3, 2))
    b := Integer("0x" . SubStr(hex, 5, 2))
    return r | (g << 8) | (b << 16)
}

; Ask Windows to draw this process's own popup menus (the right-click menu) dark or light.
CvAppMode(dark) {
    try {
        h := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        f := DllCall("GetProcAddress", "Ptr", h, "Ptr", 135, "Ptr")      ; SetPreferredAppMode
        if f
            DllCall(f, "Int", dark ? 2 : 0)
        f := DllCall("GetProcAddress", "Ptr", h, "Ptr", 136, "Ptr")      ; FlushMenuThemes
        if f
            DllCall(f)
    }
}

CvTitleBar(hwnd, dark) {
    v := dark ? 1 : 0
    try {
        if (DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20, "Int*", v, "Int", 4) != 0)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 19, "Int*", v, "Int", 4)
    }
}

; kind: "btn" (buttons), "cb" (drop-down boxes), "edit" (scroll bars)
CvCtlTheme(ctl, kind, dark) {
    try {
        if !dark {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctl.Hwnd, "Ptr", 0, "Ptr", 0)       ; back to the default look
        } else if (kind = "cb") {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctl.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
        } else {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        }
    }
}

; Editable drop-down boxes: colour the text area and the list, and give the inner
; edit field the dark theme too (otherwise it stays white).
CvComboColors(ctl, dark) {
    CvCtlTheme(ctl, "cb", dark)
    try {
        ctl.Opt("+Background" . (dark ? Cv.ebg : "FFFFFF"))
        ctl.SetFont("s9 c" . (dark ? Cv.efg : "000000"), "Segoe UI")
    }
    try {
        buf := Buffer(A_PtrSize = 8 ? 64 : 52, 0)
        NumPut("UInt", buf.Size, buf, 0)
        SendMessage(0x164, 0, buf.Ptr, ctl.Hwnd)                      ; CB_GETCOMBOBOXINFO
        po := (A_PtrSize = 8) ? 48 : 44
        edit := NumGet(buf, po, "Ptr")
        list := NumGet(buf, po + A_PtrSize, "Ptr")
        for h in [edit, list] {
            if !h
                continue
            if !dark
                DllCall("uxtheme\SetWindowTheme", "Ptr", h, "Ptr", 0, "Ptr", 0)
            else
                DllCall("uxtheme\SetWindowTheme", "Ptr", h, "Str", "DarkMode_CFD", "Ptr", 0)
        }
        DllCall("InvalidateRect", "Ptr", ctl.Hwnd, "Ptr", 0, "Int", 1)
    }
}

CvApplyTheme() {
    dark := CvIsDark()
    Cv.dark := dark
    if dark {
        Cv.bg := "202020", Cv.fg := "E6E6E6", Cv.ebg := "1E1E1E", Cv.efg := "E6E6E6"
        Cv.tabSel := "1E1E1E", Cv.tabIdle := "303030", Cv.tabLine := "555555"
    } else {
        Cv.bg := "F0F0F0", Cv.fg := "000000", Cv.ebg := "FFFFFF", Cv.efg := "000000"
        Cv.tabSel := "FFFFFF", Cv.tabIdle := "E1E1E1", Cv.tabLine := "ACACAC"
    }
    CvAppMode(dark)
    CvTitleBar(Cv.gui.Hwnd, dark)
    Cv.gui.BackColor := Cv.bg
    for c in [Cv.b1, Cv.b2, Cv.b4, Cv.b5]
        CvCtlTheme(c, "btn", dark)
    CvCtlTheme(Cv.dd, "cb", dark)
    CvComboColors(Cv.fd, dark)
    CvComboColors(Cv.sz, dark)
    for c in [Cv.uni, Cv.ansi]
        CvCtlTheme(c, "edit", dark)
    Cv.uni.Opt("+Background" . Cv.ebg)
    Cv.ansi.Opt("+Background" . Cv.ebg)
    Cv.sb.Opt("+Background" . Cv.bg)
    Cv.sb.SetFont("s9 c" . Cv.fg, "Segoe UI")
    CvApplyFonts()
    try DllCall("InvalidateRect", "Ptr", Cv.tab.Hwnd, "Ptr", 0, "Int", 1)
    try DllCall("RedrawWindow", "Ptr", Cv.gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x585)
}

; The tab headers are drawn here so they can follow the theme.
CvWmDrawItem(wParam, lParam, msg, hwnd) {
    off := (A_PtrSize = 8) ? 24 : 20
    ctlH := NumGet(lParam, off, "Ptr")
    if (hwnd = Cv.gui.Hwnd && ctlH = Cv.tab.Hwnd) {
        tabCtl := Cv.tab
        names := Cv.tabNames
    } else if (Cv.sg != "" && hwnd = Cv.sg.Hwnd && Cv.sgTab != "" && ctlH = Cv.sgTab.Hwnd) {
        tabCtl := Cv.sgTab
        names := Cv.sgTabNames
    } else {
        return
    }
    item := NumGet(lParam, 8, "UInt")
    sel := NumGet(lParam, 16, "UInt") & 1
    hdc := NumGet(lParam, off + A_PtrSize, "Ptr")
    rc := lParam + off + 2 * A_PtrSize
    b1 := DllCall("CreateSolidBrush", "UInt", CvBGR(sel ? Cv.tabSel : Cv.tabIdle), "Ptr")
    b2 := DllCall("CreateSolidBrush", "UInt", CvBGR(Cv.tabLine), "Ptr")
    DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", b1)
    DllCall("FrameRect", "Ptr", hdc, "Ptr", rc, "Ptr", b2)
    hf := SendMessage(0x31, 0, 0, tabCtl.Hwnd)               ; WM_GETFONT
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hf, "Ptr")
    DllCall("SetBkMode", "Ptr", hdc, "Int", 1)
    DllCall("SetTextColor", "Ptr", hdc, "UInt", CvBGR(Cv.fg))
    DllCall("DrawText", "Ptr", hdc, "Str", names[item + 1], "Int", -1, "Ptr", rc, "UInt", 0x25)   ; centred
    DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
    DllCall("DeleteObject", "Ptr", b1)
    DllCall("DeleteObject", "Ptr", b2)
    return 1
}

; Windows light/dark switch while "System" is selected.
CvWmSettingChange(wParam, lParam, msg, hwnd) {
    if (hwnd != Cv.gui.Hwnd || Cv.theme != "S" || !lParam)
        return
    try {
        if (StrGet(lParam, "UTF-16") = "ImmersiveColorSet")
            SetTimer(CvApplyTheme, -100)
    }
}

; ---------------------------------------------------------------------------
;  Settings (view layout and preview fonts)
; ---------------------------------------------------------------------------
CvLoadSettings() {
    Cv.encFont.CaseSense := "Off"
    if !FileExist(Cv.ini) {
        for prev in ["text_converter_config.ini", "txc_cfg.dat"] {          ; names used by earlier builds
            if FileExist(A_AppData . "\Bangla Keyboard\" . prev) {
                try FileMove(A_AppData . "\Bangla Keyboard\" . prev, Cv.ini)
                break
            }
        }
    }
    if !FileExist(Cv.ini)
        return
    try {
        Cv.fontA := IniRead(Cv.ini, "Preview", "AnsiFont", Cv.fontA)
        Cv.fontU := IniRead(Cv.ini, "Preview", "UnicodeFont", Cv.fontU)
        a := IniRead(Cv.ini, "Preview", "AnsiSize", Cv.sizeA)
        u := IniRead(Cv.ini, "Preview", "UnicodeSize", Cv.sizeU)
        if IsInteger(a)
            Cv.sizeA := Min(72, Max(6, Integer(a)))
        if IsInteger(u)
            Cv.sizeU := Min(72, Max(6, Integer(u)))
        l := IniRead(Cv.ini, "View", "Layout", Cv.layout)
        if (l = "H" || l = "V" || l = "T")
            Cv.layout := StrUpper(l)
        th := StrUpper(IniRead(Cv.ini, "View", "Theme", Cv.theme))
        if (th = "S" || th = "L" || th = "D")
            Cv.theme := th
        sr := StrUpper(IniRead(Cv.ini, "Encodings", "List", Cv.src))
        if (sr = "T" || sr = "S" || sr = "B")
            Cv.src := sr
        sh := IniRead(Cv.ini, "View", "SplitH", 50)
        sv := IniRead(Cv.ini, "View", "SplitV", 50)
        if IsNumber(sh)
            Cv.ratioH := Min(90, Max(10, Number(sh))) / 100
        if IsNumber(sv)
            Cv.ratioV := Min(90, Max(10, Number(sv))) / 100
    }
    try {                                                ; ANSI preview font chosen for each encoding
        for ln in StrSplit(IniRead(Cv.ini, "EncodingFonts"), "`n", "`r") {
            q := InStr(ln, "=")
            if (q < 2)
                continue
            part := StrSplit(SubStr(ln, q + 1), "|")
            f := Trim(part[1])
            z := (part.Length > 1) ? Trim(part[2]) : ""
            z := IsInteger(z) ? Min(72, Max(6, Integer(z))) : ""
            if (f != "" || z != "")
                Cv.encFont[SubStr(ln, 1, q - 1)] := [f, z]
        }
    }
}

; Settings are kept in %APPDATA%\Bangla Keyboard\Text Converter.dat
CvSaveSettings() {
    try {
        DirCreate(A_AppData . "\Bangla Keyboard")
        IniWrite(Cv.fontA, Cv.ini, "Preview", "AnsiFont")
        IniWrite(Cv.sizeA, Cv.ini, "Preview", "AnsiSize")
        IniWrite(Cv.fontU, Cv.ini, "Preview", "UnicodeFont")
        IniWrite(Cv.sizeU, Cv.ini, "Preview", "UnicodeSize")
        IniWrite(Cv.layout, Cv.ini, "View", "Layout")
        IniWrite(Cv.theme, Cv.ini, "View", "Theme")
        IniWrite(Cv.src, Cv.ini, "Encodings", "List")
        IniWrite(Round(Cv.ratioH * 100), Cv.ini, "View", "SplitH")
        IniWrite(Round(Cv.ratioV * 100), Cv.ini, "View", "SplitV")
        if Cv.encDirty {
            try IniDelete(Cv.ini, "EncodingFonts")
            for k, r in Cv.encFont
                IniWrite(r[1] . "|" . r[2], Cv.ini, "EncodingFonts", k)
            Cv.encDirty := false
        }
    }
}

; Key of an encoding in the per-encoding font list.
CvEncKey(it) {
    SplitPath(it["path"], , , , &nm)
    return (it["kind"] = "lib" ? "Script" : "Table") . "|" . nm
}

; Gives the ANSI preview the font chosen for this encoding in Settings (if any). The toolbar font boxes
; still work afterwards: a font picked there stays until the next encoding is chosen.
; live = false: only set the values (the window does not exist yet).
CvApplyEncFont(it, live := true) {
    k := CvEncKey(it)
    if !Cv.encFont.Has(k)
        return
    r := Cv.encFont[k]
    if (r[1] != "")
        Cv.fontA := r[1]
    if (r[2] != "")
        Cv.sizeA := r[2]
    if !live
        return
    Cv.fd.Text := Cv.fontA
    Cv.sz.Text := Cv.sizeA
    CvApplyFonts()
    CvSaveSettings()
}

CvApplyFonts() {
    Cv.ansi.SetFont("s" . Cv.sizeA . " c" . Cv.efg, Cv.fontA)
    Cv.uni.SetFont("s" . Cv.sizeU . " c" . Cv.efg, Cv.fontU)
    CvRefreshEdit(Cv.ansi)
    CvRefreshEdit(Cv.uni)
}

; SetFont alone leaves an edit box showing the old font until its text changes.
; Hand the font to the box again with the "redraw" flag set, then repaint it.
CvRefreshEdit(ctl) {
    hf := SendMessage(0x31, 0, 0, ctl.Hwnd)               ; WM_GETFONT
    SendMessage(0x30, hf, 1, ctl.Hwnd)                    ; WM_SETFONT, redraw = TRUE
    DllCall("RedrawWindow", "Ptr", ctl.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x505)   ; invalidate + erase + frame + update now
}

; Installed font names, read from the registry (a Map enumerates in sorted order).
CvFontNames() {
    names := Map()
    names.CaseSense := "Off"
    for root in ["HKLM", "HKCU"] {
        try {
            Loop Reg root . "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts", "V" {
                n := RegExReplace(A_LoopRegName, "\s*\([^)]*\)\s*$")
                for part in StrSplit(n, " & ") {
                    part := Trim(part)
                    if (part = "" || RegExMatch(part, "i)\s(Bold|Italic|Oblique)$"))
                        continue
                    names[part] := 1
                }
            }
        }
    }
    names[Cv.fontA] := 1
    names[Cv.fontU] := 1
    list := []
    for k in names {
        list.Push(k)
    }
    return list
}

;  Tooltips (the native Windows tooltip: shows after a short pause, stays while the pointer rests on the control)
; ---------------------------------------------------------------------------
CvEncTip() {
    return "Encoding used for the conversion.`n`n"
        . "Script: custom (scripted) conversion. A .json / .menc file holds a full set of rules (conjuncts, vowel signs, reph, corrections), "
        . "the same rules the keyboard uses when it types. Use it when you want more control over the result.`n`n"
        . "Table: standard (universal) conversion. A .txt / .een file is a plain list of ANSI and Unicode pairs. "
        . "Use it for ordinary, general conversion.`n`n"
        . "What is listed here is chosen in Settings > Encodings in the toolbar list."
}

CvSrcTip() {
    return "Which encodings are listed in the toolbar.`n`n"
        . "Encoding Table: only the standard (universal) tables, from Library\Encoding Table.`n"
        . "Encoding Script: only the custom, rule based scripts, from Library\Encoding Script.`n"
        . "Table Plus Script: both. Each name then starts with Script: or Table: so you can tell them apart."
}

CvMakeTip(owner) {
    tt := DllCall("CreateWindowEx", "UInt", 0x8, "Str", "tooltips_class32", "Ptr", 0, "UInt", 0x80000003
        , "Int", -2147483648, "Int", -2147483648, "Int", -2147483648, "Int", -2147483648
        , "Ptr", owner, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")      ; 0x80000003 = popup, always show, no & handling
    if !tt
        return 0
    SendMessage(0x418, 0, 440, tt)                      ; TTM_SETMAXTIPWIDTH (wraps long lines)
    SendMessage(0x403, 3, 450, tt)                      ; TTM_SETDELAYTIME, initial: 0.45 s
    SendMessage(0x403, 2, 30000, tt)                    ; TTM_SETDELAYTIME, stays: 30 s
    return tt
}

CvAddTip(tt, ctl, text) {
    if !tt
        return
    P := A_PtrSize
    ti := Buffer(24 + 6 * P, 0)                         ; TOOLINFOW
    buf := Buffer((StrLen(text) + 1) * 2, 0)
    StrPut(text, buf, "UTF-16")
    Cv.tipKeep.Push(buf)
    NumPut("UInt", ti.Size, ti, 0)
    NumPut("UInt", 0x11, ti, 4)                         ; TTF_IDISHWND | TTF_SUBCLASS
    NumPut("Ptr", ctl.Gui.Hwnd, ti, 8)
    NumPut("Ptr", ctl.Hwnd, ti, 8 + P)
    NumPut("Ptr", buf.Ptr, ti, 24 + 3 * P)
    SendMessage(0x432, 0, ti.Ptr, tt)                   ; TTM_ADDTOOLW
}

; ---------------------------------------------------------------------------
;  About ("?" button): what the app is, what it offers, how to use and customize it
; ---------------------------------------------------------------------------
CvAbout(*) {
    if (Cv.sg != "")
        return
    ab := Gui("+Owner" . Cv.gui.Hwnd, "About Bangla Text Converter")
    Cv.sg := ab
    ab.SetFont("s9 c" . Cv.fg, "Segoe UI")
    ab.BackColor := Cv.bg
    CvTitleBar(ab.Hwnd, Cv.dark)
    ab.MarginX := 16
    ab.MarginY := 12

    Head(s) {
        ab.SetFont("w700")
        ab.Add("Text", "xm y+12 w420", s)
        ab.SetFont("w400")
    }
    Body(s) {
        ab.Add("Text", "xm y+3 w420", s)
    }

    ab.SetFont("s11 w700")
    ab.Add("Text", "xm w420", "Bangla Text Converter")
    ab.SetFont("s9 w400")
    ab.Add("Text", "xm y+2 w420", "Version 2.3.5  |  Made by Sherlock Holmes")
    Body("Converts Bangla text between Unicode and ANSI (Bijoy-style) encodings, in both directions.")

    Head("Features")
    Body("- Two boxes: Unicode and ANSI, with a live ANSI font preview`n"
       . "- Several encodings (Bijoy V1 / V2, Proshika, Lekhoni, ...) in one list`n"
       . "- Undo / Redo for each box (Ctrl+Z, Ctrl+Y), also after a conversion`n"
       . "- Ctrl + mouse wheel zooms the text; light and dark themes")

    Head("How to use")
    Body("1. Type or paste Unicode text in the Unicode box (or ANSI text in the ANSI box).`n"
       . "2. Choose the encoding, then press To ANSI or To Unicode.`n"
       . "3. Copy the result. Right-click a box for Cut, Copy, Paste, Select All, Clear both, Undo and Redo.`n"
       . "To read ANSI text correctly, set a matching font (e.g. SutonnyMJ) in the font box.")

    Head("Customize (Settings)")
    Body("- Encodings list: Table, Script, or both`n"
       . "- Unicode font and size, and an ANSI font for each encoding`n"
       . "- View: horizontal, vertical or tabs (drag the divider to resize)`n"
       . "- Theme: System, Light or Dark`n"
       . "- Add encodings by putting files in the Library folder: Encoding Table (.txt) or Encoding Script (.json)")

    Done(*) {
        Cv.gui.Opt("-Disabled")
        ab.Destroy()
        Cv.sg := ""
        Cv.gui.Show()
    }
    okBtn := ab.Add("Button", "xm+340 y+16 w80 h28 Default", "Close")
    CvCtlTheme(okBtn, "btn", Cv.dark)
    okBtn.OnEvent("Click", Done)
    ab.OnEvent("Close", Done)
    ab.OnEvent("Escape", Done)

    Cv.gui.Opt("+Disabled")
    ab.Show("AutoSize")
}

; ---------------------------------------------------------------------------
CvSettings(*) {
    if (Cv.sg != "") {
        return
    }
    fonts := Cv.fonts
    sg := Gui("+Owner" . Cv.gui.Hwnd, "Settings")
    Cv.sg := sg
    dk := Cv.dark
    sg.SetFont("s9 c" . Cv.fg, "Segoe UI")
    sg.BackColor := Cv.bg
    CvTitleBar(sg.Hwnd, dk)
    rOpt := dk ? " -Theme" : ""          ; unthemed radio buttons can show light text

    gen := []                            ; controls of the General tab
    fnt := []                            ; controls of the Encoding Fonts tab
    Reg(arr, c) {
        arr.Push(c)
        return c
    }

    ; tab strip (the pages are the two groups of controls below; they are shown / hidden)
    tabC := sg.Add("Tab3", "x12 y8 w416 h28 +0x400 +0x2000", Cv.sgTabNames)
    Cv.sgTab := tabC
    tabC.UseTab()
    CvTabFitCtl(tabC, 416)

    ; ---- General
    Reg(gen, sg.Add("Text", "x12 y52 w416", "Encodings in the toolbar list"))
    cbSrc := Reg(gen, sg.Add("DropDownList", "x12 y72 w330 Choose" . (Cv.src = "T" ? 1 : Cv.src = "S" ? 2 : 3), ["Encoding Table", "Encoding Script", "Table Plus Script"]))
    Reg(gen, sg.Add("Text", "x12 y100 w416 h32", "Table = standard (universal) conversion.`nScript = custom, more controlled (scripted) conversion."))
    CvComboColors(cbSrc, dk)
    stt := CvMakeTip(sg.Hwnd)
    CvAddTip(stt, cbSrc, CvSrcTip())

    Reg(gen, sg.Add("Text", "x12 y144 w416", "Unicode preview font"))
    cbU := Reg(gen, sg.Add("ComboBox", "x12 y164 w230 R12", fonts))
    cbU.Text := Cv.fontU
    Reg(gen, sg.Add("Text", "x254 y167 w30", "Size"))
    cbS := Reg(gen, sg.Add("ComboBox", "x288 y164 w54 R12", Cv.sizes))
    cbS.Text := Cv.sizeU

    Reg(gen, sg.Add("Text", "x12 y204 w416", "View (how the two boxes are split)"))
    r1 := Reg(gen, sg.Add("Radio", "x24 y226 w320" . rOpt, "Horizontal - Unicode on top, ANSI below"))
    r2 := Reg(gen, sg.Add("Radio", "x24 y248 w320" . rOpt, "Vertical - Unicode left, ANSI right"))
    r3 := Reg(gen, sg.Add("Radio", "x24 y270 w320" . rOpt, "Tabs - one tab for Unicode, one for ANSI"))
    if (Cv.layout = "V")
        r2.Value := 1
    else if (Cv.layout = "T")
        r3.Value := 1
    else
        r1.Value := 1

    Reg(gen, sg.Add("Text", "x12 y304 w416", "Theme"))
    t1 := Reg(gen, sg.Add("Radio", "x24 y326 w90 Group" . rOpt, "System"))
    t2 := Reg(gen, sg.Add("Radio", "x120 y326 w90" . rOpt, "Light"))
    t3 := Reg(gen, sg.Add("Radio", "x206 y326 w90" . rOpt, "Dark"))
    if (Cv.theme = "L")
        t2.Value := 1
    else if (Cv.theme = "D")
        t3.Value := 1
    else
        t1.Value := 1

    ; ---- Encoding Fonts: the ANSI preview font that goes with each encoding
    Reg(fnt, sg.Add("Text", "x12 y48 w416 h48", "ANSI preview font for each encoding. It is applied automatically when you switch to that encoding, so the preview font does not have to be changed by hand. The font box in the toolbar can still be used to preview in another font."))
    lv := Reg(fnt, sg.Add("ListView", "x12 y100 w416 h190 -Multi Background" . Cv.ebg . " c" . Cv.efg, ["Encoding", "Type", "Font", "Size"]))
    lv.ModifyCol(1, 150)
    lv.ModifyCol(2, 60)
    lv.ModifyCol(3, 140)
    lv.ModifyCol(4, 45)
    Reg(fnt, sg.Add("Text", "x12 y300 w200", "Font for the selected encoding"))
    cbF := Reg(fnt, sg.Add("ComboBox", "x12 y320 w200 R12", fonts))
    Reg(fnt, sg.Add("Text", "x222 y323 w30", "Size"))
    cbZ := Reg(fnt, sg.Add("ComboBox", "x254 y320 w54 R12", Cv.sizes))
    setBtn := Reg(fnt, sg.Add("Button", "x316 y319 w50 h24", "Set"))
    clrBtn := Reg(fnt, sg.Add("Button", "x372 y319 w56 h24", "Clear"))
    Reg(fnt, sg.Add("Text", "x12 y350 w416 h32", "Select an encoding, choose its font (and size) and press Set. A size left empty keeps the current size. Press OK to save."))

    pend := Map()                         ; the choices being edited (kept only when OK is pressed)
    pend.CaseSense := "Off"
    for k, r in Cv.encFont
        pend[k] := [r[1], r[2]]
    rows := []                            ; the encoding of each list row
    for it in CvFindMaps("B") {           ; every encoding found in the Library folders
        SplitPath(it["path"], , , , &nm)
        rows.Push(it)
        r := pend.Has(CvEncKey(it)) ? pend[CvEncKey(it)] : ["", ""]
        lv.Add(, nm, (it["kind"] = "lib" ? "Script" : "Table"), r[1], r[2])
    }
    if (rows.Length = 0)
        lv.Add(, "(no encoding found in the Library folders)")

    for c in fnt
        c.Visible := false

    okBtn := sg.Add("Button", "x258 y396 w80 h28 Default", "OK")
    caBtn := sg.Add("Button", "x348 y396 w80 h28", "Cancel")
    CvComboColors(cbU, dk)
    CvComboColors(cbS, dk)
    CvComboColors(cbF, dk)
    CvComboColors(cbZ, dk)
    for c in [okBtn, caBtn, setBtn, clrBtn]
        CvCtlTheme(c, "btn", dk)
    CvListTheme(lv, dk)

    ShowTab(*) {
        g := (tabC.Value = 1)
        for c in gen
            c.Visible := g
        for c in fnt
            c.Visible := !g
        if !g {
            cbF.Visible := true
            cbZ.Visible := true
        }
    }
    PickRow(ctl, item, selected) {
        if (!selected || item < 1 || item > rows.Length)
            return
        r := pend.Has(CvEncKey(rows[item])) ? pend[CvEncKey(rows[item])] : ["", ""]
        cbF.Text := r[1]
        cbZ.Text := r[2]
    }
    ShowRow(item) {
        r := pend.Has(CvEncKey(rows[item])) ? pend[CvEncKey(rows[item])] : ["", ""]
        lv.Modify(item, "Col3", r[1], r[2])
    }
    SetFontRow(*) {
        item := lv.GetNext(0)
        if (item < 1 || item > rows.Length) {
            MsgBox("Select an encoding in the list first.", "Settings", 0x40)
            return
        }
        f := Trim(cbF.Text)
        z := Trim(cbZ.Text)
        if (z != "" && (!IsInteger(z) || z < 6 || z > 72)) {
            MsgBox("The size must be a number from 6 to 72.", "Settings", 0x30)
            return
        }
        if (f = "" && z = "")
            return ClearFontRow()
        pend[CvEncKey(rows[item])] := [f, (z = "") ? "" : Integer(z)]
        ShowRow(item)
    }
    ClearFontRow(*) {
        item := lv.GetNext(0)
        if (item < 1 || item > rows.Length)
            return
        k := CvEncKey(rows[item])
        if pend.Has(k)
            pend.Delete(k)
        cbF.Text := ""
        cbZ.Text := ""
        ShowRow(item)
    }
    tabC.OnEvent("Change", ShowTab)
    lv.OnEvent("ItemSelect", PickRow)
    setBtn.OnEvent("Click", SetFontRow)
    clrBtn.OnEvent("Click", ClearFontRow)

    Done(*) {
        Cv.gui.Opt("-Disabled")
        sg.Destroy()
        Cv.sg := ""
        Cv.sgTab := ""
        Cv.gui.Show()
    }
    Ok(*) {
        fu := Trim(cbU.Text)
        if (fu != "")
            Cv.fontU := fu
        sv := Trim(cbS.Text)
        if IsInteger(sv)
            Cv.sizeU := Min(72, Max(6, Integer(sv)))
        newSrc := (cbSrc.Value = 1) ? "T" : (cbSrc.Value = 2) ? "S" : "B"
        srcChanged := (newSrc != Cv.src)
        newL := r2.Value ? "V" : (r3.Value ? "T" : "H")
        layoutChanged := (newL != Cv.layout)
        Cv.layout := newL
        newT := t2.Value ? "L" : (t3.Value ? "D" : "S")
        themeChanged := (newT != Cv.theme)
        Cv.theme := newT
        Cv.encFont := pend
        Cv.encDirty := true
        CvApplyEncFont(Cv.files[Cv.cur])           ; the encoding in use takes its font now
        CvApplyFonts()
        CvSaveSettings()
        Done()
        if srcChanged
            CvSetSource(newSrc)
        if themeChanged
            CvApplyTheme()
        if layoutChanged
            CvApplyLayout()
    }
    okBtn.OnEvent("Click", Ok)
    caBtn.OnEvent("Click", Done)
    sg.OnEvent("Close", Done)
    sg.OnEvent("Escape", Done)

    Cv.gui.Opt("+Disabled")
    sg.Show("w440 h438")
}

; Tab headers share the full width (50% each) - the same as CvTabFit does for the main window.
CvTabFitCtl(tabCtl, availW) {
    try {
        rc := Buffer(16, 0)
        if !SendMessage(0x130A, 0, rc.Ptr, tabCtl.Hwnd)         ; TCM_GETITEMRECT
            return
        ih := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
        iw := (availW - Round(5 * A_ScreenDPI / 96)) // 2
        if (ih > 0 && iw > 20)
            SendMessage(0x1329, 0, (ih << 16) | (iw & 0xFFFF), tabCtl.Hwnd)   ; TCM_SETITEMSIZE
    }
}

; Dark / light look for a list view (the list and its column headers).
CvListTheme(lv, dark) {
    try {
        hdr := SendMessage(0x101F, 0, 0, lv.Hwnd)               ; LVM_GETHEADER
        for h in [lv.Hwnd, hdr] {
            if !h
                continue
            if dark
                DllCall("uxtheme\SetWindowTheme", "Ptr", h, "Str", "DarkMode_ItemsView", "Ptr", 0)
            else
                DllCall("uxtheme\SetWindowTheme", "Ptr", h, "Ptr", 0, "Ptr", 0)
        }
    }
}

; ---------------------------------------------------------------------------
;  Right-click menu for the two boxes: only the basic edit commands.
;  (Replaces the Windows menu with its reading-order / Unicode-control / IME items.)
; ---------------------------------------------------------------------------
CvEditMenu(wParam, lParam, *) {
    if (wParam != Cv.uni.Hwnd && wParam != Cv.ansi.Hwnd)
        return
    ctl := (wParam = Cv.uni.Hwnd) ? Cv.uni : Cv.ansi
    ; Read the selection BEFORE focusing: Focus() makes a text box select all of its text,
    ; which would turn a partial selection into a whole-document one.
    s := Buffer(4, 0)
    e := Buffer(4, 0)
    SendMessage(0xB0, s.Ptr, e.Ptr, ctl.Hwnd)           ; EM_GETSEL
    selS := NumGet(s, 0, "UInt")
    selE := NumGet(e, 0, "UInt")
    if (DllCall("GetFocus", "Ptr") != ctl.Hwnd) {
        ctl.Focus()
        SendMessage(0xB1, selS, selE, ctl.Hwnd)         ; EM_SETSEL: put the original selection back
    }
    hasSel := selE > selS
    hasText := StrLen(ctl.Value) > 0
    canPaste := DllCall("IsClipboardFormatAvailable", "UInt", 13)
    CvHistFlush(ctl)
    hm := Cv.h[ctl.Hwnd]
    canUndo := hm["p"] > 1
    canRedo := hm["p"] < hm["s"].Length
    anyText := (StrLen(Cv.uni.Value) > 0 || StrLen(Cv.ansi.Value) > 0)
    mU := "Undo`tCtrl+Z"
    mR := "Redo`tCtrl+Y"

    m := Menu()
    m.Add("Cut", (*) => CvEditCmd(ctl, 0x300))
    m.Add("Copy", (*) => SendMessage(0x301, 0, 0, ctl.Hwnd))
    m.Add("Paste", (*) => CvEditCmd(ctl, 0x302))
    m.Add("Delete", (*) => CvEditCmd(ctl, 0x303))
    m.Add()
    m.Add("Select All", (*) => SendMessage(0xB1, 0, -1, ctl.Hwnd))
    m.Add()
    m.Add("Clear both", (*) => CvClear())
    m.Add()
    m.Add(mU, (*) => CvHistStep(ctl, -1))
    m.Add(mR, (*) => CvHistStep(ctl, 1))
    if !canUndo
        m.Disable(mU)
    if !canRedo
        m.Disable(mR)
    if !anyText
        m.Disable("Clear both")
    if !hasSel {
        m.Disable("Cut")
        m.Disable("Copy")
        m.Disable("Delete")
    }
    if !canPaste
        m.Disable("Paste")
    if !hasText
        m.Disable("Select All")
    if ((lParam & 0xFFFFFFFF) = 0xFFFFFFFF) {           ; opened from the keyboard
        ctl.GetPos(&cx, &cy)
        m.Show(cx + 10, cy + 10)
    } else {
        m.Show()
    }
    return 0
}

; A text box handles WM_CONTEXTMENU itself, so the parent window never sees it.
; Subclass the two boxes to catch it and show our own menu instead of the Windows one.
CvSubclass(ctl) {
    if !Cv.subCb
        Cv.subCb := CallbackCreate(CvSubProc, , 6)
    DllCall("comctl32\SetWindowSubclass", "Ptr", ctl.Hwnd, "Ptr", Cv.subCb, "UPtr", 1, "UPtr", 0)
}

CvSubProc(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
    if (uMsg = 0x7B) {                                   ; WM_CONTEXTMENU
        SetTimer(CvEditMenu.Bind(hWnd, lParam), -1)
        return 0
    }
    if (uMsg = 0x100 && (wParam = 0x5A || wParam = 0x59) && GetKeyState("Ctrl") && !GetKeyState("Alt")) {   ; Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z
        ctl := (hWnd = Cv.ansi.Hwnd) ? Cv.ansi : Cv.uni
        CvHistStep(ctl, (wParam = 0x59 || GetKeyState("Shift")) ? 1 : -1)
        return 0
    }
    if (uMsg = 0x102 && (wParam = 0x1A || wParam = 0x19))   ; the matching WM_CHAR: keeps the box's own one-step undo out of it
        return 0
    if (uMsg = 0x20A && (wParam & 0x8)) {                ; WM_MOUSEWHEEL with Ctrl held: zoom the text
        d := (wParam >> 16) & 0xFFFF                     ; wheel delta (signed 16 bit, 120 per notch)
        if (d >= 0x8000)
            d -= 0x10000
        CvZoomWheel(hWnd, d)
        return 0
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "UPtr", wParam, "Ptr", lParam, "Ptr")
}

; Ctrl + mouse wheel over a box: zoom its text. Wheel up = bigger, wheel down = smaller (6 - 72 pt, 1 pt per notch).
; The box under the pointer is the one that changes. Each box keeps its own size; the toolbar size box follows the ANSI one.
CvZoomWheel(hWnd, delta) {
    try {
        MouseGetPos(, , , &under, 2)                     ; control under the pointer (HWND)
        if (under = Cv.uni.Hwnd || under = Cv.ansi.Hwnd)
            hWnd := under
    }
    Cv.wheel += delta
    steps := Integer(Cv.wheel / 120)                     ; whole notches (finer wheels add up until they make one)
    if (steps = 0)
        return
    Cv.wheel -= steps * 120
    isAnsi := (hWnd = Cv.ansi.Hwnd)
    cur := isAnsi ? Cv.sizeA : Cv.sizeU
    nw := Min(72, Max(6, cur + steps))
    if (nw = cur)
        return
    if isAnsi {
        Cv.sizeA := nw
        try Cv.sz.Text := nw
    } else {
        Cv.sizeU := nw
    }
    CvApplyFonts()
    SetTimer(CvSaveSettings, -500)                       ; save once the wheel stops
}

; The toolbar list. Cv.src decides what is in it: T = the tables of Library\Encoding Table (*.txt / *.een; the .txt wins
; when both exist), S = the scripts of Library\Encoding Script (*.json / *.menc; the .menc wins when both exist),
; B = scripts first, then tables, each name starting with "Script: " or "Table: ".
CvAppDir() {
    SplitPath(A_ScriptDir, &nm, &par)
    return (nm = "Tools") ? par : A_ScriptDir
}

CvFindMaps(src) {
    list := []
    tagged := (src = "B")
    if (src = "S" || src = "B") {
        found := Map()
        found.CaseSense := "Off"
        for ext in ["json", "menc"] {
            Loop Files, CvAppDir() . "\Library\Encoding Script\*." . ext {
                if (StrLower(A_LoopFileExt) != ext)             ; the pattern can also match longer extensions
                    continue
                SplitPath(A_LoopFileFullPath, , , , &nm)
                found[nm] := A_LoopFileFullPath                 ; the .menc comes second and replaces the .json
            }
        }
        for nm in EncRev.SortedKeys(found)
            list.Push(Map("kind", "lib", "path", found[nm], "name", (tagged ? "Script: " : "") . nm))
    }
    if (src = "T" || src = "B") {
        seen := Map()
        seen.CaseSense := "Off"
        for ext in ["txt", "een"] {
            Loop Files, CvAppDir() . "\Library\Encoding Table\*." . ext {
                SplitPath(A_LoopFileFullPath, , , &e, &nm)
                if (StrLower(e) != ext || seen.Has(nm))
                    continue
                seen[nm] := 1
                list.Push(Map("kind", "txt", "path", A_LoopFileFullPath, "name", (tagged ? "Table: " : "") . nm))
            }
        }
    }
    return list
}

; Changes what the toolbar list shows (Settings > Encodings in the toolbar list). The encoding in use stays when it is
; still listed; otherwise the first one that can be read is loaded. Returns false (nothing changes) when the choice has no files.
CvSetSource(src) {
    files := CvFindMaps(src)
    if (files.Length = 0) {
        where := (src = "T") ? "Library\Encoding Table (.txt / .een)" : (src = "S") ? "Library\Encoding Script (.json / .menc)" : "Library\Encoding Script or Library\Encoding Table"
        MsgBox("No encoding found for this choice.`nPut files in " . where . ".", "Bangla Text Converter", 0x10)
        return false
    }
    oldPath := (Cv.cur >= 1 && Cv.cur <= Cv.files.Length) ? Cv.files[Cv.cur]["path"] : ""
    pick := 0
    switched := false
    for idx, it in files {
        if (it["path"] = oldPath) {
            pick := idx
            break
        }
    }
    if (pick = 0) {                                       ; the one in use is not in the new list: load the first readable one
        for idx, it in files {
            try {
                CvLoadItem(it)
                pick := idx
                switched := true
                break
            } catch as e {
                MsgBox("Could not read the encoding:`n" . it["path"] . "`n`n" . e.Message, "Bangla Text Converter", 0x10)
            }
        }
        if (pick = 0)
            return false
    }
    names := []
    for it in files
        names.Push(it["name"])
    Cv.src := src
    Cv.files := files
    Cv.cur := pick
    Cv.dd.Delete()
    Cv.dd.Add(names)
    Cv.dd.Choose(pick)
    if switched
        CvApplyEncFont(files[pick])
    CvTitle()
    CvSaveSettings()
    return true
}

CvStart() {
    CvLoadSettings()
    Cv.files := CvFindMaps(Cv.src)
    if (Cv.files.Length = 0 && Cv.src != "B") {            ; the saved choice has no files: show everything
        Cv.src := "B"
        Cv.files := CvFindMaps("B")
    }
    if (Cv.files.Length = 0) {
        MsgBox("No encoding found.`nPut an encoding script (.json or .menc) in Library\Encoding Script`nor a table (.txt or .een) in Library\Encoding Table.", "Bangla Text Converter", 0x10)
        ExitApp()
    }
    names := []
    for it in Cv.files
        names.Push(it["name"])
    first := 0
    for idx, it in Cv.files {                           ; the first one that can be read
        try {
            CvLoadItem(it)
            first := idx
            break
        } catch as e {
            MsgBox("Could not read the encoding:`n" . it["path"] . "`n`n" . e.Message, "Bangla Text Converter", 0x10)
        }
    }
    if (first = 0)
        ExitApp()
    Cv.cur := first
    CvApplyEncFont(Cv.files[first], false)
    Cv.fonts := CvFontNames()

    g := Gui("+Resize +MinSize760x440 +0x2000000", "Bangla Text Converter")   ; 0x2000000 = clip children (less flicker)
    Cv.gui := g
    g.SetFont("s9", "Segoe UI")

    ; toolbar (positions are set in CvSize)
    Cv.b1 := g.Add("Button", "x12 y12 w104 h24", "To ANSI")
    Cv.dd := g.Add("DropDownList", "x124 y12 w170", names)
    Cv.b2 := g.Add("Button", "x302 y12 w104 h24", "To Unicode")
    Cv.dd.Choose(first)
    Cv.tip := CvMakeTip(g.Hwnd)
    CvAddTip(Cv.tip, Cv.dd, CvEncTip())
    Cv.fd := g.Add("ComboBox", "x414 y12 w140 R15", Cv.fonts)
    Cv.fd.Text := Cv.fontA
    Cv.sz := g.Add("ComboBox", "x560 y12 w52 R15", Cv.sizes)
    Cv.sz.Text := Cv.sizeA
    Cv.b4 := g.Add("Button", "x710 y12 w88 h24", "Settings")
    Cv.b5 := g.Add("Button", "x676 y12 w24 h24", "?")
    Cv.b1.OnEvent("Click", CvToAnsi)
    Cv.b2.OnEvent("Click", CvToUnicode)
    Cv.dd.OnEvent("Change", CvMappingChanged)
    Cv.b4.OnEvent("Click", CvSettings)
    Cv.b5.OnEvent("Click", CvAbout)
    Cv.fd.OnEvent("Change", CvToolFont)
    Cv.fd.OnEvent("LoseFocus", CvToolFontDone)
    Cv.sz.OnEvent("Change", CvToolSize)

    ; tab strip (only shown in the tab view; sized in CvSize)
    Cv.tab := g.Add("Tab3", "x12 y50 w300 h28 +0x400 +0x2000", Cv.tabNames)      ; 0x400 = fixed-width tabs, 0x2000 = we draw the tab headers (for dark mode)
    Cv.tab.OnEvent("Change", CvTabChanged)
    Cv.tab.UseTab()          ; controls added after this are NOT children of the tab

    ; Unicode and ANSI boxes (placed according to the chosen layout in CvSize)
    Cv.uni := g.Add("Edit", "x12 y50 w300 h200 Multi +VScroll Limit1000000")
    Cv.ansi := g.Add("Edit", "x12 y262 w300 h200 Multi +VScroll Limit1000000")
    Cv.sb := g.Add("Text", "x0 y430 w700 h22 +0x200", "")      ; 0x200 = centre text vertically
    CvHistInit(Cv.uni)
    CvHistInit(Cv.ansi)
    CvApplyTheme()
    CvApplyLayout()

    CvSubclass(Cv.uni)
    CvSubclass(Cv.ansi)
    g.OnEvent("Size", CvSize)
    OnMessage(0x2B, CvWmDrawItem)        ; WM_DRAWITEM (tab headers)
    OnMessage(0x1A, CvWmSettingChange)   ; WM_SETTINGCHANGE (Windows theme switch)
    OnMessage(0x20, CvWmSetCursor)       ; WM_SETCURSOR
    OnMessage(0x201, CvWmLButtonDown)    ; WM_LBUTTONDOWN
    OnMessage(0x200, CvWmMouseMove)      ; WM_MOUSEMOVE
    OnMessage(0x202, CvWmLButtonUp)      ; WM_LBUTTONUP
    g.OnEvent("Close", (*) => ExitApp())
    g.Show("w780 h520")
    CvTitle()
}

CvStart()

; Hands the memory the program does not need back to Windows (only idle pages; they return when used)
TrimMemory() {
    DllCall("psapi\EmptyWorkingSet", "Ptr", DllCall("kernel32\GetCurrentProcess", "Ptr"))
}
