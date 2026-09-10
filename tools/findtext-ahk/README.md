# FindText for AutoHotkey v2

Find text on screen and move or click the mouse there, using the **OCR engine
built into Windows**.

This is the right build if AutoHotkey is already approved and deployed at your
organisation. Nothing new gets installed, nothing is compiled, and there is no
executable to sign or get past SmartScreen - you are distributing text files
that run under an interpreter your fleet already trusts.

## The OCR engine

Windows ships an OCR engine (`Windows.Media.Ocr`). It is the same engine a C#
or PowerShell app would use - same models, same language packs, same bounding
boxes. Reaching it from AutoHotkey needs WinRT COM activation rather than a
plain `DllCall`, which is what `Lib\OCR.ahk` handles.

No OCR model ships with these scripts. Recognition happens inside Windows.

## Setup

1. Download **OCR.ahk** from <https://github.com/Descolada/OCR> and put it at
   `Lib\OCR.ahk`, next to these files.

   > Read it before deploying. You are putting it on machines across the
   > country, and "an AHK library that screen-captures and calls WinRT" is
   > exactly the kind of thing worth a look first. It is widely used in the AHK
   > community and derived from malcev's AHK v1 UWP OCR work, but check its
   > licence and contents against your own policy rather than taking that on
   > trust.

2. Run **`Doctor.ahk`**. It checks the OCR engine, lists installed languages,
   draws known text at known coordinates and verifies it is found *in the right
   place*, then tests the pointer. Do this on one machine before rolling out.

3. `#Include FindText.ahk` in your own script.

```
your-folder\
    FindText.ahk          <- the library
    Doctor.ahk            <- run this first
    Example_Hotkeys.ahk   <- usage examples
    Lib\OCR.ahk           <- download separately (step 1)
```

## Use

```ahk
#Include FindText.ahk

ClickText("Save As")                                   ; find it and click it
MoveToText("Save As")                                  ; just move the cursor
hit := FindOnScreen("Save As")                         ; just get coordinates
WaitForText("Upload complete", 120, { click: true })   ; wait, then click

; restrict the search area - the biggest speed-up available, and it removes
; false matches from elsewhere on screen
ClickText("Sign in", { region: [0, 0, 1920, 200] })

; or search one window instead of the whole screen
ClickText("OK", { win: "ahk_exe notepad.exe" })

FindOnScreen("Invoice #\d+", { regex: true })          ; regex
ClickText("Delete", { index: 2 })                      ; the 2nd match
ClickText("Remember me", { offset: [-24, 0] })         ; the checkbox beside the label
```

`FindOnScreen` returns `{x, y, w, h, cx, cy, text, count}` or `0`. `cx, cy` is
the centre - the point to click. Nothing throws on "not found", so no
try/catch is needed for the normal case.

## Options

| option | what it does |
|---|---|
| `region` | `[x, y, w, h]` - search only this rectangle. Much faster, fewer false hits. |
| `win` | search a window instead of the screen (any AHK WinTitle) |
| `regex` | treat the needle as an AHK regex |
| `caseSense` | case-sensitive matching |
| `exactSpace` | require literal spacing (see below) |
| `index` | which match to act on, 1-based |
| `scale` | upscale before OCR - raise it for small text |
| `invert` | for light text on a dark background |
| `grayscale` | drop colour before OCR |
| `lang` | BCP-47 tag, e.g. `"en-US"` |
| `offset` | `[dx, dy]` nudge for the click point |
| `speed` | MouseMove speed, 0 = instant |
| `button`, `count` | click button and click count |

## Things that will bite you

**Spacing is unreliable, so spaces are matched loosely.** OCR routinely drops
or adds spaces depending on kerning and how tightly the text is cropped -
`"Save the file"` can come back as `"Savethefile"`. A space in your search text
therefore matches any amount of whitespace, including none. Pass
`{ exactSpace: true }` if you need literal matching.

**OCR gives you the text box, not the widget box.** A left-aligned button label
sits well off the button's centre. Clicking the text usually still hits the
button, but for a checkbox or field *beside* its label, use `offset`.

**Light text on a dark toolbar is often missed.** Try `{ invert: true }`, and
restrict `region` to the dark strip - the light/dark decision is made from the
average brightness of whatever you hand it, so a dark bar inside a mostly-light
screenshot reads as "light" and gets skipped.

