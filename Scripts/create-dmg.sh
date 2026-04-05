#!/bin/bash
set -e

APP_NAME="Quickdict"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOL_NAME="${APP_NAME}"

BUILD_DIR="./build/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Building app first..."
    xcodebuild -project Quickdict.xcodeproj -scheme Quickdict -configuration Release build
fi

echo "Creating DMG..."

hdiutil create -ov \
    -volname "$VOL_NAME" \
    -fs HFS+ \
    -srcfolder "$APP_PATH" \
    "$DMG_NAME"

echo "DMG created: $DMG_NAME"
ls -la "$DMG_NAME"
