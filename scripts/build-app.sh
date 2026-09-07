#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$project_root/build/Sticky Notes.app"
executable="$project_root/.build/release/StickyNotes"

cd "$project_root"
swift build -c release --product StickyNotes

/bin/rm -rf "$bundle"
/bin/mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
/usr/bin/ditto "$executable" "$bundle/Contents/MacOS/Sticky Notes"
/usr/bin/ditto "$project_root/AppBundle/Info.plist" "$bundle/Contents/Info.plist"
/usr/bin/codesign --force --deep --sign - --entitlements "$project_root/AppBundle/StickyNotes.entitlements" "$bundle"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle"

echo "$bundle"
