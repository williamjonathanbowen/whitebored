import AppKit

@MainActor
final class HotkeyMonitor {
    private var local: Any?
    private var global: Any?
    private var chordDown = false
    private var lastFire = Date.distantPast
    var handler: (() -> Void)?

    func start() {
        stop()
        local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.consider(event)
            return event
        }
        global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.consider(event)
        }
    }

    func stop() {
        if let local { NSEvent.removeMonitor(local) }
        if let global { NSEvent.removeMonitor(global) }
        local = nil
        global = nil
        chordDown = false
    }

    private func consider(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function, .help])
        let isChord = flags.contains(.command) && flags.contains(.option)
            && !flags.contains(.shift) && !flags.contains(.control)

        if isChord {
            guard !chordDown else { return }
            chordDown = true
            let now = Date()
            guard now.timeIntervalSince(lastFire) > 0.7 else { return }
            lastFire = now
            handler?()
            return
        }
        chordDown = false
    }
}
