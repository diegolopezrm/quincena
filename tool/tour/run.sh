#!/bin/bash
# Plays integration_test/tour.dart on an iPhone simulator of its own and
# keeps a picture of every screen, named by scene and order, in the folder
# given (capturas/ios by default). The simulator is deleted at the end.
#
#   tool/tour/run.sh [folder]
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="$(mkdir -p "${1:-capturas/ios}" && cd "${1:-capturas/ios}" && pwd)"
rm -f "$OUT"/*.png "$OUT/.stop"

RUNTIME=$(xcrun simctl list runtimes available | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*' | tail -1)
UDID=$(xcrun simctl create "Quincena tour" "iPhone 17 Pro" "$RUNTIME")
finish() {
  touch "$OUT/.stop"
  sleep 1
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl delete "$UDID" >/dev/null 2>&1 || true
  rm -f "$OUT/.stop"
}
trap finish EXIT

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
# The same status bar on every picture.
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

# Takes a picture whenever the app leaves a file asking for one.
(
  while [ ! -e "$OUT/.stop" ]; do
    DATA=$(xcrun simctl get_app_container "$UDID" dev.dlsoft.quincena data 2>/dev/null || true)
    if [ -n "$DATA" ] && [ -d "$DATA/Documents/tour" ]; then
      for ASK in "$DATA"/Documents/tour/*.ready; do
        [ -e "$ASK" ] || continue
        xcrun simctl io "$UDID" screenshot "$OUT/$(basename "$ASK" .ready).png" >/dev/null 2>&1 || true
        rm -f "$ASK"
      done
    fi
    sleep 0.3
  done
) &

flutter test integration_test/tour_test.dart -d "$UDID" || true
python3 tool/tour/index.py "$OUT"
