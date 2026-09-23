import AppKit
import Carbon
import CatchMouseCore

extension Shortcut {
    var label: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result + keyLabel
    }

    static func from(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let functionKeys: [UInt16: String] = [
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
            100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13",
            107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
        ]
        // Function keys are useful standalone hotkeys. Ordinary typing still needs a modifier.
        guard functionKeys[event.keyCode] != nil || !flags.intersection([.command, .control, .option]).isEmpty else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let special: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End",
            116: "Page Up", 121: "Page Down"
        ]
        let label = functionKeys[event.keyCode] ?? special[event.keyCode] ?? event.characters(byApplyingModifiers: [])?.uppercased() ?? "Key \(event.keyCode)"
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
    }
}

final class ActionButton: NSButton {
    var onClick: (() -> Void)?

    init(_ title: String, action: @escaping () -> Void) {
        super.init(frame: .zero)
        self.title = title
        self.onClick = action
        bezelStyle = .rounded
        target = self
        self.action = #selector(performClickAction)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func performClickAction() { onClick?() }
}
