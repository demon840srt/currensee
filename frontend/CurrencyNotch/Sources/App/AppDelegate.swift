import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var menuController: AppMenuController?
    private var pillController: PillPanelController?
    private var statusItemController: StatusItemController?
    private var settingsController: SettingsWindowController?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        Logger(subsystem: "com.afik.CurrencyNotch", category: "launch").debug(
            "localization \(Bundle.main.preferredLocalizations.first ?? "?", privacy: .public), layout \(NSApp.userInterfaceLayoutDirection == .rightToLeft ? "RTL" : "LTR", privacy: .public)")
        #endif
        let model = AppModel()
        let menuController = AppMenuController(model: model)
        let pillController = PillPanelController(model: model, menuController: menuController)
        let settingsController = SettingsWindowController(model: model)
        menuController.openSettings = { [weak settingsController] in settingsController?.show() }
        statusItemController = StatusItemController(menuController: menuController)
        pillController.show()
        model.start()
        #if DEBUG
        model.autoRegisterLoginItemIfNeeded(isReleaseBuild: false)
        #else
        model.autoRegisterLoginItemIfNeeded(isReleaseBuild: true)
        #endif

        // Refresh on wake from sleep (SPEC F18).
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { model.refreshNow() }
        }

        self.model = model
        self.menuController = menuController
        self.pillController = pillController
        self.settingsController = settingsController
    }
}
