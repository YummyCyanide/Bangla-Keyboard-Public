; ===========================================================================
;  Bangla Snippet - manager for the text expander of Bangla Keyboard
;  Add, edit, remove, find, export and import snippets.
;  Keep this file in the Tools folder of Bangla Keyboard. Bangla Keyboard reads the saved data itself,
;  and picks up every change the next time a snippet is typed.
;  Data:    %AppData%\Bangla Keyboard\Bangla Keyboard Snippets\Bangla Snippet Data.dat   (UTF-8, one snippet per line: title, content and an optional comment, separated by tabs)
;  The expander's options (on/off, trigger ...) are in Bangla Keyboard > Settings > Bangla Snippet.
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines(false)                  ; no line history: less memory and CPU
SetTimer(TrimMemory, -3000)         ; once, shortly after start: hand unused memory back to Windows

global Ver := "1.7"
global Dir := A_AppData "\Bangla Keyboard\Bangla Keyboard Snippets"
global DataFile := Dir "\Bangla Snippet Data.dat"
global IniFile := A_AppData "\Bangla Keyboard\Bangla Keyboard.dat"
global Items := []                      ; [{id, title, text, comment}]
global NextId := 1
global G, LV, SB, EdFind, DdFilter, HdrH := 0, HdrCols := [], HdrFill := ""
global UndoStack := []                  ; deleted entries, newest batch last: [[{i, it}, ...], ...]
global EG := "", SG := "", AG := "", CG := "", HG := "", HTab := "", CmG := ""
global ConflictMode := ""
global TipMap := Map(), TipLast := 0, SearchX := 0, LvY := 50
global LinkCtls := Map()

; ---- look of this tool (Settings: theme, list text size ...) --------------------------
; Stored in Bangla Keyboard.dat, section [SnippetTool]. A change is applied by restarting this tool.
global ThemeList := ["Light", "Dark"]
global TextList := ["Small", "Normal", "Big", "Extra big"]
Idx(list, v, def := 1) {
    for i, n in list {
        if (n = v)
            return i
    }
    return def                                                             ; unknown value: the default (Light / Normal)
}
global UiTheme := ThemeList[Idx(ThemeList, IniRead(IniFile, "SnippetTool", "Theme", "Light"))]
global UiText := TextList[Idx(TextList, IniRead(IniFile, "SnippetTool", "TextSize", "Normal"), 2)]
global UiTips := (IniRead(IniFile, "SnippetTool", "ShowTips", "1") != "0")
global UiTop := (IniRead(IniFile, "SnippetTool", "OnTop", "0") = "1")
global SortCol := Integer(IniRead(IniFile, "SnippetTool", "SortCol", "0"))             ; 0 = file order, 1 = Title, 2 = Content, 3 = Comments
global SortDesc := (IniRead(IniFile, "SnippetTool", "SortDesc", "0") = "1")
if (SortCol < 0 || SortCol > 3)
    SortCol := 0

; dark theme: let Windows draw the list heading (Title / Content) and the menus in their dark look
if (UiTheme = "Dark") {
    try {
        um := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        DllCall(DllCall("GetProcAddress", "Ptr", um, "Ptr", 135, "Ptr"), "Int", 2)      ; SetPreferredAppMode: force dark
        DllCall(DllCall("GetProcAddress", "Ptr", um, "Ptr", 136, "Ptr"))                ; FlushMenuThemes
    }
}

SetDark(h, name) {
    try DllCall("uxtheme\SetWindowTheme", "Ptr", h, "Str", name, "Ptr", 0)
}

; the dark theme: windows and controls are painted dark (the light theme is the normal Windows look)
Skin(g) {
    if (UiTheme != "Dark")
        return
    g.BackColor := "1E1E1E"
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 20, "Int*", 1, "Int", 4)      ; dark title bar
    for c in g {
        if LinkCtls.Has(c.Hwnd)
            continue
        h := c.Hwnd
        switch c.Type {
            case "Text":
                c.Opt("cD4D4D4")
            case "Button", "CheckBox", "Radio":
                c.Opt("cD4D4D4")
                SetDark(h, "DarkMode_Explorer")
            case "Edit":
                c.Opt("Background2D2D30 cE6E6E6")
                SetDark(h, (WinGetStyle("ahk_id " h) & 0x4) ? "DarkMode_Explorer" : "DarkMode_CFD")
            case "ListView":
                c.Opt("Background252526 cE6E6E6")
                SetDark(h, "DarkMode_Explorer")
            case "DDL", "ComboBox":
                c.Opt("Background2D2D30 cE6E6E6")
                SetDark(h, "DarkMode_CFD")
            case "Tab":
                SetDark(h, "DarkMode_Explorer")
        }
    }
}

; a clickable blue text (works in both themes, unlike the system link control)
AddLink(g, opts, text, cb) {
    t := g.Add("Text", opts " +0x100", text)
    t.SetFont("underline c" . (UiTheme = "Dark" ? "6CB6FF" : "0066CC"))
    t.OnEvent("Click", cb)
    LinkCtls[t.Hwnd] := 1
    return t
}

; ---- data file --------------------------------------------------------------
Esc(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "`r")
    s := StrReplace(s, "`n", "\n")
    return StrReplace(s, "`t", "\t")
}

