;
; FindText.ahk - find text on screen and move/click the mouse there.
;
; Uses the Windows built-in OCR engine (Windows.Media.Ocr) - the same engine a
; C# app reaches via OcrEngine.TryCreateFromUserProfileLanguages(). Nothing is
; installed and nothing is bundled: the recognition happens inside Windows.
;
; Requires Descolada's OCR.ahk in Lib\ (see README.md), which does the WinRT
; COM activation. This file is the practical layer on top of it.
;
; Everything here returns plain objects and never throws on "not found", so it
; drops into existing scripts without try/catch noise.
;

#Requires AutoHotkey v2.0
#Include Lib\OCR.ahk
#Include Lib\FindTextCore.ahk

;-----------------------------------------------------------------------------
; Public API
;-----------------------------------------------------------------------------

/**
 * Find text on screen.
 *
 * @param needle  Text to look for. Spaces match any amount of whitespace
 *                (including none) unless opts.exactSpace is set - OCR spacing
 *                is not reliable enough to match literally.
 * @param opts    Optional settings object:
 *                  region     [x, y, w, h]  search only this rectangle (much faster)
 *                  win        WinTitle      search only this window instead of the screen
 *                  regex      true          treat needle as an AHK regex
 *                  caseSense  true          case-sensitive match
 *                  exactSpace true          require literal spacing
 *                  index      n             which match to return (1-based, default 1)
 *                  scale      n             upscale before OCR; raise for small text
 *                  invert     true          for light text on a dark background
 *                  grayscale  true          drop colour before OCR
 *                  lang       "en-US"       BCP-47 language tag
 * @returns  {x, y, w, h, cx, cy, text, count} or 0 when not found.
 *           cx/cy is the centre - the point to click.
 */
FindOnScreen(needle, opts := 0) {
    o := _FT_Options(opts)
    result := _FT_Capture(o)
    if (!result)
        return 0

    hits := _FT_Match(result, needle, o)
    if (hits.Length = 0 || o.index > hits.Length)
        return 0
    return hits[o.index]
}

/**
 * Find every occurrence. Same options as FindOnScreen; ignores opts.index.
 * @returns array of match objects, ordered top-to-bottom then left-to-right.
 */
FindAllOnScreen(needle, opts := 0) {
    o := _FT_Options(opts)
    result := _FT_Capture(o)
    return result ? _FT_Match(result, needle, o) : []
}

/**
 * Find text and move the cursor to it.
 * @param opts  as FindOnScreen, plus:
 *                offset [dx, dy]  nudge the point - OCR returns the box of the
 *                                 TEXT, so use this to hit a checkbox or field
 *                                 sitting beside its label
 *                speed  0-100     MouseMove speed (0 = instant)
 * @returns the match object, or 0 if the text was not found.
 */
MoveToText(needle, opts := 0) {
    o := _FT_Options(opts)
    hit := FindOnScreen(needle, opts)
    if (!hit)
        return 0
    MouseMove hit.cx + o.offset[1], hit.cy + o.offset[2], o.speed
    return hit
}

/**
 * Find text, move there and click.
 * @param opts  as MoveToText, plus:
 *                button "Left"|"Right"|"Middle"
 *                count  click count
 * @returns the match object, or 0 if the text was not found.
 */
ClickText(needle, opts := 0) {
    o := _FT_Options(opts)
    hit := MoveToText(needle, opts)
    if (!hit)
        return 0
    Sleep 50                      ; let the UI register the hover first
    Click o.button, o.count
    return hit
}

/**
 * Wait for text to appear, then optionally act on it.
 *
 * @param timeoutSec  how long to keep looking. 0 = check once.
 * @param opts        as ClickText, plus:
 *                      click    true   click it once found
 *                      move     true   move to it once found
 *                      interval ms     how often to re-check (default 500)
 * @returns the match object, or 0 on timeout.
 */
WaitForText(needle, timeoutSec := 30, opts := 0) {
    o := _FT_Options(opts)
    deadline := A_TickCount + (timeoutSec * 1000)
    loop {
        if (o.click)
            hit := ClickText(needle, opts)
        else if (o.move)
            hit := MoveToText(needle, opts)
        else
            hit := FindOnScreen(needle, opts)
        if (hit)
            return hit
        if (A_TickCount >= deadline)
            return 0
        Sleep o.interval
    }
}

/**
 * Every line of text currently on screen. Useful when working out what OCR
 * actually reads, before writing a search for it.
 * @returns array of {text, x, y, w, h}
 */
ReadScreen(opts := 0) {
    o := _FT_Options(opts)
    result := _FT_Capture(o)
    lines := []
    if (!result)
        return lines
    for line in result.Lines
        lines.Push({ text: line.Text, x: line.x, y: line.y, w: line.w, h: line.h })
    return lines
}

;-----------------------------------------------------------------------------
; Capture - the only part that touches the screen
;-----------------------------------------------------------------------------

; Build the option object OCR.ahk expects, leaving out anything unset so the
; library keeps its own defaults.
_FT_OcrOptions(o) {
    ocrOpts := {}
    if (o.scale)
        ocrOpts.scale := o.scale
    if (o.invert)
        ocrOpts.invertcolors := true
    if (o.grayscale)
        ocrOpts.grayscale := true
    if (o.lang != "")
        ocrOpts.lang := o.lang
    return ocrOpts
}

_FT_Capture(o) {
    ocrOpts := _FT_OcrOptions(o)
    try {
        if (o.win)
            return OCR.FromWindow(o.win, ocrOpts)
        if (IsObject(o.region))
            return OCR.FromRect(o.region[1], o.region[2], o.region[3], o.region[4], ocrOpts)
        return OCR.FromDesktop(ocrOpts)
    } catch as e {
        ; A missing language pack is the usual cause and is worth surfacing
        ; loudly rather than looking like "text not found".
        throw Error("OCR failed: " . e.Message
                  . "`n`nRun Doctor.ahk to check the OCR engine and languages.", -1)
    }
}

