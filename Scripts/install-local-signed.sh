#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/build/Build/Products/Release/Quickdict.app"
INSTALL_PATH="/Applications/Quickdict.app"
ENTITLEMENTS="$ROOT_DIR/Resources/Quickdict.entitlements"

IDENTITY="$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | sed -E 's/.*"(.*)"/\1/')"

if [ -z "$IDENTITY" ]; then
  echo "No Apple Development signing identity found."
  echo "Build will still work, but Accessibility/Input Monitoring permissions may not persist reliably."
  exit 1
fi

echo "Building Quickdict..."
xcodegen generate >/dev/null
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project "$ROOT_DIR/Quickdict.xcodeproj" \
  -scheme Quickdict \
  -configuration Release \
  -derivedDataPath "$ROOT_DIR/build" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

echo "Installing app to /Applications..."
rm -rf "$INSTALL_PATH"
cp -R "$APP_PATH" "$INSTALL_PATH"
xattr -cr "$INSTALL_PATH"

echo "Signing installed app with: $IDENTITY"
codesign --force --deep \
  --sign "$IDENTITY" \
  --options runtime \
  --entitlements "$ENTITLEMENTS" \
  "$INSTALL_PATH"

echo "Done. Launch /Applications/Quickdict.app."
echo "If permissions are not already granted, enable Quickdict in:"
echo "  1. Privacy & Security > Accessibility"
echo "  2. Privacy & Security > Input Monitoring"
echo "  3. Privacy & Security > Microphone"
echo "If you change Accessibility or Input Monitoring, quit and relaunch Quickdict."
