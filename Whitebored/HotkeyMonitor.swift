import AppKit

@MainActor
final class HotkeyMonitor {
    private var local: Any?
    private var lastFire = Date.distantPast
    var handler: (() -> Void)?

    func start() {
        stop()
        local = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.consider(event) ?? event
        }
    }

    func stop() {
        if let local { NSEvent.removeMonitor(local) }
        local = nil
    }

    private func consider(_ event: NSEvent) -> NSEvent? {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        guard isReturn, !event.isARepeat else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.shift) || flags.contains(.command) || flags.contains(.option) || flags.contains(.control) {
            return event
        }
        let now = Date()
        guard now.timeIntervalSince(lastFire) > 0.45 else { return nil }
        lastFire = now
        handler?()
        return nil
    }
}
