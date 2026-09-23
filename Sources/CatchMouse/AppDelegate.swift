import AppKit
import CatchMouseCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ShortcutStore()
    private let hotKeys = HotKeyManager()
    private var statusItem: NSStatusItem!
    private var settings: SettingsController!
    private var displays: [ConnectedDisplay] = []
    private var failures: [String: OSStatus] = [:]
    private var recording = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "CatchMouse")
        statusItem.button?.toolTip = "CatchMouse — move your pointer between displays"
        settings = SettingsController()
        settings.onAssign = { [weak self] shortcut, action in self?.assign(shortcut, to: action) }
        settings.onRecordingChanged = { [weak self] recording in
            guard let self else { return }
            self.recording = recording
            if recording { self.hotKeys.unregisterAll() } else { self.refresh() }
        }
        settings.onMove = { [weak self] action in self?.perform(action) }
        hotKeys.onAction = { [weak self] action in self?.perform(action) }
        NotificationCenter.default.addObserver(self, selector: #selector(screenConfigurationChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenConfigurationChanged),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        refresh()
        if !UserDefaults.standard.bool(forKey: "hasOpenedSettings") || !failures.isEmpty {
            showSettings()
        }
    }

    private func installMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let preferences = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        preferences.target = self
        appMenu.addItem(preferences)
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit CatchMouse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        appMenu.addItem(quit)
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.mainMenu = menu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    @objc private func screenConfigurationChanged() {
        settings.stopRecording()
        refresh()
    }

    private func refresh() {
        displays = ConnectedDisplay.current()
        let activeActions = Set(displays.map(\.action) + [ShortcutAction.next, ShortcutAction.previous])
        if !recording {
            failures = hotKeys.register(store.bindings.filter { activeActions.contains($0.key) })
        }
        updateInterface()
    }

    private func updateInterface() {
        var rows = displays.enumerated().map { index, display in
            SettingsController.Row(action: display.action, title: "Display \(index + 1) · \(display.name)",
                                   detail: "\(Int(display.target.bounds.width)) × \(Int(display.target.bounds.height)) points",
                                   connected: true)
        }
        rows += [
            .init(action: ShortcutAction.next, title: "Next display", detail: "Left to right, then top to bottom; wraps around.", connected: !displays.isEmpty),
            .init(action: ShortcutAction.previous, title: "Previous display", detail: "Cycle in the opposite direction.", connected: !displays.isEmpty)
        ]
        let connectedActions = Set(displays.map(\.action))
        let savedNames = UserDefaults.standard.dictionary(forKey: "displayNames") as? [String: String] ?? [:]
        var names = savedNames
        for display in displays { names[display.action] = display.name }
        UserDefaults.standard.set(names, forKey: "displayNames")
        for action in store.bindings.keys.sorted() where action.hasPrefix("display:") && !connectedActions.contains(action) {
            rows.append(.init(action: action, title: names[action] ?? "Saved display",
                              detail: "Disconnected · shortcut resumes when this display returns.", connected: false))
        }
        settings.update(rows: rows, bindings: store.bindings, failures: Set(failures.keys))

        let menu = NSMenu()
        let header = NSMenuItem(title: "CatchMouse", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for (index, display) in displays.enumerated() {
            addAction(display.action, title: "Display \(index + 1) · \(display.name)", to: menu)
        }
        menu.addItem(.separator())
        addAction(ShortcutAction.next, title: "Next display", to: menu)
        addAction(ShortcutAction.previous, title: "Previous display", to: menu)
        menu.addItem(.separator())
        let preferences = NSMenuItem(title: failures.isEmpty ? "Settings…" : "Settings… (shortcut conflict)",
                                     action: #selector(showSettings), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)
        let quit = NSMenuItem(title: "Quit CatchMouse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func addAction(_ action: String, title: String, to menu: NSMenu) {
        let suffix = store.bindings[action].map { "    \($0.label)" } ?? ""
        let item = NSMenuItem(title: title + suffix, action: #selector(menuMove(_:)), keyEquivalent: "")
        item.representedObject = action
        item.target = self
        menu.addItem(item)
    }

    private func assign(_ shortcut: Shortcut?, to action: String) -> String? {
        if let shortcut, let conflict = store.conflictingAction(for: shortcut, excluding: action) {
            let title: String
            if conflict == ShortcutAction.next { title = "Next display" }
            else if conflict == ShortcutAction.previous { title = "Previous display" }
            else { title = "another display (possibly disconnected)" }
            return "That shortcut is already assigned to \(title). Clear it first."
        }
        let previous = store.bindings[action]
        store.set(shortcut, for: action)
        refresh()
        if let status = failures[action], shortcut != nil {
            store.set(previous, for: action)
            refresh()
            return "Shortcut unavailable (\(status)). Quit any app using it, including the old CatchMouse, then record it again."
        }
        return nil
    }

    private func perform(_ action: String) {
        // Resolve again at invocation time so hot-plugging cannot leave stale coordinates.
        let current = ConnectedDisplay.current()
        let destination: DisplayTarget?
        if action == ShortcutAction.next || action == ShortcutAction.previous {
            guard let pointer = CGEvent(source: nil)?.location else { NSSound.beep(); return }
            destination = DisplayNavigation.destination(in: current.map(\.target), from: pointer,
                                                        forward: action == ShortcutAction.next)
        } else {
            destination = current.first { $0.action == action }?.target
        }
        guard let destination else { NSSound.beep(); return }
        let result = CGWarpMouseCursorPosition(destination.center)
        if result != .success {
            let alert = NSAlert()
            alert.messageText = "The pointer could not be moved"
            alert.informativeText = "macOS returned error \(result.rawValue). Check that the display is connected and try again."
            alert.runModal()
        }
    }

    @objc private func menuMove(_ sender: NSMenuItem) {
        if let action = sender.representedObject as? String { perform(action) }
    }

    @objc private func showSettings() {
        UserDefaults.standard.set(true, forKey: "hasOpenedSettings")
        settings.present()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys.unregisterAll()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
