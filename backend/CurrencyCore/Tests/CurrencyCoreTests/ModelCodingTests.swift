import Foundation
import Testing
@testable import CurrencyCore

@Suite("Model JSON round-trips")
struct ModelCodingTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func currency() throws {
        let value = Currency(code: "ILS", name: "Israeli New Shekel", kind: .fiat,
                             symbol: "₪", flagOrIcon: "🇮🇱", decimals: 4)
        #expect(try roundTrip(value) == value)
    }

    @Test func rateQuoteKeepsFullDecimalPrecision() throws {
        let value = RateQuote(quoteCode: "SHIB", baseCode: "ILS",
                              value: dec("0.0000412345678901234567"),
                              fetchedAt: now, source: "coinbase")
        let decoded = try roundTrip(value)
        #expect(decoded == value)
        #expect(decoded.value == dec("0.0000412345678901234567"))
    }

    @Test func rateQuoteEncodesDecimalAsString() throws {
        let value = RateQuote(quoteCode: "USD", baseCode: "ILS", value: dec("3.7012"),
                              fetchedAt: now, source: "coinbase")
        let json = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        #expect(json.contains("\"3.7012\""))
    }

    @Test func rateQuoteRejectsNonNumericValue() {
        let json = #"{"quoteCode":"USD","baseCode":"ILS","value":"abc","fetchedAt":0,"source":"x"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RateQuote.self, from: Data(json.utf8))
        }
    }

    @Test func historyPoint() throws {
        let value = HistoryPoint(quoteCode: "EUR", baseCode: "ILS", timestamp: now, value: dec("4.0123"))
        #expect(try roundTrip(value) == value)
    }

    @Test func watchList() throws {
        let value = try WatchList(baseCode: "ILS", orderedCodes: ["USD", "BTC"])
        #expect(try roundTrip(value) == value)
    }

    @Test func rateAlert() throws {
        let value = RateAlert(id: UUID(), quoteCode: "USD", baseCode: "ILS", direction: .above,
                              threshold: dec("3.80"), isArmed: false, lastTriggeredAt: now)
        #expect(try roundTrip(value) == value)
        let fresh = RateAlert(quoteCode: "BTC", baseCode: "ILS", direction: .below, threshold: dec("300000"))
        #expect(try roundTrip(fresh) == fresh)
        #expect(fresh.isArmed)
        #expect(fresh.lastTriggeredAt == nil)
    }

    @Test func widgetPlacement() throws {
        let value = WidgetPlacement(screenID: "display-1", originX: 656, originY: 910.5)
        #expect(try roundTrip(value) == value)
    }

    @Test(arguments: ThemeID.allCases)
    func themeID(_ theme: ThemeID) throws {
        #expect(try roundTrip(theme) == theme)
    }

    @Test func enumRawValuesAreStable() {
        #expect(ThemeID.allCases.map(\.rawValue) == ["ice", "fire", "israel", "classicNotch", "frostedGlass"])
        #expect(ChangeRange.allCases.map(\.rawValue) == ["24h", "7d", "30d"])
        #expect(AppLanguage.allCases.map(\.rawValue) == ["system", "he", "en", "es", "ru", "zh-Hans"])
        #expect(CurrencyKind.allCases.map(\.rawValue) == ["fiat", "crypto"])
        #expect(AlertDirection.allCases.map(\.rawValue) == ["above", "below"])
    }

    @Test func appSettings() throws {
        var value = AppSettings.default
        value.themeID = .israel
        value.changeRange = .d7
        value.language = .ru
        #expect(try roundTrip(value) == value)
    }
}
