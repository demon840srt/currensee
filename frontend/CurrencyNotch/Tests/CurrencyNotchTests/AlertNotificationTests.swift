import CurrencyCore
import Foundation
import Testing
@testable import CurrencyNotch

/// Phase 9 checklist: notification text localized in all 5 languages, read from the built app's .lproj bundles.
@Suite("Alert notification text")
struct AlertNotificationTests {
    static let languages = ["he", "en", "es", "ru", "zh-Hans"]
    static let keys = ["%@ rose above %@", "%@ fell below %@"]

    private func bundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"), "missing \(language).lproj")
        return try #require(Bundle(path: path))
    }

    @Test(arguments: languages)
    func notificationSentencesAreTranslated(_ language: String) throws {
        let bundle = try bundle(language)
        for key in Self.keys {
            let value = bundle.localizedString(forKey: key, value: "MISSING", table: "Localizable")
            #expect(value != "MISSING", "\(language): \(key)")
            #expect(value.contains("%1$@") && value.contains("%2$@"), "\(language): \(value)")
            if language != "en" {
                #expect(!value.contains("rose above") && !value.contains("fell below"), "\(language) fell back to English")
            }
        }
    }

    @Test func formattedSentenceKeepsCodeAndThreshold() throws {
        let format = try bundle("ru").localizedString(forKey: "%@ rose above %@", value: nil, table: "Localizable")
        let sentence = String(format: format, "USD", "3.8000 ₪")
        #expect(sentence == "USD поднялся выше 3.8000 ₪")
        let hebrew = String(format: try bundle("he").localizedString(forKey: "%@ fell below %@", value: nil, table: "Localizable"),
                            "USD", "3.7000 ₪")
        #expect(hebrew == "USD ירד מתחת ל-3.7000 ₪")
    }
}
