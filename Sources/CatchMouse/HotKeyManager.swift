import Carbon
import CatchMouseCore

/// RegisterEventHotKey receives only explicit shortcuts; it does not monitor typing.
final class HotKeyManager {
    private var handler: EventHandlerRef?
    private var references: [EventHotKeyRef] = []
    private var actions: [UInt32: String] = [:]
    var onAction: ((String) -> Void)?
    private(set) var installationStatus: OSStatus = noErr
    private static let signature: OSType = 0x434D5345 // CMSE

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        installationStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == HotKeyManager.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            guard let action = manager.actions[identifier.id] else {
                return OSStatus(eventNotHandledErr)
            }
            manager.onAction?(action)
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func register(_ bindings: [String: Shortcut]) -> [String: OSStatus] {
        unregisterAll()
        var failures: [String: OSStatus] = [:]
        for (index, action) in bindings.keys.sorted().enumerated() {
            guard let shortcut = bindings[action] else { continue }
            guard installationStatus == noErr else {
                failures[action] = installationStatus
                continue
            }
            let id = UInt32(index + 1)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                                             EventHotKeyID(signature: Self.signature, id: id),
                                             GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
            if status == noErr, let reference {
                references.append(reference)
                actions[id] = action
            } else {
                failures[action] = status
            }
        }
        return failures
    }

    func unregisterAll() {
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
        actions.removeAll()
    }

    deinit {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
    }
}
