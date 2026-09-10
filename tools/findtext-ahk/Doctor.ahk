;
; Doctor.ahk - verify that OCR, capture and the pointer all work on this machine.
;
; Run this first, on one machine, before deploying anything. It draws a window
; with known text at known coordinates, OCRs the screen, and checks that the
; text is found where it was actually drawn. That catches the three things that
; realistically go wrong - no OCR language installed, DPI scaling throwing
; coordinates off, and input being blocked - without guessing.
;

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include FindText.ahk

Main()

Main() {
    report := ""
    failures := 0

    report .= "AutoHotkey  : " . A_AhkVersion . " (" . (A_PtrSize = 8 ? "64" : "32") . "-bit)`n"
    report .= "OS          : " . A_OSVersion . "`n"
    report .= "Elevated    : " . (A_IsAdmin ? "yes" : "no") . "`n"
    report .= "Screen DPI  : " . A_ScreenDPI
              . (A_ScreenDPI != 96 ? "  (scaled display - the position test below is what proves coordinates are right)" : "")
              . "`n"
    report .= "Screen      : " . A_ScreenWidth . "x" . A_ScreenHeight . "`n`n"

    ; --- OCR engine + languages -------------------------------------------
    report .= "OCR engine:`n"
    try {
        langs := OCR.GetAvailableLanguages()
        if (Trim(langs) = "") {
            failures++
            report .= "  FAIL  no OCR languages installed`n"
            report .= "        Settings > Time & language > Language & region >`n"
            report .= "        (your language) > ... > Language options > install`n"
        } else {
            report .= "  OK    Windows OCR available`n"
            report .= "        languages: " . StrReplace(Trim(langs), "`n", ", ") . "`n"
        }
    } catch as e {
        failures++
        report .= "  FAIL  could not reach the OCR engine: " . e.Message . "`n"
    }
    report .= "`n"

    ; --- capture + recognition + coordinate accuracy -----------------------
    report .= "Capture and coordinates:`n"
    try {
        result := SelfTest()
        report .= result.text
        failures += result.failures
    } catch as e {
        failures++
        report .= "  FAIL  self-test could not run: " . e.Message . "`n"
    }
    report .= "`n"

    ; --- pointer ------------------------------------------------------------
    report .= "Pointer:`n"
    try {
        MouseGetPos &startX, &startY
        MouseMove 120, 90, 0
        Sleep 60
        MouseGetPos &gotX, &gotY
        MouseMove startX, startY, 0
        if (Abs(gotX - 120) <= 2 && Abs(gotY - 90) <= 2) {
            report .= "  OK    cursor moves where asked`n"
        } else {
            failures++
            report .= "  FAIL  asked for 120,90 but landed at " . gotX . "," . gotY . "`n"
            report .= "        Something is intercepting input, or the display is scaled`n"
            report .= "        and coordinates are being translated.`n"
        }
    } catch as e {
        failures++
        report .= "  FAIL  " . e.Message . "`n"
    }
    report .= "  note: Windows (UIPI) only allows input into windows running at the`n"
    report .= "        same or lower privilege. If a target app runs as administrator`n"
    report .= "        and this script does not, clicks are discarded silently.`n"
    if (!A_IsAdmin)
        report .= "        This script is NOT elevated - fine unless you automate an elevated app.`n"

    report .= "`n" . (failures = 0
        ? "All checks passed. This machine is good to go."
        : failures . " check(s) FAILED - see above.")

    MsgBox report, "FindText Doctor", failures = 0 ? "Iconi" : "Icon!"
    ExitApp failures = 0 ? 0 : 1
}

;
; Draw known text at known screen coordinates, OCR it, and compare. This is the
; only check that actually proves the whole chain works: if DPI scaling is
; mistranslating coordinates, the text is still found but in the wrong place,
; and only a position comparison catches that.
;
SelfTest() {
    text := "", failures := 0

    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "FindTextSelfTest")
    g.BackColor := "FFFFFF"
    g.SetFont("s11 cBlack", "Segoe UI")

    ; auto-sized (no w/h) so each control hugs its text - that makes the
    ; control rectangle a fair stand-in for the text's true position
    ctlSave   := g.Add("Text", "x30 y25", "Save As")
    ctlCancel := g.Add("Text", "x220 y25", "Cancel")
    ctlUpload := g.Add("Text", "x30 y85", "Upload complete")

    g.Show("x150 y150 w460 h150 NoActivate")
    Sleep 400                                  ; let it paint before capturing

    try {
        WinGetClientPos &clientX, &clientY, &clientW, &clientH, g.Hwnd

        checks := [ { ctl: ctlSave,   needle: "Save As" }
                  , { ctl: ctlCancel, needle: "Cancel" }
                  , { ctl: ctlUpload, needle: "Upload complete" } ]

        for check in checks {
            check.ctl.GetPos(&cx, &cy, &cw, &ch)
            wantX := clientX + cx + (cw // 2)
            wantY := clientY + cy + (ch // 2)

            hit := FindOnScreen(check.needle, { region: [clientX, clientY, clientW, clientH] })
            if (!hit) {
                failures++
                text .= "  FAIL  '" . check.needle . "' was on screen but not recognised`n"
                continue
            }

            off := Round(Sqrt((hit.cx - wantX) ** 2 + (hit.cy - wantY) ** 2))
            if (off <= 20) {
                text .= "  OK    '" . check.needle . "' found at " . hit.cx . "," . hit.cy
                     . "  (" . off . "px from where it was drawn)`n"
            } else {
                failures++
                text .= "  FAIL  '" . check.needle . "' found at " . hit.cx . "," . hit.cy
                     . " but was drawn at " . wantX . "," . wantY
                     . " - off by " . off . "px`n"
                text .= "        A large, consistent offset usually means display scaling.`n"
            }
        }

        ; multi-word phrases are the case that naive implementations get wrong:
        ; the engine returns one box per word, not per phrase
        hit := FindOnScreen("Upload complete", { region: [clientX, clientY, clientW, clientH] })
        if (hit && hit.w > 0) {
            text .= "  OK    multi-word phrase returns a single box (" . hit.w . "px wide)`n"
        } else {
            failures++
            text .= "  FAIL  multi-word phrase did not resolve to one box`n"
        }

        ; and text that is not present must not be invented
        if (FindOnScreen("ThisTextIsNotOnScreen", { region: [clientX, clientY, clientW, clientH] })) {
            failures++
            text .= "  FAIL  matched text that is not on screen`n"
        } else {
            text .= "  OK    absent text correctly reports not found`n"
        }
    } finally {
        g.Destroy()                            ; always clean up the test window
    }

    return { text: text, failures: failures }
}
