;
; Setup.ahk - fetch the OCR library and choose how the image transforms are
; implemented.
;
; Run this once. It downloads Lib\OCR.ahk and then asks whether to keep the
; upstream machine-code blobs or replace them with readable AutoHotkey. Both
; are supported and behave identically - see the README for the trade-off.
;
;   AutoHotkey64.exe Setup.ahk              ask
;   AutoHotkey64.exe Setup.ahk /keep-mcode  fastest, keeps upstream as-is
;   AutoHotkey64.exe Setup.ahk /readable    no executable memory, slower transforms
;

#Requires AutoHotkey v2.0
#SingleInstance Force

Main()

Main() {
    lib := A_ScriptDir . "\Lib\OCR.ahk"
    url := "https://raw.githubusercontent.com/Descolada/OCR/main/Lib/OCR.ahk"

    if (!DirExist(A_ScriptDir . "\Lib"))
        DirCreate A_ScriptDir . "\Lib"

    if (!FileExist(lib)) {
        try {
            Download url, lib
        } catch as e {
            MsgBox "Could not download the OCR library:`n`n" . e.Message
                . "`n`nIf your network blocks it, download this file by hand and save it as:`n"
                . lib . "`n`n" . url, "Setup", "Icon!"
            ExitApp 2
        }
    }
    if (!FileExist(lib)) {
        MsgBox "Lib\OCR.ahk is still missing.", "Setup", "Icon!"
        ExitApp 2
    }

    mode := ""
    for arg in A_Args {
        if (arg = "/keep-mcode")
            mode := "keep"
        else if (arg = "/readable")
            mode := "readable"
    }

    if (mode = "") {
        r := MsgBox("
        (
        The OCR library speeds up three image transforms with embedded machine code.

        KEEP IT (Yes)
          Fastest. Transforms take milliseconds.
          Uses base64-decoded code in executable memory, which some security
          reviews object to.

        REPLACE IT (No)
          No executable memory, nothing to explain to a security team.
          The three transforms become plain AutoHotkey and get slower - about
          30ms on a small region, 1.7s on a full screen.

        This only matters if you use the grayscale, invertcolors or monochrome
        options. They are off by default, so most setups are unaffected either way.

        Keep the machine code?
        )", "Setup - choose transform implementation", "YesNoCancel Icon?")
        if (r = "Cancel") {
            ExitApp 1
        }
        mode := (r = "Yes") ? "keep" : "readable"
    }

    if (mode = "keep") {
        MsgBox "Setup complete.`n`nLib\OCR.ahk is the upstream version, machine code intact.`n"
             . "Run Doctor.ahk next to check this machine.", "Setup", "Iconi"
        ExitApp 0
    }

    RunWait '"' . A_AhkPath . '" "' . A_ScriptDir . '\Patch-RemoveMCode.ahk" "'
           . lib . '" /quiet', A_ScriptDir, "Hide"
    report := FileExist(A_ScriptDir . "\PatchResults.txt")
        ? FileRead(A_ScriptDir . "\PatchResults.txt") : "(no report produced)"
    MsgBox "Setup complete.`n`n" . report, "Setup", "Iconi"
    ExitApp 0
}
