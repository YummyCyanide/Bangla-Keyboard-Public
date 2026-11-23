; ===========================================================================
;  Bangla Document Converter  (test build)
;  Opens a document; after you tick what to scan (font, size, style, colour ...) and press Scan,
;  lists every combination used in it, and lets you convert chosen
;  fonts between ANSI (Bijoy, Proshika, ...) and Unicode, or from one ANSI
;  encoding to another, and change the font and size.
;  Word  : .docx .docm .dotx .dotm   (and .doc .dot .rtf .odt .wps, which are first
;          converted to .docx through Microsoft Word or LibreOffice)
;  PowerPoint: .pptx .pptm .potx .potm .ppsx .ppsm   (and .ppt .pot .pps .odp, first converted to
;          .pptx through Microsoft PowerPoint or LibreOffice)
;  Everything with text is read: body text, tables, text boxes / shapes / groups, headers,
;  footers, footnotes, comments, SmartArt and chart text (slides + notes in PowerPoint).
;  Text  : .txt (encoding conversion only, a text file has no fonts)
;  The original file is never changed: the result is saved as a new file, in the same format as
;  the file that was opened (.docx stays .docx, .pptx stays .pptx, .doc stays .doc ...).
;  Only the window size and the last folders are kept in %AppData%\Bangla Keyboard\Docs Converter.dat
;  Every newly opened document starts completely fresh (scan options, plan, filters, sort, preview size).
;  Needs AutoHotkey v2 and Windows PowerShell (built into Windows 10/11).
;  The conversion rules come from the Library folder (.json, or the locked .menc): the same encodings the keyboard
;  uses for Multi Encoding and the Bangla Text Converter uses. Every encoding is listed with a tag:
;  "Script: name" (Library\Encoding Script, .json / .menc: custom, rule based conversion) and "Table: name"
;  (Library\Encoding Table, .txt / .een: standard, universal conversion).
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon                       ; taskbar only, no icon in the system tray
SetWorkingDir A_ScriptDir
ProcessSetPriority("Normal")       ; normal priority: big files never slow down typing in other programs
ListLines(false)                  ; no line history: the script runs noticeably faster
SetTimer(TrimMemory, -3000)         ; once, shortly after start: hand unused memory back to Windows

class K {
    static ek := "BanglaConverter"     ; scramble key of the .een files
    static HAS := Chr(0x09CD)
    static ZWNJ := Chr(0x200C)
    static ZWJ := Chr(0x200D)
    static VI := Chr(0x09BF)
    static VE := Chr(0x09C7)
    static VAI := Chr(0x09C8)
    static AA := Chr(0x09BE)
    static AU := Chr(0x09D7)
    static O := Chr(0x09CB)
    static AUU := Chr(0x09CC)
    static RA := Chr(0x09B0)
    static REPH := Chr(0x09B0) . Chr(0x09CD)
    static SIGNS := Chr(0x09BE) . Chr(0x09BF) . Chr(0x09C0) . Chr(0x09C1) . Chr(0x09C2) . Chr(0x09C3) . Chr(0x09C7) . Chr(0x09C8) . Chr(0x09D7) . Chr(0x0981) . Chr(0x0982) . Chr(0x0983)
}

; ---------------------------------------------------------------------------
;  Mapping table (one object per mapping file)
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
    kl := StrLen(K.ek)
    Loop n {
        i := A_Index - 1
        e := NumGet(buf, 8 + i, "UChar")
        d := ((e - (i * 31 + 17)) & 0xFF) ^ Ord(SubStr(K.ek, Mod(i, kl) + 1, 1))
        NumPut("UChar", d, out, i)
    }
    return StrGet(out, n, "UTF-8")
}

class Mapping {
    __New(path) {
        SplitPath(path, , , &ext, &nm)
        this.name := nm
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
        ; Bijoy prefers these two glyphs; only apply when the table really uses them that way
        ; (in Proshika / Adarsha the same characters mean something else)
        if (fw.Get(Chr(0x02C6), "") == K.VAI)
            rv[K.VAI] := Chr(0x02C6)
        if (fw.Get(Chr(0x00D6), "") == K.HAS . K.RA)
            rv[K.HAS . K.RA] := Chr(0x00D6)
        ; for every first character: the longest key that starts with it (makes Tokenize much faster)
        fs := Map()
        fs.CaseSense := "On"
        for key in fw {
            c1 := SubStr(key, 1, 1)
            if (StrLen(key) > fs.Get(c1, 0))
                fs[c1] := StrLen(key)
        }
        rs := Map()
        rs.CaseSense := "On"
        for key in rv {
            c1 := SubStr(key, 1, 1)
            if (StrLen(key) > rs.Get(c1, 0))
                rs[c1] := StrLen(key)
        }
        this.fwStart := fs
        this.rvStart := rs
        this.fw := fw
        this.rv := rv
        this.fwMax := fmax
        this.rvMax := rmax
        this.rephAnsi := rv.Get(K.REPH, "")
    }
}

