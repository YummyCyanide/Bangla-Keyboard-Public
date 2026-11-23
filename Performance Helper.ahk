; ===========================================================================
;  Performance Helper
;  A tiny helper that Bangla Keyboard starts by itself (Settings > Extra Settings). It sleeps until
;  Bangla Keyboard ends. If that was a normal exit (tray menu Exit, closed, Windows shutdown) it
;  quits too. If Bangla Keyboard stopped by itself (crash, killed), it starts it again.
;  After 3 restarts within 2 minutes it gives up and tells you (so it can never loop).
;
;  It uses almost no CPU while waiting. Turn it off in Settings > Extra Settings.
;  Arguments (given by Bangla Keyboard): process id, AutoHotkey exe ("-" when compiled),
;  script/exe path, tray icon (1 = show, 0 = hide).
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
ListLines(0)
KeyHistory(0)

if (A_Args.Length < 3)
    ExitApp()
global gPid := Integer(A_Args[1])
global gAhk := (A_Args[2] = "-") ? "" : A_Args[2]
global gScript := A_Args[3]
global gTray := (A_Args.Length >= 4 && A_Args[4] = "1")
global gDir := A_AppData "\Bangla Keyboard"
global gFlag := gDir "\clean-exit.flag"          ; Bangla Keyboard writes its process id here on a normal exit
global gHist := gDir "\PerformanceHelper.dat"
global gLog := gDir "\helper.log"
global gWaitMs := gTray ? 250 : 2000             ; how often it wakes to stay responsive (no real CPU use either way)

if gTray {
    A_IconHidden := false
    A_IconTip := "Performance Helper`nKeeps Bangla Keyboard running"
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Performance Helper", (*) => 0)
    A_TrayMenu.Disable("Performance Helper")
    A_TrayMenu.Add("Stop Performance Helper", (*) => ExitApp())
}

Loop {
    WaitForEnd(gPid)
    if CleanExit(gPid)
        ExitApp()
    if !CanRestart() {
        Note("Gave up: 3 restarts within 2 minutes")
        MsgBox("Bangla Keyboard stopped unexpectedly several times in a row, so it was not started again.`n`nThe details are in error.log in:`n" gDir, "Performance Helper", 0x10 | 0x40000)
        ExitApp()
    }
    Note("Bangla Keyboard stopped unexpectedly: starting it again")
    gPid := StartMain()
}

; sleeps until the process ends
WaitForEnd(pid) {
    h := pid ? DllCall("OpenProcess", "UInt", 0x100000, "Int", 0, "UInt", pid, "Ptr") : 0      ; SYNCHRONIZE
    if !h {
        while (pid && ProcessExist(pid))                  ; no access to wait on it (e.g. it runs elevated): look every 2 seconds
            Sleep(2000)
        return
    }
    while (DllCall("WaitForSingleObject", "Ptr", h, "UInt", gWaitMs, "UInt") = 0x102)      ; WAIT_TIMEOUT
        Sleep(1)
    DllCall("CloseHandle", "Ptr", h)
}

; Bangla Keyboard leaves its process id in the flag file when it ends normally
CleanExit(pid) {
    try {
        if (FileExist(gFlag) && Trim(FileRead(gFlag)) = String(pid)) {
            FileDelete(gFlag)
            return true
        }
    }
    return false
}

; at most 3 restarts within 120 seconds (the times are kept in a file, so a restarted helper still knows them)
CanRestart() {
    now := A_Now
    keep := ""
    n := 0
    txt := ""
    try txt := IniRead(gHist, "Restarts", "Times", "")
    for t in StrSplit(txt, ",") {
        if (t != "" && IsInteger(t) && StrLen(t) = 14 && DateDiff(now, t, "Seconds") < 120) {
            keep .= (keep = "" ? "" : ",") t
            n += 1
        }
    }
    if (n >= 3)
        return false
    keep .= (keep = "" ? "" : ",") now
    try IniWrite(keep, gHist, "Restarts", "Times")
    return true
}

; starts Bangla Keyboard; returns its process id (0 if it did not come up)
StartMain() {
    SplitPath(gScript, , &dir)
    cmd := (gAhk = "") ? '"' gScript '"' : '"' gAhk '" "' gScript '"'
    newPid := 0
    try {
        Run(cmd, dir, , &newPid)
    } catch {
        Note("Could not start: " gScript)
        return 0
    }
    if newPid
        return newPid
    DetectHiddenWindows(true)                             ; no id from Run: look for the program's hidden window
    SetTitleMatchMode(2)
    Loop 30 {
        Sleep(500)
        hwnd := WinExist(gScript " ahk_class AutoHotkey")
        if hwnd
            return WinGetPID(hwnd)
    }
    return 0
}

Note(text) {
    try {
        if (FileExist(gLog) && FileGetSize(gLog) > 65536)
            FileMove(gLog, gDir "\helper.old.log", 1)
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " text "`n", gLog, "UTF-8")
    }
}
