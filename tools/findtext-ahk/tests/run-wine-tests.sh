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

AHK_VERSION=${AHK_VERSION:-2.0.27}

fetch_ahk() {
    mkdir -p "$AHK_DIR"
    # autohotkey.com sits behind Cloudflare, which serves CI runners a JS
    # challenge page instead of the zip, so take the Chocolatey package feed
    # first - it is a plain nupkg (a zip) with the official build nested inside.
    echo "fetching AutoHotkey $AHK_VERSION from the Chocolatey feed..."
    if curl -sSfL -o /tmp/ahk.nupkg \
        "https://community.chocolatey.org/api/v2/package/autohotkey.portable/$AHK_VERSION" \
        && unzip -tq /tmp/ahk.nupkg >/dev/null 2>&1; then
        unzip -oq /tmp/ahk.nupkg -d /tmp/ahk-nupkg
        inner=$(find /tmp/ahk-nupkg/tools -name '*.zip' | head -1)
        if [ -n "$inner" ] && unzip -oq "$inner" -d "$AHK_DIR"; then
            [ -f "$AHK" ] && { echo "  got AutoHotkey from Chocolatey"; return 0; }
        fi
    fi

    echo "  Chocolatey feed failed; trying autohotkey.com..."
    if curl -sSfL -o /tmp/ahk2.zip https://www.autohotkey.com/download/ahk-v2.zip \
        && unzip -tq /tmp/ahk2.zip >/dev/null 2>&1; then
        unzip -oq /tmp/ahk2.zip -d "$AHK_DIR"
        [ -f "$AHK" ] && { echo "  got AutoHotkey from autohotkey.com"; return 0; }
    fi

    echo "ERROR: could not obtain AutoHotkey from any source." >&2
    echo "       autohotkey.com is behind Cloudflare and blocks some networks." >&2
    return 1
}

if [ ! -f "$AHK" ]; then
    fetch_ahk || exit 2
fi
if [ ! -f Lib/OCR.ahk ]; then
    echo "fetching OCR.ahk..."
    curl -sSfL -o Lib/OCR.ahk https://raw.githubusercontent.com/Descolada/OCR/main/Lib/OCR.ahk || exit 2
fi

# Replace the upstream machine-code blobs with readable AutoHotkey. Set
# KEEP_MCODE=1 to skip and use the library as shipped.
if [ "${KEEP_MCODE:-0}" != "1" ] && [ ! -f Lib/PixelTransforms.ahk ]; then
    echo "removing machine-code blobs from OCR.ahk..."
    timeout 180 wine "$AHK" /ErrorStdOut Patch-RemoveMCode.ahk "Lib\\OCR.ahk" /quiet >/dev/null 2>&1
    if [ -f Lib/PixelTransforms.ahk ]; then
        echo "  patched (originals kept at Lib/OCR.ahk.orig)"
    else
        echo "  WARNING: patch did not apply; continuing with the library as shipped" >&2
        [ -f PatchResults.txt ] && sed 's/^/    /' PatchResults.txt >&2
    fi
fi

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
