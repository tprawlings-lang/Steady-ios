#!/usr/bin/env bash
# Headless build + verification for the Steady iOS app. Run on a Mac with Xcode 16.
#
#   ./build.sh            # compile for the iOS Simulator (fastest way to catch errors)
#   ./build.sh device     # compile for a generic iOS device (no signing/run)
#
# This does NOT need a paid developer account or a plugged-in device — the
# simulator build type-checks and compiles every file.
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-sim}"
SCHEME="Steady"
PROJ="Steady.xcodeproj"

echo "==> Xcode: $(xcodebuild -version | head -1)"

if [ "$MODE" = "device" ]; then
  DEST='generic/platform=iOS'
else
  # Pick the first available iPhone simulator so this works on any machine.
  SIM=$(xcrun simctl list devices available | grep -m1 -oE 'iPhone [0-9][^(]*' | sed 's/ *$//') || true
  SIM="${SIM:-iPhone 15}"
  echo "==> Simulator: $SIM"
  DEST="platform=iOS Simulator,name=$SIM"
fi

echo "==> Building ($DEST)…"
xcodebuild \
  -project "$PROJ" \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  clean build | xcbeautify 2>/dev/null || \
xcodebuild \
  -project "$PROJ" \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  clean build

echo "==> Build succeeded."
