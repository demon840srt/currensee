import Foundation
import Testing
@testable import CurrencyCore
import CurrencyCoreTestSupport

@Suite("RateService")
struct RateServiceTests {
    let clock = TestClock()

    func quotes(_ prices: [String: String], source: String) -> [RateQuote] {
        MockRateProvider.quotes(base: "ILS", prices.mapValues(dec), at: clock.now, source: source)
    }

    func makeService(primary: MockRateProvider, fallback: MockRateProvider,
                     cache: DiskCache? = nil, history: HistoryStore? = nil,
                     codes: [String] = ["USD", "EUR", "BTC"]) async -> RateService {
        let service = RateService(primary: primary, fallback: fallback, cache: cache, history: history,
                                  now: clock.provider, sleeper: MockSleeper())
        await service.configure(baseCode: "ILS", codes: codes, refreshInterval: 120)
        return service
    }

    @Test func primarySuccessPublishesWatchedQuotesOnly() async {
        let primary = MockRateProvider(id: "coinbase", script: [.success(quotes(
            ["USD": "3.70", "EUR": "4.00", "BTC": "300000", "GBP": "4.6"], source: "coinbase"))])
        let service = await makeService(primary: primary, fallback: MockRateProvider(script: []))
        let outcome = await service.refresh()
        let snap = await service.snapshot
        #expect(outcome == .primary)
        #expect(Set(snap.quotes.keys) == ["USD", "EUR", "BTC"])
        #expect(snap.quotes["USD"]?.value == dec("3.70"))
        #expect(snap.status == .live)
        #expect(snap.activeSource == "coinbase")
        #expect(snap.lastUpdated == clock.now)
    }

    @Test func oneFailureDoesNotUseFallback() async {
        let primary = MockRateProvider(script: [.failure(.transport("x"))])
        let fallback = MockRateProvider(id: "frankfurter", supportsCrypto: false,
                                        script: [.success(quotes(["USD": "3.6"], source: "frankfurter"))])
        let service = await makeService(primary: primary, fallback: fallback)
        #expect(await service.refresh() == .failed)
        #expect(await fallback.requestedBases.isEmpty)
    }

    @Test func twoFailuresUseFallbackForFiatAndKeepCryptoCached() async {
        let primary = MockRateProvider(id: "coinbase", script: [
            .success(quotes(["USD": "3.70", "EUR": "4.00", "BTC": "300000"], source: "coinbase")),
            .failure(.badStatus(503)), .failure(.badStatus(503))
        ])
        let fallback = MockRateProvider(id: "frankfurter", supportsCrypto: false, script: [
            .success(quotes(["USD": "3.65", "EUR": "3.98", "BTC": "1"], source: "frankfurter"))
        ])
        let service = await makeService(primary: primary, fallback: fallback)
        #expect(await service.refresh() == .primary)
        clock.advance(by: 120)
        #expect(await service.refresh() == .failed)
        clock.advance(by: 240)
        #expect(await service.refresh() == .fallback)

        let snap = await service.snapshot
        #expect(snap.quotes["USD"]?.value == dec("3.65"))
        #expect(snap.quotes["USD"]?.source == "frankfurter")
        #expect(snap.quotes["BTC"]?.value == dec("300000"))   // crypto never taken from fallback
        #expect(snap.quotes["BTC"]?.source == "coinbase")
        #expect(snap.activeSource == "frankfurter")
    }

    @Test func primaryRecoverySwitchesBack() async {
        let primary = MockRateProvider(id: "coinbase", script: [
            .failure(.transport("x")), .failure(.transport("x")),
            .success(quotes(["USD": "3.71", "EUR": "4.01", "BTC": "301000"], source: "coinbase"))
        ])
        let fallback = MockRateProvider(id: "frankfurter", supportsCrypto: false,
                                        script: [.success(quotes(["USD": "3.65"], source: "frankfurter"))])
        let service = await makeService(primary: primary, fallback: fallback)
        _ = await service.refresh()
        #expect(await service.refresh() == .fallback)
        #expect(await service.refresh() == .primary)
        #expect(await service.snapshot.activeSource == "coinbase")
        #expect(await service.snapshot.quotes["USD"]?.source == "coinbase")
        #expect(await service.primaryFailureCount == 0)
        // Next primary failure is again "one failure": no fallback.
        await primary.setScript([.failure(.transport("x"))])
        #expect(await service.refresh() == .failed)
        #expect(await fallback.requestedBases.count == 1)
    }

