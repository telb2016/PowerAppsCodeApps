;
; Example_Hotkeys.ahk - practical usage.
;
; This is the shape most real automations take: AutoHotkey does what it is best
; at - hotkeys, window management, sending keys - and calls into OCR only for
; the one question it cannot answer itself, "where on screen is this text?".
;

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include FindText.ahk

; Ctrl+Alt+S - find "Save" and click it
^!s:: {
    if (!ClickText("Save"))
        TrayTip "'Save' is not on screen", "FindText"
}

; Ctrl+Alt+T - search only the top strip of the screen.
; Restricting the area is the single biggest speed-up available, and it also
; removes false matches from elsewhere on screen.
^!t:: {
    hit := ClickText("File", { region: [0, 0, A_ScreenWidth, 120] })
    TrayTip hit ? "clicked at " . hit.cx . "," . hit.cy : "not found", "FindText"
}

; Ctrl+Alt+W - wait for a status message, then carry on
^!w:: {
    hit := WaitForText("Upload complete", 120)
    TrayTip hit ? "finished" : "timed out after 120s", "FindText"
}

; Ctrl+Alt+C - click the checkbox sitting to the LEFT of its label.
; OCR returns the box of the text, not the widget, so nudge the click point.
^!c:: {
    ClickText("Remember me", { offset: [-24, 0] })
}

; Ctrl+Alt+N - act on the 2nd match rather than the first
^!n:: {
    ClickText("Delete", { index: 2 })
}

; Ctrl+Alt+R - regex, for text that varies
^!r:: {
    hit := FindOnScreen("Invoice #\d+", { regex: true })
    TrayTip hit ? "found: " . hit.text : "no invoice on screen", "FindText"
}

; Ctrl+Alt+D - dump what OCR actually reads.
; Run this first when a search is not matching: it is almost always that the
; text reads differently than you expect, not that the search is broken.
^!d:: {
    out := ""
    for line in ReadScreen()
        out .= line.x . "," . line.y . "  " . line.text . "`n"
    A_Clipboard := out
    MsgBox (out = "" ? "nothing recognised" : out), "Screen text (copied to clipboard)"
}

; Ctrl+Alt+I - white text on a dark toolbar needs the polarity flipped
^!i:: {
    hit := FindOnScreen("File", { region: [0, 0, A_ScreenWidth, 60], invert: true })
    TrayTip hit ? "found at " . hit.cx . "," . hit.cy : "not found", "FindText"
}

; Ctrl+Alt+Q - quit
^!q:: ExitApp
