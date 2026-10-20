#!/bin/bash
# Packages "build/Notepad Lite.app" into build/NotepadLite.dmg
# (a drag-to-Applications installer). Run ./build.sh first.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Notepad Lite.app"
DMG="build/NotepadLite.dmg"
STAGE="build/dmg"

[ -d "$APP" ] || { echo "Run ./build.sh first"; exit 1; }

echo "▸ Creating disk image…"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Notepad Lite" -srcfolder "$STAGE" -ov -format UDZO -fs HFS+ "$DMG" >/dev/null
rm -rf "$STAGE"
# Forget the temporary copy so it doesn't show up in Finder's "Open With" menu.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u "$PWD/$STAGE/Notepad Lite.app" 2>/dev/null || true
codesign --force --sign - "$DMG" >/dev/null

echo "✓ Built: $DMG"
