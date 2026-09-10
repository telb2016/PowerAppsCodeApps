;
; Verify-MCodeRemoval.ahk - prove the plain-AutoHotkey transforms behave exactly
; like the machine code they replaced, and measure what that costs.
;
; Reads the original blobs out of Lib\OCR.ahk.orig (saved by
; Patch-RemoveMCode.ahk), compiles them the way upstream did, then runs both
; implementations over identical pixel buffers and compares every pixel.
;
;   AutoHotkey64.exe Verify-MCodeRemoval.ahk
;
; Exits 0 if every transform matches byte for byte.
;

#Requires AutoHotkey v2.0
#SingleInstance Force
; Only the standalone transforms - deliberately NOT OCR.ahk, which activates
; WinRT classes the moment it loads and so only runs on real Windows.
#Include Lib\PixelTransforms.ahk

Main()

Main() {
    orig := A_ScriptDir . "\Lib\OCR.ahk.orig"
    out := "MCode removal verification`n`n"
    if (!FileExist(orig)) {
        Finish(out . "  Lib\OCR.ahk.orig not found - run Patch-RemoveMCode.ahk first.`n", 1)
        return
    }

    src := FileRead(orig, "UTF-8")
    arch := (A_PtrSize = 8) ? "x64" : "x86"
    blobs := Map()
    for name in ["GrayScale", "InvertColors", "Monochrome"] {
        if (RegExMatch(src, name . 'MCode\s*:=\s*this\.MCode\([\s\S]{0,400}?"2,' arch ':([A-Za-z0-9+/=]+)"', &m))
            blobs[name] := "2," . arch . ":" . m[1]
    }
    out .= "  blobs recovered from the original: " . blobs.Count . " of 3`n`n"
    if (blobs.Count < 3) {
        Finish(out . "  Could not recover all blobs - cannot verify.`n", 1)
        return
    }

    W := 240, H := 180, stride := W * 4, n := W * H, bytes := n * 4
    fails := 0
    out .= "  differential test over " . n . " pixels each:`n"

    for name, blob in blobs {
        mc := CompileMCode(blob)
        if (!mc) {
            out .= "    [FAIL] " . name . ": original blob would not compile here`n"
            fails++
            continue
        }
        a := Buffer(bytes), b := Buffer(bytes)
        FillPattern(a, n)
        DllCall("ntdll\memcpy", "ptr", b, "ptr", a, "ptr", bytes, "cdecl")

        if (name = "Monochrome") {
            DllCall(mc, "ptr", a, "uint", W, "uint", H, "uint", stride, "uint", 128, "cdecl uint")
            OCR_Monochrome(b.Ptr, W, H, stride, 128)
        } else if (name = "GrayScale") {
            DllCall(mc, "ptr", a, "uint", W, "uint", H, "uint", stride, "cdecl uint")
            OCR_GrayScale(b.Ptr, W, H, stride)
        } else {
            DllCall(mc, "ptr", a, "uint", W, "uint", H, "uint", stride, "cdecl uint")
            OCR_InvertColors(b.Ptr, W, H, stride)
        }

        diff := FirstDifference(a, b, n)
        if (diff = 0)
            out .= "    [ok ] " . name . ": byte-identical`n"
        else {
            out .= "    [FAIL] " . name . ": differs at pixel " . diff . "`n"
            fails++
        }
    }

    ; --- what the readability costs, on this machine ---
    out .= "`n  speed on this machine (1280x720):`n"
    TW := 1280, TH := 720, ts := TW * 4, tn := TW * TH
    buf := Buffer(tn * 4)
    mc := CompileMCode(blobs["GrayScale"])
    if (mc) {
        FillPattern(buf, tn)
        t := A_TickCount
        DllCall(mc, "ptr", buf, "uint", TW, "uint", TH, "uint", ts, "cdecl uint")
        mct := A_TickCount - t
        out .= "    original machine code : " . mct . " ms`n"
    }
    FillPattern(buf, tn)
    t := A_TickCount
    OCR_GrayScale(buf.Ptr, TW, TH, ts)
    pt := A_TickCount - t
    out .= "    plain AutoHotkey      : " . pt . " ms`n"
    out .= "`n    This cost applies ONLY when you use grayscale / invertcolors /`n"
    out .= "    monochrome. It scales with area, so passing a region rather than`n"
    out .= "    scanning the whole screen keeps it small.`n"

    out .= "`n" . (fails = 0
        ? "All transforms verified identical. The replacement is behaviour-preserving."
        : fails . " transform(s) DIFFER - do not ship this patch.")
    Finish(out, fails)
}

CompileMCode(mcode) {
    static e := Map('1', 4, '2', 1), c := (A_PtrSize = 8) ? "x64" : "x86"
    if (!RegExMatch(mcode, "^([0-9]+),(" c ":|.*?," c ":)([^,]+)", &m))
        return 0
    if (!DllCall("crypt32\CryptStringToBinary", "str", m.3, "uint", 0, "uint", e[m.1], "ptr", 0, "uint*", &s := 0, "ptr", 0, "ptr", 0))
        return 0
    p := DllCall("GlobalAlloc", "uint", 0, "ptr", s, "ptr")
    if (c = "x64")
        DllCall("VirtualProtect", "ptr", p, "ptr", s, "uint", 0x40, "uint*", &op := 0)
    if (DllCall("crypt32\CryptStringToBinary", "str", m.3, "uint", 0, "uint", e[m.1], "ptr", p, "uint*", &s, "ptr", 0, "ptr", 0))
        return p
    DllCall("GlobalFree", "ptr", p)
    return 0
}

FillPattern(buf, n) {
    seed := 987654321
    loop n {
        seed := Mod(seed * 1103515245 + 12345, 0x100000000)
        NumPut("UInt", seed & 0xFFFFFFFF, buf, (A_Index - 1) * 4)
    }
}

FirstDifference(b1, b2, pixels) {
    loop pixels
        if (NumGet(b1, (A_Index - 1) * 4, "UInt") != NumGet(b2, (A_Index - 1) * 4, "UInt"))
            return A_Index
    return 0
}

Finish(text, code) {
    try FileDelete A_ScriptDir . "\VerifyResults.txt"
    FileAppend text, A_ScriptDir . "\VerifyResults.txt"
    for arg in A_Args
        if (arg = "/quiet")
            ExitApp code
    MsgBox text, "Verify MCode Removal", code ? "Icon!" : "Iconi"
    ExitApp code
}
