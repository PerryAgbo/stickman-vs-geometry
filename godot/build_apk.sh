#!/bin/sh
# Builds the Android APK. Release-signed when the release keystore exists, otherwise a debug-signed build.
#   ./build_apk.sh [output.apk]        default output: ../build/StickmanVsGeometry.apk
# Keystore: ~/.android/stickman-release.keystore (alias stickman). Override with STICKMAN_KEYSTORE / STICKMAN_KEY_USER / STICKMAN_KEY_PASS.
set -e
cd "$(dirname "$0")"
GODOT="${GODOT:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
[ -x "$GODOT" ] || GODOT=/Applications/Godot.app/Contents/MacOS/Godot
OUT="${1:-../build/StickmanVsGeometry.apk}"
mkdir -p "$(dirname "$OUT")"
KS="${STICKMAN_KEYSTORE:-$HOME/.android/stickman-release.keystore}"
"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
if [ -f "$KS" ]; then
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KS"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${STICKMAN_KEY_USER:-stickman}"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${STICKMAN_KEY_PASS:-stickman-release}"
  "$GODOT" --headless --path . --export-release Android "$OUT" 2>&1 | grep -E "ERROR|WARNING|DONE" | grep -v "tcp:5037" || true
else
  echo "no release keystore at $KS; building a debug-signed APK"
  "$GODOT" --headless --path . --export-debug Android "$OUT" 2>&1 | grep -E "ERROR|WARNING|DONE" | grep -v "tcp:5037" || true
fi
ls -la "$OUT"
