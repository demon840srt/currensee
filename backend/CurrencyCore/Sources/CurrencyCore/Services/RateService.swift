import Foundation

/// Fetches, validates and publishes rates (SPEC F16–F20).
///
/// - Primary is tried on every refresh. After 2 consecutive primary failures the fallback serves
///   fiat; crypto keeps its last value. The next primary success switches back automatically.
/// - Backoff applies only when every source tried in a refresh failed.
/// - Jumps > 50% are held until confirmed (`JumpGuard`).
public actor RateService {
    public static let failuresBeforeFallback = 2

    public nonisolated let snapshots: AsyncStream<RateSnapshot>
    public private(set) var snapshot: RateSnapshot = .empty()
    public private(set) var primaryFailureCount = 0

    private let continuation: AsyncStream<RateSnapshot>.Continuation
    private let primary: any RateProvider
    private let fallback: any RateProvider
    private let cache: DiskCache?
    private let history: HistoryStore?
    private let fiatHistory: (any HistoryProvider)?
    private let cryptoHistory: (any HistoryProvider)?
    private let catalog: CurrencyCatalog
    private let now: @Sendable () -> Date
    private let sleeper: any Sleeper

    private var baseCode = WatchList.default.baseCode
    private var codes: [String] = []
    private var refreshInterval: TimeInterval = AppSettings.default.refreshInterval
    private var quotes: [String: RateQuote] = [:]
    private var jumpGuard = JumpGuard()
    private var allSourcesFailureCount = 0
    private var isOnline = true
    private var lastUpdated: Date?
    private var activeSource: String?

    private var loopTask: Task<Void, Never>?
    private var sleepTask: Task<Void, any Error>?
    private var refreshRequested = false

    public init(primary: any RateProvider, fallback: any RateProvider,
                cache: DiskCache?, history: HistoryStore?,
                fiatHistory: (any HistoryProvider)? = nil, cryptoHistory: (any HistoryProvider)? = nil,
                catalog: CurrencyCatalog = .bundled,
                now: @escaping @Sendable () -> Date = { Date() },
                sleeper: any Sleeper = TaskSleeper()) {
        self.primary = primary
        self.fallback = fallback
        self.cache = cache
        self.history = history
        self.fiatHistory = fiatHistory
        self.cryptoHistory = cryptoHistory
        self.catalog = catalog
        self.now = now
        self.sleeper = sleeper
        (snapshots, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    deinit {
        continuation.finish()
    }

    // MARK: - Configuration

    /// Sets base, watched codes and interval. A base change discards quotes held for the old base.
    public func configure(baseCode: String, codes: [String], refreshInterval: TimeInterval) {
        if baseCode != self.baseCode {
            quotes = [:]
            jumpGuard.reset()
            primaryFailureCount = 0
            allSourcesFailureCount = 0
            lastUpdated = nil
            activeSource = nil
        }
        self.baseCode = baseCode
        self.codes = codes
        self.refreshInterval = AppSettings.clampRefresh(refreshInterval)
        publish()
    }

    /// Shows the last good quotes from disk (if they match the current base) before any fetch.
    public func loadCache() async {
        guard let cache, let cached = await cache.load(CachedQuotes.self, from: .quotes),
              cached.baseCode == baseCode else { return }
        for quote in cached.quotes where quote.baseCode == baseCode && ResponseValidator.isPlausible(quote.value) {
            quotes[quote.quoteCode] = quote
        }
        lastUpdated = cached.quotes.map(\.fetchedAt).max()
        activeSource = cached.quotes.max { $0.fetchedAt < $1.fetchedAt }?.source
        publish()
    }

    public func setOnline(_ online: Bool) {
        let cameBack = online && !isOnline
        isOnline = online
        publish()
        if cameBack { triggerRefresh() }
    }

    /// Recomputes staleness for the current time and publishes (e.g. from a UI timer).
    public func republish() {
        publish()
    }

    public var nextDelay: TimeInterval {
        BackoffPolicy.delay(refreshInterval: refreshInterval, consecutiveFailures: allSourcesFailureCount)
    }

    // MARK: - Polling

    public func start() {
        guard loopTask == nil else { return }
        loopTask = Task { await self.runLoop() }
    }

    public func stop() {
        loopTask?.cancel()
        sleepTask?.cancel()
        loopTask = nil
        sleepTask = nil
    }

    /// Refresh now (wake from sleep, network back, "Refresh now"). Wakes the polling loop's sleep.
    public func triggerRefresh() {
        refreshRequested = true
        sleepTask?.cancel()
    }

    private func runLoop() async {
        while !Task.isCancelled {
            refreshRequested = false
            await refresh()
            guard !Task.isCancelled else { return }
            if refreshRequested { continue }
            let delay = nextDelay
            let sleeper = self.sleeper
            let task = Task { try await sleeper.sleep(for: delay) }
            sleepTask = task
            _ = try? await task.value
            sleepTask = nil
        }
    }

    // MARK: - Refresh

    @discardableResult
    public func refresh() async -> RefreshOutcome {
        let base = baseCode
        let watched = Set(codes)
        let outcome: RefreshOutcome
        do {
            let fresh = try await primary.latestRates(base: base)
            guard base == baseCode else { return .failed }   // base changed while fetching
            primaryFailureCount = 0
            accept(fresh.filter { watched.contains($0.quoteCode) }, from: primary.id)
            outcome = .primary
        } catch {
            primaryFailureCount += 1
            outcome = await refreshFromFallbackIfNeeded(base: base, watched: watched)
        }

        if outcome == .failed {
            allSourcesFailureCount += 1
        } else {
            allSourcesFailureCount = 0
            isOnline = true
            await persist()
        }
        publish()
        if outcome != .failed { await refreshDailyHistoryIfNeeded() }
        return outcome
    }

    private func refreshFromFallbackIfNeeded(base: String, watched: Set<String>) async -> RefreshOutcome {
        guard primaryFailureCount >= Self.failuresBeforeFallback else { return .failed }
        do {
            let fresh = try await fallback.latestRates(base: base)
            guard base == baseCode else { return .failed }
            let fiat = fresh.filter { watched.contains($0.quoteCode) && isFiat($0.quoteCode) }
            guard !fiat.isEmpty else { return .failed }
            accept(fiat, from: fallback.id)
            return .fallback
        } catch {
            return .failed
        }
    }

    private func accept(_ fresh: [RateQuote], from source: String) {
        for quote in fresh where quote.baseCode == baseCode && ResponseValidator.isPlausible(quote.value) {
            if let value = jumpGuard.evaluate(quote.quoteCode, new: quote.value, previous: quotes[quote.quoteCode]?.value) {
                quotes[quote.quoteCode] = RateQuote(quoteCode: quote.quoteCode, baseCode: quote.baseCode,
                                                    value: value, fetchedAt: quote.fetchedAt, source: quote.source)
            }
        }
        lastUpdated = now()
        activeSource = source
    }

    private func persist() async {
        let current = codes.compactMap { quotes[$0] }
        await history?.record(current)
        try? await cache?.save(CachedQuotes(baseCode: baseCode, quotes: quotes.values.sorted { $0.quoteCode < $1.quoteCode }),
                               to: .quotes)
    }

    // MARK: - Daily history (once per day per currency)

    private func refreshDailyHistoryIfNeeded() async {
        guard let history else { return }
        let base = baseCode
        var dueFiat: [String] = []
        var dueCrypto: [String] = []
        for code in codes where await history.needsDailyRefresh(quote: code, base: base) {
            if isFiat(code) { dueFiat.append(code) } else if isCrypto(code) { dueCrypto.append(code) }
        }
        if let fiatHistory, !dueFiat.isEmpty {
            await fetchDaily(dueFiat, base: base, provider: fiatHistory, history: history)
        }
        if let cryptoHistory {
            for code in dueCrypto {
                await fetchDaily([code], base: base, provider: cryptoHistory, history: history)
            }
        }
    }

    private func fetchDaily(_ codes: [String], base: String, provider: any HistoryProvider, history: HistoryStore) async {
        var ranges: [HistoryStore.DayRange] = []
        for code in codes {
            if let range = await history.missingDailyRange(quote: code, base: base) { ranges.append(range) }
        }
        guard let from = ranges.map(\.from).min(), let to = ranges.map(\.to).max() else {
            for code in codes { await history.markDailyFetched(quote: code, base: base) }
            return
        }
        do {
            let points = try await provider.dailyHistory(quotes: codes, base: base, from: from, to: to)
            await history.mergeDaily(points)
            for code in codes { await history.markDailyFetched(quote: code, base: base) }
        } catch {
            for code in codes { await history.markDailyAttemptFailed(quote: code, base: base) }
        }
    }

    // MARK: - Helpers

    private func isFiat(_ code: String) -> Bool { catalog.currency(for: code)?.kind == .fiat }
    private func isCrypto(_ code: String) -> Bool { catalog.currency(for: code)?.kind == .crypto }

    private func publish() {
        let current = now()
        let watchedQuotes = codes.compactMap { quotes[$0] }
        let stale = Set(watchedQuotes.filter {
            StalenessPolicy.isStale(fetchedAt: $0.fetchedAt, now: current, refreshInterval: refreshInterval,
                                    isOnline: isOnline)
        }.map(\.quoteCode))
        let next = RateSnapshot(
            baseCode: baseCode,
            codes: codes,
            quotes: Dictionary(uniqueKeysWithValues: watchedQuotes.map { ($0.quoteCode, $0) }),
            staleCodes: stale,
            status: StalenessPolicy.status(hasData: !watchedQuotes.isEmpty, anyStale: !stale.isEmpty, isOnline: isOnline),
            lastUpdated: lastUpdated,
            activeSource: activeSource
        )
        snapshot = next
        continuation.yield(next)
    }
}
