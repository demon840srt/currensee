import Foundation
import Testing
@testable import CurrencyCore
import CurrencyCoreTestSupport

@Suite("Mocks")
struct MockProviderTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func returnsScriptedResultsInOrderThenRepeatsLast() async throws {
        let first = MockRateProvider.quotes(base: "ILS", ["USD": dec("3.70")], at: now)
        let second = MockRateProvider.quotes(base: "ILS", ["USD": dec("3.71")], at: now)
        let provider = MockRateProvider(id: "mock", script: [.success(first), .failure(.noData), .success(second)])

        #expect(try await provider.latestRates(base: "ILS") == first)
        await #expect(throws: RateError.noData) { try await provider.latestRates(base: "ILS") }
        #expect(try await provider.latestRates(base: "ILS") == second)
        #expect(try await provider.latestRates(base: "ILS") == second)
        #expect(await provider.requestedBases == ["ILS", "ILS", "ILS", "ILS"])
    }

    @Test func conformsToRateProvider() async throws {
        let provider: any RateProvider = MockRateProvider(id: "m", supportsCrypto: false, script: [.success([])])
        #expect(provider.id == "m")
        #expect(provider.supportsCrypto == false)
        #expect(try await provider.latestRates(base: "USD").isEmpty)
    }

    @Test func quotesHelperBuildsSortedQuotes() {
        let q = MockRateProvider.quotes(base: "ILS", ["EUR": dec("4"), "BTC": dec("300000")], at: now, source: "s")
        #expect(q.map(\.quoteCode) == ["BTC", "EUR"])
        #expect(q.allSatisfy { $0.baseCode == "ILS" && $0.source == "s" && $0.fetchedAt == now })
    }

    @Test func mockHTTPClientServesHandlerAndRecordsURLs() async throws {
        let client = MockHTTPClient { url in
            if url.host() == "api.coinbase.com" { return (Data("{}".utf8), 200) }
            throw RateError.transport("offline")
        }
        let ok = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=ILS")!
        let (data, response) = try await client.get(ok)
        #expect(data == Data("{}".utf8))
        #expect(response.statusCode == 200)
        #expect(response.url == ok)
        await #expect(throws: RateError.transport("offline")) {
            try await client.get(URL(string: "https://example.com")!)
        }
        #expect(await client.requestedURLs.count == 2)
    }
}
