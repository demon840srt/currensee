import Foundation
import Testing
@testable import CurrencyCore

/// Locale formatters may use (narrow) no-break spaces for grouping; compare with plain spaces.
private func plain(_ s: String) -> String {
    s.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
}

private func quote(_ code: String, _ value: String, base: String = "ILS") -> RateQuote {
    RateQuote(quoteCode: code, baseCode: base, value: dec(value), fetchedAt: Date(), source: "m")
}

@Suite("RateFormatter")
struct RateFormatterTests {
    let en = RateFormatter(locale: Locale(identifier: "en_US"))

    @Test(arguments: [
        ("USD", "3.34291406", "3.3429"),          // fiat: 4
        ("EUR", "3.6653", "3.6653"),
        ("SOL", "512.345678", "512.34568"),       // crypto 1–1000: 5
        ("BTC", "194557.832", "194,557.83"),      // ≥ 1000: 2 + grouping
        ("ETH", "5311.62302", "5,311.62"),
        ("JPY", "0.02109021", "0.02109"),         // < 1: at least 4 significant digits
        ("SHIB", "0.0000117670575", "0.00001177"),
        ("CNY", "0.50082460", "0.5008"),
        ("JPY", "150.123", "150.12"),             // JPY 1–1000: 2
        ("KWD", "1000", "1,000.00")               // boundary
    ])
    func numberUsesPrecisionRule(code: String, value: String, expected: String) {
        #expect(en.number(dec(value), quoteCode: code) == expected)
    }

    @Test func fractionDigitsRule() {
        #expect(en.fractionDigits(for: dec("3.3"), quoteCode: "USD") == 4)
        #expect(en.fractionDigits(for: dec("3.3"), quoteCode: "BTC") == 5)
        #expect(en.fractionDigits(for: dec("2500"), quoteCode: "BTC") == 2)
        #expect(en.fractionDigits(for: dec("0.5"), quoteCode: "USD") == 4)
        #expect(en.fractionDigits(for: dec("0.05"), quoteCode: "USD") == 5)
        #expect(en.fractionDigits(for: dec("0.0000001234"), quoteCode: "PEPE") == 10)
        #expect(en.fractionDigits(for: dec("3.3"), quoteCode: "ZZZ") == 4)   // unknown → 4
    }

    @Test func collapsedPartsUseBaseSymbol() {
        let parts = en.collapsed(code: "USD", quote: quote("USD", "3.34291406"), baseCode: "ILS")
        #expect(parts == CollapsedRate(code: "USD", value: "3.3429", symbol: "₪"))
        #expect(parts.text == "USD 3.3429 ₪")
        let inEuro = en.collapsed(code: "USD", quote: quote("USD", "0.92", base: "EUR"), baseCode: "EUR")
        #expect(inEuro.symbol == "€")
        let unknownBase = en.collapsed(code: "USD", quote: quote("USD", "1.5", base: "ZZZ"), baseCode: "ZZZ")
        #expect(unknownBase.symbol == "ZZZ")
    }

    @Test func missingQuoteShowsDash() {
        #expect(en.collapsed(code: "USD", quote: nil, baseCode: "ILS").text == "USD — ₪")
    }

    @Test func hebrewUsesPointAndCommaGrouping() {
        let he = RateFormatter(locale: Locale(identifier: "he_IL"))
        #expect(plain(he.number(dec("3.34291406"), quoteCode: "USD")) == "3.3429")
        #expect(plain(he.number(dec("194557.832"), quoteCode: "BTC")) == "194,557.83")
    }

    @Test func russianUsesCommaDecimalAndSpaceGrouping() {
        let ru = RateFormatter(locale: Locale(identifier: "ru_RU"))
        #expect(plain(ru.number(dec("3.34291406"), quoteCode: "USD")) == "3,3429")
        #expect(plain(ru.number(dec("194557.832"), quoteCode: "BTC")) == "194 557,83")
    }

