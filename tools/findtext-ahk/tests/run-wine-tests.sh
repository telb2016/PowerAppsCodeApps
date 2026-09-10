#!/usr/bin/env bash
#
# Run the AutoHotkey checks on Linux via Wine.
#
# Covers everything that does not need a real screen: every file is parsed
# (including the OCR library), and the matching logic is run against
# hand-built recognition results. What it cannot cover is the OCR engine
# itself, screen capture and the pointer - those need the Windows job.
#
set -uo pipefail
cd "$(dirname "$0")/.."

AHK_DIR=${AHK_DIR:-.ahk}
AHK="$AHK_DIR/AutoHotkey64.exe"
export WINEPREFIX=${WINEPREFIX:-$PWD/.wineprefix}
export WINEARCH=win64 WINEDEBUG=-all
fail=0

command -v wine >/dev/null || { echo "wine not installed"; exit 2; }

# Wine needs a display even for scripts that draw nothing
if [ -z "${DISPLAY:-}" ]; then
    pgrep -x Xvfb >/dev/null || { Xvfb :99 -screen 0 1280x800x24 >/dev/null 2>&1 & sleep 2; }
    export DISPLAY=:99
fi

if [ ! -f "$AHK" ]; then
    echo "fetching AutoHotkey v2..."
    mkdir -p "$AHK_DIR"
    curl -sSL -o /tmp/ahk2.zip https://www.autohotkey.com/download/ahk-v2.zip
    unzip -oq /tmp/ahk2.zip -d "$AHK_DIR"
fi
[ -f Lib/OCR.ahk ] || {
    echo "fetching OCR.ahk..."
    curl -sSL -o Lib/OCR.ahk https://raw.githubusercontent.com/Descolada/OCR/main/Lib/OCR.ahk
}

wineboot -i >/dev/null 2>&1

echo
echo "syntax check (parses the whole include chain, OCR.ahk included):"
for f in Lib/FindTextCore.ahk FindText.ahk Doctor.ahk Example_Hotkeys.ahk Tests.ahk; do
    # /ErrorStdOut must come first, or errors open a dialog and hang forever
    # on a machine with no window manager
    if timeout 120 wine "$AHK" /ErrorStdOut /validate "$f" >/tmp/ahk_v.log 2>&1; then
        printf "  [ok ] %s\n" "$f"
    else
        fail=$((fail+1))
        printf "  [FAIL] %s\n" "$f"
        grep -viE "fixme|winediag|gstreamer|mscoree|^$" /tmp/ahk_v.log | head -4 | sed 's/^/         /'
    fi
done

echo
echo "core logic tests:"
rm -f TestResults.txt
if timeout 180 wine "$AHK" /ErrorStdOut Tests.ahk >/tmp/ahk_t.log 2>&1; then
    sed 's/^/  /' TestResults.txt
else
    fail=$((fail+1))
    [ -f TestResults.txt ] && sed 's/^/  /' TestResults.txt
    grep -viE "fixme|winediag|gstreamer|mscoree|^$" /tmp/ahk_t.log | head -5 | sed 's/^/  /'
fi

echo
[ $fail -eq 0 ] && echo "wine checks: all passed" || echo "wine checks: $fail step(s) failed"
exit $fail
