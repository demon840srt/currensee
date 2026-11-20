import Foundation
import Testing
@testable import CurrencyCore

@Suite("CurrencyCatalog")
struct CurrencyCatalogTests {
    let catalog = CurrencyCatalog.bundled

    @Test func bundledCatalogLoadsFiatAndCrypto() {
        #expect(catalog.fiat.count >= 140)
        #expect(catalog.crypto.count >= 20)
        #expect(catalog.currencies.count == catalog.fiat.count + catalog.crypto.count)
    }

    @Test func codesAreUniqueAndValid() {
        let codes = catalog.currencies.map(\.code)
        #expect(Set(codes).count == codes.count)
        #expect(codes.allSatisfy(CurrencyCode.isValid))
    }

    @Test func containsDefaultWatchListAndBase() {
        for code in WatchList.default.orderedCodes + [WatchList.default.baseCode] {
            #expect(catalog.currency(for: code) != nil, "missing \(code)")
        }
    }

    @Test func decimalsFollowRule() {
        for c in catalog.currencies {
            switch (c.kind, c.code) {
            case (.crypto, _): #expect(c.decimals == 5, "\(c.code)")
            case (.fiat, "JPY"): #expect(c.decimals == 2)
            case (.fiat, _): #expect(c.decimals == 4, "\(c.code)")
            }
        }
    }

    @Test func knownEntries() throws {
        let ils = try #require(catalog.currency(for: "ILS"))
        #expect(ils.kind == .fiat)
        #expect(ils.symbol == "₪")
        #expect(ils.flagOrIcon == "🇮🇱")
        let eur = try #require(catalog.currency(for: "EUR"))
        #expect(eur.flagOrIcon == "🇪🇺")
        let btc = try #require(catalog.currency(for: "BTC"))
        #expect(btc.kind == .crypto)
        #expect(btc.symbol == "₿")
        #expect(btc.flagOrIcon == "coin.btc")
    }

    @Test func everyEntryHasNameSymbolAndIcon() {
        for c in catalog.currencies {
            #expect(!c.name.isEmpty && !c.symbol.isEmpty && !c.flagOrIcon.isEmpty, "\(c.code)")
        }
    }

    @Test func lookupIsCaseInsensitive() {
        #expect(catalog.currency(for: "usd")?.code == "USD")
        #expect(catalog.currency(for: "nope") == nil)
    }

    @Test func localizedNamesUseLocaleForFiatAndFallBackForCrypto() {
        #expect(catalog.localizedName(for: "USD", locale: Locale(identifier: "en")) == "US Dollar")
        #expect(catalog.localizedName(for: "USD", locale: Locale(identifier: "he")) != "US Dollar")
        #expect(catalog.localizedName(for: "BTC", locale: Locale(identifier: "he")) == "Bitcoin")
        #expect(catalog.localizedName(for: "ZZZ", locale: Locale(identifier: "en")) == "ZZZ")
    }

    @Test func initRejectsDuplicates() {
        let c = Currency(code: "USD", name: "US Dollar", kind: .fiat, symbol: "$", flagOrIcon: "🇺🇸", decimals: 4)
        #expect(throws: CatalogError.duplicateCode("USD")) { try CurrencyCatalog(currencies: [c, c]) }
    }
}
