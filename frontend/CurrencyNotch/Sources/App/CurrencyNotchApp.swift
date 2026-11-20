import CurrencyCore
import SwiftUI

@main
struct CurrencyNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Must run before any localized string is loaded (ADR-0022).
        LanguageOverride.apply(SettingsStore().loadSettings().language)
    }

    var body: some Scene {
        // The pill and the menu-bar item are AppKit; the Settings window arrives in Phase 7.
        Settings { EmptyView() }
    }
}
