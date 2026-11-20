import AppKit

/// Builds the one menu shared by the menu-bar icon and right-click on the pill (SPEC F22).
/// Phase 4 items: Lock/Unlock position, Quit. Phase 7 adds the rest.
@MainActor
final class AppMenuController: NSObject, NSMenuDelegate {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        populate(menu)
        return menu
    }

    /// Rebuild right before showing so titles reflect current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()
        let lockTitle = model.isPositionLocked
            ? String(localized: "Unlock Position")
            : String(localized: "Lock Position")
        let lock = NSMenuItem(title: lockTitle, action: #selector(toggleLock), keyEquivalent: "")
        lock.target = self
        menu.addItem(lock)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: String(localized: "Quit"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleLock() {
        model.setPositionLocked(!model.isPositionLocked)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

/// Menu-bar icon showing the shared menu.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem

    init(menuController: AppMenuController) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "dollarsign.circle",
                                           accessibilityDescription: String(localized: "Currency Notch"))
        let menu = menuController.makeMenu()
        menu.delegate = menuController
        statusItem.menu = menu
    }
}
