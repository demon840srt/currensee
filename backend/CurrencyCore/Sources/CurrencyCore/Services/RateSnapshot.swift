import Foundation

/// Everything the UI needs about current rates, published by `RateService`.
public struct RateSnapshot: Sendable, Equatable {
    public let baseCode: String
    /// Watch-list order.
    public let codes: [String]
    /// Latest accepted quote per code (missing codes have no data yet).
    public let quotes: [String: RateQuote]
    public let staleCodes: Set<String>
    public let status: FeedStatus
    /// Time of the last successful fetch from any source.
    public let lastUpdated: Date?
    /// Provider that delivered the last successful fetch.
    public let activeSource: String?

    public static func empty(baseCode: String = WatchList.default.baseCode) -> RateSnapshot {
        RateSnapshot(baseCode: baseCode, codes: [], quotes: [:], staleCodes: [], status: .noData,
                     lastUpdated: nil, activeSource: nil)
    }
}

/// On-disk form of the last good quotes (`cache.json`).
public struct CachedQuotes: Codable, Sendable, Equatable {
    public let baseCode: String
    public let quotes: [RateQuote]

    public init(baseCode: String, quotes: [RateQuote]) {
        self.baseCode = baseCode
        self.quotes = quotes
    }
}

public enum RefreshOutcome: Sendable, Equatable {
    case primary, fallback, failed
}
