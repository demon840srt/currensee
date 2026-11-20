import Foundation
import Testing
@testable import CurrencyCore
import CurrencyCoreTestSupport

private let fetchedAt = Date(timeIntervalSince1970: 1_795_000_000)

/// HTTP client serving one body/status for every request.
private func client(_ data: Data, status: Int = 200) -> MockHTTPClient {
    MockHTTPClient { _ in (data, status) }
}

private func coinbase(_ http: MockHTTPClient) -> CoinbaseProvider {
    CoinbaseProvider(client: http, now: { fetchedAt })
}

private func frankfurter(_ http: MockHTTPClient) -> FrankfurterProvider {
    FrankfurterProvider(client: http, now: { fetchedAt })
}

@Suite("CoinbaseProvider")
struct CoinbaseProviderTests {
    @Test func requestsExchangeRatesForBase() async throws {
        let http = client(try Fixture.data("coinbase-rates-ILS"))
        _ = try await coinbase(http).latestRates(base: "ILS")
        let url = try #require(await http.requestedURLs.first)
        #expect(url.absoluteString == "https://api.coinbase.com/v2/exchange-rates?currency=ILS")
    }

    @Test func invertsRatesToPriceInBase() async throws {
        let quotes = try await coinbase(client(try Fixture.data("coinbase-rates-ILS"))).latestRates(base: "ILS")
        let usd = try #require(quotes.first { $0.quoteCode == "USD" })
        // Fixture: rates.USD = "0.299027658010035" units of USD per 1 ILS  →  ILS per 1 USD = 1 / that.
        #expect(usd.value == Decimal(1) / dec("0.299027658010035"))
        #expect(usd.value > dec("3.34") && usd.value < dec("3.35"))
        #expect(usd.baseCode == "ILS")
        #expect(usd.source == "coinbase")
        #expect(usd.fetchedAt == fetchedAt)
        let btc = try #require(quotes.first { $0.quoteCode == "BTC" })
        #expect(btc.value > dec("100000") && btc.value < dec("1000000"))
    }

    @Test func excludesBaseAndKeepsManyCodes() async throws {
        let quotes = try await coinbase(client(try Fixture.data("coinbase-rates-ILS"))).latestRates(base: "ILS")
        #expect(!quotes.contains { $0.quoteCode == "ILS" })
        #expect(quotes.count > 300)
        #expect(quotes.allSatisfy { ResponseValidator.isPlausible($0.value) })
    }

    @Test func skipsInvalidEntriesButKeepsValidOnes() async throws {
        let body = #"{"data":{"currency":"ILS","rates":{"USD":"0.27","EUR":"0","GBP":"-1","JPY":"NaN","CHF":"abc","CNY":"1e-30","bad code":"1","BTC":"0.0000029"}}}"#
        let quotes = try await coinbase(client(Data(body.utf8))).latestRates(base: "ILS")
        #expect(quotes.map(\.quoteCode) == ["BTC", "USD"])
    }

