import AppKit
import CatchMouseCore

struct ConnectedDisplay {
    let target: DisplayTarget
    let name: String

    var action: String { ShortcutAction.display(target.id) }

    static func current() -> [ConnectedDisplay] {
        let displays = NSScreen.screens.compactMap { screen -> ConnectedDisplay? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            // A mirrored secondary display is not an independent pointer destination.
            guard CGDisplayMirrorsDisplay(displayID) == kCGNullDirectDisplay,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
                  let identifier = CFUUIDCreateString(nil, uuid) as String? else { return nil }
            return ConnectedDisplay(target: DisplayTarget(id: identifier, bounds: CGDisplayBounds(displayID)),
                                    name: screen.localizedName)
        }
        let order = DisplayNavigation.ordered(displays.map(\.target)).map(\.id)
        return order.compactMap { id in displays.first { $0.target.id == id } }
    }
}