    @Test func chineseUsesPointAndCommaGrouping() {
        let zh = RateFormatter(locale: Locale(identifier: "zh_Hans_CN"))
        #expect(plain(zh.number(dec("3.34291406"), quoteCode: "USD")) == "3.3429")
        #expect(plain(zh.number(dec("194557.832"), quoteCode: "BTC")) == "194,557.83")
    }

    @Test func outputHasNoBidiControlCharacters() {
        // Numbers are shown LTR-isolated by the view; the string itself must not carry RLM/LRM marks.
        for id in ["he_IL", "ru_RU", "zh_Hans_CN", "en_US", "es_ES"] {
            let s = RateFormatter(locale: Locale(identifier: id)).number(dec("194557.832"), quoteCode: "BTC")
            #expect(!s.unicodeScalars.contains { (0x200E...0x200F).contains($0.value) || (0x202A...0x202E).contains($0.value) || (0x2066...0x2069).contains($0.value) }, "\(id)")
        }
    }

    @Test func languageMapsToFormattingLocale() {
        #expect(AppLanguage.he.formattingLocale.identifier == "he_IL")
        #expect(AppLanguage.ru.formattingLocale.identifier == "ru_RU")
        let zh = AppLanguage.zhHans.formattingLocale
        #expect(zh.language.languageCode?.identifier == "zh")
        #expect(zh.language.script?.identifier == "Hans")
        #expect(zh.region?.identifier == "CN")
        #expect(AppLanguage.en.formattingLocale.identifier == "en_US")
        #expect(AppLanguage.es.formattingLocale.identifier == "es_ES")
    }
}

@Suite("SplitFlapPlan")
struct SplitFlapPlanTests {
    @Test func equalLengthOnlyChangedCellsFlip() {
        let plan = SplitFlapPlan(from: "3.3429", to: "3.3471")
        #expect(plan.from.count == 6 && plan.to.count == 6)
        #expect(plan.changedCells == [4, 5])
    }

    @Test func trailingAlignmentPadsAtTheStart() {
        let plan = SplitFlapPlan(from: "3.3429", to: "194,557.83", alignment: .trailing)
        #expect(String(plan.from) == "    3.3429")
        #expect(String(plan.to) == "194,557.83")
    }

    @Test func leadingAlignmentPadsAtTheEnd() {
        let plan = SplitFlapPlan(from: "USDC", to: "EUR", alignment: .leading)
        #expect(String(plan.from) == "USDC")
        #expect(String(plan.to) == "EUR ")
        #expect(plan.changedCells == [0, 1, 2, 3])
    }

    @Test func minimumLengthKeepsTheBoardWidthStable() {
        let plan = SplitFlapPlan(from: "USD", to: "EUR", alignment: .leading, minimumLength: 4)
        #expect(plan.cellCount == 4)
        #expect(String(plan.to) == "EUR ")
    }

    @Test func staggeredDelaysFitInTotalDuration() {
        let plan = SplitFlapPlan(from: "0000000000", to: "1111111111")
        let delays = plan.changedCells.map(plan.delay(forCell:))
        #expect(delays.first == 0)
        #expect(delays == delays.sorted())
        #expect(delays.last! + SplitFlapPlan.flipDuration <= SplitFlapPlan.totalDuration + 1e-9)
    }

    @Test func noChangeMeansNoFlip() {
        let plan = SplitFlapPlan(from: "USD", to: "USD")
        #expect(plan.changedCells.isEmpty)
        #expect(plan.delay(forCell: 0) == 0)
    }

    @Test func reduceMotionSelectsCrossfade() {
        #expect(TextTransitionStyle.style(reduceMotion: true) == .crossfade)
        #expect(TextTransitionStyle.style(reduceMotion: false) == .splitFlap)
        #expect(TextTransitionStyle.crossfade.duration == 0.25)
        #expect(TextTransitionStyle.splitFlap.duration == 0.4)
    }
}
