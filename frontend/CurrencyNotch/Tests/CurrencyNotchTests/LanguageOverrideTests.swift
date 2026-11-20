import CurrencyCore
import Foundation
import Testing
@testable import CurrencyNotch

@Suite("LanguageOverride")
struct LanguageOverrideTests {
    @Test func writesAndClearsTheAppLanguagePreference() {
        let name = "CurrencyNotchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        LanguageOverride.apply(.ru, defaults: defaults)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ru"])
        LanguageOverride.apply(.zhHans, defaults: defaults)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["zh-Hans"])
        // "System" removes the app's own value; reads then fall back to the macOS-wide language list.
        LanguageOverride.apply(.system, defaults: defaults)
        #expect(defaults.persistentDomain(forName: name)?["AppleLanguages"] == nil)
    }

    @Test func ltrIsolationWrapsText() {
        #expect("3.80 ₪".ltrIsolated == "\u{2066}3.80 ₪\u{2069}")
    }
}