    @Test func allInvalidMeansNoData() async {
        let body = #"{"data":{"currency":"ILS","rates":{"USD":"0","EUR":"-2"}}}"#
        await #expect(throws: RateError.noData) {
            try await coinbase(client(Data(body.utf8))).latestRates(base: "ILS")
        }
    }

    @Test func baseMismatchIsRejected() async {
        let body = #"{"data":{"currency":"USD","rates":{"EUR":"0.9"}}}"#
        await #expect(throws: RateError.invalidResponse("base mismatch")) {
            try await coinbase(client(Data(body.utf8))).latestRates(base: "ILS")
        }
    }

    @Test(arguments: [
        #"{"data":{"currency":"ILS","rates":{"USD":0.27}}}"#,   // number instead of string
        #"{"data":{"currency":"ILS"}}"#,
        #"{"rates":{}}"#,
        "<html>Service Unavailable</html>",
        ""
    ])
    func malformedBodiesAreInvalidResponse(_ body: String) async {
        await #expect(throws: RateError.self) {
            try await coinbase(client(Data(body.utf8))).latestRates(base: "ILS")
        }
    }

    @Test func unknownBaseMapsToUnsupportedBase() async throws {
        let http = client(try Fixture.data("coinbase-error-unknown-base"), status: 400)
        await #expect(throws: RateError.unsupportedBase("XYZ")) {
            try await coinbase(http).latestRates(base: "XYZ")
        }
    }

    @Test func invalidBaseCodeNeverHitsNetwork() async {
        let http = client(Data())
        await #expect(throws: RateError.unsupportedBase("../x")) {
            try await coinbase(http).latestRates(base: "../x")
        }
        #expect(await http.requestedURLs.isEmpty)
    }

    @Test func serverErrorIsBadStatus() async {
        await #expect(throws: RateError.badStatus(503)) {
            try await coinbase(client(Data(), status: 503)).latestRates(base: "ILS")
        }
    }

    @Test func oversizedBodyIsRejected() async {
        let big = Data(count: ResponseValidator.maxBodySize + 1)
        await #expect(throws: RateError.responseTooLarge) {
            try await coinbase(client(big)).latestRates(base: "ILS")
        }
    }

    @Test func nonAllowlistedBaseURLIsRejected() async {
        let http = client(Data())
        let provider = CoinbaseProvider(client: http, baseURL: URL(string: "https://evil.example.com/v2")!)
        await #expect(throws: RateError.hostNotAllowed("evil.example.com")) {
            try await provider.latestRates(base: "ILS")
        }
        #expect(await http.requestedURLs.isEmpty)
    }

    @Test func dailyHistoryUsesSpotPricePerDay() async throws {
        let spot = try Fixture.data("coinbase-spot-BTC-ILS-2026-11-19")
        let http = client(spot)
        let points = try await coinbase(http).dailyHistory(
            quotes: ["BTC"], base: "ILS", from: utcDay(2026, 11, 17), to: utcDay(2026, 11, 19))
        #expect(points.count == 3)
        #expect(points.map(\.timestamp) == [utcDay(2026, 11, 17), utcDay(2026, 11, 18), utcDay(2026, 11, 19)])
        #expect(points.allSatisfy { $0.value == dec("204137.401771277264119628") && $0.quoteCode == "BTC" })
        let urls = await http.requestedURLs.map(\.absoluteString)
        #expect(urls.first == "https://api.coinbase.com/v2/prices/BTC-ILS/spot?date=2026-11-17")
        #expect(urls.count == 3)
    }

    @Test func dailyHistorySkipsMissingDaysButFailsOnTransport() async throws {
        let notFound = MockHTTPClient { _ in (Data(#"{"error":"not found"}"#.utf8), 404) }
        let none = try await coinbase(notFound).dailyHistory(
            quotes: ["BTC"], base: "XYZ", from: utcDay(2026, 11, 18), to: utcDay(2026, 11, 19))
        #expect(none.isEmpty)

        let offline = MockHTTPClient { _ in throw RateError.transport("offline") }
        await #expect(throws: RateError.transport("offline")) {
            try await coinbase(offline).dailyHistory(
                quotes: ["BTC"], base: "ILS", from: utcDay(2026, 11, 18), to: utcDay(2026, 11, 19))
        }
    }

    @Test func dailyHistoryRejectsMismatchedPair() async throws {
        let body = #"{"data":{"amount":"5","base":"ETH","currency":"ILS"}}"#
        let points = try await coinbase(client(Data(body.utf8))).dailyHistory(
            quotes: ["BTC"], base: "ILS", from: utcDay(2026, 11, 19), to: utcDay(2026, 11, 19))
        #expect(points.isEmpty)
    }

    @Test func dailyHistoryIsCappedAt35Days() async throws {
        let http = client(try Fixture.data("coinbase-spot-BTC-ILS-2026-11-19"))
        let points = try await coinbase(http).dailyHistory(
            quotes: ["BTC"], base: "ILS", from: utcDay(2026, 1, 1), to: utcDay(2026, 11, 19))
        #expect(points.count == 35)
        #expect(points.last?.timestamp == utcDay(2026, 11, 19))
    }
}

@Suite("FrankfurterProvider")
struct FrankfurterProviderTests {
    @Test func latestRatesAreInvertedFiatOnly() async throws {
        let http = client(try Fixture.data("frankfurter-rates-ILS"))
        let quotes = try await frankfurter(http).latestRates(base: "ILS")
        #expect(await http.requestedURLs.first?.absoluteString == "https://api.frankfurter.dev/v2/rates?base=ILS")
        let catalog = CurrencyCatalog.bundled
        #expect(quotes.allSatisfy { catalog.currency(for: $0.quoteCode)?.kind == .fiat })
        #expect(!quotes.contains { $0.quoteCode == "BTC" || $0.quoteCode == "ILS" })
        let usd = try #require(quotes.first { $0.quoteCode == "USD" })
        #expect(usd.value > dec("3") && usd.value < dec("4"))
        #expect(usd.source == "frankfurter")
        #expect(usd.fetchedAt == fetchedAt)
    }

    @Test func numberRatesKeepExactDecimals() async throws {
        let body = #"[{"date":"2026-11-20","base":"ILS","quote":"USD","rate":0.30198}]"#
        let quotes = try await frankfurter(client(Data(body.utf8))).latestRates(base: "ILS")
        #expect(quotes.first?.value == Decimal(1) / dec("0.30198"))
    }

    @Test func badRowsAreSkipped() async throws {
        let body = #"[{"date":"2026-11-20","base":"ILS","quote":"USD","rate":0.3},{"date":"2026-11-20","base":"ILS","quote":"EUR","rate":0},{"date":"2026-11-20","base":"ILS","quote":"GBP","rate":"0.2"},{"date":"2026-11-20","base":"USD","quote":"JPY","rate":150},{"oops":1}]"#
        let quotes = try await frankfurter(client(Data(body.utf8))).latestRates(base: "ILS")
        #expect(quotes.map(\.quoteCode) == ["USD"])
    }

    @Test func unknownBaseMapsToUnsupportedBase() async throws {
        let http = client(try Fixture.data("frankfurter-error-unknown-base"), status: 422)
        await #expect(throws: RateError.unsupportedBase("XYZ")) {
            try await frankfurter(http).latestRates(base: "XYZ")
        }
    }

    @Test func emptyArrayIsNoData() async {
        await #expect(throws: RateError.noData) {
            try await frankfurter(client(Data("[]".utf8))).latestRates(base: "ILS")
        }
    }

    @Test func dailyHistoryReturnsInvertedPointsPerDay() async throws {
        let http = client(try Fixture.data("frankfurter-range-ILS-USD-EUR"))
        let points = try await frankfurter(http).dailyHistory(
            quotes: ["USD", "EUR"], base: "ILS", from: utcDay(2026, 10, 15), to: utcDay(2026, 11, 19))
        let url = try #require(await http.requestedURLs.first?.absoluteString)
        #expect(url == "https://api.frankfurter.dev/v2/rates?from=2026-10-15&to=2026-11-19&base=ILS&quotes=USD,EUR")
        let usd = points.filter { $0.quoteCode == "USD" }
        #expect(usd.count == 36)
        #expect(usd.first?.timestamp == utcDay(2026, 10, 15))
        #expect(usd.last?.timestamp == utcDay(2026, 11, 19))
        #expect(usd.last?.value == Decimal(1) / dec("0.30515"))
        #expect(points.allSatisfy { $0.baseCode == "ILS" })
    }

    @Test func dailyHistoryWithNoQuotesMakesNoRequest() async throws {
        let http = client(Data())
        let points = try await frankfurter(http).dailyHistory(
            quotes: [], base: "ILS", from: utcDay(2026, 11, 1), to: utcDay(2026, 11, 2))
        #expect(points.isEmpty)
        #expect(await http.requestedURLs.isEmpty)
    }
}
