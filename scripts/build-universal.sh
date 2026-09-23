#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Compile from source for both CPUs, even when building on an Apple Silicon host.
for arch in arm64 x86_64; do
    swift build --configuration release --arch "$arch" --scratch-path "build/$arch"
done

app="dist/CatchMouse.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
arm_bin=$(swift build -c release --arch arm64 --scratch-path build/arm64 --show-bin-path)
intel_bin=$(swift build -c release --arch x86_64 --scratch-path build/x86_64 --show-bin-path)
lipo -create "$arm_bin/CatchMouse" "$intel_bin/CatchMouse" -output "$app/Contents/MacOS/CatchMouse"
lipo "$app/Contents/MacOS/CatchMouse" -verify_arch arm64 x86_64

# Ad-hoc signing supports local use. Set SIGNING_IDENTITY to a Developer ID
# Application identity to produce an archive suitable for notarization.
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app"
else
    codesign --force --sign - "$app"
fi
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" dist/CatchMouse-universal.zip
echo "Built $app and dist/CatchMouse-universal.zip"
lipo -archs "$app/Contents/MacOS/CatchMouse"
