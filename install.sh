#!/bin/bash
# Builds the app and installs it into /Applications.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="/Applications/Notepad Lite.app"
echo "▸ Installing to $DEST…"
osascript -e 'quit app "Notepad Lite"' 2>/dev/null || true
rm -rf "$DEST"
cp -R "build/Notepad Lite.app" "$DEST"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREGISTER" -f "$DEST"
# Remove the build copy so Finder's "Open With" menu shows only the installed app.
"$LSREGISTER" -u "$PWD/build/Notepad Lite.app" 2>/dev/null || true
rm -rf "build/Notepad Lite.app"
echo "✓ Installed. Open it from Launchpad / Spotlight, or: open -a \"Notepad Lite\" file.txt"
