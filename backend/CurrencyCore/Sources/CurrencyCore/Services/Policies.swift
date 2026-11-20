import Foundation

/// Delay before the next refresh: the refresh interval on success, doubling per consecutive
/// all-sources failure, capped at 15 minutes (never below the refresh interval).
public enum BackoffPolicy {
    public static let maxDelay: TimeInterval = 15 * 60

    public static func delay(refreshInterval: TimeInterval, consecutiveFailures: Int) -> TimeInterval {
        guard consecutiveFailures > 0 else { return refreshInterval }
        let exponent = min(consecutiveFailures, 16)
        let grown = refreshInterval * pow(2, Double(exponent))
        return max(refreshInterval, min(grown, maxDelay))
    }
}

public enum FeedStatus: String, Sendable, Equatable {
    /// All watched quotes are fresh.
    case live
    /// Some quotes are older than 3× the refresh interval.
    case stale
    /// We have data but no network.
    case offline
    /// No quotes at all (UI shows "—").
    case noData
}

/// SPEC F20: stale after 3× the refresh interval or when offline.
public enum StalenessPolicy {
    public static let staleMultiplier: Double = 3

    public static func isStale(fetchedAt: Date, now: Date, refreshInterval: TimeInterval, isOnline: Bool) -> Bool {
        !isOnline || now.timeIntervalSince(fetchedAt) > refreshInterval * staleMultiplier
    }

    public static func status(hasData: Bool, anyStale: Bool, isOnline: Bool) -> FeedStatus {
        guard hasData else { return .noData }
        guard isOnline else { return .offline }
        return anyStale ? .stale : .live
    }
}

/// Injectable sleep so the polling loop is testable without real time passing.
public protocol Sleeper: Sendable {
    func sleep(for seconds: TimeInterval) async throws
}

public struct TaskSleeper: Sleeper {
    public init() {}
    public func sleep(for seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}
