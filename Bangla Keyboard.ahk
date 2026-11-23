; ===========================================================================
;  Bangla Keyboard  -  small, fast Bijoy-style typing tool for Windows
;  Needs AutoHotkey v2 (portable exe is fine). Layouts live in the Layouts folder.
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsBuffer True
Persistent()
SetWorkingDir A_ScriptDir
CoordMode "Mouse", "Screen"
CoordMode "Menu", "Screen"
A_MaxHotkeysPerInterval := 2000
KeyHistory(0)
ListLines(0)                      ; no line history: less memory and CPU for the script
ProcessSetPriority "AboveNormal"

; ===========================================================================
;  Avro Phonetic (Unicode only) - the phonetic engine used by Bangla Keyboard.ahk
;  Built into this file: nothing runs until Avro Phonetic is chosen.
;
;  Turn it on in Settings > General > "Avro Phonetic (Unicode Only)". It then appears in the layout list
;  and in the Shortcuts tab like any other layout.
;
;  Quick reference (Avro phonetic)
;    Vowels      o a i I u U rri e OI O OU     (o after a consonant = no vowel)
;    Consonants  k kh g gh Ng | c ch j jh NG | T Th D Dh N | t th d dh n
;                p ph(f) b bh(v) m | z r l | sh(S) Sh s h | R Rh | y w x q
;    Marks       ng = ং    : = ঃ    ^ = ঁ    t` or TH = ৎ    . = ।    $ = ৳

;    Conjuncts   only the pairs in the Avro table join (kt, nt, st, bdh ...); other pairs stay side by side
;                (konvoy = কনভয়, Thk = ঠক); r, y, w after a consonant are still phola (kr, ky, kw)
;                ,, = explicit hasanta (k,,t)
;                kkh = ক্ষ   gg = জ্ঞ   Ngj = ঞ্জ   Ngc = ঞ্চ   Z = ্য (jophola)
;    r = plain র, never joins (tork)   rr = reph (torrk, korrm)
;                r right after a consonant is still ra-phola (kr)
;    ` (backtick) breaks a conjunct / separates letters
;    :: = literal colon      Backspace edits the word being typed
; ===========================================================================

class Avro {
    static title := "Avro Phonetic"          ; shown in the layout list, the tray menu and the Shortcuts tab
    static tokens := Map()                  ; token table (built the first time Avro Phonetic is used)
    static ready := false
    static registered := false              ; the hotkeys only Avro needs (made the first time it is used)
    static names := []                      ; those hotkeys: on while Avro Phonetic is the active layout
    static buf := ""                        ; Latin letters typed for the current word
    static shown := ""                      ; Bangla currently on screen for that word
    static BT := Chr(96)                    ; backtick
    static H := Chr(0x9CD)                  ; hasanta
    static YY := Chr(0x9DF)
    static RR := Chr(0x9DC)
    static RRH := Chr(0x9DD)

    static Init() {
        if Avro.ready
            return
        Avro.tokens := Map()
        t := Avro.tokens
        ; vowels:  keys, independent form, kar (sign after a consonant)
        Avro.AddV("a",    "আ", "া")
        Avro.AddV("i",    "ই", "ি")
        Avro.AddV("I",    "ঈ", "ী")
        Avro.AddV("u",    "উ", "ু")
        Avro.AddV("U",    "ঊ", "ূ")
        Avro.AddV("rri",  "ঋ", "ৃ")
        Avro.AddV("e",    "এ", "ে")
        Avro.AddV("OI",   "ঐ", Chr(0x9C8))
        Avro.AddV("O",    "ও", Chr(0x9CB))
        Avro.AddV("OU",   "ঔ", Chr(0x9CC))

        ; consonants
        Avro.AddC("k", "ক")
        Avro.AddC("kh", "খ")
        Avro.AddC("g", "গ")
        Avro.AddC("gh", "ঘ")
        Avro.AddC("Ng", "ঙ")
        Avro.AddC("c", "চ")
        Avro.AddC("ch", "ছ")
        Avro.AddC("j", "জ")
        Avro.AddC("jh", "ঝ")
        Avro.AddC("NG", "ঞ")
        Avro.AddC("T", "ট")
        Avro.AddC("Th", "ঠ")
        Avro.AddC("D", "ড")
        Avro.AddC("Dh", "ঢ")
        Avro.AddC("N", "ণ")
        Avro.AddC("t", "ত")
        Avro.AddC("th", "থ")
        Avro.AddC("d", "দ")
        Avro.AddC("dh", "ধ")
        Avro.AddC("n", "ন")
        Avro.AddC("p", "প")
        Avro.AddC("ph f", "ফ")
        Avro.AddC("b", "ব")
        Avro.AddC("bh v", "ভ")
        Avro.AddC("m", "ম")
        Avro.AddC("z", "য")
        Avro.AddC("l", "ল")
        Avro.AddC("sh S", "শ")
        Avro.AddC("Sh", "ষ")
        Avro.AddC("s", "স")
        Avro.AddC("h", "হ")
        Avro.AddC("Y", "য়")
        Avro.AddC("R", Avro.RR)
        Avro.AddC("Rh", Avro.RRH)
        ; common conjunct shortcuts
        Avro.AddC("kkh", "ক্ষ")
        Avro.AddC("gg", "জ্ঞ")
        Avro.AddC("Ngj", "ঞ্জ")
        Avro.AddC("Ngjh", "ঞ্ঝ")
        Avro.AddC("Ngc", "ঞ্চ")
        Avro.AddC("Ngch", "ঞ্ছ")

        ; Avro conjunct table: the only consonant pairs that join (taken from the Avro Phonetic dictionary).
        ; Any other pair is written side by side with no hasanta (konvoy = কনভয়, Thk = ঠক).
        Avro.AddJ("DD", "ড্ড")
        Avro.AddJ("GG", "জ্ঞ")
        Avro.AddJ("GN", "গ্ণ")
        Avro.AddJ("Gg", "জ্ঞ")
        Avro.AddJ("Gl", "গ্ল")
        Avro.AddJ("Gm", "গ্ম")
        Avro.AddJ("Gn", "গ্ন")
        Avro.AddJ("ND", "ণ্ড")
        Avro.AddJ("NN", "ণ্ণ")
        Avro.AddJ("NT", "ণ্ট")
        Avro.AddJ("Nm", "ণ্ম")
        Avro.AddJ("Nn", "ণ্ন")
        Avro.AddJ("Rg", "ড়্গ")
        Avro.AddJ("Sc", "শ্চ")
        Avro.AddJ("Sl", "শ্ল")
        Avro.AddJ("Sm", "শ্ম")
        Avro.AddJ("Sn", "শ্ন")
        Avro.AddJ("St", "শ্ত")
        Avro.AddJ("TT", "ট্ট")
        Avro.AddJ("Tm", "ট্ম")
        Avro.AddJ("bb", "ব্ব")
        Avro.AddJ("bd", "ব্দ")
        Avro.AddJ("bj", "ব্জ")
        Avro.AddJ("bl", "ব্ল")
        Avro.AddJ("cc", "চ্চ")
        Avro.AddJ("dd", "দ্দ")
        Avro.AddJ("dg", "দ্গ")
        Avro.AddJ("dm", "দ্ম")
        Avro.AddJ("dv", "দ্ভ")
        Avro.AddJ("fl", "ফ্ল")
        Avro.AddJ("gG", "জ্ঞ")
        Avro.AddJ("gN", "গ্ণ")
        Avro.AddJ("gg", "জ্ঞ")
        Avro.AddJ("gl", "গ্ল")
        Avro.AddJ("gm", "গ্ম")
        Avro.AddJ("gn", "গ্ন")
        Avro.AddJ("hN", "হ্ণ")
        Avro.AddJ("hl", "হ্ল")
        Avro.AddJ("hm", "হ্ম")
        Avro.AddJ("hn", "হ্ন")
        Avro.AddJ("jj", "জ্জ")
        Avro.AddJ("kT", "ক্ট")
        Avro.AddJ("kk", "ক্ক")
        Avro.AddJ("kl", "ক্ল")
        Avro.AddJ("ks", "ক্স")
        Avro.AddJ("kt", "ক্ত")
        Avro.AddJ("kx", "ক্ষ")
        Avro.AddJ("lD", "ল্ড")
        Avro.AddJ("lT", "ল্ট")
        Avro.AddJ("lb", "ল্ব")
        Avro.AddJ("lg", "ল্গ")
        Avro.AddJ("lk", "ল্ক")
        Avro.AddJ("ll", "ল্ল")
        Avro.AddJ("lm", "ল্ম")
        Avro.AddJ("lp", "ল্প")
        Avro.AddJ("lv", "ল্ভ")
        Avro.AddJ("mb", "ম্ব")
        Avro.AddJ("mf", "ম্ফ")
        Avro.AddJ("ml", "ম্ল")
        Avro.AddJ("mm", "ম্ম")
        Avro.AddJ("mn", "ম্ন")
        Avro.AddJ("mp", "ম্প")
        Avro.AddJ("mv", "ম্ভ")
        Avro.AddJ("nD", "ন্ড")
        Avro.AddJ("nT", "ন্ট")
        Avro.AddJ("nc", "ঞ্চ")
        Avro.AddJ("nd", "ন্দ")
        Avro.AddJ("nj", "ঞ্জ")
        Avro.AddJ("nk", "ঙ্ক")
        Avro.AddJ("nm", "ন্ম")
        Avro.AddJ("nn", "ন্ন")
        Avro.AddJ("ns", "ন্স")
        Avro.AddJ("nt", "ন্ত")
        Avro.AddJ("pT", "প্ট")
        Avro.AddJ("pl", "প্ল")
        Avro.AddJ("pn", "প্ন")
        Avro.AddJ("pp", "প্প")
        Avro.AddJ("ps", "প্স")
        Avro.AddJ("pt", "প্ত")
        Avro.AddJ("sT", "স্ট")
        Avro.AddJ("sf", "স্ফ")
        Avro.AddJ("sk", "স্ক")
        Avro.AddJ("sl", "স্ল")
        Avro.AddJ("sm", "স্ম")
        Avro.AddJ("sn", "স্ন")
        Avro.AddJ("sp", "স্প")
        Avro.AddJ("st", "স্ত")
        Avro.AddJ("tm", "ত্ম")
        Avro.AddJ("tn", "ত্ন")
        Avro.AddJ("tt", "ত্ত")
        Avro.AddJ("vl", "ভ্ল")
        Avro.AddJ("Gdh", "গ্ধ")
        Avro.AddJ("Ghn", "ঘ্ন")
        Avro.AddJ("NDh", "ণ্ঢ")
        Avro.AddJ("NGc", "ঞ্চ")
        Avro.AddJ("NGj", "ঞ্জ")
        Avro.AddJ("NTh", "ণ্ঠ")
        Avro.AddJ("Ngg", "ঙ্গ")
        Avro.AddJ("Ngk", "ঙ্ক")
        Avro.AddJ("Ngm", "ঙ্ম")
        Avro.AddJ("Ngx", "ঙ্ষ")
        Avro.AddJ("Sch", "শ্ছ")
        Avro.AddJ("ShN", "ষ্ণ")
        Avro.AddJ("ShT", "ষ্ট")
        Avro.AddJ("Shf", "ষ্ফ")
        Avro.AddJ("Shk", "ষ্ক")
        Avro.AddJ("Shm", "ষ্ম")
        Avro.AddJ("Shp", "ষ্প")
        Avro.AddJ("bdh", "ব্ধ")
        Avro.AddJ("bhl", "ভ্ল")
        Avro.AddJ("cNG", "চ্ঞ")
        Avro.AddJ("cch", "চ্ছ")
        Avro.AddJ("dbh", "দ্ভ")
        Avro.AddJ("ddh", "দ্ধ")
        Avro.AddJ("dgh", "দ্ঘ")
        Avro.AddJ("dhm", "ধ্ম")
        Avro.AddJ("dhn", "ধ্ন")
        Avro.AddJ("gdh", "গ্ধ")
        Avro.AddJ("ghn", "ঘ্ন")
        Avro.AddJ("jNG", "জ্ঞ")
        Avro.AddJ("jjh", "জ্ঝ")
        Avro.AddJ("kSh", "ক্ষ")
        Avro.AddJ("kkh", "ক্ষ")
        Avro.AddJ("kxN", "ক্ষ্ণ")
        Avro.AddJ("kxm", "ক্ষ্ম")
        Avro.AddJ("lbh", "ল্ভ")
        Avro.AddJ("ldh", "ল্ধ")
        Avro.AddJ("mbh", "ম্ভ")
        Avro.AddJ("mph", "ম্ফ")
        Avro.AddJ("mpl", "মপ্ল")
        Avro.AddJ("mth", "ম্থ")
        Avro.AddJ("nTh", "ন্ঠ")
        Avro.AddJ("nch", "ঞ্ছ")
        Avro.AddJ("ndh", "ন্ধ")
        Avro.AddJ("ngh", "ঙ্ঘ")
        Avro.AddJ("njh", "ঞ্ঝ")
        Avro.AddJ("nkh", "ঙ্খ")
        Avro.AddJ("nth", "ন্থ")
        Avro.AddJ("phl", "ফ্ল")
        Avro.AddJ("shc", "শ্চ")
        Avro.AddJ("shl", "শ্ল")
        Avro.AddJ("shm", "শ্ম")
        Avro.AddJ("shn", "শ্ন")
        Avro.AddJ("sht", "শ্ত")
        Avro.AddJ("skh", "স্খ")
        Avro.AddJ("skl", "স্ক্ল")
        Avro.AddJ("sph", "স্ফ")
        Avro.AddJ("spl", "স্প্ল")
        Avro.AddJ("sth", "স্থ")
        Avro.AddJ("tth", "ত্থ")
        Avro.AddJ("NGch", "ঞ্ছ")
        Avro.AddJ("NGjh", "ঞ্ঝ")
        Avro.AddJ("Nggh", "ঙ্ঘ")
        Avro.AddJ("Ngkh", "ঙ্খ")
        Avro.AddJ("Ngkx", "ঙ্ক্ষ")
        Avro.AddJ("ShTh", "ষ্ঠ")
        Avro.AddJ("Shph", "ষ্ফ")
        Avro.AddJ("kShN", "ক্ষ্ণ")
        Avro.AddJ("kShm", "ক্ষ্ম")
        Avro.AddJ("kkhN", "ক্ষ্ণ")
        Avro.AddJ("kkhm", "ক্ষ্ম")
        Avro.AddJ("shch", "শ্ছ")
        Avro.AddJ("NgkSh", "ঙ্ক্ষ")
        Avro.AddJ("Ngkkh", "ঙ্ক্ষ")

        ; Avro guard entries: these stop a table conjunct from forming when an h follows (nsh = নশ, not ন্সহ)
        Avro.AddJ("psh", "পশ")
        Avro.AddJ("ksh", "কশ")
        Avro.AddJ("lkh", "লখ")
        Avro.AddJ("lgh", "লঘ")
        Avro.AddJ("lph", "লফ")
        Avro.AddJ("nsh", "নশ")
        Avro.AddJ("Ngr", "ঙর")
        Avro.AddJ("NGr", "ঞর")
        Avro.AddJ("ngr", "ংর")

        ; marks (never form conjuncts)
        Avro.AddM("ng", "ং")
        Avro.AddM("^", "ঁ")
        Avro.AddM(":", "ঃ")
        Avro.AddM("::", ":")
        Avro.AddM("t" Avro.BT " TH", "ৎ")

        ; context-dependent tokens
        t["o"] := {kind: "o"}
        t["y"] := {kind: "y"}
        t["w"] := {kind: "w"}
        t["Z"] := {kind: "zj"}
        t[",,"] := {kind: "hs"}               ; ,, = explicit hasanta (as in Avro: hasanta + ZWNJ)
        t["r"]  := {kind: "r"}
        t["rr"] := {kind: "reph"}
        t["x"] := {kind: "x"}
        t[Avro.BT]  := {kind: "brk"}
        Avro.ready := true
    }

    static AddV(keys, indep, kar) {
        for k in StrSplit(keys, " ")
            Avro.tokens[k] := {kind: "vow", a: indep, b: kar}
    }

    static AddC(keys, txt) {
        for k in StrSplit(keys, " ")
            Avro.tokens[k] := {kind: "cons", a: txt}
    }

    ; conjunct from the Avro table (kept as is when a token with the same key already exists)
    static AddJ(key, txt) {
        if !Avro.tokens.Has(key)
            Avro.tokens[key] := {kind: "cons", a: txt}
    }

    static AddM(keys, txt) {
        for k in StrSplit(keys, " ")
            Avro.tokens[k] := {kind: "mark", a: txt}
    }

    ; -----------------------------------------------------------------------
    ;  Converter: Latin word -> Bangla word
    ;  prev:  S=start/other  C=consonant  V=vowel (incl. silent o)  M=mark  B=breaker
    ; -----------------------------------------------------------------------
    static Convert(s) {
        tokens := Avro.tokens
        H := Avro.H
        YY := Avro.YY
        out := ""
        prev := "S"
        nj := false                 ; true right after a plain র: next consonant must not join
        ph := false                 ; true right after a ফলা (y, w, Z, x): a following r is a plain র
        i := 1
        n := StrLen(s)
        while i <= n {
            tok := ""
            len := 0
            Loop 5 {
                l := 6 - A_Index
                if (i + l - 1 > n)
                    continue
                piece := SubStr(s, i, l)
                if tokens.Has(piece) {
                    tok := piece
                    len := l
                    break
                }
            }
            if (len = 0) {
                ch := SubStr(s, i, 1)
                lo := StrLower(ch)
                if tokens.Has(lo) {
                    tok := lo
                    len := 1
                } else {
                    out .= ch
                    prev := "S"
                    i += 1
                    continue
                }
            }
            st := i
            i += len
            e := tokens[tok]
            kind := e.kind
            wasNj := nj
            nj := false
            wasPh := ph
            ph := false

            if (kind = "cons") {
                out .= e.a                  ; no automatic hasanta: only the Avro table joins consonants
                prev := "C"
            } else if (kind = "r") {
                if (prev = "C" && !wasPh) {
                    out .= H "র"            ; ra-phola  (kr)
                } else {
                    out .= "র"              ; plain র, no joining with what follows
                    nj := true
                }
                prev := "C"
            } else if (kind = "reph") {
                if (prev = "C" || prev = "V") {
                    out .= "র" H            ; reph  (the next consonant sits after it)
                    prev := "B"
                } else {
                    out .= "রর"
                    prev := "C"
                    nj := true
                }
            } else if (kind = "vow") {
                if (prev = "C")
                    out .= e.b
                else if (prev = "V" && tok == "a")
                    out .= YY "া"
                else
                    out .= e.a
                prev := "V"
            } else if (kind = "o") {
                if (prev = "V")
                    out .= "ও"
                else if (prev != "C")
                    out .= "অ"
                prev := "V"
            } else if (kind = "mark") {
                out .= e.a
                prev := "M"
            } else if (kind = "y") {
                if (prev = "C" && !wasNj) {
                    out .= H "য"
                    ph := true
                } else
                    out .= YY
                prev := "C"
            } else if (kind = "w") {
                if (prev = "C" && !wasNj) {
                    out .= H "ব"
                    ph := true
                    prev := "C"
                } else {
                    out .= "ও"
                    prev := "V"
                }
            } else if (kind = "zj") {
                out .= H "য"
                ph := true
                prev := "C"
            } else if (kind = "hs") {
                out .= H Chr(0x200C)        ; ,,  explicit hasanta
                prev := "B"
            } else if (kind = "x") {
                if (st = 1) {
                    out .= "এক্স"
                } else {
                    out .= "ক" H "স"
                }
                ph := true
                prev := "C"
            } else if (kind = "brk") {
                prev := "B"
            }
        }
        return out
    }

    ; Screen update: only rewrite the part of the word that changed
    static Render() {
        newOut := Avro.Convert(Avro.buf)
        enc := ActiveEnc()
        if IsObject(enc)
            newOut := enc.Conv(newOut)
        shown := Avro.shown
        p := 0
        m := Min(StrLen(shown), StrLen(newOut))
        while (p < m && SubStr(shown, p + 1, 1) == SubStr(newOut, p + 1, 1))
            p += 1
        del := StrLen(shown) - p
        if (del > 0)
            Send("{BackSpace " del "}")
        add := SubStr(newOut, p + 1)
        if (add != "")
            SendText(add)
        Avro.shown := newOut
        Snip.Edit(del, add)
    }

    static Commit() {
        Avro.buf := ""
        Avro.shown := ""
    }

    ; a key Avro does not use: end the word and let the key through as normal
    static Pass(vk, shifted) {
        Avro.Commit()
        Send("{Blind}{vk" . Format("{:X}", vk) . "}")
        Snip.Add(KeyChar(vk, shifted))
    }

