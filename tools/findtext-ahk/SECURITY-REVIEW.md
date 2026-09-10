# Security review: Lib/OCR.ahk

Reviewed because this goes onto managed machines nationally, and "an AHK
library that captures the screen and calls into Windows internals" is exactly
the kind of dependency worth reading before deploying.

**Subject:** `Lib/OCR.ahk` from <https://github.com/Descolada/OCR>
**Size:** 1819 lines / 100,572 bytes
**SHA-256:** `ed348c0be111692c4ffeb9dcc8a9f524c575d48d7f81c8bcd96b882bb7375124`

Verify you have the same file before trusting this review:

```powershell
Get-FileHash Lib\OCR.ahk -Algorithm SHA256
```

## Finding: nothing leaves the machine

| checked for | result |
|---|---|
| HTTP/socket APIs (`WinHttp`, `XMLHTTP`, `InternetOpen`, `URLDownloadToFile`, `ws2_32`, `socket`) | **none present** |
| URLs or IP addresses | one URL, in a code comment crediting an algorithm source |
| Process launching (`Run`, `RunWait`, `ShellExecute`, `ComSpec`, `WScript.Shell`) | **none** — two `powershell` mentions are comments telling a user how to install a language pack |
| File writes (`FileAppend`, `FileOpen`, `FileDelete`, `IniWrite`, ...) | **none** |
| Registry writes / persistence (`RegWrite`, Startup, `schtasks`) | **none** |

There is no code path by which screen content, recognised text, or anything
else can leave the machine. The library has no ability to write to disk, touch
the registry, start a process, or open a network connection.

**Where the OCR happens:** entirely locally. It calls `Windows.Media.Ocr`,
the recognition engine built into Windows, via COM. No cloud service is
involved and no OCR model is bundled — Windows does the recognition, offline.

## Every external call it makes

All are local Windows APIs, and all are consistent with "capture a bitmap and
run the built-in OCR over it":

- **GDI / screen capture** — `GetDC`, `CreateCompatibleDC`, `CreateCompatibleBitmap`,
  `StretchBlt`, `GetDIBits`, `CreateDIBSection`, `SelectObject`, `DeleteDC`,
  `DeleteObject`, `PrintWindow`, `GetWindowRect`, `ClientToScreen`
- **WinRT activation** (`Combase.dll`) — `RoGetActivationFactory`,
  `RoActivateInstance`, `WindowsCreateString`, `WindowsDeleteString`,
  `WindowsGetStringRawBuffer` — the documented way a desktop app reaches
  `Windows.Media.Ocr`
- **Stream bridging** (`ShCore`) — `CreateRandomAccessStreamOnFile`,
  `CreateRandomAccessStreamOverStream` — converts a bitmap into the stream type
  the OCR API expects
- **Imaging / DPI / misc** — `gdiplus`, `ole32`, `OleAut32`, `Dwmapi`, `D3D11`,
  `SetThreadDpiAwarenessContext`, `ntdll\memcpy`

## The one thing worth understanding before you approve it

The library uses the **MCode** pattern, a long-standing AutoHotkey idiom:
base64-encoded machine code is decoded with `CryptStringToBinary`, marked
executable via `VirtualProtect` (`0x40` = `PAGE_EXECUTE_READWRITE`), and called
directly. That is genuinely "decode a blob and execute it as native code", so
it deserves scrutiny rather than a shrug.

What we checked, and what we found:

- There are **6 blobs** (x86 and x64 variants of 3 functions), each **112-188
  bytes** — far too small to be a functional payload.
- Each blob has its **original C source in a comment directly above it**. The
  three functions are `Convert_GrayScale`, `Invert_Colors` and a monochrome
  threshold. They correspond exactly to the library's `grayscale`,
  `invertcolors` and `monochrome` image options.
- Decoding them found **no embedded strings** and none of the opcodes that
  dangerous shellcode needs (`syscall`, `int 0x80`, indirect `call rax`).
- We disassembled the x64 grayscale blob to confirm it matches its comment.
  It does: `shr r9d,0x2` is `Stride/4`, `lea r10,[rbx+rax*4]` is 4-byte pixel
  indexing, and `imul edi,edi,0x24e` is **0x24e = 590 decimal**, exactly the
  green coefficient `(590 * g)` in the documented C. It is a pixel loop and
  nothing else.
- They are only invoked when the corresponding image option is used.

Verdict on this construct: **benign, documented, and matches its stated
purpose** — but flag it to IT security proactively rather than letting them
find `VirtualProtect(PAGE_EXECUTE_READWRITE)` themselves. It reads far worse
out of context than it is.

## What this review does not cover

- **Only this version.** Re-check the hash after any update; the review does
  not carry forward.
- **Static review, not runtime.** Nothing here observed the library running on
  Windows.
- **The tool built on top of it still captures your screen and moves your
  mouse.** That is its purpose, and endpoint security tools watch for exactly
  that combination regardless of how clean the dependency is. The behavioural
  conversation with IT security is separate from this code review, and still
  worth having.

## Reproducing this review

```bash
sha256sum Lib/OCR.ahk
grep -niE "WinHttp|XMLHTTP|InternetOpen|URLDownload|ws2_32|socket" Lib/OCR.ahk
grep -noE "https?://[^\"' ]+"  Lib/OCR.ahk
grep -niE "FileAppend|FileOpen|FileDelete|RegWrite|Run\(|ShellExecute" Lib/OCR.ahk
grep -oE 'DllCall\("[^"]+"' Lib/OCR.ahk | sort -u
```
