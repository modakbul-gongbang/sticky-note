#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
source_bundle="$project_root/build/Sticky Notes.app"
target_bundle="/Applications/Sticky Notes.app"
backup_bundle="$project_root/build/Sticky Notes.previous.app"
expected_id="com.hoyeon.sticky-notes"

"$project_root/scripts/build-app.sh"

if [[ -e "$target_bundle" ]]; then
  installed_id="$(/usr/bin/defaults read "$target_bundle/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
  if [[ "$installed_id" != "$expected_id" ]]; then
    echo "Refusing to replace $target_bundle because its bundle identifier is '$installed_id'." >&2
    exit 1
  fi
  while IFS= read -r installed_pid; do
    [[ -n "$installed_pid" ]] && kill "$installed_pid"
  done < <(/usr/bin/pgrep -f '^/Applications/Sticky Notes.app/Contents/MacOS/Sticky Notes$' || true)
  /bin/rm -rf "$backup_bundle"
  /bin/mv "$target_bundle" "$backup_bundle"
fi

if ! /usr/bin/ditto "$source_bundle" "$target_bundle"; then
  if [[ -e "$backup_bundle" && ! -e "$target_bundle" ]]; then
    /bin/mv "$backup_bundle" "$target_bundle"
  fi
  exit 1
fi

if ! /usr/bin/codesign --verify --deep --strict --verbose=2 "$target_bundle"; then
  /bin/rm -rf "$target_bundle"
  if [[ -e "$backup_bundle" ]]; then /bin/mv "$backup_bundle" "$target_bundle"; fi
  exit 1
fi

/usr/bin/open "$target_bundle"
echo "Installed $target_bundle"
