;
; Patch-RemoveMCode.ahk - replace OCR.ahk's machine-code blobs with plain,
; readable AutoHotkey.
;
; Why: the upstream library speeds up three image transforms by base64-decoding
; machine code into memory marked PAGE_EXECUTE_READWRITE and calling it. That is
; a legitimate, long-standing AutoHotkey technique and the blobs are benign - but
; "decode a blob and execute it" is very hard to get through a security review,
; and impossible for a reviewer to read.
;
; This rewrites those three transforms as ordinary AHK loops taken directly from
; the C source the library documents in its own comments. After patching, the
; file contains no CryptStringToBinary, no VirtualProtect and no executable
; memory allocation at all.
;
; Cost: the AHK loops are far slower than compiled code (roughly 45x). That only
; matters if you use the grayscale / invertcolors / monochrome options, and
; mostly disappears if you also pass a region rather than scanning a whole
; screen. Verify-MCodeRemoval.ahk measures it on your hardware.
;
;   AutoHotkey64.exe Patch-RemoveMCode.ahk [path\to\OCR.ahk]
;
; Idempotent: running it twice is harmless.
;

#Requires AutoHotkey v2.0
#SingleInstance Force

Main()

Main() {
    file := A_Args.Length ? A_Args[1] : A_ScriptDir . "\Lib\OCR.ahk"
    if (!FileExist(file)) {
        Report("Cannot find " . file, true)
        return
    }

    src := FileRead(file, "UTF-8")
    if (SubStr(src, 1, 1) = Chr(0xFEFF))     ; drop any BOM; FileAppend re-adds one
        src := SubStr(src, 2)
    original := src
    log := "Patching " . file . "`n`n"

    if (InStr(src, "PixelTransforms.ahk")) {
        Report("Already patched - nothing to do.", false)
        return
    }

    ; --- 1. call sites: DllCall(this.XxxMCode, ...) -> plain function calls ---
    changes := 0
    src := RegExReplace(src
        , 'DllCall\(this\.GrayScaleMCode,\s*"ptr",\s*([^,]+),\s*"uint",\s*([^,]+),\s*"uint",\s*([^,]+),\s*"uint",\s*(.+?),\s*"cdecl uint"\)'
        , 'OCR_GrayScale($1, $2, $3, $4)', &n1)
    src := RegExReplace(src
        , 'DllCall\(this\.InvertColorsMCode,\s*"ptr",\s*([^,]+),\s*"uint",\s*([^,]+),\s*"uint",\s*([^,]+),\s*"uint",\s*(.+?),\s*"cdecl uint"\)'
        , 'OCR_InvertColors($1, $2, $3, $4)', &n2)
    src := RegExReplace(src
        , 'DllCall\(this\.MonochromeMCode,\s*"ptr",\s*([^,]+),\s*"uint",\s*([^,]+),\s*"uint",\s*([^,]+),\s*"uint",\s*(.+?),\s*"uint",\s*([^,]+),\s*"cdecl uint"\)'
        , 'OCR_Monochrome($1, $2, $3, $4, $5)', &n3)
    changes := n1 + n2 + n3
    log .= "  call sites rewritten : " . changes . "  (grayscale " . n1
         . ", invert " . n2 . ", monochrome " . n3 . ")`n"

    ; --- 2. the blob assignments themselves ---
    src := RegExReplace(src
        , 'this\.(?:GrayScale|InvertColors|Monochrome)MCode\s*:=\s*this\.MCode\(\(A_PtrSize = 4\)\s*\R?\s*\?\s*"2,x86:[^"]*"\s*\R?\s*:\s*"2,x64:[^"]*"\)'
        , '', &n4)
    log .= "  blob assignments removed: " . n4 . "`n"

    ; --- 3. the MCode decoder/executor itself ---
    stub := "static MCode(mcode) {`n            return 0`n        }"
    src := RegExReplace(src
        , 'static MCode\(mcode\) \{(?:[^{}]|\{[^{}]*\})*\}'
        , stub, &n5)
    log .= "  MCode decoder neutralised: " . n5 . "`n"

    ; --- 4. put the readable replacements in their own file and include it ---
    ; A standalone file is reviewable on its own, and can be loaded without
    ; OCR.ahk - which matters because merely loading OCR.ahk activates WinRT
    ; classes and therefore only works on real Windows.
    transforms := RegExReplace(file, "[^\\/]+$", "") . "PixelTransforms.ahk"
    try FileDelete transforms
    FileAppend PureTransformSource(), transforms, "UTF-8"
    log .= "  wrote " . transforms . "`n"

    ; %A_LineFile% makes the include relative to OCR.ahk itself, not to
    ; whichever script happens to include it
    if (!InStr(src, "PixelTransforms.ahk"))
        src := "#Include " . "%A_LineFile%\..\PixelTransforms.ahk" . "`n" . src

    if (changes < 6 || n4 < 3 || n5 < 1) {
        log .= "`nABORTED - the file did not match what this patch expects.`n"
             . "Upstream has probably changed. The original was left untouched.`n"
        Report(log, true)
        return
    }

    FileCopy file, file . ".orig", 1
    FileDelete file
    FileAppend src, file, "UTF-8"

    ; --- 5. prove the dangerous constructs are gone ---
    check := FileRead(file, "UTF-8")
    log .= "`nverification:`n"
    bad := 0
    for term in ["CryptStringToBinary", "VirtualProtect", "2,x64:", "2,x86:"] {
        present := InStr(check, term) ? true : false
        log .= (present ? "  [FAIL] " : "  [ok ]  ") . term
             . (present ? " still present" : " gone") . "`n"
        if (present)
            bad++
    }
    log .= "`n" . (bad = 0
        ? "Done. Original saved as " . file . ".orig`nNo executable-memory constructs remain."
        : bad . " construct(s) still present - review manually.")
    Report(log, bad > 0)
}

