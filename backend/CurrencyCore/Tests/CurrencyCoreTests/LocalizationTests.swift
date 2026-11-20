import Foundation
import Testing
@testable import CurrencyCore

/// Locale formatters may use (narrow) no-break spaces for grouping; compare with plain spaces.
private func plain(_ s: String) -> String {
    s.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
}

@Suite("Localization")
struct LocalizationTests {
    @Test func languageMapsToAppleLanguagesOverride() {
        #expect(AppLanguage.system.appleLanguages == nil)   // follow macOS
        #expect(AppLanguage.he.appleLanguages == ["he"])
        #expect(AppLanguage.en.appleLanguages == ["en"])
        #expect(AppLanguage.es.appleLanguages == ["es"])
        #expect(AppLanguage.ru.appleLanguages == ["ru"])
        #expect(AppLanguage.zhHans.appleLanguages == ["zh-Hans"])
    }

    @Test func everyLanguageHasALocalizationFolderName() {
        let names = AppLanguage.allCases.compactMap(\.localizationName)
        #expect(names == ["he", "en", "es", "ru", "zh-Hans"])
        #expect(AppLanguage.system.localizationName == nil)
    }

    /// SPEC F31: numbers formatted with the selected locale.
    @Test(arguments: [
        ("he_IL", "3.3429", "194,557.83", "5,311.62"),
        ("en_US", "3.3429", "194,557.83", "5,311.62"),
        ("es_ES", "3,3429", "194.557,83", "5311,62"),     // CLDR: Spanish doesn't group 4-digit numbers
        ("ru_RU", "3,3429", "194 557,83", "5 311,62"),
        ("zh_Hans_CN", "3.3429", "194,557.83", "5,311.62")
    ])
    func ratesFollowLocale(locale: String, usd: String, btc: String, eth: String) {
        let formatter = RateFormatter(locale: Locale(identifier: locale))
        #expect(plain(formatter.number(dec("3.34291406"), quoteCode: "USD")) == usd)
        #expect(plain(formatter.number(dec("194557.832"), quoteCode: "BTC")) == btc)
        #expect(plain(formatter.number(dec("5311.62302"), quoteCode: "ETH")) == eth)
    }

    @Test(arguments: [
        ("he_IL", "+2.50%", "−1.20%"),
        ("en_US", "+2.50%", "−1.20%"),
        ("es_ES", "+2,50%", "−1,20%"),
        ("ru_RU", "+2,50%", "−1,20%"),
        ("zh_Hans_CN", "+2.50%", "−1.20%")
    ])
    func changeTextFollowsLocale(locale: String, up: String, down: String) {
        let builder = RateRowBuilder(formatter: RateFormatter(locale: Locale(identifier: locale)))
        #expect(builder.changeText(percent: dec("2.5")) == up)
        #expect(builder.changeText(percent: dec("-1.2")) == down)
    }

    @Test func relativeTimeIsTranslatedInEveryLanguage() {
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let texts = AppLanguage.allCases.filter { $0 != .system }.map {
            RateRowBuilder.updatedAgo(now.addingTimeInterval(-300), now: now, locale: $0.formattingLocale) ?? ""
        }
        #expect(texts.allSatisfy { !$0.isEmpty && $0.contains("5") })
        #expect(Set(texts).count == texts.count)   // each language differs
    }

    @Test func formattedNumbersCarryNoDirectionMarks() {
        for language in AppLanguage.allCases where language != .system {
            let formatter = RateFormatter(locale: language.formattingLocale)
            let builder = RateRowBuilder(formatter: formatter)
            for s in [formatter.number(dec("194557.832"), quoteCode: "BTC"), builder.changeText(percent: dec("-3.4"))] {
                #expect(!s.unicodeScalars.contains { (0x200E...0x200F).contains($0.value) || (0x202A...0x202E).contains($0.value) || (0x2066...0x2069).contains($0.value) },
                        "\(language): \(s)")
            }
        }
    }
}
