import AppKit
import CurrencyCore

/// Per-app language (SPEC F30, ADR-0022). macOS fixes an app's localization at launch, so the choice is written
/// to the app's `AppleLanguages` preference — applied at startup before any string is loaded, and after a
/// change the user restarts from Settings.
enum LanguageOverride {
    private static let key = "AppleLanguages"

    static func apply(_ language: AppLanguage, defaults: UserDefaults = .standard) {
        if let languages = language.appleLanguages {
            defaults.set(languages, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    /// Launch a fresh instance, then quit this one.
    @MainActor
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApplication.shared.terminate(nil) }
        }
    }
}

extension String {
    /// Wraps the text in Unicode left-to-right isolates so codes and numbers keep their order inside
    /// right-to-left (Hebrew) text (SPEC F31).
    var ltrIsolated: String { "\u{2066}\(self)\u{2069}" }
}
