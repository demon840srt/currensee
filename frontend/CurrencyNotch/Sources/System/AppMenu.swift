import AppKit

/// Builds the one menu shared by the menu-bar icon and right-click on the pill (SPEC F22):
/// Show/Hide pill, Lock/Unlock position, Refresh now, Settings…, Quit.
@MainActor
final class AppMenuController: NSObject, NSMenuDelegate {
    private let model: AppModel
    var openSettings: () -> Void = {}

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
        menu.addItem(item(model.settings.isPillHidden ? String(localized: "Show Pill") : String(localized: "Hide Pill"),
                          #selector(toggleHidden)))
        menu.addItem(item(model.isPositionLocked ? String(localized: "Unlock Position") : String(localized: "Lock Position"),
                          #selector(toggleLock)))
        menu.addItem(item(String(localized: "Refresh Now"), #selector(refresh), key: "r"))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Settings…"), #selector(settings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Quit"), #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleHidden() { model.apply(.setPillHidden(!model.settings.isPillHidden)) }
    @objc private func toggleLock() { model.apply(.setPositionLocked(!model.isPositionLocked)) }
    @objc private func refresh() { model.refreshNow() }
    @objc private func settings() { openSettings() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

/// Menu-bar icon showing the shared menu.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem

    init(menuController: AppMenuController) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "dollarsign.circle",
                                           accessibilityDescription: String(localized: "CurrenSee"))
        let menu = menuController.makeMenu()
        menu.delegate = menuController
        statusItem.menu = menu
    }

    var menu: NSMenu? { statusItem.menu }
}
