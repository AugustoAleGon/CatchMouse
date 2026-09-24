Download **CatchMouse-universal.dmg** below. It contains one app for **Intel and
Apple Silicon Macs running macOS 12 Monterey or later**. No source checkout,
Xcode, or developer tools are needed.

1. Open the DMG and drag **CatchMouse** into **Applications**.
2. Eject the DMG, quit any older CatchMouse, and open the installed app.
3. Assign shortcuts to your displays in Settings. CatchMouse stays in the menu bar.

**First launch:** this release is ad-hoc signed and **not notarized by Apple**.
If macOS blocks it because the developer cannot be verified, and you trust the
download, try opening the installed app, then choose **Open Anyway** in
**System Settings → Privacy & Security**. On Monterey, use **System Preferences →
Security & Privacy → General**. See [Apple's instructions](https://support.apple.com/en-us/102445).

The ZIP contains the same app as an alternative to the DMG. `SHA256SUMS.txt`
contains SHA-256 checksums for both downloads. To check downloaded files in Terminal,
put all three assets in the same folder and run `shasum -a 256 -c SHA256SUMS.txt`.
