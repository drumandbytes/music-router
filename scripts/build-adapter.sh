#!/bin/bash
# Builds MediaRemoteAdapter.framework from the vendored upstream source with
# clang (no CMake). Usage: scripts/build-adapter.sh <output-dir>
# The framework is loaded by bin/mediaremote-adapter.pl, never linked.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:?usage: build-adapter.sh <output-dir>}"
SRC="third_party/mediaremote-adapter"
FW="$OUT/MediaRemoteAdapter.framework"
VER="$FW/Versions/A"

rm -rf "$FW"
mkdir -p "$VER/Headers" "$VER/Resources"

# test.m (the `test` subcommand) needs the upstream test client, which we
# don't ship; the perl script only resolves that symbol on `test`.
SOURCES=$(ls "$SRC"/src/adapter/*.m "$SRC"/src/private/*.m "$SRC"/src/utility/*.m | grep -v '/test\.m$')

# shellcheck disable=SC2086
clang -fobjc-arc -fvisibility=default -dynamiclib \
    -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 \
    -I "$SRC/include" -I "$SRC/src" \
    -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
    -install_name "@rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter" \
    -o "$VER/MediaRemoteAdapter" $SOURCES

cp "$SRC/include/MediaRemoteAdapter.h" "$VER/Headers/"
cat > "$VER/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
    <key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
    <key>CFBundleName</key><string>MediaRemoteAdapter</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>0.7.7</string>
    <key>CFBundleVersion</key><string>0.7.7</string>
</dict>
</plist>
PLIST
ln -s A "$FW/Versions/Current"
ln -s Versions/Current/MediaRemoteAdapter "$FW/MediaRemoteAdapter"
ln -s Versions/Current/Headers "$FW/Headers"
ln -s Versions/Current/Resources "$FW/Resources"
codesign --force --sign - "$FW"