; ---------------------------------------------------------------------------
;  Library encodings (the code of Bangla Keyboard.ahk: EncJson, MencDecode, EncLib; EncRev is the way back)
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
        this.sm := Map()               ; first character -> length of the longest Unicode key that starts with it
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
        ; speed: a text is only compared as long as a key starting with its first character can be
        sm := Map()
        sm.CaseSense := "On"
        for k in L.uni {
            c1 := SubStr(k, 1, 1)
            if (StrLen(k) > sm.Get(c1, 0))
                sm[c1] := StrLen(k)
        }
        if (L.rfola.Length > 0 || L.zfola != "")                ; ্র and ্য are cut out of the text as two characters
            sm[EncLib.HAS] := Max(sm.Get(EncLib.HAS, 0), 2)
        L.sm := sm
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
            L := Min(this.sm.Get(SubStr(t, i, 1), 1), n - i + 1)
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
            L := Min(this.sm.Get(c, 1), n - i + 1)
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
        this.start := Map()              ; first character -> length of the longest ANSI key that starts with it (speed)
        this.start.CaseSense := "On"
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
        for a in this.map {
            c1 := SubStr(a, 1, 1)
            if (StrLen(a) > this.start.Get(c1, 0))
                this.start[c1] := StrLen(a)
        }
    }

    ; longest match first; text that is not in the table (spaces, punctuation, English ...) stays as it is
    Tokens(t) {
        toks := []
        n := StrLen(t)
        i := 1
        while (i <= n) {
            hit := false
            k := Min(this.start.Get(SubStr(t, i, 1), 0), n - i + 1)
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

; one encoding of the Library folder, ready to convert both ways (a Mapping object is the same for an old table)
class LibMap {
    __New(path) {
        this.lib := EncLib.Load(path)       ; Unicode -> ANSI
        this.rev := EncRev(this.lib)        ; ANSI -> Unicode, the same rules turned around
        this.name := this.lib.name
    }
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
    return (ch == K.ZWNJ || ch == K.ZWJ)
}

; Longest-match split of s using map m. Returns an array of converted pieces.
; Characters that are not in the table are passed through unchanged.
Tokenize(s, m, startMax, skipKey := "") {
    toks := []
    n := StrLen(s)
    i := 1
    while (i <= n) {
        c := SubStr(s, i, 1)
        L := startMax.Get(c, 0)                       ; longest key that starts with this character
        if (L > n - i + 1)
            L := n - i + 1
        hit := false
        while (L >= 1) {
            key := (L = 1) ? c : SubStr(s, i, L)
            if (m.Has(key) && !(skipKey != "" && key == skipKey)) {
                toks.Push(m[key])
                i += L
                hit := true
                break
            }
            L -= 1
        }
        if !hit {
            toks.Push(c)
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

MapUni(M, x) {
    return JoinTokens(Tokenize(x, M.rv, M.rvStart, K.REPH))
}

; ---------------------------------------------------------------------------
;  ANSI (Bijoy) -> Unicode
;  In ANSI the vowel signs i/e/oi come BEFORE the consonant group and the reph
;  comes AFTER it; Unicode wants the opposite, so the pieces are re-ordered.
; ---------------------------------------------------------------------------
AnsiToUni(M, s) {
    toks := Tokenize(s, M.fw, M.fwStart)
    n := toks.Length
    out := ""
    i := 1
    while (i <= n) {
        t := toks[i]
        pre := ""
        if (t == K.VI || t == K.VE || t == K.VAI) {
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
                if (SubStr(cl, -1) == K.HAS && u != K.REPH && IsConsTok(u)) {
                    cl .= u                      ; previous glyph ended in a hasanta: the next consonant belongs to it
                    i += 1
                } else if (u == K.HAS) {
                    if (i < n && IsConsTok(toks[i + 1])) {
                        cl .= u . toks[i + 1]
                        i += 2
                    } else {
                        break
                    }
                } else if (SubStr(u, 1, 1) == K.HAS) {
                    cl .= u
                    i += 1
                } else {
                    break
                }
            }
            res := cl
            if (i <= n && toks[i] == K.REPH) {
                res := K.REPH . cl
                i += 1
            }
            if (pre == K.VE) {
                if (i <= n && toks[i] == K.AA) {
                    res .= K.O
                    i += 1
                } else if (i <= n && toks[i] == K.AU) {
                    res .= K.AUU
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
UniToAnsi(M, s) {
    s := StrReplace(s, K.O, K.VE . K.AA)
    s := StrReplace(s, K.AUU, K.VE . K.AU)
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
        if (c == K.RA && j + 2 <= n && SubStr(s, j + 1, 1) == K.HAS && IsConsTok(SubStr(s, j + 2, 1))) {
            reph := true
            j += 2
        }
        if IsConsTok(SubStr(s, j, 1)) {
            kx := j + 1
            while true {
                mx := kx
                if (mx <= n && IsZW(SubStr(s, mx, 1)))
                    mx += 1
                if (mx + 1 <= n && SubStr(s, mx, 1) == K.HAS && IsConsTok(SubStr(s, mx + 1, 1))) {
                    kx := mx + 2
                } else {
                    break
                }
            }
            chain := SubStr(s, j, kx - j)
            pre := ""
            post := ""
            while (kx <= n) {
                ch := SubStr(s, kx, 1)
                if !InStr(K.SIGNS, ch, true)
                    break
                if (pre = "" && (ch == K.VI || ch == K.VE || ch == K.VAI)) {
                    pre := ch
                } else {
                    post .= ch
                }
                kx += 1
            }
            a := ""
            if (pre != "")
                a := M.rv.Get(pre, pre)
            if reph {
                a .= MapUni(M, chain) . M.rephAnsi . MapUni(M, post)
            } else {
                a .= MapUni(M, chain . post)
            }
            out .= a
            i := kx
        } else {
            out .= MapUni(M, c)
            i += 1
        }
    }
    return out
}


; ===========================================================================
;  Document handling (.docx = zip of XML files)
; ===========================================================================
; Where the runs of a Word paragraph can be: directly, or inside a link, tracked change,
; field, content control, smart tag ... (runs of a text box inside a run belong to the
; paragraph of that text box, which is processed on its own).
global CfRunXPath := "w:r | w:hyperlink/w:r | w:ins/w:r | w:moveTo/w:r | w:smartTag/w:r | w:fldSimple/w:r"
    . " | w:customXml/w:r | w:dir/w:r | w:bdo/w:r | w:sdt/w:sdtContent/w:r"
    . " | w:ins/w:hyperlink/w:r | w:ins/w:fldSimple/w:r | w:hyperlink/w:ins/w:r | w:hyperlink/w:smartTag/w:r"
    . " | w:smartTag/w:hyperlink/w:r | w:sdt/w:sdtContent/w:hyperlink/w:r | w:sdt/w:sdtContent/w:ins/w:r"
    . " | w:sdt/w:sdtContent/w:fldSimple/w:r | w:sdt/w:sdtContent/w:sdt/w:sdtContent/w:r"

; What can be scanned: [id, column heading, tick-box label]. The ticked ones make up the list: one row for every
; different combination of them (a row = one "look" of the text), and the conversion is chosen for each row.
global CfDims := [["font", "Font", "Font"], ["size", "Size", "Size"], ["style", "Style", "Style"], ["ul", "Underline", "Underline"]
    , ["strike", "Strikethrough", "Strikethrough"], ["hl", "Highlight", "Highlight"], ["lang", "Language", "Language"], ["color", "Colour", "Colour"], ["spc", "Spacing", "Spacing"]]

class Cf {
    static NS := "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    ; element order inside <w:rPr>; new elements are inserted in this order so Word accepts the file
    static order := ["rStyle", "rFonts", "b", "bCs", "i", "iCs", "caps", "smallCaps", "strike", "dstrike", "outline", "shadow", "emboss", "imprint", "noProof", "snapToGrid", "vanish", "webHidden", "color", "spacing", "w", "kern", "position", "sz", "szCs", "highlight", "u", "effect", "bdr", "shd", "fitText", "vertAlign", "rtl", "cs", "em", "lang", "eastAsianLayout", "specVanish", "oMath"]
    static mapFiles := []
    static mapNames := []
    static mapCache := Map()
    static file := ""
    static work := ""
    static fonts := Map()
    static rules := Map()
    static styleRaw := Map()
    static styleCache := Map()
    static defProps := Map()
    static defPara := ""
    static theme := Map()
    static nRuns := 0
    static nChars := 0
    static dirty := false
    static tick := 0
    static psExtract := ""
    static psZip := ""
    static curName := ""
    static curRow := 0
    static busyUI := false
    static gui := ""
    static btnOpen := "", btnRemove := "", edFile := "", lv := ""
    static hdAct := "", hdEnc := "", hdFont := "", hdSize := "", sep1 := "", sep2 := "", sep3 := "", sep4 := ""
    static tab := "", edPrev := "", edHelp := "", split := ""
    static edFind := "", ddType := "", lblMin := "", edMin := "", lblCount := ""
    static prevKey := "", paraSeq := 0, cw := 0, ch := 0, tabH := 0, sortCol := "chars", sortDesc := true
    static typeNames := ["All types", "Bangla Unicode", "ANSI / Latin text", "Mixed"]
    static scanOpt := Map(), scanIds := ["font", "size"], scanned := false, cbScan := Map()
    static colIds := [], byIds := ["any"], rowKeys := []
    static hdScan := "", btnScan := "", btnScanAll := "", btnScanNone := "", sepS := "", ddBy := ""
    static ddVal := "", btnClearF := "", colFilter := Map(), valKeys := [], fq := ""
    static lbl2 := "", lbl5 := "", lbl6 := "", btnApplyAll := "", btnApplySel := ""
    static queue := [], clip := "", busySel := false, progPre := ""
    static ddAct := "", ddMethod := "", ddMap := "", ddMap2 := "", cbFont := "", ddSize := "", edSize := ""
    static mapView := [], viewMethod := 0, methodUsable := false, defMethod := 0
    static btnConv := "", edLog := "", sb := ""
    static hdFile := "", sep0 := "", sep5 := "", hdPrev := "", btnPrevDn := "", btnPrevUp := "", lblPrevSz := "", btnPrevReset := ""
    static tabUser := false, prevSize := 11, prevFont := "Segoe UI"
    static lastOpenDir := "", lastSaveDir := "", defMap := 1, defMap2 := 1, winW := 900, winH := 570
    static partKeys := Map(), curKeys := Map(), prevPending := ""
    static kind := "", outExt := "docx", tmpDoc := "", txtText := "", txtEnc := "", dml := false
    static effCache := Map(), baseCache := Map(), paraKeys := Map(), memo := Map()
    static colW := Map()
    static pBase := 0, pSpan := 1, phLo := 0, phHi := 100, convT0 := 0, lastPct := -1, lastTxt := ""
    static pb := "", edMax := "", lblMax := ""
    static NSA := "http://schemas.openxmlformats.org/drawingml/2006/main"
    ; element order inside a DrawingML <a:rPr>
    static orderA := ["ln", "noFill", "solidFill", "gradFill", "blipFill", "pattFill", "grpFill", "effectLst", "effectDag", "highlight", "uLnTx", "uLn", "uFillTx", "uFill", "latin", "ea", "cs", "sym", "hlinkClick", "hlinkMouseOver", "rtl", "extLst"]
}

; ---------------------------------------------------------------------------
;  Small XML helpers (MSXML through COM)
; ---------------------------------------------------------------------------
CfLoadXml(path) {
    d := ComObject("MSXML2.DOMDocument.6.0")
    d.async := false
    d.preserveWhiteSpace := true
    d.validateOnParse := false
    d.resolveExternals := false
    d.setProperty("SelectionLanguage", "XPath")
    d.setProperty("SelectionNamespaces", 'xmlns:w="' . Cf.NS . '" xmlns:a="' . Cf.NSA . '"')
    if !d.load(path)
        throw Error("Could not read " . path . "`n" . d.parseError.reason)
    return d
}

; First node matching an XPath, or "" if there is none.
CfNode(n, xp) {
    if !IsObject(n)
        return ""
    try {
        r := n.selectSingleNode(xp)
        if (Type(r) = "ComObject") {
            nm := r.nodeName
            return r
        }
    }
    return ""
}

CfAttr(n, name) {
    if !IsObject(n)
        return ""
    try
        v := n.getAttribute(name)
    catch
        return ""
    return (Type(v) = "String") ? v : ""
}

CfMerge(dst, src) {
    for kk, v in src
        dst[kk] := v
}

CfHalf(v, fb) {
    return IsNumber(v) ? Number(v) : fb
}

; "" = not set, "1" = on, "0" = explicitly off
CfToggle(rPr, xp) {
    n := CfNode(rPr, xp)
    if !IsObject(n)
        return ""
    v := StrLower(CfAttr(n, "w:val"))
    return (v = "0" || v = "false" || v = "off") ? "0" : "1"
}

; ---------------------------------------------------------------------------
;  Theme fonts and styles (to find the font a run really gets)
; ---------------------------------------------------------------------------
CfLoadTheme() {
    Cf.theme := Map()
    f := Cf.work . ((Cf.kind = "ppt") ? "\ppt\theme\theme1.xml" : "\word\theme\theme1.xml")
    if !FileExist(f)
        return
    x := FileRead(f, "UTF-8")
    for kind in ["major", "minor"] {
        if RegExMatch(x, "s)<a:" . kind . "Font>(.*?)</a:" . kind . "Font>", &m) {
            blk := m[1]
            lat := RegExMatch(blk, '<a:latin typeface="([^"]*)"', &a) ? a[1] : ""
            cs := RegExMatch(blk, '<a:font script="Beng" typeface="([^"]*)"', &b) ? b[1] : ""
            if (cs = "" && RegExMatch(blk, '<a:cs typeface="([^"]*)"', &c))
                cs := c[1]
            Cf.theme[kind . "Latin"] := lat
            Cf.theme[kind . "Bidi"] := cs
        }
    }
}

CfThemeFont(name) {
    kind := InStr(name, "major") ? "major" : "minor"
    if InStr(name, "Bidi")
        return Cf.theme.Get(kind . "Bidi", "")
    if InStr(name, "EastAsia")
        return ""
    return Cf.theme.Get(kind . "Latin", "")
}

; Read fonts / sizes / bold / italic from one <w:rPr> into a Map.
; fa = Latin font, fh = high-ANSI font, fc = complex-script (Bangla Unicode) font,
; sz / szc = sizes in half points, b bc i ic = bold / italic (Latin / complex script)
CfReadRPr(rPr, p) {
    if !IsObject(rPr)
        return
    f := CfNode(rPr, "w:rFonts")
    if IsObject(f) {
        for pair in [["ascii", "fa"], ["hAnsi", "fh"], ["cs", "fc"]] {
            v := CfAttr(f, "w:" . pair[1])
            tn := CfAttr(f, "w:" . pair[1] . "Theme")
            if (pair[1] = "cs")
                tn := CfAttr(f, "w:cstheme")
            if (tn != "") {
                tv := CfThemeFont(tn)
                if (tv != "")
                    v := tv
            }
            if (v != "")
                p[pair[2]] := v
        }
    }
    for pair in [["w:sz", "sz"], ["w:szCs", "szc"]] {
        n := CfNode(rPr, pair[1])
        if IsObject(n) {
            v := CfAttr(n, "w:val")
            if (v != "")
                p[pair[2]] := v
        }
    }
    for pair in [["w:b", "b"], ["w:bCs", "bc"], ["w:i", "i"], ["w:iCs", "ic"], ["w:strike", "stk"], ["w:dstrike", "dstk"], ["w:caps", "cap"], ["w:smallCaps", "scap"]] {
        v := CfToggle(rPr, pair[1])
        if (v != "")
            p[pair[2]] := v
    }
    ; underline, colour, highlight, position, spacing, language
    for t in [["w:u", "w:val", "u"], ["w:color", "w:val", "col"], ["w:color", "w:themeColor", "colt"], ["w:highlight", "w:val", "hl"]
        , ["w:vertAlign", "w:val", "va"], ["w:spacing", "w:val", "spc"], ["w:lang", "w:val", "lg"], ["w:lang", "w:bidi", "lgb"]] {
        n := CfNode(rPr, t[1])
        if IsObject(n) {
            v := CfAttr(n, t[2])
            if (v != "")
                p[t[3]] := v
            else if (t[1] = "w:u")
                p["u"] := "single"
        }
    }
}

CfBuildStyles() {
    Cf.effCache := Map()
    Cf.baseCache := Map()
    Cf.styleRaw := Map()
    Cf.styleCache := Map()
    Cf.defProps := Map()
    Cf.defPara := ""
    f := Cf.work . "\word\styles.xml"
    if !FileExist(f)
        return
    d := CfLoadXml(f)
    CfReadRPr(CfNode(d, "//w:docDefaults/w:rPrDefault/w:rPr"), Cf.defProps)
    nodes := d.selectNodes("//w:style")
    Loop nodes.length {
        s := nodes.item(A_Index - 1)
        id := CfAttr(s, "w:styleId")
        if (id = "")
            continue
        props := Map()
        CfReadRPr(CfNode(s, "w:rPr"), props)
        raw := Map("based", CfAttr(CfNode(s, "w:basedOn"), "w:val"), "type", CfAttr(s, "w:type"), "props", props)
        Cf.styleRaw[id] := raw
        dflt := StrLower(CfAttr(s, "w:default"))
        if (raw["type"] = "paragraph" && (dflt = "1" || dflt = "true"))
            Cf.defPara := id
    }
}

CfStyleProps(id, depth := 0) {
    if (id = "" || !Cf.styleRaw.Has(id) || depth > 12)
        return Map()
    if Cf.styleCache.Has(id)
        return Cf.styleCache[id]
    raw := Cf.styleRaw[id]
    res := Map()
    CfMerge(res, CfStyleProps(raw["based"], depth + 1))
    CfMerge(res, raw["props"])
    Cf.styleCache[id] := res
    return res
}

; ---------------------------------------------------------------------------
;  Runs
; ---------------------------------------------------------------------------
; Everything we need to know about one run of text, or "" if it has no text.
CfRunInfo(r, pst) {
    ts := r.selectNodes("w:t")
    nt := ts.length
    if (nt = 0)
        return ""
    text := ""
    Loop nt
        text .= ts.item(A_Index - 1).text
    if (text = "")
        return ""
    rPr := CfNode(r, "w:rPr")
    rx := IsObject(rPr) ? rPr.xml : ""
    ck := pst . "|" . rx                               ; runs that look the same share one result
    if Cf.effCache.Has(ck) {
        eff := Cf.effCache[ck]
    } else {
        eff := Map()
        CfMerge(eff, CfBaseProps(pst))
        if IsObject(rPr)
            CfMerge(eff, CfStyleProps(CfAttr(CfNode(rPr, "w:rStyle"), "w:val")))
        CfReadRPr(rPr, eff)
        Cf.effCache[ck] := eff
    }
    bn := RegExMatch(text, "[\x{0980}-\x{09FF}]") > 0
    font := bn ? eff.Get("fc", "") : (eff.Has("fa") ? eff["fa"] : eff.Get("fh", ""))
    if (font = "")
        font := "(default)"
    ; the size the run really gets (half points): complex-script size for Bangla Unicode text
    half := CfHalf(eff.Get("sz", ""), 20)
    if bn
        half := CfHalf(eff.Get("szc", ""), half)
    half := Round(half)
    szl := CfPtLabel(half)
    return CfFinishInfo(Map("run", r, "rpr", rPr, "rx", rx, "text", text, "bn", bn, "font", font, "eff", eff, "nt", nt
        , "size", szl, "sizeNum", half / 2), false)
}

; Adds the scanned values of a run (info["attr"]) and its list key: only the options that were ticked when
; Scan was pressed are part of the key, so a conversion set for a row reaches exactly the runs that row shows.
CfFinishInfo(info, ppt) {
    eff := info["eff"]
    bn := info["bn"]
    xk := "_x" . (bn ? 1 : 0)
    if eff.Has(xk) {
        x := eff[xk]
    } else {
        x := ppt ? CfExtraP(eff) : CfExtraW(eff, bn)
        eff[xk] := x
    }
    attr := Map()
    key := ""
    for id in Cf.scanIds {
        v := (id = "font") ? info["font"] : ((id = "size") ? info["size"] : x[id])
        attr[id] := v
        key .= (A_Index > 1 ? "|" : "") . v
    }
    info["attr"] := attr
    info["key"] := key
    return info
}

CfStyleLabel(bold, ital) {
    if (bold && ital)
        return "Bold Italic"
    return bold ? "Bold" : (ital ? "Italic" : "Regular")
}

CfCap1(v) {
    return StrUpper(SubStr(v, 1, 1)) . SubStr(v, 2)
}

; Word: readable text for every scannable property of a run
CfExtraW(eff, bn) {
    x := Map()
    x["style"] := CfStyleLabel(eff.Get(bn ? "bc" : "b", "") = "1", eff.Get(bn ? "ic" : "i", "") = "1")
    if (eff.Get("cap", "") = "1")
        x["style"] .= ", All caps"
    if (eff.Get("scap", "") = "1")
        x["style"] .= ", Small caps"
    u := eff.Get("u", "")
    x["ul"] := (u = "" || u = "none") ? "None" : CfCap1(u)
    x["strike"] := (eff.Get("dstk", "") = "1") ? "Double" : ((eff.Get("stk", "") = "1") ? "Single" : "None")
    c := eff.Get("col", "")
    if RegExMatch(c, "^[0-9A-Fa-f]{6}$")
        x["color"] := "#" . StrUpper(c)
    else if (eff.Get("colt", "") != "")
        x["color"] := "Theme: " . eff["colt"]
    else
        x["color"] := "Automatic"
    h := eff.Get("hl", "")
    x["hl"] := (h = "" || h = "none") ? "None" : CfCap1(h)
    x["caps"] := (eff.Get("cap", "") = "1") ? "All caps" : ((eff.Get("scap", "") = "1") ? "Small caps" : "None")
    va := eff.Get("va", "")
    x["pos"] := (va = "superscript") ? "Superscript" : ((va = "subscript") ? "Subscript" : "Normal")
    sp := eff.Get("spc", "")
    if (IsNumber(sp) && Number(sp) != 0) {
        t := String(Round(Number(sp) / 20, 2))
        if InStr(t, ".")
            t := RTrim(RTrim(t, "0"), ".")
        x["spc"] := (Number(sp) > 0 ? "+" : "") . t . " pt"
    } else {
        x["spc"] := "Normal"
    }
    lg := bn ? eff.Get("lgb", eff.Get("lg", "")) : eff.Get("lg", "")
    x["lang"] := (lg = "") ? "(not set)" : lg
    return x
}

; PowerPoint: values come from the run itself; what a run inherits from the slide / master is not resolved here
CfExtraP(eff) {
    x := Map()
    inh := "(inherited)"
    hasB := eff.Has("b")
    hasI := eff.Has("i")
    x["style"] := (!hasB && !hasI) ? inh : CfStyleLabel(eff.Get("b", "") = "1", eff.Get("i", "") = "1")
    if (eff.Get("cap", "") = "all")
        x["style"] .= ", All caps"
    else if (eff.Get("cap", "") = "small")
        x["style"] .= ", Small caps"
    u := eff.Get("u", "")
    x["ul"] := (u = "") ? inh : ((u = "none") ? "None" : ((u = "sng") ? "Single" : ((u = "dbl") ? "Double" : CfCap1(u))))
    st := eff.Get("stk", "")
    x["strike"] := (st = "") ? inh : ((st = "dblStrike") ? "Double" : ((st = "sngStrike") ? "Single" : "None"))
    x["color"] := eff.Get("col", inh)
    x["hl"] := eff.Get("hl", "None")
    cp := eff.Get("cap", "")
    x["caps"] := (cp = "") ? inh : ((cp = "all") ? "All caps" : ((cp = "small") ? "Small caps" : "None"))
    bl := eff.Get("base", "")
    if !IsNumber(bl)
        x["pos"] := inh
    else
        x["pos"] := (Number(bl) > 0) ? "Superscript" : ((Number(bl) < 0) ? "Subscript" : "Normal")
    sp := eff.Get("spc", "")
    if !IsNumber(sp) {
        x["spc"] := inh
    } else if (Number(sp) = 0) {
        x["spc"] := "Normal"
    } else {
        t := String(Round(Number(sp) / 100, 2))
        if InStr(t, ".")
            t := RTrim(RTrim(t, "0"), ".")
        x["spc"] := (Number(sp) > 0 ? "+" : "") . t . " pt"
    }
    x["lang"] := eff.Get("lg", inh)
    return x
}

; document defaults + paragraph style, merged once per paragraph style
CfBaseProps(pst) {
    if Cf.baseCache.Has(pst)
        return Cf.baseCache[pst]
    base := Map()
    CfMerge(base, Cf.defProps)
    CfMerge(base, CfStyleProps(pst != "" ? pst : Cf.defPara))
    Cf.baseCache[pst] := base
    return base
}

; half points -> "11" or "11.5"
CfPtLabel(half) {
    return (Mod(half, 2) = 0) ? String(half // 2) : String(half // 2) . ".5"
}

CfFmtSize(n) {
    if (n < 1024)
        return n . " B"
    if (n < 1048576)
        return Round(n / 1024, 1) . " KB"
    return Round(n / 1048576, 2) . " MB"
}

CfIsSimple(r) {
    kids := r.childNodes
    cnt := 0
    Loop kids.length {
        nm := kids.item(A_Index - 1).nodeName
        if (nm = "#text")
            continue
        if (nm = "w:t")
            cnt += 1
        else if (nm != "w:rPr")
            return false
    }
    return (cnt = 1)
}

CfCount(info, para) {
    fkey := info["key"]
    if !Cf.fonts.Has(fkey) {
        a := info["attr"]
        Cf.fonts[fkey] := Map("key", fkey, "name", a.Has("font") ? info["font"] : "(any font)", "size", a.Has("size") ? info["size"] : "(any size)"
            , "sizeNum", a.Has("size") ? info["sizeNum"] : 0, "attr", a, "runs", 0, "chars", 0, "bn", 0, "text", "", "para", 0, "tl", 0)
    }
    Cf.curKeys[fkey] := 1                                ; this part uses this font (so the convert pass can skip other parts)
    st := Cf.fonts[fkey]
    st["runs"] += 1
    st["chars"] += StrLen(info["text"])
    if info["bn"]
        st["bn"] += 1
    if (st["tl"] >= 250000) {                          ; the preview only needs the first part of a very long text
        st["cut"] := true
        return
    }
    st["tl"] += StrLen(info["text"]) + 2
    if (st["para"] != para) {                         ; a new paragraph starts on a new line
        if (st["text"] != "")
            st["text"] .= "`r`n"
        st["para"] := para
    }
    st["text"] .= info["text"]
}

CfApplies(rule, info) {
    if (rule.act = 1 || rule.act = 3)
        return !info["bn"]
    if (rule.act = 2)
        return info["bn"]
    return (rule.act = 4)
}

CfConvertText(rule, s) {
    if (rule.act = 4)
        return s
    mk := ""
    if (StrLen(s) <= 600) {                            ; the same words come back again and again: remember them
        mk := rule.act . "|" . rule.map . "|" . rule.map2 . Chr(1) . s
        if Cf.memo.Has(mk)
            return Cf.memo[mk]
    }
    M := CfGetMap(rule.map)
    if (rule.act = 1)
        res := CfToUni(M, s)
    else if (rule.act = 2)
        res := CfToAnsi(M, s)
    else                                               ; ANSI -> ANSI: through Unicode
        res := CfToAnsi(CfGetMap(rule.map2), CfToUni(M, s))
    if (mk != "")
        Cf.memo[mk] := res
    return res
}

CfGetMap(idx) {
    if !Cf.mapCache.Has(idx) {
        it := Cf.mapFiles[idx]
        Cf.mapCache[idx] := (it["kind"] = "lib") ? LibMap(it["path"]) : Mapping(it["path"])
    }
    return Cf.mapCache[idx]
}

; ANSI text -> Unicode text and back, with a Library encoding or an old table
CfToUni(M, s) {
    return (M is LibMap) ? M.rev.Conv(s) : AnsiToUni(M, s)
}

CfToAnsi(M, s) {
    return (M is LibMap) ? M.lib.Conv(s) : UniToAnsi(M, s)
}

; ---- building / changing <w:rPr> children -------------------------------------
CfIdx(lname) {
    for i, n in Cf.order {
        if (n = lname)
            return i
    }
    return 999
}

CfInsertOrdered(parent, node, lname) {
    my := CfIdx(lname)
    kids := parent.childNodes
    Loop kids.length {
        c := kids.item(A_Index - 1)
        if (CfIdx(c.baseName) > my) {
            parent.insertBefore(node, c)
            return
        }
    }
    parent.appendChild(node)
}

CfGetOrCreate(rPr, lname) {
    n := CfNode(rPr, "w:" . lname)
    if IsObject(n)
        return n
    n := rPr.ownerDocument.createNode(1, "w:" . lname, Cf.NS)
    CfInsertOrdered(rPr, n, lname)
    return n
}

CfSetVal(rPr, lname, val) {
    CfGetOrCreate(rPr, lname).setAttribute("w:val", String(val))
}

CfSetOn(rPr, lname) {
    n := CfGetOrCreate(rPr, lname)
    try n.removeAttribute("w:val")
}

CfSetFonts(rPr, font) {
    f := CfGetOrCreate(rPr, "rFonts")
    for a in ["w:asciiTheme", "w:hAnsiTheme", "w:eastAsiaTheme", "w:cstheme", "w:hint"] {
        try f.removeAttribute(a)
    }
    for a in ["w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"]
        f.setAttribute(a, font)
}

CfApplyFormat(r, rule, info) {
    eff := info["eff"]
    bn := info["bn"]
    rPr := info["rpr"]
    if !IsObject(rPr) {
        rPr := r.ownerDocument.createNode(1, "w:rPr", Cf.NS)
        r.insertBefore(rPr, r.firstChild)
    }
    if (rule.font != "")
        CfSetFonts(rPr, rule.font)
    szA := CfHalf(eff.Get("sz", ""), 20)
    szC := CfHalf(eff.Get("szc", ""), szA)
    base := (rule.act = 1 || rule.act = 3) ? szA : ((rule.act = 2) ? szC : (bn ? szC : szA))
    newSz := ""
    if (rule.sizeMode = 1)
        newSz := Round(base + rule.sizeVal * 2)
    else if (rule.sizeMode = 2)
        newSz := Round(rule.sizeVal * 2)
    else if (rule.act = 1 || rule.act = 2)
        newSz := base
    if (newSz != "") {
        newSz := Max(2, newSz)
        CfSetVal(rPr, "sz", newSz)
        CfSetVal(rPr, "szCs", newSz)
    }
    ; bold / italic live in different elements for Latin and Bangla Unicode text
    if (rule.act = 1) {
        if (eff.Get("b", "") = "1" && eff.Get("bc", "") != "1")
            CfSetOn(rPr, "bCs")
        if (eff.Get("i", "") = "1" && eff.Get("ic", "") != "1")
            CfSetOn(rPr, "iCs")
    } else if (rule.act = 2) {
        if (eff.Get("bc", "") = "1" && eff.Get("b", "") != "1")
            CfSetOn(rPr, "b")
        if (eff.Get("ic", "") = "1" && eff.Get("i", "") != "1")
            CfSetOn(rPr, "i")
    }
}

; A run with several text pieces or other content (tabs, breaks): convert each piece on its own.
CfConvertRun(info, rule) {
    r := info["run"]
    ts := r.selectNodes("w:t")
    arr := []
    Loop ts.length
        arr.Push(ts.item(A_Index - 1))
    for t in arr {
        t.text := CfConvertText(rule, t.text)
        t.setAttribute("xml:space", "preserve")
    }
    CfApplyFormat(r, rule, info)
    Cf.nRuns += 1
    Cf.nChars += StrLen(info["text"])
    Cf.dirty := true
}

; Convert a group of neighbouring runs that look the same as one piece of text,
; so vowel signs and reph that sit in the next run are put in the right order.
CfFlush(&u) {
    if !IsObject(u)
        return
    rule := u["rule"]
    runs := u["runs"]
    first := runs[1]
    ppt := Cf.dml
    t := CfNode(first, ppt ? "a:t" : "w:t")
    t.text := CfConvertText(rule, u["text"])
    if !ppt
        t.setAttribute("xml:space", "preserve")
    Loop runs.Length - 1 {
        rr := runs[A_Index + 1]
        rr.parentNode.removeChild(rr)
    }
    if ppt
        CfApplyFormatP(first, rule, u["info"])
    else
        CfApplyFormat(first, rule, u["info"])
    Cf.nRuns += runs.Length
    Cf.nChars += StrLen(u["text"])
    Cf.dirty := true
    u := ""
}

; Scan (convert = false) or convert (convert = true) one XML part of the document.
CfProcessPart(path, convert) {
    if Cf.dml {
        CfProcessPartPpt(path, convert)
        return
    }
    d := CfLoadXml(path)
    pname := CfPartName(path)
    paras := d.selectNodes("//w:p")
    np := paras.length
    Loop np {
        pi := A_Index
        if (A_TickCount - Cf.tick > 120) {
            Cf.tick := A_TickCount
            CfProgress(CfPartPct(pi, np), convert ? "Converting" : "Reading")
            Sleep(-1)
        }
        pk := pname . "|" . pi
        if (convert && !CfParaActive(Cf.paraKeys.Get(pk, "")))
            continue                                   ; nothing in this paragraph is to be changed
        p := paras.item(pi - 1)
        Cf.paraSeq += 1
        rl := p.selectNodes(CfRunXPath)
        nr := rl.length
        if (nr = 0)
            continue
        runs := []                                   ; snapshot: the node list is live and changes while we edit
        Loop nr
            runs.Push(rl.item(A_Index - 1))
        pst := CfAttr(CfNode(p, "w:pPr/w:pStyle"), "w:val")
        unit := ""
        ks := ""
        for r in runs {
            info := CfRunInfo(r, pst)
            if !IsObject(info) {
                CfFlush(&unit)
                continue
            }
            if !convert {
                CfCount(info, Cf.paraSeq)
                ks .= info["key"] . "`n"
                continue
            }
            rule := Cf.rules.Get(info["key"], "")
            if (!IsObject(rule) || !CfApplies(rule, info)) {
                CfFlush(&unit)
                continue
            }
            if !CfIsSimple(r) {
                CfFlush(&unit)
                CfConvertRun(info, rule)
                continue
            }
            ukey := info["key"] . "|" . r.parentNode.nodeName . "|" . info["rx"]
            if (IsObject(unit) && unit["key"] = ukey) {
                unit["runs"].Push(r)
                unit["text"] .= info["text"]
            } else {
                CfFlush(&unit)
                unit := Map("key", ukey, "rule", rule, "info", info, "runs", [r], "text", info["text"])
            }
        }
        CfFlush(&unit)
        if (!convert && ks != "")
            Cf.paraKeys[pk] := ks                      ; remembered, so the convert pass can skip untouched paragraphs
    }
    if (convert && Cf.dirty)
        d.save(path)
}

; does any run key of this paragraph have a conversion set?
CfParaActive(kstr) {
    if (kstr = "")
        return false
    Loop Parse kstr, "`n" {
        if (A_LoopField = "")
            continue
        r := Cf.rules.Get(A_LoopField, "")
        if (IsObject(r) && r.act != 0)
            return true
    }
    return false
}

; "word\document.xml", "ppt\slides\slide3.xml" ... (path inside the package)
CfPartName(path) {
    return RegExReplace(path, "i)^.*?\\BFC_[^\\]+\\", "")
}

; Parts whose text is written as DrawingML (<a:p><a:r><a:t>): all of PowerPoint, plus
; SmartArt and charts inside Word documents.
CfIsDml(path) {
    return RegExMatch(CfPartName(path), "i)^(ppt\\|word\\diagrams\\|word\\charts\\)") > 0
}

CfPartPct(pi, np) {
    return Cf.phLo + (Cf.phHi - Cf.phLo) * (Cf.pBase + Cf.pSpan * pi / np)
}

; ---- PowerPoint (DrawingML): runs are <a:r><a:rPr/><a:t/></a:r> ----------------
CfThemeFontP(v) {
    kind := InStr(v, "mj") ? "major" : "minor"
    if InStr(v, "-cs")
        return Cf.theme.Get(kind . "Bidi", "")
    if InStr(v, "-ea")
        return ""
    return Cf.theme.Get(kind . "Latin", "")
}

CfRunInfoP(r) {
    tn := CfNode(r, "a:t")
    if !IsObject(tn)
        return ""
    text := tn.text
    if (text = "")
        return ""
    rPr := CfNode(r, "a:rPr")
    rx := IsObject(rPr) ? rPr.xml : ""
    ck := "P|" . rx
    if Cf.effCache.Has(ck) {
        eff := Cf.effCache[ck]
    } else {
        eff := Map()
        if IsObject(rPr) {
            sz := CfAttr(rPr, "sz")
            if IsNumber(sz)
                eff["sz"] := Number(sz)
            for pair in [["b", "b"], ["i", "i"], ["u", "u"], ["strike", "stk"], ["cap", "cap"], ["baseline", "base"], ["spc", "spc"], ["lang", "lg"]] {
                v := CfAttr(rPr, pair[1])
                if (v != "")
                    eff[pair[2]] := (pair[1] = "b" || pair[1] = "i") ? ((v = "1" || StrLower(v) = "true") ? "1" : "0") : v
            }
            cn := CfNode(rPr, "a:solidFill/a:srgbClr")
            if IsObject(cn)
                eff["col"] := "#" . StrUpper(CfAttr(cn, "val"))
            else {
                cn := CfNode(rPr, "a:solidFill/a:schemeClr")
                if IsObject(cn)
                    eff["col"] := "Theme: " . CfAttr(cn, "val")
            }
            hn := CfNode(rPr, "a:highlight/a:srgbClr")
            if IsObject(hn)
                eff["hl"] := "#" . StrUpper(CfAttr(hn, "val"))
            for pair in [["a:latin", "fa"], ["a:cs", "fc"]] {
                n := CfNode(rPr, pair[1])
                if IsObject(n) {
                    v := CfAttr(n, "typeface")
                    if (SubStr(v, 1, 1) = "+")
                        v := CfThemeFontP(v)
                    if (v != "")
                        eff[pair[2]] := v
                }
            }
        }
        Cf.effCache[ck] := eff
    }
    bn := RegExMatch(text, "[\x{0980}-\x{09FF}]") > 0
    font := bn ? eff.Get("fc", "") : eff.Get("fa", "")
    if (font = "")
        font := "(inherited)"
    if eff.Has("sz") {
        half := Round(eff["sz"] / 50)                  ; sz is in 1/100 pt
        szl := CfPtLabel(half)
        sn := half / 2
    } else {
        szl := "(auto)"
        sn := 0
    }
    return CfFinishInfo(Map("run", r, "rpr", rPr, "rx", rx, "text", text, "bn", bn, "font", font, "eff", eff, "nt", 1
        , "size", szl, "sizeNum", sn), true)
}

CfIdxA(lname) {
    for i, n in Cf.orderA {
        if (n = lname)
            return i
    }
    return 999
}

CfGetOrCreateA(rPr, lname) {
    n := CfNode(rPr, "a:" . lname)
    if IsObject(n)
        return n
    n := rPr.ownerDocument.createNode(1, "a:" . lname, Cf.NSA)
    my := CfIdxA(lname)
    kids := rPr.childNodes
    Loop kids.length {
        c := kids.item(A_Index - 1)
        if (CfIdxA(c.baseName) > my) {
            rPr.insertBefore(n, c)
            return n
        }
    }
    rPr.appendChild(n)
    return n
}

CfApplyFormatP(r, rule, info) {
    rPr := info["rpr"]
    if !IsObject(rPr) {
        rPr := r.ownerDocument.createNode(1, "a:rPr", Cf.NSA)
        r.insertBefore(rPr, r.firstChild)
    }
    if (rule.font != "") {
        for nm in ["latin", "ea", "cs"] {
            n := CfGetOrCreateA(rPr, nm)
            for a in ["pitchFamily", "charset", "panose"] {
                try n.removeAttribute(a)
            }
            n.setAttribute("typeface", rule.font)
        }
    }
    eff := info["eff"]
    base := eff.Has("sz") ? eff["sz"] : 0
    newSz := ""
    if (rule.sizeMode = 1 && base > 0)
        newSz := Round(base + rule.sizeVal * 100)
    else if (rule.sizeMode = 2)
        newSz := Round(rule.sizeVal * 100)
    if (newSz != "") {
        newSz := Min(400000, Max(100, newSz))
        rPr.setAttribute("sz", String(newSz))
    }
}

CfProcessPartPpt(path, convert) {
    d := CfLoadXml(path)
    pname := CfPartName(path)
    paras := d.selectNodes("//a:p")
    np := paras.length
    Loop np {
        pi := A_Index
        if (A_TickCount - Cf.tick > 120) {
            Cf.tick := A_TickCount
            CfProgress(CfPartPct(pi, np), convert ? "Converting" : "Reading")
            Sleep(-1)
        }
        pk := pname . "|" . pi
        if (convert && !CfParaActive(Cf.paraKeys.Get(pk, "")))
            continue
        p := paras.item(pi - 1)
        Cf.paraSeq += 1
        rl := p.selectNodes("a:r | a:br | a:fld")
        nr := rl.length
        if (nr = 0)
            continue
        runs := []
        Loop nr
            runs.Push(rl.item(A_Index - 1))
        unit := ""
        ks := ""
        for r in runs {
            if (r.nodeName != "a:r") {                   ; a line break or a field ends a group of runs
                CfFlush(&unit)
                continue
            }
            info := CfRunInfoP(r)
            if !IsObject(info) {
                CfFlush(&unit)
                continue
            }
            if !convert {
                CfCount(info, Cf.paraSeq)
                ks .= info["key"] . "`n"
                continue
            }
            rule := Cf.rules.Get(info["key"], "")
            if (!IsObject(rule) || !CfApplies(rule, info)) {
                CfFlush(&unit)
                continue
            }
            ukey := info["key"] . "|" . info["rx"]
            if (IsObject(unit) && unit["key"] = ukey) {
                unit["runs"].Push(r)
                unit["text"] .= info["text"]
            } else {
                CfFlush(&unit)
                unit := Map("key", ukey, "rule", rule, "info", info, "runs", [r], "text", info["text"])
            }
        }
        CfFlush(&unit)
        if (!convert && ks != "")
            Cf.paraKeys[pk] := ks
    }
    if (convert && Cf.dirty)
        d.save(path)
}

; Run CfProcessPart over several parts; each part gets a share of the progress bar
; (from phLo % to phHi %) in proportion to its file size.
CfRunParts(parts, convert, lo, hi) {
    sizes := []
    total := 0
    for part in parts {
        s := FileGetSize(part)
        sizes.Push(s)
        total += s
    }
    total := Max(total, 1)
    done := 0
    Cf.phLo := lo
    Cf.phHi := hi
    Cf.tick := A_TickCount
    for i, part in parts {
        Cf.pBase := done / total
        Cf.pSpan := sizes[i] / total
        Cf.dirty := false
        Cf.dml := CfIsDml(part)
        if !convert
            Cf.curKeys := Map()
        CfProcessPart(part, convert)
        if !convert
            Cf.partKeys[CfPartName(part)] := Cf.curKeys
        done += sizes[i]
    }
    CfProgress(hi)
}

; The XML parts that hold text.
CfParts(dir) {
    list := []
    if (Cf.kind = "ppt") {                              ; slides in order (slide2 before slide10), then notes, SmartArt, charts
        keys := []
        paths := []
        for spec in [["slides", "^slide\d+\.xml$", 0], ["notesSlides", "^notesSlide\d+\.xml$", 1000000]
                   , ["diagrams", "^(data|drawing)\d*\.xml$", 2000000], ["charts", "^chart\d*\.xml$", 3000000]
                   , ["slideMasters", "^slideMaster\d+\.xml$", 4000000], ["slideLayouts", "^slideLayout\d+\.xml$", 5000000]
                   , ["notesMasters", "^notesMaster\d+\.xml$", 6000000]] {
            Loop Files dir . "\ppt\" . spec[1] . "\*.xml" {
                if !RegExMatch(A_LoopFileName, "i)" . spec[2])
                    continue
                num := RegExMatch(A_LoopFileName, "(\d+)\.xml$", &mm) ? Integer(mm[1]) : 0
                keys.Push(spec[3] + num)
                paths.Push(A_LoopFileFullPath)
            }
        }
        Loop keys.Length - 1 {                           ; insertion sort
            i := A_Index + 1
            kx := keys[i]
            px := paths[i]
            j := i - 1
            while (j >= 1 && keys[j] > kx) {
                keys[j + 1] := keys[j]
                paths[j + 1] := paths[j]
                j -= 1
            }
            keys[j + 1] := kx
            paths[j + 1] := px
        }
        return paths
    }
    wd := dir . "\word"
    for nm in ["document.xml", "footnotes.xml", "endnotes.xml", "comments.xml"] {
        if FileExist(wd . "\" . nm)
            list.Push(wd . "\" . nm)
    }
    Loop Files wd . "\header*.xml"
        list.Push(A_LoopFileFullPath)
    Loop Files wd . "\footer*.xml"
        list.Push(A_LoopFileFullPath)
    for spec in [["diagrams", "^(data|drawing)\d*\.xml$"], ["charts", "^chart\d*\.xml$"]] {      ; SmartArt and chart text
        Loop Files wd . "\" . spec[1] . "\*.xml" {
            if RegExMatch(A_LoopFileName, "i)" . spec[2])
                list.Push(A_LoopFileFullPath)
        }
    }
    return list
}

; ---------------------------------------------------------------------------
;  Zip / unzip through Windows PowerShell (built in, no extra tools needed)
; ---------------------------------------------------------------------------
CfWriteScripts() {
    ex := "
(
param([string]$Zip, [string]$Dest)
$ErrorActionPreference = 'Stop'
try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
    [void][System.IO.Directory]::CreateDirectory($Dest)
    $root = (Get-Item -LiteralPath $Dest).FullName.TrimEnd('\')
    $z = [System.IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        foreach ($e in $z.Entries) {
            $n = $e.FullName
            if ($n.EndsWith('/')) { continue }
            if (-not ($n -match '\.(xml|rels)$')) { continue }
            $target = [System.IO.Path]::GetFullPath($root + '\' + $n.Replace('/', '\'))
            if (-not $target.StartsWith($root + '\')) { continue }
            [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target))
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
        }
    } finally { $z.Dispose() }
} catch { Write-Host $_ ; exit 1 }
)"
    zp := "
(
param([string]$Src, [string]$Over, [string]$Dst)
$ErrorActionPreference = 'Stop'
try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $Dst) { Remove-Item -LiteralPath $Dst -Force }
    $overRoot = (Get-Item -LiteralPath $Over).FullName.TrimEnd('\')
    $zin = [System.IO.Compression.ZipFile]::OpenRead($Src)
    $zout = [System.IO.Compression.ZipFile]::Open($Dst, 'Create')
    try {
        foreach ($e in $zin.Entries) {
            $n = $e.FullName
            if ($n.EndsWith('/')) { continue }
            $ov = $overRoot + '\' + $n.Replace('/', '\')
            if ([System.IO.File]::Exists($ov)) {
                [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zout, $ov, $n, [System.IO.Compression.CompressionLevel]::Fastest)
            } else {
                $lv = [System.IO.Compression.CompressionLevel]::Fastest
                if ($n -match '\.(png|jpe?g|gif|webp|heic|jfif|mp3|mp4|m4a|wav|wmv|avi|mov|zip|docx|xlsx|pptx|pdf)$') { $lv = [System.IO.Compression.CompressionLevel]::NoCompression }
                $ne = $zout.CreateEntry($n, $lv)
                $si = $e.Open()
                $so = $ne.Open()
                try { $si.CopyTo($so) } finally { $so.Dispose(); $si.Dispose() }
            }
        }
    } finally { $zout.Dispose(); $zin.Dispose() }
} catch { Write-Host $_ ; exit 1 }
)"
    Cf.psExtract := A_Temp . "\BFC_extract.ps1"
    Cf.psZip := A_Temp . "\BFC_zip.ps1"
    for pair in [[Cf.psExtract, ex], [Cf.psZip, zp]] {
        try FileDelete(pair[1])
        f := FileOpen(pair[1], "w", "UTF-8")          ; with BOM, so Windows PowerShell reads it correctly
        f.Write(pair[2])
        f.Close()
    }
}

CfRunPS(script, a1, a2, a3 := "") {
    cmd := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . script . '" "' . a1 . '" "' . a2 . '"' . (a3 != "" ? ' "' . a3 . '"' : "")
    try code := RunWait(cmd, , "Hide")
    catch
        return false
    return (code = 0)
}

CfCleanup(*) {
    if (Cf.work != "" && DirExist(Cf.work)) {
        try DirDelete(Cf.work, true)
    }
    Cf.work := ""
    if (Cf.tmpDoc != "") {                            ; the .docx / .pptx made from a .doc / .odt / .ppt ... file
        try FileDelete(Cf.tmpDoc)
        Cf.tmpDoc := ""
    }
}

; ===========================================================================
;  Window
; ===========================================================================
; The list (everything, tagged): first the scripts of Library\Encoding Script (.json or .menc; a .menc wins when both exist),
; shown as "Script: name", then the tables of Library\Encoding Table (*.txt and *.een; the .txt wins when both exist),
; shown as "Table: name".
CfAppDir() {
    SplitPath(A_ScriptDir, &nm, &par)
    return (nm = "Tools") ? par : A_ScriptDir
}

CfFindMaps() {
    list := []
    found := Map()
    found.CaseSense := "Off"
    for ext in ["json", "menc"] {
        Loop Files, CfAppDir() . "\Library\Encoding Script\*." . ext {
            if (StrLower(A_LoopFileExt) != ext)             ; the pattern can also match longer extensions
                continue
            SplitPath(A_LoopFileFullPath, , , , &nm)
            found[nm] := A_LoopFileFullPath                 ; the .menc comes second and replaces the .json
        }
    }
    for nm in EncRev.SortedKeys(found)
        list.Push(Map("kind", "lib", "path", found[nm], "name", "Script: " . nm))
    seen := Map()
    seen.CaseSense := "Off"
    for ext in ["txt", "een"] {
        Loop Files, CfAppDir() . "\Library\Encoding Table\*." . ext {
            SplitPath(A_LoopFileFullPath, , , &e, &nm)
            if (StrLower(e) != ext || seen.Has(nm))
                continue
            seen[nm] := 1
            list.Push(Map("kind", "txt", "path", A_LoopFileFullPath, "name", "Table: " . nm))
        }
    }
    return list
}

CfFontNames() {
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
    for n in ["Kalpurush", "SutonnyMJ", "AdarshaLipi", "Bornomala", "Nirmala UI", "SolaimanLipi", "Siyam Rupali", "Vrinda"]
        names[n] := 1
    list := []
    for fk in names
        list.Push(fk)
    return list
}

; Grey placeholder text in an empty edit box (v2 has no SetCue method).
CfSetCue(ctl, text) {
    try SendMessage(0x1501, 1, StrPtr(text), ctl.Hwnd)    ; EM_SETCUEBANNER, shown even when focused
}

CfLog(s) {
    Cf.edLog.Value := Cf.edLog.Value . s . "`r`n"
    SendMessage(0x115, 7, 0, Cf.edLog.Hwnd)           ; scroll to the end
}

CfNewRule() {
    return {act: 0, method: Cf.defMethod, map: Cf.defMap, map2: Cf.defMap2, font: "", sizeMode: 0, sizeVal: 0}
}

CfPlanText(rule) {
    if (rule.act = 0)
        return "Keep as is"
    names := ["", "ANSI to Unicode", "Unicode to ANSI", "ANSI to ANSI", "Change Font/Size"]
    s := names[rule.act + 1]
    if (rule.act = 3)
        s .= " [" . Cf.mapNames[rule.map] . " > " . Cf.mapNames[rule.map2] . "]"
    else if (rule.act < 3)
        s .= " [" . Cf.mapNames[rule.map] . "]"
    if (rule.font != "")
        s .= "  >  " . rule.font
    if (rule.sizeMode = 1)
        s .= "  " . (rule.sizeVal > 0 ? "+" : "") . rule.sizeVal . " pt"
    else if (rule.sizeMode = 2)
        s .= "  " . rule.sizeVal . " pt"
    return s
}

; error text with the place it happened (function, line, variable): makes a problem easy to report and fix
CfErrText(e) {
    t := e.Message
    try {
        if (e.Extra != "")
            t .= "`n`nDetail: " . e.Extra
        t .= "`n`nIn: " . e.What . "   (line " . e.Line . ")"
    }
    return t
}

CfBusy(on) {
    Cf.gui.Opt(on ? "+Disabled" : "-Disabled")
    if !on {
        Cf.gui.Show()
        CfRepaint()
    }
}

; Force every control (list, its header, texts, preview) to draw itself again.
; Without this, parts of the window stay blank or half drawn until the mouse touches them.
CfRepaint() {
    DllCall("RedrawWindow", "Ptr", Cf.gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)   ; INVALIDATE | ERASE | ALLCHILDREN | UPDATENOW
    hdr := SendMessage(0x101F, 0, 0, Cf.lv.Hwnd)
    if hdr
        DllCall("RedrawWindow", "Ptr", hdr, "Ptr", 0, "Ptr", 0, "UInt", 0x105)
}

; ---- the panel under the font list ------------------------------------------
CfEnableUI(act) {
    on := (act >= 0)
    Cf.ddAct.Enabled := on
    Cf.btnApplyAll.Enabled := on
    Cf.btnApplySel.Enabled := on
    Cf.ddMethod.Enabled := (act >= 1 && act <= 3 && Cf.methodUsable)
    Cf.ddMap.Enabled := (act >= 1 && act <= 3)
    Cf.ddMap2.Enabled := (act = 3)
    Cf.lbl2.Text := (act = 3) ? "From encoding" : "ANSI encoding"
    nf := (Cf.kind != "txt")                           ; a plain text file has no font or size
    Cf.cbFont.Enabled := (act >= 1 && nf)
    Cf.ddSize.Enabled := (act >= 1 && nf)
    Cf.edSize.Enabled := (act >= 1 && nf && Cf.ddSize.Value > 1)
}

CfLoadRuleUI(rule) {
    Cf.busyUI := true
    Cf.ddAct.Choose(rule.act + 1)
    Cf.ddMethod.Choose(rule.method + 1)
    CfFillMapBoxes(rule.method, rule.map, rule.map2)
    Cf.cbFont.Text := rule.font
    Cf.ddSize.Choose(rule.sizeMode + 1)
    Cf.edSize.Value := rule.sizeVal
    CfEnableUI(rule.act)
    Cf.busyUI := false
}

; ---- Method: which kind of encoding the two encoding boxes list (0 = Both, 1 = Scripts, 2 = Table) ----
; Cf.mapFiles keeps every encoding under a fixed number (the rules store that number). A "view" is the list of
; those numbers that the Method lets through, in the same order. A Method with nothing in it shows everything.
CfMethodView(method) {
    v := []
    for i, it in Cf.mapFiles {
        if (method = 0 || (method = 1 && it["kind"] = "lib") || (method = 2 && it["kind"] != "lib"))
            v.Push(i)
    }
    if (v.Length = 0) {
        for i, it in Cf.mapFiles
            v.Push(i)
    }
    return v
}

CfInView(view, idx) {
    for i in view {
        if (i = idx)
            return true
    }
    return false
}

; the encoding number behind a position in the boxes as they are shown now
CfViewIdx(pos) {
    if (Cf.mapView.Length = 0)
        return 1
    return Cf.mapView[Max(1, Min(Cf.mapView.Length, pos))]
}

; the position in the boxes of an encoding number (1 = the first one, when the Method hides it)
CfViewPos(idx) {
    for p, i in Cf.mapView {
        if (i = idx)
            return p
    }
    return 1
}

; list the encodings of a Method in both encoding boxes and select the two given encodings
CfFillMapBoxes(method, from1, to1) {
    if (Cf.viewMethod != method) {
        Cf.mapView := CfMethodView(method)
        Cf.viewMethod := method
        names := []
        for i in Cf.mapView
            names.Push(Cf.mapNames[i])
        Cf.ddMap.Delete()
        Cf.ddMap.Add(names)
        Cf.ddMap2.Delete()
        Cf.ddMap2.Add(names)
    }
    Cf.ddMap.Choose(CfViewPos(from1))
    Cf.ddMap2.Choose(CfViewPos(to1))
}

; the Method box was changed: it goes to every selected row; a row whose encoding the new Method hides gets the
; first encoding of that Method (rows whose encoding still fits keep it)
CfMethodChanged(*) {
    if (Cf.busyUI || Cf.curName = "")
        return
    m := Cf.ddMethod.Value - 1
    Cf.defMethod := m
    view := CfMethodView(m)
    cur := Cf.rules[Cf.curName]
    todo := [cur]
    row := 0
    while (row := Cf.lv.GetNext(row)) {
        r := Cf.rules[Cf.rowKeys[row]]
        if (ObjPtr(r) != ObjPtr(cur))
            todo.Push(r)
    }
    for r in todo {
        r.method := m
        if !CfInView(view, r.map)
            r.map := view[1]
        if !CfInView(view, r.map2)
            r.map2 := (view.Length > 1 && view[1] = r.map) ? view[2] : view[1]
    }
    Cf.defMap := cur.map
    Cf.defMap2 := cur.map2
    CfRefreshPlans()
}

CfUIChanged(*) {
    if (Cf.busyUI || Cf.curName = "")
        return
    rule := Cf.rules[Cf.curName]
    old := rule.act
    oMap := rule.map, oMap2 := rule.map2, oFont := rule.font, oSM := rule.sizeMode, oSV := rule.sizeVal   ; to see what was changed
    rule.act := Cf.ddAct.Value - 1
    if (rule.act != old && Cf.kind != "txt" && Trim(Cf.cbFont.Text) = "") {      ; a sensible starting font
        if (rule.act = 1)
            Cf.cbFont.Text := "Kalpurush"
        else if (rule.act = 2 || rule.act = 3)
            Cf.cbFont.Text := "SutonnyMJ"
    }
    rule.map := CfViewIdx(Cf.ddMap.Value)
    rule.map2 := CfViewIdx(Cf.ddMap2.Value)
    Cf.defMap := rule.map                           ; default for the next rows of this document only
    Cf.defMap2 := rule.map2
    rule.font := Trim(Cf.cbFont.Text)
    rule.sizeMode := Max(0, Cf.ddSize.Value - 1)
    v := Trim(Cf.edSize.Text)
    if IsNumber(v)
        rule.sizeVal := Number(v)
    CfEnableUI(rule.act)
    ; several rows selected: whatever was changed just now is applied to every selected row (the other
    ; settings of those rows stay as they are); the list may be sorted / filtered, so ask which rows are selected
    row := 0
    while (row := Cf.lv.GetNext(row)) {
        r := Cf.rules[Cf.rowKeys[row]]
        if (ObjPtr(r) != ObjPtr(rule)) {
            if (rule.act != old)
                r.act := rule.act
            if (rule.map != oMap) {
                r.map := rule.map
                if !CfInView(CfMethodView(r.method), r.map)       ; that row's Method hides this encoding: follow this row's Method
                    r.method := rule.method
            }
            if (rule.map2 != oMap2) {
                r.map2 := rule.map2
                if !CfInView(CfMethodView(r.method), r.map2)
                    r.method := rule.method
            }
            if (rule.font != oFont)
                r.font := rule.font
            if (rule.sizeMode != oSM)
                r.sizeMode := rule.sizeMode
            if (rule.sizeVal != oSV)
                r.sizeVal := rule.sizeVal
        }
        Cf.lv.Modify(row, "Col" . Cf.colIds.Length, CfPlanText(r))
    }
}

; ---- right-click menu of the list: selecting, copying settings, resetting ----
CfSelectedRows() {
    rows := []
    row := 0
    while (row := Cf.lv.GetNext(row))
        rows.Push(row)
    return rows
}

; after the selection was changed by code: the panel follows one row of the selection
CfSelDone(primary := 0) {
    Cf.busySel := false
    Cf.lv.Opt("+Redraw")
    rows := CfSelectedRows()
    if (rows.Length = 0)
        return
    if (primary < 1)
        primary := rows[1]
    isSel := false
    for r in rows {
        if (r = primary)
            isSel := true
    }
    if !isSel
        primary := rows[1]
    Cf.curRow := primary
    Cf.curName := Cf.rowKeys[primary]
    CfLoadRuleUI(Cf.rules[Cf.curName])
    CfShowPreview(Cf.curName)
    if (rows.Length > 1)
        Cf.sb.SetText("  " . rows.Length . " rows selected - a change you make on the right applies to all of them.")
}

CfSelAll(*) {
    Cf.busySel := true
    Cf.lv.Opt("-Redraw")
    Cf.lv.Modify(0, "Select")
    CfSelDone(Cf.curRow)
}

CfSelInvert(*) {
    on := Map()
    for r in CfSelectedRows()
        on[r] := 1
    Cf.busySel := true
    Cf.lv.Opt("-Redraw")
    Loop Cf.rowKeys.Length
        Cf.lv.Modify(A_Index, on.Has(A_Index) ? "-Select" : "Select")
    CfSelDone(Cf.curRow)
}

; select every row that has the same value in one column (same font, same size, same plan ...)
CfSelSame(id, val, *) {
    Cf.busySel := true
    Cf.lv.Opt("-Redraw")
    Cf.lv.Modify(0, "-Select")
    first := 0
    for i, key in Cf.rowKeys {
        if (StrCompare(CfSortText(Cf.fonts[key], id), val, "Off") = 0) {
            Cf.lv.Modify(i, "Select")
            if (first = 0)
                first := i
        }
    }
    CfSelDone(first)
}

CfCopyRule(dst, src) {
    dst.act := src.act
    dst.method := src.method
    dst.map := src.map
    dst.map2 := src.map2
    dst.font := src.font
    dst.sizeMode := src.sizeMode
    dst.sizeVal := src.sizeVal
}

CfRefreshPlans() {
    col := "Col" . Cf.colIds.Length
    Cf.lv.Opt("-Redraw")
    for i, key in Cf.rowKeys
        Cf.lv.Modify(i, col, CfPlanText(Cf.rules[key]))
    Cf.lv.Opt("+Redraw")
    if (Cf.curName != "" && Cf.rules.Has(Cf.curName))
        CfLoadRuleUI(Cf.rules[Cf.curName])
}

CfCopySettings(item, *) {
    r := Cf.rules[Cf.rowKeys[item]]
    Cf.clip := {act: r.act, method: r.method, map: r.map, map2: r.map2, font: r.font, sizeMode: r.sizeMode, sizeVal: r.sizeVal}
    Cf.sb.SetText("  Settings copied. Select other rows and use Paste settings (right-click).")
}

CfPasteSettings(*) {
    if !IsObject(Cf.clip)
        return
    for row in CfSelectedRows()
        CfCopyRule(Cf.rules[Cf.rowKeys[row]], Cf.clip)
    CfRefreshPlans()
}

CfResetSelected(*) {
    for row in CfSelectedRows()
        Cf.rules[Cf.rowKeys[row]] := CfNewRule()
    CfRefreshPlans()
}

; the settings of one row go to every row that the list shows now (the filter decides which)
CfApplyAllShown(srcKey, *) {
    if (srcKey = "" || !Cf.rules.Has(srcKey) || Cf.rowKeys.Length = 0)
        return
    src := Cf.rules[srcKey]
    srcPlan := CfPlanText(src)
    clash := 0
    for key in Cf.rowKeys {
        r := Cf.rules[key]
        if (r.act != 0 && CfPlanText(r) != srcPlan)
            clash += 1
    }
    if (clash > 0 && MsgBox("Apply these settings to all " . Cf.rowKeys.Length . " rows shown?`n`n" . clash . " of them already have a different plan, which will be replaced.", "Bangla Document Converter", 0x124) != "Yes")
        return
    for key in Cf.rowKeys {
        if (key != srcKey)
            CfCopyRule(Cf.rules[key], src)
    }
    CfRefreshPlans()
    Cf.sb.SetText("  Settings applied to all " . Cf.rowKeys.Length . " rows shown.")
}

; the settings now shown go to every selected row of the list
CfApplySelected(*) {
    if (Cf.curName = "" || !Cf.rules.Has(Cf.curName))
        return
    src := Cf.rules[Cf.curName]
    n := 0
    for row in CfSelectedRows() {
        key := Cf.rowKeys[row]
        if (key != Cf.curName) {
            CfCopyRule(Cf.rules[key], src)
            n += 1
        }
    }
    CfRefreshPlans()
    Cf.sb.SetText("  Settings applied to " . CfSelectedRows().Length . " selected row(s).")
}

CfListMenu(lv, item, isRight, x, y) {
    if (Cf.rowKeys.Length = 0)
        return
    if (item < 1 || item > Cf.rowKeys.Length)
        item := lv.GetNext(0, "F")
    n := CfSelectedRows().Length
    m := Menu()
    m.Add("Select all", CfSelAll)
    m.Add("Invert selection", CfSelInvert)
    if (item > 0) {
        st := Cf.fonts[Cf.rowKeys[item]]
        sm := Menu()
        for id in Cf.colIds {
            if (id = "runs" || id = "chars")
                continue
            hd := (id = "type") ? "Type" : ((id = "plan") ? "Plan" : id)
            for dim in CfDims {
                if (dim[1] = id)
                    hd := dim[2]
            }
            val := CfSortText(st, id)
            sm.Add(StrReplace(hd . ":  " . val, "&", "&&"), CfSelSame.Bind(id, val))
        }
        m.Add("Select all rows with the same", sm)
    }
    m.Add()
    if (item > 0) {
        m.Add("Copy settings of this row", CfCopySettings.Bind(item))
        m.Add("Apply this row's settings to all shown rows", (*) => CfApplyAllShown(Cf.rowKeys[item]))
    }
    m.Add("Paste settings to the selected rows", CfPasteSettings)
    if (!IsObject(Cf.clip) || n = 0)
        m.Disable("Paste settings to the selected rows")
    m.Add()
    m.Add("Reset the selected rows to Keep as is", CfResetSelected)
    if (n = 0)
        m.Disable("Reset the selected rows to Keep as is")
    m.Show()
}

; ---- hover tips: a timer looks where the mouse is, so a tip also appears over a disabled control ----
CfTipBox(ctrls) {
    l := 99999, t := 99999, r := 0, b := 0
    for c in ctrls {
        if !c.Visible                                   ; a hidden control gives no tip
            continue
        c.GetPos(&x, &y, &w, &h)
        l := Min(l, x), t := Min(t, y), r := Max(r, x + w), b := Max(b, y + h)
    }
    return [l, t, r, b]
}

; hover tips of the window: [controls the tip covers, text]. Always on; short and simple on purpose.
CfTipAreas() {
    scan := []
    for k, c in Cf.cbScan
        scan.Push(c)
    tabTip := ["Log: what the program did, step by step."
        , "Preview: a sample of the text that uses the selected row."
        , "Help: how to use this window."]
    return [[[Cf.hdSize, Cf.ddSize, Cf.edSize]
            , "Size in points.`nChange by: adds to the current size. Negative = smaller, e.g. -2.`nSet to: uses this exact size."]
        , [[Cf.btnApplySel], "Copy the settings now shown (action, encoding, font, size) to every selected row."]
        , [[Cf.btnApplyAll], "Copy the settings now shown (action, encoding, font, size) to every row the list shows.`nThe filter decides which rows those are."]
        , [[Cf.hdFile, Cf.btnOpen], "Open a Word, PowerPoint or text file.`nYou can also drop files on this window."]
        , [[Cf.btnRemove], "Close the open document and clear the list."]
        , [[Cf.hdScan], "Choose what to look at when scanning."]
        , [[Cf.btnScanAll], "Tick every scan option."]
        , [[Cf.btnScanNone], "Untick every scan option."]
        , [scan, "Tick what to look at when scanning.`nEach ticked item becomes a column you can filter by."]
        , [[Cf.btnScan], "Scan the document and list the fonts found."]
        , [[Cf.edFind], "Type here to show only the rows that contain it."]
        , [[Cf.ddBy], "Pick a column to filter by.`nA second box then lists every value found in that column; a * marks a column that is filtered."]
        , [[Cf.ddVal], "Show only the rows whose chosen column has this value.`nAll columns stay visible. Values come from the scanned data that the other filters still show."]
        , [[Cf.btnClearF], "Remove every filter and show all rows again."]
        , [[Cf.ddType], "Show only rows of one kind of text."]
        , [[Cf.lblMin, Cf.edMin], "Hide rows with fewer characters than this."]
        , [[Cf.lblMax, Cf.edMax], "Hide rows with more characters than this. Empty = no limit."]
        , [[Cf.lblCount], "Rows shown / rows found."]
        , [[Cf.lv], "One row per font found. Select rows, then set what to do on the right.`nRight-click a row for more."]
        , [[Cf.split], "Drag up or down to resize the list and the boxes below."]
        , [[Cf.edLog, Cf.edPrev, Cf.edHelp], tabTip[Max(1, Min(3, Cf.tab.Value))]]
        , [[Cf.ddMethod], "Which encodings the boxes below list.`nBoth: scripts and tables.`nScripts: custom (scripted) conversion only.`nTable: standard (universal) conversion only."]
        , [[Cf.hdAct, Cf.ddAct], "What to do with the selected rows.`nKeep as is leaves them unchanged."]
        , [[Cf.hdEnc, Cf.lbl2, Cf.ddMap], "The encoding the text is written in now.`n`nScript: custom (scripted) conversion with its own rules (more control).`nTable: standard (universal) conversion from a plain list of pairs."]
        , [[Cf.lbl6, Cf.ddMap2], "The encoding to turn the text into.`n`nScript: custom (scripted) conversion with its own rules (more control).`nTable: standard (universal) conversion from a plain list of pairs."]
        , [[Cf.hdFont, Cf.cbFont], "The font for the converted text.`nPick one or type its name."]
        , [[Cf.hdPrev, Cf.lblPrevSz], "Size of the text in the Preview tab."]
        , [[Cf.btnPrevDn], "Smaller preview text."]
        , [[Cf.btnPrevUp], "Bigger preview text."]
        , [[Cf.btnPrevReset], "Back to the normal preview size."]
        , [[Cf.btnConv], "Convert using the plan set on each row and save a new file.`nYour original file is never changed."]]
}

CfTipTick() {
    static hits := 0, shown := 0
    if !IsObject(Cf.gui)
        return
    which := 0
    try {
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "Ptr", pt)
        hw := DllCall("WindowFromPoint", "Int64", NumGet(pt, 0, "Int64"), "Ptr")
        if (hw && DllCall("GetAncestor", "Ptr", hw, "UInt", 2, "Ptr") = Cf.gui.Hwnd) {
            DllCall("ScreenToClient", "Ptr", Cf.gui.Hwnd, "Ptr", pt)
            mx := NumGet(pt, 0, "Int")
            my := NumGet(pt, 4, "Int")
            areas := CfTipAreas()
            for i, a in areas {
                bx := CfTipBox(a[1])
                if (mx >= bx[1] && mx < bx[3] && my >= bx[2] && my < bx[4]) {
                    which := i
                    tip := a[2]
                    break
                }
            }
        }
    }
    if (which = 0) {
        hits := 0
        if shown {
            ToolTip(, , , 19)
            shown := 0
        }
        return
    }
    if (shown && shown != which) {
        ToolTip(, , , 19)
        shown := 0
        hits := 0
    }
    hits += 1
    if (hits >= 2 && !shown) {
        ToolTip(tip, , , 19)
        shown := which
    }
}

CfDelayedUI(*) {
    SetTimer(CfUIChanged, -80)       ; the text of a drop-down box needs a moment to update after a pick
}

; after a click / Ctrl / Shift selection: keep the panel on a row that is still selected, and say how many are
CfSelFix() {
    n := 0
    found := false
    row := 0
    while (row := Cf.lv.GetNext(row)) {
        n += 1
        if (n = 1)
            first := row
        if (row = Cf.curRow)
            found := true
    }
    if (n = 0)
        return
    if (!found && first <= Cf.rowKeys.Length) {
        Cf.curRow := first
        Cf.curName := Cf.rowKeys[first]
        CfLoadRuleUI(Cf.rules[Cf.curName])
        CfShowPreview(Cf.curName)
    }
    if (n > 1)
        Cf.sb.SetText("  " . n . " rows selected - a change you make on the right applies to all of them.")
}

CfRowSelect(lv, row, selected) {
    if Cf.busySel
        return
    SetTimer(CfSelFix, -20)
    if (!selected || row < 1 || row > Cf.rowKeys.Length)
        return
    Cf.curRow := row
    Cf.curName := Cf.rowKeys[row]
    CfLoadRuleUI(Cf.rules[Cf.curName])
    CfShowPreview(Cf.curName)
}

; Show the complete text that uses the selected font, in that font (if it is installed).
; Done a moment after the click (the list is still busy with the click itself), and repainted, so it
; appears at once without having to click the preview box.
CfShowPreview(key) {
    Cf.prevPending := key
    SetTimer(CfShowPreviewNow, -10)
}

CfShowPreviewNow() {
    key := Cf.prevPending
    if (key = "")
        return
    if (key = Cf.prevKey && Cf.edPrev.Value != "")     ; already showing it (e.g. only the filter changed)
        return
    if !Cf.fonts.Has(key) {
        Cf.prevKey := ""
        Cf.edPrev.Value := ""
        return
    }
    Cf.prevKey := key
    st := Cf.fonts[key]
    fn := (st["name"] = "(default)" || st["name"] = "(inherited)" || st["name"] = "(plain text)" || st["name"] = "(any font)") ? "Segoe UI" : st["name"]
    Cf.prevFont := fn
    Cf.tab.Choose(2)
    CfApplyPreviewFont()
    txt := st["text"]
    if (StrLen(txt) > 300000) {                        ; plain text files: keep the preview box fast
        txt := SubStr(txt, 1, 300000)
        st["cut"] := true
    }
    if st.Has("cut")
        txt .= "`r`n`r`n... (the preview shows only the first part of this very long text; the conversion covers all of it)"
    Cf.edPrev.Value := txt
    SendMessage(0xB1, 0, 0, Cf.edPrev.Hwnd)           ; EM_SETSEL 0,0: caret to the top
    SendMessage(0xB7, 0, 0, Cf.edPrev.Hwnd)           ; EM_SCROLLCARET
    CfRedrawTab()
}

; repaint the visible page of the Log / Preview / Help tab
CfRedrawTab() {
    for ed in [Cf.edLog, Cf.edPrev, Cf.edHelp] {
        if DllCall("IsWindowVisible", "Ptr", ed.Hwnd)
            DllCall("RedrawWindow", "Ptr", ed.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
    }
}

CfTabChanged(*) {
    CfRedrawTab()
    if (Cf.tab.Value = 2 && Cf.prevKey = "" && Cf.curName != "")
        CfShowPreview(Cf.curName)
}

; ---- preview text size (A- / A+ / Reset in the right panel) ----------------------
CfApplyPreviewFont() {
    Cf.lblPrevSz.Text := Cf.prevSize . " pt"
    Cf.btnPrevDn.Enabled := (Cf.prevSize > 6)
    Cf.btnPrevUp.Enabled := (Cf.prevSize < 48)
    try Cf.edPrev.SetFont("s" . Cf.prevSize . " norm", Cf.prevFont)
}

CfPrevStep(step) {
    Cf.prevSize := (step = 0) ? 11 : Min(48, Max(6, Cf.prevSize + step))
    CfApplyPreviewFont()
}

; ---- removing the document ------------------------------------------------------
CfRemove(*) {
    if (Cf.file = "")
        return
    old := Cf.file
    CfCleanup()
    Cf.file := ""
    Cf.kind := ""
    Cf.txtText := ""
    Cf.paraKeys := Map()
    CfProgressReset()
    CfNewDocDefaults()
    CfClearResults()
    Cf.edFile.Text := "No document open"
    Cf.btnRemove.Enabled := false
    Cf.queue := []
    Cf.btnConv.Text := "Convert and save as..."
    CfEnableScan()
    Cf.tab.Choose(1)
    CfLog("Removed: " . old)
    Cf.sb.SetText("  Open a Word, PowerPoint or text file (or drop one or more files on this window).")
}

; a document was opened or removed: every setting goes back to its start value
CfNewDocDefaults() {
    for dim in CfDims {
        if Cf.cbScan.Has(dim[1])
            Cf.cbScan[dim[1]].Value := (dim[1] = "font" || dim[1] = "size") ? 1 : 0
    }
    Cf.scanIds := ["font", "size"]
    Cf.sortCol := "chars"
    Cf.sortDesc := true
    Cf.prevSize := 11
    Cf.prevFont := "Segoe UI"
    CfApplyPreviewFont()
}

; right panel back to its start values (no old font / encoding / size is carried over)
CfResetPanel() {
    Cf.busyUI := true
    Cf.ddAct.Choose(1)
    Cf.ddMethod.Choose(1)
    CfFillMapBoxes(0, 1, Cf.mapFiles.Length > 1 ? 2 : 1)
    Cf.cbFont.Text := ""
    Cf.ddSize.Choose(1)
    Cf.edSize.Value := "0"
    Cf.busyUI := false
}

; empty list, rules and preview (a file was opened, removed or scanned again)
CfClearResults() {
    Cf.fonts := Map()
    Cf.fonts.CaseSense := "Off"
    Cf.rules := Map()
    Cf.rules.CaseSense := "Off"
    Cf.scanned := false
    Cf.curName := ""
    Cf.curRow := 0
    Cf.rowKeys := []
    Cf.lv.Delete()
    Cf.edPrev.Value := ""
    Cf.prevKey := ""
    Cf.lblCount.Text := ""
    Cf.clip := ""                                       ; copied settings, encodings: back to the start values
    Cf.defMap := 1
    Cf.defMap2 := (Cf.mapFiles.Length > 1 ? 2 : 1)
    Cf.defMethod := 0
    CfResetPanel()
    Cf.colFilter := Map()
    Cf.colFilter.CaseSense := "Off"
    Cf.valKeys := []
    Cf.edFind.Value := ""
    Cf.ddType.Choose(1)
    Cf.edMin.Value := "0"
    Cf.edMax.Value := ""
    Cf.ddBy.Delete()
    Cf.ddBy.Add(["Any column"])
    Cf.ddBy.Choose(1)
    Cf.ddVal.Delete()
    Cf.ddVal.Add(["(pick a column first)"])
    Cf.ddVal.Choose(1)
    Cf.ddVal.Enabled := false
    Cf.btnClearF.Enabled := false
    CfEnableUI(-1)
}

; the scan options (right panel): Scan button needs an open file, tick boxes are not used for a text file
CfEnableScan() {
    has := (Cf.file != "")
    Cf.btnScan.Enabled := has
    on := (Cf.kind != "txt")
    for id, cb in Cf.cbScan
        cb.Enabled := on
    Cf.btnScanAll.Enabled := on
    Cf.btnScanNone.Enabled := on
}

CfScanAll(*) {
    for id, cb in Cf.cbScan
        cb.Value := 1
}

CfScanNone(*) {
    for id, cb in Cf.cbScan
        cb.Value := 0
}

CfTypeOf(st) {
    return (st["bn"] = st["runs"]) ? "Bangla Unicode" : ((st["bn"] = 0) ? "ANSI / Latin text" : "Mixed")
}

CfSortText(st, id) {
    if (id = "type")
        return CfTypeOf(st)
    if (id = "plan")
        return CfPlanText(Cf.rules[st["key"]])
    return st["attr"].Get(id, "")
}

; Compare two list entries by the current sort column (-1, 0, 1).
CfCmp(a, b) {
    c := Cf.sortCol
    if (c = "size" || c = "runs" || c = "chars") {
        va := (c = "size") ? a["sizeNum"] : a[c]
        vb := (c = "size") ? b["sizeNum"] : b[c]
        r := (va < vb) ? -1 : ((va > vb) ? 1 : 0)
    } else {
        r := StrCompare(CfSortText(a, c), CfSortText(b, c), "Off")
    }
    if Cf.sortDesc
        r := -r
    if (r != 0)
        return r
    r := StrCompare(a["name"], b["name"], "Off")        ; same value: font name, then size, then the rest
    if (r != 0)
        return r
    r := (a["sizeNum"] < b["sizeNum"]) ? -1 : ((a["sizeNum"] > b["sizeNum"]) ? 1 : 0)
    if (r != 0)
        return r
    return StrCompare(a["key"], b["key"], "Off")
}

; The columns follow what was scanned: one column for each ticked option, then Type, Runs, Characters, Plan.
; The "filter by" box is rebuilt with the same names.
CfBuildColumns() {
    Cf.lv.Opt("-Redraw")
    Cf.lv.Delete()
    n := Cf.lv.GetCount("Col")
    Loop n
        Cf.lv.DeleteCol(1)
    Cf.colIds := []
    heads := []
    Cf.byIds := ["any"]
    names := ["Any column"]
    widths := Map("font", "150", "size", "60 Float", "style", "90", "ul", "80", "strike", "95", "color", "95", "hl", "85", "lang", "80", "spc", "80", "type", "110", "runs", "60 Integer", "chars", "90 Integer", "plan", "280")
    for id in Cf.scanIds {
        for dim in CfDims {
            if (dim[1] = id) {
                Cf.colIds.Push(id)
                heads.Push(dim[2])
                names.Push(dim[2])
                Cf.byIds.Push(id)
            }
        }
    }
    for t in [["type", "Type", "110"], ["runs", "Runs", "60 Integer"], ["chars", "Characters", "90 Integer"], ["plan", "Plan", "280"]] {
        Cf.colIds.Push(t[1])
        heads.Push(t[2])
    }
    Cf.colW := Map()
    for i, hd in heads {
        Cf.lv.InsertCol(i, "", hd)
        Cf.colW[i] := widths[Cf.colIds[i]]
        Cf.lv.ModifyCol(i, Cf.colW[i])
    }
    Cf.lv.Opt("+Redraw")
    Cf.ddBy.Delete()
    Cf.ddBy.Add(names)
    Cf.ddBy.Choose(1)
    CfApplyColView()
    ok := false
    for id in Cf.colIds {
        if (id = Cf.sortCol)
            ok := true
    }
    if !ok {
        Cf.sortCol := "chars"
        Cf.sortDesc := true
    }
}

; All columns always stay visible; the filter boxes only decide which rows are listed.
CfApplyColView() {
    Cf.lv.Opt("-Redraw")
    for i, id in Cf.colIds
        Cf.lv.ModifyCol(i, Cf.colW[i])
    Cf.lv.Opt("+Redraw")
}

CfByChanged(*) {
    CfRefreshList()
}

; the value drop-down: pick one value of the chosen column; every other column's rows are filtered by it too
CfValChanged(*) {
    by := Cf.byIds[Max(1, Min(Cf.byIds.Length, Cf.ddBy.Value))]
    if (by = "any")
        return
    idx := Cf.ddVal.Value
    if (idx <= 1 || idx > Cf.valKeys.Length)
        Cf.colFilter.Delete(by)
    else
        Cf.colFilter[by] := Cf.valKeys[idx]
    CfRefreshList()
}

CfClearFilters(*) {
    Cf.colFilter := Map()
    Cf.colFilter.CaseSense := "Off"
    Cf.edFind.Value := ""
    Cf.ddType.Choose(1)
    Cf.edMin.Value := "0"
    Cf.edMax.Value := ""
    Cf.ddBy.Choose(1)
    CfRefreshList()
}

; read the filter boxes once per refresh
CfReadFilter() {
    mn := Trim(Cf.edMin.Text)
    mx := Trim(Cf.edMax.Text)
    return {q: Trim(Cf.edFind.Text), tsel: Max(1, Cf.ddType.Value)
        , minc: IsInteger(mn) ? Integer(mn) : 0
        , maxc: (IsInteger(mx) && Integer(mx) > 0) ? Integer(mx) : 0}       ; empty / 0 = no upper limit
}

; does a row pass every filter? skip = a column whose own value filter is left out (to list that column's values)
CfRowPasses(st, f, skip := "") {
    if (f.q != "") {
        hit := false
        for id, v in st["attr"] {
            if InStr(v, f.q) {
                hit := true
                break
            }
        }
        if !hit
            return false
    }
    for id, v in Cf.colFilter {
        if (id != skip && st["attr"].Get(id, "") != v)
            return false
    }
    if (f.tsel > 1 && CfTypeOf(st) != Cf.typeNames[f.tsel])
        return false
    if (st["chars"] < f.minc)
        return false
    if (f.maxc > 0 && st["chars"] > f.maxc)
        return false
    return true
}

; Rebuild the value drop-down for the chosen column from the scanned data that the OTHER filters still let through,
; and mark the columns that have a value filter in the column drop-down.
CfBuildValues(f) {
    ; column names, a * after those that are filtered
    sel := Max(1, Cf.ddBy.Value)
    names := ["Any column"]
    for id in Cf.colIds {
        for dim in CfDims {
            if (dim[1] = id)
                names.Push(dim[2] . (Cf.colFilter.Has(id) ? "  *" : ""))
        }
    }
    changed := (SendMessage(0x146, 0, 0, Cf.ddBy.Hwnd) != names.Length)         ; CB_GETCOUNT
    if !changed {
        Loop names.Length {
            if (CfComboText(Cf.ddBy, A_Index) != names[A_Index]) {
                changed := true
                break
            }
        }
    }
    if changed {
        Cf.ddBy.Delete()
        Cf.ddBy.Add(names)
        Cf.ddBy.Choose(sel)
    }
    by := Cf.byIds[Max(1, Min(Cf.byIds.Length, sel))]
    Cf.ddVal.Delete()
    if (by = "any" || Cf.fonts.Count = 0) {
        Cf.valKeys := []
        Cf.ddVal.Add(["(pick a column first)"])
        Cf.ddVal.Choose(1)
        Cf.ddVal.Enabled := false
    } else {
        counts := Map()
        counts.CaseSense := "Off"
        for fk, st in Cf.fonts {
            if CfRowPasses(st, f, by) {
                v := st["attr"].Get(by, "")
                counts[v] := counts.Get(v, 0) + 1
            }
        }
        chosen := Cf.colFilter.Get(by, "")
        if (chosen != "" && !counts.Has(chosen))
            counts[chosen] := 0                         ; the chosen value stays in the list, even if other filters hide all its rows
        vals := []
        for v, n in counts
            vals.Push(v)
        Loop vals.Length - 1 {                          ; insertion sort (numbers by value, text A-Z)
            i := A_Index + 1
            x := vals[i]
            j := i - 1
            while (j >= 1 && CfValCmp(vals[j], x) > 0) {
                vals[j + 1] := vals[j]
                j -= 1
            }
            vals[j + 1] := x
        }
        Cf.valKeys := [""]
        items := ["All values  (" . vals.Length . ")"]
        pick := 1
        for v in vals {
            Cf.valKeys.Push(v)
            items.Push(v . "   (" . counts[v] . (counts[v] = 1 ? " row)" : " rows)"))
            if (chosen != "" && v = chosen)
                pick := A_Index + 1
        }
        Cf.ddVal.Add(items)
        Cf.ddVal.Choose(pick)
        Cf.ddVal.Enabled := true
    }
    anyF := (f.q != "" || Cf.colFilter.Count > 0 || f.tsel > 1 || f.minc > 0 || f.maxc > 0)
    Cf.btnClearF.Enabled := (Cf.fonts.Count > 0 && anyF)
}

CfComboText(ctl, i) {
    n := SendMessage(0x149, i - 1, 0, ctl.Hwnd)         ; CB_GETLBTEXTLEN
    if (n <= 0)
        return ""
    b := Buffer((n + 2) * 2, 0)
    SendMessage(0x148, i - 1, b, ctl.Hwnd)              ; CB_GETLBTEXT
    return StrGet(b, "UTF-16")
}

CfValCmp(a, b) {
    if (IsNumber(a) && IsNumber(b))
        return (Number(a) < Number(b)) ? -1 : ((Number(a) > Number(b)) ? 1 : 0)
    return StrCompare(a, b, "Off")
}

; Called after a scan: one conversion rule per row.
CfFillList() {
    Cf.rules := Map()
    Cf.rules.CaseSense := "Off"
    for fk, st in Cf.fonts                              ; every document starts fresh: nothing is kept from earlier ones
        Cf.rules[st["key"]] := CfNewRule()
    Cf.curName := ""
    Cf.curRow := 0
    Cf.prevKey := ""
    CfBuildColumns()
    Cf.colFilter := Map()
    Cf.colFilter.CaseSense := "Off"
    Cf.edFind.Value := ""
    Cf.ddType.Choose(1)
    Cf.edMin.Value := "0"
    Cf.edMax.Value := ""
    CfRefreshList()
}

; Rebuild the list from the current filter and sort settings.
CfRefreshList(*) {
    keep := Cf.curName
    f := CfReadFilter()
    rows := []
    for fk, st in Cf.fonts {
        if CfRowPasses(st, f)
            rows.Push(st)
    }
    Loop rows.Length - 1 {                              ; insertion sort
        i := A_Index + 1
        x := rows[i]
        j := i - 1
        while (j >= 1 && CfCmp(rows[j], x) > 0) {
            rows[j + 1] := rows[j]
            j -= 1
        }
        rows[j + 1] := x
    }
    Cf.lv.Opt("-Redraw")
    Cf.lv.Delete()
    Cf.rowKeys := []
    sel := 0
    for st in rows {
        vals := []
        for id in Cf.colIds {
            if (id = "type")
                vals.Push(CfTypeOf(st))
            else if (id = "runs")
                vals.Push(st["runs"])
            else if (id = "chars")
                vals.Push(st["chars"])
            else if (id = "plan")
                vals.Push(CfPlanText(Cf.rules[st["key"]]))
            else
                vals.Push(st["attr"].Get(id, ""))
        }
        Cf.lv.Add("", vals*)
        Cf.rowKeys.Push(st["key"])
        if (st["key"] = keep)
            sel := A_Index
    }
    Cf.lv.Opt("+Redraw")
    CfRepaint()
    Cf.lblCount.Text := (Cf.fonts.Count = 0) ? "" : rows.Length . " of " . Cf.fonts.Count . " shown"
    CfBuildValues(f)
    CfSortArrows()
    if (rows.Length = 0) {
        Cf.curName := ""
        Cf.curRow := 0
        CfEnableUI(-1)
        Cf.edPrev.Value := ""
        Cf.prevKey := ""
        return
    }
    if (sel = 0)
        sel := 1
    Cf.lv.Modify(sel, "Select Focus Vis")
    CfRowSelect(Cf.lv, sel, true)
}

; Draw the sort arrow (up = A-Z / small first, down = Z-A / big first) in the header
; of the column the list is sorted by, and remove it from the other columns.
CfSortArrows() {
    hdr := SendMessage(0x101F, 0, 0, Cf.lv.Hwnd)          ; LVM_GETHEADER
    if !hdr
        return
    off := 8 + 2 * A_PtrSize + 4                           ; offset of HDITEM.fmt
    hi := Buffer(A_PtrSize = 8 ? 72 : 48, 0)
    for col, id in Cf.colIds {
        NumPut("UInt", 0x4, hi, 0)                         ; mask = HDI_FORMAT
        if !SendMessage(0x120B, col - 1, hi, hdr)          ; HDM_GETITEMW
            continue
        fmt := NumGet(hi, off, "Int") & ~0x600             ; clear HDF_SORTUP (0x400) and HDF_SORTDOWN (0x200)
        if (id = Cf.sortCol)
            fmt |= (Cf.sortDesc ? 0x200 : 0x400)
        NumPut("Int", fmt, hi, off)
        SendMessage(0x120C, col - 1, hi, hdr)              ; HDM_SETITEMW
    }
    DllCall("InvalidateRect", "Ptr", hdr, "Ptr", 0, "Int", true)
}

CfFilterDelayed(*) {
    SetTimer(CfRefreshList, -200)
}

; Click on a column header: sort by it (again = reverse).
CfColClick(lv, col) {
    if (col < 1 || col > Cf.colIds.Length)
        return
    id := Cf.colIds[col]
    if (id = Cf.sortCol) {
        Cf.sortDesc := !Cf.sortDesc
    } else {
        Cf.sortCol := id
        Cf.sortDesc := (id = "runs" || id = "chars")     ; numbers: biggest first
    }
    CfRefreshList()
}

; ---- opening a file ---------------------------------------------------------
CfOpenDialog(*) {
    f := FileSelect("M3", (Cf.lastOpenDir != "" && DirExist(Cf.lastOpenDir)) ? Cf.lastOpenDir : "", "Open one or more documents (Ctrl / Shift + click to pick several)", "Documents (*.docx;*.docm;*.dotx;*.dotm;*.pptx;*.pptm;*.potx;*.potm;*.ppsx;*.ppsm;*.doc;*.dot;*.rtf;*.odt;*.wps;*.ppt;*.pot;*.pps;*.odp;*.txt)")
    if (f.Length > 0)
        CfOpenMany(f)
}

CfKindOf(ext) {
    if InStr(" docx docm dotx dotm ", " " . ext . " ")
        return "word"
    if InStr(" pptx pptm potx potm ppsx ppsm ", " " . ext . " ")
        return "ppt"
    if InStr(" doc dot rtf odt wps ", " " . ext . " ")
        return "legacy"
    if InStr(" ppt pot pps odp ", " " . ext . " ")
        return "legacyppt"
    if (ext = "txt")
        return "txt"
    return ""
}

; Bar + label under the Convert button. pct 0..100; with text the label shows it with a percentage
; and, while converting, an estimate of the time left.
CfProgress(pct, txt := "") {
    pct := Min(100, Max(0, pct))
    ip := Round(pct)
    if (ip != Cf.lastPct) {
        Cf.pb.Value := ip
        Cf.lastPct := ip
    }
    if (txt = "")
        return
    s := Cf.progPre . txt . " " . ip . "%"
    if (Cf.convT0 > 0 && pct >= 8 && pct < 100) {
        el := (A_TickCount - Cf.convT0) / 1000
        if (el >= 3) {
            left := Round(el * (100 - pct) / pct)
            s .= "  (about " . (left >= 90 ? Round(left / 60) . " min" : Max(1, left) . " s") . " left)"
        }
    }
    if (s != Cf.lastTxt) {
        Cf.lastTxt := s
        Cf.sb.SetText("  " . s)
    }
}

CfProgressReset() {
    Cf.pb.Value := 0
    Cf.lastPct := 0
    Cf.lastTxt := ""
}

; .doc / .rtf / .odt ... -> .docx through Microsoft Word, or LibreOffice when Word is not there.
CfToDocx(src, dst) {
    w := ""
    try {
        w := ComObject("Word.Application")
        w.Visible := false
        w.DisplayAlerts := 0
        doc := w.Documents.Open(src, false, true)
        doc.SaveAs2(dst, 16)                            ; 16 = wdFormatXMLDocument (.docx)
        doc.Close(0)
        w.Quit(0)
        w := ""
        if FileExist(dst)
            return true
    } catch {
        if IsObject(w) {
            try w.Quit(0)
        }
    }
    return CfLibreConvert(src, dst, "docx")
}

; .ppt / .pot / .pps / .odp -> .pptx through Microsoft PowerPoint, or LibreOffice when PowerPoint is not there.
CfToPptx(src, dst) {
    p := ""
    try {
        p := ComObject("PowerPoint.Application")
        pres := p.Presentations.Open(src, -1, 0, 0)     ; read only, untitled, no window (-1 = msoTrue)
        pres.SaveAs(dst, 24)                                     ; 24 = ppSaveAsOpenXMLPresentation (.pptx)
        pres.Close()
        p.Quit()
        p := ""
        if FileExist(dst)
            return true
    } catch {
        if IsObject(p) {
            try p.Quit()
        }
    }
    return CfLibreConvert(src, dst, "pptx")
}

; The format a result is saved in is the one the file was opened in (a .wps file can only be saved as .docx).
CfOutExt(ext, newExt) {
    return (ext = "wps") ? newExt : ext
}

; .docx -> .doc / .dot / .rtf / .odt again, through Microsoft Word, or LibreOffice when Word is not there.
CfFromDocx(src, dst) {
    SplitPath(dst, , , &ext)
    ext := StrLower(ext)
    codes := Map("doc", 0, "dot", 1, "rtf", 6, "odt", 23)       ; Word's SaveAs2 format numbers
    w := ""
    if codes.Has(ext) {
        try {
            w := ComObject("Word.Application")
            w.Visible := false
            w.DisplayAlerts := 0
            doc := w.Documents.Open(src, false, true)
            doc.SaveAs2(dst, codes[ext])
            doc.Close(0)
            w.Quit(0)
            w := ""
            if FileExist(dst)
                return true
        } catch {
            if IsObject(w) {
                try w.Quit(0)
            }
        }
    }
    return CfLibreConvert(src, dst, ext)
}

; .pptx -> .ppt / .pot / .pps / .odp again, through Microsoft PowerPoint, or LibreOffice when PowerPoint is not there.
CfFromPptx(src, dst) {
    SplitPath(dst, , , &ext)
    ext := StrLower(ext)
    codes := Map("ppt", 1, "pot", 5, "pps", 7, "odp", 50)       ; PowerPoint's SaveAs format numbers
    p := ""
    if codes.Has(ext) {
        try {
            p := ComObject("PowerPoint.Application")
            pres := p.Presentations.Open(src, -1, 0, 0)
            pres.SaveAs(dst, codes[ext])
            pres.Close()
            p.Quit()
            p := ""
            if FileExist(dst)
                return true
        } catch {
            if IsObject(p) {
                try p.Quit()
            }
        }
    }
    return CfLibreConvert(src, dst, ext)
}

; LibreOffice (headless): converts src to the format fmt ("docx" / "pptx") and moves the result to dst.
CfLibreConvert(src, dst, fmt) {
    SplitPath(src, , , , &nm)
    for root in [EnvGet("ProgramFiles"), EnvGet("ProgramW6432"), EnvGet("ProgramFiles(x86)")] {
        exe := root . "\LibreOffice\program\soffice.exe"
        if (root = "" || !FileExist(exe))
            continue
        outDir := A_Temp . "\BFC_lo_" . A_TickCount
        DirCreate(outDir)
        try RunWait('"' . exe . '" --headless --convert-to ' . fmt . ' --outdir "' . outDir . '" "' . src . '"', , "Hide")
        f := outDir . "\" . nm . "." . fmt
        if FileExist(f) {
            FileMove(f, dst, 1)
            try DirDelete(outDir, true)
            return true
        }
        try DirDelete(outDir, true)
    }
    return false
}

; Plain text: one entry, "(plain text)". The encoding is detected (UTF-8 / UTF-16, else ANSI).
CfLoadTxt(path) {
    b := FileRead(path, "RAW")
    n := b.Size
    enc := "CP1252"
    if (n >= 2 && NumGet(b, 0, "UChar") = 0xFF && NumGet(b, 1, "UChar") = 0xFE)
        enc := "UTF-16"
    else if (n = 0 || (n >= 3 && NumGet(b, 0, "UChar") = 0xEF && NumGet(b, 1, "UChar") = 0xBB && NumGet(b, 2, "UChar") = 0xBF))
        enc := "UTF-8"
    else if (DllCall("MultiByteToWideChar", "UInt", 65001, "UInt", 8, "Ptr", b, "Int", n, "Ptr", 0, "Int", 0, "Int") > 0)
        enc := "UTF-8"                                  ; MB_ERR_INVALID_CHARS: valid UTF-8
    text := FileRead(path, enc)
    Cf.txtText := text
    Cf.txtEnc := enc
}

; plain text: the single "font" entry, made when Scan is pressed
CfTxtEntry() {
    text := Cf.txtText
    bn := (RegExMatch(text, "[\x{0980}-\x{09FF}]") > 0) ? 1 : 0
    key := "(plain text)|-"
    shown := StrReplace(StrReplace(text, "`r`n", "`n"), "`n", "`r`n")
    Cf.fonts[key] := Map("key", key, "name", "(plain text)", "size", "-", "sizeNum", 0, "attr", Map("font", "(plain text)", "size", "-"), "runs", 1, "chars", StrLen(text), "bn", bn, "text", shown, "para", 0)
}

CfDrop(g, ctl, files, x, y) {
    CfOpenMany(files)
}

; Several files: the first one is opened as usual, the others wait in a queue. Scan reads all of them (so every
; font combination of every file is in the list) and Convert applies the same plan to all of them.
CfOpenMany(files) {
    if (files.Length = 0)
        return
    CfOpen(files[1])
    if (files.Length = 1 || StrLower(Cf.file) != StrLower(files[1]))
        return
    isTxt := (Cf.kind = "txt")
    seen := Map()
    seen.CaseSense := "Off"
    seen[Cf.file] := 1
    q := []
    Loop files.Length - 1 {
        p := files[A_Index + 1]
        if seen.Has(p)
            continue
        seen[p] := 1
        SplitPath(p, , , &ext)
        k := CfKindOf(StrLower(ext))
        if (k = "" || ((k = "txt") != isTxt)) {
            CfLog("Skipped (not supported together with the first file): " . p)
            continue
        }
        q.Push(p)
    }
    Cf.queue := q
    if (q.Length > 0) {
        CfUpdateFileLabel()
        CfLog("Also added to the batch: " . q.Length . " more file(s).")
        Cf.sb.SetText("  " . (q.Length + 1) . " files opened. Press Scan: all of them are read, and one plan is used for every file.")
    }
}

CfUpdateFileLabel() {
    n := Cf.queue.Length
    Cf.btnConv.Text := (n > 0) ? "Convert all and save in folder..." : "Convert and save as..."
    Cf.edFile.Text := Cf.file . (n > 0 ? "   (+" . n . " more file" . (n > 1 ? "s" : "") . ")" : "")
}

; ---- batch helpers: another file is handled with the state of the open file put aside and restored ----
CfStash() {
    s := Map()
    for n in ["file", "kind", "outExt", "work", "tmpDoc", "txtText", "txtEnc", "partKeys", "paraKeys", "effCache", "baseCache"
            , "curKeys", "dml", "dirty", "theme", "styleRaw", "styleCache", "defProps", "defPara"]
        s[n] := Cf.%n%
    Cf.work := ""
    Cf.tmpDoc := ""
    return s
}

CfUnstash(s) {
    for n, v in s
        Cf.%n% := v
}

; unpack (or read) one file into Cf.work / Cf.txtText, like Open does
CfPrepare(path) {
    SplitPath(path, , , &ext)
    ext := StrLower(ext)
    kind := CfKindOf(ext)
    outExt := ext
    src := path
    if (kind = "legacy" || kind = "legacyppt") {
        isPpt := (kind = "legacyppt")
        newExt := isPpt ? "pptx" : "docx"
        Cf.tmpDoc := A_Temp . "\BFC_conv_" . A_TickCount . "." . newExt
        if !(isPpt ? CfToPptx(path, Cf.tmpDoc) : CfToDocx(path, Cf.tmpDoc)) {
            Cf.tmpDoc := ""
            throw Error("Could not open this ." . ext . " file (Word, PowerPoint or LibreOffice is needed for it).")
        }
        src := Cf.tmpDoc
        kind := isPpt ? "ppt" : "word"
        outExt := CfOutExt(ext, newExt)
    }
    Cf.kind := kind
    Cf.outExt := outExt
    Cf.file := path
    Cf.txtText := ""
    if (kind = "txt") {
        CfLoadTxt(path)
    } else {
        Cf.work := A_Temp . "\BFC_" . A_TickCount
        if !(CfRunPS(Cf.psExtract, src, Cf.work) && DirExist(Cf.work))
            throw Error("Could not open the file (damaged, password protected, or not a real document).")
    }
}

; read another file of the batch: its font combinations are added to the list (counts are added up)
CfScanOther(path) {
    s := CfStash()
    try {
        CfPrepare(path)
        Cf.effCache := Map()
        Cf.baseCache := Map()
        Cf.paraKeys := Map()
        Cf.partKeys := Map()
        CfLoadTheme()
        CfBuildStyles()
        CfRunParts(CfParts(Cf.work), false, 6, 100)
    } finally {
        CfCleanup()
        CfUnstash(s)
    }
}

CfScanQueue() {
    total := Cf.queue.Length + 1
    i := 1
    while (i <= Cf.queue.Length) {
        Cf.progPre := "File " . (i + 1) . " of " . total . ": "
        try {
            CfScanOther(Cf.queue[i])
            i += 1
        } catch as e {
            CfLog("Skipped (could not read): " . Cf.queue[i] . "  -  " . e.Message)
            Cf.queue.RemoveAt(i)
        }
    }
    Cf.progPre := ""
    CfUpdateFileLabel()
}

; convert another file of the batch with the plan that is set; returns the saved path
CfConvertOther(path, outDir) {
    s := CfStash()
    oldFonts := Cf.fonts
    out := ""
    try {
        CfPrepare(path)
        out := CfUniqueOut(outDir, path, Cf.outExt)
        if (Cf.kind = "txt") {
            CfConvertTxt(out)
        } else {
            Cf.fonts := Map()
            Cf.fonts.CaseSense := "Off"
            Cf.effCache := Map()
            Cf.baseCache := Map()
            Cf.paraKeys := Map()
            Cf.partKeys := Map()
            CfLoadTheme()
            CfBuildStyles()
            Cf.paraSeq := 0
            CfRunParts(CfParts(Cf.work), false, 1, 4)
            CfConvertDoc(out)
        }
    } finally {
        Cf.fonts := oldFonts
        CfCleanup()
        CfUnstash(s)
    }
    return out
}

; name_converted.ext in the folder; never overwrites: name_converted (2).ext ... when it exists
CfUniqueOut(dir, path, ext) {
    SplitPath(path, , , , &nm)
    out := dir . "\" . nm . "_converted." . ext
    n := 2
    while FileExist(out) {
        out := dir . "\" . nm . "_converted (" . n . ")." . ext
        n += 1
    }
    return out
}

CfConvertBatch() {
    SplitPath(Cf.file, , &dir)
    if (Cf.lastSaveDir != "" && DirExist(Cf.lastSaveDir))
        dir := Cf.lastSaveDir
    files := [Cf.file]
    for p in Cf.queue
        files.Push(p)
    total := files.Length
    outDir := DirSelect("*" . dir, 3, "Choose the folder where the " . total . " converted files will be saved")
    if (outDir = "")
        return
    outDir := RTrim(outDir, "\")
    done := 0
    nFail := 0
    t0 := A_TickCount
    CfBusy(true)
    try {
        for i, p in files {
            Cf.progPre := "File " . i . " of " . total . ": "
            Cf.convT0 := 0
            Cf.nRuns := 0
            Cf.nChars := 0
            try {
                if (i = 1) {
                    out := CfUniqueOut(outDir, p, Cf.outExt)
                    if (Cf.kind = "txt")
                        CfConvertTxt(out)
                    else
                        CfConvertDoc(out)
                } else {
                    out := CfConvertOther(p, outDir)
                }
                done += 1
                CfLog("Saved: " . out)
            } catch as e {
                nFail += 1
                CfLog("FAILED: " . p . "  -  " . e.Message)
            }
        }
    } finally {
        Cf.progPre := ""
        Cf.convT0 := 0
        CfProgressReset()
    }
    Cf.lastSaveDir := outDir
    CfSaveSettings()
    secs := Round((A_TickCount - t0) / 1000, 1)
    CfLog("Batch finished: " . done . " of " . total . " file(s) converted in " . secs . " s" . (nFail > 0 ? ", " . nFail . " failed (see above)." : "."))
    Cf.sb.SetText("  Done. " . done . " of " . total . " file(s) converted in " . secs . " s.")
    CfBusy(false)
    if (MsgBox(done . " of " . total . " file(s) converted" . (nFail > 0 ? " (" . nFail . " failed, see the Log tab)" : "") . ".`n`nSaved in:`n" . outDir . "`n`nOpen the folder?", "Bangla Document Converter", 0x24) = "Yes")
        Run('explorer.exe "' . outDir . '"')
}

CfOpen(path) {
    SplitPath(path, , &pdir, &ext)
    ext := StrLower(ext)
    kind := CfKindOf(ext)
    if (kind = "") {
        MsgBox("This file type is not supported.`n`nSupported:`nWord: .docx .docm .dotx .dotm (and .doc .dot .rtf .odt .wps, through Word or LibreOffice)`nPowerPoint: .pptx .pptm .potx .potm .ppsx .ppsm (and .ppt .pot .pps .odp, through PowerPoint or LibreOffice)`nText: .txt`n`nSee the Help tab for the full list.", "Bangla Document Converter", 0x30)
        return
    }
    Cf.lastOpenDir := pdir
    CfBusy(true)
    try {
        t0 := A_TickCount
        CfCleanup()
        Cf.convT0 := 0
        CfProgress(1, "Opening")
        outExt := ext
        src := path
        if (kind = "legacy" || kind = "legacyppt") {
            isPpt := (kind = "legacyppt")
            newExt := isPpt ? "pptx" : "docx"
            CfProgress(2, "Converting to ." . newExt)
            Cf.tmpDoc := A_Temp . "\BFC_conv_" . A_TickCount . "." . newExt
            if !(isPpt ? CfToPptx(path, Cf.tmpDoc) : CfToDocx(path, Cf.tmpDoc)) {
                Cf.tmpDoc := ""
                throw Error("Could not open this ." . ext . " file.`n" . (isPpt ? "Microsoft PowerPoint" : "Microsoft Word") . " (or LibreOffice) is needed for it. Or open it in " . (isPpt ? "PowerPoint" : "Word") . " and save it as ." . newExt . " first.")
            }
            src := Cf.tmpDoc
            kind := isPpt ? "ppt" : "word"
            outExt := CfOutExt(ext, newExt)
        }
        Cf.kind := kind
        Cf.outExt := outExt
        Cf.effCache := Map()
        Cf.baseCache := Map()
        Cf.paraKeys := Map()
        Cf.partKeys := Map()
        Cf.txtText := ""
        t1 := A_TickCount
        if (kind = "txt") {
            CfLoadTxt(path)
        } else {
            Cf.work := A_Temp . "\BFC_" . A_TickCount
            CfProgress(3, "Unpacking")
            if !(CfRunPS(Cf.psExtract, src, Cf.work) && DirExist(Cf.work))
                throw Error("Could not open the file (damaged, password protected, or not a real document).")
            t1 := A_TickCount
        }
        t2 := A_TickCount
        Cf.file := path
        Cf.queue := []
        CfUpdateFileLabel()
        CfNewDocDefaults()                             ; a new document: all settings start fresh
        CfClearResults()                               ; nothing is scanned yet: the scan starts only with the Scan button
        Cf.edLog.Value := ""
        CfLog("Opened: " . path . "  (" . CfFmtSize(FileGetSize(path)) . ")")
        if (src != path)
            CfLog("Read through a temporary ." . (kind = "ppt" ? "pptx" : "docx") . " copy (needed for ." . ext . " files). The result will be saved as ." . outExt . (outExt = ext ? " again." : " (a ." . ext . " file cannot be written)."))
        if (kind = "txt")
            CfLog("Plain text, " . StrLen(Cf.txtText) . " character(s), read as " . Cf.txtEnc . ". No fonts in a text file: press Scan, then pick a conversion.")
        else
            CfLog("Unpacked in " . (t2 - t0) . " ms. Nothing is scanned yet: tick what to scan on the right, then press Scan.")
        Cf.btnRemove.Enabled := true
        CfEnableScan()
        CfProgressReset()
        Cf.sb.SetText("  Opened. Tick what to scan (right side), then press Scan.")
    } catch as e {
        MsgBox(CfErrText(e), "Bangla Document Converter", 0x10)
        Cf.sb.SetText("  Could not open the file.")
        CfProgressReset()
    }
    CfBusy(false)
}

; ---- scanning: only when the Scan button is pressed ---------------------------
CfScan(*) {
    if (Cf.file = "" || (Cf.kind != "txt" && Cf.work = "")) {
        MsgBox("Open a document first.", "Bangla Document Converter", 0x30)
        return
    }
    ids := []
    if (Cf.kind = "txt") {
        ids := ["font", "size"]
    } else {
        for dim in CfDims {
            if (Cf.cbScan[dim[1]].Value = 1)
                ids.Push(dim[1])
        }
    }
    if (ids.Length = 0) {
        MsgBox("Tick at least one thing to scan (for example Font), then press Scan.", "Bangla Document Converter", 0x30)
        return
    }
    if Cf.scanned {
        for k, r in Cf.rules {
            if (r.act != 0) {
                if (MsgBox("Scanning again clears the conversions you have chosen so far.`n`nScan again?", "Bangla Document Converter", 0x124) != "Yes")
                    return
                break
            }
        }
    }
    CfBusy(true)
    try {
        t0 := A_TickCount
        Cf.scanIds := ids
        Cf.effCache := Map()
        Cf.baseCache := Map()
        Cf.paraKeys := Map()
        Cf.partKeys := Map()
        CfClearResults()
        Cf.convT0 := 0
        CfProgress(1, "Reading")
        nparts := 0
        if (Cf.kind = "txt") {
            CfTxtEntry()
        } else {
            CfLoadTheme()
            CfBuildStyles()
            Cf.paraSeq := 0
            parts := CfParts(Cf.work)
            nparts := parts.Length
            CfRunParts(parts, false, 6, 100)
            if (Cf.queue.Length > 0)
                CfScanQueue()                              ; the other files of the batch
        }
        Cf.scanned := true
        CfFillList()
        names := ""
        for id in ids {
            for dim in CfDims {
                if (dim[1] = id)
                    names .= (names = "" ? "" : ", ") . dim[2]
            }
        }
        if (Cf.kind = "txt")
            CfLog("Scanned the text.")
        else
            CfLog("Scanned " . nparts . " part(s) in " . (A_TickCount - t0) . " ms. Looked at: " . names . ". " . Cf.fonts.Count . " different combination(s) found" . (Cf.queue.Length > 0 ? " in " . (Cf.queue.Length + 1) . " files" : "") . ".")
        CfProgressReset()
        Cf.sb.SetText("  " . Cf.fonts.Count . " combination(s) found. Pick one or more (Ctrl / Shift + click) in the list and choose what to do with them.")
        CfSaveSettings()
    } catch as e {
        MsgBox(CfErrText(e), "Bangla Document Converter", 0x10)
        Cf.sb.SetText("  The scan failed.")
        CfProgressReset()
    }
    CfBusy(false)
}

; ---- converting -------------------------------------------------------------
CfConvert(*) {
    if (Cf.file = "" || (Cf.kind != "txt" && Cf.work = "")) {
        MsgBox("Open a document first.", "Bangla Document Converter", 0x30)
        return
    }
    if !Cf.scanned {
        MsgBox("Tick what to scan, press Scan, and choose what to do with the results first.", "Bangla Document Converter", 0x30)
        return
    }
    todo := 0
    for name, rule in Cf.rules {
        if (rule.act = 0)
            continue
        name := StrReplace(name, "|", " / ")
        if (Cf.kind = "txt") {
            if (rule.act = 4) {
                MsgBox("A plain text file has no fonts. Choose ANSI to Unicode, Unicode to ANSI or ANSI to ANSI.", "Bangla Document Converter", 0x30)
                return
            }
        } else {
            if ((rule.act < 4 && rule.font = "") || (rule.act = 4 && rule.font = "" && rule.sizeMode = 0)) {
                MsgBox("Choose a target font" . (rule.act = 4 ? " or a size change" : "") . " for: " . name, "Bangla Document Converter", 0x30)
                return
            }
            if (rule.sizeMode > 0 && rule.sizeVal = 0 && rule.sizeMode = 2) {
                MsgBox("The size for " . name . " is 0. Enter a size in points.", "Bangla Document Converter", 0x30)
                return
            }
        }
        todo += 1
    }
    if (todo = 0) {
        MsgBox("Nothing to do yet. Select a font and choose an action for it.", "Bangla Document Converter", 0x30)
        return
    }
    if (Cf.queue.Length > 0) {
        CfConvertBatch()
        return
    }
    SplitPath(Cf.file, , &dir, , &nm)
    if (Cf.lastSaveDir != "" && DirExist(Cf.lastSaveDir))
        dir := Cf.lastSaveDir
    out := FileSelect("S16", dir . "\" . nm . "_converted." . Cf.outExt, "Save the converted document as", "Converted file (*." . Cf.outExt . ")")
    if (out = "")
        return
    if (StrLower(SubStr(out, -(StrLen(Cf.outExt) + 1))) != "." . Cf.outExt)
        out .= "." . Cf.outExt
    if (StrLower(out) = StrLower(Cf.file)) {
        MsgBox("Please save under a different name. The original file is never overwritten.", "Bangla Document Converter", 0x30)
        return
    }
    CfBusy(true)
    try {
        t0 := A_TickCount
        Cf.convT0 := t0
        Cf.nRuns := 0
        Cf.nChars := 0
        if (Cf.kind = "txt")
            CfConvertTxt(out)
        else
            CfConvertDoc(out)
        t2 := A_TickCount
        Cf.convT0 := 0
        CfLog("Saved: " . out)
        SplitPath(out, , &od)
        Cf.lastSaveDir := od
        CfSaveSettings()
        CfLog("Converted " . (Cf.kind = "txt" ? Cf.nChars . " character(s)" : Cf.nRuns . " run(s), " . Cf.nChars . " character(s)") . " in " . Round((t2 - t0) / 1000, 1) . " s.")
        Cf.sb.SetText("  Done. Converted in " . Round((t2 - t0) / 1000, 1) . " s.")
        CfBusy(false)
        if (MsgBox("Saved:`n" . out . "`n`nShow it in Explorer?", "Bangla Document Converter", 0x24) = "Yes")
            Run('explorer.exe /select,"' . out . '"')
    } catch as e {
        Cf.convT0 := 0
        CfBusy(false)
        MsgBox("Conversion failed:`n" . CfErrText(e), "Bangla Document Converter", 0x10)
        Cf.sb.SetText("  Conversion failed.")
        CfProgressReset()
    }
}

; Word / PowerPoint: convert the parts of a copy of the unpacked file, then pack it again.
CfConvertDoc(out) {
    w2 := A_Temp . "\BFC_out_" . A_TickCount
    try {
        CfProgress(1, "Preparing")
        DirCreate(w2)
        ; Only the parts that have something to convert are copied and processed. Every other entry of the
        ; original file (images, fonts, other parts ...) is copied straight into the new file when packing.
        todo := []
        for part in CfParts(Cf.work) {
            pn := CfPartName(part)
            if !CfPartActive(pn)
                continue
            dst := w2 . "\" . pn
            SplitPath(dst, , &dd)
            DirCreate(dd)
            FileCopy(part, dst, 1)
            todo.Push(dst)
        }
        Cf.paraSeq := 0
        CfLog("Convert: " . todo.Length . " part(s) hold text that has a conversion set (of " . CfParts(Cf.work).Length . " read).")
        for tp in todo
            CfLog("   part: " . CfPartName(tp))
        if (todo.Length = 0)
            throw Error("None of the document parts matched the rows you set up, so nothing could be converted.`nScan again, choose an action (and a font) for the rows, then press Convert.`nThe Log tab lists what was found.")
        CfRunParts(todo, true, 4, 90)
        CfLog("Convert: " . Cf.nRuns . " run(s) changed.")
        if (Cf.nRuns = 0)
            throw Error("The document was read, but no text run was changed, so no file was saved.`nThe chosen rows probably do not match the text (for example ANSI to Unicode on Bangla Unicode text, or the reverse).`nCheck the action of each row, then try again.")
        CfProgress(92, "Saving")
        src := Cf.file
        if (Cf.tmpDoc != "")
            src := Cf.tmpDoc                            ; a .doc / .odt / .ppt ... file was converted first
        SplitPath(src, , , &srcExt)
        SplitPath(out, , , &outExt)
        if (Cf.tmpDoc != "" && StrLower(outExt) != StrLower(srcExt)) {      ; opened as .doc / .odt / .ppt ...: pack as .docx / .pptx, then save in the original format
            pk := A_Temp . "\BFC_pk_" . A_TickCount . "." . srcExt
            if !(CfRunPS(Cf.psZip, src, w2, pk) && FileExist(pk))
                throw Error("Could not write the output file.")
            CfProgress(96, "Saving as ." . outExt)
            ok := (StrLower(srcExt) = "pptx") ? CfFromPptx(pk, out) : CfFromDocx(pk, out)
            try FileDelete(pk)
            if !(ok && FileExist(out))
                throw Error("Could not save as ." . outExt . ". Microsoft " . (StrLower(srcExt) = "pptx" ? "PowerPoint" : "Word") . " (or LibreOffice) is needed to write that format.")
        } else if !(CfRunPS(Cf.psZip, src, w2, out) && FileExist(out)) {
            throw Error("Could not write the output file.")
        }
        CfProgress(100, "Done")
    } finally {
        try DirDelete(w2, true)
    }
}

; does this part use a font that has a conversion set?
CfPartActive(pn) {
    ks := Cf.partKeys.Get(pn, "")
    if !IsObject(ks)
        return false
    for k, v in ks {
        r := Cf.rules.Get(k, "")
        if (IsObject(r) && r.act != 0)
            return true
    }
    return false
}

; Plain text: converted line by line.
CfConvertTxt(out) {
    rule := ""
    for k, r in Cf.rules {
        if (r.act != 0) {
            rule := r
            break
        }
    }
    lines := StrSplit(Cf.txtText, "`n")
    n := lines.Length
    Cf.tick := A_TickCount
    CfProgress(2, "Converting")
    res := ""
    for i, ln in lines {
        if (A_TickCount - Cf.tick > 120) {
            Cf.tick := A_TickCount
            CfProgress(2 + 88 * i / n, "Converting")
            Sleep(-1)
        }
        res .= (i > 1 ? "`n" : "") . CfConvertText(rule, ln)
    }
    CfProgress(92, "Saving")
    enc := (rule.act = 1) ? "UTF-8" : "CP1252"            ; Unicode result, or an ANSI (Bijoy ...) result
    f := FileOpen(out, "w", enc)
    f.Write(res)
    f.Close()
    Cf.nRuns := 1
    Cf.nChars := StrLen(Cf.txtText)
    CfProgress(100, "Done")
}

; ---- layout -----------------------------------------------------------------
; Left : file path row, filter row, font list (70 %), splitter, Log / Preview tabs (30 %).
; Right: a fixed-width properties panel, sections stacked top to bottom:
;        File (Open / Remove), Action, Encoding, Target font, Size, Preview text size, Convert.
CfSize(g, minMax, w, h) {
    if (minMax = -1)
        return
    Cf.cw := w
    Cf.ch := h
    CfLayout()
}

; The right-hand properties panel . On its own (partial = true) only this
; panel is moved and repainted: painting is switched off while the controls move, then the panel's area is
; redrawn once, so nothing flickers and the list / tabs on the left are left alone.
CfLayoutRight(partial := false) {
    w := Cf.cw
    h := Cf.ch
    if (w < 1 || h < 1)
        return
    d := A_ScreenDPI / 96
    m := Round(10 * d)
    gap := Round(6 * d)
    bh := Round(26 * d)
    eh := Round(24 * d)
    lh := Round(18 * d)
    sbh := 0
    Cf.sb.GetPos(, , , &sbh)
    pw := Round(250 * d)
    px := w - m - pw
    if partial
        SendMessage(0x000B, 0, 0, Cf.gui.Hwnd)           ; WM_SETREDRAW off
    try {
        ; ---- right: properties panel ----
        y := m
        half := (pw - gap) // 2
        Cf.hdFile.Move(px, y, pw, lh)
        Cf.btnOpen.Move(px, y + Round(20 * d), half, bh)
        Cf.btnRemove.Move(px + half + gap, y + Round(20 * d), pw - half - gap, bh)
        y += Round(54 * d)
        Cf.sep0.Move(px, y - Round(6 * d), pw, 2)

        ; scan options: two columns of tick boxes, then the Scan button
        wsb := Round(52 * d)
        Cf.hdScan.Move(px, y, pw, lh)
        cbh := Round(19 * d)
        ycb := y + Round(22 * d)
        cw1 := Round(58 * d)                               ; 3 columns x 3 rows: [Font Size Style] [Underline Strikethrough Highlight] [Language]
        cw2 := Round(102 * d)
        cw3 := pw - cw1 - cw2
        cpad := Round(4 * d)                               ; small gap so the tick boxes don't touch the left border
        colX := [cpad, cw1 + cpad, cw1 + cw2 + cpad]
        colW := [cw1 - cpad, cw2, cw3 - cpad]
        for i, dim in CfDims {
            cc := (i - 1) // 3 + 1
            Cf.cbScan[dim[1]].Move(px + colX[cc], ycb + Mod(i - 1, 3) * cbh, colW[cc], cbh)
        }
        yScan := ycb + 3 * cbh + Round(4 * d)               ; one line:  [All]  [ Scan ]  [None]
        Cf.btnScanAll.Move(px, yScan, wsb, Round(28 * d))
        Cf.btnScan.Move(px + wsb + gap, yScan, pw - 2 * wsb - 2 * gap, Round(28 * d))
        Cf.btnScanNone.Move(px + pw - wsb, yScan, wsb, Round(28 * d))
        y += Round(119 * d)
        Cf.sepS.Move(px, y - Round(6 * d), pw, 2)

        wAct := Round(145 * d)                             ; Action and Method share one line
        Cf.hdAct.Move(px, y, wAct, lh)
        Cf.ddAct.Move(px, y + Round(20 * d), wAct)
        Cf.ddMethod.Move(px + wAct + gap, y + Round(20 * d), pw - wAct - gap)
        y += Round(54 * d)
        Cf.sep1.Move(px, y - Round(6 * d), pw, 2)

        Cf.hdEnc.Move(px, y, pw, lh)
        Cf.lbl2.Move(px, y + Round(20 * d), pw, lh)
        Cf.ddMap.Move(px, y + Round(36 * d), pw)
        Cf.lbl6.Move(px, y + Round(68 * d), pw, lh)
        Cf.ddMap2.Move(px, y + Round(84 * d), pw)
        y += Round(118 * d)
        Cf.sep2.Move(px, y - Round(6 * d), pw, 2)

        Cf.hdFont.Move(px, y, pw, lh)
        Cf.cbFont.Move(px, y + Round(20 * d), pw)
        y += Round(54 * d)
        Cf.sep3.Move(px, y - Round(6 * d), pw, 2)

        ; size: the mode drop-down, the number box and "pt" share one line
        wSzDd := Round(150 * d)
        wSzEd := Round(56 * d)
        Cf.hdSize.Move(px, y, pw, lh)
        Cf.ddSize.Move(px, y + Round(20 * d), wSzDd)
        Cf.edSize.Move(px + wSzDd + gap, y + Round(20 * d), pw - wSzDd - gap, eh)      ; the number box takes all the free width
        y += Round(58 * d)
        Cf.sep4.Move(px, y - Round(6 * d), pw, 2)

        ; (the preview text size buttons now live in the filter area on the left)

        ; Apply to selected | Apply to all: 50 % each, right above Convert
        Cf.btnApplySel.Move(px, y + Round(2 * d), half, bh)
        Cf.btnApplyAll.Move(px + half + gap, y + Round(2 * d), pw - half - gap, bh)
        Cf.btnConv.Move(px, y + Round(2 * d) + bh + gap, pw, Round(34 * d))
    } finally {
        if partial {
            SendMessage(0x000B, 1, 0, Cf.gui.Hwnd)       ; WM_SETREDRAW on
            rc := Buffer(16, 0)
            NumPut("Int", px - 4, "Int", 0, "Int", w, "Int", Max(1, h - sbh), rc)
            DllCall("RedrawWindow", "Ptr", Cf.gui.Hwnd, "Ptr", rc, "Ptr", 0, "UInt", 0x185)
        }
    }
}

CfLayout(redraw := true) {
    w := Cf.cw
    h := Cf.ch
    if (w < 1 || h < 1)
        return
    d := A_ScreenDPI / 96
    m := Round(10 * d)
    gap := Round(6 * d)
    bh := Round(26 * d)
    eh := Round(24 * d)
    lh := Round(18 * d)
    sbh := 0
    Cf.sb.GetPos(, , , &sbh)
    pw := Round(250 * d)                           ; width of the properties panel
    px := w - m - pw
    lw := px - gap - m                             ; width of the left side

    ; status bar: text part on the left, progress part (with the progress bar) on the very right
    partW := Round(230 * d)
    gripW := Round(18 * d)
    Cf.sb.SetParts(Max(Round(100 * d), w - partW))
    pbH := Max(8, sbh - Round(8 * d))
    DllCall("SetWindowPos", "Ptr", Cf.pb.Hwnd, "Ptr", 0   ; HWND_TOP; x / y are relative to the status bar
        , "Int", Max(Round(100 * d), w - partW) + Round(4 * d), "Int", Max(0, (sbh - pbH) // 2)
        , "Int", partW - gripW - Round(8 * d), "Int", pbH, "UInt", 0x40)   ; SWP_SHOWWINDOW
    DllCall("RedrawWindow", "Ptr", Cf.pb.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x105)

    CfLayoutRight(false)

    ; ---- left: file path row ----
    wCnt := Round(110 * d)
    Cf.edFile.Move(m, m, Max(Round(60 * d), lw - wCnt - gap), lh)   ; same line as the "File" heading on the right
    Cf.lblCount.Move(m + lw - wCnt, m, wCnt, lh)                     ; "n of n shown" at the right end of this line

    ; ---- left: filter rows ----
    ; row 1: [text to find] [in which column] [type]      row 2: min / max characters, count
    y2 := m + Round(20 * d)                        ; same line (top and height) as the Open button
    gapS := Round(4 * d)                           ; tighter spacing below
    wBy := Round(130 * d)
    wType := Round(120 * d)
    wMinL := Round(62 * d)
    wMin := Round(52 * d)
    wVal := Round(150 * d)
    wFind := Max(Round(70 * d), lw - (wBy + wVal + wType + 3 * gap))
    Cf.edFind.Move(m, y2, wFind, bh)
    dh := 0
    Cf.ddBy.GetPos(, , , &dh)
    yd := y2 + Max(0, (bh - dh) // 2)              ; centre the drop-downs on the same line
    x := m + wFind + gap
    Cf.ddBy.Move(x, yd, wBy)
    x += wBy + gap
    Cf.ddVal.Move(x, yd, wVal)                     ; value list of the chosen column, right next to it
    x += wVal + gap
    Cf.ddType.Move(x, yd, wType)
    y3 := y2 + bh + gapS

    ; ---- left: list, splitter, tabs ----
    spH := Round(6 * d)
    minLv := Round(90 * d)
    minTab := Round(110 * d)
    lvTop := y3
    avail := h - sbh - gap - lvTop
    tbH := eh + 2 * gapS                               ; the filter / preview toolbar sits under the list
    if !Cf.tabUser                                     ; until the splitter is dragged: Log / Preview = 40 %, list + toolbar = 60 %
        Cf.tabH := Round(avail * 0.40)
    tabH := Min(Max(Cf.tabH, minTab), Max(minTab, avail - spH - tbH - minLv))
    lvH := avail - spH - tbH - tabH
    Cf.lv.Move(m, lvTop, lw, lvH)
    yT := lvTop + lvH + gapS
    x := m
    Cf.lblMin.Move(x, yT + Round(4 * d), wMinL, lh)
    x += wMinL
    Cf.edMin.Move(x, yT, wMin, eh)
    x += wMin + gap
    Cf.lblMax.Move(x, yT + Round(4 * d), wMinL, lh)
    x += wMinL
    Cf.edMax.Move(x, yT, wMin, eh)
    x += wMin + gap
    wClr := Round(100 * d)
    Cf.btnClearF.Move(x, yT, wClr, eh)
    x += wClr - wMin                               ; keep the preview-size "never over" check below working

    ; preview text size, right-aligned on the Min / Max line:  Preview size:  [A-] [A+]  21 pt  [Reset]
    gp := Round(2 * d)                             ; tight spacing between the preview controls
    wPl := Round(76 * d)
    wPb := Round(30 * d)
    wPv := Round(42 * d)
    wPr := Round(52 * d)
    xp := m + lw - (wPl + 2 * wPb + wPv + wPr + 3 * gp)
    xp := Max(xp, x + wMin + gap)                  ; never over the Max box / Clear filters button
    Cf.hdPrev.Move(xp, yT + Round(4 * d), wPl, lh)
    xp += wPl
    Cf.btnPrevDn.Move(xp, yT, wPb, eh)
    xp += wPb + gp
    Cf.btnPrevUp.Move(xp, yT, wPb, eh)
    xp += wPb + gp
    Cf.lblPrevSz.Move(xp, yT + Round(4 * d), wPv, lh)
    xp += wPv + gp
    Cf.btnPrevReset.Move(xp, yT, wPr, eh)

    Cf.split.Move(m, lvTop + lvH + tbH, lw, spH)
    yTab := lvTop + lvH + tbH + spH
    Cf.tab.Move(m, yTab, lw, tabH)
    CfFitTabs()

    ; the two edit boxes sit inside the tab's display area
    rc := Buffer(16, 0)
    NumPut("Int", 0, "Int", 0, "Int", lw, "Int", tabH, rc)
    SendMessage(0x1328, 0, rc, Cf.tab.Hwnd)           ; TCM_ADJUSTRECT: window rect -> display rect
    ex := m + NumGet(rc, 0, "Int")
    ey := yTab + NumGet(rc, 4, "Int")
    ew := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
    ehh := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
    Cf.edLog.Move(ex, ey, ew, ehh)
    Cf.edPrev.Move(ex, ey, ew, ehh)
    Cf.edHelp.Move(ex, ey, ew, ehh)

    if redraw     ; repaint everything once: avoids left-over pieces of moved controls
        DllCall("RedrawWindow", "Ptr", Cf.gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
}

; the Log / Preview / Help tabs share the full width of the tab control equally
CfFitTabs() {
    tab := Cf.tab.Hwnd
    n := SendMessage(0x1304, 0, 0, tab)                 ; TCM_GETITEMCOUNT
    if (n < 1)
        return
    Cf.tab.Opt("+0x400 -0x200")                         ; TCS_FIXEDWIDTH on, TCS_MULTILINE off (one row, never wraps)
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", tab, "Ptr", rc)
    tw := NumGet(rc, 8, "Int")
    if (tw < 50)
        return
    ir := Buffer(16, 0)
    SendMessage(0x130A, 0, ir, tab)                     ; TCM_GETITEMRECT: keep the current tab height
    th := NumGet(ir, 12, "Int") - NumGet(ir, 4, "Int")
    if (th < 10)
        th := Round(24 * A_ScreenDPI / 96)
    SendMessage(0x1329, 0, ((th & 0xFFFF) << 16) | (((tw - 4) // n) & 0xFFFF), tab)   ; TCM_SETITEMSIZE
}

; ---- dragging the splitter between the list and the Log / Preview tabs -------
CfSplitDown(wParam, lParam, msg, hwnd) {
    if (!IsObject(Cf.split) || hwnd != Cf.split.Hwnd)
        return
    d := A_ScreenDPI / 96
    gap := Round(6 * d)
    spH := Round(6 * d)
    sbh := 0
    Cf.sb.GetPos(, , , &sbh)
    pt := Buffer(8, 0)
    DllCall("SetCapture", "Ptr", hwnd)
    while GetKeyState("LButton", "P") {
        DllCall("GetCursorPos", "Ptr", pt)
        DllCall("ScreenToClient", "Ptr", Cf.gui.Hwnd, "Ptr", pt)
        my := NumGet(pt, 4, "Int")
        Cf.tabH := (Cf.ch - sbh - gap) - (my + spH // 2)
        Cf.tabUser := true                              ; from now on the user's height is kept
        CfLayout(false)
        Sleep(15)
    }
    DllCall("ReleaseCapture")
    CfLayout(true)
    return 0
}

CfSetCursor(wParam, lParam, msg, hwnd) {
    if (IsObject(Cf.split) && wParam = Cf.split.Hwnd) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32645, "Ptr"))   ; up/down arrows
        return 1
    }
}

; ---------------------------------------------------------------------------
;  Settings: %AppData%\Bangla Keyboard\Docs Converter.dat
; ---------------------------------------------------------------------------
CfSettingsFile() {
    dir := A_AppData . "\Bangla Keyboard\"
    f := dir . "Docs Converter.dat"
    if !FileExist(f) {
        for prev in ["file_converter_settings.ini", "dcv_cfg.dat"] {        ; names used by earlier builds
            if FileExist(dir . prev) {
                try FileMove(dir . prev, f)
                break
            }
        }
    }
    return f
}

CfIni(sec, key, def := "") {
    try return IniRead(CfSettingsFile(), sec, key, def)
    return def
}

CfLoadSettings() {
    w := CfIni("Window", "W2")
    h := CfIni("Window", "H2")
    if (IsInteger(w) && IsInteger(h)) {
        Cf.winW := Min(A_ScreenWidth, Max(820, Integer(w)))
        Cf.winH := Min(A_ScreenHeight, Max(570, Integer(h)))
    }
    for dim in CfDims
        Cf.scanOpt[dim[1]] := (dim[1] = "font" || dim[1] = "size")      ; always the same start: Font and Size
    try IniDelete(CfSettingsFile(), "Scan")                ; older builds kept these: not any more
    try IniDelete(CfSettingsFile(), "Preview")
    Cf.lastOpenDir := CfIni("Folders", "LastOpen")
    Cf.lastSaveDir := CfIni("Folders", "LastSave")
    try IniDelete(CfSettingsFile(), "FontRules")        ; plans and encodings of earlier documents are not kept
    try IniDelete(CfSettingsFile(), "Encoding")
}

CfSaveSettings(*) {
    try {
        f := CfSettingsFile()
        SplitPath(f, , &d)
        DirCreate(d)
        if !FileExist(f)
            FileOpen(f, "w", "UTF-16").Close()            ; UTF-16 with BOM, so folder names with any letters are kept
        IniWrite(Cf.lastOpenDir, f, "Folders", "LastOpen")
        IniWrite(Cf.lastSaveDir, f, "Folders", "LastSave")
        if (IsObject(Cf.gui) && WinGetMinMax(Cf.gui.Hwnd) = 0) {
            Cf.gui.GetClientPos(, , &w, &h)
            IniWrite(w, f, "Window", "W2")
            IniWrite(h, f, "Window", "H2")
        }
    }
}

; ---------------------------------------------------------------------------
;  Help tab
; ---------------------------------------------------------------------------
CfHelpText() {
    t := "HOW TO USE`r`n"
    t .= "`r`n1. Open a file (Open button, or drop it on this window). You can pick or drop several files at once. Nothing is scanned yet.`r`n"
    t .= "2. On the right, under Scan options, tick what you want to look at, then press Scan.`r`n"
    t .= "3. Select a row in the list, then choose an action: ANSI to Unicode, Unicode to ANSI, ANSI to ANSI, or Change Font/Size.`r`n"
    t .= "4. Choose the encoding, the target font and the size. Repeat for other rows. The Plan column shows what will happen.`r`n"
    t .= "5. Check the Preview tab, then press Convert and save as...`r`n"
    t .= "`r`nEncodings: Script or Table`r`n"
    t .= "   Script: - custom conversion. A script (.json / .menc, in Library\Encoding Script) holds a full set of rules (conjuncts, vowel signs, reph, corrections), the same rules the keyboard uses when it types. Use it when you want more control over the result.`r`n"
    t .= "   Table: - standard (universal) conversion. A table (.txt / .een, in Library\Encoding Table) is a plain list of ANSI and Unicode pairs. Use it for ordinary, general conversion.`r`n"
    t .= "   Method - the box next to Action. Both lists every encoding, Scripts lists only the scripts, Table lists only the tables. It is kept for each row, like the other settings.`r`n"
    t .= "`r`nThe original file is never changed: the result is always saved as a new file.`r`n"
    t .= "`r`n`r`nSCAN OPTIONS`r`n"
    t .= "`r`nThe scan runs only when you press Scan, never when a file is opened. Tick one or more:`r`n"
    t .= "   Font - the font name.`r`n"
    t .= "   Size - the text size in points.`r`n"
    t .= "   Style - Regular, Bold, Italic or Bold Italic, plus other variants: All caps, Small caps.`r`n"
    t .= "   Underline, Strikethrough - none, single, double ...`r`n"
    t .= "   Highlight - the marker colour behind the text.`r`n"
    t .= "   Language - the language the text is marked with.`r`n"
    t .= "   Colour - the text colour.`r`n"
    t .= "   Spacing - extra or reduced space between the letters.`r`n"
    t .= "`r`nThe list gets one column for each ticked option and one row for each different combination, so a conversion is set per combination (for example only the Bold text of one font). To change several rows at once, select them (Ctrl + click, Shift + click or Ctrl + A): whatever you change on the right is applied to all selected rows, and their other settings stay as they are. Use All / None to tick or clear every box. Scanning again with other options replaces the list.`r`n"
    t .= "In PowerPoint, a value the text takes from its slide or master is shown as (inherited).`r`n"
    t .= "`r`n`r`nSELECTING AND COPYING SETTINGS`r`n"
    t .= "`r`nRight-click the list: Select all, Invert selection, Select all rows with the same font / size / style / plan, Copy settings of this row, Paste settings to the selected rows, and Reset the selected rows to Keep as is.`r`n"
    t .= "The Apply to all button (next to Action) copies the settings now shown to every row the list shows, so filter first (for example type a font name) and apply.`r`n"
    t .= "`r`n`r`nSEVERAL FILES AT ONCE`r`n"
    t .= "`r`nOpen or drop several files (all Word / PowerPoint, or all .txt). The first one is shown; Scan reads all of them and puts every combination in the list. Set the plan once, press Convert and choose a folder: every file is saved there as name_converted (an existing file is never overwritten). A file that cannot be read is skipped and noted in the Log.`r`n"
    t .= "`r`nFILTER`r`n"
    t .= "`r`nType in the first box to filter the list, and choose in which column to look (the boxes follow your scan options). Choosing a column opens a second box with every value found in that column (taken from the scanned data that the other filters still show). Pick a value and the list shows only the rows with that value, with all their columns. Filters on different columns work together, a * marks a filtered column, and Clear filters removes them all. Type filters Bangla Unicode / ANSI text, and Min / Max chars limit by amount of text.`r`n"
    t .= "`r`n`r`nSUPPORTED FILE TYPES`r`n"
    t .= "`r`nWord (read and saved in the same format)`r`n"
    t .= "   .docx  .docm  .dotx  .dotm`r`n"
    t .= "`r`nWord, older / other formats (first converted to .docx, the result is saved as .docx)`r`n"
    t .= "   .doc  .dot  .rtf  .odt  .wps`r`n"
    t .= "   Needs Microsoft Word, or LibreOffice, installed on this PC.`r`n"
    t .= "`r`nPowerPoint (read and saved in the same format)`r`n"
    t .= "   .pptx  .pptm  .potx  .potm  .ppsx  .ppsm`r`n"
    t .= "`r`nPowerPoint, older / other formats (first converted to .pptx, the result is saved as .pptx)`r`n"
    t .= "   .ppt  .pot  .pps  .odp`r`n"
    t .= "   Needs Microsoft PowerPoint, or LibreOffice, installed on this PC.`r`n"
    t .= "`r`nPlain text (encoding conversion only, a text file has no fonts)`r`n"
    t .= "   .txt`r`n"
    t .= "`r`nNot supported: Excel (.xlsx .xls), LibreOffice Calc (.ods), PDF.`r`n"
    t .= "`r`n`r`nWHAT IS CONVERTED`r`n"
    t .= "`r`nWord: body text, tables, text boxes, shapes and groups, headers, footers, footnotes, endnotes, comments, SmartArt and chart text.`r`n"
    t .= "PowerPoint: slides (text, tables, shapes, groups), speaker notes, SmartArt, chart text, slide masters and layouts.`r`n"
    t .= "`r`n`r`nSETTINGS`r`n"
    t .= "`r`nSaved automatically in:`r`n   " . CfSettingsFile() . "`r`n"
    t .= "Only the window size and the last folders are remembered. Nothing about a document is kept: every newly opened document starts fresh (Font and Size ticked, Keep as is, no filters, normal preview size), and you set it up as you need.`r`n"
    return t
}

CfStart() {
    Cf.mapFiles := CfFindMaps()
    if (Cf.mapFiles.Length = 0) {
        MsgBox("No encoding found.`nPut an encoding script (.json or .menc) in Library\Encoding Script`nor a table (.txt or .een) in Library\Encoding Table.", "Bangla Document Converter", 0x10)
        ExitApp()
    }
    for it in Cf.mapFiles
        Cf.mapNames.Push(it["name"])
    Cf.defMap := 1
    Cf.defMap2 := (Cf.mapFiles.Length > 1 ? 2 : 1)
    Cf.defMethod := 0
    nLib := 0
    for it in Cf.mapFiles {
        if (it["kind"] = "lib")
            nLib += 1
    }
    Cf.methodUsable := (nLib > 0 && nLib < Cf.mapFiles.Length)     ; the Method box only has a choice when scripts and tables both exist
    Cf.mapView := CfMethodView(0)
    Cf.viewMethod := 0
    CfLoadSettings()
    Cf.rules.CaseSense := "Off"
    CfWriteScripts()
    fontList := CfFontNames()

    d0 := A_ScreenDPI / 96
    g := Gui("+Resize +0x2000000 +MinSize" . Round(800 * d0) . "x" . Round(570 * d0), "Bangla Document Converter")      ; minimum height 570
    Cf.gui := g
    g.SetFont("s9", "Segoe UI")

    ; file section (top of the right panel), created first so Tab starts on Open
    Cf.hdFile := g.Add("Text", "x700 y10 w250", "File")
    Cf.btnOpen := g.Add("Button", "x700 y32 w120 h26", "Open")
    Cf.btnRemove := g.Add("Button", "x830 y32 w120 h26 Disabled", "Remove")
    Cf.sep0 := g.Add("Text", "x700 y62 w250 h2 0x10")

    ; scan options (right panel, under the Open button): nothing is scanned until Scan is pressed
    Cf.hdScan := g.Add("Text", "x700 y70 w120", "Scan options")
    Cf.btnScanAll := g.Add("Button", "x830 y68 w40 h22", "All")
    Cf.btnScanNone := g.Add("Button", "x874 y68 w40 h22", "None")
    for dim in CfDims {
        cb := g.Add("Checkbox", "x700 y96 w120 h19", dim[3])
        cb.Value := Cf.scanOpt.Get(dim[1], 0) ? 1 : 0
        Cf.cbScan[dim[1]] := cb
    }
    Cf.btnScan := g.Add("Button", "x700 y240 w250 h28 Disabled", "Scan")
    Cf.sepS := g.Add("Text", "x700 y272 w250 h2 0x10")

    ; left side (exact positions are set by CfLayout)
    Cf.edFile := g.Add("Text", "x10 y10 w640 h26 0x200 0x8000", "No document open")   ; plain text: centred vertically, long paths shortened in the middle
    Cf.edFind := g.Add("Edit", "x10 y42 w180 h24", "")
    CfSetCue(Cf.edFind, "Filter the list ...")
    Cf.ddBy := g.Add("DropDownList", "x196 y42 w130 Choose1", ["Any column"])
    Cf.ddType := g.Add("DropDownList", "x332 y42 w130 Choose1", Cf.typeNames)
    Cf.lblMin := g.Add("Text", "x332 y46 w62", "Min chars")
    Cf.edMin := g.Add("Edit", "x396 y42 w52 h24 Number", "0")
    Cf.lblMax := g.Add("Text", "x454 y46 w62", "Max chars")
    Cf.edMax := g.Add("Edit", "x518 y42 w52 h24 Number", "")
    CfSetCue(Cf.edMax, "no limit")
    Cf.lblCount := g.Add("Text", "x540 y46 w110 Right", "")
    Cf.ddVal := g.Add("DropDownList", "x10 y96 w300 Disabled Choose1", ["(pick a column first)"])
    Cf.btnClearF := g.Add("Button", "x320 y96 w100 h24 Disabled", "Clear filters")
    Cf.lv := g.Add("ListView", "x10 y72 w640 h200 +Multi NoSort Grid", ["Font", "Size", "Type", "Runs", "Characters", "Plan"])
    CfBuildColumns()                                      ; the columns follow the ticked scan options
    CfSortArrows()                                        ; show the default sort (Characters, biggest first)
    Cf.split := g.Add("Text", "x10 y276 w640 h6 0x100 BackgroundD4D4D4")
    Cf.tab := g.Add("Tab3", "x10 y286 w640 h250", ["Log", "Preview", "Help"])
    Cf.tab.UseTab(1)
    Cf.edLog := g.Add("Edit", "x14 y316 w630 h210 ReadOnly Multi +VScroll")
    Cf.edLog.SetFont("s9", "Consolas")
    Cf.tab.UseTab(2)
    Cf.edPrev := g.Add("Edit", "x14 y316 w630 h210 ReadOnly Multi +VScroll")
    Cf.edPrev.SetFont("s" . Cf.prevSize, Cf.prevFont)
    Cf.tab.UseTab(3)
    Cf.edHelp := g.Add("Edit", "x14 y316 w630 h210 ReadOnly Multi +VScroll Limit400000")    ; same kind of box as the guide in Layout Builder
    Cf.edHelp.SetFont("s10", "Nirmala UI")
    Cf.edHelp.Value := CfHelpText()
    Cf.tab.UseTab()
    SendMessage(0xC5, 0, 0, Cf.edLog.Hwnd)               ; EM_SETLIMITTEXT: no 32 K limit, the preview can be long
    SendMessage(0xC5, 0, 0, Cf.edPrev.Hwnd)

    ; right side: properties panel (plain labels and lines, no group boxes)
    Cf.hdAct := g.Add("Text", "x700 y10 w120", "Action")
    Cf.btnApplySel := g.Add("Button", "x700 y422 w120 h26 Disabled", "Apply to selected")
    Cf.btnApplyAll := g.Add("Button", "x830 y422 w120 h26 Disabled", "Apply to all")
    Cf.ddAct := g.Add("DropDownList", "x700 y32 w145 Choose1", ["Keep as is", "ANSI to Unicode", "Unicode to ANSI", "ANSI to ANSI", "Change Font/Size"])
    Cf.ddMethod := g.Add("DropDownList", "x851 y32 w99 Choose1", ["Both", "Scripts", "Table"])
    Cf.sep1 := g.Add("Text", "x700 y62 w250 h2 0x10")
    Cf.hdEnc := g.Add("Text", "x700 y68 w250", "Encoding")
    Cf.lbl2 := g.Add("Text", "x700 y90 w250", "ANSI encoding")
    Cf.ddMap := g.Add("DropDownList", "x700 y108 w250 Choose" . Cf.defMap, Cf.mapNames)
    Cf.lbl6 := g.Add("Text", "x700 y142 w250", "To encoding")
    Cf.ddMap2 := g.Add("DropDownList", "x700 y160 w250 Choose" . Cf.defMap2, Cf.mapNames)
    Cf.sep2 := g.Add("Text", "x700 y192 w250 h2 0x10")
    Cf.hdFont := g.Add("Text", "x700 y198 w250", "Target font")
    Cf.cbFont := g.Add("ComboBox", "x700 y220 w250 R15", fontList)
    Cf.sep3 := g.Add("Text", "x700 y250 w250 h2 0x10")
    Cf.hdSize := g.Add("Text", "x700 y256 w250", "Size")
    Cf.ddSize := g.Add("DropDownList", "x700 y278 w150 Choose1", ["Keep size", "Change by (points)", "Set to (points)"])
    Cf.edSize := g.Add("Edit", "x856 y278 w56 h24", "0")
    Cf.sep4 := g.Add("Text", "x700 y350 w250 h2 0x10")
    Cf.hdPrev := g.Add("Text", "x700 y356 w84", "Preview size:")
    Cf.btnPrevDn := g.Add("Button", "x700 y378 w34 h24", "A-")
    Cf.btnPrevUp := g.Add("Button", "x746 y378 w34 h24", "A+")
    Cf.lblPrevSz := g.Add("Text", "x792 y383 w82 Center", Cf.prevSize . " pt")
    Cf.btnPrevReset := g.Add("Button", "x880 y378 w56 h24", "Reset")
    Cf.btnConv := g.Add("Button", "x700 y422 w250 h36 Default", "Convert and save as...")
    for hd in [Cf.hdFile, Cf.hdScan, Cf.hdAct, Cf.hdEnc, Cf.hdFont, Cf.hdSize]
        hd.SetFont("s9 w700", "Segoe UI")

    Cf.sb := g.Add("StatusBar", , "  Open a Word, PowerPoint or text file (or drop one or more files on this window).")
    ; progress bar lives inside the right end of the status bar (child of the status bar window)
    Cf.pb := g.Add("Progress", "x0 y0 w100 h14 Range0-100", 0)
    DllCall("SetParent", "Ptr", Cf.pb.Hwnd, "Ptr", Cf.sb.Hwnd)

    Cf.btnOpen.OnEvent("Click", CfOpenDialog)
    Cf.btnRemove.OnEvent("Click", CfRemove)
    Cf.btnApplyAll.OnEvent("Click", (*) => CfApplyAllShown(Cf.curName))
    Cf.btnApplySel.OnEvent("Click", CfApplySelected)
    Cf.lv.OnEvent("ContextMenu", CfListMenu)
    SetTimer(CfTipTick, 300)                            ; hover tips (they also work on disabled controls)
    Cf.btnConv.OnEvent("Click", CfConvert)
    Cf.btnScan.OnEvent("Click", CfScan)
    Cf.btnScanAll.OnEvent("Click", CfScanAll)
    Cf.btnScanNone.OnEvent("Click", CfScanNone)
    Cf.ddBy.OnEvent("Change", CfByChanged)
    Cf.btnPrevDn.OnEvent("Click", (*) => CfPrevStep(-1))
    Cf.btnPrevUp.OnEvent("Click", (*) => CfPrevStep(1))
    Cf.btnPrevReset.OnEvent("Click", (*) => CfPrevStep(0))
    Cf.lv.OnEvent("ItemSelect", CfRowSelect)
    Cf.tab.OnEvent("Change", CfTabChanged)
    Cf.lv.OnEvent("ColClick", CfColClick)
    Cf.edFind.OnEvent("Change", CfFilterDelayed)
    Cf.edMin.OnEvent("Change", CfFilterDelayed)
    Cf.edMax.OnEvent("Change", CfFilterDelayed)
    Cf.ddType.OnEvent("Change", CfRefreshList)
    Cf.ddVal.OnEvent("Change", CfValChanged)
    Cf.btnClearF.OnEvent("Click", CfClearFilters)
    Cf.ddAct.OnEvent("Change", CfUIChanged)
    Cf.ddMap.OnEvent("Change", CfUIChanged)
    Cf.ddMap2.OnEvent("Change", CfUIChanged)
    Cf.ddMethod.OnEvent("Change", CfMethodChanged)
    Cf.ddSize.OnEvent("Change", CfUIChanged)
    Cf.edSize.OnEvent("Change", CfDelayedUI)
    Cf.cbFont.OnEvent("Change", CfDelayedUI)
    Cf.cbFont.OnEvent("LoseFocus", CfDelayedUI)
    g.OnEvent("Size", CfSize)
    g.OnEvent("DropFiles", CfDrop)
    g.OnEvent("Close", (*) => ExitApp())
    OnMessage(0x201, CfSplitDown)                        ; WM_LBUTTONDOWN (splitter)
    OnMessage(0x20, CfSetCursor)                         ; WM_SETCURSOR   (splitter)
    OnExit(CfCleanup)
    OnExit(CfSaveSettings)
    CfEnableUI(-1)
    g.Show("w" . Cf.winW . " h" . Max(570, Min(Cf.winH, A_ScreenHeight - 120)))
}

CfStart()

; Ctrl+A = Select All: the text in a text box, otherwise every row of the list
#HotIf IsObject(Cf.gui) && WinActive("ahk_id " . Cf.gui.Hwnd)
^a:: {
    c := ""
    try c := Cf.gui.FocusedCtrl
    if IsObject(c) {
        if (c.Type = "Edit") {
            SendMessage(0x00B1, 0, -1, c.Hwnd)              ; EM_SETSEL
            return
        }
        if (c.Type = "ComboBox") {
            SendMessage(0x0142, 0, 0xFFFF0000, c.Hwnd)      ; CB_SETEDITSEL
            return
        }
    }
    if (Cf.rowKeys.Length > 0 && !Cf.busySel)
        CfSelAll()
}
#HotIf

; Hands the memory the program does not need back to Windows (only idle pages; they return when used)
TrimMemory() {
    DllCall("psapi\EmptyWorkingSet", "Ptr", DllCall("kernel32\GetCurrentProcess", "Ptr"))
}
