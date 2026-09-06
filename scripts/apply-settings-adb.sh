#!/usr/bin/env bash
set -euo pipefail

# Apply the Leaf Voxel reference settings to a connected MLP1 over adb.
#
#   scripts/apply-settings-adb.sh                 # show what would change
#   scripts/apply-settings-adb.sh --write         # apply it
#   scripts/apply-settings-adb.sh --write --enable-for red
#
# Pulls the device profile, patches it locally with apply-settings.lua, and
# pushes it back. The profile never leaves the device except into a local
# temporary file, and nothing personal is written into it -- see the header of
# apply-settings.lua.
#
# Gen1Recomp must be closed: the engine rewrites options.lua as it exits, so a
# patch applied while it runs is lost.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The card that holds the profile is discovered, never assumed: the MLP1 has two
# slots and their mount points can swap between boots, so /mnt/sdcard is not
# reliably the same card twice.
REMOTE_REL=.userdata/mlp1/gen1recomp/love/pokemon-love2d/options.lua
REMOTE_CANDIDATES="${REMOTE_CANDIDATES:-/mnt/sdcard /media/sdcard1}"

WRITE=0
PASS=()
for arg in "$@"; do
    case "$arg" in
        --write) WRITE=1 ;;
        *) PASS+=("$arg") ;;
    esac
done

LUA_BIN="$(command -v luajit || command -v lua || true)"
[ -z "$LUA_BIN" ] && { echo "need lua or luajit on PATH" >&2; exit 1; }

if [ -n "${ADB_SERIAL:-}" ]; then
    serial="$ADB_SERIAL"
else
    serial="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
    [ -z "${serial:-}" ] && { echo "no online adb device" >&2; exit 1; }
fi
ADB=(adb -s "$serial")

# pgrep -x matches the process NAME. Do not use -f: the adb shell's own
# command line contains the pattern, so -f matches this very shell and the
# check would report the game running when it is not.
if "${ADB[@]}" shell "pgrep -x love.aarch64 >/dev/null" 2>/dev/null; then
    echo "Gen1Recomp is running on $serial; close it first or the engine will" >&2
    echo "overwrite this patch when it exits." >&2
    exit 1
fi

# Resolve the profile's card: mounted, and actually holding the file. Refuse to
# guess if more than one card has one -- picking the wrong profile would write
# settings into a game the user is not playing.
REMOTE=""
for card in $REMOTE_CANDIDATES; do
    "${ADB[@]}" shell "awk -v p='$card' '\$2 == p { f = 1 } END { exit f ? 0 : 1 }' /proc/mounts" >/dev/null 2>&1 || continue
    "${ADB[@]}" shell "[ -f '$card/$REMOTE_REL' ]" >/dev/null 2>&1 || continue
    if [ -n "$REMOTE" ]; then
        echo "Found a Gen1Recomp profile on more than one card:" >&2
        echo "  $REMOTE" >&2
        echo "  $card/$REMOTE_REL" >&2
        echo "Set REMOTE_CANDIDATES to the one you mean." >&2
        exit 1
    fi
    REMOTE="$card/$REMOTE_REL"
done
if [ -z "$REMOTE" ]; then
    echo "No Gen1Recomp profile found on: $REMOTE_CANDIDATES" >&2
    echo "Launch the port once so it writes its options, then retry." >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

"${ADB[@]}" pull "$REMOTE" "$TMP/options.lua" >/dev/null
echo "Pulled $REMOTE from $serial"

if [ "$WRITE" -eq 0 ]; then
    "$LUA_BIN" "$SCRIPT_DIR/apply-settings.lua" "$TMP/options.lua" --dry-run "${PASS[@]+"${PASS[@]}"}"
    echo
    echo "Nothing written. Re-run with --write to apply."
    exit 0
fi

"$LUA_BIN" "$SCRIPT_DIR/apply-settings.lua" "$TMP/options.lua" "${PASS[@]+"${PASS[@]}"}"

# Keep a dated copy on the device next to the engine's own .bak before pushing.
stamp="$(date +%Y%m%d-%H%M%S)"
"${ADB[@]}" shell "cp $REMOTE $REMOTE.before-leaf-voxel-$stamp"
"${ADB[@]}" push "$TMP/options.lua" "$REMOTE" >/dev/null
"${ADB[@]}" shell "chmod 755 $REMOTE"
echo "Pushed to $serial (previous profile saved as options.lua.before-leaf-voxel-$stamp)"
