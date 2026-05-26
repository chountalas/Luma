#!/usr/bin/env bash
# One-command signed + notarized release.
# Usage:  ./script/release.sh            (builds version from project.yml default)
#         VERSION=0.1.5 ./script/release.sh
set -euo pipefail

APP_NAME="Luma"
VERSION="${VERSION:-0.1.4}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION-arm64.dmg"
ZIP_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION-arm64.zip"
SIGN_IDENTITY="Developer ID Application: Connor Hountalas (V54JNNN85Y)"
NOTARY_PROFILE="luma-notary"

cd "$ROOT_DIR"

echo "==> Building and signing $APP_NAME $VERSION"
CODE_SIGN_IDENTITY="$SIGN_IDENTITY" VERSION="$VERSION" ./script/package_release.sh >/dev/null

echo "==> Signing the disk image"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"

echo "==> Submitting to Apple for notarization (this takes a minute or two)"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling the notarization ticket"
xcrun stapler staple "$DMG_PATH"
xcrun stapler staple "$APP_PATH"

echo "==> Rebuilding the zip from the stapled app + refreshing checksums"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" "$DMG_PATH" > "$ROOT_DIR/dist/checksums.txt"

echo "==> Verifying Gatekeeper acceptance"
spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"

echo ""
echo "Done. Notarized files in dist/:"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
echo "  $ROOT_DIR/dist/checksums.txt"
echo ""
echo "Upload them to a GitHub release with:"
echo "  gh release upload v$VERSION dist/$APP_NAME-$VERSION-arm64.dmg dist/$APP_NAME-$VERSION-arm64.zip dist/checksums.txt --clobber -R chountalas/Luma"
