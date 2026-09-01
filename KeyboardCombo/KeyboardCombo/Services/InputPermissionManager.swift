import AppKit
import CoreGraphics
import Observation

@MainActor
@Observable
final class InputPermissionManager {
    private(set) var isGranted = false

    init() {
        refresh()
    }

    func refresh() {
        isGranted = CGPreflightListenEventAccess()
    }

    @discardableResult
    func request() -> Bool {
        isGranted = CGRequestListenEventAccess()
        if !isGranted {
            openSystemSettings()
        }
        return isGranted
    }

    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
