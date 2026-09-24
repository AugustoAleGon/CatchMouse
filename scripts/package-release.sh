#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep packaging separate so a notarized, stapled app can be repackaged without
# rebuilding it or replacing its signature.
app="dist/CatchMouse.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
lipo "$app/Contents/MacOS/CatchMouse" -verify_arch arm64 x86_64
codesign --verify --deep --strict "$app"

mkdir -p build
stage=$(mktemp -d "$PWD/build/dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/CatchMouse.app"
ln -s /Applications "$stage/Applications"
cp Resources/INSTALL.txt "$stage/INSTALL.txt"

ditto -c -k --sequesterRsrc --keepParent "$app" dist/CatchMouse-universal.zip
hdiutil create -volname "CatchMouse $version" -srcfolder "$stage" \
    -fs HFS+ -format UDZO -ov dist/CatchMouse-universal.dmg
hdiutil verify dist/CatchMouse-universal.dmg
(
    cd dist
    shasum -a 256 CatchMouse-universal.dmg CatchMouse-universal.zip > SHA256SUMS.txt
)
echo "Built CatchMouse $version: dist/CatchMouse-universal.dmg and dist/CatchMouse-universal.zip"