    @Test func backoffGrowsToMaxAndResetsOnSuccess() async {
        let primary = MockRateProvider(script: [.failure(.transport("x"))])
        let fallback = MockRateProvider(script: [.failure(.transport("y"))])
        let service = await makeService(primary: primary, fallback: fallback)
        #expect(await service.nextDelay == 120)
        var delays: [TimeInterval] = []
        for _ in 0..<5 {
            _ = await service.refresh()
            delays.append(await service.nextDelay)
        }
        #expect(delays == [240, 480, 900, 900, 900])
        await primary.setScript([.success(quotes(["USD": "3.7"], source: "mock"))])
        _ = await service.refresh()
        #expect(await service.nextDelay == 120)
    }

    @Test func quotesGoStaleAfterThreeIntervals() async {
        let primary = MockRateProvider(script: [
            .success(quotes(["USD": "3.70", "EUR": "4.0", "BTC": "300000"], source: "m")),
            .failure(.transport("x"))
        ])
        let service = await makeService(primary: primary, fallback: MockRateProvider(script: [.failure(.noData)]))
        _ = await service.refresh()
        clock.advance(by: 360)
        await service.republish()
        #expect(await service.snapshot.status == .live)
        clock.advance(by: 1)
        _ = await service.refresh()
        let snap = await service.snapshot
        #expect(snap.status == .stale)
        #expect(snap.staleCodes == ["USD", "EUR", "BTC"])
        #expect(snap.quotes["USD"]?.value == dec("3.70"))  // stale data still shown
    }

    @Test func noDataIsDistinctFromStaleAndOffline() async {
        let service = await makeService(primary: MockRateProvider(script: [.failure(.transport("x"))]),
                                        fallback: MockRateProvider(script: [.failure(.noData)]))
        #expect(await service.snapshot.status == .noData)
        _ = await service.refresh()
        #expect(await service.snapshot.status == .noData)
        await service.setOnline(false)
        #expect(await service.snapshot.status == .noData)
    }

    @Test func goingOfflineMarksDataStaleAndOnlineTriggersRefresh() async {
        let primary = MockRateProvider(script: [.success(quotes(["USD": "3.7", "EUR": "4", "BTC": "3"], source: "m"))])
        let service = await makeService(primary: primary, fallback: MockRateProvider(script: []))
        _ = await service.refresh()
        await service.setOnline(false)
        #expect(await service.snapshot.status == .offline)
        #expect(await service.snapshot.staleCodes.count == 3)
        await service.setOnline(true)
        #expect(await service.snapshot.status == .live)
    }

    @Test func bigJumpIsHeldUntilConfirmed() async {
        let primary = MockRateProvider(script: [
            .success(quotes(["USD": "3.70"], source: "m")),
            .success(quotes(["USD": "37.0"], source: "m")),
            .success(quotes(["USD": "3.71"], source: "m")),
            .success(quotes(["USD": "8.00"], source: "m")),
            .success(quotes(["USD": "8.10"], source: "m"))
        ])
        let service = await makeService(primary: primary, fallback: MockRateProvider(script: []), codes: ["USD"])
        _ = await service.refresh()
        _ = await service.refresh()
        #expect(await service.snapshot.quotes["USD"]?.value == dec("3.70"))   // spike held
        _ = await service.refresh()
        #expect(await service.snapshot.quotes["USD"]?.value == dec("3.71"))   // spike dropped
        _ = await service.refresh()
        #expect(await service.snapshot.quotes["USD"]?.value == dec("3.71"))   // held
        _ = await service.refresh()
        #expect(await service.snapshot.quotes["USD"]?.value == dec("8.10"))   // confirmed
    }

