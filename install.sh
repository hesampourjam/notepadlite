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
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
echo "✓ Installed. Open it from Launchpad / Spotlight, or: open -a \"Notepad Lite\" file.txt"
