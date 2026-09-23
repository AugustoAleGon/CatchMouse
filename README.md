# CatchMouse

Move your mouse pointer between Mac displays with a keyboard shortcut.

CatchMouse is a free, open-source menu-bar app for **Intel and Apple Silicon Macs**
running **macOS 12 Monterey or later**. Assign a shortcut to each connected display,
or cycle through your displays with next and previous shortcuts. The pointer lands
in the center of the destination display.

This is a fresh Swift implementation. The original repository contained only a
compiled Intel app; its source and artwork are not used by this version.

## Features

- Custom global shortcuts for individual displays, with no fixed display limit.
- Next and previous display shortcuts, with wraparound.
- Saved assignments keyed to display UUIDs, so changing display order does not
  intentionally reassign your shortcuts.
- Automatic updates when displays connect, disconnect, or change arrangement.
- Disconnected display assignments stay saved and become active on reconnection.
- Support for negative display coordinates and mixed display scaling.
- Shortcut conflict feedback and buttons to try moving the pointer immediately.
- Native menu-bar controls, with no network service, account, or third-party dependency.

## Build and install

You need Xcode or the Xcode Command Line Tools with **Swift 5.9 or later** and a
macOS SDK. You can build both architectures from either an Intel or Apple Silicon Mac.

```sh
git clone https://github.com/AugustoAleGon/CatchMouse.git
cd CatchMouse
./scripts/build-universal.sh
open dist/CatchMouse.app
```

The script creates:

- `dist/CatchMouse.app` — one universal app containing `arm64` and `x86_64` binaries.
- `dist/CatchMouse-universal.zip` — the app packaged for transfer.

Drag the built app into Applications to install it. Quit the old CatchMouse before
using this version so it does not compete for the same shortcuts. The new app uses
its own preferences; old shortcuts are not imported.

Builds use an ad-hoc signature by default. They are intended for local testing and
are not Apple-notarized downloads. To distribute an app that passes Gatekeeper's
normal checks, follow the signing and notarization steps below.

## Use CatchMouse

1. Open CatchMouse. Settings appear on the first launch.
2. Click **Record shortcut** beside a display, then press a key combination such as
   **F18** or **Control + Option + 1**. Function keys **F1–F20** work on their own.
   Other keys need Command, Control, or Option; Shift is optional.
3. Repeat for the other displays. For example, assign Control + Option + 1, 2, and 3
   to a three-display setup.
4. Optionally assign **Next display** and **Previous display** to cycle from the
   display currently containing the pointer. Order is left to right, then top to
   bottom, with wraparound.
5. Close Settings. CatchMouse stays in the menu bar and the shortcuts work in other apps.

Use the pointer icon in the menu bar to reopen Settings, move to a display, or quit.
Press **Esc** to cancel recording, or click **Clear** to remove an assignment.
Shortcuts are temporarily paused while recording a new combination.

For a two-display setup, you can assign **F18** to the built-in display and **F19**
to the external display. Quit the original CatchMouse or another app that owns those
keys before assigning them here. Registration is exclusive, so CatchMouse reports
a conflict instead of silently sharing the shortcut. Depending on your keyboard,
F1–F12 may need the Fn/Globe key to send function keys instead of media controls.

Mirrored displays share a pointer destination. Use extended displays for independent
screen shortcuts. macOS may give a display a different UUID after a dock or hardware
change; if that happens, clear its disconnected assignment and record a new one.

For launch at login, add CatchMouse in your macOS Login Items settings.

## Troubleshooting

- **A shortcut does nothing:** verify CatchMouse is running, check Settings for a
  conflict, and try a combination not used by macOS or another app. Some system
  shortcuts are reserved even if registration succeeds.
- **A display is disconnected:** its assignment is retained, but its shortcut is
  inactive until that display returns. Clear a saved assignment to reuse its key.
- **The pointer does not move:** try the display's **Move** button and ensure it is
  an extended display. Remote desktop tools or other pointer utilities may interfere.
- **No Dock icon:** CatchMouse is a menu-bar utility. Open the app again to show Settings.

The app registers specific hotkeys using `RegisterEventHotKey` and moves the pointer
with `CGWarpMouseCursorPosition`. It does not install a global keyboard event tap,
capture screen contents, or request Input Monitoring permission.

## Development

```sh
swift test
swift run CatchMouse
./scripts/build-universal.sh
lipo dist/CatchMouse.app/Contents/MacOS/CatchMouse -verify_arch arm64 x86_64
codesign --verify --deep --strict dist/CatchMouse.app
```

Use the packaged app for normal use; `swift run` is useful during development. You
can also open `Package.swift` in Xcode. Build output is ignored by Git.

| Path | Purpose |
| --- | --- |
| `Sources/CatchMouse/` | AppKit interface, global hotkeys, and connected display discovery |
| `Sources/CatchMouseCore/` | Display navigation and persistent shortcut bindings |
| `Tests/CatchMouseCoreTests/` | Navigation, persistence, and conflict regression tests |
| `Tests/CatchMouseTests/` | Native hotkey registration, AppKit event dispatch, and shortcut recording tests |
| `Resources/Info.plist` | New app identity and minimum macOS version |
| `scripts/build-universal.sh` | Compile, combine, verify, sign, and package both architectures |
| `legacy/` | Original binary, excluded from the MIT license and new builds |

GitHub Actions runs the tests, builds both architectures, verifies the app signature,
and uploads the ZIP as a workflow artifact. It does not publish a release.

Before a public release, test on physical Intel and Apple Silicon Macs with multiple
displays: direct shortcuts, forward/backward cycling, mixed scaling, displays above
and left of the main screen, hot-plugging, persistence after relaunch, and conflicts
with another running app. Automated tests and architecture checks do not replace
those hardware checks.

## Signing a public release

With a Developer ID Application certificate installed in your keychain:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/build-universal.sh
xcrun notarytool submit dist/CatchMouse-universal.zip --keychain-profile YOUR_PROFILE --wait
xcrun stapler staple dist/CatchMouse.app
xcrun stapler validate dist/CatchMouse.app
spctl --assess --type execute --verbose dist/CatchMouse.app
ditto -c -k --sequesterRsrc --keepParent dist/CatchMouse.app dist/CatchMouse-universal.zip
```

Configure `YOUR_PROFILE` with your own Apple notarization credentials first. Keep
certificates and credentials out of the repository. After notarization succeeds,
staple and repackage the app before attaching the ZIP to a GitHub release. See Apple's
[universal binary documentation](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
and [notarization guide](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Contributing

Issues and pull requests are welcome. Describe the macOS version, Mac architecture,
display arrangement, and steps to reproduce a bug. Run `swift test` and the universal
build before submitting changes. Add regression tests for changes to navigation or
shortcut persistence. Contributions to the new implementation are under MIT.

## License

The new source code, build scripts, and documentation are released under the
[MIT License](LICENSE). Anyone can use, study, modify, and redistribute them while
retaining the license and copyright notice. MIT also permits commercial reuse; it
does not require derivative versions to be open source. CatchMouse itself is free.
See the [Open Source Initiative's MIT license page](https://opensource.org/license/mit).

**Exception:** `legacy/CatchMouse.app` is the original third-party binary and is not
covered by MIT. Its existing rights notices remain in place. See
[legacy/README.md](legacy/README.md).
