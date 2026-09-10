;
; Probe.ahk - report what this machine can actually do, without asserting.
;
; Run on a CI runner before Doctor.ahk: a runner with no OCR language pack, or
; no interactive desktop, fails the doctor for environmental reasons rather
; than code reasons, and this tells the two apart.
;
#Requires AutoHotkey v2.0
#Include FindText.ahk

out := "AutoHotkey : " . A_AhkVersion . " (" . (A_PtrSize = 8 ? "64" : "32") . "-bit)`n"
out .= "OS         : " . A_OSVersion . "`n"
out .= "Screen     : " . A_ScreenWidth . "x" . A_ScreenHeight . " @ " . A_ScreenDPI . " DPI`n"
out .= "Elevated   : " . (A_IsAdmin ? "yes" : "no") . "`n"

out .= "OCR langs  : "
try {
    langs := Trim(OCR.GetAvailableLanguages())
    out .= (langs = "" ? "NONE INSTALLED" : StrReplace(langs, "`n", ", ")) . "`n"
} catch as e {
    out .= "ERROR - " . e.Message . "`n"
}

; can we capture and recognise anything at all on this desktop?
out .= "Capture    : "
try {
    lines := ReadScreen({ region: [0, 0, Min(A_ScreenWidth, 800), Min(A_ScreenHeight, 600)] })
    out .= "ok, " . lines.Length . " line(s) of text recognised on the desktop`n"
} catch as e {
    out .= "FAILED - " . e.Message . "`n"
}

try FileDelete "ProbeResults.txt"
FileAppend out, "ProbeResults.txt"
ExitApp 0
