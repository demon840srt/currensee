import AppKit
import SwiftUI

/// Hosts the SwiftUI settings in a plain window; more reliable than the Settings scene for an
/// LSUIElement (menu-bar-only) app.
@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = String(localized: "CurrenSee Settings")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        model.reloadLoginItemState()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