    ; One typed key (called by TypingKey in Bangla Keyboard.ahk while Avro Phonetic is the active layout)
    static Key(vk, shifted) {
        if !Avro.ready
            Avro.Init()
        n := 0                                                   ; commas at the end of the word being typed
        while (n < StrLen(Avro.buf) && SubStr(Avro.buf, StrLen(Avro.buf) - n, 1) = ",")
            n += 1
        if (vk = 188 && !shifted) {                              ; ,  ends the word; ,, inside a word = explicit hasanta
            if (Avro.buf != "" && n < 2) {
                Avro.buf .= ","
                Avro.Render()
                return
            }
            Avro.Pass(vk, shifted)
            return
        }
        if (n = 1)                                               ; a single comma: the word ended there
            Avro.Commit()
        if (vk >= 65 && vk <= 90) {                              ; letters
            up := shifted ? true : false
            if GetKeyState("CapsLock", "T")
                up := !up
            ch := Chr(vk)
            Avro.buf .= up ? ch : StrLower(ch)
            Avro.Render()
            return
        }
        if (vk >= 48 && vk <= 57) {                              ; digits
            if !shifted {
                Avro.Commit()
                SendText(EncText(Chr(0x9E6 + vk - 48)))
                Snip.Add(Chr(0x9E6 + vk - 48))
            } else if (vk = 52) {                                ; $  ->  ৳
                Avro.Commit()
                SendText(EncText(Chr(0x9F3)))
                Snip.Add(Chr(0x9F3))
            } else if (vk = 54) {                                ; ^  ->  chandrabindu (part of the word)
                Avro.buf .= "^"
                Avro.Render()
            } else {
                Avro.Pass(vk, shifted)
            }
            return
        }
        if (vk >= 96 && vk <= 105) {                             ; numpad digits
            Avro.Commit()
            SendText(EncText(Chr(0x9E6 + vk - 96)))
            Snip.Add(Chr(0x9E6 + vk - 96))
            return
        }
        if (vk = 190 && !shifted) {                              ; .  ->  ।
            Avro.Commit()
            SendText(EncText(Chr(0x964)))
            Snip.Add(Chr(0x964))
            return
        }
        if (vk = 186 && shifted) {                               ; :  ->  visarga / literal colon (part of the word)
            Avro.buf .= ":"
            Avro.Render()
            return
        }
        if (vk = 192 && !shifted) {                              ; `  breaks a conjunct
            if (Avro.buf = "") {
                SendText(Avro.BT)
                Snip.Add(Avro.BT)
                return
            }
            Avro.buf .= Avro.BT
            Avro.Render()
            return
        }
        Avro.Pass(vk, shifted)                                   ; space, punctuation, ...: ends the word
    }

    ; The few hotkeys that only Avro needs. Made once, the first time Avro Phonetic is switched on, so that
    ; startup costs nothing. The letter / digit / punctuation hotkeys are the ones Bangla Keyboard already has.
    static Register() {
        if Avro.registered
            return
        Avro.registered := true
        Avro.Init()
        names := []
        HotIf()
        Loop 36 {                                                ; letters A-Z (vk 65-90) and numpad digits (vk 96-105)
            vk := (A_Index <= 26) ? 64 + A_Index : 69 + A_Index
            if App.vkSet.Has(vk)
                continue
            n := Format("vk{:X}", vk)
            Hotkey("$" . n, TypingKey.Bind(vk, false), "Off")
            names.Push("$" . n)
            if (vk <= 90) {
                Hotkey("$+" . n, TypingKey.Bind(vk, true), "Off")
                names.Push("$+" . n)
            }
        }
        Hotkey("$BackSpace", AvroBack, "Off")                    ; Backspace edits the Latin word being typed
        Hotkey("$+BackSpace", AvroBack, "Off")
        names.Push("$BackSpace", "$+BackSpace")
        for k in ["Insert", "NumpadDot", "NumpadAdd", "NumpadSub", "NumpadMult", "NumpadDiv"] {
            Hotkey("~*" . k, ResetKey, "Off")                    ; keys that move the caret or change the text end the word
            names.Push("~*" . k)
        }
        Loop 12 {
            Hotkey("~*F" . A_Index, ResetKey, "Off")
            names.Push("~*F" . A_Index)
        }
        HotIf()
        Avro.names := names
    }
}

AvroBack(*) {
    Critical
    if (Avro.buf = "") {
        Send("{BackSpace}")
        Snip.Back()
        return
    }
    Avro.buf := SubStr(Avro.buf, 1, -1)
    Avro.Render()
}

; Avro Phonetic as a layout of the program (no layout file: it is built in)
AvroLayout() {
    L := Layout()
    L.name := Avro.title
    L.kind := "avro"
    return L
}

; Switch the Avro-only hotkeys on / off together with the layout. Backspace: Bijoy layouts let it through with
; a buffer reset (~*BS); Avro takes it over instead (so it can edit the word), so that one is off while Avro is on.
AvroMode(on) {
    if (on = App.avroActive)
        return
    if on
        Avro.Register()
    HotIf()
    for n in Avro.names {
        try Hotkey(n, on ? "On" : "Off")
    }
    try Hotkey("~*BS", (on || !App.typingOn) ? "Off" : "On")
    HotIf()
    App.avroActive := on
    Avro.Commit()
}

; Settings > General > "Avro Phonetic (Unicode Only)": add it to / take it out of the program's layout list.
; It is always the last layout, so the numbers of the other layouts never change.
ApplyAvroSetting(on) {
    id := "L:" . Avro.title
    SaveSetting("General", "AvroPhonetic", on ? 1 : 0)
    n := App.layouts.Length
    has := (n > 0 && App.layouts[n].kind = "avro")
    if on {
        App.avroOn := true
        if has
            return
        App.layouts.Push(AvroLayout())
        v := IniRead(App.ini, "Shortcuts", IniKey(id), "none")
        App.shortcuts[id] := (v = "none" || IsUnsupportedHk(v)) ? "" : v
        App.shown[id] := (IniRead(App.ini, "Shown", IniKey(id), "1") != "0")
        k := Avro.title
        sz := IniRead(App.ini, "Fonts", k . ".Size", "0")
        App.fonts[k] := {on: (IniRead(App.ini, "Fonts", k . ".On", "0") = "1")
            , font: IniRead(App.ini, "Fonts", k . ".Font", "")
            , size: (IsInteger(sz) && sz >= 4 && sz <= 400) ? Integer(sz) : 0
            , keep: IniRead(App.ini, "Fonts", k . ".Keep", "")}
        return
    }
    App.avroOn := false
    if !has
        return
    if (App.cur = n)
        SetLayout(0)                                   ; it is in use: back to English first
    for h, m in App.winModes.Clone() {
        if (m = n)
            App.winModes[h] := 0
    }
    if (App.globMode = n)
        App.globMode := 0
    if (App.lastBn = n)
        App.lastBn := 1
    App.layouts.Pop()
    FixLastBn()
}


; ---------------------------------------------------------------------------
;  Layout: reads one of the layout files (.bkl or .xml - both hold XML, the same format as Bijoy Bayanno;
;  a .bkl is the locked (scrambled) form made with Tools\Pupo Encrypter.ahk)
; ---------------------------------------------------------------------------
; .bkl = a layout (XML) file scrambled byte by byte. Layout: "BKL" + 0x01 + the text length (4 bytes), then each byte is
; (plain XOR key[i]) + (i*31+17), all modulo 256. It only stops the file being read or changed by accident; it is not
; real encryption. Keep the key the same as in Tools\Pupo Encrypter.ahk.
BklDecode(buf) {
    static key := "BanglaLayoutKey"
    if (buf.Size < 8 || NumGet(buf, 0, "UChar") != 0x42 || NumGet(buf, 1, "UChar") != 0x4B
        || NumGet(buf, 2, "UChar") != 0x4C || NumGet(buf, 3, "UChar") != 1)
        throw Error("This is not a valid .bkl layout file.")
    n := NumGet(buf, 4, "UInt")
    if (n > buf.Size - 8)
        throw Error("This .bkl layout file is damaged (it ends too early).")
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

class Layout {
    name := ""
    hotkey := ""
    icon := ""        ; <IconName> in the layout file -> Icons\<IconName>.png (first choice) or .ico
    nor := Map()      ; vk -> text without Shift
    sh := Map()       ; vk -> text with Shift
    optN := Map()     ; vk -> option name (Delay, DeInc1, DeInc2, MoveL, Xtra)
    optS := Map()
    juks := Map()     ; joining rules: typed sequence -> replacement
    maxSeq := 1
    kind := ""        ; "" = a layout file, "avro" = the built-in Avro Phonetic layout

    static Unesc(s) {
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

    static Load(path) {
        SplitPath(path, , , &fext)
        txt := (StrLower(fext) = "bkl") ? BklDecode(FileRead(path, "RAW")) : FileRead(path, "UTF-8")
        L := Layout()
        if RegExMatch(txt, "s)<Name>(.*?)</Name>", &m) {
            L.name := Layout.Unesc(m[1])
        } else {
            SplitPath(path, , , , &nm)
            L.name := nm
        }
        if RegExMatch(txt, "s)<IconName>(.*?)</IconName>", &m)
            L.icon := Trim(Layout.Unesc(m[1]))
        if RegExMatch(txt, "s)<Shortcut>(.*?)</Shortcut>", &m) {
            sc := m[1]
            mods := ""
            if InStr(sc, "<Ctrl>True")
                mods .= "^"
            if InStr(sc, "<Alt>True")
                mods .= "!"
            if InStr(sc, "<Shift>True")
                mods .= "+"
            if RegExMatch(sc, "<KeyCode>(\d+)</KeyCode>", &k)
                L.hotkey := mods . Format("vk{:X}", Integer(k[1]))
        }
        keyRe := 's)<Key KeyCode="(\d+)"([^>]*)>\s*<Normal>(.*?)</Normal>\s*<Shift>(.*?)</Shift>\s*</Key>'
        pos := 1
        while (pos := RegExMatch(txt, keyRe, &m, pos)) {
            pos += m.Len[0]
            vk := Integer(m[1])
            L.nor[vk] := Layout.Unesc(m[3])
            L.sh[vk] := Layout.Unesc(m[4])
            if RegExMatch(m[2], 'Normal_Option="([^"]*)"', &o)
                L.optN[vk] := o[1]
            if RegExMatch(m[2], 'Shift_Option="([^"]*)"', &o)
                L.optS[vk] := o[1]
        }
        jukRe := 's)<Juk>\s*<Seq>(.*?)</Seq>\s*<Out>(.*?)</Out>\s*</Juk>'
        pos := 1
        while (pos := RegExMatch(txt, jukRe, &m, pos)) {
            pos += m.Len[0]
            seq := Layout.Unesc(m[1])
            out := Layout.Unesc(m[2])
            ; some outputs carry a stray leading space that the sequence does not have
            if (SubStr(out, 1, 1) == " " && SubStr(seq, 1, 1) != " ")
                out := LTrim(out, " ")
            L.juks[seq] := out
            if (StrLen(seq) > L.maxSeq)
                L.maxSeq := StrLen(seq)
        }
        return L
    }
}

; ---------------------------------------------------------------------------
;  Engine: turns one key press into "backspaces + text to type"
; ---------------------------------------------------------------------------
class Engine {
    static HAS := Chr(0x09CD)
    static ZWNJ := Chr(0x200C)
    static ZWJ := Chr(0x200D)
    static MAXBUF := 24

    buf := ""       ; what we typed recently (so joining rules can look back)
    vowel := ""     ; a vowel sign (i, e, ai) still waiting to follow its consonant
    mode := ""      ; "lead" = typed before its consonant, "tail" = already after it
    pend := ""      ; the whole new text of the last key press (before it is cut to MAXBUF); used by encodings

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
        this.pend := nw
        if (StrLen(nw) > Engine.MAXBUF)
            nw := SubStr(nw, -Engine.MAXBUF)
        this.buf := nw
        this.vowel := nvw
        this.mode := nmd
        return [bs, txt]
    }
}

; Types the result of Engine.Press (works in any program, no clipboard)
SendOut(bs, txt) {
    s := ""
    if (bs > 0)
        s := "{BS " bs "}"
    Loop Parse txt
        s .= "{U+" . Format("{:04X}", Ord(A_LoopField)) . "}"
    if (s != "")
        Send(s)
}

; ---------------------------------------------------------------------------
;  Encodings (Library folder): you type Unicode, the text that reaches the program is converted to an older
;  ANSI encoding (Bijoy style) while you type. The rules of one encoding live in one file: Library\Encoding Script\<name>.json (or the locked Library\Encoding Script\<name>.menc)
;  The Encoding submenu (layout menu of the bar and tray menu, shown while a Unicode layout is active) picks the one in use. "Unicode" = off.
; ---------------------------------------------------------------------------

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

; ---- encodings: which one is in use -----------------------------------------
; the encoding files in the Library folder (names without the extension). An encoding may be a plain .json or a locked
; .menc (made with Tools\Pupo Encrypter.ahk; same content, scrambled). Both are read. If both exist with the same name,
; the .menc one is used. The names are listed in alphabetical order.
EncodingFiles() {
    found := Map()
    for ext in ["json", "menc"] {
        Loop Files App.dir . "\Library\Encoding Script\*." . ext {
            if (StrLower(A_LoopFileExt) != ext)           ; "*.json" can also match longer extensions: skip them
                continue
            SplitPath(A_LoopFileFullPath, , , , &nm)
            found[StrLower(nm)] := nm
        }
    }
    names := []
    for k, nm in found
        names.Push(nm)
    Loop names.Length {
        i := A_Index
        v := names[i]
        j := i - 1
        while (j >= 1 && StrCompare(names[j], v) > 0) {
            names[j + 1] := names[j]
            j--
        }
        names[j + 1] := v
    }
    return names
}

; the file of an encoding: the .menc when there is one, else the .json; "" when neither exists
EncPath(name) {
    for ext in ["menc", "json"] {
        p := App.dir . "\Library\Encoding Script\" . name . "." . ext
        if FileExist(p)
            return p
    }
    return ""
}

; "" = no conversion. Returns false (and keeps no encoding) when the file cannot be read.
LoadEncoding(name) {
    App.enc := ""
    App.encName := ""
    if (name = "")
        return true
    path := EncPath(name)
    if (path = "")
        return false
    try {
        App.enc := EncLib.Load(path)
        App.encName := name
        return true
    } catch as e {
        App.enc := ""
        App.encName := ""
        MsgBox("This Library file could not be read:`n" . name . "`n`n" . e.Message, "Bangla Keyboard", 0x10)
    }
    return false
}

; the encoding that converts what you type right now (a Unicode layout, or Avro Phonetic, with an encoding chosen); "" = none
ActiveEnc() {
    if (!App.encOn || !IsObject(App.enc) || App.cur < 1)
        return ""
    if !LayoutIsUnicode(App.layouts[App.cur])
        return ""
    return App.enc
}

; text typed straight (digits, danda, taka) in the encoding in use
EncText(s) {
    enc := ActiveEnc()
    return IsObject(enc) ? enc.Conv(s) : s
}

EncChoices() {
    a := ["Unicode"]
    for nm in EncodingFiles()
        a.Push(nm)
    return a
}

SetEncoding(name, *) {
    if LoadEncoding(name)
        SaveSetting("General", "Encoding", App.encName)
    if IsObject(App.eng)
        App.eng.Reset()
    Avro.Commit()
    BuildTrayMenu()
    RefreshUI()
    if App.fontOn
        FontKick()
}

; the Encoding submenu (tray menu and the bar's layout menu): Unicode + every file of the Library folder
MakeEncMenu() {
    m := Menu()
    m.Add("Unicode", SetEncoding.Bind(""))
    for nm in EncodingFiles()
        m.Add(StrReplace(nm, "&", "&&"), SetEncoding.Bind(nm))
    try m.Check(App.encName = "" ? "Unicode" : StrReplace(App.encName, "&", "&&"))
    return m
}

; the Encoding submenu is always listed while Multi Encoding is ticked (and the Library has files) ...
EncMenuOn() {
    return App.encOn && EncodingFiles().Length > 0
}

; ... but it can only be used in a Unicode layout (or Avro Phonetic); in English / ANSI layouts it is greyed out
EncUsable() {
    if (App.cur < 1)
        return false
    return LayoutIsUnicode(App.layouts[App.cur])
}

; the layouts as menu items (English first, then every layout in alphabetical order)
AddLayoutItems(m) {
    if IsShown("English")
        m.Add("English", SetLayout.Bind(0))
    for i in LayoutOrder() {
        if IsShown("L:" . App.layouts[i].name)
            m.Add(App.layouts[i].name, SetLayout.Bind(i))
    }
}

; puts the check mark on the layout in use (m = the menu that holds the layout items)
MarkLayouts(m) {
    try m.Uncheck("English")
    for L in App.layouts
        try m.Uncheck(L.name)
    try m.Check(CurrentName())
}

; ---------------------------------------------------------------------------
;  App state, settings, layout switching, hotkeys, tray
; ---------------------------------------------------------------------------
class App {
    static dir := A_ScriptDir                                  ; program files (read-only is fine)
    static dataDir := A_AppData "\Bangla Keyboard"             ; settings live here (always writable; shared with the tools in the Tools folder)
    static ini := A_AppData "\Bangla Keyboard\Bangla Keyboard.dat"
    static skins := []           ; skins found in Skins\*\skin.ini: {id, folder, name}
    static maxExt := 6           ; the most extra buttons (Ext1 - Ext6) a skin can have
    static skinH := 24           ; height of the skin bar that is shown
    static skinTrans := false    ; the skin bar's buttons are transparent pictures
    static skinMode := false     ; the skin bar's name box shows the mode (ENG / বাংলা) instead of the layout name
    static skinModeTxt := ["ENG", "বাংলা"]     ; the two texts of that box: English, Bangla
    static menuAnchor := ""      ; the control the layout menu opens under (empty = the name box)
    static toolMenu := ""         ; the tray menu's Tools submenu (kept here so it stays alive)
    static layouts := []
    static cur := 0              ; 0 = English, otherwise index into layouts
    static lastBn := 1           ; Bangla layout used by the English <-> Bangla toggle
    static eng := ""
    static bar := ""
    static pic := ""
    static nameCtl := ""
    static dlg := ""
    static dlgSt := ""            ; the state object of the Settings window while it is open (used by its scroll bar)
    static about := ""           ; the About window while it is open
    static version := "4.2.8"
    static onTop := true
    static theme := "DarkGreen"
    static style := "GreenBangla"  ; bar style: Classic | ClassicExt | AeroDark | PurpleRaised | GreenBangla | EkusheDark | EkusheBN | BanglaKb
    static rebuilding := false     ; true while the bar is being destroyed and built again (UpdateBar must not touch it then)
    static rebuildAgain := false   ; a rebuild was asked for while one was running: it is done once more afterwards
    static ext := []               ; the two extra bar buttons of the "Ext" styles: {on: shown on the bar (button 1 is always on), act: file in Tools, icon: icon name}
    static picSz := 20
    static iconSize := 1           ; position in IconSizes() of the icon size on the bar (1 = Original, 20 px)
    static barX := ""
    static barY := ""
    static tipShown := false
    static typingNames := []
    static typingOn := false
    static avroOn := false         ; Settings > General > "Avro Phonetic (Unicode Only)" is ticked: it is in the layout list
    static avroActive := false     ; Avro Phonetic is the layout in use right now
    static encName := ""           ; Library\<name>.json in use ("" = no conversion: the text stays Unicode)
    static enc := ""               ; the rules of that encoding (an EncLib object), "" = none
    static encMenu := ""           ; the tray menu's Encoding submenu (kept here so it stays alive)
    static trayLay := ""           ; the tray menu's Layouts submenu (when layoutSub is on)
    static encOn := true           ; multi encoding is switched on (Settings > Multi Encoding)
    static encKeys := Map()        ; encoding name ("Unicode" = no conversion) -> shortcut key ("#" = with the Win key), "" = none
    static layoutSub := false      ; the layouts sit in a "Layouts" submenu of the tray menu
    static vkSet := Map()          ; keys (vk codes) that have a typing hotkey
    static msgHooked := false
    static hov := []             ; bar buttons that light up under the mouse: {ctl, hwnds, norm, hov, pw, ph, top}
    static hovCur := 0           ; the one that is lit now (0 = none)
    static hovTimer := false     ; true while the hover check runs (only while the mouse is over the bar)
    static shortcuts := Map()    ; action id -> hotkey text ("" = no shortcut)
    static shown := Map()        ; action id -> true/false: is this item listed in the application (menus) and its shortcut active?
    static regNames := []        ; shortcut hotkeys that are currently registered
    static perWin := false       ; false = Global (one mode for all windows), true = each window keeps its own mode
    static winModes := Map()     ; window handle -> layout index (0 = English), used when perWin is true
    static curWin := 0           ; the window whose mode is showing now (last normal window that was active)
    static fgHook := 0
    static trayHooked := false
    static trayDbl := false
    static startMin := false     ; start with the bar minimized to the tray
    static trayAlways := true    ; keep the tray icon visible all the time (false = only while the bar is minimized)
    static toolsSub := true      ; the Tools programs sit in a "Tools" submenu of the tray menu (false = listed directly in the tray menu)
    static confirmClose := true  ; ask "Yes / No" before the bar's close button exits the program
    static splashOn := true      ; show the splash screen when the program starts
    static splashMs := 2000      ; how long it stays (milliseconds)
    static helperOn := true      ; start the Performance Helper together with the program (Settings > Extra Settings)
    static helperTray := false   ; the Performance Helper shows its own tray icon
    static splash := ""          ; the splash window while it is visible
    static tips := true          ; show a hint when the mouse rests on an option in Settings
    static menuPrev := 0         ; window that was active before the bar's layout menu opened
    static fontOn := false       ; Fonts tab: change the font automatically in Office apps
    static fonts := Map()        ; layout name (or "English") -> {on, font, size, keep}
    static fontDirty := false    ; the cursor probably moved: check the font before the next key
    static lastKey := 0          ; tick of the last typed key
    static fontCom := Map()      ; COM connections to Word / Excel / PowerPoint (dropped when you leave those apps)
    static globMode := 0         ; mode used by all non-Office windows when Mode switching is "Global"
    static userFont := Map()     ; "window|layout" -> the font you last used for that layout in that window
    static ansiSeen := Map()     ; fonts you used while an ANSI layout was active (so English can move away from them)
    static manualOn := false     ; Fonts tab: manual font shortcuts (work with or without the automatic font change)
    static slots := []           ; manual font slots: {key, font, size}
    static manualHold := 0       ; window whose font was just set by hand: the automatic change leaves it alone until the layout / window changes
}

; ---- colour themes for the bar ---------------------------------------------
;  bg = bar background, fld/ftx = layout box + its text, arr = arrow,
;  stb/mnb/clb = settings / minimize / close buttons, btx = button text
ThemeNames() {
    return ["Navy", "Blue", "Sky", "Cyan", "Teal", "Green", "DarkGreen", "Lime", "Yellow", "Orange", "Red", "Maroon", "Brown", "Pink", "Purple", "Indigo", "Slate", "Gray", "Light", "Dark", "Charcoal", "Midnight", "Black"]
}

Themes() {
    static t := ""
    if IsObject(t)
        return t
    t := Map()
    t["Navy"]      := {bg: "1B2238", fld: "FFF3E0", ftx: "1B2238", arr: "55607A", stb: "3F6FB5", mnb: "5B6B85", clb: "C0392B", btx: "FFFFFF"}
    t["Blue"]      := {bg: "1E5AA8", fld: "E8F1FF", ftx: "0F2E57", arr: "3C6AA8", stb: "143F75", mnb: "3E78C2", clb: "D64545", btx: "FFFFFF"}
    t["Green"]     := {bg: "2E8B57", fld: "EAF8EF", ftx: "14452B", arr: "3F8F63", stb: "1F6B41", mnb: "4FA574", clb: "D64545", btx: "FFFFFF"}
    t["DarkGreen"] := {bg: "12301F", fld: "D9EFE0", ftx: "0E2A1A", arr: "3F7A58", stb: "1F6B41", mnb: "2D5A41", clb: "B03A2E", btx: "FFFFFF"}
    t["Purple"]    := {bg: "5B3A9A", fld: "F1EAFB", ftx: "2D1B52", arr: "6B4FA3", stb: "7A4FC2", mnb: "7860A8", clb: "D64545", btx: "FFFFFF"}
    t["Dark"]      := {bg: "1E1E1E", fld: "2D2D30", ftx: "E6E6E6", arr: "9A9A9A", stb: "3B3B3F", mnb: "3B3B3F", clb: "B03A2E", btx: "FFFFFF"}
    t["Light"]     := {bg: "F0F0F0", fld: "FFFFFF", ftx: "202020", arr: "666666", stb: "D9E6F7", mnb: "E1E1E1", clb: "F2C2C2", btx: "202020"}
    t["Teal"]      := {bg: "0F766E", fld: "E6FFFB", ftx: "073B37", arr: "2A8F87", stb: "0B5A54", mnb: "2F918A", clb: "D64545", btx: "FFFFFF"}
    t["Red"]       := {bg: "9B2226", fld: "FDECEC", ftx: "4A1013", arr: "9B4B4E", stb: "7A1A1D", mnb: "B24A4E", clb: "3D0E10", btx: "FFFFFF"}
    t["Orange"]    := {bg: "D9731A", fld: "FFF3E6", ftx: "5A2D05", arr: "A8641E", stb: "A85A12", mnb: "C98641", clb: "8E2A1F", btx: "FFFFFF"}
    t["Pink"]      := {bg: "C2417C", fld: "FFEAF3", ftx: "5C1636", arr: "9C4A72", stb: "9C2F62", mnb: "D06A9B", clb: "8E2A1F", btx: "FFFFFF"}
    t["Slate"]     := {bg: "4A5560", fld: "ECEFF2", ftx: "232A31", arr: "5E6B78", stb: "36404A", mnb: "6A7782", clb: "B03A2E", btx: "FFFFFF"}
    t["Sky"]       := {bg: "3AA0E0", fld: "EAF6FF", ftx: "0B3A5C", arr: "3C86B8", stb: "1F78B4", mnb: "5CB3E8", clb: "D64545", btx: "FFFFFF"}
    t["Cyan"]      := {bg: "0891A5", fld: "E3FAFD", ftx: "053B44", arr: "2A8A99", stb: "06707F", mnb: "2AA3B5", clb: "D64545", btx: "FFFFFF"}
    t["Lime"]      := {bg: "7CB518", fld: "F4FBE3", ftx: "2A3F05", arr: "5C8A12", stb: "5A8A0F", mnb: "91C23A", clb: "C0392B", btx: "FFFFFF"}
    t["Yellow"]    := {bg: "F2C230", fld: "FFFBE6", ftx: "4A3A00", arr: "9A7B10", stb: "8A6A00", mnb: "A67F00", clb: "B03A2E", btx: "FFFFFF"}
    t["Maroon"]    := {bg: "6B1B2E", fld: "FBE9EE", ftx: "3A0D18", arr: "9C5565", stb: "4D1220", mnb: "8A3A4C", clb: "2E0A12", btx: "FFFFFF"}
    t["Brown"]     := {bg: "5D4037", fld: "F3E9E4", ftx: "2E1D17", arr: "8D6E63", stb: "3E2723", mnb: "7A5A4F", clb: "C0392B", btx: "FFFFFF"}
    t["Indigo"]    := {bg: "3F3D9E", fld: "ECEBFF", ftx: "1F1E5A", arr: "5A58B8", stb: "2E2C7A", mnb: "5B59B5", clb: "D64545", btx: "FFFFFF"}
    t["Gray"]      := {bg: "8A8F98", fld: "F2F3F5", ftx: "22262B", arr: "5F656E", stb: "5A606A", mnb: "6F757F", clb: "B03A2E", btx: "FFFFFF"}
    t["Charcoal"]  := {bg: "2B2F36", fld: "3A3F47", ftx: "ECECEC", arr: "A0A6AF", stb: "4A505A", mnb: "4A505A", clb: "B03A2E", btx: "FFFFFF"}
    t["Midnight"]  := {bg: "0B1530", fld: "1B2A4F", ftx: "DCE6FF", arr: "7F93C4", stb: "2F4C93", mnb: "26396B", clb: "B03A2E", btx: "FFFFFF"}
    t["Black"]     := {bg: "000000", fld: "1A1A1A", ftx: "F2F2F2", arr: "8A8A8A", stb: "2B2B2B", mnb: "2B2B2B", clb: "B03A2E", btx: "FFFFFF"}
    return t
}

; Settings are kept in %AppData%\Bangla Keyboard\Bangla Keyboard.dat so the program also works when
; installed in Program Files. Earlier builds used other names or places (bangla_keyboard_config.ini, the
; BanglaKeyboard folder, Settings.ini): the first one found is carried over once.
PrepareDataDir() {
    try DirCreate(App.dataDir)
    if FileExist(App.ini)
        return
    oldDir := A_AppData "\BanglaKeyboard"                         ; folder name of the first builds (no space)
    for prev in [App.dataDir "\bangla_keyboard_config.ini", App.dataDir "\bkb_cfg.dat", oldDir "\bangla_keyboard_config.ini"
        , oldDir "\Settings.ini", App.dataDir "\Settings.ini"] {
        if FileExist(prev) {
            try FileMove(prev, App.ini)
            if FileExist(App.ini) {
                try DirDelete(oldDir)                              ; only succeeds when the old folder is empty
                return
            }
        }
    }
    old := A_ScriptDir "\Settings.ini"
    if FileExist(old)
        try FileCopy(old, App.ini)
}

LoadSettings() {
    App.onTop := (IniRead(App.ini, "General", "AlwaysOnTop", "1") = "1")
    App.theme := IniRead(App.ini, "General", "Theme", "DarkGreen")
    if !Themes().Has(App.theme)
        App.theme := "DarkGreen"
    App.style := IniRead(App.ini, "General", "BarStyle", "GreenBangla")
    if (StyleIds()[StyleIndex(App.style)] != App.style)
        App.style := "GreenBangla"
    n := IniRead(App.ini, "General", "IconPx", "20")        ; saved as the size in pixels
    App.iconSize := 1
    for k, v in IconSizes() {
        if (v = n)
            App.iconSize := k
    }
    App.barX := IniRead(App.ini, "Bar", "X", "")
    App.barY := IniRead(App.ini, "Bar", "Y", "")
    App.perWin := (IniRead(App.ini, "General", "ModeSwitching", "Global") = "PerWindow")
    App.splashOn := (IniRead(App.ini, "General", "ShowSplash", "1") = "1")
    App.startMin := (IniRead(App.ini, "General", "StartMinimized", "0") = "1")
    App.trayAlways := (IniRead(App.ini, "General", "TrayAlways", "1") = "1")
    App.toolsSub := (IniRead(App.ini, "General", "ToolsSubmenu", "1") = "1")
    App.layoutSub := (IniRead(App.ini, "General", "LayoutsSubmenu", "0") = "1")
    App.confirmClose := (IniRead(App.ini, "General", "ConfirmClose", "1") = "1")
    App.tips := (IniRead(App.ini, "General", "ShowTips", "1") = "1")
    App.helperOn := (IniRead(App.ini, "Extra", "PerformanceHelper", "1") != "0")
    App.helperTray := (IniRead(App.ini, "Extra", "PerformanceHelperTray", "0") = "1")
    App.avroOn := (IniRead(App.ini, "General", "AvroPhonetic", "0") = "1")
    secs := IniRead(App.ini, "General", "SplashSeconds", "2")
    App.splashMs := (IsNumber(secs) && secs >= 1 && secs <= 5) ? Round(secs) * 1000 : 2000      ; 1 - 5 seconds
}

; the two extra buttons of the "Default Ext" / "Ekushey BN" bar styles (each one has its own tick box in Settings)
LoadExtButtons() {
    App.ext := []
    Loop App.maxExt                                                ; button 1 is always on, the others only when ticked (off by default); buttons 3 and up exist only in the [+] skins that have them
        App.ext.Push({on: (A_Index = 1) ? true : (IniRead(App.ini, "ExtButtons", "Button" . A_Index . ".Enabled", "0") = "1")
            , act: IniRead(App.ini, "ExtButtons", "Button" . A_Index . ".Action", "")
            , icon: IniRead(App.ini, "ExtButtons", "Button" . A_Index . ".Icon", "App icon")})
}

; the numbers of the extra buttons shown on the bar: [1] or [1, 2] (the Default / Ekushey / Bangla styles have two; the [+] skins read App.ext themselves)
ExtShown() {
    a := []
    for i, b in App.ext {
        if (i > 2)
            break
        if b.on
            a.Push(i)
    }
    return a
}

SaveSetting(section, key, value) {
    try IniWrite(value, App.ini, section, key)
}

; A layout file is XML. It may be a plain .xml, or a locked .bkl (made with Tools\Pupo Encrypter.ahk; same content, scrambled).
; Both are read. If both exist with the same name, the .bkl one is used (the .xml is listed first, so the .bkl replaces it).
LoadLayouts() {
    App.layouts := []
    found := Map()
    for ext in ["xml", "bkl"] {
        Loop Files A_ScriptDir "\Layouts\*." . ext {
            if (StrLower(A_LoopFileExt) != ext)
                continue
            SplitPath(A_LoopFileFullPath, , , , &nm)
            found[StrLower(nm)] := {nm: nm, file: A_LoopFileName, path: A_LoopFileFullPath}
        }
    }
    files := []
    for k, f in found
        files.Push(f)
    Loop files.Length {                                  ; keep the layouts in file-name order
        i := A_Index
        f := files[i]
        j := i - 1
        while (j >= 1 && StrCompare(files[j].nm, f.nm) > 0) {
            files[j + 1] := files[j]
            j--
        }
        files[j + 1] := f
    }
    for f in files {
        try {
            App.layouts.Push(Layout.Load(f.path))
        } catch as e {
            MsgBox("Could not read this layout file:`n" f.file "`n`n" e.Message, "Bangla Keyboard", 0x10)
        }
    }
    if (App.layouts.Length = 0) {
        MsgBox("No layout files were found in the Layouts folder.", "Bangla Keyboard", 0x10)
        ExitApp()
    }
    if App.avroOn
        App.layouts.Push(AvroLayout())                  ; always the last layout
    App.lastBn := 1
    for i, L in App.layouts {
        if InStr(L.name, "unicode") {
            App.lastBn := i
            break
        }
    }
}

; ---- typing ----------------------------------------------------------------
TypingKey(vk, shifted, *) {
    Critical "On"
    if App.fontOn {                                   ; Fonts feature: re-check the font when typing starts after a pause / the cursor moved
        now := A_TickCount
        if (App.fontDirty || now - App.lastKey > 1500)
            FontApply()
        App.lastKey := now
    }
    if App.avroActive {                               ; Avro Phonetic: its own engine
        Avro.Key(vk, shifted)
        return
    }
    eng := App.eng
    lay := eng.lay
    has := shifted ? lay.sh.Has(vk) : lay.nor.Has(vk)
    if !has {
        ; this layout does not use the key: let it through as normal
        eng.Reset()
        Send("{Blind}{vk" . Format("{:X}", vk) . "}")
        Snip.Add(KeyChar(vk, shifted))
        return
    }
    txt := shifted ? lay.sh[vk] : lay.nor[vk]
    if (txt == " ") {
        eng.Track(" ")
        Send("{Blind}{Space}")
        Snip.Add(" ")
        return
    }
    old := eng.buf
    r := eng.Press(vk, shifted)
    enc := ActiveEnc()
    if IsObject(enc) {
        ; an encoding is chosen: what is on the screen is the ANSI form of the Unicode text, so only the changed end is retyped
        a0 := enc.Conv(old)
        a1 := enc.Conv(eng.pend)
        n := Min(StrLen(a0), StrLen(a1))
        p := 0
        while (p < n && SubStr(a0, p + 1, 1) == SubStr(a1, p + 1, 1))
            p += 1
        SendOut(StrLen(a0) - p, SubStr(a1, p + 1))
    } else {
        SendOut(r[1], r[2])
    }
    Snip.Edit(r[1], r[2])
}

ResetKey(*) {
    if (App.fontOn && !RegExMatch(A_ThisHotkey, "i)^~[LR](Ctrl|Alt|Win)$"))
        App.fontDirty := true
    if App.avroActive
        Avro.Commit()
    if IsObject(App.eng)
        App.eng.Reset()
    if (A_ThisHotkey = "~*BS")
        Snip.Back()
    else
        Snip.Clear()
}

RegisterTypingKeys() {
    vks := Map()
    for L in App.layouts {
        for vk in L.nor
            vks[vk] := 1
        for vk in L.sh
            vks[vk] := 1
    }
    Loop 10
        vks[47 + A_Index] := 1
    for vk in [32, 186, 187, 188, 189, 190, 191, 192, 219, 220, 221, 222]
        vks[vk] := 1
    HotIf()
    names := []
    for vk in vks {
        n := Format("vk{:X}", vk)
        Hotkey("$" . n, TypingKey.Bind(vk, false), "Off")
        Hotkey("$+" . n, TypingKey.Bind(vk, true), "Off")
        names.Push("$" . n, "$+" . n)
    }
    ; keys that only clear the look-back buffer and then behave normally
    for n in ["~*Enter", "~*NumpadEnter", "~*Tab", "~*Esc", "~*BS", "~*Delete", "~*Left", "~*Right"
        , "~*Up", "~*Down", "~*Home", "~*End", "~*PgUp", "~*PgDn", "~*LButton", "~*RButton", "~*MButton"
        , "~LCtrl", "~RCtrl", "~LAlt", "~RAlt", "~LWin", "~RWin"] {
        Hotkey(n, ResetKey, "Off")
        names.Push(n)
    }
    HotIf()
    App.typingNames := names
    App.vkSet := vks
}

; Typing hotkeys exist only while a Bangla layout is active, so English is untouched.
EnableTyping(on) {
    if (on = App.typingOn)
        return
    HotIf()
    for n in App.typingNames {
        if (on && App.avroActive && n = "~*BS")
            continue                                   ; Avro Phonetic handles Backspace itself
        try Hotkey(n, on ? "On" : "Off")
    }
    HotIf()
    App.typingOn := on
}

; ---- keyboard mode switching: Global / Per Application-Window ---------------
; Can this window own a mode? (not our own windows, not the taskbar / desktop)
IsBindable(hwnd) {
    if !hwnd
        return false
    try {
        if (WinGetPID("ahk_id " . hwnd) = ProcessExist())
            return false
        cls := WinGetClass("ahk_id " . hwnd)
        if RegExMatch(cls, "^(Shell_TrayWnd|Shell_SecondaryTrayWnd|NotifyIconOverflowWindow|TopLevelWindowForOverflowXamlIsland|Progman|WorkerW|#32768)$")
            return false
        return true
    }
    return false
}

; Windows tells us at once when another window becomes the active one
InstallForegroundHook() {
    cb := CallbackCreate(OnForeground, , 7)
    App.fgHook := DllCall("SetWinEventHook", "UInt", 3, "UInt", 3, "Ptr", 0, "Ptr", cb, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")
    OnExit(CleanupOnExit)
}

; Must return 0 (or nothing): a non-zero return value cancels the exit.
CleanupOnExit(*) {
    if App.fgHook {
        DllCall("UnhookWinEvent", "Ptr", App.fgHook)
        App.fgHook := 0
    }
    return 0
}

; Per-window mode: switch to the mode that the newly active window had (new windows start in English)
OnForeground(hHook, ev, hwnd, idObj, idChild, thr, tm) {
    if App.onTop
        SetTimer(KeepOnTop, -80)               ; the newly active window may have covered the bar: bring it back
    if (!(App.perWin || App.fontOn) || !IsBindable(hwnd) || hwnd = App.curWin)
        return
    App.curWin := hwnd
    fa := IsFontApp(hwnd)                   ; Office app with the Fonts feature on: it remembers its own mode
    if !fa
        App.fontCom := Map()                ; let go of Word / Excel / PowerPoint
    if (App.winModes.Count > 300) {
        for h in App.winModes.Clone() {
            if !WinExist("ahk_id " . h)
                App.winModes.Delete(h)
        }
    }
    m := (App.perWin || fa) ? App.winModes.Get(hwnd, 0) : App.globMode
    if (m > 0 && !IsShown("L:" . App.layouts[m].name))
        m := 0
    ApplyLayout(m)
}

; ---- switching layouts -----------------------------------------------------
SetLayout(i, *) {
    if (i < 0 || i > App.layouts.Length)
        return
    if (App.curWin && (App.perWin || IsFontApp(App.curWin)))
        App.winModes[App.curWin] := i          ; only the current window changes
    else
        App.globMode := i
    if (i > 0)
        App.lastBn := i
    ApplyLayout(i)
}

ApplyLayout(i) {
    App.cur := i
    App.manualHold := 0
    if (i > 0)
        App.eng := Engine(App.layouts[i])
    AvroMode(i > 0 && App.layouts[i].kind = "avro")
    EnableTyping(i > 0 ? true : false)
    RefreshUI()
    if App.fontOn
        FontKick()
}

; Shortcut of a layout: first press switches it on, pressing it again goes back to English
ToggleLayout(i, *) {
    SetLayout(App.cur = i ? 0 : i)
}

ToggleEnglish(*) {
    SetLayout(App.cur = 0 ? App.lastBn : 0)
}

ToggleBar(*) {
    if DllCall("IsWindowVisible", "ptr", App.bar.Hwnd)
        HideBar()
    else
        ShowBar()
}

CurrentName() {
    return App.cur = 0 ? "English" : App.layouts[App.cur].name
}

; the order the layouts are listed in: alphabetical by name (Avro Phonetic is one of them)
LayoutOrder() {
    order := []
    for i, L in App.layouts {
        j := order.Length
        while (j >= 1 && StrCompare(App.layouts[order[j]].name, L.name) > 0)       ; insertion sort
            j--
        order.InsertAt(j + 1, i)
    }
    return order
}

; Icon files for English (i = 0) or a layout, best first. The names are tried in this order: <IconName> from the layout file,
; the layout's own name, then "Unicode"; and for each name a picture Icons\<name>.png wins over Icons\<name>.ico.
; Avro Phonetic first looks for any avro*.png / avro*.ico in the Icons folder.
IconCandidates(i) {
    names := []
    if (i = 0)
        names := ["English"]
    else {
        L := App.layouts[i]
        names := [L.icon, L.name, "Unicode"]
    }
    list := []
    if (i > 0 && App.layouts[i].kind = "avro") {           ; Avro Phonetic: any Icons\avro*.png / avro*.ico (avro.png, avro.ico, Avro Phonetic.png ...) comes first
        for ext in ["png", "ico"] {
            Loop Files App.dir . "\Icons\avro*." . ext
                list.Push(A_LoopFileFullPath)
        }
    }
    for n in names {
        if (n = "")
            continue
        for ext in ["png", "ico"] {
            p := App.dir . "\Icons\" . n . "." . ext
            if FileExist(p)
                list.Push(p)
        }
    }
    return list
}

; the icon sizes in pixels, biggest first (same order as the names in IconSizeLabels)
IconSizes() {
    return [20, 19, 18, 17, 16, 15, 14]
}

IconSizeLabels() {
    return ["Original", "Regular", "Medium", "Reduced", "Compact", "Petite", "Smaller"]
}

; Put a .png in an icon box of the tray: the tray wants an icon file, so the picture is wrapped in a small .ico (a PNG is a valid
; icon image). Pictures bigger than 256 px cannot be wrapped: those are skipped (the next candidate, usually the .ico, is used).
PngAsIcon(png) {
    try {
        f := FileOpen(png, "r")
        n := f.Length
        buf := Buffer(n)
        f.RawRead(buf, n)
        f.Close()
        if (n < 24 || NumGet(buf, 1, "UChar") != 0x50 || NumGet(buf, 2, "UChar") != 0x4E || NumGet(buf, 3, "UChar") != 0x47)
            return ""
        w := NumGet(buf, 18, "UChar") * 256 + NumGet(buf, 19, "UChar")       ; width / height are big-endian in the PNG header
        h := NumGet(buf, 22, "UChar") * 256 + NumGet(buf, 23, "UChar")
        if (w < 1 || h < 1 || w > 256 || h > 256)
            return ""
        ico := Buffer(22 + n, 0)
        NumPut("UShort", 0, "UShort", 1, "UShort", 1, ico, 0)                ; ICONDIR: reserved, type = icon, 1 image
        NumPut("UChar", (w = 256) ? 0 : w, "UChar", (h = 256) ? 0 : h, "UChar", 0, "UChar", 0, ico, 6)
        NumPut("UShort", 1, "UShort", 32, "UInt", n, "UInt", 22, ico, 10)    ; planes, bits, size of the image, where it starts
        DllCall("RtlMoveMemory", "ptr", ico.Ptr + 22, "ptr", buf.Ptr, "uptr", n)
        out := A_Temp . "\BanglaKeyboard_tray.ico"
        o := FileOpen(out, "w")
        o.RawWrite(ico, ico.Size)
        o.Close()
        return out
    }
    return ""
}

; the tray icon follows the current layout: the same files as the bar, .png first
SetTrayIconFile() {
    for p in IconCandidates(App.cur) {
        if (StrLower(SubStr(p, -4)) = ".png") {
            q := PngAsIcon(p)
            if (q != "") {
                try {
                    TraySetIcon(q)
                    return
                }
            }
            continue
        }
        try {
            TraySetIcon(p)
            return
        }
    }
}

; ---- shortcut keys -----------------------------------------------------------
; Every action that can have a shortcut. "def" is the built-in default.
ActionList() {
    a := []
    a.Push({id: "Toggle", label: "Toggle On/Off", def: "F5", cb: ToggleEnglish})
    a.Push({id: "English", label: "English", def: "^!e", cb: ToggleEnglish})
    for i in LayoutOrder()
        a.Push({id: "L:" . App.layouts[i].name, label: App.layouts[i].name, def: App.layouts[i].hotkey, cb: ToggleLayout.Bind(i)})
    for f in ToolFiles()                                ; every program / script found in the Tools folder (ticked = its shortcut starts it)
        a.Push({id: "R:" . f.full, label: f.name, def: "", cb: RunTool.Bind(f.path)})
    return a
}

; Win-key combinations and the old "special key" shortcuts (~ & |) cannot be shown in the key box
IsUnsupportedHk(hk) {
    return RegExMatch(hk, "[#&~|]") ? true : false
}

IniKey(id) {
    return "Key_" . RegExReplace(id, "[^\w]", "_")
}

LoadShortcuts() {
    App.shortcuts := Map()
    for a in ActionList() {
        v := IniRead(App.ini, "Shortcuts", IniKey(a.id), "<default>")
        if (v = "<default>") {
            v := a.def
            if (a.id = "Toggle") {
                old := IniRead(App.ini, "General", "ToggleHotkey", "")      ; settings file of older versions
                if (old != "")
                    v := old
            }
        } else if (v = "none")
            v := ""
        else if IsUnsupportedHk(v)
            v := a.def                      ; older versions allowed Win / special keys; they are gone now
        App.shortcuts[a.id] := v
    }
}

; Items ticked in Settings > Layouts / Extra Tools are listed in the bar menu / tray menu and their shortcut works.
; Unticked items are hidden and their shortcut is switched off. (Tools programs are always listed in the tray menu;
; the tick only switches their shortcut on, and starts unticked.)
IsShown(id) {
    return App.shown.Get(id, true)
}

LoadShown() {
    App.shown := Map()
    any := false
    for a in ActionList() {
        v := (IniRead(App.ini, "Shown", IniKey(a.id), (SubStr(a.id, 1, 2) = "R:") ? "0" : "1") != "0")
        App.shown[a.id] := v
        if (v && SubStr(a.id, 1, 2) = "L:")
            any := true
    }
    if !any {                                   ; never leave the program without a Bangla layout
        for L in App.layouts
            App.shown["L:" . L.name] := true
    }
    FixLastBn()
}

; the layout used by the On/Off toggle must be one that is listed
FixLastBn() {
    if (App.lastBn >= 1 && App.lastBn <= App.layouts.Length && IsShown("L:" . App.layouts[App.lastBn].name))
        return
    for i, L in App.layouts {
        if IsShown("L:" . L.name) {
            App.lastBn := i
            return
        }
    }
}

UnregisterShortcuts() {
    HotIf()
    for n in App.regNames {
        try Hotkey(n, "Off")
    }
    App.regNames := []
}

ApplyShortcuts() {
    UnregisterShortcuts()
    HotIf()
    for a in ActionList() {
        hk := App.shortcuts.Get(a.id, "")
        if (hk = "" || !IsShown(a.id))
            continue
        for part in StrSplit(hk, "|") {
            if (part = "")
                continue
            try {
                Hotkey(part, a.cb, "On")
                App.regNames.Push(part)
            }
        }
    }
    if App.manualOn {                                     ; manual font slots (Win key allowed; "$" = always catch it, even over Windows' own Win+number)
        for i, sl in App.slots {
            if (sl.key = "" || sl.font = "")
                continue
            try {
                Hotkey("$" . sl.key, FontManual.Bind(i), "On")
                App.regNames.Push("$" . sl.key)
            }
        }
    }
    if App.encOn {                                        ; one shortcut per encoding (Win key allowed)
        for nm, hk in App.encKeys {
            if (hk = "")
                continue
            try {
                Hotkey("$" . hk, EncHotkey.Bind(nm), "On")
                App.regNames.Push("$" . hk)
            }
        }
    }
}

; "^!vk56" -> {mods: "^!", key: "vk56"}
SplitHk(hk) {
    mods := ""
    while (hk != "" && InStr("^!+#", SubStr(hk, 1, 1))) {
        mods .= SubStr(hk, 1, 1)
        hk := SubStr(hk, 2)
    }
    return {mods: mods, key: hk}
}

PrettyHk(hk) {
    if (hk = "")
        return "(none)"
    p := SplitHk(hk)
    s := ""
    Loop Parse p.mods
        s .= (A_LoopField = "^") ? "Ctrl+" : (A_LoopField = "!") ? "Alt+" : (A_LoopField = "+") ? "Shift+" : "Win+"
    return s . StrUpper(GetKeyName(p.key))
}

; ---- tray -------------------------------------------------------------------
BuildTrayMenu() {
    tm := A_TrayMenu
    tm.Delete()
    tm.Add("Show / Hide bar", ToggleBar)
    tm.Add()
    if App.layoutSub {
        App.trayLay := Menu()
        AddLayoutItems(App.trayLay)
        tm.Add("Layouts", App.trayLay)
    } else {
        App.trayLay := ""
        AddLayoutItems(tm)
    }
    tm.Add()
    if EncMenuOn() {                       ; Library folder: the encoding the typed Unicode is converted to
        App.encMenu := MakeEncMenu()
        tm.Add("Encoding", App.encMenu)
        if !EncUsable()
            try tm.Disable("Encoding")
        tm.Add()
    } else {
        App.encMenu := ""
    }
    files := ToolFiles()                   ; programs / scripts in the Tools folder: a "Tools" submenu (default) or a plain list
    if (files.Length > 0) {
        if App.toolsSub {
            App.toolMenu := Menu()
            for f in files
                App.toolMenu.Add(StrReplace(f.name, "&", "&&"), RunTool.Bind(f.path))
            tm.Add("Tools", App.toolMenu)
        } else {
            App.toolMenu := ""
            used := Map()                  ; menu items are found by name, so a tool must not share a name with another item
            used.CaseSense := "Off"
            for n in ["Show / Hide bar", "English", "Settings...", "About...", "Exit"]
                used[n] := 1
            for L in App.layouts
                used[StrReplace(L.name, "&", "&&")] := 1
            for f in files {
                nm := StrReplace(f.name, "&", "&&")
                if used.Has(nm)
                    nm .= " (tool)"
                used[nm] := 1
                tm.Add(nm, RunTool.Bind(f.path))
            }
        }
    }
    tm.Add()
    tm.Add("Settings...", ShowSettings)
    tm.Add("About...", ShowAbout)
    tm.Add("Exit", CloseBar)
    ; no default menu item: left clicks on the tray icon are handled by TrayClick below
    ;   single click = toggle On/Off (English <-> last Bangla layout), double click = show / hide the bar
    if !App.trayHooked {
        OnMessage(0x404, TrayClick)          ; AHK_NOTIFYICON
        App.trayHooked := true
    }
}

; every .exe and .ahk file in the Tools folder next to this script
ToolFiles() {
    list := []
    count := Map()
    Loop Files App.dir . "\Tools\*.*" {
        if RegExMatch(A_LoopFileExt, "i)^(exe|ahk)$") {
            base := RegExReplace(A_LoopFileName, "\.[^.]*$")             ; file name without the extension
            count[StrLower(base)] := count.Get(StrLower(base), 0) + 1
            list.Push({name: base, full: A_LoopFileName, path: A_LoopFileFullPath})
        }
    }
    for f in list {
        if (count[StrLower(f.name)] > 1)
            f.name := f.full                                              ; same name twice (e.g. Tool.exe + Tool.ahk): keep the extension so both show
    }
    return list
}

RunTool(path, *) {
    SplitPath(path, &nm, &dir, &ext)
    try {
        if (StrLower(ext) = "ahk" && FileExist(A_AhkPath))
            Run('"' . A_AhkPath . '" "' . path . '"', dir)
        else
            Run('"' . path . '"', dir)
    } catch as e {
        MsgBox("Could not start " . nm . "`n`n" . e.Message, "Bangla Keyboard", 0x10)
    }
}

TrayClick(wParam, lParam, msg, hwnd) {
    if (hwnd != A_ScriptHwnd)
        return
    if (lParam = 0x205) {                    ; WM_RBUTTONUP: the menu is about to open - re-read the Tools folder first
        BuildTrayMenu()
        MarkLayouts(IsObject(App.trayLay) ? App.trayLay : A_TrayMenu)
        return
    }
    if (lParam = 0x203) {                    ; WM_LBUTTONDBLCLK
        SetTimer(ToggleEnglish, 0)           ; cancel the pending single-click action
        App.trayDbl := true
        ToggleBar()
        return 0
    }
    if (lParam = 0x202) {                    ; WM_LBUTTONUP
        if App.trayDbl {                     ; the release that ends a double click
            App.trayDbl := false
            return 0
        }
        SetTimer(ToggleEnglish, -DllCall("GetDoubleClickTime", "UInt"))   ; wait to see if a 2nd click follows
        return 0
    }
}

; The tray icon is always shown, or - when "Always show the tray icon" is off - only while the bar is hidden.
SyncTray() {
    if !IsObject(App.bar)
        return
    want := App.trayAlways ? false : (DllCall("IsWindowVisible", "ptr", App.bar.Hwnd) != 0)     ; hide the icon while the bar is on screen (unless it is set to stay)
    try {
        if (A_IconHidden != want)
            A_IconHidden := want
    }
}

UpdateTray() {
    MarkLayouts(IsObject(App.trayLay) ? App.trayLay : A_TrayMenu)
    SetTrayIconFile()
    A_IconTip := "Bangla Keyboard - " . CurrentName() . (IsObject(ActiveEnc()) ? " [" . App.encName . "]" : "") . (App.perWin ? " (per window)" : "")
    SyncTray()                  ; TraySetIcon must not bring the icon back while the bar is visible
}

RefreshUI() {
    UpdateTray()
    UpdateBar()
}

; ---- start with Windows -------------------------------------------------------
StartupLink() {
    return A_Startup "\Bangla Keyboard.lnk"
}

IsAutoStart() {
    return FileExist(StartupLink()) != ""
}

SetAutoStart(on) {
    lnk := StartupLink()
    try {
        if on {
            if A_IsCompiled {          ; installed .exe: start the program itself
                FileCreateShortcut(A_ScriptFullPath, lnk, A_ScriptDir, "", "Bangla Keyboard", App.dir "\Icons\Unicode.ico")
            } else {
                FileCreateShortcut(A_AhkPath, lnk, A_ScriptDir, '"' A_ScriptFullPath '"', "Bangla Keyboard", App.dir "\Icons\Unicode.ico")
            }
        } else if FileExist(lnk) {
            FileDelete(lnk)
        }
    }
}

; Picture-control text for the current layout's icon (loaded as a handle, which is the most reliable way).
; The first file that loads wins: a .png before an .ico (see IconCandidates). It is loaded at the size of the icon box (App.picSz).
PicSpec() {
    sz := App.picSz
    for f in IconCandidates(App.cur) {
        h := 0
        type := 0
        isIco := (StrLower(SubStr(f, -4)) = ".ico")
        try {
            h := LoadPicture(f, (isIco ? "Icon1 " : "") . "w" . sz . " h" . sz, &type)
        }
        if h
            return ((type = 1) ? "HICON:" : "HBITMAP:") . h
    }
    throw Error("no icon picture")                       ; the caller shows the letter badge instead
}

; The icon of the bar: a square that always stays centred on the middle of its place (x = left edge of the old 20 px icon box, so
; the centre is x + 10, and the middle of the bar height), whatever the "Icon size" setting is: Original = 20 px (as it always was),
; then Regular 19, Medium 18, Reduced 17, Compact 16, Petite 15, Smaller 14 (see IconSizes). It never gets wider than the room up to the name box (nameX).
AddBarIcon(g, x, nameX, barH, badgeOpt) {
    cx := x + 10
    s := IconSizes()[Min(7, Max(1, App.iconSize))]
    s := Max(8, Min(s, barH, 2 * (nameX - cx), 2 * cx))
    ix := cx - s // 2
    iy := (barH - s) // 2
    App.picSz := s
    pos := "x" . ix . " y" . iy . " w" . s . " h" . s
    try {
        App.pic := g.Add("Picture", pos . " BackgroundTrans", PicSpec())
    } catch {
        ; never fail because of the icon: show a small letter badge instead
        App.pic := g.Add("Text", pos . " Center +0x200 " . badgeOpt, IconBadge())
        App.pic.SetFont("s" . Max(6, Min(10, s * 2 // 5)) . " bold", "Segoe UI")
    }
}

IconBadge() {
    if (App.cur = 0)
        return "E"
    n := App.layouts[App.cur].icon
    if (n = "" && App.layouts[App.cur].kind = "avro")
        return "A"
    return (n = "") ? "B" : SubStr(n, 1, 1)
}

; ---------------------------------------------------------------------------
;  The top bar:  [icon + drag] [layout dropdown] [settings] [minimize to tray] [close]
; ---------------------------------------------------------------------------
BuildBar() {
    th := Themes()[App.theme]
    opts := "-Caption +ToolWindow +E0x08000000 " . (App.onTop ? "+AlwaysOnTop" : "")
    g := Gui(opts, "Bangla Keyboard")
    g.BackColor := th.bg
    g.MarginX := 0
    g.MarginY := 0
    App.bar := g
    App.hov := []                      ; (the old buttons are gone with the old bar)
    App.hovCur := 0

    barW := 232
    barH := 24
    App.picSz := 20
    App.skinTrans := false
    App.skinMode := false
    if (IsSkinId(App.style) && FileExist(StyleDir() . "skin.ini")) {          ; a skin of the Skins folder (skin.ini)
        barW := BuildBarSkin(g)
        barH := App.skinH
    } else if (!IsSkinId(App.style) && !UsesTheme(App.style) && FileExist(StyleDir() . "bar_bg.png")) {
        barH := (App.style = "GreenBangla") ? 26 : 24      ; every style is as thin as Classic, except Bijoy Bayanno (1 px more on top and bottom)
        if (App.style = "AeroDark") {
            BuildBarAero(g)
            barW := 258
        } else if (App.style = "PurpleRaised") {
            BuildBarPurple(g)
            barW := 258
        } else if (App.style = "EkusheDark") {
            barW := BuildBarEkushe(g)
        } else if (App.style = "EkusheBN") {
            barW := BuildBarEkushe(g, true, ExtShown())
        } else if (App.style = "BanglaKb") {
            barW := BuildBarBanglaKb(g, ExtShown())
        } else {
            BuildBarGreen(g)
            barW := 260
        }
    } else
        barW := BuildBarClassic(g, th, App.style = "ClassicExt" ? ExtShown() : [])

    if !App.msgHooked {
        OnMessage(0x201, BarMouseDown)     ; WM_LBUTTONDOWN: drag from the icon / empty parts
        OnMessage(0x232, BarMoved)         ; WM_EXITSIZEMOVE: remember where it was dropped
        OnMessage(0x200, HoverMove)        ; WM_MOUSEMOVE: light up the bar button under the mouse
        App.msgHooked := true
    }

    realW := Round(barW * A_ScreenDPI / 96)
    x := App.barX
    y := App.barY
    if !(IsNumber(x) && IsNumber(y) && PointOnScreen(x + 20, y + 10)) {
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
        x := l + (r - l - realW) // 2
        y := t
    }
    g.Show("NoActivate w" . barW . " h" . barH . " x" . x . " y" . y)
    WinGetPos(, , &w, &h, "ahk_id " . g.Hwnd)
}

BuildBarClassic(g, th, ext := []) {
    ; icon of the current layout = state indicator and the handle for moving the bar
    AddBarIcon(g, 4, 28, 24, "Background" . th.fld . " c" . th.ftx)

    ; "dropdown": a box that opens the layout list (a little narrower on "Default Ext", to make room for its buttons)
    nw := 100 - 6 * ext.Length
    App.nameCtl := g.Add("Text", "x28 y2 w" . nw . " h20 +0x200 +0x100 Background" . th.fld . " c" . th.ftx, "  " . CurrentName())
    App.nameCtl.SetFont("s8 bold", "Segoe UI")
    x := 28 + nw
    arrow := g.Add("Text", "x" . x . " y2 w18 h20 Center +0x200 +0x100 Background" . th.fld . " c" . th.arr, "▼")
    arrow.SetFont("s8", "Segoe UI Symbol")
    App.nameCtl.OnEvent("Click", ShowLayoutMenu)
    arrow.OnEvent("Click", ShowLayoutMenu)
    x += 23

    for i in ext {                                                 ; the ticked extra buttons, left of the settings button
        AddExtButton(g, i, x, 2, 24, 20, "", th.stb, th.btx, 16)
        x += 27
    }

    ; settings, minimize to tray, close
    bSet := g.Add("Text", "x" . x . " y2 w24 h20 Center +0x200 +0x100 Background" . th.stb . " c" . th.btx, "⚙")
    bSet.SetFont("s9", "Segoe UI Symbol")
    bSet.OnEvent("Click", ShowSettings)
    AddColorHover(bSet, th.stb)
    x += 27
    bMin := g.Add("Text", "x" . x . " y2 w24 h20 Center +0x200 +0x100 Background" . th.mnb . " c" . th.btx, "−")
    bMin.SetFont("s10 bold", "Segoe UI")
    bMin.OnEvent("Click", HideBar)
    AddColorHover(bMin, th.mnb)
    x += 27
    bClose := g.Add("Text", "x" . x . " y2 w24 h20 Center +0x200 +0x100 Background" . th.clb . " c" . th.btx, "×")
    bClose.SetFont("s10 bold", "Segoe UI")
    bClose.OnEvent("Click", CloseBar)
    AddColorHover(bClose, th.clb)
    bClose.OnEvent("DoubleClick", CloseBar)      ; a quick second click would otherwise be ignored
    g.OnEvent("Close", BarCloseEvent)            ; Alt+F4 etc. behave the same as the [x] button
    return x + 27                                ; width of the bar
}

; ---- the two extra buttons ("Default Ext" and "Ekushey BN" styles) ----------------------------------------------
; Each button starts one program / script from the Tools folder (chosen in Settings > General) and shows the icon
; chosen there. Pictures put in Skins\Button Icons appear in that icon list too.
; The built-in icons are grouped by the tool they suit: Docs Converter, Text Converter, Layout Builder, Quick Note.
ExtGlyphs() {
    ; icons that suit the tools that come with the program, with a few variants each (name, Unicode character)
    static t := [["Docs: File", 0x1F4C4], ["Docs: Pages", 0x1F4D1], ["Docs: Curl", 0x1F4C3], ["Docs: Convert", 0x1F504]
        , ["Text: Aa", 0x1F524], ["Text: abc", 0x1F521], ["Text: ABC", 0x1F520]
        , ["Text: Arrows", 0x21C4], ["Text: Swap", 0x21C6]
        , ["Layout: Keys", 0x2328], ["Layout: Ruler", 0x1F4D0], ["Layout: Wrench", 0x1F527], ["Layout: Puzzle", 0x1F9E9]
        , ["Layout: Tools", 0x1F6E0]
        , ["Note: Memo", 0x1F4DD], ["Note: Pad", 0x1F5D2], ["Note: Book", 0x1F4D3], ["Note: Pencil", 0x270E]
        , ["Note: Pin", 0x1F4CC]]
    return t
}

; names for the icon list in Settings: (None) = empty button, the program's own icon, the built-in icons, then your own pictures
ExtIconNames() {
    a := ["(None)", "App icon"]
    for g in ExtGlyphs()
        a.Push(g[1])
    Loop Files App.dir . "\Skins\Button Icons\*.*" {
        if RegExMatch(A_LoopFileExt, "i)^(png|ico|jpg|jpeg|bmp|gif)$")
            a.Push(A_LoopFileName)
    }
    return a
}

; what extra button i shows: a picture (pic, with its icon option) or a text symbol (glyph)
ExtIconInfo(i) {
    b := IsObject(i) ? i : App.ext[i]                                    ; i = a button number, or the button itself (buttons of the [+] skins)
    act := b.act
    if (StrLower(SubStr(act, 1, 5)) = "tool:")
        act := SubStr(act, 6)
    path := (act = "" || RegExMatch(act, "[\\/:]")) ? "" : App.dir . "\Tools\" . act
    ico := b.icon
    if (ico = "(Skin default)" || ico = "")
        ico := "App icon"
    if (ico = "(None)")
        return {glyph: "", pic: "", opt: "", none: true}                 ; empty button: no icon at all
    if (ico = "App icon") {
        if (path != "" && FileExist(path)) {
            SplitPath(path, , , &ext)
            if (StrLower(ext) = "exe")
                return {glyph: "", pic: path, opt: "Icon1"}
            if FileExist(A_AhkPath)
                return {glyph: "", pic: A_AhkPath, opt: "Icon1"}      ; a script: the AutoHotkey icon
        }
        return {glyph: "+", pic: "", opt: ""}                         ; nothing assigned yet
    }
    for g in ExtGlyphs() {
        if (g[1] = ico)
            return {glyph: Chr(g[2]), pic: "", opt: ""}
    }
    f := App.dir . "\Skins\Button Icons\" . ico
    if FileExist(f)
        return {glyph: "", pic: f, opt: ""}
    return {glyph: Chr(ExtGlyphs()[1][2]), pic: "", opt: ""}
}

; ---- hover effect of the bar buttons ------------------------------------------------------------------------
; Every button has a picture (name.png) and a lit picture (name_hover.png) in its style folder; the colour-based
; buttons of the Classic styles are simply drawn in a lighter colour while the mouse is over them.
BtnFile(d, name, hover := false) {
    f := d . name . (hover ? "_hover" : "") . ".png"
    return FileExist(f) ? f : ""
}

; a picture button of the bar (x, y, w, h in normal 96-dpi units); it lights up when the mouse is over it
AddPicBtn(g, d, name, x, y, w, h) {
    norm := BtnFile(d, name)
    ; Aero Dark icons are transparent PNGs: let the bar picture show through instead of the window colour
    pic := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h . (App.style = "AeroDark" || App.skinTrans ? " +BackgroundTrans" : ""), norm)
    AddHover(pic, [pic.Hwnd], norm, BtnFile(d, name, true), w, h)
    return pic
}

; remember a picture control and its two pictures (normal / lit); top = a control lying over it that must be redrawn too
AddHover(ctl, hwnds, norm, hov, w, h, top := "") {
    if (norm = "" || hov = "")
        return
    k := A_ScreenDPI / 96
    App.hov.Push({ctl: ctl, hwnds: hwnds, norm: norm, hov: hov, pw: Round(w * k), ph: Round(h * k), top: top, col: false})
}

; a button that is just a coloured box (Classic styles): lit = the same colour, lighter (darker for very light colours)
AddColorHover(ctl, hex, top := "", hovHex := "") {
    App.hov.Push({ctl: ctl, hwnds: [ctl.Hwnd], norm: hex, hov: (hovHex != "") ? hovHex : HoverColor(hex), pw: 0, ph: 0, top: top, col: true})
}

HoverColor(hex) {
    r := Integer("0x" . SubStr(hex, 1, 2)), g := Integer("0x" . SubStr(hex, 3, 2)), b := Integer("0x" . SubStr(hex, 5, 2))
    if ((r * 299 + g * 587 + b * 114) / 1000 > 170) {            ; light colour: a little darker
        r := Round(r * 0.88), g := Round(g * 0.88), b := Round(b * 0.88)
    } else {                                                      ; dark colour: a little lighter
        r := Round(r + (255 - r) * 0.24), g := Round(g + (255 - g) * 0.24), b := Round(b + (255 - b) * 0.24)
    }
    return Format("{:02X}{:02X}{:02X}", r, g, b)
}

HoverFind(h) {
    for it in App.hov {
        for x in it.hwnds {
            if (x = h)
                return it
        }
    }
    return 0
}

HoverSet(it, on) {
    try {
        if it.col {
            it.ctl.Opt("Background" . (on ? it.hov : it.norm))
            it.ctl.Redraw()
        } else {
            it.ctl.Value := "*w" . it.pw . " *h" . it.ph . " " . (on ? it.hov : it.norm)
            if (App.style = "AeroDark" || App.skinTrans)
                it.ctl.Redraw()                                    ; transparent picture: repaint what lies behind it
        }
        if IsObject(it.top)
            it.top.Redraw()
    }
}

; WM_MOUSEMOVE over the bar: check now and keep checking (every 40 ms) until the mouse has left the bar again.
; Nothing runs while the mouse is somewhere else.
HoverMove(wParam, lParam, msg, hwnd) {
    if (App.hov.Length = 0 || !IsObject(App.bar))
        return
    if (hwnd != App.bar.Hwnd) {
        c := GuiCtrlFromHwnd(hwnd)
        if !(IsObject(c) && c.Gui.Hwnd = App.bar.Hwnd)
            return
    }
    HoverTick()
    if !App.hovTimer {
        App.hovTimer := true
        SetTimer(HoverTick, 40)
    }
}

HoverTick() {
    it := 0
    over := false
    try {
        MouseGetPos(, , &win, &ctl, 2)
        if (IsObject(App.bar) && win = App.bar.Hwnd) {
            over := true
            it := HoverFind(ctl)
        }
    }
    if (it != App.hovCur) {
        if IsObject(App.hovCur)
            HoverSet(App.hovCur, false)
        if IsObject(it)
            HoverSet(it, true)
        App.hovCur := it
    }
    if !over {
        SetTimer(HoverTick, 0)
        App.hovTimer := false
    }
}

; one button: a face (colour or picture) with the icon on top. sz = icon size in pixels
AddExtButton(g, i, x, y, w, h, facePic, bg, fg, sz, hovPic := "", hovHex := "", clickCb := "") {
    cb := IsObject(clickCb) ? clickCb : ExtClick.Bind(i)               ; clickCb: what a button of a [+] skin does
    if (facePic != "")
        face := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h, facePic)
    else
        face := g.Add("Text", "x" . x . " y" . y . " w" . w . " h" . h . " +0x100 " . (bg = "" ? "BackgroundTrans" : "Background" . bg))
    face.OnEvent("Click", cb)
    ic := ExtIconInfo(i)
    top := ""
    if (ic.pic != "") {
        try top := g.Add("Picture", "x" . (x + (w - sz) // 2) . " y" . (y + (h - sz) // 2) . " w" . sz . " h" . sz . " BackgroundTrans " . ic.opt, ic.pic)
    }
    if !IsObject(top) {
        top := g.Add("Text", "x" . x . " y" . y . " w" . w . " h" . h . " Center +0x200 +0x100 BackgroundTrans c" . fg, (ic.glyph != "" || ic.HasProp("none")) ? ic.glyph : "+")
        top.SetFont(sz > 14 ? "s9" : "s8", "Segoe UI Symbol")
    }
    top.OnEvent("Click", cb)
    if (facePic != "" && hovPic != "")
        AddHover(face, [face.Hwnd, top.Hwnd], facePic, hovPic, w, h, top)
    else if (facePic = "" && bg != "") {
        AddColorHover(face, bg, top, hovHex)
        App.hov[App.hov.Length].hwnds.Push(top.Hwnd)
    }
}

ExtClick(i, *) {
    b := App.ext[i]
    if (b.act = "") {
        ExtTip("No action is assigned to button " . i . ".`nChoose one in Settings > General.")
        return
    }
    path := App.dir . "\Tools\" . b.act
    if !FileExist(path) {
        ExtTip(b.act . " was not found in the Tools folder.`nChoose another one in Settings > General.")
        return
    }
    RunTool(path)
}

ExtTip(msg) {
    ToolTip(msg)
    SetTimer(ToolTip, -2500)
}

; folder with the pictures of the current bar style
StyleDir() {
    if IsSkinId(App.style)
        return App.dir "\Skins\" . SubStr(App.style, 6) . "\"
    return App.dir "\Skins\" . (App.style = "AeroDark" ? "Ekushey New" : App.style = "PurpleRaised" ? "Bijoy Ekattor" : App.style = "EkusheDark" ? "Ekushey Old" : App.style = "EkusheBN" ? "Ekushey" : App.style = "BanglaKb" ? "Bangla" : "Bijoy Bayanno") . "\"
}

; ---- "Purple Raised" style: purple bar, peach dropdown, raised red / grey buttons ----
;  [icon] [English  | v] [কিবোর্ড]  [wrench = settings] [minimize] [close]
BuildBarPurple(g) {
    d := StyleDir()
    g.BackColor := "3E226A"
    g.Add("Picture", "x0 y0 w258 h24", d . "bar_bg.png")
    AddBarIcon(g, 4, 28, 24, "BackgroundFFFFFF c000000")
    App.nameCtl := g.Add("Text", "x28 y3 w76 h18 +0x200 +0x100 BackgroundFBE9D8 c303030", "  " . CurrentName())
    App.nameCtl.SetFont("s7 bold", "Segoe UI")
    App.nameCtl.OnEvent("Click", ShowLayoutMenu)
    arrow := g.Add("Picture", "x104 y3 w22 h18", d . "arrow.png")
    arrow.OnEvent("Click", ShowLayoutMenu)

    bSet := AddPicBtn(g, d, "settings", 185, 4, 21, 16)
    bSet.OnEvent("Click", ShowSettings)
    bMin := AddPicBtn(g, d, "min", 209, 4, 21, 16)
    bMin.OnEvent("Click", HideBar)
    bClose := AddPicBtn(g, d, "close", 233, 4, 21, 16)
    bClose.OnEvent("Click", CloseBar)
    bClose.OnEvent("DoubleClick", CloseBar)
    g.OnEvent("Close", BarCloseEvent)
}

; ---- "Green Bangla" style (Bijoy Bayanno): dark green bar ----
;  [icon = settings] [English  v] [green arrow = minimize] [red x = close]
;  (click the icon for Settings)
BuildBarGreen(g) {
    d := StyleDir()
    g.BackColor := "345044"
    g.Add("Picture", "x0 y0 w260 h26", d . "bar_bg.png")           ; 26 px high: everything below sits 1 px lower than before

    AddBarIcon(g, 86, 108, 26, "BackgroundFFFFFF c000000")           ; this bar is 26 px high
    App.pic.OnEvent("Click", ShowSettings)                           ; the icon still shows the current mode, and clicking it opens Settings
    App.nameCtl := g.Add("Text", "x108 y4 w80 h18 +0x200 +0x100 BackgroundFFFFFF c000000", "  " . CurrentName())
    App.nameCtl.SetFont("s8", "Times New Roman")
    App.nameCtl.OnEvent("Click", ShowLayoutMenu)
    arrow := g.Add("Picture", "x188 y4 w20 h18", d . "arrow.png")
    arrow.OnEvent("Click", ShowLayoutMenu)

    bMin := AddPicBtn(g, d, "min", 213, 4, 18, 18)
    bMin.OnEvent("Click", HideBar)
    bClose := AddPicBtn(g, d, "close", 236, 3, 20, 20)
    bClose.OnEvent("Click", CloseBar)
    bClose.OnEvent("DoubleClick", CloseBar)
    g.OnEvent("Close", BarCloseEvent)
}

; ---- "Aero Dark" style: dark glass bar built from the pictures in Skins\Ekushey New ----
;  [icon] [English      v] [কিবোর্ড] [gear = settings] [minimize] [close]
;  (colour theme does not apply to this style: the colours are part of the pictures)
BuildBarAero(g) {
    d := StyleDir()
    g.BackColor := "050C22"
    g.Add("Picture", "x0 y0 w258 h24", d . "bar_bg.png")           ; frame + glass gradient (clicks pass through = drag)

    AddBarIcon(g, 4, 30, 24, "BackgroundFFFFFF c000000")

    nmY := 4, nmH := 16                                            ; the name box and the arrow button share the same top and height
    App.nameCtl := g.Add("Text", "x30 y" . nmY . " w84 h" . nmH . " +0x200 +0x100 BackgroundFFFFFF c000000", "  " . CurrentName())
    App.nameCtl.SetFont("s7 bold", "Segoe UI")
    App.nameCtl.OnEvent("Click", ShowLayoutMenu)
    arrow := AddPicBtn(g, d, "arrow", 114, nmY, 18, nmH)
    arrow.OnEvent("Click", ShowLayoutMenu)

    bSet := AddPicBtn(g, d, "settings", 192, 4, 17, 17)
    bSet.OnEvent("Click", ShowSettings)
    bMin := AddPicBtn(g, d, "min", 212, 2, 20, 20)
    bMin.OnEvent("Click", HideBar)
    bClose := AddPicBtn(g, d, "close", 236, 4, 17, 17)
    bClose.OnEvent("Click", CloseBar)
    bClose.OnEvent("DoubleClick", CloseBar)
    g.OnEvent("Close", BarCloseEvent)
}

; ---- "Ekushe Dark" style: black glossy bar like the Bijoy Ekushe 2016 tool bar ----
;  [icon] [English  | v] [grip]  [wrench = settings] [minimize] [close]   (no caption label)
BuildBarEkushe(g, bn := false, ext := []) {
    d := StyleDir()
    g.BackColor := "000000"
    bw := !bn ? 224 : 207 + 24 * ext.Length                        ; bar width: Ekushey Old | Ekushey BN: 207 + 24 for each ticked extra button
    bg := (bn && ext.Length = 1) ? BarBgOne(d) : "bar_bg.png"     ; Ekushey BN: the 1-button picture, or the 2-button one
    try
        g.Add("Picture", "x0 y0 w" . bw . " h24", d . bg)
    catch                                                          ; a picture that cannot be read: use the standard one instead of failing
        g.Add("Picture", "x0 y0 w" . bw . " h24", d . "bar_bg.png")
    AddBarIcon(g, 4, 32, 24, "BackgroundFFFFFF c000000")
    App.nameCtl := g.Add("Text", "x32 y6 w78 h12 +0x200 +0x100 BackgroundFBE9D8 c101030", "  " . CurrentName())
    App.nameCtl.SetFont("s7 bold", "Segoe UI")
    App.nameCtl.OnEvent("Click", ShowLayoutMenu)
    arrow := g.Add("Picture", "x110 y5 w18 h14", d . "arrow.png")
    arrow.OnEvent("Click", ShowLayoutMenu)

    x := bn ? 134 : 151                                            ; "Ekushey BN" has no dotted grip, so everything sits closer
    for i in ext {
        AddExtButton(g, i, x, 4, 21, 16, BtnFile(d, "button_bg"), "", "22242E", 14, BtnFile(d, "button_bg", true))
        x += 24
    }
    bSet := AddPicBtn(g, d, "settings", x, 4, 21, 16)
    bSet.OnEvent("Click", ShowSettings)
    bMin := AddPicBtn(g, d, "min", x + 24, 4, 21, 16)
    bMin.OnEvent("Click", HideBar)
    bClose := AddPicBtn(g, d, "close", x + 48, 4, 21, 16)
    bClose.OnEvent("Click", CloseBar)
    bClose.OnEvent("DoubleClick", CloseBar)
    g.OnEvent("Close", BarCloseEvent)
    return bw
}

; ---- "Bangla [+]" style: teal bar, dynamic left buttons, state icon, white dropdown, blue settings, green minimize, red close ----
;  [button 1] | [button 2] | [icon] [English        v] | [green arrow = minimize] | [red x = close]
;  The buttons on the left are the extra buttons (Settings > General): button 1 is always there, button 2 when ticked.
;  Settings: use the layout menu (last item) or the tray icon.
BuildBarBanglaKb(g, ext := []) {
    d := StyleDir()
    bar := "115048"
    g.BackColor := bar
    sepC := "9FC4BB"
    bgPic := g.Add("Picture", "x0 y0 w248 h24", d . "bar_bg.png")      ; resized below once the width is known
    x := 4
    for i in ext {                                                 ; the dynamic buttons, then a separator after each
        AddExtButton(g, i, x, 2, 22, 20, "", bar, "E6F2EE", 16)
        g.Add("Text", "x" . (x + 25) . " y4 w1 h16 Background" . sepC)
        x += 30
    }
    AddBarIcon(g, x, x + 24, 24, "BackgroundFFFFFF c000000")      ; icon of the current layout, just left of the name box
    x += 24
    App.nameCtl := g.Add("Text", "x" . x . " y3 w86 h18 +0x200 +0x100 BackgroundFFFFFF c000000", "  " . CurrentName())
    App.nameCtl.SetFont("s8", "Segoe UI")
    App.nameCtl.OnEvent("Click", ShowLayoutMenu)
    arrow := g.Add("Picture", "x" . (x + 86) . " y3 w18 h18", d . "arrow.png")
    arrow.OnEvent("Click", ShowLayoutMenu)
    x += 108
    g.Add("Text", "x" . x . " y4 w1 h16 Background" . sepC)
    bSet := AddPicBtn(g, d, "settings", x + 4, 4, 16, 16)          ; settings button, same size as minimize
    bSet.OnEvent("Click", ShowSettings)
    x += 24
    g.Add("Text", "x" . x . " y4 w1 h16 Background" . sepC)
    bMin := AddPicBtn(g, d, "min", x + 4, 4, 16, 16)               ; smaller than the close button
    bMin.OnEvent("Click", HideBar)
    x += 24
    g.Add("Text", "x" . x . " y4 w1 h16 Background" . sepC)
    bClose := AddPicBtn(g, d, "close", x + 4, 2, 20, 20)
    bClose.OnEvent("Click", CloseBar)
    bClose.OnEvent("DoubleClick", CloseBar)
    g.OnEvent("Close", BarCloseEvent)
    barW := x + 28
    bgPic.Move(, , barW, 24)
    return barW
}

; the bar picture of "Ekushey BN" with ONE extra button (the normal case). It is also kept inside this script, so if the file is
; missing (e.g. only BanglaKeyboard.ahk was copied) it is written again; the 2-button picture is the last resort.
BarBgOne(d) {
    static b64 := "iVBORw0KGgoAAAANSUhEUgAAAOcAAAAYCAYAAAABMOrsAAABAklEQVR42u3bsQ2DMBBG4T8SBROwhAs6KjdswGSsRMMCdEhMAGIF7lKlIyXxSXnfApFsP86ylNc4jn4chwDE0TSNKjPTuq6sBhDIvu+qzvPUtm2sBhBI13Wq3F1m9vMfX5aFHQikbVsWIdq1tlSckjTPM7sQQM652BnAPXcvG6ck9X3PThQ0TZMkESdxIirOQMA4zUzXdbEaf44zEO9jyeQEk5NrLYgTxAniJE4QJx6LkwchSDwIRfxYMjnB5ORaC+IEcYI4iRPEicfi5EEIEg9CET+WTE4wObnW3vv8KwLEiUBx5pzZBeJEtDjrumYHgMjXWgBf4kwpaRgGVgMIJKWkNzjjBRBMrpiDAAAAAElFTkSuQmCC"
    f := d . "bar_bg_one.png"
    if FileExist(f)
        return "bar_bg_one.png"
    try {
        n := 0
        DllCall("Crypt32\CryptStringToBinaryW", "str", b64, "uint", 0, "uint", 1, "ptr", 0, "uint*", &n, "ptr", 0, "ptr", 0)
        buf := Buffer(n)
        DllCall("Crypt32\CryptStringToBinaryW", "str", b64, "uint", 0, "uint", 1, "ptr", buf, "uint*", &n, "ptr", 0, "ptr", 0)
        h := FileOpen(f, "w")
        h.RawWrite(buf, n)
        h.Close()
        return "bar_bg_one.png"
    }
    return "bar_bg.png"
}

; Re-create the bar (used when the colour theme or style changes)
RebuildBar() {
    if App.rebuilding {                    ; another click / event came in while the bar is being built: never build two at once,
        App.rebuildAgain := true           ; just remember it and do it once more when the running one is finished
        return
    }
    App.rebuilding := true                 ; also keeps UpdateBar away from the half-built bar
    vis := true
    try {
        Loop {
            App.rebuildAgain := false
            if IsObject(App.bar) {
                if (A_Index = 1)
                    vis := (DllCall("IsWindowVisible", "ptr", App.bar.Hwnd) != 0)
                old := App.bar
                App.bar := 0                   ; detach first: while the old window is being destroyed, mouse/hover messages
                App.hov := []                  ; must not find a dead Gui in App.bar (that was the "Gui has no window" error)
                App.hovCur := 0
                try old.Destroy()
            }
            BuildBar()
            if !App.rebuildAgain
                break
        }
    } finally
        App.rebuilding := false
    UpdateBar()
    if !vis
        App.bar.Hide()
    SyncTray()
}


; ---------------------------------------------------------------------------
;  Your own bar skins: every folder in Skins that holds a skin.ini is listed in Settings > General (bar style)
;  under the name written in its [Skin] section. The built-in styles above are not touched by this.
;  Start from the "Skin Template" folder (a copy of Bijoy Ekattor): copy it into Skins, rename it, edit skin.ini.
;  Folders whose name starts with "_" or "." are skipped.
; ---------------------------------------------------------------------------
IsSkinId(id) {
    return (SubStr(id, 1, 5) = "Skin:") ? true : false
}

; reads Skins\*\skin.ini again (startup, and whenever Settings is opened)
LoadSkins() {
    list := []
    Loop Files App.dir . "\Skins\*", "D" {
        nm := A_LoopFileName
        if (SubStr(nm, 1, 1) = "_" || SubStr(nm, 1, 1) = "." || !FileExist(A_LoopFileFullPath . "\skin.ini"))
            continue
        ini := SkinIni(A_LoopFileFullPath . "\skin.ini")
        title := Trim(SkinStr(ini, "Skin", "Name", ""))
        used := []                                       ; which of the buttons Ext1 - Ext6 the skin has (a skin with some is a [+] skin)
        Loop App.maxExt
            used.Push(false)
        Loop 40 {
            sec := "Button" . A_Index
            if !ini.Has(sec)
                break
            if (RegExMatch(SkinStr(ini, sec, "Action", ""), "i)^Ext([1-9])$", &m) && Integer(m[1]) <= App.maxExt)
                used[Integer(m[1])] := true
        }
        list.Push({id: "Skin:" . nm, folder: nm, name: (title = "") ? nm : title, ext: used})
    }
    Loop list.Length {                                   ; by name
        f := list[A_Index]
        j := A_Index - 1
        while (j >= 1 && StrCompare(list[j].name, f.name) > 0) {
            list[j + 1] := list[j]
            j--
        }
        list[j + 1] := f
    }
    App.skins := list
}

SkinName(id) {
    for s in App.skins {
        if (s.id = id)
            return s.name
    }
    return SubStr(id, 6)
}

; a small .ini reader that also understands UTF-8 (names in Bangla): Map of section -> Map of key -> value
SkinIni(path) {
    ini := Map()
    ini.CaseSense := "Off"
    txt := ""
    try txt := FileRead(path, "UTF-8")
    if (SubStr(txt, 1, 1) == Chr(0xFEFF))
        txt := SubStr(txt, 2)
    sec := ""
    Loop Parse txt, "`n", "`r" {
        line := Trim(A_LoopField)
        c := SubStr(line, 1, 1)
        if (line = "" || c = ";" || c = "#")
            continue
        if (c = "[" && SubStr(line, -1) = "]") {
            sec := Trim(SubStr(line, 2, StrLen(line) - 2))
            if !ini.Has(sec) {
                m := Map()
                m.CaseSense := "Off"
                ini[sec] := m
            }
            continue
        }
        p := InStr(line, "=")
        if (!p || sec = "")
            continue
        v := Trim(SubStr(line, p + 1))
        q := InStr(v, " " Chr(59))                              ; a comment after the value
        if q
            v := Trim(SubStr(v, 1, q - 1))
        ini[sec][Trim(SubStr(line, 1, p - 1))] := v
    }
    return ini
}

SkinStr(ini, sec, key, def := "") {
    return (ini.Has(sec) && ini[sec].Has(key)) ? ini[sec][key] : def
}

SkinInt(ini, sec, key, def, lo, hi) {
    v := SkinStr(ini, sec, key, "")
    return IsInteger(v) ? Min(hi, Max(lo, Integer(v))) : def
}

SkinHex(ini, sec, key, def) {
    v := RegExReplace(SkinStr(ini, sec, key, ""), "^#")
    return RegExMatch(v, "i)^[0-9a-f]{6}$") ? v : def
}

; a picture of the skin folder by file name (never outside the folder); "" if it is not there
SkinFile(d, name) {
    if (name = "" || RegExMatch(name, "[\\/:]") || InStr(name, ".."))
        return ""
    return FileExist(d . name) ? (d . name) : ""
}

; what a button does: Settings, Minimize, Close, Toggle, English, LayoutMenu, NextLayout, Layout:<name>,
; Tool:<file in Tools>, ToolsMenu, About, None. "" = not understood.
SkinAction(spec) {
    spec := Trim(spec)
    p := InStr(spec, ":")
    kind := StrLower(Trim(p ? SubStr(spec, 1, p - 1) : spec))
    arg := Trim(p ? SubStr(spec, p + 1) : "")
    switch kind {
        case "settings":
            return (*) => ShowSettings()
        case "minimize":
            return (*) => HideBar()
        case "close":
            return (*) => CloseBar()
        case "toggle":
            return (*) => ToggleEnglish()
        case "english":
            return SetLayout.Bind(0)
        case "layoutmenu":
            return (*) => ShowLayoutMenu()
        case "nextlayout":
            return (*) => NextLayout()
        case "layout":
            for i, L in App.layouts {
                if (StrLower(L.name) = StrLower(arg))
                    return SetLayout.Bind(i)
            }
            return ""
        case "tool":
            return RunSkinTool.Bind(arg)
        case "toolsmenu":
            return (*) => ShowToolsPopup()
        case "about":
            return (*) => ShowAbout()
        case "none", "":
            return (*) => 0
    }
    return ""
}

; the next listed Bangla layout (from English: the first one)
NextLayout(*) {
    shown := []
    for i in LayoutOrder() {
        if IsShown("L:" . App.layouts[i].name)
            shown.Push(i)
    }
    if (shown.Length = 0)
        return
    pos := 0
    for k, i in shown {
        if (i = App.cur)
            pos := k
    }
    SetLayout(shown[Mod(pos, shown.Length) + 1])
}

RunSkinTool(file, *) {
    if (file = "" || RegExMatch(file, "[\\/:]")) {                  ; only programs of the Tools folder can be started from a skin
        ExtTip("A skin button can only start a file from the Tools folder.")
        return
    }
    path := App.dir . "\Tools\" . file
    if !FileExist(path) {
        ExtTip(file . " was not found in the Tools folder.")
        return
    }
    RunTool(path)
}

ShowPopup(m) {
    prev := WinExist("A")
    App.menuPrev := prev
    WinActivate("ahk_id " . App.bar.Hwnd)                           ; lets the menu close when you click elsewhere
    m.Show()
    App.menuPrev := 0
    GiveFocusBack(prev)
}

ShowToolsPopup(*) {
    files := ToolFiles()
    if (files.Length = 0) {
        ExtTip("There are no programs in the Tools folder.")
        return
    }
    m := Menu()
    for f in files
        m.Add(StrReplace(f.name, "&", "&&"), RunTool.Bind(f.path))
    ShowPopup(m)
}

; ---- the extra buttons of a [+] skin (Avro Flat [+]) ----------------------------------------------------------
; A skin button with  Action=Ext1  (or Ext2, Ext3)  is the extra button of that number from Settings > TopBar Theme
; (the same "Extra buttons" rows the other [+] styles use): it starts the Tools program chosen there and shows the icon chosen there.
; "App icon" (the default) keeps the picture of the skin (name.png, lit with name_hover.png).

; one Ext button of a skin: the skin's own picture or, when you picked another icon, a flat button with that icon
AddSkinExtButton(g, d, n, img, x, y, w, h, ini, sec) {
    e := App.ext[n]
    cb := ExtClick.Bind(n)
    if ((e.icon = "App icon" || e.icon = "(Skin default)" || e.icon = "") && img != "") {
        ctl := AddPicBtn(g, d, img, x, y, w, h)
        ctl.OnEvent("Click", cb)
        return
    }
    bg := SkinHex(ini, sec, "BackColor", App.skinTrans ? "" : SkinHex(ini, "Skin", "BackColor", "3E226A"))     ; a transparent skin: the bar picture shows behind the icon
    if (StrLower(SkinStr(ini, sec, "BackColor", "")) = "transparent")
        bg := ""
    AddExtButton(g, n, x, y, w, h, "", bg, SkinHex(ini, sec, "TextColor", "FFFFFF"), 16, "", SkinHex(ini, sec, "HoverColor", bg = "" ? "" : HoverColor(bg)), cb)
}

; ---- the bar made from skin.ini: [icon] [layout name box + arrow] [any number of buttons] ----
BuildBarSkin(g) {
    d := StyleDir()
    folder := SubStr(App.style, 6)
    ini := SkinIni(d . "skin.ini")
    w := SkinInt(ini, "Skin", "Width", 258, 60, 1600)
    h := SkinInt(ini, "Skin", "Height", 24, 16, 80)
    App.skinH := h
    App.skinTrans := (SkinInt(ini, "Skin", "Transparent", 0, 0, 1) = 1)
    g.BackColor := SkinHex(ini, "Skin", "BackColor", "3E226A")
    bg := SkinFile(d, SkinStr(ini, "Skin", "Background", "bar_bg.png"))
    if (bg != "") {
        try g.Add("Picture", "x0 y0 w" . w . " h" . h, bg)
    }

    ; the layout name box (always exists, because the bar keeps its text up to date; Show=0 hides it)
    lx := SkinInt(ini, "LayoutBox", "X", 28, 0, 1600)
    ly := SkinInt(ini, "LayoutBox", "Y", 3, 0, 200)
    lw := SkinInt(ini, "LayoutBox", "W", 76, 10, 800)
    lh := SkinInt(ini, "LayoutBox", "H", 18, 8, 80)
    showBox := (SkinInt(ini, "LayoutBox", "Show", 1, 0, 1) = 1)
    ; the icon (it is also the handle for dragging the bar); it must not grow into the name box
    if (SkinInt(ini, "Icon", "Show", 1, 0, 1) = 1)
        AddBarIcon(g, SkinInt(ini, "Icon", "X", 4, -10, 1600), showBox ? lx : w, h, "BackgroundFFFFFF c000000")
    lbTrans := (StrLower(SkinStr(ini, "LayoutBox", "BackColor", "")) = "transparent")        ; BackColor=Transparent: the bar picture shows behind the name
    al := StrLower(SkinStr(ini, "LayoutBox", "Align", "left"))
    opt := "x" . lx . " y" . ly . " w" . lw . " h" . lh . " +0x200 +0x100 " . (al = "center" ? "Center " : al = "right" ? "Right " : "")
        . (lbTrans ? "BackgroundTrans" : "Background" . SkinHex(ini, "LayoutBox", "BackColor", "FBE9D8")) . " c" . SkinHex(ini, "LayoutBox", "TextColor", "303030")
    if !showBox
        opt .= " Hidden"
    App.skinMode := (StrLower(SkinStr(ini, "LayoutBox", "Display", "Name")) = "mode")       ; Display=Mode: the box shows ENG / বাংলা
    App.skinModeTxt := [SkinStr(ini, "LayoutBox", "EnglishText", "ENG"), SkinStr(ini, "LayoutBox", "BanglaText", "বাংলা")]
    App.nameCtl := g.Add("Text", opt, BarNameText())
    App.nameCtl.SetFont("s" . SkinInt(ini, "LayoutBox", "FontSize", 7, 5, 24) . (SkinInt(ini, "LayoutBox", "Bold", 1, 0, 1) = 1 ? " bold" : ""), SkinStr(ini, "LayoutBox", "Font", "Segoe UI"))
    nameAct := SkinStr(ini, "LayoutBox", "Action", "")                  ; what a click on the box does (default: the layout list)
    nameCb := (nameAct = "") ? "" : SkinAction(nameAct)
    App.nameCtl.OnEvent("Click", IsObject(nameCb) ? nameCb : ShowLayoutMenu)
    nameHov := SkinHex(ini, "LayoutBox", "HoverColor", "")              ; HoverColor: the box lights up under the mouse
    if (showBox && nameHov != "" && !lbTrans)
        AddColorHover(App.nameCtl, SkinHex(ini, "LayoutBox", "BackColor", "FBE9D8"), "", nameHov)
    arrow := RegExReplace(SkinStr(ini, "LayoutBox", "Arrow", "arrow"), "i)\.png$")
    if (showBox && arrow != "" && SkinFile(d, arrow . ".png") != "") {
        ar := AddPicBtn(g, d, arrow, SkinInt(ini, "LayoutBox", "ArrowX", lx + lw, 0, 1600), SkinInt(ini, "LayoutBox", "ArrowY", ly, 0, 200)
            , SkinInt(ini, "LayoutBox", "ArrowW", 22, 4, 200), SkinInt(ini, "LayoutBox", "ArrowH", lh, 4, 80))
        ar.OnEvent("Click", ShowLayoutMenu)
    }

    ; buttons: [Button1], [Button2] ... as many as you like (the numbers must follow each other)
    gaps := []                                                          ; [x, width] of the Ext buttons that are switched off: the buttons right of them move left
    Loop 40 {
        sec := "Button" . A_Index
        if !ini.Has(sec)
            break
        act := SkinStr(ini, sec, "Action", "None")
        x := SkinInt(ini, sec, "X", 0, -50, 1600)
        y := SkinInt(ini, sec, "Y", 4, -50, 200)
        bw := SkinInt(ini, sec, "W", 21, 4, 400)
        bh := SkinInt(ini, sec, "H", 16, 4, 80)
        img := RegExReplace(SkinStr(ini, sec, "Image", ""), "i)\.png$")
        txt := SkinStr(ini, sec, "Text", "")
        rawX := x
        for gp in gaps {
            if (rawX > gp[1])                                           ; gp[1] = the raw skin.ini X of a switched-off button
                x -= gp[2]
        }
        if (RegExMatch(act, "i)^Ext([1-9])$", &em) && Integer(em[1]) <= App.maxExt) {                  ; an extra button of Settings > TopBar Theme (see App.ext)
            if !App.ext[Integer(em[1])].on {                            ; ticked off: no button, and the gap is closed
                gaps.Push([rawX, bw])
                continue
            }
            AddSkinExtButton(g, d, Integer(em[1]), img, x, y, bw, bh, ini, sec)
            continue
        }
        if (img != "") {
            ctl := AddPicBtn(g, d, img, x, y, bw, bh)                  ; img.png, lit with img_hover.png when that file exists
        } else {
            bg2 := SkinHex(ini, sec, "BackColor", "5A3C8C")
            ctl := g.Add("Text", "x" . x . " y" . y . " w" . bw . " h" . bh . " Center +0x200 +0x100 Background" . bg2 . " c" . SkinHex(ini, sec, "TextColor", "FFFFFF"), txt)
            ctl.SetFont("s" . SkinInt(ini, sec, "FontSize", 8, 5, 24) . (SkinInt(ini, sec, "Bold", 0, 0, 1) = 1 ? " bold" : ""), SkinStr(ini, sec, "Font", "Segoe UI"))
            AddColorHover(ctl, bg2, "", SkinHex(ini, sec, "HoverColor", ""))
        }
        cb := SkinAction(act)
        if (cb = "")
            cb := ((n, *) => ExtTip("Button " . n . ": the action is not known.`nCheck skin.ini.")).Bind(A_Index)
        else if (StrLower(act) = "layoutmenu")
            cb := ((c, *) => ShowLayoutMenuAt(c))                      ; the list opens right under this button
        ctl.OnEvent("Click", cb)
        if (StrLower(act) = "close")
            ctl.OnEvent("DoubleClick", cb)
    }
    g.OnEvent("Close", BarCloseEvent)
    for gp in gaps
        w -= gp[2]
    return w
}

StyleIds() {
    ; every style in alphabetical order of its name (see StyleBaseName); the ids are the values saved in the settings file
    a := ["Classic", "ClassicExt", "BanglaKb", "GreenBangla", "PurpleRaised", "EkusheBN", "AeroDark", "EkusheDark"]
    for sk in App.skins                                   ; plus the skins you added to the Skins folder
        a.Push(sk.id)
    out := []
    for id in a {
        j := out.Length
        while (j >= 1 && StrCompare(StyleBaseName(out[j]), StyleBaseName(id)) > 0)       ; insertion sort
            j--
        out.InsertAt(j + 1, id)
    }
    return out
}

; the name of a style without the [+] mark
StyleBaseName(id) {
    static names := Map("Classic", "Default Bar", "ClassicExt", "Default", "BanglaKb", "Bangla", "GreenBangla", "Bijoy Bayanno"
        , "PurpleRaised", "Bijoy Ekattor", "EkusheBN", "Ekushey", "AeroDark", "Ekushey New", "EkusheDark", "Ekushey Old")
    return names.Has(id) ? names[id] : SkinName(id)
}

StyleLabels() {
    a := []
    for id in StyleIds()
        a.Push(StyleBaseName(id) . ((IsExtStyle(id) || IsSkinExt(id)) ? " [+]" : ""))        ; [+] = this style has the extra buttons you can set up
    return a
}

; which of the buttons Ext1 - Ext6 a skin has: an array of App.maxExt true / false
SkinExtSlots(id) {
    for s in App.skins {
        if (s.id = id)
            return s.ext
    }
    a := []
    Loop App.maxExt
        a.Push(false)
    return a
}

; the on / off state of every extra button (to undo the live preview when Settings is cancelled)
ExtOnList() {
    a := []
    for b in App.ext
        a.Push(b.on)
    return a
}

; how many extra-button rows Settings needs: 2 (the Default / Ekushey / Bangla styles) or the highest Ext number any skin uses
ExtRowCount() {
    n := 2
    for s in App.skins {
        for k, v in s.ext {
            if v
                n := Max(n, k)
        }
    }
    return n
}

; a skin of the Skins folder that has buttons you set up yourself ([+] skin, e.g. Avro Flat [+])
IsSkinExt(id) {
    for v in SkinExtSlots(id) {
        if v
            return true
    }
    return false
}

; the styles that have the extra buttons
IsExtStyle(id) {
    return (id = "ClassicExt" || id = "EkusheBN" || id = "BanglaKb") ? true : false
}

; the styles drawn from the colour themes (the others use their own pictures)
UsesTheme(id) {
    return (id = "Classic" || id = "ClassicExt") ? true : false
}

StyleIndex(id) {
    for i, v in StyleIds()
        if (v = id)
            return i
    return 1
}

ApplyStyle(name) {
    if (StyleIds()[StyleIndex(name)] != name)
        return
    App.style := name
    RebuildBar()
}

ApplyTheme(name) {
    if !Themes().Has(name)
        return
    App.theme := name
    RebuildBar()
}

PointOnScreen(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x < r && y >= t && y < b)
            return true
    }
    return false
}

BarMouseDown(wParam, lParam, msg, hwnd) {
    if (IsObject(App.bar) && hwnd = App.bar.Hwnd)
        PostMessage(0xA1, 2, 0, , "ahk_id " . hwnd)     ; WM_NCLBUTTONDOWN + HTCAPTION = drag the window
}

BarMoved(wParam, lParam, msg, hwnd) {
    if (IsObject(App.bar) && hwnd = App.bar.Hwnd) {
        WinGetPos(&x, &y, , , "ahk_id " . hwnd)
        SaveSetting("Bar", "X", x)
        SaveSetting("Bar", "Y", y)
        App.barX := x
        App.barY := y
    }
}

ShowBar(*) {
    App.bar.Show("NoActivate")
    KeepOnTop()
    SyncTray()
}

; Keeps the bar above every other window. The "always on top" flag alone is not enough: any other topmost
; window that gets activated later (or a window that raises itself) ends up above the bar. So the bar is put back
; on top right after every window change (no polling timer); nothing happens while it is already first.
KeepOnTop(*) {
    if (!App.onTop || !IsObject(App.bar) || App.menuPrev)       ; (not while the layout menu is open)
        return
    try {
        h := App.bar.Hwnd
        if !DllCall("IsWindowVisible", "Ptr", h)
            return
        if DllCall("GetWindow", "Ptr", h, "UInt", 3, "Ptr")      ; GW_HWNDPREV: some window is above the bar
            DllCall("SetWindowPos", "Ptr", h, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x213)   ; HWND_TOPMOST, no move / size / activate
    }
}

HideBar(*) {
    App.bar.Hide()
    SyncTray()                  ; icon appears in the tray now
    if !App.tipShown {
        App.tipShown := true
        TrayTip("Still running in the tray. Double-click the tray icon to bring the bar back.", "Bangla Keyboard")
    }
}

GiveFocusBack(hwnd) {
    if (hwnd && hwnd != App.bar.Hwnd && WinExist("ahk_id " . hwnd))
        try WinActivate("ahk_id " . hwnd)
}

; the text of the name box: the layout name, or (skins with Display=Mode) ENG / বাংলা
BarNameText() {
    if App.skinMode
        return App.skinModeTxt[App.cur = 0 ? 1 : 2]
    return "  " . CurrentName()
}

UpdateBar() {
    if (!IsObject(App.bar) || App.rebuilding)
        return
    try App.nameCtl.Text := BarNameText()     ; (a bar that was just replaced is skipped; RebuildBar updates the new one)
    try {
        App.pic.Value := PicSpec()
    } catch {
        try App.pic.Text := IconBadge()
    }
}

ShowLayoutMenuAt(ctl) {
    App.menuAnchor := ctl
    ShowLayoutMenu()
}

ShowLayoutMenu(*) {
    m := Menu()
    AddLayoutItems(m)                              ; the bar's menu always lists the layouts directly
    try m.Check(CurrentName())
    if EncMenuOn() {                               ; Encoding is always a submenu (here and in the tray menu)
        m.Add()
        em := MakeEncMenu()
        m.Add("Encoding", em)
        if !EncUsable()
            try m.Disable("Encoding")
    }
    if (App.style = "BanglaKb") {                  ; this style has a settings button, so only About is added here
        m.Add()
        m.Add("About...", ShowAbout)
    }
    anchor := IsObject(App.menuAnchor) ? App.menuAnchor : App.nameCtl      ; the list opens under the name box (or under the button that asked)
    App.menuAnchor := ""
    anchor.GetPos(&cx, &cy, , &ch)
    WinGetClientPos(&wx, &wy, , , "ahk_id " . App.bar.Hwnd)
    prev := WinExist("A")
    App.menuPrev := prev
    WinActivate("ahk_id " . App.bar.Hwnd)          ; lets the menu close when you click elsewhere
    m.Show(wx + cx, wy + cy + ch)
    App.menuPrev := 0
    GiveFocusBack(prev)
}

; ---- every way of closing (bar [x], tray "Exit", Alt+F4) ends up here ----------------
; Asks first when "Confirm before closing" is ticked in Settings.
BarCloseEvent(*) {
    CloseBar()
    return true                                  ; never let Windows destroy the bar by itself
}

CloseBar(*) {
    static asking := false
    if App.confirmClose {
        if asking
            return
        asking := true
        r := MsgBox("Close Bangla Keyboard?`n`nBangla typing will stop until you start it again.", "Bangla Keyboard", 0x40124)   ; Yes/No + question icon + No is default + on top
        asking := false
        if (r != "Yes")
            return
    }
    ExitApp()
}

; ---- About window ------------------------------------------------------------------------------------------------
; Opened from the tray menu (just above Exit) and from the layout menu of the "Bangla [+]" bar.
ShowAbout(*) {
    if IsObject(App.about) {
        try {
            App.about.Show()
            return
        }
        App.about := ""
    }
    DllCall("LoadLibrary", "Str", "Msftedit.dll")                  ; the rich text (RichEdit 5) control
    g := Gui("+AlwaysOnTop -MinimizeBox", "About Bangla Keyboard")
    g.MarginX := 10
    g.MarginY := 10
    g.SetFont("s9", "Segoe UI")

    ; top: the name, the version and the credit, starting at the left edge (a small rich text box that looks like part of the window)
    head := AboutRich(g, "x18 y8 w488 h92", false)
    AboutSetRtf(head, AboutHeadRtf())

    ; three tabs, each one a rich text box with its own scroll bar (it appears when the text is longer than the box)
    tb := g.Add("Tab3", "x10 y106 w496 h352 +0x400", ["About", "Keyboard", "Tools"])      ; 0x400 = all tabs the same width
    for k, rtf in [AboutRtfApp(), AboutRtfKeyboard(), AboutRtfTools()] {
        tb.UseTab(k)
        e := AboutRich(g, "x18 y138 w480 h312", true)
        AboutSetRtf(e, rtf)
    }
    tb.UseTab()
    ok := g.Add("Button", "x416 y468 w90 h28 Default", "OK")
    ok.OnEvent("Click", AboutClose)
    g.OnEvent("Close", AboutClose)
    g.OnEvent("Escape", AboutClose)
    App.about := g
    g.Show("w516")
    tb.GetPos(, , &tw)                                              ; the three tabs share the whole width
    SendMessage(0x1329, 0, (Round(24 * A_ScreenDPI / 96) << 16) | ((tw - 8) // 3), tb)      ; TCM_SETITEMSIZE
    ok.Focus()
}

; a read-only RichEdit box. boxed = white page with a border and a vertical scroll bar; otherwise it takes the window colour
AboutRich(g, opt, boxed) {
    style := " +0x4 +0x40 +0x800"                                   ; multi-line, auto-scroll, read-only
    if boxed
        style .= " +0x200000 +0x10000 +E0x200"                      ; vertical scroll bar, tab stop, sunken edge
    e := g.Add("Custom", "ClassRICHEDIT50W " . opt . style)
    SendMessage(0x443, 0, boxed ? 0xFFFFFF : DllCall("GetSysColor", "Int", 15, "UInt"), e)      ; EM_SETBKGNDCOLOR
    SendMessage(0xD3, 3, 10 | (10 << 16), e)                        ; EM_SETMARGINS: 10 px left and right
    return e
}

AboutSetRtf(ed, rtf) {
    n := StrPut(rtf, "CP1252")
    b := Buffer(n, 0)
    StrPut(rtf, b, n, "CP1252")
    st := Buffer(8, 0)                                              ; SETTEXTEX: flags = 0 (replace all), code page 1252
    NumPut("UInt", 0, st, 0)
    NumPut("UInt", 1252, st, 4)
    SendMessage(0x461, st.Ptr, b.Ptr, ed)                           ; EM_SETTEXTEX (the text is RTF)
    SendMessage(0xB1, 0, 0, ed)                                     ; nothing selected, shown from the top
}

; ---- tiny rich text writer: the text of each tab is a list of lines
;   "# Title"   a green heading      "* text"  a bullet      "1| text"  a numbered step      anything else  a paragraph
;   **word**    makes word bold
RtfOpen() {
    return "{\rtf1\ansi\ansicpg1252\deff0{\fonttbl{\f0\fswiss\fcharset0 Segoe UI;}}"
        . "{\colortbl;\red0\green110\blue60;\red110\green110\blue110;}\f0\fs19 "
}

RtfEsc(s) {
    out := ""
    Loop Parse, s {
        c := Ord(A_LoopField)
        if (A_LoopField = "\" || A_LoopField = "{" || A_LoopField = "}")
            out .= "\" . A_LoopField
        else if (c > 127)
            out .= "\u" . (c > 32767 ? c - 65536 : c) . "?"
        else
            out .= A_LoopField
    }
    return out
}

RtfInline(s) {
    out := ""
    for i, part in StrSplit(s, "**")
        out .= (Mod(i, 2) = 0) ? "{\b " . RtfEsc(part) . "}" : RtfEsc(part)
    return out
}

RtfPage(lines) {
    r := RtfOpen()
    for ln in lines {
        txt := SubStr(ln, 3)
        if (SubStr(ln, 1, 2) = "# ")
            r .= "\pard\sb180\sa70\keepn{\b\fs22\cf1 " . RtfEsc(txt) . "}\par"
        else if (SubStr(ln, 1, 2) = "* ")
            r .= "\pard\li330\fi-220\sa50\tx330 \u8226?\tab " . RtfInline(txt) . "\par"
        else if RegExMatch(ln, "^(\d)\| (.*)$", &m)
            r .= "\pard\li330\fi-290\sa50\tx330 " . m[1] . ".\tab " . RtfInline(m[2]) . "\par"
        else
            r .= "\pard\sa80 " . RtfInline(ln) . "\par"
    }
    return r . "}"
}

AboutHeadRtf() {
    return RtfOpen()
        . "\pard\sa70{\b\fs36\cf1 Bangla Keyboard}{\fs20\cf2   Version " . RtfEsc(App.version) . "}\par"
        . "\pard\sa0 " . RtfInline("The idea of this application is inspired by existing Bangla keyboards, but its design, functionality and features are designed by **Sherlock Holmes** (nickname), with the assistance of AI.") . "\par}"
}

AboutRtfApp() {
    return RtfPage([
        "# What is Bangla Keyboard?",
        "A small, fast Bijoy-style typing tool for Windows. It lets you type Bangla in any program, stays out of your way as a thin bar and a tray icon, and needs no installer.",
        "# What it offers",
        "* **Type anywhere**: works in any Windows program, no clipboard needed.",
        "* **Three layouts**: Bijoy Classic, Bijoy Unicode and UniBijoy, plus any layout you add or build. Layouts can be plain (.xml) or locked (.bkl).",
        "* **Avro Phonetic** (optional): type Bangla with English letters, Unicode only. Tick it in Settings > General and it joins the layout list.",
        "* **Quick switching**: one click or a shortcut key toggles English and Bangla. The layout list always starts with English, then every layout in alphabetical order.",
        "* **Multi Encoding**: type Unicode as usual and the text that reaches the program is converted to ANSI (Bijoy style) at once, using an encoding script of Library\Encoding Script (.json or locked .menc).",
        "* **Bangla Snippet**: a text expander. Type a saved title and the trigger, and it is replaced by the saved text (with dates, clipboard and cursor macros).",
        "* **Automatic fonts**: the font follows the layout in Word, Excel, PowerPoint, Outlook, WPS Office and LibreOffice Writer.",
        "* **Quick Fonts**: up to 10 shortcut keys, each applying a font and size to the cursor or selection.",
        "* **Your own look**: ten bar styles (Avro Classic [+], Avro Flat [+], Bangla [+], Bijoy Bayanno, Bijoy Ekattor, Default, Default Bar, Ekushey [+], Ekushey New, Ekushey Old), colour themes, adjustable icon size and a tray icon. Designers can also make their own bar skins (see Make your own skin).",
        "* **Extra buttons**: the [+] styles can have buttons that start your own tools (two in most styles, three in Avro Flat [+] and Avro Classic [+]).",
        "* **Tools**: document and text converters, a layout builder, a note editor, a typing tutor, a snippet manager, a file locker, an emoji picker and an on-screen keyboard (see the Tools tab).",
        "* **Performance Helper**: a tiny helper that starts Bangla Keyboard again if it ever stops unexpectedly. It uses almost no CPU, and you can switch it off or show its tray icon in Settings > Extra Settings.",
        "* **Error log**: problems are written quietly to %AppData%\Bangla Keyboard\error.log instead of opening error windows, and typing goes on.",
        "# Credits",
        "The idea is inspired by existing Bangla keyboards. The design, functionality and features are designed by **Sherlock Holmes** (nickname), with the assistance of AI.",
        "# Good to know",
        "* Free and open source (GNU GPL v3). It is not sold, so please do not sell or repackage it.",
        "* No paid or licensed fonts are included. Please get any fonts you need legally.",
        "* Skins and artwork are for personal, non-commercial use. All names and trademarks belong to their owners; this project is not affiliated with them.",
        "* Your settings are saved in %AppData%\Bangla Keyboard, so updates never erase them."
    ])
}

AboutRtfKeyboard() {
    return RtfPage([
        "# Getting started",
        "1| Pick a layout from the bar's drop-down list (or press its shortcut key) and start typing.",
        "2| Click the tray icon to switch between English and your last Bangla layout.",
        "3| Double-click the tray icon to show or hide the bar. Right-click it for layouts, tools, Settings, About and Exit.",
        "# Fonts",
        "* Bijoy Classic (ANSI) needs a matching ANSI font such as SutonnyMJ, which you must get yourself.",
        "* The Unicode layouts work with fonts like Nirmala UI, which comes with Windows.",
        "# Customize it (Settings, from the tray menu or the bar)",
        "* **General**: typing mode (one for all windows, or each program remembers its own), start with Windows, always on top, splash screen, tray icon, Tools in the tray menu (submenu or list), close confirmation, tooltips and Avro Phonetic.",
        "* **TopBar Theme**: bar style, colour theme, icon size and the Extra buttons (tick a button, choose the Tools program it starts and its icon). The bar changes at once; Cancel puts it back.",
        "* **Bangla Snippet**: turn the text expander on or off and set its trigger, case, word-start, paste and macro options. Add the texts in Tools > Bangla Snippet.",
        "* **Layouts (all)**: give every layout its own shortcut key, choose which ones are listed, or restore the defaults.",
        "* **Multi Encoding**: switch ANSI conversion on or off, give every encoding a shortcut key (the Win key can be part of it) and press the ? button to see its details.",
        "* **Extra Tools**: a shortcut key for every program of the Tools folder, and whether it is listed in the menus.",
        "* **Auto Fonts**: automatic font change for Office programs when you switch typing mode.",
        "* **Quick Fonts**: up to 10 manual font shortcuts.",
        "* **Extra Settings**: start the Performance Helper together with the program, and show or hide its tray icon.",
        "* Nothing is saved until you press Save. Each tab has its own Reset button.",
        "# If it is your main typing program",
        "* Programs that run as administrator (for example Task Manager or an administrator Command Prompt) do not accept typed text from Bangla Keyboard, unless Bangla Keyboard runs as administrator too.",
        "* Remote Desktop, virtual machines, some games and a few old or unusual programs may not accept the typing. Switch to English there, or use the On Screen KB tool.",
        "* Avro Phonetic rewrites the word you are typing, so auto-complete and auto-correct (in Word, browsers, spreadsheets) can get in its way. Finish a word with Space.",
        "* To stop the program on purpose, use Exit in the tray menu. The notes at the end of README.md explain every case in detail.",
        "# Make your own skin",
        "* Copy the **_Skin Template** folder from the **Skins** folder, rename it (without the _ at the front) and edit its **skin.ini** and pictures.",
        "* skin.ini says where the icon, the layout box and every button go, and what each button does: Settings, About, Minimize, Close, On/Off toggle, a layout, the layout menu, or a program from the Tools folder. Add as many buttons as you like. Buttons with Action=Ext1 - Ext6 are the extra buttons of Settings > TopBar Theme (a [+] skin, like Avro Flat [+] or Avro Classic [+]).",
        "* Your skin appears in Settings > TopBar Theme (TopBar style) under the name written in skin.ini. Built-in styles are never changed.",
        "# Add more layouts",
        "Drop a .xml or .bkl layout file into the Layouts folder and restart, or build one with the Layout Builder. If a .bkl and a .xml share a name, the .bkl is used.",
        "# Add more encodings",
        "Drop a .json or .menc encoding file into Library\Encoding Script and restart. A .menc is a locked .json made with Pupo Encrypter. If a .menc and a .json share a name, the .menc is used.",
        "# Encoding Script and Encoding Table",
        "The Library folder holds two kinds of encoding files. They look alike in the converters, but they do different jobs:",
        "* **Encoding Script** (Library\Encoding Script, .json / .menc): custom, more controlled conversion. A script is a full set of rules (conjuncts, vowel signs, reph, corrections), so it can convert exactly the way its maker designed. The keyboard's Multi Encoding typing uses scripts only, and the converters can use them too.",
        "* **Encoding Table** (Library\Encoding Table, .txt / .een): standard (universal) conversion. A table is a plain list of ANSI and Unicode pairs, one pair per line. It is simple and general, and it is read by the converters only (Text Converter and Docs Converter).",
        "* **Which one to use?** Use a Table for ordinary, everyday conversion. Use a Script when you need more control or a custom result. In the converters, names start with Script: or Table: so you can tell them apart.",
        "* **Text Converter**: Settings > Encodings in the toolbar list chooses what the toolbar dropdown shows: Encoding Table, Encoding Script, or Table Plus Script.",
        "* **Docs Converter**: lists everything, tagged Script: or Table:."
    ])
}

AboutRtfTools() {
    return RtfPage([
        "# Included tools",
        "They live in the Tools folder. Open them from the tray menu, or put them on the bar's extra buttons (Settings > TopBar Theme). Any .ahk or .exe you drop into Tools also appears in the tray menu.",
        "* **Docs Converter**: converts Word and PowerPoint documents (and text files) between older ANSI fonts such as Bijoy and Unicode. You choose which fonts to convert, and the original file is never changed. Encodings are listed with a tag: Script: (custom) or Table: (standard).",
        "* **Text Converter**: two boxes. Type or paste in one, then press To ANSI or To Unicode. Hover over the encoding dropdown to see what Script and Table mean, and choose which of them are listed in Settings. Hold Ctrl and scroll the mouse wheel over a box to zoom its text in or out.",
        "* **Layout Builder**: builds and edits keyboard layouts (.xml), with a Try it tab to test them.",
        "* **Quick Note**: a small rich-text editor for writing Bangla, with an automatic recovery draft and shortcut keys you can change (File > Settings).",
        "* **Bangla Snippet**: add, edit, find, export and import the texts of the text expander.",
        "* **Typing Tutor**: typing practice and tests with a timer. Correct letters turn green, wrong ones red. The Test, Results and History tabs show the test you are taking, its result and every test you have finished. Texts come from the Typing Tutor Data folder, one file per language.",
        "* **Pupo Encrypter**: locks and unlocks layouts (.xml / .bkl), encoding tables (.txt / .een) and multi-encoding files (.json / .menc) so nobody changes them by accident. This is light scrambling, not real encryption.",
        "* **Emoji Picker**: a replacement for the Windows emoji panel. It opens at the text cursor or the mouse and types the emoji you pick into the program you are using. It uses nothing while it is not running.",
        "* **On Screen KB**: an on-screen Bangla keyboard with Bangla and English pages. It can be resized (keys and fonts scale with it) and has light and dark mode, button themes and key font settings.",
        "# Good to know",
        "* The converters read their tables from Library\Encoding Table and their scripts from Library\Encoding Script (Bijoy V1, Bijoy V2, Lekhoni and Proshika). Table = standard (universal) conversion, Script = custom, more controlled conversion.",
        "* The Performance Helper is not in the Tools folder: it sits next to Bangla Keyboard and starts by itself (Settings > Extra Settings)."
    ])
}

AboutClose(*) {
    try App.about.Destroy()
    App.about := ""
}

; ---- shortcut key box ---------------------------------------------------------
; Replaces Windows' own Hotkey control, which refuses some combinations (Ctrl+Alt+Z for one) and puts the old
; value back when the keys are released. While the box has the focus, every key combination is recorded the moment
; it is pressed and stays until another one is pressed. Backspace / Delete on their own clear it.
; Tab, Enter and Esc keep their normal job (moving around / closing the window), so they cannot be recorded.
class KeyBox {
    static ih := ""             ; the key recorder: it only exists while a box has the focus
    static cur := ""            ; the box that is recording
    hk := ""                    ; recorded shortcut in hotkey text, e.g. "^!z"
    ctl := ""
    onChange := ""              ; optional: called after a key was recorded or cleared by the person

    __New(g, opts) {
        this.ctl := g.Add("Edit", opts . " ReadOnly Center BackgroundWhite")
        this.ctl.OnEvent("Focus", KeyBoxBegin.Bind(this))
        this.ctl.OnEvent("LoseFocus", KeyBoxEnd.Bind(this))
    }

    Value {
        get => this.hk
        set {
            this.hk := value
            this.ctl.Value := (value = "") ? "" : PrettyHk(value)
        }
    }

    Enabled {
        get => this.ctl.Enabled
        set => this.ctl.Enabled := value
    }
}

KeyBoxBegin(box, *) {
    KeyBoxEnd()
    ih := InputHook()
    ih.KeyOpt("{All}", "NS")                                       ; see every key, and keep it away from the window
    ih.KeyOpt("{Tab}{Enter}{Esc}{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}", "-S")   ; these must keep working normally
    ih.OnKeyDown := KeyBoxDown.Bind(box)
    ih.Start()
    KeyBox.ih := ih
    KeyBox.cur := box
}

; box = "" stops whichever box is recording; otherwise only that box
KeyBoxEnd(box := "", *) {
    if (IsObject(box) && !(IsObject(KeyBox.cur) && ObjPtr(KeyBox.cur) = ObjPtr(box)))
        return
    if IsObject(KeyBox.ih)
        try KeyBox.ih.Stop()
    KeyBox.ih := ""
    KeyBox.cur := ""
}

KeyBoxDown(box, ih, vk, sc) {
    if (vk = 0xE7 || (vk >= 0x10 && vk <= 0x12) || (vk >= 0xA0 && vk <= 0xA5) || vk = 0x5B || vk = 0x5C)
        return                                                     ; text typed by this program, or a modifier key on its own
    if !(IsObject(App.dlg) && WinActive("ahk_id " . App.dlg.Hwnd)) {
        KeyBoxEnd()                                                ; never keep the keyboard captured outside the Settings window
        return
    }
    if (vk = 0x09 || vk = 0x0D || vk = 0x1B)
        return
    mods := (GetKeyState("Ctrl", "P") ? "^" : "") . (GetKeyState("Alt", "P") ? "!" : "") . (GetKeyState("Shift", "P") ? "+" : "")
    if (mods = "" && (vk = 0x08 || vk = 0x2E))
        box.Value := ""                                            ; Backspace / Delete
    else
        box.Value := mods . KeyBoxName(vk, sc)
    if IsObject(box.onChange)
        try box.onChange.Call()
}

; letters and digits as themselves, named keys by name (F5, Insert ...), anything else as its key code
KeyBoxName(vk, sc) {
    n := GetKeyName(Format("vk{:X}sc{:03X}", vk, sc))
    if (n = "")
        return Format("vk{:X}", vk)
    if (StrLen(n) = 1)
        return RegExMatch(n, "i)^[a-z0-9]$") ? StrLower(n) : Format("vk{:X}", vk)
    return n
}

; ---- settings window: a list of pages on the left (like Photoshop's Preferences), the picked page on the right ----------
SettingsPages() {
    return ["General", "TopBar Theme", "Bangla Snippet", "Layouts (all)", "Multi Encoding", "Extra Tools", "Auto Fonts", "Quick Fonts", "Extra Settings"]
}

; remember a control as belonging to page n (the page shows / hides it); returns the control
PageAdd(st, n, c) {
    st.pg[n].Push((IsObject(c) && c.HasProp("ctl")) ? c.ctl : c)
    return c
}

ShowSettings(*) {
    if IsObject(App.dlg) {
        try App.dlg.Show()
        return
    }
    prev := WinExist("A")
    LoadSkins()                  ; skins added / removed since the program started
    if (IsSkinId(App.style) && StyleIds()[StyleIndex(App.style)] != App.style) {      ; the skin in use was deleted
        App.style := "GreenBangla"
        RebuildBar()
    }
    UnregisterShortcuts()        ; so pressing a shortcut inside the key boxes records it instead of running it

    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Bangla Keyboard - Settings")
    g.SetFont("s9", "Segoe UI")
    g.MarginX := 6
    g.MarginY := 6
    st := {g: g, prev: prev, rows: [], saved: false, origTheme: App.theme, origStyle: App.style, origIconSize: App.iconSize, origExt: ExtOnList(), pg: [], cur: 1, side: [], hov: 0, accent: ""}
    pages := SettingsPages()
    Loop pages.Length
        st.pg.Push([])

    acts := ActionList()
    nA := 0
    nR := 0
    for a in acts {
        if (SubStr(a.id, 1, 2) = "R:")
            nR++
        else
            nA++
    }
    ; the window is as tall as its tallest page
    H := Max(344, 25 * nA + 38, 25 * Max(1, nR) + 38, 27 * (App.layouts.Length + 1) + 60, 27 * FontSlotCount() + 60, 27 * (EncChoices().Length + 1) + 60)
    gx := 160                                                      ; left edge of the page area
    gw := 334                                                      ; width of the page area
    x0 := gx + 8                                                   ; left edge of the controls on a page
    xd := gx + 108                                                 ; left edge of the drop-down boxes next to a label
    wd := gw - 116                                                 ; their width

    ; the sidebar: a light panel, one flat row per page, a thin accent bar beside the picked page
    g.Add("Text", "x0 y0 w148 h" . (H + 12) . " BackgroundF2F2F2")
    g.Add("Text", "x148 y0 w1 h" . (H + 12) . " BackgroundDADADA")
    st.sideTxt := []
    Loop pages.Length {
        sy := 10 + (A_Index - 1) * 28
        it := g.Add("Text", "x0 y" . sy . " w148 h28 +0x100 BackgroundF2F2F2")
        it.OnEvent("Click", SideClick.Bind(st, A_Index))
        st.side.Push(it)
        tx := g.Add("Text", "x12 y" . sy . " w134 h28 +0x200 +0x100 BackgroundF2F2F2", pages[A_Index])
        tx.SetFont("s10 w400 c404040", "Segoe UI")
        tx.OnEvent("Click", SideClick.Bind(st, A_Index))
        st.sideTxt.Push(tx)
    }
    Loop pages.Length
        PageAdd(st, A_Index, g.Add("GroupBox", "x" . gx . " y6 w" . gw . " h" . H, pages[A_Index]))

    ; ---------- 1: General (mode, startup, splash, tray, other options) ----------
    st.cbAvro := PageAdd(st, 1, g.Add("Checkbox", "x" . x0 . " y28", "Avro Phonetic (Unicode Only)"))
    st.cbAvro.Value := App.avroOn ? 1 : 0
    st.cbStart := PageAdd(st, 1, g.Add("Checkbox", "x" . x0 . " y50", "Start with Windows"))
    st.cbStart.Value := IsAutoStart() ? 1 : 0
    st.cbMin := PageAdd(st, 1, g.Add("Checkbox", "x" . x0 . " y72", "Start with the top bar minimized (in the tray)"))
    st.cbMin.Value := App.startMin ? 1 : 0
    st.cbTray := PageAdd(st, 1, g.Add("Checkbox", "x" . x0 . " y94", "Always show the tray icon"))
    st.cbTray.Value := App.trayAlways ? 1 : 0
    st.cbToolsSub := PageAdd(st, 1, g.Add("Checkbox", "x" . x0 . " y116", "Show the Tools in the tray menu as a submenu"))
    st.cbToolsSub.Value := App.toolsSub ? 1 : 0
    st.cbLaySub := PageAdd(st, 1, g.Add("Checkbox", "x" . x0 . " y138", "Show the Layouts in the tray menu as a submenu"))
    st.cbLaySub.Value := App.layoutSub ? 1 : 0
    st.cbConfirm := PageAdd(st, 1, g.Add("Checkbox", "x" . x0 . " y160", "Confirm before closing"))
    st.cbConfirm.Value := App.confirmClose ? 1 : 0
    st.cbTips := PageAdd(st, 1, g.Add("Checkbox", "x" . x0 . " y182", "Show tooltips (a hint on every option)"))
    st.cbTips.Value := App.tips ? 1 : 0
    ; the drop-down options sit at the bottom
    PageAdd(st, 1, g.Add("Text", "x" . x0 . " y214 w100 h22 +0x200", "Mode switching:"))
    st.ddMode := PageAdd(st, 1, g.Add("DropDownList", "x" . xd . " y212 w" . wd . " Choose" . (App.perWin ? 2 : 1), ["Global (All Windows)", "Per Application/Window"]))
    st.cbSplash := PageAdd(st, 1, g.Add("Checkbox", "x" . x0 . " y244 w100 h22", "Splash screen:"))    ; ticked = show the splash, unticked = off (and the time box is greyed out)
    st.cbSplash.Value := App.splashOn ? 1 : 0
    st.ddSplash := PageAdd(st, 1, g.Add("DropDownList", "x" . xd . " y242 w" . wd . " Choose" . Min(5, Max(1, Round(App.splashMs / 1000))), ["1 second", "2 seconds", "3 seconds", "4 seconds", "5 seconds"]))
    st.ddSplash.Enabled := (st.cbSplash.Value = 1)
    st.cbSplash.OnEvent("Click", (*) => st.ddSplash.Enabled := (st.cbSplash.Value = 1))

    ; ---------- 2: TopBar Theme (+ extra buttons) ----------
    st.cbTop := PageAdd(st, 2, g.Add("Checkbox", "x" . x0 . " y28", "Keep the bar on top of other windows"))
    st.cbTop.Value := App.onTop ? 1 : 0
    PageAdd(st, 2, g.Add("Text", "x" . x0 . " y56 w100 h22 +0x200", "TopBar color:"))
    st.ddTheme := PageAdd(st, 2, g.Add("DropDownList", "x" . xd . " y54 w" . wd, ThemeNames()))
    try st.ddTheme.Choose(App.theme)
    st.ddTheme.OnEvent("Change", (*) => ApplyTheme(st.ddTheme.Text))      ; live preview, Cancel puts it back
    PageAdd(st, 2, g.Add("Text", "x" . x0 . " y84 w100 h22 +0x200", "TopBar style:"))
    st.ddStyle := PageAdd(st, 2, g.Add("DropDownList", "x" . xd . " y82 w" . wd . " Choose" . StyleIndex(App.style), StyleLabels()))
    st.ddStyle.OnEvent("Change", (*) => PreviewStyle(st))             ; live preview, Cancel puts it back
    st.ddTheme.Enabled := UsesTheme(App.style)                        ; colours only apply to the Default styles
    PageAdd(st, 2, g.Add("Text", "x" . x0 . " y112 w100 h22 +0x200", "Icon size:"))
    st.ddIcon := PageAdd(st, 2, g.Add("DropDownList", "x" . xd . " y110 w" . wd . " Choose" . App.iconSize, IconSizeLabels()))
    st.ddIcon.OnEvent("Change", (*) => PreviewIconSize(st))           ; live preview, Cancel puts it back

    ; ---------- 4: Extra Buttons ----------
    ; tick a button to show it on the bar, then pick which Tools program it starts, and its icon
    PageAdd(st, 2, g.Add("Text", "x" . x0 . " y146 w" . (gw - 16) . " h32", 'Extra buttons (only shown with the [+] styles; button 1 is always on; buttons 3+ only in skins that have them):'))
    st.ext := []
    st.extFiles := ToolFiles()
    exAct := ["(None)"]
    for f in st.extFiles
        exAct.Push(f.name)
    exIco := ExtIconNames()
    st.extDD := []
    Loop ExtRowCount() {
        bn := A_Index
        ry := 184 + (bn - 1) * 28
        b := App.ext[bn]
        ia := 1
        for k, f in st.extFiles {
            if (f.full = b.act)
                ia := k + 1
        }
        ii := 1
        for k, nm in exIco {
            if (nm = b.icon)
                ii := k
        }
        cb := PageAdd(st, 2, g.Add("Checkbox", "x" . x0 . " y" . ry . " w74 h22", "Button " . bn . ":"))
        cb.Value := b.on ? 1 : 0
        cb.OnEvent("Click", ToggleExt.Bind(st, bn))
        dA := PageAdd(st, 2, g.Add("DropDownList", "x" . (x0 + 80) . " y" . ry . " w130 Choose" . ia, exAct))
        dI := PageAdd(st, 2, g.Add("DropDownList", "x" . (x0 + 216) . " y" . ry . " w108 Choose" . ii, exIco))
        SendMessage(0x160, 170, 0, dI.Hwnd)          ; CB_SETDROPPEDWIDTH: the open list is wider than the box, so the names fit
        st.ext.Push(cb, dA, dI)
        st.extDD.Push({on: cb, act: dA, icon: dI})
    }
    SyncExtRows(st)


    ; ---------- 3: Layouts / 4: Extra Tools  (shortcut keys) ----------
    yL := 28
    yT := 28
    if (nR = 0)
        PageAdd(st, 6, g.Add("Text", "x" . x0 . " y30 w" . (gw - 16), "No .exe / .ahk files found in the Tools folder."))
    for a in acts {
        isR := (SubStr(a.id, 1, 2) = "R:")
        pn := isR ? 6 : 4
        y := isR ? yT : yL
        row := {id: a.id, label: a.label, def: a.def, dshow: isR ? 0 : 1, cb: "", hk: "", clr: ""}
        PageAdd(st, pn, g.Add("Text", "x" . x0 . " y" . y . " w120 h22 +0x200", StrReplace(a.label, "&", "&&")))
        row.hk := PageAdd(st, pn, KeyBox(g, "x" . (x0 + 124) . " y" . y . " w110 h22"))
        row.cb := PageAdd(st, pn, g.Add("Checkbox", "x" . (x0 + 240) . " y" . y . " w20 h22"))           ; every row has a tick box: unticked = no shortcut
        row.cb.Value := App.shown.Get(a.id, !isR) ? 1 : 0
        row.clr := PageAdd(st, pn, g.Add("Button", "x" . (x0 + 264) . " y" . y . " w56 h22", "Clear"))
        LoadRow(row, App.shortcuts.Get(a.id, ""))
        row.clr.OnEvent("Click", ClearRow.Bind(row))
        row.cb.OnEvent("Click", SyncRow.Bind(row))
        SyncRow(row)
        st.rows.Push(row)
        if isR
            yT += 25
        else
            yL += 25
    }

    ; ---------- 5: Multi Encoding (a shortcut key for every encoding) ----------
    st.cbEnc := PageAdd(st, 5, g.Add("Checkbox", "x" . x0 . " y28 w" . (gw - 16), "Multi Encoding (Automatic convert to ANSI)"))
    st.cbEnc.Value := App.encOn ? 1 : 0
    st.erows := []
    ey := 58
    for nm in EncChoices() {                           ; "Unicode" (no conversion) first, then every file of the Library folder
        row := {id: nm}
        PageAdd(st, 5, g.Add("Text", "x" . x0 . " y" . ey . " w76 h22 +0x200", StrReplace(nm, "&", "&&")))
        row.win := PageAdd(st, 5, g.Add("Checkbox", "x" . (x0 + 80) . " y" . ey . " w42 h22", "Win"))
        row.hk := PageAdd(st, 5, KeyBox(g, "x" . (x0 + 124) . " y" . ey . " w96 h22"))
        row.clr := PageAdd(st, 5, g.Add("Button", "x" . (x0 + 224) . " y" . ey . " w56 h22", "Clear"))
        row.info := PageAdd(st, 5, g.Add("Button", "x" . (x0 + 286) . " y" . ey . " w22 h22", "?"))     ; square info button: shows the Metadata of the encoding
        LoadEncRow(row, App.encKeys.Get(nm, ""))
        row.clr.OnEvent("Click", ClearEncRow.Bind(row))
        row.info.OnEvent("Click", EncInfo.Bind(st, nm))
        st.erows.Push(row)
        ey += 27
    }
    st.cbEnc.OnEvent("Click", SyncEncRows.Bind(st))
    SyncEncRows(st)

    ; ---------- 6: Auto Fonts ----------
    st.cbFont := PageAdd(st, 7, g.Add("Checkbox", "x" . x0 . " y28 w" . (gw - 16), "Change the font automatically (Office apps)"))
    st.cbFont.Value := App.fontOn ? 1 : 0
    st.frows := []
    fl := []
    try fl := InstalledFonts()
    fy := 58
    fkeys := []
    for i in LayoutOrder()
        fkeys.Push(App.layouts[i].name)
    fkeys.Push("English")
    for k in fkeys {
        c := App.fonts.Get(k)
        row := {key: k}
        row.cb := PageAdd(st, 7, g.Add("Checkbox", "x" . x0 . " y" . fy . " w112 h22", k))
        row.cb.Value := c.on ? 1 : 0
        row.font := PageAdd(st, 7, g.Add("ComboBox", "x" . (x0 + 116) . " y" . (fy - 1) . " w150 r10", fl))
        row.font.Text := c.font
        row.size := PageAdd(st, 7, g.Add("ComboBox", "x" . (x0 + 270) . " y" . (fy - 1) . " w54 r10", ["Auto", "8", "9", "10", "11", "12", "14", "16", "18", "20", "24", "28", "36"]))
        row.size.Text := c.size ? c.size : "Auto"
        row.cb.OnEvent("Click", SyncFontRows.Bind(st))
        st.frows.Push(row)
        fy += 27
    }
    st.cbFont.OnEvent("Click", SyncFontRows.Bind(st))
    SyncFontRows(st)

    ; ---------- 9: Extra Settings (Performance Helper) ----------
    st.cbHelper := PageAdd(st, 9, g.Add("Checkbox", "x" . x0 . " y28 w" . (gw - 16), "Start the Performance Helper with the program"))
    st.cbHelper.Value := App.helperOn ? 1 : 0
    st.cbHelperTray := PageAdd(st, 9, g.Add("Checkbox", "x" . x0 . " y50 w" . (gw - 16), "Show the Performance Helper icon in the tray"))
    st.cbHelperTray.Value := App.helperTray ? 1 : 0
    st.cbHelperTray.Enabled := (st.cbHelper.Value = 1)
    st.cbHelper.OnEvent("Click", (*) => st.cbHelperTray.Enabled := (st.cbHelper.Value = 1))
    PageAdd(st, 9, g.Add("Text", "x" . x0 . " y90 w" . (gw - 16) . " h96", "The Performance Helper is a tiny background program. If Bangla Keyboard ever stops unexpectedly, it starts it again.`n`nIt uses almost no CPU or memory while it waits. To stop Bangla Keyboard on purpose, use Exit in its tray menu."))

    ; ---------- 6: Quick Fonts (manual font shortcuts) ----------
    ; tick the box, then give each slot its own key (Ctrl / Alt / Win + key), font and size.
    ; Only one slot shows at first; the next one appears when the last one is filled (up to FontSlotCount()).
    st.cbManual := PageAdd(st, 8, g.Add("Checkbox", "x" . x0 . " y28 w" . (gw - 16), "Manual font shortcuts (Office apps)"))
    st.cbManual.Value := App.manualOn ? 1 : 0
    st.slots := []
    sy := 58
    Loop FontSlotCount() {
        row := {}
        row.win := PageAdd(st, 8, g.Add("Checkbox", "x" . x0 . " y" . sy . " w42 h22", "Win"))
        row.hk := PageAdd(st, 8, KeyBox(g, "x" . (x0 + 46) . " y" . sy . " w96 h22"))
        row.hk.onChange := SlotChanged.Bind(st)
        row.font := PageAdd(st, 8, g.Add("ComboBox", "x" . (x0 + 146) . " y" . sy . " w116 r10", fl))
        SendMessage(0x160, 220, 0, row.font)               ; CB_SETDROPPEDWIDTH: the font list is wider than the box
        row.size := PageAdd(st, 8, g.Add("ComboBox", "x" . (x0 + 270) . " y" . sy . " w54 r10", ["Auto", "8", "9", "10", "11", "12", "14", "16", "18", "20", "24", "28", "36"]))
        row.font.OnEvent("Change", SlotChanged.Bind(st))
        LoadSlotRow(row, App.slots[A_Index])
        st.slots.Push(row)
        sy += 27
    }
    st.cbManual.OnEvent("Click", ManualToggle.Bind(st))
    SyncSlotRows(st)

    ; ---------- 7: Bangla Snippet (text expander) ----------
    ; The tick box switches the whole expander on / off: unticked, nothing runs and the saved snippets are not kept in memory.
    ; The texts themselves are added and edited with Tools > Bangla Snippet.
    st.cbSnip := PageAdd(st, 3, g.Add("Checkbox", "x" . x0 . " y28 w" . (gw - 16), "Bangla Snippet (text expander)"))
    st.cbSnip.Value := Snip.enabled ? 1 : 0
    PageAdd(st, 3, g.Add("Text", "x" . x0 . " y54 w" . (gw - 16) . " h20", "Add and edit the texts in Tools > Bangla Snippet."))
    st.lblTrig := PageAdd(st, 3, g.Add("Text", "x" . x0 . " y86 w100 h22 +0x200", "Trigger key:"))
    st.edTrig := PageAdd(st, 3, g.Add("Edit", "x" . xd . " y84 w90 Limit10", Snip.trigger))
    st.cbSnipCs := PageAdd(st, 3, g.Add("Checkbox", "x" . x0 . " y118", "Case-sensitive matching"))
    st.cbSnipCs.Value := Snip.cs ? 1 : 0
    st.cbSnipWb := PageAdd(st, 3, g.Add("Checkbox", "x" . x0 . " y140", "Title must start at a word boundary"))
    st.cbSnipWb.Value := Snip.wb ? 1 : 0
    st.cbSnipClip := PageAdd(st, 3, g.Add("Checkbox", "x" . x0 . " y162", "Paste via clipboard (for very long snippets)"))
    st.cbSnipClip.Value := Snip.clip ? 1 : 0
    st.cbSnipMac := PageAdd(st, 3, g.Add("Checkbox", "x" . x0 . " y184", "Macros: {date}  {date=bn}  {time}  {clipboard}  {cursor} ..."))
    st.cbSnipMac.Value := Snip.macros ? 1 : 0
    st.cbSnip.OnEvent("Click", SyncSnipRows.Bind(st))
    SyncSnipRows(st)

    ; ---------- buttons: Reset on the left, Save and Cancel on the right ----------
    by := H + 18
    right := gx + gw                                               ; right edge of the page area
    bReset := g.Add("Button", "x6 y" . by . " w100", "Reset")
    bReset.OnEvent("Click", ResetTab.Bind(st))
    bSave := g.Add("Button", "x" . (right - 208) . " y" . by . " w100 Default", "Save")
    bCancel := g.Add("Button", "x" . (right - 100) . " y" . by . " w100", "Cancel")
    bSave.OnEvent("Click", SaveSettingsDlg.Bind(st))
    bCancel.OnEvent("Click", DlgClose.Bind(st))
    g.OnEvent("Close", DlgClose.Bind(st))
    g.OnEvent("Escape", DlgClose.Bind(st))
    st.bReset := bReset
    st.bSave := bSave
    st.bCancel := bCancel
    ShowPage(st, 1)                                ; only the first page shows
    AddSettingsTips(st)                            ; hover hints (switched on / off by the "Show tooltips" box)
    SetTimer(TipPoll, 120)
    SetTimer(SideHover, 50)
    App.dlg := g
    App.dlgSt := st
    g.Show()
}

; shows the controls of page n and hides the ones of every other page
ShowPage(st, n) {
    if (n < 1 || n > st.pg.Length)
        return
    st.cur := n
    for i, list in st.pg {
        v := (i = n)
        for c in list
            c.Visible := v
    }
    SideColors(st)
    FontsLayout(st)                                  ; the manual font slots that are not in use stay hidden
}

SideClick(st, n, *) {
    ShowPage(st, n)
}

; sidebar look: picked page = white row + bold text + accent bar, the row under the mouse = slightly darker
SideColors(st) {
    for i, it in st.side {
        sel := (i = st.cur)
        hot := (it.Hwnd = st.hov)
        col := sel ? "FFFFFF" : hot ? "E4E4E4" : "F2F2F2"
        t := st.sideTxt[i]
        it.Opt("Background" . col)
        t.Opt("Background" . col)
        t.SetFont(sel ? "s10 bold c1F1F1F" : "s10 norm c404040", "Segoe UI")      ; only the weight changes: the text stays where it is
        it.Redraw()
        t.Redraw()
    }
}

; runs while Settings is open: lights up the sidebar row under the mouse
SideHover() {
    st := App.dlgSt
    if !IsObject(st)
        return
    MouseGetPos(, , &win, &ctl, 2)
    h := (win = st.g.Hwnd && IsInteger(ctl)) ? ctl : 0
    on := 0
    for i, it in st.side {
        if (h && (it.Hwnd = h || st.sideTxt[i].Hwnd = h))
            on := it.Hwnd
    }
    if (on = st.hov)
        return
    st.hov := on
    SideColors(st)
}

; ---- Manual Fonts page: the slots show one at a time ---------------------------------------------------------------
; Nothing shows until "Manual font shortcuts" is ticked. Slot 1 shows first; the next slot appears when the last
; visible one has both a shortcut and a font, up to FontSlotCount(). A slot with anything in it stays visible.
VisibleSlots(st) {
    last := 0
    done := 0
    for i, r in st.slots {
        k := (r.hk.Value != "")
        f := (Trim(r.font.Text) != "")
        if (k || f)
            last := i
        if (k && f)
            done := i
    }
    return Min(FontSlotCount(), Max(1, last, done + 1))
}

SlotChanged(st, *) {
    FontsLayout(st)
}

ManualToggle(st, *) {
    SyncSlotRows(st)
    FontsLayout(st)
}

; shows / hides the manual font slots (only while the Quick Fonts page is the one showing)
FontsLayout(st, *) {
    n := (st.cbManual.Value = 1) ? VisibleSlots(st) : 0
    page := (st.cur = 8)
    for i, r in st.slots {
        v := (page && i <= n)
        r.hk.ctl.Visible := v
        r.win.Visible := v
        r.font.Visible := v
        r.size.Visible := v
    }
}

; ---- "Reset": puts the page that is showing back to its defaults (nothing is saved until you press Save) ----
ResetTab(st, *) {
    switch st.cur {
        case 1: ResetGeneralPage(st)
        case 2: ResetTopBarPage(st)
        case 3: ResetSnipPage(st)
        case 4: ResetShortcutRows(st, false)
        case 5: ResetEncPage(st)
        case 6: ResetShortcutRows(st, true)
        case 7: ResetFontsTab(st)
        case 8: ResetManualTab(st)
        case 9: ResetExtraPage(st)
    }
}

ResetSnipPage(st) {
    st.cbSnip.Value := 1
    st.edTrig.Value := "=="
    st.cbSnipCs.Value := 0
    st.cbSnipWb.Value := 0
    st.cbSnipClip.Value := 0
    st.cbSnipMac.Value := 1
    SyncSnipRows(st)
}

; the options of the Bangla Snippet page are greyed out while its main tick box is off
SyncSnipRows(st, *) {
    on := (st.cbSnip.Value = 1)
    for c in [st.lblTrig, st.edTrig, st.cbSnipCs, st.cbSnipWb, st.cbSnipClip, st.cbSnipMac]
        c.Enabled := on
}

SaveSnipSettings(st) {
    SaveSetting("Snippets", "Enabled", st.cbSnip.Value = 1 ? 1 : 0)
    SaveSetting("Snippets", "Trigger", st.edTrig.Value)
    SaveSetting("Snippets", "CaseSensitive", st.cbSnipCs.Value = 1 ? 1 : 0)
    SaveSetting("Snippets", "WordBoundary", st.cbSnipWb.Value = 1 ? 1 : 0)
    SaveSetting("Snippets", "Clipboard", st.cbSnipClip.Value = 1 ? 1 : 0)
    SaveSetting("Snippets", "Macros", st.cbSnipMac.Value = 1 ? 1 : 0)
    Snip.Reload()                                      ; starts / stops the expander right now
}

ResetGeneralPage(st) {
    st.ddMode.Choose(1)
    st.cbStart.Value := 0
    st.cbMin.Value := 0
    st.cbSplash.Value := 1
    st.ddSplash.Choose(2)
    st.ddSplash.Enabled := true
    st.cbTray.Value := 1
    st.cbToolsSub.Value := 1
    st.cbConfirm.Value := 1
    st.cbTips.Value := 1
    st.cbAvro.Value := 0
    st.cbLaySub.Value := 0
}

ResetExtraPage(st) {
    st.cbHelper.Value := 1
    st.cbHelperTray.Value := 0
    st.cbHelperTray.Enabled := true
}

ResetTopBarPage(st) {
    st.cbTop.Value := 1
    st.ddIcon.Choose(1)
    st.ddTheme.Choose("DarkGreen")
    st.ddStyle.Choose(StyleIndex("GreenBangla"))
    st.ddTheme.Enabled := UsesTheme("GreenBangla")
    for k, r in st.extDD {
        r.on.Value := (k = 1) ? 1 : 0                  ; default: button 1 on, the others off
        App.ext[k].on := (k = 1)
        r.act.Choose(1)
        r.icon.Choose(2)                               ; 1 = (None), 2 = App icon (the default)
    }
    App.theme := "DarkGreen"
    ApplyStyle("GreenBangla")                      ; live preview (Cancel puts the old look back)
    SyncExtRows(st)
}

ResetFontsTab(st) {
    st.cbFont.Value := 0
    for r in st.frows {
        isEng := (r.key = "English")
        r.cb.Value := isEng ? 1 : 0
        r.font.Text := isEng ? "Arial" : ""
        r.size.Text := "Auto"
    }
    SyncFontRows(st)
}

ResetManualTab(st) {
    st.cbManual.Value := 0
    for r in st.slots {
        r.hk.Value := ""
        r.win.Value := 0
        r.font.Text := ""
        r.size.Text := "Auto"
    }
    SyncSlotRows(st)
    FontsLayout(st)
}

; the extra-button rows are only there while an "Ext" style is picked
; ---------------------------------------------------------------------------
;  Hover hints for the Settings window: rest the mouse on an option and a small tooltip explains it.
;  Controls and their text are listed in AddSettingsTips; TipPoll shows the one under the mouse.
;  Turn them off with "Show tooltips" (General tab).
; ---------------------------------------------------------------------------
SetTip(st, ctl, text) {
    if IsObject(ctl)
        st.tips[ctl.Hwnd] := text
}

AddSettingsTips(st) {
    st.tips := Map()
    SetTip(st, st.cbStart, "Starts Bangla Keyboard by itself when you sign in to Windows.")
    SetTip(st, st.cbTop, "Keeps the top bar above other windows, so it is never hidden behind them.")
    SetTip(st, st.cbSnip, "Turns the text expander on or off.`nOn: type a saved title and then the trigger, and both are replaced by the saved text.`nExample: type  addr==  and it becomes your full address.`nOff: nothing runs and no snippets are kept in memory.")
    SetTip(st, st.edTrig, "The characters you type right after a title to expand it (no spaces).`nExample: with ==, typing  sig==  expands the snippet titled sig.`nChange it to ## and you type  sig##  instead.")
    SetTip(st, st.cbSnipCs, "On: capital and small letters must match.`nExample: a snippet titled Sig expands with  Sig==  but not with  sig==.`nOff: both work.")
    SetTip(st, st.cbSnipWb, "On: a title only works at the start of a word.`nExample: with the title sig, typing  my sig==  works, but  mysig==  does not.`nOff: it also works inside a word.")
    SetTip(st, st.cbSnipClip, "On: the text is pasted instead of typed. Much faster for long texts, like a full letter.`nYour clipboard is restored afterwards.`nOff: the text is typed letter by letter (slower, works everywhere).")
    SetTip(st, st.cbSnipMac, "On: special words in a snippet are replaced when it expands.`n{date} 22/11/2026   {time} 02:30 PM   {time24} 14:30`n{datetime} 22/11/2026 02:30 PM   {longdate} Sunday, 22 November 2026`n{day} Sunday   {month} November   {year} 2026`nAdd =bn for Bangla: {date=bn} ২২/১১/২০২৬   {longdate=bn} রবিবার, ২২ নভেম্বর ২০২৬`n{clipboard} the text you copied last   {cursor} where the cursor ends up`nExample: Dear {cursor},  leaves the cursor after Dear.`nOff: they are typed exactly as written.")
    SetTip(st, st.cbMin, "The program starts hidden in the tray instead of showing the top bar.`nClick the tray icon to bring the bar back.")
    SetTip(st, st.cbConfirm, "Asks `"are you sure?`" before the program closes.")
    SetTip(st, st.cbTray, "Keeps the tray icon visible all the time.`nUnticked, it only shows while the top bar is minimized.")
    SetTip(st, st.cbToolsSub, "Ticked: the programs of the Tools folder sit in a Tools submenu of the tray menu.`nUnticked: they are listed directly in the tray menu.")
    SetTip(st, st.cbLaySub, "Ticked: the layouts sit in a Layouts submenu of the tray menu.`nUnticked: they are listed directly in the tray menu.`nThe bar's layout menu always lists them directly.")
    for r in st.erows
        SetTip(st, r.info, "Shows the details of this encoding (name, version, developer, suggested font ...).")
    SetTip(st, st.cbEnc, "Ticked: the text you type in a Unicode layout can be converted to an ANSI encoding of the Library folder,`nand every encoding below can have its own shortcut key (Win key included).`\nUnticked: no conversion, no encoding shortcuts.")
    SetTip(st, st.cbHelper, "Starts a tiny helper program together with Bangla Keyboard.`nIf Bangla Keyboard ever stops unexpectedly (a crash), the helper starts it again.`nIt uses almost no CPU or memory while it waits.`nUntick to switch it off (it stops right after you press Save).")
    SetTip(st, st.cbHelperTray, "Shows the Performance Helper's own small icon in the tray.`nUnticked: it runs hidden, with no icon.")
    SetTip(st, st.cbTips, "Shows a hint like this one when you rest the mouse on an option.`nUntick to turn the hints off.")
    SetTip(st, st.cbAvro, "Adds Avro Phonetic (type Bangla with English letters, Unicode only)`nto the layout list and the Layout page. Untick to hide it again.`nSave, then open Settings again to give it a shortcut key.")
    SetTip(st, st.cbSplash, "Shows a picture when the program starts.`nPictures come from the Splash folder.")
    SetTip(st, st.ddSplash, "How long the splash stays.`nPictures in the Splash folder are used.")
    SetTip(st, st.ddTheme, "Colours of the top bar (Default styles only).`nYou see it at once; Cancel puts it back.")
    SetTip(st, st.ddStyle, "The look of the top bar.`nYou see it at once; Cancel puts it back.")
    SetTip(st, st.ddMode, "Global: one typing mode for every window.`nPer Application/Window: each window remembers its own mode.")
    SetTip(st, st.ddIcon, "Size of the icon on the top bar. You see it at once.`nCustom bar icon: put a .png or .ico in the Icons folder, named like`nthe layout (e.g. Unicode.png). A .png is used before a .ico.`nEnglish uses English.png / English.ico.")
    for k, r in st.extDD {
        onTip := "Tick to show extra button " . k . " on the top bar ([+] styles only)." . ((k > 2) ? "`nThis button exists only in the skins that have it." : "")
        if (k = 1)
            onTip := "Extra button 1 on the top bar ([+] styles only). It is always on."
        SetTip(st, r.on, onTip)
        SetTip(st, r.act, "The program or script from the Tools folder that button " . k . " starts.`nChoose (None) to leave the button empty.")
        SetTip(st, r.icon, "The icon of button " . k . ". Pick (None) for an empty button, a built-in symbol, or your own picture.`n(In a skin like Avro Flat, App icon keeps the skin's own picture.)`nTo add your own: put a .png / .ico / .jpg / .bmp / .gif in Skins\Button Icons,`nreopen Settings, then choose its file name here.")
    }
    for row in st.rows {
        lbl := StrReplace(row.label, "&", "")
        SetTip(st, row.hk.ctl, "Click here, then press the keys you want for `"" . lbl . "`".")
        SetTip(st, row.cb, "Tick to use this shortcut. Untick to switch it off.")
        SetTip(st, row.clr, "Removes the shortcut of `"" . lbl . "`".")
    }
    SetTip(st, st.cbFont, "Changes the font by itself in Office apps when you switch typing mode,`nusing the fonts chosen below.")
    for row in st.frows {
        SetTip(st, row.cb, "Use the font on this row when typing " . row.key . ".")
        SetTip(st, row.font, "Font for " . row.key . ". Pick one or type its name.")
        SetTip(st, row.size, "Font size for " . row.key . ", or Auto to leave the size as it is.")
    }
    SetTip(st, st.cbManual, "Your own keys that apply a chosen font and size in Office apps.`nTick it, then fill a slot: a key, the font and the size.")
    for row in st.slots {
        SetTip(st, row.hk.ctl, "Click here, then press the key you want for this font.")
        SetTip(st, row.win, "Tick to add the Windows key to this shortcut.")
        SetTip(st, row.font, "The font this key applies.")
        SetTip(st, row.size, "The size this key applies, or Auto to leave the size as it is.")
    }
    SetTip(st, st.bReset, "Puts the options of this tab back to their defaults.`nNothing is kept until you press Save.")
    SetTip(st, st.bSave, "Saves all changes and closes Settings.")
    SetTip(st, st.bCancel, "Closes Settings without saving. Live previews are undone.")
}

; runs while Settings is open: after the mouse rests ~0.6 s on an option with a hint, the hint shows next to the mouse
TipPoll() {
    static last := 0, since := 0, shown := false
    txt := ""
    st := App.dlgSt
    if (IsObject(st) && st.HasProp("tips") && st.cbTips.Value = 1) {
        MouseGetPos(, , &win, &ctl, 2)
        if (win = App.dlg.Hwnd) {
            h := IsInteger(ctl) ? ctl : 0
            Loop 3 {
                if (!h || h = win)
                    break
                if st.tips.Has(h) {
                    txt := st.tips[h]
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
    }
    if (txt = "") {
        if shown {
            ToolTip(, , , 19)
            shown := false
        }
        if !IsObject(st)
            last := 0
        return
    }
    if (!shown && A_TickCount - since >= 600) {
        ToolTip(txt, , , 19)
        shown := true
    }
}

SyncExtRows(st) {
    id := StyleFromDD(st)
    isExt := IsExtStyle(id)
    slots := SkinExtSlots(id)                          ; the buttons Ext1 - Ext6 a skin has (all false for the other styles)
    for k, r in st.extDD {
        avail := (isExt && k <= 2) || slots[k]         ; the rows are greyed out unless the picked style has this button
        r.on.Enabled := avail
        r.act.Enabled := avail && (k = 1 || r.on.Value = 1)     ; the boxes of buttons 2 and 3 are greyed out until ticked
        r.icon.Enabled := avail && (k = 1 || r.on.Value = 1)
    }
}

; the tick box of extra button i: the bar changes at once (Cancel puts it back)
ToggleExt(st, i, *) {
    if (i = 1) {                                       ; button 1 cannot be switched off
        st.extDD[1].on.Value := 1
        return
    }
    App.ext[i].on := (st.extDD[i].on.Value = 1)
    SyncExtRows(st)
    if (IsExtStyle(App.style) || IsSkinExt(App.style))
        RebuildBar()
}

; the "Icon size" box: the bar is drawn again at once (Cancel puts it back)
PreviewIconSize(st) {
    App.iconSize := Max(1, st.ddIcon.Value)
    RebuildBar()
}

StyleFromDD(st) {
    return StyleIds()[Max(1, st.ddStyle.Value)]
}

PreviewStyle(st) {
    ApplyStyle(StyleFromDD(st))
    st.ddTheme.Enabled := UsesTheme(App.style)
    SyncExtRows(st)
}

DlgClose(st, *) {
    SetTimer(TipPoll, 0)
    SetTimer(SideHover, 0)
    ToolTip(, , , 19)
    KeyBoxEnd()
    undoExt := false
    if !st.saved {
        for i, o in st.origExt {
            if (App.ext[i].on != o) {
                App.ext[i].on := o
                undoExt := true
            }
        }
    }
    if (!st.saved && App.iconSize != st.origIconSize) {
        App.iconSize := st.origIconSize                ; undo the live icon-size preview
        RebuildBar()
    }
    if (!st.saved && App.style != st.origStyle)
        ApplyStyle(st.origStyle)                       ; undo the live style preview
    if (!st.saved && App.theme != st.origTheme)
        ApplyTheme(st.origTheme)                       ; undo the live colour preview
    if (undoExt && (IsExtStyle(App.style) || IsSkinExt(App.style)))
        RebuildBar()                                   ; undo the live extra-buttons preview
    try App.dlg.Destroy()
    App.dlg := ""
    App.dlgSt := ""
    ApplyShortcuts()
    GiveFocusBack(st.prev)
}

; one shortcut row <-> hotkey text
LoadRow(row, hk) {
    row.hk.Value := ""
    if (hk != "") {
        p := SplitHk(hk)
        row.hk.Value := StrReplace(p.mods, "#", "") . p.key
    }
}

ClearRow(row, *) {
    LoadRow(row, "")
}

; an unticked row is greyed out
SyncRow(row, *) {
    on := (!IsObject(row.cb) || row.cb.Value = 1)
    row.hk.Enabled := on
    row.clr.Enabled := on
}

RowHotkey(row) {
    return row.hk.Value
}

ResetShortcutRows(st, tools := false) {
    for row in st.rows {
        if ((SubStr(row.id, 1, 2) = "R:") != tools)
            continue
        LoadRow(row, row.def)
        if IsObject(row.cb) {
            row.cb.Value := row.dshow
            SyncRow(row)
        }
    }
}

; returns "" when fine, otherwise a message for the person
ValidateShortcuts(st, keys) {
    seen := Map()
    shownLayouts := 0
    for r in st.rows {
        if (SubStr(r.id, 1, 2) = "L:" && r.cb.Value = 1 && !(r.id = "L:" . Avro.title && st.cbAvro.Value = 0))
            shownLayouts++
    }
    if (shownLayouts = 0)
        return "Keep at least one Bangla layout ticked."
    for r in st.rows {
        if (r.id = "L:" . Avro.title && st.cbAvro.Value = 0)
            continue                                  ; Avro Phonetic is being switched off
        if (IsObject(r.cb) && r.cb.Value = 0)
            continue                                  ; hidden items have no active shortcut
        hk := keys[r.id]
        if (hk = "")
            continue
        p := SplitHk(hk)
        if (!InStr(p.mods, "^") && !InStr(p.mods, "!")) {
            if !RegExMatch(p.key, "i)^(F\d+|Insert|AppsKey|PrintScreen)$")
                return r.label . ": " . PrettyHk(hk) . " would also be typed as a normal key.`nAdd Ctrl or Alt, or use an F-key."
        }
        k := StrLower(PrettyHk(hk))
        if seen.Has(k)
            return "The shortcut " . PrettyHk(hk) . " is used twice:`n" . seen[k] . "  and  " . r.label
        seen[k] := r.label
    }
    return ""
}

; ---- save ---------------------------------------------------------------------
SaveSettingsDlg(st, *) {
    newMap := Map()
    for r in st.rows
        newMap[r.id] := RowHotkey(r)
    err := ValidateShortcuts(st, newMap)
    if (err != "") {
        MsgBox(err, "Bangla Keyboard", "0x30 Owner" . st.g.Hwnd)
        return
    }

    err := ValidateFonts(st)
    if (err != "") {
        MsgBox(err, "Bangla Keyboard", "0x30 Owner" . st.g.Hwnd)
        return
    }

    err := ValidateManual(st, newMap)
    if (err != "") {
        MsgBox(err, "Bangla Keyboard", "0x30 Owner" . st.g.Hwnd)
        return
    }

    err := ValidateEnc(st, newMap)
    if (err != "") {
        ShowPage(st, 5)
        MsgBox(err, "Bangla Keyboard", "0x30 Owner" . st.g.Hwnd)
        return
    }

    if (st.edTrig.Value = "" || RegExMatch(st.edTrig.Value, "\s")) {
        ShowPage(st, 3)
        MsgBox("The Bangla Snippet trigger key cannot be empty or contain spaces.", "Bangla Keyboard", "0x30 Owner" . st.g.Hwnd)
        return
    }

    perWin := (st.ddMode.Value = 2)

    SetAutoStart(st.cbStart.Value)
    App.onTop := (st.cbTop.Value = 1)
    try App.bar.Opt(App.onTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
    if App.onTop
        KeepOnTop()
    if (st.ddTheme.Text != App.theme)
        ApplyTheme(st.ddTheme.Text)
    SaveSetting("General", "AlwaysOnTop", App.onTop ? 1 : 0)
    SaveSetting("General", "Theme", App.theme)
    extChanged := false
    for k, r in st.extDD {
        on := (k = 1 || r.on.Value = 1)
        act := (r.act.Value <= 1) ? "" : st.extFiles[r.act.Value - 1].full
        ico := r.icon.Text
        if (on != App.ext[k].on || act != App.ext[k].act || ico != App.ext[k].icon)
            extChanged := true
        App.ext[k].on := on
        App.ext[k].act := act
        App.ext[k].icon := ico
        SaveSetting("ExtButtons", "Button" . k . ".Enabled", on ? 1 : 0)
        SaveSetting("ExtButtons", "Button" . k . ".Action", act)
        SaveSetting("ExtButtons", "Button" . k . ".Icon", ico)
    }
    if (Max(1, st.ddIcon.Value) != App.iconSize) {
        App.iconSize := Max(1, st.ddIcon.Value)
        RebuildBar()
    }
    SaveSetting("General", "IconPx", IconSizes()[App.iconSize])
    if (StyleFromDD(st) != App.style)
        ApplyStyle(StyleFromDD(st))
    else if (extChanged && (IsExtStyle(App.style) || IsSkinExt(App.style)))
        RebuildBar()                                   ; the buttons of the bar changed
    SaveSetting("General", "BarStyle", App.style)
    App.splashOn := (st.cbSplash.Value = 1)
    SaveSetting("General", "ShowSplash", App.splashOn ? 1 : 0)
    App.splashMs := st.ddSplash.Value * 1000
    SaveSetting("General", "SplashSeconds", st.ddSplash.Value)
    App.startMin := (st.cbMin.Value = 1)
    SaveSetting("General", "StartMinimized", App.startMin ? 1 : 0)
    App.confirmClose := (st.cbConfirm.Value = 1)
    SaveSetting("General", "ConfirmClose", App.confirmClose ? 1 : 0)
    App.trayAlways := (st.cbTray.Value = 1)
    SaveSetting("General", "TrayAlways", App.trayAlways ? 1 : 0)
    App.toolsSub := (st.cbToolsSub.Value = 1)
    SaveSetting("General", "ToolsSubmenu", App.toolsSub ? 1 : 0)
    App.layoutSub := (st.cbLaySub.Value = 1)
    SaveSetting("General", "LayoutsSubmenu", App.layoutSub ? 1 : 0)
    App.tips := (st.cbTips.Value = 1)
    SaveSetting("General", "ShowTips", App.tips ? 1 : 0)
    SaveSnipSettings(st)
    SyncTray()

    if (perWin != App.perWin) {
        App.winModes := Map()
        if perWin {
            if IsBindable(st.prev)
                App.curWin := st.prev
            if App.curWin
                App.winModes[App.curWin] := App.cur      ; this window keeps its current mode
        }
        App.perWin := perWin
    }
    SaveSetting("General", "ModeSwitching", perWin ? "PerWindow" : "Global")
    if IsObject(App.eng)
        App.eng.Reset()

    wasOn := App.fontOn
    SaveFontSettings(st)
    SaveManualSettings(st)
    SaveEncSettings(st)
    SaveExtraSettings(st)
    if (App.fontOn && !wasOn && !App.perWin) {        ; the Fonts feature was just switched on: this window and mode become the starting point
        if IsBindable(st.prev)
            App.curWin := st.prev
        if (App.curWin && IsFontApp(App.curWin))
            App.winModes[App.curWin] := App.cur
        else
            App.globMode := App.cur
    }
    if !App.fontOn
        App.fontCom := Map()

    App.shortcuts := newMap
    for id, hk in newMap
        SaveSetting("Shortcuts", IniKey(id), (hk = "") ? "none" : hk)

    newShown := Map()
    for r in st.rows
        newShown[r.id] := IsObject(r.cb) ? (r.cb.Value = 1) : true
    App.shown := newShown
    for id, v in newShown
        SaveSetting("Shown", IniKey(id), v ? 1 : 0)
    if ((st.cbAvro.Value = 1) != App.avroOn)
        ApplyAvroSetting(st.cbAvro.Value = 1)         ; Avro Phonetic added to / removed from the layout list
    FixLastBn()
    BuildTrayMenu()
    if (App.cur > 0 && !IsShown("L:" . App.layouts[App.cur].name))
        SetLayout(0)                                  ; the layout in use was just hidden

    st.saved := true
    DlgClose(st)
    RefreshUI()
    if App.fontOn
        FontKick(300)                                 ; the window gets focus back first, then the font is checked
}

; ---------------------------------------------------------------------------
;  Fonts: automatic font change in Office apps (Settings > Fonts)
;  Nothing runs in the background. The font is checked only when you switch layout, switch to an Office window,
;  start typing after a pause, or move the cursor - and only while one of these apps is the active window:
;  Word / Excel / PowerPoint, Outlook (mail editor), WPS Office (Writer / Spreadsheets / Presentation) and
;  LibreOffice / OpenOffice Writer. They are driven through COM (LibreOffice through its UNO bridge);
;  the font is never changed while text is selected.
; ---------------------------------------------------------------------------
LoadFonts() {
    App.fontOn := (IniRead(App.ini, "Fonts", "Enabled", "0") = "1")
    App.fonts := Map()
    keys := []
    for L in App.layouts
        keys.Push(L.name)
    keys.Push("English")
    for k in keys {
        isEng := (k = "English")
        sz := IniRead(App.ini, "Fonts", k . ".Size", "0")
        App.fonts[k] := {on: (IniRead(App.ini, "Fonts", k . ".On", isEng ? "1" : "0") = "1")
            , font: IniRead(App.ini, "Fonts", k . ".Font", isEng ? "Arial" : "")
            , size: (IsInteger(sz) && sz >= 4 && sz <= 400) ? Integer(sz) : 0
            , keep: IniRead(App.ini, "Fonts", k . ".Keep", "")}      ; Keep = extra fonts to leave alone, e.g. Keep=SolaimanLipi, Nikosh
    }
}

ValidateFonts(st) {
    for r in st.frows {
        if (r.cb.Value != 1)
            continue
        if (Trim(r.font.Text) = "")
            return "Pick a font for " . r.key . ", or untick it."
        sz := Trim(r.size.Text)
        if (sz != "" && sz != "Auto" && !(IsInteger(sz) && sz >= 4 && sz <= 400))
            return "The size for " . r.key . " must be Auto or a number from 4 to 400."
    }
    return ""
}

SaveFontSettings(st) {
    App.fontOn := (st.cbFont.Value = 1)
    SaveSetting("Fonts", "Enabled", App.fontOn ? 1 : 0)
    for r in st.frows {
        sz := Trim(r.size.Text)
        c := App.fonts[r.key]
        c.on := (r.cb.Value = 1)
        c.font := Trim(r.font.Text)
        c.size := IsInteger(sz) ? Integer(sz) : 0
        SaveSetting("Fonts", r.key . ".On", c.on ? 1 : 0)
        SaveSetting("Fonts", r.key . ".Font", c.font)
        SaveSetting("Fonts", r.key . ".Size", c.size)
    }
}

SyncFontRows(st, *) {
    all := (st.cbFont.Value = 1)
    for r in st.frows {
        r.cb.Enabled := all
        e := all && r.cb.Value = 1
        r.font.Enabled := e
        r.size.Enabled := e
    }
}

; ---- encodings: shortcut keys (Settings > Multi Encoding) -------------------------
LoadEncKeys() {
    App.encOn := (IniRead(App.ini, "Encodings", "Enabled", "1") != "0")
    App.encKeys := Map()
    for nm in EncChoices()
        App.encKeys[nm] := IniRead(App.ini, "EncodingKeys", IniKey(nm), "")
}

LoadEncRow(row, hk) {
    row.win.Value := InStr(hk, "#") ? 1 : 0
    row.hk.Value := ""
    p := SplitHk(hk)
    if (p.key != "")
        row.hk.Value := StrReplace(p.mods, "#", "") . p.key
}

; the I button of an encoding: reads the "Metadata" of its Library file (.menc or .json) and shows it in a small window
EncInfo(st, nm, *) {
    meta := ""
    err := ""
    fname := ""
    if (nm = "Unicode") {
        meta := Map("Encoding", "Unicode", "Type", "No conversion", "Note", "The text you type stays Unicode.")
    } else {
        path := EncPath(nm)
        if (path = "") {
            err := "The file of this encoding was not found in the Library folder."
        } else {
            SplitPath(path, &fname, , &fext)
            try {
                txt := (StrLower(fext) = "menc") ? MencDecode(FileRead(path, "RAW")) : FileRead(path, "UTF-8")
                d := EncJson.Parse(txt)
                if (d is Map && d.Has("Metadata") && d["Metadata"] is Map)
                    meta := d["Metadata"]
            } catch as e {
                err := "This file could not be read:`n" . e.Message
            }
        }
    }
    try st.info.Destroy()
    ig := Gui("+AlwaysOnTop +Owner" . st.g.Hwnd . " -MinimizeBox -MaximizeBox", "Encoding Info - " . nm)
    ig.SetFont("s9", "Segoe UI")
    ig.MarginX := 16
    ig.MarginY := 14
    st.info := ig
    rows := []
    if (meta is Map) {
        for k in ["Encoding", "Type", "Version", "Company", "Developer", "Modified By", "Suggested Font"] {
            if meta.Has(k)
                rows.Push(k)
        }
        for k, v in meta {                                  ; any other entries of the file, after the usual ones
            known := false
            for u in rows {
                if (u = k)
                    known := true
            }
            if !known
                rows.Push(k)
        }
    }
    first := true
    for k in rows {
        v := meta[k]
        if (v is Map || v is Array)
            continue
        ig.Add("Text", "x16 y" . (first ? "14" : "+8") . " w110 c606060", StrReplace(k, "&", "&&"))
        ig.Add("Text", "x130 yp w290", StrReplace(String(v), "&", "&&"))
        first := false
    }
    if (err != "") {
        ig.Add("Text", "x16 y" . (first ? "14" : "+8") . " w404", err)
        first := false
    } else if first {
        ig.Add("Text", "x16 y14 w404", "This encoding file has no Metadata.")
    }
    ig.Add("Button", "x340 y+18 w80 h26 Default", "Close").OnEvent("Click", (*) => ig.Destroy())
    ig.OnEvent("Escape", (*) => ig.Destroy())
    ig.OnEvent("Close", (*) => ig.Destroy())
    ig.Show("AutoSize")
}

ClearEncRow(row, *) {
    row.hk.Value := ""
    row.win.Value := 0
}

EncRowKey(r) {
    return (r.hk.Value = "") ? "" : (r.win.Value = 1 ? "#" : "") . r.hk.Value
}

; the rows are greyed out while Multi encoding is unticked
SyncEncRows(st, *) {
    on := (st.cbEnc.Value = 1)
    for r in st.erows {
        r.hk.Enabled := on
        r.win.Enabled := on
        r.clr.Enabled := on
    }
}

ResetEncPage(st) {
    st.cbEnc.Value := 1
    for r in st.erows
        ClearEncRow(r)
    SyncEncRows(st)
}

SaveEncSettings(st) {
    App.encOn := (st.cbEnc.Value = 1)
    SaveSetting("Encodings", "Enabled", App.encOn ? 1 : 0)
    App.encKeys := Map()
    for r in st.erows {
        k := EncRowKey(r)
        App.encKeys[r.id] := k
        SaveSetting("EncodingKeys", IniKey(r.id), k)
    }
}

; returns "" when fine, otherwise a message for the person
ValidateEnc(st, keys) {
    if (st.cbEnc.Value != 1)
        return ""
    seen := Map()
    for r in st.rows {
        if (IsObject(r.cb) && r.cb.Value = 0)
            continue
        hk := keys[r.id]
        if (hk != "")
            seen[StrLower(PrettyHk(hk))] := r.label
    }
    if (st.cbManual.Value = 1) {
        for i, r in st.slots {
            if (r.hk.Value != "")
                seen[StrLower(PrettyHk((r.win.Value = 1 ? "#" : "") . r.hk.Value))] := "Font shortcut " . i
        }
    }
    for r in st.erows {
        hk := EncRowKey(r)
        if (hk = "")
            continue
        label := "Encoding " . r.id
        p := SplitHk(hk)
        if (!InStr(p.mods, "^") && !InStr(p.mods, "!") && !InStr(p.mods, "#")) {
            if !RegExMatch(p.key, "i)^(F\d+|Insert|AppsKey|PrintScreen)$")
                return label . ": " . PrettyHk(hk) . " would also be typed as a normal key.`nAdd Ctrl, Alt or Win, or use an F-key."
        }
        k := StrLower(PrettyHk(hk))
        if seen.Has(k)
            return "The shortcut " . PrettyHk(hk) . " is used twice:`n" . seen[k] . "  and  " . label
        seen[k] := label
    }
    return ""
}

; the shortcut of an encoding was pressed: switch to it (works in any layout, the conversion itself only runs in Unicode layouts)
EncHotkey(nm, *) {
    name := (nm = "Unicode") ? "" : nm
    if (name != "" && EncPath(name) = "")
        return
    SetEncoding(name)
    ToolTip("Encoding: " . nm)
    SetTimer(EncTipOff, -1200)
}

EncTipOff() {
    ToolTip()
}

; ---- manual font shortcuts (Settings > Fonts) --------------------------------
FontSlotCount() {
    return 10
}

LoadManualFonts() {
    App.manualOn := (IniRead(App.ini, "FontShortcuts", "Enabled", "0") = "1")
    App.slots := []
    Loop FontSlotCount() {
        n := "Slot" . A_Index
        sz := IniRead(App.ini, "FontShortcuts", n . ".Size", "0")
        App.slots.Push({key: IniRead(App.ini, "FontShortcuts", n . ".Key", "")
            , font: IniRead(App.ini, "FontShortcuts", n . ".Font", "")
            , size: (IsInteger(sz) && sz >= 4 && sz <= 400) ? Integer(sz) : 0})
    }
}

SaveManualSettings(st) {
    App.manualOn := (st.cbManual.Value = 1)
    SaveSetting("FontShortcuts", "Enabled", App.manualOn ? 1 : 0)
    for i, r in st.slots {
        sl := App.slots[i]
        sz := Trim(r.size.Text)
        sl.key := (r.hk.Value = "") ? "" : (r.win.Value = 1 ? "#" : "") . r.hk.Value
        sl.font := Trim(r.font.Text)
        sl.size := IsInteger(sz) ? Integer(sz) : 0
        SaveSetting("FontShortcuts", "Slot" . i . ".Key", sl.key)
        SaveSetting("FontShortcuts", "Slot" . i . ".Font", sl.font)
        SaveSetting("FontShortcuts", "Slot" . i . ".Size", sl.size)
    }
}

; returns "" when fine, otherwise a message for the person
ValidateManual(st, keys) {
    if (st.cbManual.Value != 1)
        return ""
    seen := Map()
    for r in st.rows {
        if (IsObject(r.cb) && r.cb.Value = 0)
            continue
        hk := keys[r.id]
        if (hk != "")
            seen[StrLower(PrettyHk(hk))] := r.label
    }
    for i, r in st.slots {
        label := "Font shortcut " . i
        fnt := Trim(r.font.Text)
        if (r.hk.Value = "") {
            if (fnt != "")
                return label . ": press a key in the shortcut box, or clear the font."
            continue
        }
        if (fnt = "")
            return label . ": pick a font, or clear the shortcut."
        sz := Trim(r.size.Text)
        if (sz != "" && sz != "Auto" && !(IsInteger(sz) && sz >= 4 && sz <= 400))
            return label . ": the size must be Auto or a number from 4 to 400."
        hk := (r.win.Value = 1 ? "#" : "") . r.hk.Value
        p := SplitHk(hk)
        if (!InStr(p.mods, "^") && !InStr(p.mods, "!") && !InStr(p.mods, "#")) {
            if !RegExMatch(p.key, "i)^(F\d+|Insert|AppsKey|PrintScreen)$")
                return label . ": " . PrettyHk(hk) . " would also be typed as a normal key.`nAdd Ctrl, Alt or Win, or use an F-key."
        }
        k := StrLower(PrettyHk(hk))
        if seen.Has(k)
            return "The shortcut " . PrettyHk(hk) . " is used twice:`n" . seen[k] . "  and  " . label
        seen[k] := label
    }
    return ""
}

LoadSlotRow(row, sl) {
    row.win.Value := InStr(sl.key, "#") ? 1 : 0
    row.hk.Value := ""
    p := SplitHk(sl.key)
    if (p.key != "")
        row.hk.Value := StrReplace(p.mods, "#", "") . p.key
    row.font.Text := sl.font
    row.size.Text := sl.size ? sl.size : "Auto"
}

SyncSlotRows(st, *) {
    on := (st.cbManual.Value = 1)
    for r in st.slots {
        r.hk.Enabled := on
        r.win.Enabled := on
        r.font.Enabled := on
        r.size.Enabled := on
    }
}

; The shortcut of a slot was pressed: put that font on the cursor / selection of the active Office window.
; Works whether or not the automatic font change is on.
FontManual(i, *) {
    sl := App.slots[i]
    if (sl.font = "")
        return
    hwnd := WinExist("A")
    if !hwnd
        return
    try p := StrLower(WinGetProcessName("ahk_id " . hwnd))
    catch
        return
    apps := FontApps()
    if !apps.Has(p)
        return
    ctx := {font: sl.font, size: sl.size, uni: FontHasBengali(sl.font)}
    done := false
    for pair in apps[p] {
        Loop 2 {                                         ; 2nd try = fresh connection
            try {
                office := FontCom(pair[1], A_Index = 2)
                if RegExMatch(pair[1], "i)^(Word|KWPS)\.")
                    done := FontSetWord(office, ctx)
                else if RegExMatch(pair[1], "i)^(Excel|KET)\.")
                    done := FontSetExcel(office, ctx)
                else if RegExMatch(pair[1], "i)^Outlook\.")
                    done := FontSetOutlook(office, ctx)
                else if RegExMatch(pair[1], "i)^com\.sun\.star\.")
                    done := FontSetLO(office, ctx)
                else
                    done := FontSetPpt(office, ctx)
                break
            } catch {
                if App.fontCom.Has(pair[1])
                    App.fontCom.Delete(pair[1])
            }
        }
        if done
            break
    }
    if done
        App.manualHold := hwnd
    if !App.fontOn
        App.fontCom := Map()                             ; nothing else needs the Office connection
}

FontSetWord(office, ctx) {
    f := office.Selection.Font
    f.Name := ctx.font
    try f.NameAscii := ctx.font
    try f.NameOther := ctx.font
    if ctx.uni
        try f.NameBi := ctx.font
    if ctx.size {
        f.Size := ctx.size
        if ctx.uni
            try f.SizeBi := ctx.size
    }
    return true
}

FontSetExcel(office, ctx) {
    f := office.Selection.Font
    f.Name := ctx.font
    if ctx.size
        f.Size := ctx.size
    return true
}

FontSetPpt(office, ctx) {
    sel := office.ActiveWindow.Selection
    if (sel.Type = 3)
        f := sel.TextRange.Font
    else if (sel.Type = 2)
        f := sel.ShapeRange.TextFrame.TextRange.Font
    else
        return false
    f.Name := ctx.font
    try f.NameAscii := ctx.font
    try f.NameOther := ctx.font
    if ctx.uni
        try f.NameComplexScript := ctx.font
    if ctx.size
        f.Size := ctx.size
    return true
}

; every installed font family (only built while the Settings window opens)
InstalledFonts() {
    seen := Map()
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    lf := Buffer(92, 0)                                 ; LOGFONTW
    NumPut("UChar", 1, lf, 23)                          ; DEFAULT_CHARSET = all families
    cb := CallbackCreate(FontEnumProc, , 4)
    try DllCall("gdi32\EnumFontFamiliesExW", "Ptr", hdc, "Ptr", lf, "Ptr", cb, "Ptr", ObjPtr(seen), "UInt", 0)
    CallbackFree(cb)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    s := ""
    for n in seen
        s .= n . "`n"
    return StrSplit(Sort(RTrim(s, "`n"), "U"), "`n")
}

FontEnumProc(lpelfe, lpntme, fontType, lParam) {
    seen := ObjFromPtrAddRef(lParam)
    n := StrGet(lpelfe + 28, 32, "UTF-16")              ; LOGFONTW.lfFaceName
    if (n != "" && SubStr(n, 1, 1) != "@")
        seen[n] := 1
    return 1
}

; does this font contain Bengali letters? (tests the letter KA) - tells Unicode fonts from ANSI ones
FontHasBengali(name) {
    static cache := Map()
    if cache.Has(name)
        return cache[name]
    ok := false
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    hf := DllCall("gdi32\CreateFontW", "Int", -16, "Int", 0, "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0
        , "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 4, "UInt", 0, "WStr", name, "Ptr")
    if hf {
        old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hf, "Ptr")
        ch := Buffer(2, 0)
        NumPut("UShort", 0x0995, ch)
        gi := Buffer(2, 0)
        r := DllCall("gdi32\GetGlyphIndicesW", "Ptr", hdc, "Ptr", ch, "Int", 1, "Ptr", gi, "UInt", 1, "UInt")   ; 1 = mark missing glyphs
        ok := (r = 1 && NumGet(gi, 0, "UShort") != 0xFFFF)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
        DllCall("DeleteObject", "Ptr", hf)
    }
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    cache[name] := ok
    return ok
}

; a layout whose keys type Bengali letters is a Unicode layout; otherwise it is an ANSI (Bijoy Classic style) layout
LayoutIsUnicode(L) {
    static cache := Map()
    if (L.kind = "avro")
        return true
    if cache.Has(L.name)
        return cache[L.name]
    uni := false
    for m in [L.nor, L.sh] {
        for vk, t in m {
            if RegExMatch(t, "[\x{0980}-\x{09FF}]") {
                uni := true
                break
            }
        }
        if uni
            break
    }
    cache[L.name] := uni
    return uni
}

; process name -> [COM name, handler] list
FontApps() {
    static m := Map(
        "winword.exe", [["Word.Application", FontDoWord]],
        "excel.exe", [["Excel.Application", FontDoExcel]],
        "powerpnt.exe", [["PowerPoint.Application", FontDoPpt]],
        "outlook.exe", [["Outlook.Application", FontDoOutlook]],
        "wps.exe", [["KWPS.Application", FontDoWord], ["KET.Application", FontDoExcel], ["KWPP.Application", FontDoPpt]],
        "et.exe", [["KET.Application", FontDoExcel]],
        "wpp.exe", [["KWPP.Application", FontDoPpt]],
        "soffice.bin", [["com.sun.star.ServiceManager", FontDoLO]],
        "soffice.exe", [["com.sun.star.ServiceManager", FontDoLO]])
    return m
}

IsFontApp(hwnd) {
    if (!App.fontOn || !hwnd)
        return false
    try p := StrLower(WinGetProcessName("ahk_id " . hwnd))
    catch
        return false
    return FontApps().Has(p)
}

FontKick(ms := 80) {
    App.fontDirty := true
    SetTimer(FontApply, -ms)
}

FontApply(*) {
    Critical "On"
    App.fontDirty := false
    try FontApplyNow()                                   ; never let a font problem interrupt typing or show an error box
}

FontApplyNow() {
    if !App.fontOn
        return
    hwnd := WinExist("A")
    if !IsFontApp(hwnd)
        return
    if (hwnd = App.manualHold)                           ; a manual font shortcut was used here: keep that font
        return
    isEng := (App.cur = 0)
    cfg := App.fonts.Get(isEng ? "English" : App.layouts[App.cur].name, "")
    if (!IsObject(cfg) || !cfg.on)
        return
    key := isEng ? "English" : App.layouts[App.cur].name
    encL := isEng ? "" : ActiveEnc()
    if IsObject(encL) {                                  ; typing Unicode that is converted to ANSI: the ANSI font of the encoding is the right one
        key .= "|" . App.encName
        if (encL.font != "")
            cfg := {on: cfg.on, font: encL.font, size: cfg.size, keep: cfg.keep}
    }
    fnt := isEng ? cfg.font : App.userFont.Get(hwnd . "|" . key, cfg.font)      ; the font you were using here before wins over the default
    ctx := {cfg: cfg, eng: isEng, uni: (!isEng && !IsObject(encL) && LayoutIsUnicode(App.layouts[App.cur])), hwnd: hwnd, key: key
        , font: fnt, size: (fnt = cfg.font) ? cfg.size : 0}
    for pair in FontApps()[StrLower(WinGetProcessName("ahk_id " . hwnd))] {
        done := false
        Loop 2 {                                         ; 2nd try = fresh connection (the old one may be stale)
            try {
                office := FontCom(pair[1], A_Index = 2)
                done := pair[2](office, ctx)
                break
            } catch {
                if App.fontCom.Has(pair[1])
                    App.fontCom.Delete(pair[1])
            }
        }
        if done
            break
    }
}

FontCom(progid, fresh := false) {
    if (!fresh && App.fontCom.Has(progid))
        return App.fontCom[progid]
    o := RegExMatch(progid, "i)^com\.sun\.star\.") ? ComObject(progid) : ComObjActive(progid)     ; LibreOffice / OpenOffice: through the UNO bridge
    App.fontCom[progid] := o
    return o
}

FontAccepted(cur, ctx) {
    for f in StrSplit(ctx.cfg.keep, ",", " ") {
        if (f != "" && f = cur)
            return true
    }
    if ctx.eng
        return !RegExMatch(cur, "i)MJ$") && !App.ansiSeen.Has(cur)      ; English: anything except an ANSI font
    if ctx.uni
        return FontHasBengali(cur)                       ; Unicode: any font that has Bengali letters
    return RegExMatch(cur, "i)MJ$") ? true : false       ; ANSI: SutonnyMJ, SutonnyOMJ ...
}

; Is a font change needed? A font you picked yourself is left alone:
; it is only replaced when it is the document's default font (nothing chosen yet), or one this program set itself.
FontNeedsChange(ctx, cur, defFn) {
    cur := Trim(cur)
    if (cur != "" && (cur = ctx.font || FontAccepted(cur, ctx)))
        return FontKeep(ctx, cur)
    if (cur != "" && !ctx.eng && !FontIsOurs(cur) && !(!ctx.uni && FontHasBengali(cur))) {
        def := ""
        try def := Trim(defFn())
        if (cur != def && SubStr(cur, 1, 1) != "+")
            return FontKeep(ctx, cur)
    }
    return true
}

; remember what is in use for this layout in this window; returns false = nothing to change
FontKeep(ctx, cur) {
    if !ctx.eng {
        if (App.userFont.Count > 300)
            App.userFont := Map()
        App.userFont[ctx.hwnd . "|" . ctx.key] := cur
        if !ctx.uni
            App.ansiSeen[cur] := 1
    }
    return false
}

FontIsOurs(cur) {
    for k, c in App.fonts {
        if (c.on && c.font != "" && c.font = cur)
            return true
    }
    return false
}

FontDefWord(office, sel, ctx) {
    try {
        f := sel.Paragraphs.Item(1).Style.Font
        return ctx.uni ? f.NameBi : f.Name
    }
    f := office.ActiveDocument.Styles.Item(-1).Font
    return ctx.uni ? f.NameBi : f.Name
}

FontDefExcel(office) {
    return office.ActiveWorkbook.Styles.Item("Normal").Font.Name
}

FontDefPpt(office, ctx) {
    return office.ActivePresentation.SlideMaster.Theme.ThemeFontScheme.MinorFont.Item(ctx.uni ? 2 : 1).Name
}

; Word (and WPS Writer): only at a plain cursor, never over selected text.
; Bengali Unicode text uses Word's "complex script" font, ANSI text the normal one.
FontDoWord(office, ctx) {
    sel := office.Selection
    if (sel.Type != 1)                                   ; 1 = just a blinking cursor
        return false
    f := sel.Font
    if FontNeedsChange(ctx, ctx.uni ? f.NameBi : f.Name, () => FontDefWord(office, sel, ctx)) {
        n := ctx.font
        if ctx.uni {
            f.NameBi := n
            if ctx.size
                f.SizeBi := ctx.size
        } else {
            f.Name := n
            try f.NameAscii := n
            try f.NameOther := n
            if ctx.size
                f.Size := ctx.size
        }
    }
    return true
}

; Excel: only an empty single cell that is not being edited (existing cells are never reformatted)
FontDoExcel(office, ctx) {
    if (office.Selection.Cells.Count != 1)
        return false
    c := office.ActiveCell
    if (c.Value != "")
        return false
    f := c.Font
    if FontNeedsChange(ctx, f.Name, () => FontDefExcel(office)) {
        f.Name := ctx.font
        if ctx.size
            f.Size := ctx.size
    }
    return true
}

; PowerPoint: only at a plain cursor inside a text box
FontDoPpt(office, ctx) {
    sel := office.ActiveWindow.Selection
    if (sel.Type != 3)                                   ; 3 = text
        return false
    tr := sel.TextRange
    if (tr.Length != 0)
        return false
    f := tr.Font
    if FontNeedsChange(ctx, ctx.uni ? f.NameComplexScript : f.Name, () => FontDefPpt(office, ctx)) {
        n := ctx.font
        if ctx.uni {
            f.NameComplexScript := n
        } else {
            f.Name := n
            try f.NameAscii := n
            try f.NameOther := n
        }
        if ctx.size
            f.Size := ctx.size
    }
    return true
}

; Outlook: the mail editor is a Word document, so the Word handlers do the work (a message window, or an inline reply)
OutlookEditor(ol) {
    ed := ""
    try ed := ol.ActiveInspector.WordEditor
    if !IsObject(ed)
        try ed := ol.ActiveExplorer.ActiveInlineResponseWordEditor
    return IsObject(ed) ? ed.Application : ""
}

FontDoOutlook(ol, ctx) {
    wd := OutlookEditor(ol)
    if !IsObject(wd)
        return false
    return FontDoWord(wd, ctx)
}

FontSetOutlook(ol, ctx) {
    wd := OutlookEditor(ol)
    if !IsObject(wd)
        return false
    return FontSetWord(wd, ctx)
}

; LibreOffice / OpenOffice Writer: only at a plain cursor, never over selected text.
; Bengali Unicode text uses the "complex script" font of Writer, ANSI text the normal (Western) one.
FontDoLO(sm, ctx) {
    doc := sm.createInstance("com.sun.star.frame.Desktop").CurrentComponent
    if (!IsObject(doc) || !doc.supportsService("com.sun.star.text.TextDocument"))
        return false
    vc := doc.CurrentController.ViewCursor
    if !vc.isCollapsed()                                 ; text is selected: leave it
        return false
    cur := ctx.uni ? vc.CharFontNameComplex : vc.CharFontName
    if FontNeedsChange(ctx, cur, () => FontDefLO(doc, vc, ctx)) {
        if ctx.uni {
            vc.CharFontNameComplex := ctx.font
            if ctx.size
                vc.CharHeightComplex := ctx.size
        } else {
            vc.CharFontName := ctx.font
            if ctx.size
                vc.CharHeight := ctx.size
        }
    }
    return true
}

; the font of the paragraph style at the cursor (what "nothing chosen yet" means in Writer)
FontDefLO(doc, vc, ctx) {
    try {
        ps := doc.StyleFamilies.getByName("ParagraphStyles").getByName(vc.ParaStyleName)
        return ctx.uni ? ps.CharFontNameComplex : ps.CharFontName
    }
    return ""
}

; manual shortcut in Writer: the selection, or the cursor when nothing is selected
FontSetLO(sm, ctx) {
    doc := sm.createInstance("com.sun.star.frame.Desktop").CurrentComponent
    if (!IsObject(doc) || !doc.supportsService("com.sun.star.text.TextDocument"))
        return false
    vc := doc.CurrentController.ViewCursor
    if ctx.uni {
        vc.CharFontNameComplex := ctx.font
        if ctx.size
            vc.CharHeightComplex := ctx.size
    } else {
        vc.CharFontName := ctx.font
        if ctx.size
            vc.CharHeight := ctx.size
    }
    return true
}

; ---------------------------------------------------------------------------
;  Start
; ---------------------------------------------------------------------------
ReadyTip() {
    s := ""
    for a in ActionList() {
        hk := App.shortcuts.Get(a.id, "")
        if (hk != "" && (SubStr(a.id, 1, 2) = "L:" || a.id = "English"))
            s .= a.label . " = " . PrettyHk(hk) . ",  "
    }
    return (s = "") ? "Ready." : "Ready.  " . RTrim(s, ", ")
}

; ---------------------------------------------------------------------------
;  Splash screen: shows one random picture for a few seconds, taken from the Splash folder
;    Splash\   - .png / .jpg / .jpeg / .bmp (no animated GIFs, no sub-folders)
;  If the folder is empty or missing, no splash is shown. Turn it off in Settings.
; ---------------------------------------------------------------------------
SplashImages() {
    list := []
    d := App.dir . "\Splash"
    if !DirExist(d)                                                                  ; a missing folder is simply skipped
        return list
    Loop Files d . "\*.*" {
        if RegExMatch(A_LoopFileExt, "i)^(png|jpg|jpeg|bmp)$")
            list.Push(A_LoopFileFullPath)
    }
    return list
}

; one random picture from the folder (never the same one twice in a row when there are several)
PickSplash() {
    list := SplashImages()
    if (list.Length = 0)
        return ""
    if (list.Length = 1)
        return list[1]
    last := IniRead(App.ini, "General", "LastSplash", "")
    pool := []
    for p in list {
        if (p != last)
            pool.Push(p)                                  ; everything except the picture shown last time
    }
    f := pool[Random(1, pool.Length)]
    SaveSetting("General", "LastSplash", f)
    return f
}

; very large picture: shrink to 80% of the screen at most
FitSize(&w, &h) {
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
    k := Min(1, (r - l) * 0.8 / w, (b - t) * 0.8 / h)
    if (k < 1) {
        w := Max(1, Round(w * k))
        h := Max(1, Round(h * k))
    }
}

SplashStatic(f) {
    g := ""
    try {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border -DPIScale")      ; plain pixels
        g.MarginX := 0
        g.MarginY := 0
        pic := g.Add("Picture", "x0 y0", f)
        pic.GetPos(, , &w, &h)
        ow := w
        oh := h
        FitSize(&w, &h)
        if (w != ow || h != oh)
            pic.Move(0, 0, w, h)
        g.Show("NoActivate Center w" . w . " h" . h)
        return g
    } catch {
        if IsObject(g)
            try g.Destroy()
        return ""
    }
}

ShowSplash() {
    if !App.splashOn
        return
    f := PickSplash()
    if (f = "")
        return
    g := SplashStatic(f)
    if !IsObject(g)
        return
    App.splash := g
    SetTimer(CloseSplash, -App.splashMs)
}

CloseSplash(*) {
    try App.splash.Destroy()
    App.splash := ""
}

; ===========================================================================
;  Bangla Snippet - text expander engine
;  Type a saved title, then the trigger (== by default). The title and the trigger are replaced by the saved text.
;  Snippets: %AppData%\Bangla Keyboard\Bangla Keyboard Snippets\Bangla Snippet Data.dat  (edited with Tools\Bangla Snippet.ahk)
;    one line per snippet:  title <TAB> content   (\\ \n \r \t are escapes, so content can hold line breaks)
;    an optional third column  <TAB> comment  is a note kept by Bangla Snippet; it is ignored here
;  Options live in Bangla Keyboard.dat, section [Snippets] (Settings > Bangla Snippet): Enabled, Trigger, CaseSensitive, WordBoundary, Clipboard, Macros
;  When Bangla Snippet is switched off nothing of this runs: no key watcher, no timer, no snippets in memory.
;  Snippets are loaded into memory only while it is on; the data file's timestamp is only checked when a trigger has just been typed.
; ===========================================================================
; the character a key types (for keys a Bangla layout lets through as normal)
KeyChar(vk, shifted) {
    if !Snip.enabled                                           ; Bangla Snippet is off: nothing is looked up
        return ""
    st := Buffer(256, 0)
    if shifted
        NumPut("UChar", 0x80, st, 0x10)
    sc := DllCall("MapVirtualKey", "UInt", vk, "UInt", 0, "UInt")
    out := Buffer(32, 0)
    n := DllCall("ToUnicode", "UInt", vk, "UInt", sc, "Ptr", st, "Ptr", out, "Int", 8, "UInt", 4, "Int")
    return (n > 0) ? StrGet(out, n, "UTF-16") : ""
}

class Snip {
    static dir := A_AppData "\Bangla Keyboard\Bangla Keyboard Snippets"
    static file := A_AppData "\Bangla Keyboard\Bangla Keyboard Snippets\Bangla Snippet Data.dat"
    ; options (read from the [Snippets] section of Bangla Keyboard.dat; changed in Settings > Bangla Snippet)
    static enabled := false         ; false = the expander does not run at all
    static trigger := "=="
    static cs := false              ; case-sensitive titles
    static wb := false              ; the title must start at a word boundary
    static clip := false            ; paste through the clipboard (long snippets)
    static macros := true           ; {date} {time} {clipboard} {cursor} ...
    ; data (only held in memory while the expander is on)
    static raw := []                ; [{title, text}] as saved
    static map := Map()             ; title (lower-cased unless case-sensitive) -> text
    static maxLen := 0
    static stamp := ""              ; modified time of the data file when it was loaded
    ; typing record (only exists while the expander is on)
    static buf := ""
    static busy := false            ; true while we type an expansion (our own keys are ignored)
    static ih := ""                 ; the key watcher
    static tickFn := ""             ; the 0.5 second check
    static lastWin := 0
    static lastClick := false

    static Start() {
        Snip.LoadSettings()
        Snip.Apply()
    }

    ; Settings was saved: read the options again and start / stop the expander accordingly
    static Reload() {
        Snip.LoadSettings()
        Snip.Apply()
    }

    static Apply() {
        if Snip.enabled
            Snip.On()
        else
            Snip.Off()
    }

    ; switch on: load the snippets, start the key watcher and the check timer
    static On() {
        if IsObject(Snip.ih) {                                 ; already running: only the options may have changed
            Snip.BuildMap()
            return
        }
        try DirCreate(Snip.dir)
        Snip.Load()
        ih := InputHook("V")                                   ; V = only watch the keys, never block them
        ih.OnChar := Snip.OnChar.Bind(Snip)
        ih.OnKeyDown := Snip.OnKey.Bind(Snip)
        ih.KeyOpt("{Backspace}", "N")
        ih.KeyOpt("{Enter}{NumpadEnter}{Esc}{Tab}{Delete}{Left}{Right}{Up}{Down}{Home}{End}{PgUp}{PgDn}", "N")
        ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LWin}{RWin}", "N")
        Snip.ih := ih
        Snip.buf := ""
        Snip.lastWin := 0
        Snip.lastClick := false
        ih.Start()
        Snip.tickFn := Snip.Tick.Bind(Snip)
        SetTimer(Snip.tickFn, 500)                             ; mouse click / window switch
    }

    ; switch off: nothing runs any more and the snippets are let go of
    static Off() {
        if IsObject(Snip.tickFn) {
            SetTimer(Snip.tickFn, 0)
            Snip.tickFn := ""
        }
        if IsObject(Snip.ih) {
            try Snip.ih.Stop()
            Snip.ih := ""
        }
        Snip.buf := ""
        Snip.raw := []
        Snip.map := Map()
        Snip.maxLen := 0
        Snip.stamp := ""
    }

    static LoadSettings() {
        Snip.enabled := (IniRead(App.ini, "Snippets", "Enabled", "1") != "0")
        t := IniRead(App.ini, "Snippets", "Trigger", "==")
        Snip.trigger := (t = "" || RegExMatch(t, "\s")) ? "==" : t
        Snip.cs := (IniRead(App.ini, "Snippets", "CaseSensitive", "0") = "1")
        Snip.wb := (IniRead(App.ini, "Snippets", "WordBoundary", "0") = "1")
        Snip.clip := (IniRead(App.ini, "Snippets", "Clipboard", "0") = "1")
        Snip.macros := (IniRead(App.ini, "Snippets", "Macros", "1") != "0")
    }

    static Unesc(s) {
        out := ""
        i := 1
        n := StrLen(s)
        while (i <= n) {
            c := SubStr(s, i, 1)
            if (c = "\" && i < n) {
                i++
                d := SubStr(s, i, 1)
                out .= (d = "n") ? "`n" : (d = "r") ? "`r" : (d = "t") ? "`t" : d
            } else
                out .= c
            i++
        }
        return out
    }

    static Load() {
        raw := []
        Snip.stamp := FileExist(Snip.file) ? FileGetTime(Snip.file, "M") : ""
        if (Snip.stamp != "") {
            try {
                txt := FileRead(Snip.file, "UTF-8")
                Loop Parse txt, "`n", "`r" {
                    p := InStr(A_LoopField, "`t")
                    if (p < 2)
                        continue
                    rest := SubStr(A_LoopField, p + 1)
                    q := InStr(rest, "`t")                     ; optional third column = the comment (a note for the user, never typed)
                    if q
                        rest := SubStr(rest, 1, q - 1)
                    raw.Push({title: Snip.Unesc(SubStr(A_LoopField, 1, p - 1)), text: Snip.Unesc(rest)})
                }
            }
        }
        Snip.raw := raw
        Snip.BuildMap()
    }

    ; title -> text lookup (the first of two equal titles wins)
    static BuildMap() {
        m := Map()
        mx := 0
        for it in Snip.raw {
            k := Snip.cs ? it.title : StrLower(it.title)
            if (k = "" || m.Has(k))
                continue
            m[k] := it.text
            mx := Max(mx, StrLen(k))
        }
        Snip.map := m
        Snip.maxLen := mx
    }

    ; runs twice a second, only while the expander is on (no disk access: the data file is checked in Sync)
    static Tick() {
        if (Snip.busy)
            return
        cl := GetKeyState("LButton", "P") || GetKeyState("RButton", "P")
        if (cl && !Snip.lastClick)
            Snip.buf := ""
        Snip.lastClick := cl
        w := WinExist("A")
        if (w != Snip.lastWin) {
            Snip.lastWin := w
            Snip.buf := ""
        }
    }

    ; reload the snippets when Bangla Snippet saved the data file since the last load
    static Sync() {
        st := FileExist(Snip.file) ? FileGetTime(Snip.file, "M") : ""
        if (st != Snip.stamp)
            Snip.Load()
    }

    ; English (no Bangla layout on): the keys come from a plain key watcher.
    ; While a Bangla layout / Avro is on, Bangla Keyboard tells us itself what it typed (Add / Edit / Back / Clear below),
    ; because the watcher cannot follow text that the layouts rewrite on screen.
    static OnKey(ih, vk, sc) {
        if (Snip.busy || App.cur > 0)
            return
        if (vk = 8)                                            ; Backspace
            Snip.buf := SubStr(Snip.buf, 1, -1)
        else
            Snip.buf := ""
    }

    static OnChar(ih, ch) {
        if (Snip.busy || App.cur > 0)
            return
        Snip.Add(ch)
    }

    ; text that was just typed
    static Add(str) {
        if (!Snip.enabled || Snip.busy || str = "")
            return
        Snip.buf .= str
        if (StrLen(Snip.buf) > 400)
            Snip.buf := SubStr(Snip.buf, -300)
        Snip.Check()
    }

    ; a Bangla layout changed the text on screen: delete bs characters at the end, then type str
    static Edit(bs, str) {
        if (!Snip.enabled || Snip.busy)
            return
        if (bs > 0)
            Snip.buf := SubStr(Snip.buf, 1, Max(0, StrLen(Snip.buf) - bs))
        Snip.Add(str)
    }

    static Back() {
        if (Snip.enabled && !Snip.busy)
            Snip.buf := SubStr(Snip.buf, 1, -1)
    }

    static Clear() {
        if (Snip.enabled && !Snip.busy)
            Snip.buf := ""
    }

    static Check() {
        tl := StrLen(Snip.trigger)
        if (StrLen(Snip.buf) < tl || SubStr(Snip.buf, -tl) != Snip.trigger)
            return
        Snip.Sync()                                            ; only now (a trigger was typed) is the data file looked at
        m := Snip.Match(SubStr(Snip.buf, 1, StrLen(Snip.buf) - tl))
        if IsObject(m)
            Snip.Expand(m.len + tl, m.text, SubStr(Snip.buf, StrLen(Snip.buf) - m.len - tl + 1))
        ; no match: the trigger stays exactly as typed
    }

    ; the longest saved title that ends the typed text
    static Match(head) {
        n := StrLen(head)
        L := Min(n, Snip.maxLen)
        while (L >= 1) {
            cand := SubStr(head, n - L + 1)
            key := Snip.cs ? cand : StrLower(cand)
            if Snip.map.Has(key) {
                if (!Snip.wb || L = n || !RegExMatch(SubStr(head, n - L, 1), "[\p{L}\p{M}\p{N}_]"))
                    return {len: L, text: Snip.map[key]}
            }
            L--
        }
        return ""
    }

    ; Bangla digits, names and parts of the day for the =bn macros, e.g. {date=bn}
    static BnDigits(s) {
        out := ""
        Loop Parse s
            out .= (p := InStr("0123456789", A_LoopField)) ? SubStr("০১২৩৪৫৬৭৮৯", p, 1) : A_LoopField
        return out
    }
    static BnMonth(m) => ["জানুয়ারি", "ফেব্রুয়ারি", "মার্চ", "এপ্রিল", "মে", "জুন", "জুলাই", "আগস্ট", "সেপ্টেম্বর", "অক্টোবর", "নভেম্বর", "ডিসেম্বর"][m]
    static BnDay(d) => ["রবিবার", "সোমবার", "মঙ্গলবার", "বুধবার", "বৃহস্পতিবার", "শুক্রবার", "শনিবার"][d]      ; 1 = Sunday
    static BnPeriod(h) => (h < 4) ? "রাত" : (h < 6) ? "ভোর" : (h < 12) ? "সকাল" : (h < 16) ? "দুপুর" : (h < 18) ? "বিকাল" : (h < 20) ? "সন্ধ্যা" : "রাত"

    ; one date / time macro; bn = true gives Bangla Unicode
    static DateValue(name, bn, now) {
        h := Integer(FormatTime(now, "H")), wd := Integer(FormatTime(now, "WDay")), mo := Integer(FormatTime(now, "M"))
        switch name {
            case "date":
                v := FormatTime(now, "dd/MM/yyyy")
            case "time24":
                v := FormatTime(now, "HH:mm")
            case "time":
                v := bn ? FormatTime(now, "hh:mm") " " Snip.BnPeriod(h) : FormatTime(now, "hh:mm tt")
            case "datetime":
                return Snip.DateValue("date", bn, now) " " Snip.DateValue("time", bn, now)
            case "longdate":
                v := bn ? Snip.BnDay(wd) ", " FormatTime(now, "d") " " Snip.BnMonth(mo) " " FormatTime(now, "yyyy")
                        : FormatTime(now, "dddd, d MMMM yyyy")
            case "day":
                v := bn ? Snip.BnDay(wd) : FormatTime(now, "dddd")
            case "month":
                v := bn ? Snip.BnMonth(mo) : FormatTime(now, "MMMM")
            case "year":
                v := FormatTime(now, "yyyy")
        }
        return bn ? Snip.BnDigits(v) : v
    }

    ; {date} {time} {time24} {datetime} {longdate} {day} {month} {year}, each also as  =bn  ({date=bn}) for Bangla
    static DateMacros(text) {
        now := A_Now
        out := "", pos := 1
        while RegExMatch(text, "i)\{(datetime|longdate|date|time24|time|day|month|year)(=bn)?\}", &m, pos) {
            out .= SubStr(text, pos, m.Pos - pos) Snip.DateValue(StrLower(m[1]), m[2] != "", now)
            pos := m.Pos + m.Len
        }
        return out SubStr(text, pos)
    }

    ; {date} {time} {time24} {datetime} {longdate} {day} {month} {year} (+ =bn), {clipboard} {cursor}: returns the text, and how many characters the cursor must go back
    static Macro(text, &back) {
        back := 0
        text := Snip.DateMacros(text)
        if InStr(text, "{clipboard}")                          ; the text you copied last
            text := StrReplace(text, "{clipboard}", StrReplace(A_Clipboard, "`r`n", "`n"))
        p := InStr(text, "{cursor}")
        if p {
            back := StrLen(StrReplace(SubStr(text, p + 8), "{cursor}"))
            text := StrReplace(text, "{cursor}")
        }
        return text
    }

    static Expand(nBack, text, typed := "") {
        Critical "On"
        Snip.busy := true
        Snip.buf := ""
        back := 0
        isUni := (RegExMatch(text, "[\x{0980}-\x{09FF}]") || InStr(text, "=bn}")) ? true : false      ; Bengali Unicode in the saved text: only that is converted
        if Snip.macros
            text := Snip.Macro(text, &back)
        enc := ActiveEnc()
        if IsObject(enc) {                                     ; an encoding is chosen: the screen holds ANSI, so delete its length and type the ANSI form
            if (typed != "")
                nBack := StrLen(enc.Conv(typed))
            if isUni
                text := enc.Conv(text)                         ; a snippet saved in ANSI (or plain English) is typed as it is
        }
        if IsObject(App.eng)
            App.eng.Reset()
        Send("{BS " nBack "}")
        if (Snip.clip) {
            old := ClipboardAll()
            A_Clipboard := RegExReplace(text, "\r?\n", "`r`n")
            if ClipWait(1) {
                Send("^v")
                Sleep(250)
            }
            A_Clipboard := old
        } else if (text != "")
            SendText(text)
        if (back > 0)
            Send("{Left " back "}")
        Critical "Off"
        Sleep(40)                                              ; let the keys we just sent pass by (ignored)
        Snip.buf := ""
        Snip.busy := false
    }
}

; ---- error log + watchdog -----------------------------------------------------------------
; Errors nobody caught: written to %AppData%\Bangla Keyboard\error.log instead of a dialog that could hide behind other
; windows. The part of the program that failed stops; typing goes on. (Critical errors end the program: see the Performance Helper.)
LogError(e, mode) {
    global bkCrashed
    if (mode = "ExitApp")
        bkCrashed := true                                      ; the program is about to end because of this: not a normal exit
    try {
        dir := A_AppData "\Bangla Keyboard"
        DirCreate(dir)
        file := dir "\error.log"
        if (FileExist(file) && FileGetSize(file) > 262144)     ; keep the log small: the old one becomes error.old.log
            FileMove(file, dir "\error.old.log", 1)
        msg := "", what := "", extra := "", line := "", stack := ""
        if IsObject(e) {
            try msg := e.Message
            try what := e.What
            try extra := e.Extra
            try line := e.Line
            try stack := e.Stack
        } else
            msg := String(e)
        text := FormatTime(, "yyyy-MM-dd HH:mm:ss") "  [" mode "]  " msg
        if (extra != "")
            text .= "  (" extra ")"
        text .= "`n    in " what "  (line " line ")  version " App.version "`n"
        if (stack != "")
            text .= "    " StrReplace(RTrim(stack, "`r`n"), "`n", "`n    ") "`n"
        FileAppend(text, file, "UTF-8")
    }
    return 1                                                   ; no error dialog; this thread ends
}

; A normal exit leaves its process id in clean-exit.flag, so the Performance Helper knows it must not start the program again.
MarkCleanExit(reason, code) {
    global bkCrashed
    if (reason = "Error" || (IsSet(bkCrashed) && bkCrashed))
        return 0
    try {
        f := A_AppData "\Bangla Keyboard\clean-exit.flag"
        try FileDelete(f)
        FileAppend(ProcessExist(), f)
    }
    return 0
}

; The Performance Helper (Performance Helper.ahk / .exe next to this program) waits for this program; if it stops without a
; normal exit, it starts it again. It uses almost no CPU while waiting. Settings > Extra Settings: start with the program, tray icon.
StartHelper() {
    if !App.helperOn
        return
    exe := App.dir . "\Performance Helper.exe"
    ahk := App.dir . "\Performance Helper.ahk"
    args := ProcessExist() . ' "' . (A_IsCompiled ? "-" : A_AhkPath) . '" "' . A_ScriptFullPath . '" ' . (App.helperTray ? 1 : 0)
    try {
        if FileExist(exe)
            Run('"' . exe . '" ' . args, App.dir)
        else if (FileExist(ahk) && FileExist(A_AhkPath))
            Run('"' . A_AhkPath . '" "' . ahk . '" ' . args, App.dir)
    }
}

; closes the running Performance Helper (found by its hidden window, so no other program can be hit by mistake)
StopHelper() {
    dhw := A_DetectHiddenWindows
    tmm := A_TitleMatchMode
    DetectHiddenWindows(true)
    SetTitleMatchMode(2)
    for p in [App.dir . "\Performance Helper.exe", App.dir . "\Performance Helper.ahk"] {
        try {
            h := WinExist(p . " ahk_class AutoHotkey")
            if h {
                pid := WinGetPID(h)
                WinClose(h, , 2)
                if WinExist("ahk_id " . h)
                    ProcessClose(pid)
            }
        }
    }
    DetectHiddenWindows(dhw)
    SetTitleMatchMode(tmm)
}

; Save in Settings > Extra Settings: a changed option restarts the helper right away (or stops it)
SaveExtraSettings(st) {
    on := (st.cbHelper.Value = 1)
    tray := (st.cbHelperTray.Value = 1)
    changed := (on != App.helperOn || tray != App.helperTray)
    App.helperOn := on
    App.helperTray := tray
    SaveSetting("Extra", "PerformanceHelper", on ? 1 : 0)
    SaveSetting("Extra", "PerformanceHelperTray", tray ? 1 : 0)
    if changed {
        StopHelper()
        StartHelper()                                          ; does nothing when it is switched off
    }
}

OnError(LogError)                 ; unhandled errors go to error.log
PrepareDataDir()
LoadSkins()
LoadSettings()
ShowSplash()                      ; first thing, so it appears at once; the rest loads behind it
LoadLayouts()
LoadEncoding(IniRead(App.ini, "General", "Encoding", ""))
LoadEncKeys()      ; Library folder (Unicode typing converted to ANSI)
LoadFonts()
LoadManualFonts()
LoadExtButtons()
LoadShortcuts()
LoadShown()
App.eng := Engine(App.layouts[1])
BuildTrayMenu()
RegisterTypingKeys()
ApplyShortcuts()
BuildBar()
if App.startMin
    App.bar.Hide()                ; start in the tray; double-click the tray icon to show the bar
SyncTray()                        ; bar visible = no tray icon, bar hidden = tray icon
InstallForegroundHook()
SetTimer(KeepOnTop, -250)         ; once; after that every window change re-raises the bar (OnForeground), no polling
if IsBindable(WinExist("A"))
    App.curWin := WinExist("A")
SetLayout(0)
Snip.Start()                      ; Bangla Snippet engine
OnExit(MarkCleanExit)              ; a normal exit tells the Performance Helper not to start the program again
StartHelper()
if (IniRead(App.ini, "General", "ReadyNotice", "0") = "1")      ; the "Ready ..." notification is off by default
    TrayTip(ReadyTip(), "Bangla Keyboard")
