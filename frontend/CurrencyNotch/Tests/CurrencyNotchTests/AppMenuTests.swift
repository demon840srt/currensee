import AppKit
import CurrencyCore
import Testing
@testable import CurrencyNotch

/// Login-item fake so tests never touch the real ServiceManagement registration.
private struct StubLoginItem: LoginItemService {
    var status: LoginItemStatus { .notRegistered }
    func register() throws {}
    func unregister() throws {}
}

@MainActor
@Suite("AppMenu")
struct AppMenuTests {
    private func makeModel() -> (AppModel, UserDefaults, String) {
        let name = "CurrencyNotchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (AppModel(store: SettingsStore(defaults: defaults), loginItems: StubLoginItem()), defaults, name)
    }

    private func titles(_ menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "—" : $0.title }
    }

    @Test func rightClickMenuMatchesMenuBarMenu() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }
        let controller = AppMenuController(model: model)

        // Menu-bar menu is refreshed through the delegate; the right-click menu is built fresh.
        let menuBar = controller.makeMenu()
        for state in [(false, false), (true, false), (false, true), (true, true)] {
            model.apply(.setPositionLocked(state.0))
            model.apply(.setPillHidden(state.1))
            controller.menuNeedsUpdate(menuBar)
            let rightClick = controller.makeMenu()
            #expect(titles(menuBar) == titles(rightClick))
            #expect(menuBar.items.map(\.action) == rightClick.items.map(\.action))
        }
    }

    @Test func menuHasAllSpecItems() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }
        // Menu item targets are weak; keep the controller alive like AppDelegate does.
        let controller = AppMenuController(model: model)
        let menu = controller.makeMenu()
        let real = menu.items.filter { !$0.isSeparatorItem }
        #expect(real.count == 5)   // Show/Hide, Lock/Unlock, Refresh now, Settings…, Quit
        #expect(real.allSatisfy { $0.target === controller && $0.action != nil })
    }
}
