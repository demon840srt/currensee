import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pillPanel: PillPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = PillPanel()
        panel.moveToTopCenter(of: NSScreen.main)
        panel.orderFrontRegardless()
        pillPanel = panel
    }
}
