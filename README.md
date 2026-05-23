# Luma

Luma is a clean-room, native Apple Silicon macOS menu bar utility for screen warmth, dimming, and sunset-to-sunrise scheduling.

It does not reuse Iris source code, assets, license behavior, or private app data. The optional importer only maps safe visual and schedule preferences from the local Iris preferences plist.

## Build And Run

```bash
./script/build_and_run.sh --verify
```

The app uses a CoreGraphics gamma table where macOS allows it and falls back to click-through overlay windows if a display rejects direct gamma changes.

Quit Iris before using Luma as the daily driver. Running both at the same time can make their display filters override each other.

## Package A Downloadable App

```bash
./script/package_release.sh
```

This produces:

- `dist/Luma-0.1.1-arm64.dmg`
- `dist/Luma-0.1.1-arm64.zip`
- `dist/checksums.txt`

The local package is signed ad hoc by default. For a no-warning public download, set `CODE_SIGN_IDENTITY` to a Developer ID Application certificate and notarize the DMG.