    @Test func cacheIsPublishedBeforeFirstFetchAndSavedAfterSuccess() async throws {
        try await withTempDirectory { dir in
            let cache = DiskCache(directory: dir)
            let cached = CachedQuotes(baseCode: "ILS", quotes: quotes(["USD": "3.69", "EUR": "3.99"], source: "coinbase"))
            try await cache.save(cached, to: .quotes)

            let primary = MockRateProvider(script: [.success(quotes(["USD": "3.72", "EUR": "4.01", "BTC": "1"], source: "coinbase"))])
            let service = await makeService(primary: primary, fallback: MockRateProvider(script: []), cache: cache)
            await service.loadCache()
            #expect(await primary.requestedBases.isEmpty)
            #expect(await service.snapshot.quotes["USD"]?.value == dec("3.69"))

            _ = await service.refresh()
            let saved = await cache.load(CachedQuotes.self, from: .quotes)
            #expect(saved?.quotes.first { $0.quoteCode == "USD" }?.value == dec("3.72"))
        }
    }

    @Test func cacheForAnotherBaseIsIgnored() async throws {
        try await withTempDirectory { dir in
            let cache = DiskCache(directory: dir)
            try await cache.save(CachedQuotes(baseCode: "USD", quotes: []), to: .quotes)
            let service = await makeService(primary: MockRateProvider(script: []),
                                            fallback: MockRateProvider(script: []), cache: cache)
            await service.loadCache()
            #expect(await service.snapshot.quotes.isEmpty)
        }
    }

    @Test func baseChangeClearsQuotes() async {
        let primary = MockRateProvider(script: [.success(quotes(["USD": "3.7"], source: "m"))])
        let service = await makeService(primary: primary, fallback: MockRateProvider(script: []))
        _ = await service.refresh()
        await service.configure(baseCode: "USD", codes: ["EUR"], refreshInterval: 120)
        let snap = await service.snapshot
        #expect(snap.baseCode == "USD")
        #expect(snap.quotes.isEmpty)
    }

    @Test func pollingLoopRefreshesThenSleepsAndTriggerWakesIt() async throws {
        let primary = MockRateProvider(script: [.success(quotes(["USD": "3.7"], source: "m"))])
        let sleeper = MockSleeper(immediateCount: 1)
        let service = RateService(primary: primary, fallback: MockRateProvider(script: []),
                                  cache: nil, history: nil, now: clock.provider, sleeper: sleeper)
        await service.configure(baseCode: "ILS", codes: ["USD"], refreshInterval: 120)
        await service.start()
        try await waitUntil { await primary.requestedBases.count == 2 }   // first + after immediate sleep
        await service.triggerRefresh()                                      // wakes the long sleep
        try await waitUntil { await primary.requestedBases.count == 3 }
        await service.stop()
        #expect(await sleeper.requestedDelays.allSatisfy { $0 == 120 })
    }

    @Test func dailyHistoryFetchedOncePerDayAfterSuccess() async throws {
        await withTempDirectory { dir in
            let history = HistoryStore(cache: DiskCache(directory: dir), now: clock.provider)
            let fiatHistory = MockHistoryProvider(result: .success([
                HistoryPoint(quoteCode: "USD", baseCode: "ILS", timestamp: clock.now.addingTimeInterval(-86_400), value: dec("3.6"))
            ]))
            let cryptoHistory = MockHistoryProvider(result: .success([]))
            let primary = MockRateProvider(script: [.success(quotes(["USD": "3.7", "BTC": "300000"], source: "m"))])
            let service = RateService(primary: primary, fallback: MockRateProvider(script: []),
                                      cache: nil, history: history,
                                      fiatHistory: fiatHistory, cryptoHistory: cryptoHistory,
                                      now: clock.provider, sleeper: MockSleeper())
            await service.configure(baseCode: "ILS", codes: ["USD", "BTC"], refreshInterval: 120)
            _ = await service.refresh()
            _ = await service.refresh()
            #expect(await fiatHistory.requests.map(\.quotes) == [["USD"]])
            #expect(await cryptoHistory.requests.map(\.quotes) == [["BTC"]])
            #expect(await history.dailyPoints(quote: "USD", base: "ILS").count == 1)
        }
    }
}

/// Polls `condition` until true or 2 s pass.
func waitUntil(_ condition: @Sendable () async -> Bool) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("condition not met in time")
}
