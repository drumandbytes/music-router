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

PLIST="$BUNDLE/Contents/Info.plist"
cp Resources/Info.plist "$PLIST"
# PlistBuddy fails loudly on a typo key; the old sed no-op'd silently
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$PLIST"

echo "Signing (ad-hoc)..."
# apple-events entitlement is required under hardened runtime: add
# `--options runtime` with a Developer ID when notarizing.
codesign --force --sign - --entitlements Resources/MusicRouter.entitlements "$BUNDLE"

echo "Built: $BUNDLE"
codesign -dv "$BUNDLE"
