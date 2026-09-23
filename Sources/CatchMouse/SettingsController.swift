import AppKit
import CatchMouseCore

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

final class SettingsController: NSWindowController, NSWindowDelegate {
    struct Row {
        let action: String
        let title: String
        let detail: String
        let connected: Bool
    }

    var onAssign: ((Shortcut?, String) -> String?)?
    var onRecordingChanged: ((Bool) -> Void)?
    var onMove: ((String) -> Void)?
    private var rows: [Row] = []
    private var bindings: [String: Shortcut] = [:]
    private var failures: Set<String> = []
    private var eventMonitor: Any?
    private var recordingAction: String?
    private let stack = FlippedStackView()
    private let message = NSTextField(wrappingLabelWithString: "")

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 500),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "CatchMouse"
        window.minSize = NSSize(width: 620, height: 400)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.center()
        let content = window.contentView!
        let heading = NSTextField(labelWithString: "Your pointer. Any screen.")
        heading.font = .systemFont(ofSize: 25, weight: .semibold)
        let intro = NSTextField(wrappingLabelWithString:
            "Assign a shortcut to jump to the center of a display. Shortcuts work while you use other apps.")
        intro.textColor = .secondaryLabelColor
        let footer = NSTextField(wrappingLabelWithString:
            "Use F1–F20 on their own, or ⌘ Command, ⌃ Control, or ⌥ Option with a key. Esc cancels. Changes save automatically.")
        footer.font = .systemFont(ofSize: 12)
        footer.textColor = .secondaryLabelColor
        message.font = .systemFont(ofSize: 12)
        message.textColor = .systemRed
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = stack
        for view in [heading, intro, scroll, message, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 26),
            intro.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 10),
            intro.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            intro.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -26),
            scroll.topAnchor.constraint(equalTo: intro.bottomAnchor, constant: 24),
            scroll.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: intro.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: message.topAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            message.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            message.trailingAnchor.constraint(equalTo: intro.trailingAnchor),
            message.heightAnchor.constraint(greaterThanOrEqualToConstant: 18),
            message.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8),
            footer.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: intro.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -22)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(rows: [Row], bindings: [String: Shortcut], failures: Set<String>) {
        self.rows = rows
        self.bindings = bindings
        self.failures = failures
        render()
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func render() {
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        for row in rows {
            let title = NSTextField(labelWithString: row.title)
            title.font = .systemFont(ofSize: 13, weight: .semibold)
            let detail = NSTextField(wrappingLabelWithString:
                failures.contains(row.action) ? "Shortcut unavailable. Choose another combination." : row.detail)
            detail.font = .systemFont(ofSize: 11)
            detail.textColor = failures.contains(row.action) ? .systemRed : .secondaryLabelColor
            let labels = NSStackView(views: [title, detail])
            labels.orientation = .vertical
            labels.alignment = .leading
            labels.spacing = 3
            let record = ActionButton(recordingAction == row.action ? "Press shortcut…" : (bindings[row.action]?.label ?? "Record shortcut")) { [weak self] in
                self?.startRecording(row.action)
            }
            record.widthAnchor.constraint(equalToConstant: 155).isActive = true
            record.setAccessibilityLabel("Shortcut for \(row.title)")
            let clear = ActionButton("Clear") { [weak self] in
                self?.stopRecording()
                if let error = self?.onAssign?(nil, row.action) { self?.message.stringValue = error }
            }
            clear.widthAnchor.constraint(equalToConstant: 55).isActive = true
            clear.isEnabled = bindings[row.action] != nil
            clear.setAccessibilityLabel("Clear shortcut for \(row.title)")
            let move = ActionButton("Move") { [weak self] in self?.onMove?(row.action) }
            move.widthAnchor.constraint(equalToConstant: 55).isActive = true
            move.isEnabled = row.connected
            move.setAccessibilityLabel("Move pointer to \(row.title)")
            let line = NSStackView(views: [labels, record, clear, move])
            line.alignment = .centerY
            line.distribution = .fill
            line.spacing = 10
            labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
            stack.addArrangedSubview(line)
            line.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -4).isActive = true
            let separator = NSBox()
            separator.boxType = .separator
            stack.addArrangedSubview(separator)
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -4).isActive = true
        }
    }

    private func startRecording(_ action: String) {
        stopRecording()
        recordingAction = action
        message.stringValue = "Press your shortcut now, or Esc to cancel."
        onRecordingChanged?(true)
        render()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isKeyWindow == true else { return event }
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }
            guard let shortcut = Shortcut.from(event) else {
                self.message.stringValue = "Press a function key such as F18, or include Command, Control, or Option."
                return nil
            }
            // Remove the monitor before assigning; the assignment rebuilds the shortcut registry.
            self.stopRecording()
            if let error = self.onAssign?(shortcut, action) { self.message.stringValue = error }
            return nil
        }
    }

    func stopRecording() {
        guard recordingAction != nil else { return }
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        recordingAction = nil
        message.stringValue = ""
        onRecordingChanged?(false)
        render()
    }

    func windowWillClose(_ notification: Notification) { stopRecording() }
    func windowDidResignKey(_ notification: Notification) { stopRecording() }
}
