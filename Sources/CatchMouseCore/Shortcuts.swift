import Foundation

public struct Shortcut: Codable, Equatable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let keyLabel: String

    public init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    public func matches(_ other: Shortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }
}

/// Display actions use the display UUID, never its transient position in NSScreen.screens.
public enum ShortcutAction {
    public static let next = "next"
    public static let previous = "previous"
    public static func display(_ uuid: String) -> String { "display:\(uuid)" }
}

public final class ShortcutStore {
    private let defaults: UserDefaults
    private let key = "shortcuts.v1"
    public private(set) var bindings: [String: Shortcut]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([String: Shortcut].self, from: data) {
            bindings = saved
        } else {
            bindings = [:]
        }
    }

    public func conflictingAction(for shortcut: Shortcut, excluding action: String) -> String? {
        bindings.keys.sorted().first { $0 != action && bindings[$0]?.matches(shortcut) == true }
    }

    public func set(_ shortcut: Shortcut?, for action: String) {
        bindings[action] = shortcut
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: key)
        }
    }
}
