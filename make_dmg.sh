#!/bin/bash
# Crée dist/StatGithub-<version>.dmg (avec lien vers Applications) et sa somme SHA-256.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-1.0}"
APP="build/StatGithub.app"
[ -d "$APP" ] || ./build_app.sh

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
xattr -cr "$STAGE/StatGithub.app"   # sinon la signature est invalidée par des attributs Finder
codesign --verify --strict "$STAGE/StatGithub.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p dist
DMG="dist/StatGithub-${VERSION}.dmg"
rm -f "$DMG"
hdiutil create -volname "StatGithub" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
(cd dist && shasum -a 256 "StatGithub-${VERSION}.dmg" > "StatGithub-${VERSION}.dmg.sha256")
echo "✅ $DMG"
cat "dist/StatGithub-${VERSION}.dmg.sha256"
