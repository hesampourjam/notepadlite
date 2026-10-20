#!/bin/bash
# Builds "build/Notepad Lite.app".
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Notepad Lite.app"

# Universal binary: runs natively on Apple Silicon and Intel Macs.
ARCHS=(--arch arm64 --arch x86_64)

echo "▸ Compiling (release, universal)…"
swift build -c release "${ARCHS[@]}"

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release "${ARCHS[@]}" --show-bin-path)/NotepadLite" "$APP/Contents/MacOS/NotepadLite"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ]; then
  echo "▸ Rendering icon…"
  ICONSET="build/AppIcon.iconset"
  rm -rf "$ICONSET" && mkdir -p "$ICONSET"
  swiftc -O -o build/make_icon tools/make_icon.swift
  build/make_icon build/icon_1024.png
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Signing (ad-hoc)…"
codesign --force --sign - "$APP" >/dev/null

echo "✓ Built: $APP"
