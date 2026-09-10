; FindTextCore.ahk - matching logic, with no dependency on OCR or the screen.
;
; Kept separate so it can be exercised without a display: Tests.ahk feeds it
; recognition results built by hand and checks the boxes that come back.
;
; Anything here is pure computation - given the same words in, you get the same
; matches out.

_FT_Options(opts) {
    o := { region: 0, win: 0, regex: false, caseSense: false, exactSpace: false
         , index: 1, scale: 0, invert: false, grayscale: false, lang: ""
         , offset: [0, 0], speed: 2, button: "Left", count: 1
         , click: false, move: false, interval: 500 }
    if (IsObject(opts)) {
        for k, v in opts.OwnProps()
            o.%k% := v
    }
    return o
}

; Escape regex metacharacters. Backslash must be handled first, or the
; backslashes added for the other characters get escaped a second time.
_FT_Escape(s) {
    s := StrReplace(s, "\", "\\")
    for ch in StrSplit(".*?+[]{}()^$|/-", "")
        s := StrReplace(s, ch, "\" . ch)
    return s
}

; Spaces in the needle become \s* so a phrase still matches when OCR drops or
; adds spacing, which it does routinely on narrow crops and tight kerning.
_FT_Pattern(needle, o) {
    if (o.regex)
        return needle
    if (o.exactSpace)
        return _FT_Escape(needle)

    pattern := ""
    for part in StrSplit(Trim(needle), " ") {
        if (part = "")
            continue
        if (pattern != "")
            pattern .= "\s*"
        pattern .= _FT_Escape(part)
    }
    return pattern
}

;
; The engine reports word-level boxes, so a multi-word phrase has no single
; box. Rebuild each line, remember which characters each word occupies, match
; against the rebuilt line, then union the boxes of the words the match covers.
; That is what makes "Save As" return one box rather than two, or nothing.
;
_FT_Match(result, needle, o) {
    pattern := (o.caseSense ? "" : "i)") . _FT_Pattern(needle, o)
    hits := []

    for line in result.Lines {
        text := ""
        spans := []
        for word in line.Words {
            if (text != "")
                text .= " "
            spans.Push({ s: StrLen(text) + 1, e: StrLen(text) + StrLen(word.Text), word: word })
            text .= word.Text
        }
        if (text = "")
            continue

        pos := 1
        while (found := RegExMatch(text, pattern, &m, pos)) {
            ms := found
            me := found + m.Len[0] - 1

            covered := []
            for span in spans {
                if (span.s <= me && span.e >= ms)
                    covered.Push(span.word)
            }
            if (covered.Length) {
                x1 := covered[1].x, y1 := covered[1].y
                x2 := covered[1].x + covered[1].w, y2 := covered[1].y + covered[1].h
                for word in covered {
                    x1 := Min(x1, word.x)
                    y1 := Min(y1, word.y)
                    x2 := Max(x2, word.x + word.w)
                    y2 := Max(y2, word.y + word.h)
                }
                hits.Push({ x: x1, y: y1, w: x2 - x1, h: y2 - y1
                          , cx: x1 + (x2 - x1) // 2, cy: y1 + (y2 - y1) // 2
                          , text: m[0] })
            }
            pos := found + Max(1, m.Len[0])   ; Max() guards a zero-width match
        }
    }

    ; top-to-bottom, then left-to-right, so index 1 is the topmost match
    _FT_SortHits(hits)
    for i, hit in hits
        hit.count := hits.Length
    return hits
}

; Insertion sort - hit counts here are small and AHK has no stable sort for
; arrays of objects.
_FT_SortHits(hits) {
    loop hits.Length - 1 {
        i := A_Index + 1
        current := hits[i]
        j := i - 1
        while (j >= 1 && (hits[j].y > current.y
                       || (hits[j].y = current.y && hits[j].x > current.x))) {
            hits[j + 1] := hits[j]
            j--
        }
        hits[j + 1] := current
    }
    return hits
}
