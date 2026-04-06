#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Quickdict"
VERSION="1.0.1"
BUILD_DIR="$ROOT_DIR/build/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$ROOT_DIR/$APP_NAME-$VERSION.dmg"
STAGING_DIR="$ROOT_DIR/build/dmg-root"
IDENTITY="$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | sed -E 's/.*"(.*)"/\1/' || true)"

echo "Building Quickdict release app..."
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

if [ ! -d "$APP_PATH" ]; then
  echo "Release app was not produced at $APP_PATH"
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
xattr -cr "$APP_PATH"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
cp "$ROOT_DIR/README.md" "$STAGING_DIR/README.md"
ln -s /Applications "$STAGING_DIR/Applications"
xattr -cr "$STAGING_DIR/$APP_NAME.app"

if [ -n "$IDENTITY" ]; then
  echo "Signing staged app with: $IDENTITY"
  codesign --force --deep \
    --sign "$IDENTITY" \
    --options runtime \
    --entitlements "$ROOT_DIR/Resources/Quickdict.entitlements" \
    "$STAGING_DIR/$APP_NAME.app"
fi

rm -f "$DMG_NAME"

echo "Creating DMG..."
hdiutil create -ov \
  -volname "$APP_NAME" \
  -fs HFS+ \
  -srcfolder "$STAGING_DIR" \
  "$DMG_NAME" >/dev/null

echo "Created: $DMG_NAME"
ls -lh "$DMG_NAME"
