#!/bin/bash
set -euo pipefail

# Renders one panel scene offscreen into <output directory>/<scene>.png.
# Usage: scripts/quick-capture.sh <editor|switcher> <output directory>

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <editor|switcher> <output directory>" >&2
  exit 2
fi

scene="$1"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_directory="$(cd "$project_root" && mkdir -p "$2" && cd "$2" && pwd)"

case "$scene" in
  editor|switcher) ;;
  *) echo "unknown scene '$scene'" >&2; exit 2 ;;
esac

cd "$project_root"
STICKY_EVIDENCE_DIR="$output_directory" STICKY_EVIDENCE_SCENE="$scene" \
  swift test --filter EvidenceCaptureTests >&2

echo "$output_directory/$scene.png"