Report(text, isError) {
    try FileDelete A_ScriptDir . "\PatchResults.txt"
    FileAppend text, A_ScriptDir . "\PatchResults.txt"
    if (A_Args.Length > 1 && A_Args[2] = "/quiet")
        ExitApp isError ? 1 : 0
    MsgBox text, "Patch-RemoveMCode", isError ? "Icon!" : "Iconi"
    ExitApp isError ? 1 : 0
}

PureTransformSource() {
    return "
(
;
; PixelTransforms.ahk - generated by Patch-RemoveMCode.ahk. Do not edit by hand.
;
; ============================================================================
; Plain-AutoHotkey replacements for the machine-code blobs the upstream library
; uses. Transcribed from the C source in its own comments, and verified to
; produce byte-identical output - see Verify-MCodeRemoval.ahk.
;
; Buffer layout: 32-bit ARGB pixels, stride bytes per row.
; ============================================================================

OCR_GrayScale(ptr, w, h, stride) {
    offset := stride // 4, yEnd := h * offset, y := 0
    while (y < yEnd) {
        base := ptr + y * 4, x := 0
        while (x < w) {
            p := base + x * 4, argb := NumGet(p, 0, 'UInt')
            a := argb & 0xFF000000
            r := (argb & 0x00FF0000) >> 16, g := (argb & 0x0000FF00) >> 8, b := argb & 0xFF
            gray := (300 * r + 590 * g + 110 * b) >> 10
            NumPut('UInt', (gray << 16) | (gray << 8) | gray | a, p, 0)
            x++
        }
        y += offset
    }
    return 0
}

OCR_InvertColors(ptr, w, h, stride) {
    offset := stride // 4, yEnd := h * offset, y := 0
    while (y < yEnd) {
        base := ptr + y * 4, x := 0
        while (x < w) {
            p := base + x * 4, argb := NumGet(p, 0, 'UInt')
            a := argb & 0xFF000000
            r := (argb & 0x00FF0000) >> 16, g := (argb & 0x0000FF00) >> 8, b := argb & 0xFF
            NumPut('UInt', ((255 - r) << 16) | ((255 - g) << 8) | (255 - b) | a, p, 0)
            x++
        }
        y += offset
    }
    return 0
}

OCR_Monochrome(ptr, w, h, stride, threshold) {
    offset := stride // 4, yEnd := h * offset, y := 0
    while (y < yEnd) {
        base := ptr + y * 4, x := 0
        while (x < w) {
            p := base + x * 4, argb := NumGet(p, 0, 'UInt')
            r := (argb & 0x00FF0000) >> 16, g := (argb & 0x0000FF00) >> 8, b := argb & 0xFF
            lum := (77 * r + 150 * g + 29 * b) >> 8
            NumPut('UInt', (lum > threshold) ? 0xFFFFFFFF : 0xFF000000, p, 0)
            x++
        }
        y += offset
    }
    return 0
}
)"
}
