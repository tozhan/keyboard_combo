import CoreGraphics
import Foundation

private func keyboardEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}

struct ModifierPressTracker {
    private var pressed: Set<UInt16> = []
    private var lastCapsLockEvent = Date.distantPast

    mutating func shouldCount(keyCode: UInt16, at date: Date) -> Bool {
        guard KeyCatalog.modifierKeyCodes.contains(keyCode) else { return false }

        if keyCode == 57 {
            guard date.timeIntervalSince(lastCapsLockEvent) > 0.1 else { return false }
            lastCapsLockEvent = date
            return true
        }

        if pressed.remove(keyCode) != nil {
            return false
        }
        pressed.insert(keyCode)
        return true
    }

    mutating func reset() {
        pressed.removeAll()
        lastCapsLockEvent = .distantPast
    }
}

final class KeyboardMonitor: @unchecked Sendable {
    private let onKeyPress: @Sendable (KeyPress) -> Void
    private let stateLock = NSLock()
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var eventTap: CFMachPort?
    private var stopRequested = false
    private var modifierTracker = ModifierPressTracker()

    init(onKeyPress: @escaping @Sendable (KeyPress) -> Void) {
        self.onKeyPress = onKeyPress
    }

    var isRunning: Bool {
        stateLock.withLock { thread != nil }
    }

    func start() {
        stateLock.lock()
        guard thread == nil else {
            stateLock.unlock()
            return
        }

        let monitorThread = Thread { [weak self] in
            self?.run()
        }
        monitorThread.name = "KeyboardCombo.EventTap"
        monitorThread.qualityOfService = .userInteractive
        stopRequested = false
        thread = monitorThread
        stateLock.unlock()
        monitorThread.start()
    }

    func stop() {
        let currentRunLoop = stateLock.withLock {
            stopRequested = true
            return runLoop
        }
        if let currentRunLoop {
            CFRunLoopStop(currentRunLoop)
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = stateLock.withLock({ eventTap }) {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        let rawCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard rawCode >= 0, rawCode <= UInt16.max else { return }
        let keyCode = UInt16(rawCode)

        switch type {
        case .keyDown:
            onKeyPress(
                KeyPress(
                    keyCode: keyCode,
                    occurredAt: .now,
                    isAutoRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                )
            )
        case .flagsChanged:
            handleModifier(keyCode: keyCode)
        default:
            break
        }
    }

    private func handleModifier(keyCode: UInt16) {
        let now = Date.now
        if modifierTracker.shouldCount(keyCode: keyCode, at: now) {
            onKeyPress(KeyPress(keyCode: keyCode, occurredAt: now, isAutoRepeat: false))
        }
    }

    private func run() {
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keyboardEventTapCallback,
            userInfo: userInfo
        ) else {
            stateLock.withLock {
                thread = nil
            }
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let currentRunLoop = CFRunLoopGetCurrent()
        let shouldStop = stateLock.withLock {
            eventTap = tap
            runLoop = currentRunLoop
            return stopRequested
        }
        CFRunLoopAddSource(currentRunLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        if !shouldStop {
            CFRunLoopRun()
        }

        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(currentRunLoop, source, .commonModes)
        stateLock.withLock {
            eventTap = nil
            runLoop = nil
            thread = nil
            stopRequested = false
        }
        modifierTracker.reset()
    }
}
