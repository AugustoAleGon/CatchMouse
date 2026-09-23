import XCTest
import CoreGraphics
@testable import CatchMouseCore

final class CatchMouseCoreTests: XCTestCase {
    let left = DisplayTarget(id: "left", bounds: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
    let main = DisplayTarget(id: "main", bounds: CGRect(x: 0, y: 0, width: 1440, height: 900))
    let upper = DisplayTarget(id: "upper", bounds: CGRect(x: 0, y: -1200, width: 1920, height: 1200))

    func testCentersUseGlobalPointsIncludingNegativeCoordinates() {
        XCTAssertEqual(left.center, CGPoint(x: -960, y: 540))
        XCTAssertEqual(upper.center, CGPoint(x: 960, y: -600))
        XCTAssertEqual(main.center, CGPoint(x: 720, y: 450))
    }

    func testNavigationUsesPointerDisplayAndWrapsInBothDirections() {
        let displays = [main, upper, left]
        XCTAssertEqual(DisplayNavigation.destination(in: displays, from: left.center, forward: true), upper)
        XCTAssertEqual(DisplayNavigation.destination(in: displays, from: main.center, forward: true), left)
        XCTAssertEqual(DisplayNavigation.destination(in: displays, from: left.center, forward: false), main)
        XCTAssertEqual(DisplayNavigation.destination(in: displays, from: upper.center, forward: false), left)
    }

    func testEmptySingleAndDisconnectedDisplay() {
        XCTAssertNil(DisplayNavigation.destination(in: [], from: .zero, forward: true))
        XCTAssertEqual(DisplayNavigation.destination(in: [main], from: main.center, forward: false), main)
        XCTAssertEqual(DisplayNavigation.destination(in: [main, left], from: upper.center, forward: true), left)
    }

    func testShortcutPersistenceConflictAndRemoval() throws {
        let suite = "CatchMouseTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShortcutStore(defaults: defaults)
        let action = ShortcutAction.display("persistent-display-uuid")
        let shortcut = Shortcut(keyCode: 18, modifiers: 768, keyLabel: "1")
        store.set(shortcut, for: action)
        XCTAssertEqual(ShortcutStore(defaults: defaults).bindings[action], shortcut)
        // A layout-dependent label must not let a duplicate hardware shortcut through.
        let relabeled = Shortcut(keyCode: 18, modifiers: 768, keyLabel: "&")
        XCTAssertEqual(store.conflictingAction(for: relabeled, excluding: ShortcutAction.next), action)
        XCTAssertNil(store.conflictingAction(for: shortcut, excluding: action))
        store.set(nil, for: action)
        XCTAssertNil(ShortcutStore(defaults: defaults).bindings[action])
    }

    func testCorruptPreferencesDoNotPreventLaunch() throws {
        let suite = "CatchMouseTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: "shortcuts.v1")
        XCTAssertTrue(ShortcutStore(defaults: defaults).bindings.isEmpty)
    }
}
