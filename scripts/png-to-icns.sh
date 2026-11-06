#!/usr/bin/env bash
# Converts any PNG/JPEG (including wide logos) into a macOS .icns file.
# The image is centred on a square canvas so it isn't stretched.
#
# Usage: scripts/png-to-icns.sh <input image> <output .icns> [background hex, default FFFFFF]
# macOS only (uses sips and iconutil).
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "usage: $0 <input image> <output.icns> [background hex]" >&2
    exit 64
fi

SRC="$1"
OUT="$2"
BACKGROUND="${3:-FFFFFF}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/hoichoi-icon.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/AppIcon.iconset"

# Normalise to PNG.
sips -s format png "$SRC" --out "$WORK/source.png" >/dev/null

width=$(sips -g pixelWidth "$WORK/source.png" | awk '/pixelWidth/ { print $2 }')
height=$(sips -g pixelHeight "$WORK/source.png" | awk '/pixelHeight/ { print $2 }')
longest=$(( width > height ? width : height ))
# Leave a ~10% margin around the artwork.
side=$(( longest * 11 / 10 ))

cp "$WORK/source.png" "$WORK/square.png"
sips --padToHeightWidth "$side" "$side" --padColor "$BACKGROUND" "$WORK/square.png" >/dev/null

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$WORK/square.png" \
        --out "$WORK/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$(( size * 2 ))
    sips -z "$double" "$double" "$WORK/square.png" \
        --out "$WORK/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p "$(dirname "$OUT")"
iconutil -c icns "$WORK/AppIcon.iconset" -o "$OUT"
echo "Wrote $OUT"
