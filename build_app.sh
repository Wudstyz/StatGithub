#!/bin/bash
# Construit StatGithub.app (Apple Silicon, signature ad hoc). Rien à installer à part Xcode.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/StatGithub.app"
VERSION="${VERSION:-1.0}"
MIN_MACOS="14.0"   # @Observable et les sélections de graphiques exigent macOS 14

echo "▶︎ Compilation (arm64, release)…"
swift build -c release --arch arm64

echo "▶︎ Icône…"
if [ ! -f Resources/icon.icns ]; then
  TMP="$(mktemp -d)"
  swift tools/make_icon.swift "$TMP"
  iconutil -c icns "$TMP/icon.iconset" -o Resources/icon.icns
  mkdir -p docs && cp "$TMP/icon-1024.png" docs/icon.png
  rm -rf "$TMP"
fi

echo "▶︎ Assemblage de l'app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/StatGithub "$APP/Contents/MacOS/StatGithub"
cp Resources/icon.icns "$APP/Contents/Resources/icon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>StatGithub</string>
  <key>CFBundleDisplayName</key><string>StatGithub</string>
  <key>CFBundleIdentifier</key><string>fr.woodstyles.statgithub</string>
  <key>CFBundleExecutable</key><string>StatGithub</string>
  <key>CFBundleIconFile</key><string>icon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSRequiresAquaSystemAppearance</key><true/>
  <key>CFBundleDevelopmentRegion</key><string>fr</string>
  <key>NSHumanReadableCopyright</key><string>© Woodstyles. Licence MIT.</string>
</dict>
</plist>
PLIST

echo "▶︎ Signature ad hoc…"
xattr -cr "$APP"   # le Bureau (iCloud) ajoute des attributs Finder qui empêchent la signature
codesign --force --sign - "$APP/Contents/MacOS/StatGithub"
codesign --force --sign - "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "✅ $APP"
