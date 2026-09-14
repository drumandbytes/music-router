#!/bin/bash
# Builds MusicRouter.app without Xcode: swift build + manual bundle assembly
# + ad-hoc codesign. Usage: scripts/build-app.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP_NAME="MusicRouter"
BUNDLE="build/${APP_NAME}.app"

echo "Building ${APP_NAME} ${VERSION}..."
swift build -c release

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

cp ".build/release/${APP_NAME}" "$BUNDLE/Contents/MacOS/${APP_NAME}"
cp "Resources/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"

sed "s/<string>0.1.0<\/string>/<string>${VERSION}<\/string>/" Resources/Info.plist \
    > "$BUNDLE/Contents/Info.plist"

echo "Signing (ad-hoc)..."
codesign --force --deep --sign - "$BUNDLE"

echo "Built: $BUNDLE"
codesign -dv "$BUNDLE"
