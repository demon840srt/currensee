import Foundation

public enum ChangeDirection: String, Sendable, Equatable {
    case up, down, flat
}

/// Change % and sparkline values for one currency over one range.
public struct ChangeSummary: Sendable, Equatable {
    public enum State: Sendable, Equatable { case collecting, ready }

    public let state: State
    /// Rounded to 2 decimals; nil while collecting.
    public let percent: Decimal?
    public let direction: ChangeDirection
    /// Oldest → newest, at most `HistoryStore.maxSparklinePoints`, ending with the current value.
    public let points: [Decimal]

    public static let collecting = ChangeSummary(state: .collecting, percent: nil, direction: .flat, points: [])
}

/// Local history for sparklines and change % (SPEC F21, ADR-0014).
/// - Intraday: one point per 15-minute bucket from each refresh, kept 48 hours.
/// - Daily: one point per UTC day from providers, kept 35 days.
public actor HistoryStore {
    public static let bucketSeconds: TimeInterval = 15 * 60
    public static let intradayRetention: TimeInterval = 48 * 3600
    public static let dailyRetentionDays = 35
    public static let dailyBackfillDays = 31
    public static let failedRetryDelay: TimeInterval = 3600
    public static let maxSparklinePoints = 48

    public struct DayRange: Sendable, Equatable {
        public let from: Date
        public let to: Date
    }

    private struct Storage: Codable {
        var intraday: [String: [HistoryPoint]] = [:]
        var daily: [String: [HistoryPoint]] = [:]
        var dailyFetchedAt: [String: Date] = [:]
        var dailyFailedAt: [String: Date] = [:]
    }

    private let cache: DiskCache?
    private let now: @Sendable () -> Date
    private var storage = Storage()

    public init(cache: DiskCache?, now: @escaping @Sendable () -> Date = { Date() }) {
        self.cache = cache
        self.now = now
    }

    public func load() async {
        if let saved = await cache?.load(Storage.self, from: .history) {
            storage = saved
            prune()
        }
    }

    // MARK: - Writing

    /// Records refresh results, keeping the last value per 15-minute bucket.
    public func record(_ quotes: [RateQuote]) async {
        for quote in quotes {
            let bucket = Date(timeIntervalSince1970:
                (quote.fetchedAt.timeIntervalSince1970 / Self.bucketSeconds).rounded(.down) * Self.bucketSeconds)
            let point = HistoryPoint(quoteCode: quote.quoteCode, baseCode: quote.baseCode, timestamp: bucket, value: quote.value)
            let key = Self.key(quote.quoteCode, quote.baseCode)
            var series = storage.intraday[key, default: []]
            if let last = series.last, last.timestamp == bucket {
                series[series.count - 1] = point
            } else if let last = series.last, last.timestamp > bucket {
                continue   // out-of-order; ignore
            } else {
                series.append(point)
            }
            storage.intraday[key] = series
        }
        prune()
        await save()
    }

    /// Merges provider daily points (stamped to 00:00 UTC), replacing existing values for the same day.
    public func mergeDaily(_ points: [HistoryPoint]) async {
        for point in points where ResponseValidator.isPlausible(point.value) {
            let day = UTCDay.start(of: point.timestamp)
            let key = Self.key(point.quoteCode, point.baseCode)
            var series = storage.daily[key, default: []].filter { $0.timestamp != day }
            series.append(HistoryPoint(quoteCode: point.quoteCode, baseCode: point.baseCode, timestamp: day, value: point.value))
            storage.daily[key] = series.sorted { $0.timestamp < $1.timestamp }
        }
        prune()
        await save()
    }

    public func markDailyFetched(quote: String, base: String) async {
        let key = Self.key(quote, base)
        storage.dailyFetchedAt[key] = now()
        storage.dailyFailedAt[key] = nil
        await save()
    }

    public func markDailyAttemptFailed(quote: String, base: String) async {
        storage.dailyFailedAt[Self.key(quote, base)] = now()
        await save()
    }

    // MARK: - Reading

    public func intradayPoints(quote: String, base: String) -> [HistoryPoint] {
        storage.intraday[Self.key(quote, base)] ?? []
    }

    public func dailyPoints(quote: String, base: String) -> [HistoryPoint] {
        storage.daily[Self.key(quote, base)] ?? []
    }

    /// Due once per UTC day; after a failure, retried at most hourly.
    public func needsDailyRefresh(quote: String, base: String) -> Bool {
        let key = Self.key(quote, base)
        let current = now()
        if let failed = storage.dailyFailedAt[key], current.timeIntervalSince(failed) < Self.failedRetryDelay {
            return false
        }
        guard let fetched = storage.dailyFetchedAt[key] else { return true }
        return UTCDay.start(of: fetched) != UTCDay.start(of: current)
    }

    /// Days still missing between the last stored day (or 31 days back) and yesterday; nil if complete.
    public func missingDailyRange(quote: String, base: String) -> DayRange? {
        let today = UTCDay.start(of: now())
        let yesterday = UTCDay.adding(-1, to: today)
        var from = UTCDay.adding(-Self.dailyBackfillDays, to: today)
        if let last = dailyPoints(quote: quote, base: base).last?.timestamp {
            from = max(from, UTCDay.adding(1, to: last))
        }
        return from <= yesterday ? DayRange(from: from, to: yesterday) : nil
    }

    public func summary(quote: String, base: String, range: ChangeRange, current: Decimal?) -> ChangeSummary {
        guard let current else { return .collecting }
        var values = series(quote: quote, base: base, range: range).map(\.value)
        values.append(current)
        guard values.count >= 2, let first = values.first, first > 0 else { return .collecting }

        var raw = (current - first) / first * 100
        var percent = Decimal()
        NSDecimalRound(&percent, &raw, 2, .plain)
        let direction: ChangeDirection = percent > 0 ? .up : (percent < 0 ? .down : .flat)
        return ChangeSummary(state: .ready, percent: percent, direction: direction, points: Self.downsample(values))
    }

    // MARK: - Private

    private func series(quote: String, base: String, range: ChangeRange) -> [HistoryPoint] {
        let current = now()
        switch range {
        case .h24:
            let windowStart = current.addingTimeInterval(-24 * 3600)
            let intraday = intradayPoints(quote: quote, base: base).filter { $0.timestamp >= windowStart }
            // Until snapshots cover the window start, seed it with the most recent daily value from 12–72 h ago.
            let covered = intraday.first.map { $0.timestamp <= windowStart.addingTimeInterval(4 * 3600) } ?? false
            guard !covered else { return intraday }
            let seed = dailyPoints(quote: quote, base: base).last {
                $0.timestamp >= current.addingTimeInterval(-72 * 3600) && $0.timestamp <= current.addingTimeInterval(-12 * 3600)
            }
            return (seed.map { [$0] } ?? []) + intraday
        case .d7, .d30:
            let days = range == .d7 ? 7 : 30
            let windowStart = UTCDay.adding(-days, to: current)
            return dailyPoints(quote: quote, base: base).filter { $0.timestamp >= windowStart }
        }
    }

    static func downsample(_ values: [Decimal]) -> [Decimal] {
        guard values.count > maxSparklinePoints else { return values }
        let last = values.count - 1
        return (0..<maxSparklinePoints).map { i in
            values[Int((Double(i) * Double(last) / Double(maxSparklinePoints - 1)).rounded())]
        }
    }

    private func prune() {
        let current = now()
        let intradayCutoff = current.addingTimeInterval(-Self.intradayRetention)
        let dailyCutoff = UTCDay.adding(-Self.dailyRetentionDays, to: current)
        storage.intraday = storage.intraday.compactMapValues { series in
            let kept = series.filter { $0.timestamp >= intradayCutoff }
            return kept.isEmpty ? nil : kept
        }
        storage.daily = storage.daily.compactMapValues { series in
            let kept = series.filter { $0.timestamp >= dailyCutoff }
            return kept.isEmpty ? nil : kept
        }
    }

    private func save() async {
        try? await cache?.save(storage, to: .history)
    }

    private static func key(_ quote: String, _ base: String) -> String { "\(quote)/\(base)" }
}
