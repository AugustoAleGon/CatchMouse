import XCTest
import Carbon
import AppKit
import CatchMouseCore
@testable import CatchMouse

final class HotKeyManagerTests: XCTestCase {
    func testHotKeyEventReachesActionThroughAppKitEventLoop() throws {
        let application = NSApplication.shared
        let manager = HotKeyManager()
        application.setActivationPolicy(.prohibited)
        application.finishLaunching()
        let shortcut = Shortcut(keyCode: UInt32(kVK_F18),
                                modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey), keyLabel: "F18")
        XCTAssertTrue(manager.register(["next": shortcut]).isEmpty)
        defer { manager.unregisterAll() }
        var received: String?
        manager.onAction = { received = $0 }
        var event: EventRef?
        XCTAssertEqual(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed),
                                   0, EventAttributes(kEventAttributeUserEvent), &event), noErr)
        let hotKeyEvent = try XCTUnwrap(event)
        defer { ReleaseEvent(hotKeyEvent) }
        var identifier = EventHotKeyID(signature: 0x434D5345, id: 1)
        XCTAssertEqual(SetEventParameter(hotKeyEvent, EventParamName(kEventParamDirectObject),
                                         EventParamType(typeEventHotKeyID),
                                         MemoryLayout<EventHotKeyID>.size, &identifier), noErr)
        var target = GetApplicationEventTarget()
        XCTAssertEqual(SetEventParameter(hotKeyEvent, EventParamName(kEventParamPostTarget),
                                         EventParamType(typeEventTargetRef),
                                         MemoryLayout<EventTargetRef?>.size, &target), noErr)
        XCTAssertEqual(PostEventToQueue(GetMainEventQueue(), hotKeyEvent, Int16(kEventPriorityStandard)), noErr)
        // Exercise the AppKit event loop used by the app, rather than bypassing it
        // with a direct Carbon SendEventToEventTarget call.
        let deadline = Date().addingTimeInterval(0.1)
        while received == nil && Date() < deadline {
            if let event = application.nextEvent(matching: .any, until: deadline, inMode: .default, dequeue: true) {
                application.sendEvent(event)
            }
        }
        XCTAssertEqual(received, "next")
    }

    func testOperatingSystemConflictAndUnregistration() {
        let first = HotKeyManager()
        let second = HotKeyManager()
        XCTAssertEqual(first.installationStatus, noErr)
        XCTAssertEqual(second.installationStatus, noErr)
        // An intentionally unusual shortcut minimizes interference with a developer's apps.
        let shortcut = Shortcut(keyCode: UInt32(kVK_F19),
                                modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey), keyLabel: "F19")
        defer { first.unregisterAll(); second.unregisterAll() }
        XCTAssertTrue(first.register(["first": shortcut]).isEmpty)
        XCTAssertNotNil(second.register(["second": shortcut])["second"])
        first.unregisterAll()
        XCTAssertTrue(second.register(["second": shortcut]).isEmpty,
                      "Releasing an assignment must allow the same shortcut to be registered again.")
    }

    func testRecorderRejectsTypingAndPreservesHardwareKeyAndModifiers() throws {
        func event(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                                          modifierFlags: flags, timestamp: 0, windowNumber: 0,
                                          context: nil, characters: "a", charactersIgnoringModifiers: "a",
                                          isARepeat: false, keyCode: 0))
        }
        XCTAssertNil(Shortcut.from(try event([])))
        XCTAssertNil(Shortcut.from(try event(.shift)))
        let recorded = try XCTUnwrap(Shortcut.from(try event([.control, .option, .shift, .capsLock])))
        XCTAssertEqual(recorded.keyCode, 0)
        XCTAssertEqual(recorded.modifiers, UInt32(controlKey | optionKey | shiftKey))
    }

    func testStandaloneF18AndF19CanBeRecorded() throws {
        for (keyCode, label) in [(kVK_F18, "F18"), (kVK_F19, "F19")] {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: .function, timestamp: 0, windowNumber: 0, context: nil,
                characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(keyCode)))
            let shortcut = try XCTUnwrap(Shortcut.from(event))
            XCTAssertEqual(shortcut.keyCode, UInt32(keyCode))
            XCTAssertEqual(shortcut.modifiers, 0)
            XCTAssertEqual(shortcut.label, label)
        }
    }
}
