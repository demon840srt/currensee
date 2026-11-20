import Foundation
import Testing
@testable import CurrencyNotch

/// Phase 10: no missing keys in any language — checked against the built app's .lproj bundles (what ships).
@Suite("Localization completeness")
struct LocalizationCompletenessTests {
    static let languages = ["he", "en", "es", "ru", "zh-Hans"]
    /// Strings that are legitimately identical to English in some language (Spanish "Fiat", "General",
    /// "Israel", and the "min"/"s" unit abbreviations).
    static let allowedSameAsEnglish: Set<String> = ["Fiat", "General", "Israel", "%lld min", "%lld s"]

    private func table(_ language: String) throws -> [String: String] {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"), "missing \(language).lproj")
        let url = URL(fileURLWithPath: path).appendingPathComponent("Localizable.strings")
        let dictionary = try #require(NSDictionary(contentsOf: url) as? [String: String], "unreadable \(language) table")
        return dictionary
    }

    /// Format specifiers in order of argument position (`%1$@` and `%@` both count as one object argument).
    private func specifiers(_ s: String) -> [String] {
        let regex = /%(?:\d+\$)?(@|lld|ld|d|f)/
        return s.matches(of: regex).map { String($0.output.1) }.sorted()
    }

    @Test func englishTableIsTheReferenceAndNotEmpty() throws {
        #expect(try table("en").count >= 70)
    }

    @Test(arguments: languages)
    func everyKeyIsTranslated(_ language: String) throws {
        let english = try table("en")
        let current = try table(language)
        let missing = Set(english.keys).subtracting(current.keys)
        #expect(missing.isEmpty, "\(language) missing: \(missing.sorted())")
        for (key, value) in current {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "\(language) empty: \(key)")
            #expect(specifiers(value) == specifiers(key), "\(language) placeholders differ: \(key) → \(value)")
        }
    }

    @Test(arguments: ["he", "es", "ru", "zh-Hans"])
    func translationsAreNotEnglishFallbacks(_ language: String) throws {
        let english = try table("en")
        let current = try table(language)
        // Keys that are only symbols/units shared across languages are allowed to match.
        let sameAsEnglish = current.filter { key, value in
            english[key] == value && !Self.allowedSameAsEnglish.contains(key) && value.contains(where: \.isLetter)
        }
        #expect(sameAsEnglish.isEmpty, "\(language) untranslated: \(sameAsEnglish.keys.sorted())")
    }
}
