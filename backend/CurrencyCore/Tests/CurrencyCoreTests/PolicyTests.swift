import Foundation
import Testing
@testable import CurrencyCore

@Suite("BackoffPolicy")
struct BackoffPolicyTests {
    @Test func growsExponentiallyToFifteenMinutes() {
        let delays = (0...6).map { BackoffPolicy.delay(refreshInterval: 120, consecutiveFailures: $0) }
        #expect(delays == [120, 240, 480, 900, 900, 900, 900])
    }

    @Test func neverBelowRefreshIntervalOrAboveMax() {
        #expect(BackoffPolicy.delay(refreshInterval: 600, consecutiveFailures: 1) == 900)
        #expect(BackoffPolicy.delay(refreshInterval: 1200, consecutiveFailures: 0) == 1200)
        #expect(BackoffPolicy.delay(refreshInterval: 1200, consecutiveFailures: 3) == 1200)
        #expect(BackoffPolicy.delay(refreshInterval: 60, consecutiveFailures: 1000) == 900)
    }
}

@Suite("StalenessPolicy")
struct StalenessPolicyTests {
    let now = Date(timeIntervalSince1970: 1_795_000_000)

    @Test func staleAfterThreeRefreshIntervals() {
        #expect(!StalenessPolicy.isStale(fetchedAt: now.addingTimeInterval(-360), now: now,
                                         refreshInterval: 120, isOnline: true))
        #expect(StalenessPolicy.isStale(fetchedAt: now.addingTimeInterval(-361), now: now,
                                        refreshInterval: 120, isOnline: true))
    }

    @Test func offlineIsAlwaysStale() {
        #expect(StalenessPolicy.isStale(fetchedAt: now, now: now, refreshInterval: 120, isOnline: false))
    }

    @Test func feedStatusDistinguishesNoDataStaleOfflineLive() {
        #expect(StalenessPolicy.status(hasData: false, anyStale: false, isOnline: true) == .noData)
        #expect(StalenessPolicy.status(hasData: false, anyStale: false, isOnline: false) == .noData)
        #expect(StalenessPolicy.status(hasData: true, anyStale: false, isOnline: false) == .offline)
        #expect(StalenessPolicy.status(hasData: true, anyStale: true, isOnline: true) == .stale)
        #expect(StalenessPolicy.status(hasData: true, anyStale: false, isOnline: true) == .live)
    }
}
