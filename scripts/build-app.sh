#!/usr/bin/env bash
# Builds "Hoichoi for Mac.app" into ./build and a zip into ./dist.
#
# Environment variables:
#   VERSION            marketing version (default 0.1.0)
#   BUILD_NUMBER       build number (default 1)
#   ARCHS              space-separated architectures (default "arm64 x86_64" = universal)
#   CODESIGN_IDENTITY  signing identity (default "-" = ad-hoc)
set -euo pipefail

cd "$(dirname "$0")/.."

EXECUTABLE="HoichoiForMac"
APP="build/Hoichoi for Mac.app"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHS="${ARCHS:-arm64 x86_64}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

arch_flags=()
for arch in $ARCHS; do
    arch_flags+=(--arch "$arch")
done

echo "==> Building $EXECUTABLE ($ARCHS)"
swift build -c release "${arch_flags[@]}"
BIN_DIR="$(swift build -c release "${arch_flags[@]}" --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "build/Hoichoi for Mac.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
ICON="Resources/AppIcon.icns"
# Personal icon override for local builds only. Resources/Custom/ is git-ignored,
# and CI never uses it, so a custom icon can't end up in a public release.
if [[ -z "${CI:-}" ]]; then
    if [[ -f Resources/Custom/AppIcon.icns ]]; then
        ICON="Resources/Custom/AppIcon.icns"
    else
        for candidate in Resources/Custom/AppIcon.png Resources/Custom/AppIcon.jpg Resources/Custom/AppIcon.jpeg; do
            if [[ -f "$candidate" ]]; then
                ./scripts/png-to-icns.sh "$candidate" build/CustomAppIcon.icns "${CUSTOM_ICON_BACKGROUND:-FFFFFF}"
                ICON="build/CustomAppIcon.icns"
                break
            fi
        done
    fi
fi
echo "    icon: $ICON"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD_NUMBER/g" \
    Resources/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (identity: $CODESIGN_IDENTITY)"
sign_flags=(--force --sign "$CODESIGN_IDENTITY" --entitlements Resources/HoichoiForMac.entitlements)
if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    sign_flags+=(--options runtime --timestamp)
fi
codesign "${sign_flags[@]}" "$APP"
codesign --verify --strict --verbose=2 "$APP"

mkdir -p dist
ZIP="dist/Hoichoi-for-Mac-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Creating disk image"
# Stage the app next to an /Applications shortcut so users can drag-install.
rm -rf "build/dmg-staging"
mkdir -p "build/dmg-staging"
ditto "$APP" "build/dmg-staging/Hoichoi for Mac.app"
ln -s /Applications "build/dmg-staging/Applications"
DMG="dist/Hoichoi-for-Mac-$VERSION.dmg"
rm -f "$DMG"
hdiutil create \
    -volname "Hoichoi for Mac" \
    -srcfolder "build/dmg-staging" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG"
rm -rf "build/dmg-staging"
if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$DMG"
fi
hdiutil verify "$DMG"

echo
echo "Built: $APP"
echo "Zip:   $ZIP"
echo "DMG:   $DMG"
