;
; Tests.ahk - exercise the matching logic without a screen or an OCR engine.
;
; Recognition results are built by hand here, so these assertions run anywhere
; AutoHotkey runs, including under Wine on a build machine. They cover the part
; that is genuinely easy to get wrong: turning per-word boxes into one box for
; a phrase, ordering, indexing, and the whitespace tolerance that real OCR
; output makes necessary.
;
;   AutoHotkey64.exe /ErrorStdOut Tests.ahk
;
; Writes TestResults.txt and exits 0 on success, 1 on any failure.
;

#Requires AutoHotkey v2.0
#Include Lib\FindTextCore.ahk

global gOut := "", gFail := 0

Main()

Main() {
    Log("FindText core tests  (AHK " . A_AhkVersion . ")`n")

    screen := MockScreen()

    ; --- multi-word phrases must resolve to ONE box spanning both words -----
    hits := Find(screen, "Save As")
    Check("'Save As' finds exactly 1 match", hits.Length, 1)
    if (hits.Length) {
        ; "Save" is at x=77 w=35, "As" at x=120 w=15  ->  union 77..135
        Check("  box starts at first word", hits[1].x, 77)
        Check("  box ends at last word", hits[1].x + hits[1].w, 135)
        Check("  centre is between them", hits[1].cx, 106)
        Check("  matched text", hits[1].text, "Save As")
    }

    ; --- a substring inside one word keeps that word's box ------------------
    hits := Find(screen, "Cancel")
    Check("'Cancel' finds 1 match", hits.Length, 1)
    if (hits.Length)
        Check("  centre", hits[1].cx, 300)

    ; --- multiple hits, ordered top-to-bottom ------------------------------
    hits := Find(screen, "Save")
    Check("'Save' finds 2 matches", hits.Length, 2)
    if (hits.Length = 2) {
        Check("  first is the higher one", hits[1].y, 135)
        Check("  second is lower", hits[2].y, 323)
        Check("  count is reported", hits[1].count, 2)
    }

    ; --- the whitespace lesson: real OCR drops spaces on narrow crops -------
    hits := Find(screen, "Save the file")
    Check("phrase matches when OCR kept the spaces", hits.Length >= 1, true)

    narrow := MockNarrowCrop()          ; same words, recognised as "Savethefile"
    hits := Find(narrow, "Save the file")
    Check("phrase still matches when OCR DROPPED the spaces", hits.Length, 1)

    hits := Find(narrow, "Save the file", { exactSpace: true })
    Check("  ...and exactSpace correctly refuses it", hits.Length, 0)

    ; --- regex --------------------------------------------------------------
    hits := Find(screen, "Sav\w+ As", { regex: true })
    Check("regex 'Sav\\w+ As' matches", hits.Length, 1)

    hits := Find(screen, "Item\s*\d+", { regex: true })
    Check("regex with a digit group matches", hits.Length, 1)
    if (hits.Length)
        Check("  captured text", hits[1].text, "Item 42")

    ; --- case sensitivity ---------------------------------------------------
    Check("case-insensitive by default", Find(screen, "cancel").Length, 1)
    Check("caseSense:true respects case", Find(screen, "cancel", { caseSense: true }).Length, 0)

    ; --- absent text must not be invented -----------------------------------
    Check("absent text finds nothing", Find(screen, "ThisIsNotOnScreen").Length, 0)

    ; --- regex metacharacters in a plain needle must be literal -------------
    hits := Find(screen, "Total (USD)")
    Check("parentheses in a plain needle are literal", hits.Length, 1)

    ; --- a needle spanning two lines must NOT match -------------------------
    Check("no match across separate lines", Find(screen, "Cancel Upload").Length, 0)

    Log("`n" . (gFail = 0 ? "All tests passed." : gFail . " test(s) FAILED."))
    try FileDelete "TestResults.txt"
    FileAppend gOut, "TestResults.txt"
    ExitApp gFail = 0 ? 0 : 1
}

Find(result, needle, opts := 0) {
    return _FT_Match(result, needle, _FT_Options(opts))
}

Check(label, got, want) {
    global gFail
    ok := (got = want)
    if (!ok)
        gFail++
    Log((ok ? "  [ok ] " : "  [FAIL] ") . label
        . (ok ? "" : "   got=" . _Show(got) . " want=" . _Show(want)))
}

_Show(v) {
    if (v = true && v != 1)
        return "true"
    return IsObject(v) ? "<object>" : "'" . v . "'"
}

Log(line) {
    global gOut
    gOut .= line . "`n"
}

;-----------------------------------------------------------------------------
; Hand-built recognition results, shaped like what the OCR engine returns:
; result.Lines[] -> line.Words[] -> word.Text / .x / .y / .w / .h
;-----------------------------------------------------------------------------

MockScreen() {
    return { Lines: [
        Line([ W("Document", 22, 18, 80, 15), W("Editor", 108, 18, 55, 15) ]),
        Line([ W("Save", 77, 135, 35, 11),  W("As", 120, 135, 15, 11) ]),
        Line([ W("Cancel", 276, 135, 49, 11) ]),
        Line([ W("Upload", 77, 235, 55, 14), W("complete", 138, 235, 64, 14) ]),
        Line([ W("Save", 61, 323, 35, 11), W("the", 100, 323, 25, 11), W("file", 129, 323, 24, 11) ]),
        Line([ W("Item", 61, 380, 30, 11), W("42", 95, 380, 18, 11) ]),
        Line([ W("Total", 61, 420, 35, 11), W("(USD)", 100, 420, 40, 11) ])
    ]}
}

; What the same line looks like when OCR is given a narrow crop: the spaces
; are gone and it comes back as a single word.
MockNarrowCrop() {
    return { Lines: [ Line([ W("Savethefile", 61, 323, 84, 11) ]) ] }
}

Line(words) {
    return { Words: words }
}

W(text, x, y, w, h) {
    return { Text: text, x: x, y: y, w: w, h: h }
}