**Elevated windows cannot be clicked** unless the script is elevated too. This
is UIPI, a Windows security boundary - it applies identically to AutoHotkey,
C#, Python and Power Automate. Windows does not report the failure, so the
click simply does nothing. `Doctor.ahk` reports whether the script is elevated.

**Display scaling throws coordinates off** if capture and pointer disagree
about pixels. `Doctor.ahk` catches this by checking that text is found *where
it was actually drawn*, not merely that it was found.

**When a search will not match, dump what OCR reads first.** `ReadScreen()`
returns every line with its coordinates - see the `Ctrl+Alt+D` example. It is
almost always that the text reads differently than you assumed.

## A note on security review

Even with AutoHotkey approved, this script captures the screen and synthesises
mouse input. Endpoint security tools watch for exactly that combination, and
they can flag it days after it starts working, not immediately.

Being already-approved software removes the installation problem, not the
behavioural one. A short heads-up to whoever runs endpoint security - what it
does, where it runs, why - is still worth ten minutes.

## Verification status

Two layers, because they cover different things.

**Linux / Wine - runs on every push, and has actually been run:**

```bash
./tests/run-wine-tests.sh
```

- every file is parsed, including the 100KB `OCR.ahk` include chain
  (`AutoHotkey64.exe /ErrorStdOut /validate`)
- 22 assertions over the matching logic, against recognition results built by
  hand in `Tests.ahk` - no screen or OCR engine required

Those tests were checked by breaking the code on purpose and confirming they
notice: removing the whitespace tolerance, disabling regex escaping, unioning
only the first word's box, reversing the sort, inverting the case flag and
corrupting the match count were each detected. A suite that cannot fail proves
nothing, so this matters more than the pass count.

**Windows runner - the parts Wine cannot reach:**

`.github/workflows/ahk.yml` runs the same syntax and logic checks on
`windows-latest`, then `Probe.ahk` (reports OCR languages and whether capture
works, never fails) and `Doctor.ahk` (the real end-to-end check). The probe
runs first deliberately: a runner with no OCR language pack fails the doctor
for environmental reasons, and the probe output is how you tell that apart from
a genuine code failure.

**Still unverified anywhere:** the OCR engine call itself, screen capture, and
the pointer, on *your* hardware. `Doctor.ahk` is the answer to that - it draws
known text at known coordinates and checks it is found in the right place. Run
it on one machine before rolling out.

### Layout

```
FindText.ahk            capture + move/click  (needs a screen)
Lib\FindTextCore.ahk    matching logic        (pure - this is what Tests.ahk covers)
Lib\OCR.ahk             download separately
Doctor.ahk              end-to-end check on a real machine
Probe.ahk               reports the environment without asserting
Tests.ahk               core logic tests
testsun-wine-tests.sh run the lot on Linux
```

The split exists so the logic can be tested without a screen. `FindTextCore.ahk`
has no dependency on OCR or the display at all.

## Removing the machine-code blobs

The upstream OCR library speeds up three image transforms by base64-decoding
machine code into executable memory. It is benign — see `SECURITY-REVIEW.md`,
which disassembles it — but "decode a blob and execute it" is hard to get past a
security review and impossible for a reviewer to read.

```
AutoHotkey64.exe Patch-RemoveMCode.ahk        # swap blobs for readable AHK
AutoHotkey64.exe Verify-MCodeRemoval.ahk      # prove the swap changed nothing
```

After patching, the library contains no `CryptStringToBinary`, no
`VirtualProtect` and no encoded blobs. The replacements live in
`Lib/PixelTransforms.ahk` — three functions, ~60 lines, transcribed from the C
source in the library's own comments.

`Verify-MCodeRemoval.ahk` recovers the original blobs from the `.orig` backup,
runs both versions over identical buffers and compares every pixel. All three
come back byte-identical.

**The trade-off:** the AHK loops are much slower than compiled code (~18ms vs
~850ms for a 1280x720 buffer). This applies *only* when using `grayscale`,
`invertcolors` or `monochrome`, and scales with area — with a `region` it is
negligible. Never use those options and the code never runs. Set `KEEP_MCODE=1`
to keep the upstream version.

Both the local test script and CI apply and verify the patch automatically.
