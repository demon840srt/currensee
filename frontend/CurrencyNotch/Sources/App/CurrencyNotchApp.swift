import SwiftUI

@main
struct CurrencyNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The pill and the menu-bar item are AppKit; the Settings window arrives in Phase 7.
        Settings { EmptyView() }
    }
}
