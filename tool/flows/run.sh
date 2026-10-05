#!/bin/bash
# Plays the flows of integration_test/flows/ on an iPhone simulator of its
# own. Every step leaves a picture and the line that goes under it; every
# flow leaves what its checks found. tool/flows/storyboard.py then puts each
# flow on one image. The simulator is deleted at the end.
#
#   tool/flows/run.sh [folder]        (capturas/flujos by default)
#
# To watch it, open the simulator called "Quincena flujos" while it plays.
set -euo pipefail
cd "$(dirname "$0")/../.."
BASE="$(mkdir -p "${1:-capturas/flujos}" && cd "${1:-capturas/flujos}" && pwd)"
OUT="$BASE/pasos"
mkdir -p "$OUT"
rm -f "$OUT"/*.png "$OUT"/*.txt "$OUT"/*.json "$OUT/.stop"

RUNTIME=$(xcrun simctl list runtimes available | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*' | tail -1)
UDID=$(xcrun simctl create "Quincena flujos" "iPhone 17 Pro" "$RUNTIME")
echo "$UDID" > "$OUT/.udid"
finish() {
  touch "$OUT/.stop"
  sleep 2
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl delete "$UDID" >/dev/null 2>&1 || true
  rm -f "$OUT/.stop" "$OUT/.udid"
}
trap finish EXIT

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
# The same status bar on every picture.
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

# Takes a picture whenever the app leaves a file asking for one, keeps the
# line in the file beside it, and collects what each flow's checks found.
(
  while [ ! -e "$OUT/.stop" ]; do
    DATA=$(xcrun simctl get_app_container "$UDID" dev.dlsoft.quincena data 2>/dev/null || true)
    if [ -n "$DATA" ] && [ -d "$DATA/Documents/tour" ]; then
      for ASK in "$DATA"/Documents/tour/*.ready; do
        [ -e "$ASK" ] || continue
        NAME=$(basename "$ASK" .ready)
        xcrun simctl io "$UDID" screenshot "$OUT/$NAME.png" >/dev/null 2>&1 || true
        cp "$ASK" "$OUT/$NAME.txt"
        rm -f "$ASK"
      done
      for DONE in "$DATA"/Documents/tour/*.result.json; do
        [ -e "$DONE" ] || continue
        mv "$DONE" "$OUT/"
      done
    fi
    sleep 0.3
  done
) &

flutter test integration_test/flows_test.dart -d "$UDID" ${FLOWS_NAME:+--plain-name "$FLOWS_NAME"} || true
sleep 2
python3 tool/flows/storyboard.py "$BASE"