Unesc(s) {
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

NewItem(title, text, comment := "") {
    global NextId
    return {id: NextId++, title: title, text: text, comment: comment}
}

LoadItems() {
    global Items := []
    if !FileExist(DataFile)
        return
    try txt := FileRead(DataFile, "UTF-8")
    catch
        return
    Loop Parse txt, "`n", "`r" {
        p := InStr(A_LoopField, "`t")
        if (p < 2)
            continue
        rest := SubStr(A_LoopField, p + 1)
        q := InStr(rest, "`t")                                         ; optional third column: the comment
        cm := ""
        if q {
            cm := Unesc(SubStr(rest, q + 1))
            rest := SubStr(rest, 1, q - 1)
        }
        Items.Push(NewItem(Unesc(SubStr(A_LoopField, 1, p - 1)), Unesc(rest), cm))
    }
}

SaveItems() {
    DirCreate(Dir)
    if FileExist(DataFile)
        FileCopy(DataFile, Dir "\Bangla Snippet Data.bak", 1)          ; one backup copy before every save
    out := ""
    for it in Items
        out .= Esc(it.title) "`t" Esc(it.text) (it.comment != "" ? "`t" Esc(it.comment) : "") "`n"      ; the comment column only when there is a comment
    tmp := Dir "\Bangla Snippet Data.tmp"
    f := FileOpen(tmp, "w", "UTF-8-RAW")
    f.Write(out)
    f.Close()
    FileMove(tmp, DataFile, 1)
}

; ---- list -------------------------------------------------------------------
Preview(s) {
    s := StrReplace(StrReplace(s, "`r"), "`n", " ")
    return (StrLen(s) > 90) ? SubStr(s, 1, 90) "..." : s
}

Refill(*) {
    f := Trim(EdFind.Value)
    m := DdFilter.Value                                                ; 1 = All, 2 = Title, 3 = Content, 4 = Comments
    LV.Opt("-Redraw")
    LV.Delete()
    for it in Items {
        if (f = "" || ((m = 1 || m = 2) && InStr(it.title, f)) || ((m = 1 || m = 3) && InStr(it.text, f)) || ((m = 1 || m = 4) && InStr(it.comment, f)))
            LV.Add("", it.title, Preview(it.text), Preview(it.comment), it.id)
    }
    LV.ModifyCol(1, 180)
    LV.ModifyCol(2, 290)
    LV.ModifyCol(3, 130)
    LV.ModifyCol(4, 0)                                                 ; hidden column: the id of the entry
    ApplySort()
    LV.Opt("+Redraw")
    n := LV.GetCount()
    SB.Text := (f = "") ? (Items.Length " entries") : (n " of " Items.Length " entries")
}

ById(id) {
    for i, it in Items {
        if (it.id = id)
            return i
    }
    return 0
}

RowIndex(r) => ById(Integer(LV.GetText(r, 4)))

; ---- sorting: a click on a heading sorts, a second click reverses; the order is kept when the list refreshes and next time
ColSort(n, *) {
    global SortCol, SortDesc
    SortDesc := (SortCol = n) ? !SortDesc : false
    SortCol := n
    IniWrite(SortCol, IniFile, "SnippetTool", "SortCol")
    IniWrite(SortDesc ? 1 : 0, IniFile, "SnippetTool", "SortDesc")
    ApplySort()
}

ApplySort() {
    if (SortCol > 0)
        LV.ModifyCol(SortCol, SortDesc ? "SortDesc" : "Sort")
    names := ["Title", "Content", "Comments"]
    for i, t in HdrCols {                                              ; dark theme: arrow on the sorted heading
        arrow := (i = SortCol) ? (SortDesc ? "  " Chr(0x25BC) : "  " Chr(0x25B2)) : ""
        t.Text := "  " names[i] arrow
    }
}

TitleIndex(t, skipIdx := 0) {
    for i, it in Items {
        if (i != skipIdx && StrLower(it.title) = StrLower(t))
            return i
    }
    return 0
}

; ---- installed fonts (for the font preview in the editor) ----------------------------
FontEnum(names, lpelfe, lpntme, fontType, lParam) {
    face := StrGet(lpelfe + 28, 32, "UTF-16")
    if (face != "" && SubStr(face, 1, 1) != "@")
        names[face] := 1
    return 1
}

FontList() {
    static cache := ""
    if IsObject(cache)
        return cache
    names := Map()
    names.CaseSense := "Off"
    lf := Buffer(92, 0)
    NumPut("UChar", 1, lf, 23)                                         ; DEFAULT_CHARSET: every font, ANSI ones too
    cb := CallbackCreate(FontEnum.Bind(names), "F", 4)
    dc := DllCall("GetDC", "Ptr", 0, "Ptr")
    DllCall("EnumFontFamiliesExW", "Ptr", dc, "Ptr", lf, "Ptr", cb, "Ptr", 0, "UInt", 0)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", dc)
    CallbackFree(cb)
    s := ""
    for n in names
        s .= n "`n"
    s := Sort(RTrim(s, "`n"), "D`n")
    cache := StrSplit(s, "`n")
    return cache
}

; ---- add / edit ---------------------------------------------------------------
OpenEditor(idx := 0, *) {
    global EG
    if IsObject(EG) {
        EG.Show()
        return
    }
    old := idx ? Items[idx] : {title: "", text: ""}
    EG := Gui("+Owner" G.Hwnd " +Resize +MinSize470x340", idx ? "Edit Snippet" : "Add New Snippet")
    EG.SetFont("s10")
    sz := Integer(IniRead(IniFile, "Snippets", "EditorSize", "10"))
    sz := Min(32, Max(7, sz))
    fn := IniRead(IniFile, "Snippets", "EditorFont", "")
    fonts := FontList()
    pick := 1
    for i, n in fonts {
        if (StrLower(n) = StrLower(fn)) {
            pick := i + 1
            break
        }
    }
    EG.Add("Text", "x12 y12", "Title (what you type):")
    eT := EG.Add("Edit", "x12 y32 w480 Limit100", old.title)
    EG.Add("Text", "x12 y68", "Content (what it becomes):")
    lnk := AddLink(EG, "x392 y68 w100", "Help and Guide", (*) => OpenHelp(2))      ; opens on the Macros tab
    eC := EG.Add("Edit", "x12 y88 w480 h200 Multi WantReturn", StrReplace(old.text, "`n", "`r`n"))
    eC.SetFont("s" sz, fn)
    ; bottom row: zoom out / zoom in and a font to preview the text in (left), Save and Cancel (right)
    bZm := EG.Add("Button", "x12 y304 w34 h28", "A-")
    bZm.OnEvent("Click", (*) => DoZoom(-1))
    bZp := EG.Add("Button", "x50 y304 w34 h28", "A+")
    bZp.OnEvent("Click", (*) => DoZoom(1))
    ddF := EG.Add("DropDownList", "x92 y306 w210 R15 Choose" pick, ["(Default font)"])
    ddF.Add(fonts)
    ddF.Choose(pick)
    ddF.OnEvent("Change", DoFont)
    bSv := EG.Add("Button", "x332 y304 w76 h28 Default", "Save")
    bSv.OnEvent("Click", DoSave)
    bCn := EG.Add("Button", "x416 y304 w76 h28", "Cancel")
    bCn.OnEvent("Click", DoClose)
    EG.OnEvent("Size", DoSize)
    EG.OnEvent("Close", DoClose)
    EG.OnEvent("Escape", DoClose)
    G.Opt("+Disabled")
    Skin(EG)
    EG.Show("w504 h350")

    ; the window can be resized: the boxes grow, the bottom row follows
    DoSize(g, mm, w, h) {
        if (mm = -1)
            return
        eT.Move(, , w - 24)
        lnk.Move(w - 112)
        eC.Move(, , w - 24, h - 150)
        by := h - 46
        bZm.Move(, by)
        bZp.Move(, by)
        ddF.Move(, by + 2)
        bSv.Move(w - 172, by)
        bCn.Move(w - 88, by)
    }

    ; zoom and font only change how the text looks here (it is saved as plain text); the choice is remembered
    DoZoom(d) {
        sz := Min(32, Max(7, sz + d))
        eC.SetFont("s" sz, fn)
        IniWrite(sz, IniFile, "Snippets", "EditorSize")
    }
    DoFont(*) {
        fn := (ddF.Value = 1) ? "" : ddF.Text
        eC.SetFont("s" sz, fn)
        IniWrite(fn, IniFile, "Snippets", "EditorFont")
    }

    DoSave(*) {
        t := Trim(StrReplace(eT.Value, "`t", " "))
        if (t = "") {
            MsgBox("The title cannot be empty.", "Bangla Snippet", 0x30)
            return
        }
        if (TitleIndex(t, idx) && MsgBox("A snippet with the title `"" t "`" already exists.`n`nSave anyway?", "Bangla Snippet", 0x134) != "Yes")
            return
        c := StrReplace(eC.Value, "`r`n", "`n")
        if idx
            Items[idx] := {id: Items[idx].id, title: t, text: c, comment: Items[idx].comment}
        else
            Items.Push(NewItem(t, c))
        SaveItems()
        Refill()
        DoClose()
    }
    DoClose(*) {
        global EG
        G.Opt("-Disabled")
        EG.Destroy()
        EG := ""
        WinActivate("ahk_id " G.Hwnd)
    }
}

AddNew(*) => OpenEditor(0)

EditSel(*) {
    r := LV.GetNext()
    if r
        OpenEditor(RowIndex(r))
    else
        MsgBox("Select a snippet first.", "Bangla Snippet", 0x40)
}

RemoveSel(*) {
    ids := []
    r := 0
    while (r := LV.GetNext(r))
        ids.Push(Integer(LV.GetText(r, 4)))
    if !ids.Length {
        MsgBox("Select a snippet first.", "Bangla Snippet", 0x40)
        return
    }
    if (MsgBox("Remove " ids.Length " selected snippet(s)?", "Bangla Snippet", 0x124) != "Yes")
        return
    sel := Map()
    for id in ids
        sel[id] := 1
    batch := []                                                        ; [{i: old position, it: the entry}], oldest position first
    for i, it in Items {
        if sel.Has(it.id)
            batch.Push({i: i, it: it})
    }
    loop batch.Length
        Items.RemoveAt(batch[batch.Length - A_Index + 1].i)            ; from the end, so the positions stay right
    UndoStack.Push(batch)
    if (UndoStack.Length > 20)
        UndoStack.RemoveAt(1)
    SaveItems()
    Refill()
}

; brings back the entries of the last deletion, at their old places
UndoDelete(*) {
    if !UndoStack.Length
        return
    batch := UndoStack.Pop()
    ids := []
    for b in batch {
        Items.InsertAt(Min(b.i, Items.Length + 1), b.it)
        ids.Push(b.it.id)
    }
    SaveItems()
    Refill()
    SelectIds(ids)
}

; copies of the selected entries, each right after its original, titled "Title (copy)", "Title (copy 2)" ...
DupSel(*) {
    ids := []
    r := 0
    while (r := LV.GetNext(r))
        ids.Push(Integer(LV.GetText(r, 4)))
    if !ids.Length
        return
    news := []
    for id in ids {
        i := ById(id)
        if !i
            continue
        base := SubStr(Items[i].title, 1, 80), t := base " (copy)", n := 2
        while TitleIndex(t)
            t := base " (copy " n++ ")"
        it := NewItem(t, Items[i].text, Items[i].comment)
        Items.InsertAt(i + 1, it)
        news.Push(it.id)
    }
    SaveItems()
    Refill()
    SelectIds(news)
}

; selects the shown rows whose entry id is in ids
SelectIds(ids) {
    LV.Modify(0, "-Select")
    first := true
    loop LV.GetCount() {
        id := Integer(LV.GetText(A_Index, 4))
        for x in ids {
            if (x = id) {
                LV.Modify(A_Index, first ? "Select Focus Vis" : "Select")
                first := false
                break
            }
        }
    }
}

ListKey(ctl, lParam) {
    k := NumGet(lParam, A_PtrSize * 3, "UShort")
    if (k = 46)                                                        ; Delete key
        RemoveSel()
    else if (k = 65 && GetKeyState("Ctrl"))                            ; Ctrl+A: select every entry shown
        LV.Modify(0, "Select")
    else if (k = 68 && GetKeyState("Ctrl"))                            ; Ctrl+D: duplicate
        DupSel()
    else if (k = 90 && GetKeyState("Ctrl"))                            ; Ctrl+Z: restore the last deleted
        UndoDelete()
}

; right-click menu of the list
ListMenu(ctl, row, *) {
    if (row && LV.GetNext(row - 1) != row)                             ; right-click on an unselected row: select just that row
        LV.Modify(row, "Select Focus")
    n := 0, r := 0
    while (r := LV.GetNext(r))
        n++
    m := Menu()
    if (n = 1)
        m.Add("Edit", EditSel)
    if n
        m.Add("Duplicate`tCtrl+D", DupSel)
    if (n = 1) {
        m.Add("Copy content", (*) => CopySel(true))
        m.Add("Copy title", (*) => CopySel(false))
        hasC := (Items[RowIndex(LV.GetNext())].comment != "")
        m.Add()
        m.Add(hasC ? "Edit comment" : "Add comment", OpenComment)
        if hasC
            m.Add("Remove comment", RemoveComment)
    }
    if n
        m.Add()
    dn := "Delete" (n > 1 ? " " n " snippets" : "") "`tDel"            ; the full item name, needed to disable it
    m.Add(dn, RemoveSel)
    if !n
        m.Disable(dn)
    if UndoStack.Length
        m.Add("Restore deleted (" UndoStack[UndoStack.Length].Length ")`tCtrl+Z", UndoDelete)
    m.Add()
    m.Add("Add new snippet", AddNew)
    m.Add("Select all`tCtrl+A", (*) => LV.Modify(0, "Select"))
    m.Show()
}

CopySel(content) {
    i := RowIndex(LV.GetNext())
    if i
        A_Clipboard := content ? StrReplace(Items[i].text, "`n", "`r`n") : Items[i].title
}

; ---- comments: right-click a snippet > Add comment; a small box opens, type and click Save ----------
OpenComment(*) {
    global CmG
    if IsObject(CmG) {
        CmG.Show()
        return
    }
    r := LV.GetNext()
    if !r {
        MsgBox("Select a snippet first.", "Bangla Snippet", 0x40)
        return
    }
    id := Integer(LV.GetText(r, 4))
    i := ById(id)
    if !i
        return
    it := Items[i]
    CmG := Gui("+Owner" G.Hwnd " +Resize +MinSize330x230", (it.comment = "") ? "Add Comment" : "Edit Comment")
    CmG.SetFont("s10")
    CmG.Add("Text", "x12 y12 w396 h20 +0x4000", "Comment for:  " it.title)                ; 0x4000: long titles end with ...
    eC := CmG.Add("Edit", "x12 y36 w396 h164 Multi WantReturn VScroll", StrReplace(it.comment, "`n", "`r`n"))
    bSv := CmG.Add("Button", "x248 y214 w76 h28 Default", "Save")
    bSv.OnEvent("Click", DoSave)
    bCn := CmG.Add("Button", "x332 y214 w76 h28", "Cancel")
    bCn.OnEvent("Click", DoClose)
    CmG.OnEvent("Size", DoSize)
    CmG.OnEvent("Close", DoClose)
    CmG.OnEvent("Escape", DoClose)
    G.Opt("+Disabled")
    Skin(CmG)
    CmG.Show("w420 h260")
    eC.Focus()

    DoSize(g, mm, w, h) {
        if (mm = -1)
            return
        eC.Move(, , w - 24, h - 96)
        by := h - 46
        bSv.Move(w - 172, by)
        bCn.Move(w - 88, by)
    }
    DoSave(*) {
        c := Trim(StrReplace(eC.Value, "`r`n", "`n"), " `t`r`n")                  ; an empty box removes the comment
        j := ById(id)
        if j {
            Items[j] := {id: id, title: Items[j].title, text: Items[j].text, comment: c}
            SaveItems()
            Refill()
            SelectIds([id])
        }
        DoClose()
    }
    DoClose(*) {
        global CmG
        G.Opt("-Disabled")
        CmG.Destroy()
        CmG := ""
        WinActivate("ahk_id " G.Hwnd)
    }
}

RemoveComment(*) {
    r := LV.GetNext()
    i := r ? RowIndex(r) : 0
    if !i
        return
    it := Items[i]
    Items[i] := {id: it.id, title: it.title, text: it.text, comment: ""}
    SaveItems()
    Refill()
    SelectIds([it.id])
}

; ---- export -----------------------------------------------------------------
CsvQuote(s) => '"' StrReplace(s, '"', '""') '"'

Export(*) {
    if !Items.Length {
        MsgBox("There are no snippets to export.", "Bangla Snippet", 0x40)
        return
    }
    f := FileSelect("S16", A_Desktop "\Bangla Snippets.csv", "Export snippets (end the name with .csv or .txt)", "Snippets (*.csv; *.txt)")
    if (f = "")
        return
    if !RegExMatch(f, "i)\.(csv|txt)$")
        f .= ".csv"
    out := ""
    if RegExMatch(f, "i)\.csv$") {
        out := "Title,Content,Comments`r`n"
        for it in Items
            out .= CsvQuote(it.title) "," CsvQuote(StrReplace(it.text, "`n", "`r`n")) "," CsvQuote(StrReplace(it.comment, "`n", "`r`n")) "`r`n"
    } else {
        for it in Items
            out .= Esc(it.title) "`t" Esc(it.text) (it.comment != "" ? "`t" Esc(it.comment) : "") "`r`n"
    }
    try {
        h := FileOpen(f, "w", "UTF-8")                                 ; UTF-8 (Excel opens Bangla in a .csv correctly)
        h.Write(out)
        h.Close()
        MsgBox(Items.Length " snippets exported to:`n" f, "Bangla Snippet", 0x40)
    } catch as e
        MsgBox("Could not save the file.`n`n" e.Message, "Bangla Snippet", 0x10)
}

; ---- import -----------------------------------------------------------------
CountChar(s, ch) {
    s := StrReplace(s, ch, , , &n)
    return n
}

ParseCsv(txt) {
    nl := InStr(txt, "`n")
    first := nl ? SubStr(txt, 1, nl - 1) : txt
    delim := ","
    if (CountChar(first, "`t") > CountChar(first, ","))
        delim := "`t"
    else if (CountChar(first, ";") > CountChar(first, ","))
        delim := ";"
    rows := []
    row := []
    field := ""
    inq := false
    i := 1
    n := StrLen(txt)
    while (i <= n) {
        c := SubStr(txt, i, 1)
        if inq {
            if (c = '"') {
                if (SubStr(txt, i + 1, 1) = '"') {
                    field .= '"'
                    i++
                } else
                    inq := false
            } else
                field .= c
        } else if (c = '"' && field = "") {
            inq := true
        } else if (c = delim) {
            row.Push(field)
            field := ""
        } else if (c = "`n") {
            row.Push(field)
            field := ""
            rows.Push(row)
            row := []
        } else if (c != "`r") {
            field .= c
        }
        i++
    }
    if (field != "" || row.Length) {
        row.Push(field)
        rows.Push(row)
    }
    list := []
    for r in rows {
        if (r.Length < 2 || Trim(r[1]) = "")
            continue
        list.Push({title: Trim(r[1]), text: StrReplace(r[2], "`r`n", "`n"), comment: (r.Length > 2) ? Trim(StrReplace(r[3], "`r`n", "`n"), " `t`r`n") : ""})
    }
    if (list.Length && rows[1].Length > 1 && StrLower(list[1].title) = "title" && StrLower(Trim(rows[1][2])) = "content")
        list.RemoveAt(1)
    return list
}

ParseTabbed(txt) {
    list := []
    Loop Parse txt, "`n", "`r" {
        p := InStr(A_LoopField, "`t")
        if (p < 2)
            continue
        t := Trim(Unesc(SubStr(A_LoopField, 1, p - 1)))
        if (t != "") {
            rest := SubStr(A_LoopField, p + 1)
            q := InStr(rest, "`t")                                     ; optional third column: the comment
            cm := q ? Unesc(SubStr(rest, q + 1)) : ""
            list.Push({title: t, text: Unesc(q ? SubStr(rest, 1, q - 1) : rest), comment: cm})
        }
    }
    return list
}

; asks what to do with titles that already exist: "skip" | "over" | "both" | "" (cancel)
AskConflict(n) {
    global ConflictMode, CG
    ConflictMode := ""
    CG := Gui("+Owner" G.Hwnd, "Import - titles that already exist")
    CG.SetFont("s10")
    CG.Add("Text", "x14 y14 w360", n " title(s) in the file already exist in your list.`nWhat should happen to them?")
    CG.Add("Button", "x14 y64 w110", "Skip").OnEvent("Click", (*) => Pick("skip"))
    CG.Add("Button", "x134 y64 w110", "Overwrite").OnEvent("Click", (*) => Pick("over"))
    CG.Add("Button", "x254 y64 w110", "Keep both").OnEvent("Click", (*) => Pick("both"))
    CG.OnEvent("Close", (*) => Pick(""))
    CG.OnEvent("Escape", (*) => Pick(""))
    G.Opt("+Disabled")
    Skin(CG)
    CG.Show("w380 h110")
    WinWaitClose("ahk_id " CG.Hwnd)
    G.Opt("-Disabled")
    WinActivate("ahk_id " G.Hwnd)
    return ConflictMode

    Pick(m) {
        global ConflictMode := m
        CG.Destroy()
    }
}

Import(*) {
    f := FileSelect(1, A_Desktop, "Import snippets", "Snippets (*.csv; *.txt; *.dat)")
    if (f = "")
        return
    try txt := FileRead(f, "UTF-8")
    catch as e {
        MsgBox("Could not read the file.`n`n" e.Message, "Bangla Snippet", 0x10)
        return
    }
    list := RegExMatch(f, "i)\.csv$") ? ParseCsv(txt) : ParseTabbed(txt)
    if !list.Length {
        MsgBox("No snippets were found in that file.", "Bangla Snippet", 0x30)
        return
    }
    ; titles that exist already (in the list, or twice in the file)
    seen := Map()
    for it in Items
        seen[StrLower(it.title)] := true
    clash := 0
    for it in list {
        k := StrLower(it.title)
        if seen.Has(k)
            clash++
        else
            seen[k] := true
    }
    mode := "both"
    if clash {
        mode := AskConflict(clash)
        if (mode = "")
            return
    }
    byTitle := Map()
    for i, it in Items
        if !byTitle.Has(StrLower(it.title))
            byTitle[StrLower(it.title)] := i
    added := over := skipped := both := 0
    for it in list {
        k := StrLower(it.title)
        t := SubStr(it.title, 1, 100)
        if byTitle.Has(k) {
            if (mode = "skip")
                skipped++
            else if (mode = "over") {
                idx := byTitle[k]
                Items[idx] := {id: Items[idx].id, title: Items[idx].title, text: it.text, comment: (it.comment != "") ? it.comment : Items[idx].comment}
                over++
            } else {
                Items.Push(NewItem(t, it.text, it.comment))
                both++
            }
        } else {
            Items.Push(NewItem(t, it.text, it.comment))
            byTitle[k] := Items.Length
            added++
        }
    }
    SaveItems()
    Refill()
    MsgBox("Import finished.`n`nAdded: " added "`nOverwritten: " over "`nKept both: " both "`nSkipped: " skipped, "Bangla Snippet", 0x40)
}

; ---- settings (look of this tool) ----------------------------------------------------------
OpenSettings(*) {
    global SG
    if IsObject(SG) {
        SG.Show()
        return
    }
    SG := Gui("+Owner" G.Hwnd " -MinimizeBox -MaximizeBox", "Bangla Snippet - Settings")
    SG.SetFont("s10")
    SG.Add("Text", "x16 y22 w110 h22 +0x200", "Theme:")
    ddT := SG.Add("DropDownList", "x130 y20 w170 Choose" Idx(ThemeList, UiTheme), ThemeList)
    SG.Add("Text", "x16 y56 w110 h22 +0x200", "List text size:")
    ddX := SG.Add("DropDownList", "x130 y54 w170 Choose" Idx(TextList, UiText), TextList)
    cTip := AddCheck(SG, 16, 94, 290, "Show a name when pointing at a button", UiTips)
    cTop := AddCheck(SG, 16, 120, 290, "Keep this window on top", UiTop)
    SG.Add("Button", "x130 y164 w80 Default", "Save").OnEvent("Click", DoSave)
    SG.Add("Button", "x220 y164 w80", "Cancel").OnEvent("Click", DoClose)
    SG.OnEvent("Close", DoClose)
    SG.OnEvent("Escape", DoClose)
    Skin(SG)
    G.Opt("+Disabled")
    SG.Show("w324 h208")

    DoSave(*) {
        changed := (ddT.Text != UiTheme || ddX.Text != UiText || (cTip.Value = 1) != UiTips || (cTop.Value = 1) != UiTop)
        IniWrite(ddT.Text, IniFile, "SnippetTool", "Theme")
        IniWrite(ddX.Text, IniFile, "SnippetTool", "TextSize")
        IniWrite(cTip.Value, IniFile, "SnippetTool", "ShowTips")
        IniWrite(cTop.Value, IniFile, "SnippetTool", "OnTop")
        DoClose()
        if changed
            Reload()                                                   ; the new look is applied by starting the tool again
    }
    DoClose(*) {
        global SG
        G.Opt("-Disabled")
        SG.Destroy()
        SG := ""
        WinActivate("ahk_id " G.Hwnd)
    }
}

; ---- help & guide -------------------------------------------------------------
Lines(arr) {
    t := ""
    for s in arr
        t .= s "`r`n"
    return t
}

HelpTabs() {
    tabs := []
    tabs.Push(["Quick Start", Lines([
        "WHAT IT DOES",
        "You save a short abbreviation (the Title) together with a long text (the Content). Later, in any program, you type the title and then the trigger, and Bangla Keyboard replaces both with the full text.",
        "",
        "QUICK START",
        "1. Click the + button (Add new snippet).",
        "2. Title: the short word you will type, for example  addr",
        "3. Content: the full text, for example your address. It can have many lines, and it can be Bangla or English.",
        "4. Click Save.",
        "5. In any program type  addr==  (the title, then two equal signs). The title and the == are replaced by your text.",
        "",
        "Bangla Keyboard must be running with Bangla Snippet ticked in its Settings. Changes you save here are picked up by it the next time you type a snippet; nothing needs a restart.",
        "",
        "THE TRIGGER",
        "The trigger is what you type right after the title. It is  ==  by default and can be changed in Bangla Keyboard > Settings > Bangla Snippet. If what you typed before the trigger is not a saved title, nothing happens and the trigger stays exactly as typed, so  ==  in code or normal text is safe."])])
    tabs.Push(["Macros", Lines([
        "MACROS - special words for the Content",
        "",
        "Write these words inside the Content of a snippet. When the snippet expands they are replaced:",
        "",
        "    {date}        today's date, like 22/11/2026",
        "    {time}        the time right now, like 02:30 PM",
        "    {time24}      the time in 24 hours, like 14:30",
        "    {datetime}    date and time together, like 22/11/2026 02:30 PM",
        "    {longdate}    the long date, like Sunday, 22 November 2026",
        "    {day}         the day name, like Sunday",
        "    {month}       the month name, like November",
        "    {year}        the year, like 2026",
        "    {clipboard}   the text you copied last (Ctrl+C)",
        "    {cursor}      nothing is typed for it; after the text is typed, the cursor is placed right here",
        "",
        "BANGLA DATES AND TIMES",
        "",
        "Add  =bn  inside the braces and the date or time is written in Bangla (Unicode), with Bangla digits, day and month names:",
        "",
        "    {date=bn}      ২২/১১/২০২৬",
        "    {time=bn}      ০২:৩০ বিকাল",
        "    {time24=bn}    ১৪:৩০",
        "    {datetime=bn}  ২২/১১/২০২৬ ০২:৩০ বিকাল",
        "    {longdate=bn}  রবিবার, ২২ নভেম্বর ২০২৬",
        "    {day=bn}       রবিবার",
        "    {month=bn}     নভেম্বর",
        "    {year=bn}      ২০২৬",
        "",
        "{clipboard} and {cursor} are the same in both languages. The time of day is রাত, ভোর, সকাল, দুপুর, বিকাল or সন্ধ্যা instead of AM / PM.",
        "",
        "EXAMPLES",
        "",
        "Content:   Dear {cursor},",
        "Result:    Dear ,    and the cursor waits after Dear, ready for a name.",
        "",
        "Content:   Meeting notes - {date} {time}",
        "Result:    Meeting notes - 22/11/2026 02:30 PM",
        "",
        "Content:   আজকের তারিখ: {longdate=bn}",
        "Result:    আজকের তারিখ: রবিবার, ২২ নভেম্বর ২০২৬",
        "",
        "Content:   Hello {clipboard}, thanks for writing on {longdate}.",
        "Result:    the name you copied is put in, followed by today's long date.",
        "",
        "Content:   Thanks for your email.{cursor}   Best regards, Sam",
        "Result:    the whole text is typed and the cursor is left after the first sentence, so you can add a line of your own.",
        "",
        "GOOD TO KNOW",
        "- Type them exactly as shown: small letters inside curly braces. Add =bn for Bangla, like {date=bn}.",
        "- Bangla Keyboard must be a version that knows =bn; an older one types {date=bn} as it is.",
        "- Dates, times and {clipboard} are taken at the moment the snippet expands. Day and month names follow your Windows language.",
        "- Use one {cursor} per snippet. If there are several, the first one is used.",
        "- Macros can be switched off in Bangla Keyboard > Settings > Bangla Snippet. Then they are typed exactly as written.",
        "- They also work when Paste via clipboard is on."])])
    tabs.Push(["Matching", Lines([
        "HOW A TITLE IS MATCHED",
        "- The longest matching title wins. With  My address  and  My address 2  saved, typing  My address 2==  gives the second one.",
        "- Capital or small letters do not matter, unless Case-sensitive matching is on in Bangla Keyboard > Settings > Bangla Snippet.",
        "- With Title must start at a word boundary on, a title only works at the start of a word (after a space, punctuation, or at the start of a line), never in the middle of one.",
        "- If nothing matches, the trigger stays as typed.",
        "",
        "WHAT STARTS THE TYPING RECORD AGAIN",
        "Pressing Enter, Esc, Tab, an arrow key, Home/End, Ctrl/Alt/Win, clicking the mouse, or changing the window. So type the title and the trigger together, without moving away. Backspace works normally: fix a typo and carry on.",
        "",
        "BANGLA TITLES",
        "Titles can be Bangla. Type the title with the same keyboard layout (or Avro) that you used when you saved it, then the trigger. English and Bangla titles can be mixed in one list."])])
    tabs.Push(["Toolbar", Lines([
        "THE MAIN WINDOW",
        "The buttons show only an icon: rest the mouse on one to see its name. From the left: + Add new, pencil = Edit selected, cross = Remove selected, arrow up = Export, arrow down = Import, gear = Settings, i = About, ? = Help.",
        "Double-click an entry to edit it. The Delete key removes the selected entries after you confirm.",
        "Ctrl+A selects every entry shown. Right-click the list for a menu: Edit, Duplicate, Copy content, Copy title, Add comment (Edit comment / Remove comment), Delete, Restore deleted, Add new snippet and Select all.",
        "Duplicate (Ctrl+D) makes a copy of each selected entry, titled  Title (copy). Restore deleted (Ctrl+Z) brings back the entries of the last deletion at their old places; it can be repeated for the last 20 deletions, until this tool is closed.",
        "Search box (right of the buttons): type to filter the list. The drop-down at its right chooses where to look: All (title, content and comments), Title, Content or Comments.",
        "The Comments column shows the note you added to a snippet. Click a column heading to sort the list, click again to reverse it (an arrow shows the order in the dark theme). The order is kept after every change and the next time you open this tool.",
        "Export: saves all entries (title, content and comment) to a .csv (opens in Excel) or a .txt file. End the file name with .csv or .txt to choose.",
        "Import: reads a .csv, .txt or .dat file (the comment column is optional). If titles already exist you choose Skip, Overwrite or Keep both, and a summary is shown at the end.",
        "Settings (gear): the look of this tool: theme (Light or Dark), the text size of the list, button names on/off and always on top. Saving restarts the tool to apply them.",
        "About: what the tool does, the version and the number of entries.",
        "The expander's options (on/off, trigger, case-sensitive, word boundary, paste via clipboard, macros) are in Bangla Keyboard > Settings > Bangla Snippet, not here.",
        "",
        "COMMENTS",
        "A comment is a private note for yourself, for example where a snippet is used. It is never typed when the snippet expands. To add one: right-click a snippet, click Add comment, type in the box and click Save. Right-click it again to Edit or Remove the comment. Saving an empty box removes the comment.",
        "",
        "THE ADD / EDIT WINDOW",
        "Title must not be empty; you are warned about a duplicate title. The window can be resized.",
        "A- / A+ make the Content text smaller or bigger, and the font list shows it in any installed font (for example an ANSI font). This only changes how it looks here; the snippet is saved as plain text."])])
    tabs.Push(["Tips", Lines([
        "TIPS",
        "- Keep titles short but unlikely to be typed by accident, for example  addr  or  sig1.",
        "- For a very long snippet that types slowly, turn on Paste via clipboard (Bangla Keyboard > Settings > Bangla Snippet). Your clipboard is restored afterwards.",
        "- The text is typed exactly as saved; it is not changed by the Bangla layouts.",
        "- Export a copy now and then as a backup. The program also keeps one automatic .bak copy of the data.",
        "",
        "NOT WORKING?",
        "- Is Bangla Keyboard running, and is Bangla Snippet ticked in Bangla Keyboard > Settings > Bangla Snippet? (When it is off, nothing is expanded.)",
        "- Did you type the title exactly, with the trigger straight after it?",
        "- Did you click or press an arrow key between the title and the trigger?",
        "- Some programs that run as administrator, and some remote-desktop windows, do not accept typed text from other programs.",
        "",
        "WHERE IS THE DATA?",
        "%AppData%\Bangla Keyboard\Bangla Keyboard Snippets\Bangla Snippet Data.dat  (UTF-8). Use the Open data folder link below to go there."])])
    return tabs
}

OpenDataFolder(*) {
    DirCreate(Dir)
    Run('explorer.exe "' Dir '"')
}

; n = the tab to show (1 Quick Start, 2 Macros ...)
OpenHelp(n := 1) {
    global HG, HTab
    if IsObject(HG) {
        HTab.Choose(n)
        HG.Show()
        return
    }
    HG := Gui("+Owner" G.Hwnd " +Resize +MinSize480x340", "Help & Guide")
    HG.SetFont("s10")
    tabs := HelpTabs()
    names := []
    for t in tabs
        names.Push(t[1])
    eds := []
    dark := (UiTheme = "Dark")
    if (!dark) {
        tb := HG.Add("Tab3", "x12 y12 w580 h400", names)
        HTab := tb
        for i, t in tabs {
            tb.UseTab(i)
            ed := HG.Add("Edit", "x24 y46 w556 h354 ReadOnly Multi VScroll", t[2])
            if (t[1] = "Macros")
                ed.SetFont("s11")                                      ; the Macros tab is the one to notice
            eds.Push(ed)
        }
        tb.UseTab()
    } else {
        ; dark theme: the system tab control cannot be painted dark, so the tabs are drawn as our own dark strip
        tb := ""
        labels := []
        tx := 12
        for i, t in tabs {
            tw := StrLen(t[1]) * 9 + 28
            lb := HG.Add("Text", "x" tx " y12 w" tw " h26 +0x100 +0x200 Center Background2D2D30 cD4D4D4", t[1])
            lb.OnEvent("Click", SetTab.Bind(i))
            LinkCtls[lb.Hwnd] := 1
            labels.Push(lb)
            tx += tw + 2
            ed := HG.Add("Edit", "x12 y40 w580 h360 ReadOnly Multi VScroll Hidden", t[2])
            if (t[1] = "Macros")
                ed.SetFont("s11")
            eds.Push(ed)
        }
        HTab := {Choose: (a*) => SetTab(a[a.Length])}                  ; same Choose(n) as the real tab control
    }
    lk := AddLink(HG, "x14 y430 w160", "Open data folder", OpenDataFolder)
    bt := HG.Add("Button", "x500 y424 w92 h28 Default", "Close")
    bt.OnEvent("Click", DoClose)
    HG.OnEvent("Close", DoClose)
    HG.OnEvent("Escape", DoClose)
    HG.OnEvent("Size", DoSize)
    if (!dark)
        tb.Choose(n)
    Skin(HG)
    if (dark)
        SetTab(n)
    HG.Show("w604 h466")
    bt.Focus()

    SetTab(i, *) {
        for j, e in eds
            e.Visible := (i = j)
        for j, lb in labels {
            lb.Opt("Background" (i = j ? "3E3E42" : "2D2D30") " c" (i = j ? "FFFFFF" : "A0A0A0"))
            lb.Redraw()
        }
    }

    DoSize(g, mm, w, h) {
        if (mm = -1)
            return
        if (dark) {
            for ed in eds
                ed.Move(, , w - 24, h - 94)
        } else {
            tb.Move(, , w - 24, h - 66)
            for ed in eds
                ed.Move(, , w - 48, h - 112)
        }
        lk.Move(, h - 38)
        bt.Move(w - 104, h - 42)
    }
    DoClose(*) {
        global HG
        HG.Destroy()
        HG := ""
    }
}

HelpClick(*) => OpenHelp(1)

; ---- about -------------------------------------------------------------------
OpenAbout(*) {
    global AG
    if IsObject(AG) {
        AG.Show()
        return
    }
    on := (IniRead(IniFile, "Snippets", "Enabled", "1") != "0")
    trig := IniRead(IniFile, "Snippets", "Trigger", "==")
    AG := Gui("+Owner" G.Hwnd " -MinimizeBox -MaximizeBox", "About Bangla Snippet")
    AG.SetFont("s10")
    AG.Add("Text", "x20 y12 w420 h32", "Bangla Snippet").SetFont("s14 w700")
    AG.Add("Text", "x20 y48 w420 h22 cGray", "Version " Ver "  -  a text expander for Bangla Keyboard")
    AG.Add("Text", "x20 y80 w420", "Save a short title together with a long text. Then, in any program, type the title followed by the trigger and it is replaced by the full text: addresses, signatures, replies, Bangla paragraphs, anything you type again and again.")
    AG.Add("Text", "x20 y150 w420", "Works with English and Bangla (Bijoy layouts and Avro), with multi-line text and with date / time macros in Bangla, like {date=bn}, without using your clipboard.")
    AG.Add("Text", "x20 y204 w420", "This tool only manages your snippets. Bangla Keyboard does the expanding, so keep it running.")
    AG.Add("Text", "x20 y246 w420 h1 0x10")                              ; thin line
    AG.Add("Text", "x20 y258 w420", "Entries saved:  " Items.Length)
    AG.Add("Text", "x20 y280 w420", "Snippets:  " (on ? "On" : "Off") "      Trigger:  " trig)
    AddLink(AG, "x20 y312 w200", "Help and Guide", (*) => OpenHelp(1))
    AG.Add("Button", "x360 y306 w80 h28 Default", "Close").OnEvent("Click", DoClose)
    AG.OnEvent("Close", DoClose)
    AG.OnEvent("Escape", DoClose)
    G.Opt("+Disabled")
    Skin(AG)
    AG.Show("w460 h352")

    DoClose(*) {
        global AG
        G.Opt("-Disabled")
        AG.Destroy()
        AG := ""
        WinActivate("ahk_id " G.Hwnd)
    }
}

; a tick box with a separate text, so the text can follow the theme
AddCheck(g, x, y, w, text, val) {
    cb := g.Add("Checkbox", "x" x " y" y " w20 h22")
    cb.Value := val ? 1 : 0
    lb := g.Add("Text", "x" (x + 22) " y" y " w" (w - 22) " h22 +0x200 +0x100", text)
    lb.OnEvent("Click", (*) => cb.Value := !cb.Value)
    return cb
}

; height in pixels of one line of text in a control's current font (used to centre text vertically)
TextLineH(ctl) {
    hdc := DllCall("GetDC", "Ptr", ctl.Hwnd, "Ptr")
    hf := SendMessage(0x31, 0, 0, ctl)                                 ; WM_GETFONT
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hf, "Ptr")
    tm := Buffer(A_PtrSize = 8 ? 80 : 60, 0)
    DllCall("GetTextMetricsW", "Ptr", hdc, "Ptr", tm)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
    DllCall("ReleaseDC", "Ptr", ctl.Hwnd, "Ptr", hdc)
    return NumGet(tm, 0, "Int")                                        ; tmHeight
}

; ---- toolbar tooltips (the buttons show only an icon) ----------------------------------
BtnHover(wParam, lParam, msg, hwnd) {
    global TipLast
    if (!UiTips || hwnd = TipLast || !TipMap.Has(hwnd))
        return
    TipLast := hwnd
    ToolTip(TipMap[hwnd])
    SetTimer(TipCheck, 100)
}

TipCheck() {
    global TipLast
    c := 0
    try MouseGetPos(, , , &c, 2)
    if (c != TipLast) {
        ToolTip()
        TipLast := 0
        SetTimer(TipCheck, 0)
    }
}

; ---- main window -------------------------------------------------------------
try DirCreate(Dir)
LoadItems()
G := Gui("+Resize +MinSize560x300" (UiTop ? " +AlwaysOnTop" : ""), "Bangla Snippet")
ts := Map("Small", 9, "Normal", 10, "Big", 12, "Extra big", 14)[UiText]   ; text size of the list only
G.SetFont("s10")
UseMdl := false
for n in FontList() {
    if (n = "Segoe MDL2 Assets") {
        UseMdl := true
        break
    }
}
bw := 32, bh := 26, bf := 10                                            ; button width, height and icon size
; icon buttons: [Windows icon, fallback symbol, what it does, action, extra gap after it]
Btns := [[Chr(0xE710), "+", "Add new snippet", AddNew, 0]
    , [Chr(0xE70F), Chr(0x270E), "Edit selected snippet", EditSel, 0]
    , [Chr(0xE74D), Chr(0x2715), "Remove selected snippets", RemoveSel, 12]
    , [Chr(0xE898), Chr(0x21E7), "Export snippets to a file", Export, 0]
    , [Chr(0xE896), Chr(0x21E9), "Import snippets from a file", Import, 12]
    , [Chr(0xE713), Chr(0x2699), "Settings (theme, list text size ...)", OpenSettings, 0]
    , [Chr(0xE946), Chr(0x2139), "About", OpenAbout, 0]
    , [Chr(0xE897), "?", "Help and Guide", HelpClick, 0]]
x := 10
for b in Btns {
    bt := G.Add("Button", "x" x " y8 w" bw " h" bh, UseMdl ? b[1] : b[2])
    bt.SetFont("s" bf, UseMdl ? "Segoe MDL2 Assets" : "Segoe UI Symbol")
    bt.OnEvent("Click", b[4])
    TipMap[bt.Hwnd] := b[3]
    x += bw + 4 + b[5]
}
OnMessage(0x200, BtnHover)                                              ; WM_MOUSEMOVE: show the name of the button
SearchX := x + 6
; the search box: a frame as high as the buttons, with the text box inside it
bgc := (UiTheme = "Dark") ? "2D2D30" : "FFFFFF"
fgc := (UiTheme = "Dark") ? "E6E6E6" : "000000"
ddW := 100                                                              ; width of the filter drop-down
SrchFrm := G.Add("Text", "x" SearchX " y8 w300 h" bh " +Border +0x100 Background" bgc)
EdFind := G.Add("Edit", "x" (SearchX + 6) " y8 w288 h" bh " -Multi -E0x200 Background" bgc " c" fgc)
th := TextLineH(EdFind)
EdFind.Move(, 8 + (bh - th) // 2, , th)                                 ; exactly one text line high, centred in the frame
SrchFrm.OnEvent("Click", (*) => EdFind.Focus())
LinkCtls[SrchFrm.Hwnd] := 1                                             ; the dark theme must not repaint these two
LinkCtls[EdFind.Hwnd] := 1
SendMessage(0x1501, 1, StrPtr("Search titles and content"), EdFind)      ; grey hint text (works in AutoHotkey 2.0)
EdFind.OnEvent("Change", Refill)
; where to search: the normal Windows drop-down (All / Title / Content), centred beside the search box
DdFilter := G.Add("DropDownList", "x" (SearchX + 306) " y8 w" ddW " r5 Choose1", ["All", "Title", "Content", "Comments"])
DdFilter.GetPos(, , , &dh)
DdFilter.Move(, 8 + (bh - dh) // 2)
DdFilter.OnEvent("Change", Refill)
LvY := 8 + bh + 12
G.SetFont("s" ts)                                                       ; the text size setting applies to the list only (set before the list is made)
if (UiTheme = "Dark") {
    ; the system list heading cannot be painted dark: in the dark theme the heading is our own bar (click a title to sort)
    HdrH := ts * 2 + 6
    for i, nm in [["Title", 12, 179], ["Content", 192, 289], ["Comments", 482, 129]] {
        t := G.Add("Text", "x" nm[2] " y" LvY " w" nm[3] " h" HdrH " +0x100 +0x200 Background2D2D30 cE6E6E6", "  " nm[1])
        t.OnEvent("Click", ColSort.Bind(i))
        LinkCtls[t.Hwnd] := 1
        HdrCols.Push(t)
    }
    HdrFill := G.Add("Text", "x612 y" LvY " w100 h" HdrH " Background2D2D30")
    LinkCtls[HdrFill.Hwnd] := 1
}
LV := G.Add("ListView", "x10 y" (LvY + HdrH) " w680 h300" (UiTheme = "Dark" ? " -Hdr" : " Grid") " NoSort", ["Title", "Content", "Comments", "id"])      ; sorting is done by ColSort
G.SetFont("s10")
LV.OnEvent("ColClick", (c, n) => ColSort(n))                                         ; light theme: the system heading
LV.OnEvent("DoubleClick", EditSel)
LV.OnNotify(-155, ListKey)
LV.OnEvent("ContextMenu", ListMenu)
SB := G.Add("Text", "x10 y410 w400 h20")
G.OnEvent("Size", OnSize)
G.OnEvent("Close", (*) => ExitApp())
OnSize(g, mm, w, h) {
    if (mm = -1)
        return
    fw := Max(100, w - SearchX - 10 - ddW - 6)
    SrchFrm.Move(, , fw)
    EdFind.Move(, , fw - 12)
    DdFilter.Move(SearchX + fw + 6)
    if HdrH
        HdrFill.Move(, , Max(0, w - 22 - 600))
    LV.Move(, , w - 20, h - LvY - HdrH - 30)
    SB.Move(10, h - 24, w - 20)
}
Refill()
G.Opt("+MinSize" (SearchX + 170 + ddW) "x300")
Skin(G)
G.Show("w" Max(700, SearchX + 200 + ddW) " h440")

; Ctrl+A in the search box selects its text (a plain edit box does not do this by itself)
#HotIf WinActive("ahk_id " G.Hwnd) && ControlGetFocus("ahk_id " G.Hwnd) = EdFind.Hwnd
^a::SendMessage(0xB1, 0, -1, EdFind)                                    ; EM_SETSEL: everything
#HotIf

; Hands the memory the program does not need back to Windows (only idle pages; they return when used)
TrimMemory() {
    DllCall("psapi\EmptyWorkingSet", "Ptr", DllCall("kernel32\GetCurrentProcess", "Ptr"))
}
